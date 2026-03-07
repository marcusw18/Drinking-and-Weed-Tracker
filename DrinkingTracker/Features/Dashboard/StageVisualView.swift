import SwiftUI

struct StageVisualView: View {
    let stage: IntoxicationStage

    var body: some View {
        VStack(spacing: 12) {
            // Character emoji scaled by stage
            Text(stage.emoji)
                .font(.system(size: 72))
                .scaleEffect(1.0 + Double(stage.rawValue) * 0.05)
                .animation(.spring(duration: 0.4), value: stage)

            Text(stage.label)
                .font(.title2.bold())
                .foregroundStyle(stage.color)

            // Stage indicator dots
            HStack(spacing: 8) {
                ForEach(IntoxicationStage.allCases, id: \.rawValue) { s in
                    Circle()
                        .fill(s.rawValue <= stage.rawValue ? s.color : Color(.systemGray5))
                        .frame(width: 10, height: 10)
                        .scaleEffect(s == stage ? 1.4 : 1.0)
                        .animation(.spring(duration: 0.3), value: stage)
                }
            }

            // Recommendations
            if !stage.recommendations.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(stage.recommendations, id: \.self) { rec in
                        Label(rec, systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(stage.color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
