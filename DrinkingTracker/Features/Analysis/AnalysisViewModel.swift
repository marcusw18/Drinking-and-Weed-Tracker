import Foundation
import UIKit

@Observable
final class AnalysisViewModel {

    enum AnalysisStep: String {
        case idle = "idle"
        case requestingWatch = "Requesting Watch data..."
        case capturingFace = "Capturing face photo..."
        case analyzingFace = "Analyzing face..."
        case analyzingVoice = "Analyzing voice..."
        case askingGemini = "Generating summary..."
        case saving = "Saving results..."
        case complete = "Complete"
        case failed = "Analysis failed"
    }

    var currentStep: AnalysisStep = .idle
    var result: AnalysisLog? = nil
    var errorMessage: String? = nil
    var isRunning: Bool { currentStep != .idle && currentStep != .complete && currentStep != .failed }

    // Collected data
    var capturedImage: UIImage? = nil
    var survey: PreAnalysisSurvey = PreAnalysisSurvey()

    @ObservationIgnored private let appState: AppState
    @ObservationIgnored private let watchManager = WatchSessionManager.shared
    @ObservationIgnored private var collectedAudioURL: URL? = nil
    @ObservationIgnored private var collectedHealthData: [String: Any] = [:]

    init(appState: AppState) {
        self.appState = appState
    }

    // MARK: - Full Pipeline

    func runAnalysis(isManual: Bool) async {
        currentStep = .requestingWatch
        errorMessage = nil

        // TEMPORARY: Test VoiceAnalyzer
        Task {
            do {
                let allowed = await VoiceAnalyzer.shared.requestMicrophonePermission()
                print("Mic allowed:", allowed)

                if !allowed {
                    print("Microphone permission denied")
                    return
                }

                let audioURL = try await VoiceAnalyzer.shared.recordAudio(duration: 5)
                print("Recorded file:", audioURL)
                print("File exists:", FileManager.default.fileExists(atPath: audioURL.path))

                let score = try await VoiceAnalyzer.shared.analyzeAudio(audioURL: audioURL)
                print("Voice score:", score)

                await VoiceAnalyzer.shared.cleanup()
            } catch {
                print("Voice analyzer error:", error.localizedDescription)
            }
        }

        // 1. Request Watch data (audio + health)
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await self.requestWatchData()
            }
            // Give watch 75 seconds to respond (60s recording + transfer time)
            try? await Task.sleep(for: .seconds(75))
        }

        // 2. Capture face (manual analysis only)
        var blushScore: Double? = nil
        if isManual, let image = capturedImage {
            currentStep = .analyzingFace
            if let faceResult = try? await FaceAnalyzer.analyze(image: image) {
                blushScore = faceResult.blushScore
            }
        }

        // 3. Analyze voice with Vulture server
        var slurScore: Double? = nil
        if let audioURL = collectedAudioURL {
            currentStep = .analyzingVoice
            slurScore = (try? await VultureService.shared.analyzeVoice(audioURL: audioURL))?.slurScore
        }

        // 4. Refresh health metrics
        await HealthKitService.shared.refreshAll()
        let hr   = HealthKitService.shared.latestHeartRate ?? (collectedHealthData["heartRate"] as? Double)
        let hrv  = HealthKitService.shared.latestHRV ?? (collectedHealthData["hrv"] as? Double)
        let spo2 = HealthKitService.shared.latestSpO2 ?? (collectedHealthData["spo2"] as? Double)

        appState.latestHeartRate = hr
        appState.latestHRV = hrv
        appState.latestSpO2 = spo2

        // 5. Gemini summary
        currentStep = .askingGemini
        let summary = try? await GeminiService.shared.stageSummary(
            bac: appState.currentBAC,
            stage: appState.currentStage,
            heartRate: hr,
            slurScore: slurScore,
            blushScore: blushScore
        )

        // 6. Build + save log
        currentStep = .saving
        let log = AnalysisLog(
            id: UUID(),
            userId: appState.userId,
            timestamp: Date(),
            bacEstimated: appState.currentBAC,
            stage: appState.currentStage,
            heartRate: hr,
            hrv: hrv,
            spo2: spo2,
            slurScore: slurScore,
            blushScore: blushScore,
            geminiSummary: summary,
            trigger: isManual ? .manual : .auto
        )

        try? await SupabaseService.shared.insertAnalysisLog(log)
        appState.analysisLogs.insert(log, at: 0)

        result = log
        currentStep = .complete
    }

    // MARK: - Watch Data Collection

    private func requestWatchData() async {
        watchManager.onHealthDataReceived = { [weak self] data in
            self?.collectedHealthData = data
        }
        watchManager.onAudioReceived = { [weak self] url in
            self?.collectedAudioURL = url
        }
        watchManager.requestAnalysis()
    }

    func reset() {
        currentStep = .idle
        result = nil
        errorMessage = nil
        capturedImage = nil
        collectedAudioURL = nil
        collectedHealthData = [:]
    }
}
