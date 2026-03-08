import SwiftUI

struct ScanView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // Title + underline
                VStack(alignment: .leading, spacing: 6) {
                    Text("Scan")
                        .font(AppTheme.Fonts.title(38))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    Rectangle()
                        .fill(AppTheme.Colors.divider)
                        .frame(width: 60, height: 1)
                }
                .padding(.top, 16)
                .padding(.horizontal, 20)

                // Subtitle
                Text("Center your face within the target")
                    .font(AppTheme.Fonts.mono(13))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .padding(.top, 8)
                    .padding(.horizontal, 20)

                // Camera viewfinder placeholder
                ZStack {
                    RoundedRectangle(cornerRadius: AppTheme.Radius.card)
                        .fill(AppTheme.Colors.inputBackground)

                    FaceSilhouette()
                        .stroke(Color.white.opacity(0.7), lineWidth: 2)
                        .frame(width: 180, height: 220)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 420)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.Radius.card)
                        .stroke(AppTheme.Colors.divider, lineWidth: 1)
                )
                .padding(.horizontal, 16)
                .padding(.top, 20)

                Spacer(minLength: 140)
            }
        }
    }
}

// MARK: - Face Silhouette Shape

struct FaceSilhouette: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width, h = rect.height, cx = rect.midX

        path.addEllipse(in: CGRect(x: cx - w * 0.38, y: rect.minY, width: w * 0.76, height: h * 0.72))

        path.move(to: CGPoint(x: cx - w * 0.18, y: rect.minY + h * 0.70))
        path.addQuadCurve(to: CGPoint(x: cx + w * 0.18, y: rect.minY + h * 0.70),
                          control: CGPoint(x: cx, y: rect.minY + h * 0.78))

        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: cx - w * 0.18, y: rect.minY + h * 0.72),
                          control: CGPoint(x: cx - w * 0.4, y: rect.minY + h * 0.80))
        path.move(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: cx + w * 0.18, y: rect.minY + h * 0.72),
                          control: CGPoint(x: cx + w * 0.4, y: rect.minY + h * 0.80))

        return path
    }
}

#Preview { ScanView() }
