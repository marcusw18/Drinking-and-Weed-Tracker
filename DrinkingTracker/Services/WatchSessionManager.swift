import Foundation
import WatchConnectivity

/// iPhone-side WatchConnectivity manager.
/// Sends analysis requests to the watch and receives audio + health data back.
@Observable
final class WatchSessionManager: NSObject, WCSessionDelegate {

    static let shared = WatchSessionManager()

    var isWatchReachable = false
    var receivedAudioURL: URL? = nil

    // Callbacks set by AnalysisViewModel
    var onHealthDataReceived: (([String: Any]) -> Void)?
    var onAudioReceived: ((URL) -> Void)?

    private override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    // MARK: - Requests

    /// Ask the watch to begin a 60-second voice + health data capture.
    func requestAnalysis() {
        guard WCSession.default.isReachable else { return }
        WCSession.default.sendMessage(["action": "startCapture"], replyHandler: nil)
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        isWatchReachable = session.isReachable
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        isWatchReachable = session.isReachable
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        // Receive health metrics from watch
        if message["type"] as? String == "healthData" {
            onHealthDataReceived?(message)
        }
    }

    func session(_ session: WCSession, didReceive file: WCSessionFile) {
        // Copy the transferred audio file to a stable location
        let dest = FileManager.default.temporaryDirectory
            .appendingPathComponent("watchAudio_\(Date().timeIntervalSince1970).m4a")
        try? FileManager.default.copyItem(at: file.fileURL, to: dest)
        onAudioReceived?(dest)
    }

    // Required iOS-only delegate stubs
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }
}
