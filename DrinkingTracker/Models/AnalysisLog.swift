import Foundation

struct AnalysisLog: Identifiable, Codable {
    let id: UUID
    let userId: String
    let timestamp: Date
    let bacEstimated: Double
    let stage: IntoxicationStage
    let heartRate: Double?
    let hrv: Double?
    let spo2: Double?
    let slurScore: Double?       // 0.0 – 1.0 from Vulture server
    let blushScore: Double?      // 0.0 – 1.0 from Vision analysis
    let geminiSummary: String?
    let trigger: AnalysisTrigger

    enum AnalysisTrigger: String, Codable {
        case manual = "manual"
        case auto = "auto"
    }

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case timestamp
        case bacEstimated = "bac_estimated"
        case stage
        case heartRate = "heart_rate"
        case hrv
        case spo2
        case slurScore = "slur_score"
        case blushScore = "blush_score"
        case geminiSummary = "gemini_summary"
        case trigger
    }
}
