import Foundation
import FirebaseAuth

@Observable
final class AppState {

    // MARK: - Auth
    var firebaseUser: User? = nil
    var isLoggedIn: Bool { firebaseUser != nil }
    var userId: String { firebaseUser?.uid ?? "" }

    // MARK: - Session
    var isSessionActive: Bool = false
    var sessionStartTime: Date? = nil

    // MARK: - BAC & Stage
    var currentBAC: Double = 0.0
    var currentStage: IntoxicationStage = .sober

    // MARK: - Data
    var drinkLogs: [DrinkLog] = []
    var analysisLogs: [AnalysisLog] = []
    var userProfile: UserProfile? = nil

    // MARK: - Health (from Apple Watch / HealthKit)
    var latestHeartRate: Double? = nil
    var latestHRV: Double? = nil
    var latestSpO2: Double? = nil

    // MARK: - UI State
    var showAddDrink = false
    var showHistory = false
    var showAnalysis = false
    var showChatbot = false
    var isAnalysisRunning = false

    // MARK: - BAC Refresh
    func refreshBAC() {
        guard let profile = userProfile else { return }
        let sessionDrinks = isSessionActive
            ? drinkLogs.filter { $0.timestamp >= (sessionStartTime ?? .distantPast) }
            : drinkLogs
        currentBAC = BACCalculator.currentBAC(drinks: sessionDrinks, profile: profile)
        currentStage = IntoxicationStage.from(bac: currentBAC)
    }

    func startSession() {
        isSessionActive = true
        sessionStartTime = Date()
    }

    func endSession() {
        isSessionActive = false
        sessionStartTime = nil
    }
}
