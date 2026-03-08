import SwiftUI

// MARK: - Watch Theme
// Mirrors AppTheme from the phone app, adapted for the compact watch screen.

enum WatchTheme {

    enum Colors {
        static let background     = Color(white: 0.05)
        static let card           = Color(white: 0.11)
        static let textPrimary    = Color(white: 0.95)
        static let textSecondary  = Color(white: 0.50)
        static let divider        = Color(white: 0.18)
        static let dotGreen       = Color(red: 0.20, green: 0.85, blue: 0.40)
        static let dotTeal        = Color(red: 0.20, green: 0.80, blue: 0.75)
        static let dotYellow      = Color(red: 0.95, green: 0.85, blue: 0.15)
        static let dotRed         = Color(red: 0.95, green: 0.30, blue: 0.25)
        static let accentGreen    = Color(red: 0.20, green: 0.85, blue: 0.40)
    }

    enum Fonts {
        static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
            .system(size: size, weight: weight, design: .monospaced)
        }
    }
}

// MARK: - Stage color helper for watch (mirrors IntoxicationStage.color on phone)

extension IntoxicationStageWatch {
    var watchColor: Color {
        switch self {
        case .sober:    return WatchTheme.Colors.dotGreen
        case .relaxed:  return Color(red: 0.6, green: 0.9, blue: 0.2)
        case .tipsy:    return WatchTheme.Colors.dotYellow
        case .drunk:    return .orange
        case .veryDrunk: return Color(red: 0.9, green: 0.3, blue: 0.1)
        case .danger:   return WatchTheme.Colors.dotRed
        }
    }
}
