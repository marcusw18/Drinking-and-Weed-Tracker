import SwiftUI

// MARK: - Watch Record View
// Shows auto-analysis countdown during a session, manual trigger, and results.

struct WatchRecordView: View {
    @Environment(WatchAppState.self) private var watchState
    @StateObject private var session = WatchSessionManagerWatch.shared

    var body: some View {
        ZStack {
            WatchTheme.Colors.background.ignoresSafeArea()

            VStack(spacing: 10) {
                if session.isCapturing {
                    capturingView
                } else if watchState.sessionActive {
                    autoModeView
                } else {
                    manualView
                }
            }
            .padding()
        }
    }

    // MARK: - Auto mode: session is active, showing countdown + manual trigger

    private var autoModeView: some View {
        VStack(spacing: 10) {
            Text("AUTO ANALYSIS")
                .font(WatchTheme.Fonts.mono(9))
                .foregroundColor(WatchTheme.Colors.dotGreen)

            // Countdown ring to next auto-capture
            ZStack {
                Circle()
                    .stroke(WatchTheme.Colors.divider, lineWidth: 3)
                    .frame(width: 60, height: 60)

                Circle()
                    .trim(from: 0, to: autoProgress)
                    .stroke(
                        WatchTheme.Colors.dotGreen,
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: session.secondsUntilNextCapture)

                VStack(spacing: 0) {
                    Text(countdownString)
                        .font(WatchTheme.Fonts.mono(13, weight: .bold))
                        .foregroundColor(WatchTheme.Colors.textPrimary)
                    Text("next")
                        .font(WatchTheme.Fonts.mono(7))
                        .foregroundColor(WatchTheme.Colors.textSecondary)
                }
            }

            // Manual override
            Button {
                session.triggerCapture()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 10))
                    Text("Analyze Now")
                        .font(WatchTheme.Fonts.mono(10))
                }
                .foregroundColor(WatchTheme.Colors.dotGreen)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(WatchTheme.Colors.card)
                .cornerRadius(6)
            }
            .buttonStyle(.plain)

            // Last result summary (if available)
            if let score = watchState.drunkennessScore {
                HStack(spacing: 6) {
                    Text("Last:")
                        .font(WatchTheme.Fonts.mono(9))
                        .foregroundColor(WatchTheme.Colors.textSecondary)
                    Text("\(score)/100")
                        .font(WatchTheme.Fonts.mono(10, weight: .semibold))
                        .foregroundColor(scoreColor(score))
                    if !watchState.slurLabel.isEmpty && watchState.slurLabel != "None" {
                        Text("· \(watchState.slurLabel) slur")
                            .font(WatchTheme.Fonts.mono(9))
                            .foregroundColor(WatchTheme.Colors.textSecondary)
                    }
                }
            }
        }
    }

    // MARK: - No session: manual-only mode

    private var manualView: some View {
        VStack(spacing: 12) {
            Text("MANUAL")
                .font(WatchTheme.Fonts.mono(9))
                .foregroundColor(WatchTheme.Colors.textSecondary)

            Button {
                session.triggerCapture()
            } label: {
                ZStack {
                    Circle()
                        .fill(WatchTheme.Colors.card)
                        .frame(width: 56, height: 56)
                    Image(systemName: "mic.fill")
                        .font(.system(size: 20))
                        .foregroundColor(WatchTheme.Colors.textSecondary)
                }
            }
            .buttonStyle(.plain)

            Text("Start a session\non iPhone first")
                .font(WatchTheme.Fonts.mono(9))
                .foregroundColor(WatchTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Capturing: 30s countdown ring

    private var capturingView: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(WatchTheme.Colors.divider, lineWidth: 4)
                    .frame(width: 64, height: 64)

                Circle()
                    .trim(from: 0,
                          to: CGFloat(session.captureSecondsRemaining) / 30.0)
                    .stroke(WatchTheme.Colors.dotRed,
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
                .foregroundColor(WatchTheme.Colors.dotRed)

            Text("Keep talking\nnaturally")
                .font(WatchTheme.Fonts.mono(9))
                .foregroundColor(WatchTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Helpers

    /// 0→1 as countdown goes from full to 0
    private var autoProgress: CGFloat {
        let total = CGFloat(15 * 60)
        let remaining = CGFloat(session.secondsUntilNextCapture)
        return remaining / total
    }

    private var countdownString: String {
        let s = session.secondsUntilNextCapture
        let m = s / 60
        let sec = s % 60
        return String(format: "%d:%02d", m, sec)
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
