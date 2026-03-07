import Foundation

enum AlcoholType: String, CaseIterable, Codable {
    case beer = "beer"
    case wine = "wine"
    case spirits = "spirits"
    case cocktail = "cocktail"
    case cider = "cider"
    case other = "other"

    var defaultPercentage: Double {
        switch self {
        case .beer:     return 5.0
        case .wine:     return 13.0
        case .spirits:  return 40.0
        case .cocktail: return 12.0
        case .cider:    return 5.0
        case .other:    return 5.0
        }
    }

    var defaultVolumeMl: Double {
        switch self {
        case .beer:     return 355
        case .wine:     return 150
        case .spirits:  return 44
        case .cocktail: return 200
        case .cider:    return 355
        case .other:    return 200
        }
    }

    var icon: String {
        switch self {
        case .beer:     return "🍺"
        case .wine:     return "🍷"
        case .spirits:  return "🥃"
        case .cocktail: return "🍸"
        case .cider:    return "🍎"
        case .other:    return "🥤"
        }
    }
}

struct DrinkLog: Identifiable, Codable, Equatable {
    let id: UUID
    let userId: String
    let timestamp: Date
    let alcoholType: AlcoholType
    let percentage: Double   // e.g. 5.0 for 5%
    let volumeMl: Double

    init(
        id: UUID = UUID(),
        userId: String,
        timestamp: Date = Date(),
        alcoholType: AlcoholType,
        percentage: Double,
        volumeMl: Double
    ) {
        self.id = id
        self.userId = userId
        self.timestamp = timestamp
        self.alcoholType = alcoholType
        self.percentage = percentage
        self.volumeMl = volumeMl
    }

    /// Pure ethanol in grams: volume × ABV × density of ethanol (0.789 g/mL)
    var gramsOfAlcohol: Double {
        volumeMl * (percentage / 100.0) * 0.789
    }

    // MARK: - Codable keys (match Supabase snake_case columns)
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case timestamp
        case alcoholType = "alcohol_type"
        case percentage
        case volumeMl = "volume_ml"
    }
}
