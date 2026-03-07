import SwiftUI

enum IntoxicationStage: Int, CaseIterable, Codable {
    case sober = 0
    case relaxed = 1
    case tipsy = 2
    case drunk = 3
    case veryDrunk = 4
    case danger = 5

    var label: String {
        switch self {
        case .sober:    return "Sober"
        case .relaxed:  return "Relaxed"
        case .tipsy:    return "Tipsy"
        case .drunk:    return "Drunk"
        case .veryDrunk: return "Very Drunk"
        case .danger:   return "Danger"
        }
    }

    var emoji: String {
        switch self {
        case .sober:    return "😊"
        case .relaxed:  return "😌"
        case .tipsy:    return "😄"
        case .drunk:    return "😵‍💫"
        case .veryDrunk: return "😵"
        case .danger:   return "🚨"
        }
    }

    var color: Color {
        switch self {
        case .sober:    return .green
        case .relaxed:  return Color(red: 0.6, green: 0.9, blue: 0.2)
        case .tipsy:    return .yellow
        case .drunk:    return .orange
        case .veryDrunk: return Color(red: 0.9, green: 0.3, blue: 0.1)
        case .danger:   return .red
        }
    }

    /// BAC lower bound for this stage
    var bacThreshold: Double {
        switch self {
        case .sober:    return 0.00
        case .relaxed:  return 0.03
        case .tipsy:    return 0.08
        case .drunk:    return 0.15
        case .veryDrunk: return 0.25
        case .danger:   return 0.35
        }
    }

    var recommendations: [String] {
        switch self {
        case .sober:
            return ["You're good to go!", "Stay hydrated."]
        case .relaxed:
            return ["Drink water between drinks.", "Eat something if you haven't."]
        case .tipsy:
            return ["Do not drive.", "Drink water now.", "Slow down on alcohol."]
        case .drunk:
            return ["Stop drinking alcohol.", "Drink lots of water.", "Do NOT drive.", "Find a safe place to rest."]
        case .veryDrunk:
            return ["Stop drinking immediately.", "You need someone to look after you.", "Call a friend or family member.", "Do NOT drive or operate machinery."]
        case .danger:
            return ["SEEK MEDICAL ATTENTION if vomiting or unconscious.", "Do NOT leave this person alone.", "Call emergency services if unresponsive.", "Recovery position if lying down."]
        }
    }

    static func from(bac: Double) -> IntoxicationStage {
        // Walk backwards through stages to find the highest threshold <= bac
        return allCases.last { bac >= $0.bacThreshold } ?? .sober
    }
}
