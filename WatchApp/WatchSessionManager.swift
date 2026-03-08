import Foundation
import WatchConnectivity
import HealthKit
import AVFoundation
import CoreMotion
import UserNotifications

// MARK: - Watch Session Manager (Watch side)
// Handles WatchConnectivity, 30-second audio recording, CoreMotion movement,
// HealthKit reads, and receives drunkenness score + auth context from iPhone.

@MainActor
final class WatchSessionManagerWatch: NSObject, ObservableObject, WCSessionDelegate {

    static let shared = WatchSessionManagerWatch()

    @Published var isCapturing = false
    @Published var captureSecondsRemaining = 30

    /// Seconds until the next automatic 15-minute analysis fires (0 when no session)
    @Published var secondsUntilNextCapture: Int = 0

    private let healthStore = HKHealthStore()
    private let motionManager = CMMotionManager()
    private var audioRecorder: AVAudioRecorder?
    private var recordingCountdownTimer: Timer?
    private var autoAnalysisTimer: Timer?      // fires every 15 min during session
    private var autoCountdownTimer: Timer?     // decrements secondsUntilNextCapture each second
    private var accelerometerSamples: [Double] = []

    private static let autoIntervalSeconds = 15 * 60   // 15 minutes

    private override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
        requestHealthAuthorization()
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession,
                 activationDidCompleteWith state: WCSessionActivationState,
                 error: Error?) {}

    /// iPhone requests a capture
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard message["action"] as? String == "startCapture" else { return }
        Task { await startCapture() }
    }

    /// Receives BAC / stage / auth / score updates from iPhone
    func session(_ session: WCSession, didReceiveApplicationContext context: [String: Any]) {
        let state = WatchAppState.shared

        // Auth sync
        if let uid = context["userId"] as? String, !uid.isEmpty { state.userId = uid }
        if let name = context["displayName"] as? String { state.displayName = name }

        // Session
        if let bac = context["bac"] as? Double { state.currentBAC = bac }
        if let raw = context["stage"] as? Int { state.currentStageRaw = raw }
        if let drinks = context["drinkCount"] as? Int { state.drinkCount = drinks }
        if let active = context["sessionActive"] as? Bool {
            let wasActive = state.sessionActive
            state.sessionActive = active
            // Start/stop 15-min auto-analysis timer when session state changes
            if active && !wasActive { startAutoAnalysisTimer() }
            else if !active && wasActive { stopAutoAnalysisTimer() }
        }

        // Analysis result (computed on iPhone after Vulture + health scoring)
        if let score = context["drunkennessScore"] as? Int { state.drunkennessScore = score }
        if let slur = context["slurLabel"] as? String { state.slurLabel = slur }
        if let hr = context["heartRate"] as? Double { state.latestHeartRate = hr }
    }

    // MARK: - Auto-Analysis Timer (15-minute interval)

    private func startAutoAnalysisTimer() {
        stopAutoAnalysisTimer()
        secondsUntilNextCapture = Self.autoIntervalSeconds

        // Fires every 15 minutes to trigger automatic analysis
        autoAnalysisTimer = Timer.scheduledTimer(
            withTimeInterval: TimeInterval(Self.autoIntervalSeconds),
            repeats: true
        ) { [weak self] _ in
            Task { await self?.startCapture() }
        }

        // UI countdown: decrement every second
        autoCountdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if self.secondsUntilNextCapture > 0 {
                    self.secondsUntilNextCapture -= 1
                } else {
                    // Reset after a capture fires
                    self.secondsUntilNextCapture = Self.autoIntervalSeconds
                }
            }
        }
    }

    private func stopAutoAnalysisTimer() {
        autoAnalysisTimer?.invalidate()
        autoAnalysisTimer = nil
        autoCountdownTimer?.invalidate()
        autoCountdownTimer = nil
        secondsUntilNextCapture = 0
    }

    // MARK: - Manual Trigger (from WatchRecordView)

    func triggerCapture() {
        Task { await startCapture() }
    }

    // MARK: - Capture Pipeline

    private func startCapture() async {
        guard !isCapturing else { return }
        isCapturing = true
        captureSecondsRemaining = 30
        accelerometerSamples = []

        startMotionTracking()

        recordingCountdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                if self.captureSecondsRemaining > 0 { self.captureSecondsRemaining -= 1 }
            }
        }

        // 1. Record 30-second voice clip
        let audioURL = await recordAudio(duration: 30)

        // 2. Read HealthKit
        let healthData = await readHealthData()

        // 3. Compute movement score
        let movScore = stopMotionTracking()
        WatchAppState.shared.movementScore = movScore

        recordingCountdownTimer?.invalidate()
        recordingCountdownTimer = nil
        // Reset auto-countdown to full 15 min after each capture
        if WatchAppState.shared.sessionActive {
            secondsUntilNextCapture = Self.autoIntervalSeconds
        }

        // 4. Send health + movement to iPhone
        var payload = healthData
        payload["type"] = "healthData"
        payload["movementScore"] = movScore
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(payload, replyHandler: nil)
        }

        // 5. Transfer audio — iPhone will POST to Vulture, compute score, send back
        if let url = audioURL {
            WCSession.default.transferFile(url, metadata: ["type": "voiceClip"])
        }

        isCapturing = false
        captureSecondsRemaining = 30
    }

    // MARK: - Audio Recording (30 seconds)

    private func recordAudio(duration: TimeInterval) async -> URL? {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("watchCapture_\(Int(Date().timeIntervalSince1970)).m4a")

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 16000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
        ]

        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .default)
            try audioSession.setActive(true)
            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.record(forDuration: duration)
            try await Task.sleep(for: .seconds(duration))
            audioRecorder?.stop()
            try? audioSession.setActive(false)
            return url
        } catch {
            print("WatchAudio error: \(error)")
            return nil
        }
    }

    // MARK: - CoreMotion — Accelerometer jerkiness → movement impairment

    private func startMotionTracking() {
        guard motionManager.isAccelerometerAvailable else { return }
        motionManager.accelerometerUpdateInterval = 0.1
        motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, _ in
            guard let data else { return }
            let mag = sqrt(
                data.acceleration.x * data.acceleration.x +
                data.acceleration.y * data.acceleration.y +
                data.acceleration.z * data.acceleration.z
            )
            self?.accelerometerSamples.append(mag)
        }
    }

    /// Stops accelerometer and returns 0–1 movement impairment score.
    /// Standard deviation: ~0.05 = steady, ~0.30+ = very erratic.
    private func stopMotionTracking() -> Double {
        motionManager.stopAccelerometerUpdates()
        let s = accelerometerSamples
        guard s.count > 10 else { return 0 }
        let mean = s.reduce(0, +) / Double(s.count)
        let variance = s.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(s.count)
        return min(sqrt(variance) / 0.30, 1.0)
    }

    // MARK: - HealthKit

    private func readHealthData() async -> [String: Any] {
        var data: [String: Any] = [:]
        if let hr = await fetchLatest(type: .heartRate, unit: HKUnit(from: "count/min")) {
            data["heartRate"] = hr
            await MainActor.run { WatchAppState.shared.latestHeartRate = hr }
        }
        if let hrv = await fetchLatest(type: .heartRateVariabilitySDNN, unit: .secondUnit(with: .milli)) {
            data["hrv"] = hrv
        }
        if let spo2 = await fetchLatest(type: .oxygenSaturation, unit: .percent()) {
            data["spo2"] = spo2
        }
        return data
    }

    private func fetchLatest(type id: HKQuantityTypeIdentifier, unit: HKUnit) async -> Double? {
        let type = HKQuantityType(id)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        return await withCheckedContinuation { cont in
            let q = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sort]) { _, samples, _ in
                cont.resume(returning: (samples?.first as? HKQuantitySample)?.quantity.doubleValue(for: unit))
            }
            healthStore.execute(q)
        }
    }

    private func requestHealthAuthorization() {
        let types: Set<HKObjectType> = [
            HKQuantityType(.heartRate),
            HKQuantityType(.heartRateVariabilitySDNN),
            HKQuantityType(.oxygenSaturation)
        ]
        healthStore.requestAuthorization(toShare: [], read: types) { _, _ in }
    }
}

// MARK: - IntoxicationStageWatch

/// Mirror of IntoxicationStage for Watch — no SwiftUI Color dependency.
enum IntoxicationStageWatch: Int {
    case sober = 0, relaxed, tipsy, drunk, veryDrunk, danger

    var label: String {
        ["Sober", "Relaxed", "Tipsy", "Drunk", "Very Drunk", "Danger"][rawValue]
    }
    var emoji: String {
        ["😊", "😌", "😄", "😵‍💫", "😵", "🚨"][rawValue]
    }
}
