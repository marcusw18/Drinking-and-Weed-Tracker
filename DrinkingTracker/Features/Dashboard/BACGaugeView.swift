import SwiftUI

struct BACGaugeView: View {
    let bac: Double
    let stage: IntoxicationStage

    private let maxBAC: Double = 0.40

    var body: some View {
        VStack(spacing: 8) {
            Text("Blood Alcohol Content")
                .font(.caption)
                .foregroundStyle(.secondary)

            ZStack {
                // Track arc
                Arc(startAngle: .degrees(150), endAngle: .degrees(390))
                    .stroke(Color(.systemGray5), style: StrokeStyle(lineWidth: 18, lineCap: .round))

                // Fill arc
                Arc(startAngle: .degrees(150), endAngle: .degrees(150 + 240 * fillFraction))
                    .stroke(
                        stage.color,
                        style: StrokeStyle(lineWidth: 18, lineCap: .round)
                    )
                    .animation(.easeInOut(duration: 0.6), value: bac)

                // Center text
                VStack(spacing: 2) {
                    Text(String(format: "%.3f%%", bac))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                    Text("BAC")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 180, height: 120)

            if bac > 0 {
                let hours = BACCalculator.hoursUntilSober(currentBAC: bac)
                Text("Sober in ~\(formattedHours(hours))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var fillFraction: Double {
        min(bac / maxBAC, 1.0)
    }

    private func formattedHours(_ hours: Double) -> String {
        let h = Int(hours)
        let m = Int((hours - Double(h)) * 60)
        if h == 0 { return "\(m)m" }
        return m == 0 ? "\(h)h" : "\(h)h \(m)m"
    }
}

// MARK: - Arc Shape

struct Arc: Shape {
    var startAngle: Angle
    var endAngle: Angle

    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.addArc(
            center: CGPoint(x: rect.midX, y: rect.midY),
            radius: min(rect.width, rect.height) / 2,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: false
        )
        return p
    }
}
