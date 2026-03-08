import SwiftUI

// MARK: - Watch Record View
// Second tab: triggers 30-second voice capture, shows countdown, then displays results.

struct WatchRecordView: View {
    @Environment(WatchAppState.self) private var watchState
    @StateObject private var session = WatchSessionManagerWatch.shared

    var body: some View {
        ZStack {
            WatchTheme.Colors.background.ignoresSafeArea()

            VStack(spacing: 10) {
                if session.isCapturing {
                    capturingView
                } else if watchState.drunkennessScore != nil {
                    resultsView
                } else {
                    idleView
                }
            }
            .padding()
        }
    }

    // MARK: - Idle: Analyze button

    private var idleView: some View {
        VStack(spacing: 12) {
            Text("ANALYZE")
                .font(WatchTheme.Fonts.mono(11))
                .foregroundColor(WatchTheme.Colors.textSecondary)

            Button {
                session.triggerCapture()
            } label: {
                ZStack {
                    Circle()
                        .fill(WatchTheme.Colors.dotGreen)
                        .frame(width: 60, height: 60)
                    Image(systemName: "mic.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.black)
                }
            }
            .buttonStyle(.plain)

            Text("30 sec voice\n+ movement")
                .font(WatchTheme.Fonts.mono(9))
                .foregroundColor(WatchTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Capturing: Countdown ring

    private var capturingView: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(WatchTheme.Colors.divider, lineWidth: 4)
                    .frame(width: 64, height: 64)

                Circle()
                    .trim(from: 0,
                          to: CGFloat(session.captureSecondsRemaining) / 30.0)
                    .stroke(WatchTheme.Colors.dotGreen,
                            style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 64, height: 64)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: session.captureSecondsRemaining)

                VStack(spacing: 0) {
                    Text("\(session.captureSecondsRemaining)")
                        .font(WatchTheme.Fonts.mono(18, weight: .bold))
                        .foregroundColor(WatchTheme.Colors.textPrimary)
                    Text("sec")
                        .font(WatchTheme.Fonts.mono(8))
                        .foregroundColor(WatchTheme.Colors.textSecondary)
                }
            }

            Text("Recording...")
                .font(WatchTheme.Fonts.mono(10))
                .foregroundColor(WatchTheme.Colors.dotGreen)

            Text("Keep talking\nnaturally")
                .font(WatchTheme.Fonts.mono(9))
                .foregroundColor(WatchTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Results panel

    private var resultsView: some View {
        VStack(spacing: 8) {
            if let score = watchState.drunkennessScore {
                Text("RESULT")
                    .font(WatchTheme.Fonts.mono(9))
                    .foregroundColor(WatchTheme.Colors.textSecondary)

                Text("\(score)")
                    .font(WatchTheme.Fonts.mono(36, weight: .bold))
                    .foregroundColor(scoreColor(score))
                + Text("/100")
                    .font(WatchTheme.Fonts.mono(14))
                    .foregroundColor(WatchTheme.Colors.textSecondary)

                if !watchState.slurLabel.isEmpty {
                    HStack(spacing: 4) {
                        Text("SLUR")
                            .font(WatchTheme.Fonts.mono(8))
                            .foregroundColor(WatchTheme.Colors.textSecondary)
                        Text(watchState.slurLabel)
                            .font(WatchTheme.Fonts.mono(9, weight: .semibold))
                            .foregroundColor(WatchTheme.Colors.textPrimary)
                    }
                }
            }

            // Re-analyze button
            Button {
                session.triggerCapture()
            } label: {
                Text("Re-analyze")
                    .font(WatchTheme.Fonts.mono(10))
                    .foregroundColor(WatchTheme.Colors.dotGreen)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(WatchTheme.Colors.card)
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)
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
