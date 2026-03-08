import SwiftUI

// MARK: - Watch Status View
// Primary tab: shows current intoxication stage, BAC, heart rate, drunkenness score.

struct WatchStatusView: View {
    @Environment(WatchAppState.self) private var watchState

    var body: some View {
        ZStack {
            WatchTheme.Colors.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 8) {

                    // MARK: Stage Badge
                    stageBadge

                    // MARK: BAC Row
                    metricRow(
                        label: "BAC",
                        value: String(format: "%.3f%%", watchState.currentBAC),
                        color: bacColor
                    )

                    // MARK: Heart Rate Row
                    if let hr = watchState.latestHeartRate {
                        metricRow(
                            label: "❤️ HR",
                            value: "\(Int(hr)) bpm",
                            color: WatchTheme.Colors.dotRed
                        )
                    }

                    // MARK: Drunkenness Score
                    if let score = watchState.drunkennessScore {
                        scoreBar(score: score)
                    }

                    // MARK: Drinks Count
                    if watchState.sessionActive {
                        metricRow(
                            label: "DRINKS",
                            value: "\(watchState.drinkCount)",
                            color: WatchTheme.Colors.textSecondary
                        )
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 6)
            }
        }
    }

    // MARK: - Stage Badge

    private var stageBadge: some View {
        HStack(spacing: 6) {
            Text(watchState.currentStage.emoji)
                .font(.system(size: 28))
            VStack(alignment: .leading, spacing: 1) {
                Text(watchState.currentStage.label.uppercased())
                    .font(WatchTheme.Fonts.mono(12, weight: .bold))
                    .foregroundColor(watchState.currentStage.watchColor)
                if !watchState.sessionActive {
                    Text("No session")
                        .font(WatchTheme.Fonts.mono(9))
                        .foregroundColor(WatchTheme.Colors.textSecondary)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(watchState.currentStage.watchColor.opacity(0.12))
        .cornerRadius(8)
    }

    // MARK: - Metric Row

    private func metricRow(label: String, value: String, color: Color) -> some View {
        HStack {
            Text(label)
                .font(WatchTheme.Fonts.mono(9))
                .foregroundColor(WatchTheme.Colors.textSecondary)
            Spacer()
            Text(value)
                .font(WatchTheme.Fonts.mono(12, weight: .semibold))
                .foregroundColor(color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(WatchTheme.Colors.card)
        .cornerRadius(6)
    }

    // MARK: - Score Bar

    private func scoreBar(score: Int) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text("SCORE")
                    .font(WatchTheme.Fonts.mono(9))
                    .foregroundColor(WatchTheme.Colors.textSecondary)
                Spacer()
                Text("\(score)/100")
                    .font(WatchTheme.Fonts.mono(11, weight: .semibold))
                    .foregroundColor(scoreColor(score))
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(WatchTheme.Colors.divider)
                        .frame(height: 4)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(scoreColor(score))
                        .frame(width: geo.size.width * CGFloat(score) / 100, height: 4)
                        .animation(.spring(response: 0.5), value: score)
                }
            }
            .frame(height: 4)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(WatchTheme.Colors.card)
        .cornerRadius(6)
    }

    // MARK: - Color Helpers

    private var bacColor: Color {
        switch watchState.currentBAC {
        case ..<0.03: return WatchTheme.Colors.dotGreen
        case ..<0.08: return WatchTheme.Colors.dotTeal
        case ..<0.15: return WatchTheme.Colors.dotYellow
        case ..<0.25: return .orange
        default:      return WatchTheme.Colors.dotRed
        }
    }

    private func scoreColor(_ score: Int) -> Color {
        switch score {
        case ..<25: return WatchTheme.Colors.dotGreen
        case ..<50: return WatchTheme.Colors.dotYellow
        case ..<75: return .orange
        default:    return WatchTheme.Colors.dotRed
        }
    }
}
