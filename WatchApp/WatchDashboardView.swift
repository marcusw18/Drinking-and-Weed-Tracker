import SwiftUI

struct WatchDashboardView: View {
    @StateObject private var sessionManager = WatchSessionManagerWatch.shared

    var body: some View {
        VStack(spacing: 8) {
            if sessionManager.isCapturing {
                capturingView
            } else {
                statusView
            }
        }
        .padding()
    }

    private var statusView: some View {
        VStack(spacing: 6) {
            Text(sessionManager.currentStageEmoji)
                .font(.system(size: 40))

            Text(sessionManager.currentStageLabel)
                .font(.headline)

            if sessionManager.currentBAC > 0 {
                Text(String(format: "BAC %.3f%%", sessionManager.currentBAC))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                Text("Session not active")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var capturingView: some View {
        VStack(spacing: 8) {
            ProgressView()
            Text("Capturing…")
                .font(.caption)
            Text("\(sessionManager.captureSecondsRemaining)s remaining")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}
