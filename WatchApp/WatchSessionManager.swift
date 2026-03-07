import Foundation
import WatchConnectivity
import HealthKit
import AVFoundation

/// Apple Watch-side session manager.
/// Listens for capture requests from the iPhone, records voice + reads health data, sends back.
@MainActor
final class WatchSessionManagerWatch: NSObject, ObservableObject, WCSessionDelegate {

    static let shared = WatchSessionManagerWatch()

    @Published var isCapturing = false
    @Published var captureSecondsRemaining = 60
    @Published var currentStageEmoji = "😊"
    @Published var currentStageLabel = "Sober"
    @Published var currentBAC: Double = 0.0

    private let healthStore = HKHealthStore()
    private var audioRecorder: AVAudioRecorder?
    private var countdownTimer: Timer?

    private override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
        requestHealthAuthorization()
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {}

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard message["action"] as? String == "startCapture" else { return }
        Task { await startCapture() }
    }

    func session(_ session: WCSession, didReceiveApplicationContext context: [String: Any]) {
        // Receive BAC / stage updates from phone
        if let bac = context["bac"] as? Double { currentBAC = bac }
        if let stageRaw = context["stage"] as? Int,
           let stage = IntoxicationStageWatch(rawValue: stageRaw) {
            currentStageEmoji = stage.emoji
            currentStageLabel = stage.label
        }
    }

    // MARK: - Capture Pipeline

    private func startCapture() async {
        guard !isCapturing else { return }
        isCapturing = true
        captureSecondsRemaining = 60

        // Start countdown UI
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.captureSecondsRemaining -= 1
            }
        }

        // 1. Record voice
        let audioURL = await recordAudio(duration: 60)

        // 2. Read health data
        let healthData = await readHealthData()

        // Stop countdown
        countdownTimer?.invalidate()
        countdownTimer = nil

        // 3. Send health data immediately via message
        var payload = healthData
        payload["type"] = "healthData"
        WCSession.default.sendMessage(payload, replyHandler: nil)

        // 4. Transfer audio file
        if let url = audioURL {
            WCSession.default.transferFile(url, metadata: ["type": "voiceClip"])
        }

        isCapturing = false
        captureSecondsRemaining = 60
    }

    // MARK: - Audio Recording

    private func recordAudio(duration: TimeInterval) async -> URL? {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("watchCapture.m4a")

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 12000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
        ]

        do {
            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.record(forDuration: duration)
            try await Task.sleep(for: .seconds(duration))
            return url
        } catch {
            return nil
        }
    }

    // MARK: - Health Data

    private func readHealthData() async -> [String: Any] {
        var data: [String: Any] = [:]

        if let hr = await fetchLatest(type: .heartRate, unit: HKUnit(from: "count/min")) {
            data["heartRate"] = hr
        }
        if let hrv = await fetchLatest(type: .heartRateVariabilitySDNN, unit: .secondUnit(with: .milli)) {
            data["hrv"] = hrv
        }
        if let spo2 = await fetchLatest(type: .oxygenSaturation, unit: .percent()) {
            data["spo2"] = spo2
        }

        return data
    }

    private func fetchLatest(type quantityTypeID: HKQuantityTypeIdentifier, unit: HKUnit) async -> Double? {
        let type = HKQuantityType(quantityTypeID)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sort]) { _, samples, _ in
                let value = (samples?.first as? HKQuantitySample)?.quantity.doubleValue(for: unit)
                continuation.resume(returning: value)
            }
            healthStore.execute(query)
        }
    }

    // MARK: - HealthKit Auth

    private func requestHealthAuthorization() {
        let types: Set<HKObjectType> = [
            HKQuantityType(.heartRate),
            HKQuantityType(.heartRateVariabilitySDNN),
            HKQuantityType(.oxygenSaturation)
        ]
        healthStore.requestAuthorization(toShare: [], read: types) { _, _ in }
    }
}

/// Mirror of IntoxicationStage for Watch (no SwiftUI Color dependency)
enum IntoxicationStageWatch: Int {
    case sober = 0, relaxed, tipsy, drunk, veryDrunk, danger

    var label: String {
        ["Sober", "Relaxed", "Tipsy", "Drunk", "Very Drunk", "Danger"][rawValue]
    }
    var emoji: String {
        ["😊", "😌", "😄", "😵‍💫", "😵", "🚨"][rawValue]
    }
}
