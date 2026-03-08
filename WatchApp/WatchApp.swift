import SwiftUI
import FirebaseCore
import UserNotifications

@main
struct DrinkingTrackerWatchApp: App {

    private let watchState = WatchAppState.shared

    init() {
        FirebaseApp.configure()
        // Request notification permission for high-intoxication alerts
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
        // Activate WatchConnectivity immediately so auth context arrives ASAP
        _ = WatchSessionManagerWatch.shared
    }

    var body: some Scene {
        WindowGroup {
            WatchRootView()
                .environment(watchState)
        }
    }
}

// MARK: - Root View

struct WatchRootView: View {
    @Environment(WatchAppState.self) private var watchState

    var body: some View {
        if watchState.isLoggedIn {
            WatchDashboardView()
        } else {
            WatchLoginView()
        }
    }
}
