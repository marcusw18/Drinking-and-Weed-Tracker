import SwiftUI
import WatchKit

// MARK: - Watch Dashboard View
// Main container: two-page TabView (Status / Record) with high-intoxication alerts.

struct WatchDashboardView: View {
    @Environment(WatchAppState.self) private var watchState

    @State private var showStageAlert = false
    @State private var showDrinkAlert = false
    @State private var stageAlertMessage = ""
    @State private var drinkAlertMessage = ""

    var body: some View {
        TabView {
            WatchStatusView()
                .tag(0)
            WatchRecordView()
                .tag(1)
        }
        .tabViewStyle(.page)
        .background(WatchTheme.Colors.background)
        // Stage alert: fires when stage enters drunk or worse
        .alert("⚠️ High Intoxication", isPresented: $showStageAlert) {
            Button("OK") {}
        } message: {
            Text(stageAlertMessage)
        }
        // Drink count milestones
        .alert("🍺 Drink Alert", isPresented: $showDrinkAlert) {
            Button("OK") {}
        } message: {
            Text(drinkAlertMessage)
        }
        // Watch for stage escalation into drunk / very drunk / danger
        .onChange(of: watchState.currentStageRaw) { _, newRaw in
            guard newRaw >= 3, newRaw > watchState.lastAlertedStage else { return }
            watchState.lastAlertedStage = newRaw
            let stage = IntoxicationStageWatch(rawValue: newRaw) ?? .drunk
            stageAlertMessage = stageWarning(stage)
            showStageAlert = true
            WKInterfaceDevice.current().play(.notification)
        }
        // Watch for drink count milestones (every 5 drinks)
        .onChange(of: watchState.drinkCount) { _, count in
            let milestone = (count / 5) * 5
            guard milestone >= 5, milestone > watchState.lastAlertedDrinkMilestone else { return }
            watchState.lastAlertedDrinkMilestone = milestone
            drinkAlertMessage = "You've had \(count) drinks. Consider slowing down."
            showDrinkAlert = true
            WKInterfaceDevice.current().play(.notification)
        }
    }

    private func stageWarning(_ stage: IntoxicationStageWatch) -> String {
        switch stage {
        case .drunk:
            return "Drunk level detected. Stop drinking and drink water."
        case .veryDrunk:
            return "Very high intoxication. Get someone with you. Do NOT drive."
        case .danger:
            return "DANGER level. Seek a safe place immediately. Call someone."
        default:
            return "Your intoxication level has increased."
        }
    }
}
