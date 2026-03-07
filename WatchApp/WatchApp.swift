import SwiftUI
import FirebaseCore

@main
struct DrinkingTrackerWatchApp: App {

    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            WatchDashboardView()
        }
    }
}
