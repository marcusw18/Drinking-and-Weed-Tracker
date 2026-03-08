import SwiftUI
import FirebaseCore
import AVFoundation
import SmartSpectraSwiftSDK

@main
struct DrinkingTrackerApp: App {

    @State private var appState = AppState()

    init() {
        FirebaseApp.configure()
        // Configure SmartSpectra once at launch so SmartSpectraView() is ready when shown.
        // Do NOT call setImageOutputEnabled or startProcessing — SmartSpectraView() owns the
        // camera session and manages the internal VitalsProcessor itself.
        let sdk = SmartSpectraSwiftSDK.shared
        sdk.setApiKey(Config.smartSpectraAPIKey)
        sdk.setSmartSpectraMode(.continuous)
        sdk.setCameraPosition(AVCaptureDevice.Position.front)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
        }
    }
}

struct RootView: View {
    @Environment(AppState.self) private var appState
    @State private var authStateListenerSet = false

    var body: some View {
        Group {
            if appState.isLoggedIn {
                DashboardView()
            } else {
                LoginView()
            }
        }
        .onAppear {
            guard !authStateListenerSet else { return }
            authStateListenerSet = true
            // Listen for Firebase auth changes
            _ = FirebaseAuth.Auth.auth().addStateDidChangeListener { _, user in
                appState.firebaseUser = user
            }
        }
    }
}
