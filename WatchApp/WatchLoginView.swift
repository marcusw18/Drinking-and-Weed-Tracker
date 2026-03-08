import SwiftUI

// MARK: - Watch Login View
// Shown when the watch hasn't yet received auth context from the iPhone.
// Auth is synced automatically when user logs in on the iPhone app.

struct WatchLoginView: View {
    @StateObject private var session = WatchSessionManagerWatch.shared

    var body: some View {
        ZStack {
            WatchTheme.Colors.background.ignoresSafeArea()

            VStack(spacing: 10) {
                // App icon area
                ZStack {
                    Circle()
                        .fill(WatchTheme.Colors.card)
                        .frame(width: 44, height: 44)
                    Text("🍺")
                        .font(.system(size: 22))
                }

                Text("TRACKER")
                    .font(WatchTheme.Fonts.mono(14, weight: .bold))
                    .foregroundColor(WatchTheme.Colors.textPrimary)

                Rectangle()
                    .fill(WatchTheme.Colors.divider)
                    .frame(height: 0.5)
                    .padding(.horizontal, 20)

                Text("Open iPhone app\nto sign in")
                    .font(WatchTheme.Fonts.mono(11))
                    .foregroundColor(WatchTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)

                // Pulsing dot indicating waiting for iPhone
                WaitingDot()
                    .padding(.top, 4)
            }
            .padding()
        }
    }
}

// MARK: - Waiting Dot Animation

private struct WaitingDot: View {
    @State private var opacity: Double = 1.0

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(WatchTheme.Colors.dotGreen)
                    .frame(width: 4, height: 4)
                    .opacity(opacity)
                    .animation(
                        .easeInOut(duration: 0.6)
                            .repeatForever()
                            .delay(Double(i) * 0.2),
                        value: opacity
                    )
            }
        }
        .onAppear { opacity = 0.2 }
    }
}
