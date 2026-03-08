import SwiftUI

// MARK: - App Theme
// Single source of truth for all colors, fonts, and spacing across the app.

struct AppTheme {

    // MARK: - Colors
    struct Colors {
        // Backgrounds
        static let background       = Color(hex: "#F2F2F2")   // warm light gray (main bg)
        static let cardBackground   = Color(hex: "#FFFFFF")   // white cards
        static let inputBackground  = Color(hex: "#EBEBEB")   // form fields / gray6 equivalent

        // Text
        static let textPrimary      = Color(hex: "#111111")   // near-black
        static let textSecondary    = Color(hex: "#888888")   // medium gray
        static let textTertiary     = Color(hex: "#BBBBBB")   // light gray

        // Accent
        static let accentBlack      = Color(hex: "#111111")   // primary button bg, bold text
        static let accentWhite      = Color(hex: "#FFFFFF")   // primary button label

        // Divider / Border
        static let divider          = Color(hex: "#D8D8D8")

        // Tab bar icons
        static let tabActive        = Color(hex: "#111111")
        static let tabInactive      = Color(hex: "#CCCCCC")

        // Calendar dot colors
        static let dotRed           = Color(hex: "#F4A0A0")   // day 12
        static let dotGreen         = Color(hex: "#A0E0A8")   // day 16
        static let dotYellow        = Color(hex: "#F5EE88")   // day 17
        static let dotTeal          = Color(hex: "#82D9BE")   // day 24
        static let dotGray          = Color(hex: "#CCCCCC")   // day 26
    }

    // MARK: - Typography
    struct Fonts {
        // Large display / page title
        static func title(_ size: CGFloat = 38) -> Font {
            .system(size: size, weight: .regular, design: .serif)
        }
        // Monospaced body / labels / buttons
        static func mono(_ size: CGFloat = 15, weight: Font.Weight = .regular) -> Font {
            .system(size: size, weight: weight, design: .monospaced)
        }
    }

    // MARK: - Corner Radii
    struct Radius {
        static let card: CGFloat   = 14
        static let button: CGFloat = 16
        static let field: CGFloat  = 10
    }

    // MARK: - Shadows
    struct Shadow {
        static let card = ShadowStyle(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

struct ShadowStyle {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

// MARK: - View Modifier helpers
extension View {
    func cardShadow() -> some View {
        self.shadow(
            color: AppTheme.Shadow.card.color,
            radius: AppTheme.Shadow.card.radius,
            x: AppTheme.Shadow.card.x,
            y: AppTheme.Shadow.card.y
        )
    }
}

// MARK: - Hex Color Init
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB,
                  red:   Double(r) / 255,
                  green: Double(g) / 255,
                  blue:  Double(b) / 255,
                  opacity: Double(a) / 255)
    }
}
