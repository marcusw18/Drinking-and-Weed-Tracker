import SwiftUI
import FirebaseAuth

struct DashboardView: View {
    @Environment(AppState.self) private var appState
    @State private var autoTimer = AutoAnalysisTimer(interval: 15 * 60)
    @State private var bacRefreshTimer: Timer? = nil

    var body: some View {
        @Bindable var state = appState
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {

                    // Stage Visual
                    StageVisualView(stage: appState.currentStage)

                    // BAC Gauge
                    BACGaugeView(bac: appState.currentBAC, stage: appState.currentStage)

                    // Health Metrics
                    HealthMetricsView(
                        heartRate: appState.latestHeartRate,
                        hrv: appState.latestHRV,
                        spo2: appState.latestSpO2
                    )

                    // Action Buttons
                    actionButtons
                }
                .padding()
            }
            .background(Color(.systemBackground))
            .navigationTitle("Drinking Tracker")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Sign Out", role: .destructive) {
                            try? Auth.auth().signOut()
                        }
                    } label: {
                        Image(systemName: "person.circle")
                    }
                }
            }
            .sheet(isPresented: $state.showAddDrink) {
                AddDrinkView()
            }
            .sheet(isPresented: $state.showHistory) {
                DrinkHistoryView()
            }
            .sheet(isPresented: $state.showAnalysis) {
                AnalysisView()
            }
            .sheet(isPresented: $state.showChatbot) {
                GeminiChatView()
            }
        }
        .onAppear {
            setupTimers()
            Task { await loadInitialData() }
        }
        .onDisappear {
            bacRefreshTimer?.invalidate()
            autoTimer.stop()
        }
    }

    // MARK: - Action Buttons

    @ViewBuilder
    private var actionButtons: some View {
        VStack(spacing: 12) {
            // Start / Stop Session
            Button {
                if appState.isSessionActive {
                    appState.endSession()
                    autoTimer.stop()
                } else {
                    appState.startSession()
                    autoTimer.start()
                }
            } label: {
                Label(
                    appState.isSessionActive ? "Stop Session" : "Start Drinking",
                    systemImage: appState.isSessionActive ? "stop.circle" : "play.circle"
                )
                .frame(maxWidth: .infinity)
                .padding()
                .background(appState.isSessionActive ? Color.red : Color.green)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .fontWeight(.semibold)
            }

            HStack(spacing: 12) {
                // Add Drink
                DashboardButton(icon: "plus.circle", label: "Add Drink", color: .blue) {
                    appState.showAddDrink = true
                }
                // Logs
                DashboardButton(icon: "list.bullet", label: "Logs", color: .indigo) {
                    appState.showHistory = true
                }
                // Analysis
                DashboardButton(icon: "chart.bar", label: "Analyse", color: .orange) {
                    appState.showAnalysis = true
                }
                // Chatbot
                DashboardButton(icon: "bubble.left.and.bubble.right", label: "Chat", color: .purple) {
                    appState.showChatbot = true
                }
            }
        }
    }

    // MARK: - Setup

    private func setupTimers() {
        // Refresh BAC every 60 seconds
        bacRefreshTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            appState.refreshBAC()
        }

        // Auto-analysis every 15 min when session active
        autoTimer.onFire = {
            appState.showAnalysis = true
        }
        if appState.isSessionActive { autoTimer.start() }
    }

    private func loadInitialData() async {
        guard !appState.userId.isEmpty else { return }
        async let profile = try? SupabaseService.shared.fetchProfile(userId: appState.userId)
        async let logs = try? SupabaseService.shared.fetchDrinkLogs(userId: appState.userId)
        let (p, l) = await (profile, logs)
        if let p { appState.userProfile = p }
        if let l { appState.drinkLogs = l }
        appState.refreshBAC()
        await HealthKitService.shared.refreshAll()
        appState.latestHeartRate = HealthKitService.shared.latestHeartRate
        appState.latestHRV = HealthKitService.shared.latestHRV
        appState.latestSpO2 = HealthKitService.shared.latestSpO2
    }
}

// MARK: - Small helper button

struct DashboardButton: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title2)
                Text(label)
                    .font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}
