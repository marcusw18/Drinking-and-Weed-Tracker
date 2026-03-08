import SwiftUI

// MARK: - Session View

struct SessionView: View {
    @Environment(AppState.self) private var appState
    @State private var now: Date = Date()
    @State private var selectedMood: Int = 0

    private let displayTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private let drinkTypes: [(icon: String, label: String, type: AlcoholType)] = [
        ("mug.fill",       "Beer",     .beer),
        ("wineglass",      "Wine",     .wine),
        ("martini.glass",  "Cocktail", .cocktail),
        ("drop.fill",      "Spirits",  .spirits)
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

                // MARK: Current Stage Description
                VStack(alignment: .leading, spacing: 14) {
                    // Stage label + description
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(appState.currentStage.label)
                                .font(AppTheme.Fonts.mono(13, weight: .semibold))
                                .foregroundColor(AppTheme.Colors.textPrimary)
                            Spacer()
                            Text(appState.currentStage.emoji)
                                .font(.system(size: 20))
                        }
                        ForEach(appState.currentStage.recommendations, id: \.self) { rec in
                            Text("· \(rec)")
                                .font(AppTheme.Fonts.mono(12))
                                .foregroundColor(AppTheme.Colors.textSecondary)
                        }
                    }

                    Divider().background(AppTheme.Colors.divider)

                    // How do you feel? — 5 stages
                    Text("How do you feel?")
                        .font(AppTheme.Fonts.mono(12))
                        .foregroundColor(AppTheme.Colors.textSecondary)

                    HStack(spacing: 0) {
                        ForEach(0..<5) { index in
                            Button { selectedMood = index } label: {
                                moodIcon(for: index)
                                    .font(.system(size: 28))
                                    .foregroundColor(selectedMood == index
                                        ? moodColor(for: index)
                                        : AppTheme.Colors.textTertiary)
                                    .overlay(
                                        Circle()
                                            .stroke(selectedMood == index
                                                ? moodColor(for: index)
                                                : Color.clear, lineWidth: 2.5)
                                            .frame(width: 44, height: 44)
                                    )
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 4)
                            }
                        }
                    }
                }
                .padding(16)
                .background(AppTheme.Colors.cardBackground)
                .cornerRadius(AppTheme.Radius.card)
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

    // Maps to: sober, relaxed, tipsy, drunk, veryDrunk
    @ViewBuilder
    private func moodIcon(for index: Int) -> some View {
        switch index {
        case 0:  Image(systemName: "face.smiling.inverse")  // sober
        case 1:  Image(systemName: "face.smiling")          // relaxed
        case 2:  Image(systemName: "face.expressionless")   // tipsy
        case 3:  Image(systemName: "face.dizzy")            // drunk
        default: Image(systemName: "face.dizzy.fill")       // very drunk
        }
    }

    // Green → yellow → orange → red as stages worsen
    private func moodColor(for index: Int) -> Color {
        switch index {
        case 0:  return AppTheme.Colors.dotGreen
        case 1:  return AppTheme.Colors.dotTeal
        case 2:  return AppTheme.Colors.dotYellow
        case 3:  return Color.orange
        default: return AppTheme.Colors.dotRed
        }
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
