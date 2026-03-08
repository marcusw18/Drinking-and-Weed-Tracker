import Foundation

// MARK: - Watch App State
// Single source of truth for the Watch app, populated via WatchConnectivity
// from the iPhone (auth, BAC, stage, drinks) and locally (health, score).

@Observable
final class WatchAppState {

    static let shared = WatchAppState()
    private init() {}

    // MARK: - Auth (synced from iPhone)
    var userId: String = ""
    var displayName: String = ""
    var isLoggedIn: Bool { !userId.isEmpty }

    // MARK: - Session (synced from iPhone)
    var currentBAC: Double = 0.0
    var currentStageRaw: Int = 0
    var drinkCount: Int = 0
    var sessionActive: Bool = false

    var currentStage: IntoxicationStageWatch {
        IntoxicationStageWatch(rawValue: currentStageRaw) ?? .sober
    }

    // MARK: - Health (read locally on watch)
    var latestHeartRate: Double? = nil

    // MARK: - Analysis Results (from Vulture + iPhone composite)
    var drunkennessScore: Int? = nil     // 0–100
    var slurLabel: String = ""          // "None" / "Mild" / "Moderate" / "High"
    var movementScore: Double = 0.0     // 0–1 accelerometer variance

    // MARK: - Alert Tracking
    var lastAlertedStage: Int = -1
    var lastAlertedDrinkMilestone: Int = 0
}
