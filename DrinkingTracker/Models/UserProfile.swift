import Foundation

enum BiologicalSex: String, CaseIterable, Codable {
    case male = "male"
    case female = "female"
    case other = "other"

    /// Widmark r-factor
    var widmarkR: Double {
        switch self {
        case .male:   return 0.68
        case .female: return 0.55
        case .other:  return 0.615  // midpoint
        }
    }
}

struct UserProfile: Codable {
    let userId: String
    var weightKg: Double
    var heightCm: Double
    var biologicalSex: BiologicalSex
    var displayName: String

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case weightKg = "weight_kg"
        case heightCm = "height_cm"
        case biologicalSex = "biological_sex"
        case displayName = "display_name"
    }
}
