import Foundation
import UIKit

@Observable
final class AnalysisViewModel {

    enum AnalysisStep: String {
        case idle          = "idle"
        case capturingFace = "Capturing face photo..."
        case analyzingFace = "Analyzing face..."
        case fetchingHealth = "Reading health data..."
        case askingGemini  = "Generating summary..."
        case saving        = "Saving results..."
        case complete      = "Complete"
        case failed        = "Analysis failed"
    }

    var currentStep: AnalysisStep = .idle
    var result: AnalysisLog? = nil
    var errorMessage: String? = nil
    var isRunning: Bool { currentStep != .idle && currentStep != .complete && currentStep != .failed }

    var capturedImage: UIImage? = nil
    var survey: PreAnalysisSurvey = PreAnalysisSurvey()

    @ObservationIgnored private let appState: AppState

    init(appState: AppState) {
        self.appState = appState
    }

    // MARK: - Full Pipeline

    func runAnalysis(isManual: Bool) async {
        errorMessage = nil

        // 1. Face analysis (manual only — requires a captured UIImage)
        var blushScore: Double? = nil
        if isManual, let image = capturedImage {
            currentStep = .analyzingFace
            if let faceResult = try? await FaceAnalyzer.analyze(image: image) {
                blushScore = faceResult.blushScore
            }
        }

        // 2. Refresh health metrics from HealthKit
        currentStep = .fetchingHealth
        await HealthKitService.shared.refreshAll()
        let hr   = HealthKitService.shared.latestHeartRate
        let hrv  = HealthKitService.shared.latestHRV
        let spo2 = HealthKitService.shared.latestSpO2

        appState.latestHeartRate = hr
        appState.latestHRV       = hrv
        appState.latestSpO2      = spo2

        // 3. Gemini summary
        currentStep = .askingGemini
        let summary = try? await GeminiService.shared.stageSummary(
            bac: appState.currentBAC,
            stage: appState.currentStage,
            heartRate: hr,
            slurScore: nil,
            blushScore: blushScore
        )

        // 4. Build + save log
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
            slurScore: nil,
            blushScore: blushScore,
            geminiSummary: summary,
            trigger: isManual ? .manual : .auto
        )

        try? await SupabaseService.shared.insertAnalysisLog(log)
        appState.analysisLogs.insert(log, at: 0)

        result = log
        currentStep = .complete
    }

    func reset() {
        currentStep = .idle
        result = nil
        errorMessage = nil
        capturedImage = nil
    }
}
