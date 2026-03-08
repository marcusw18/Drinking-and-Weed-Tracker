import Foundation
import WatchConnectivity

// MARK: - Watch Session Manager (iPhone side)
// Syncs auth + session state to the watch, receives audio + health data,
// forwards audio to Vulture, computes a composite drunkenness score (0–100),
// and sends the result back to the watch.

@Observable
final class WatchSessionManager: NSObject, WCSessionDelegate {

    static let shared = WatchSessionManager()

    var isWatchReachable = false

    // Callbacks set by AnalysisViewModel (existing analysis pipeline)
    var onHealthDataReceived: (([String: Any]) -> Void)?
    var onAudioReceived: ((URL) -> Void)?

    // Health payload from last watch message, used when audio arrives
    private var pendingHealthData: [String: Any] = [:]

    private override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    // MARK: - Sync to Watch

    /// Push auth + session state to the watch via applicationContext.
    /// Call this on login, on BAC refresh, and when drinks are added.
    func syncToWatch(bac: Double,
                     stage: Int,
                     drinkCount: Int,
                     sessionActive: Bool,
                     userId: String,
                     displayName: String) {
        guard WCSession.default.activationState == .activated else { return }
        let ctx: [String: Any] = [
            "bac": bac,
            "stage": stage,
            "drinkCount": drinkCount,
            "sessionActive": sessionActive,
            "userId": userId,
            "displayName": displayName
        ]
        try? WCSession.default.updateApplicationContext(ctx)
    }

    /// Ask the watch to start a 30-second voice + health capture.
    func requestAnalysis() {
        guard WCSession.default.isReachable else { return }
        WCSession.default.sendMessage(["action": "startCapture"], replyHandler: nil)
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession,
                 activationDidCompleteWith state: WCSessionActivationState,
                 error: Error?) {
        isWatchReachable = session.isReachable
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        isWatchReachable = session.isReachable
    }

    /// Receives health + movement data from the watch
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard message["type"] as? String == "healthData" else { return }
        pendingHealthData = message
        onHealthDataReceived?(message)
    }

    /// Receives the 30-second audio clip from the watch
    func session(_ session: WCSession, didReceive file: WCSessionFile) {
        guard file.metadata?["type"] as? String == "voiceClip" else { return }

        let dest = FileManager.default.temporaryDirectory
            .appendingPathComponent("watchAudio_\(Date().timeIntervalSince1970).m4a")
        try? FileManager.default.copyItem(at: file.fileURL, to: dest)

        // Notify existing analysis pipeline (AnalysisViewModel)
        onAudioReceived?(dest)

        // Forward to Vulture + compute + return score to watch
        let health = pendingHealthData
        Task { await analyzeAndSendScore(audioURL: dest, healthData: health) }
    }

    // Required iOS-only stubs
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) { WCSession.default.activate() }

    // MARK: - Drunkenness Score (0–100)

    /// Computes a composite score:
    ///   Slur score (Vulture)  40%
    ///   Heart rate anomaly    25%
    ///   Movement impairment   15%
    ///   Remaining headroom    20% (BAC weight lives on the phone side)
    private func analyzeAndSendScore(audioURL: URL, healthData: [String: Any]) async {
        var slurScore: Double = 0
        var slurLabel = "None"

        if let response = try? await VultureService.shared.analyzeVoice(audioURL: audioURL) {
            slurScore  = response.slurScore
            slurLabel  = severityLabel(slurScore)
        }

        // Heart rate: 0 at ≤65 bpm → 1.0 at ≥130 bpm
        let hr  = healthData["heartRate"] as? Double ?? 0
        let hrC = min(max((hr - 65.0) / 65.0, 0), 1.0)

        // Movement: 0–1 from watch accelerometer standard deviation
        let movC = healthData["movementScore"] as? Double ?? 0

        // Weighted sum, normalised to 0–100
        let rawScore  = slurScore * 0.40 + hrC * 0.25 + movC * 0.15
        let score = min(Int((rawScore / 0.80) * 100), 100)

        // Merge result into the watch's applicationContext
        var ctx = WCSession.default.applicationContext
        ctx["drunkennessScore"] = score
        ctx["slurLabel"] = slurLabel
        if hr > 0 { ctx["heartRate"] = hr }
        try? WCSession.default.updateApplicationContext(ctx)
    }

    private func severityLabel(_ score: Double) -> String {
        switch score {
        case ..<0.25: return "None"
        case ..<0.50: return "Mild"
        case ..<0.75: return "Moderate"
        default:      return "High"
        }
    }
}
