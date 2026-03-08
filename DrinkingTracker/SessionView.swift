import SwiftUI

// MARK: - Session View

struct SessionView: View {
    @Environment(AppState.self) private var appState
    @State private var now: Date = Date()

    private let displayTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private let drinkTypes: [(icon: String, label: String, type: AlcoholType)] = [
        ("mug.fill",      "Beer",     .beer),
        ("wineglass",     "Wine",     .wine),
        ("wineglass.fill","Cocktail", .cocktail),
        ("drop.fill",     "Spirits",  .spirits)
    ]

    private var sessionDrinks: [DrinkLog] {
        guard let start = appState.sessionStartTime else { return [] }
        return appState.drinkLogs.filter { $0.timestamp >= start }
    }

    private var elapsedSeconds: Int {
        guard let start = appState.sessionStartTime else { return 0 }
        return max(0, Int(now.timeIntervalSince(start)))
    }

    private var timeString: String {
        let h = elapsedSeconds / 3600
        let m = (elapsedSeconds % 3600) / 60
        let s = elapsedSeconds % 60
        return String(format: "%02dh : %02dm : %02ds", h, m, s)
    }

    // Maps stage index (0-4) to the five display stages
    private let displayStages: [IntoxicationStage] = [
        .sober, .relaxed, .tipsy, .drunk, .veryDrunk
    ]

    // Highlighted index — clamp .danger to index 4
    private var activeStageIndex: Int {
        min(appState.currentStage.rawValue, 4)
    }

    var body: some View {
        @Bindable var state = appState
        return ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // MARK: Title + Timer
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text("Session")
                        .font(AppTheme.Fonts.title(34))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    Text(timeString)
                        .font(AppTheme.Fonts.mono(13))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
                .padding(.top, 16)
                .padding(.horizontal, 20)

                // MARK: Drink Counter
                SectionHeader(title: "Drink Counter", onPlus: { state.showAddDrink = true })
                    .padding(.top, 20)
                    .padding(.horizontal, 20)

                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("Total : \(sessionDrinks.count) Drinks")
                            .font(AppTheme.Fonts.mono(13))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        Spacer()
                        Image(systemName: "slider.horizontal.3")
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }

                    HStack(spacing: 0) {
                        ForEach(drinkTypes, id: \.label) { item in
                            Button { state.showAddDrink = true } label: {
                                VStack(spacing: 6) {
                                    Image(systemName: item.icon)
                                        .font(.system(size: 22))
                                        .foregroundColor(AppTheme.Colors.textSecondary)
                                        .frame(width: 54, height: 54)
                                        .background(AppTheme.Colors.inputBackground)
                                        .clipShape(Circle())
                                    Text(item.label)
                                        .font(AppTheme.Fonts.mono(10))
                                        .foregroundColor(AppTheme.Colors.textSecondary)
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                    }
                }
                .padding(16)
                .background(AppTheme.Colors.cardBackground)
                .cornerRadius(AppTheme.Radius.card)
                .cardShadow()
                .padding(.horizontal, 16)
                .padding(.top, 10)

                // MARK: Current Stage — system determined
                VStack(alignment: .leading, spacing: 14) {

                    // Stage label + description (auto-updates from appState.currentStage)
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(appState.currentStage.label)
                                .font(AppTheme.Fonts.mono(15, weight: .semibold))
                                .foregroundColor(AppTheme.Colors.textPrimary)
                            Text("BAC \(String(format: "%.3f", appState.currentBAC))%")
                                .font(AppTheme.Fonts.mono(11))
                                .foregroundColor(AppTheme.Colors.textSecondary)
                        }
                        Spacer()
                        Text(appState.currentStage.emoji)
                            .font(.system(size: 32))
                    }

                    // Stage-specific recommendations
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(appState.currentStage.recommendations, id: \.self) { rec in
                            HStack(alignment: .top, spacing: 6) {
                                Circle()
                                    .fill(appState.currentStage.color)
                                    .frame(width: 5, height: 5)
                                    .padding(.top, 5)
                                Text(rec)
                                    .font(AppTheme.Fonts.mono(12))
                                    .foregroundColor(AppTheme.Colors.textSecondary)
                            }
                        }
                    }

                    Divider().background(AppTheme.Colors.divider)

                    // Intoxication level row — read-only, system determined
                    Text("Intoxication Level")
                        .font(AppTheme.Fonts.mono(11))
                        .foregroundColor(AppTheme.Colors.textSecondary)

                    HStack(spacing: 0) {
                        ForEach(Array(displayStages.enumerated()), id: \.offset) { index, stage in
                            let isActive = index == activeStageIndex
                            VStack(spacing: 4) {
                                Text(stage.emoji)
                                    .font(.system(size: 26))
                                    .opacity(isActive ? 1.0 : 0.25)
                                    .overlay(
                                        Circle()
                                            .stroke(isActive ? stage.color : Color.clear, lineWidth: 2.5)
                                            .frame(width: 44, height: 44)
                                    )
                                    .scaleEffect(isActive ? 1.1 : 1.0)
                                    .animation(.spring(response: 0.3), value: activeStageIndex)

                                Circle()
                                    .fill(isActive ? stage.color : Color.clear)
                                    .frame(width: 4, height: 4)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
                .padding(16)
                .background(AppTheme.Colors.cardBackground)
                .cornerRadius(AppTheme.Radius.card)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.Radius.card)
                        .stroke(appState.currentStage.color.opacity(0.4), lineWidth: 1.5)
                )
                .cardShadow()
                .padding(.horizontal, 16)
                .padding(.top, 12)

                // MARK: Health
                SectionHeader(title: "Health", showPlus: false, showSettings: true)
                    .padding(.top, 20)
                    .padding(.horizontal, 20)

                HStack(spacing: 12) {
                    HealthMetricCard(
                        title: "Heart Rate",
                        value: appState.latestHeartRate.map { String(Int($0)) } ?? "--",
                        unit: "bpm",
                        icon: "heart.fill",
                        iconColor: AppTheme.Colors.dotRed
                    )
                    HealthMetricCard(
                        title: "BAC",
                        value: String(format: "%.3f", appState.currentBAC),
                        unit: "%",
                        icon: "drop.fill",
                        iconColor: AppTheme.Colors.dotTeal
                    )
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)

                Spacer(minLength: 140)
            }
        }
        .onReceive(displayTimer) { now = $0 }
        .sheet(isPresented: $state.showAddDrink) { AddDrinkView() }
    }
}

// MARK: - Health Metric Card

struct HealthMetricCard: View {
    let title: String
    let value: String
    let unit: String
    let icon: String
    let iconColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(AppTheme.Fonts.mono(12))
                .foregroundColor(AppTheme.Colors.textSecondary)
            Spacer()
            Text(value)
                .font(AppTheme.Fonts.mono(36, weight: .regular))
                .foregroundColor(AppTheme.Colors.textPrimary)
            Text(unit)
                .font(AppTheme.Fonts.mono(13))
                .foregroundColor(AppTheme.Colors.textSecondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .leading)
        .background(AppTheme.Colors.cardBackground)
        .cornerRadius(AppTheme.Radius.card)
        .cardShadow()
    }
}

#Preview { SessionView().environment(AppState()) }
