import SwiftUI
import FirebaseAuth

// MARK: - Main Tab Container

struct DashboardView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedTab: Int = 0
    @State private var currentMonth: Date = {
        let c = Calendar.current
        return c.date(from: c.dateComponents([.year, .month], from: Date())) ?? Date()
    }()
    @State private var autoTimer = AutoAnalysisTimer(interval: 15 * 60)
    @State private var bacRefreshTimer: Timer? = nil

    var body: some View {
        @Bindable var state = appState
        return ZStack(alignment: .bottom) {
            AppTheme.Colors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // MARK: Tab Content
                Group {
                    switch selectedTab {
                    case 0: homeTab
                    case 1: SessionView()
                    case 2: HabitTrackerView()
                    case 3: GeminiChatView()
                    case 4: ScanView()
                    default: homeTab
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // MARK: Bottom Bar (changes per tab)
                VStack(spacing: 0) {
                    switch selectedTab {
                    case 0:
                        Button {
                            appState.startSession()
                            autoTimer.start()
                            selectedTab = 1
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "martini.glass").font(.system(size: 18))
                                Text("Start Drinking").font(AppTheme.Fonts.mono(17, weight: .semibold))
                            }
                            .foregroundColor(AppTheme.Colors.accentWhite)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(AppTheme.Colors.accentBlack)
                            .cornerRadius(AppTheme.Radius.button)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 12)
                        .background(AppTheme.Colors.background)

                    case 1:
                        VStack(spacing: 10) {
                            Button { selectedTab = 4 } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "camera").font(.system(size: 18))
                                    Text("Scan").font(AppTheme.Fonts.mono(17, weight: .semibold))
                                }
                                .foregroundColor(AppTheme.Colors.accentWhite)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 18)
                                .background(AppTheme.Colors.accentBlack)
                                .cornerRadius(AppTheme.Radius.button)
                            }
                            Button {
                                appState.endSession()
                                autoTimer.stop()
                                selectedTab = 0
                            } label: {
                                Text("Stop Session")
                                    .font(AppTheme.Fonts.mono(14))
                                    .foregroundColor(AppTheme.Colors.textSecondary)
                            }
                            .padding(.bottom, 4)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        .padding(.bottom, 8)
                        .background(AppTheme.Colors.background)

                    case 4:
                        VStack(spacing: 12) {
                            Button { state.showAnalysis = true } label: {
                                Text("Scan")
                                    .font(AppTheme.Fonts.mono(17, weight: .semibold))
                                    .foregroundColor(AppTheme.Colors.accentWhite)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 18)
                                    .background(AppTheme.Colors.accentBlack)
                                    .cornerRadius(AppTheme.Radius.button)
                            }
                            Button { selectedTab = 1 } label: {
                                Text("Go Back")
                                    .font(AppTheme.Fonts.mono(14))
                                    .foregroundColor(AppTheme.Colors.textSecondary)
                            }
                            .padding(.bottom, 4)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        .padding(.bottom, 8)
                        .background(AppTheme.Colors.background)

                    default:
                        EmptyView()
                    }

                    CustomTabBar(selectedTab: $selectedTab)
                }
            }
        }
        .ignoresSafeArea(edges: .bottom)
        // Sheets at root so any tab can trigger them
        .sheet(isPresented: $state.showAddDrink) { AddDrinkView() }
        .sheet(isPresented: $state.showHistory)  { DrinkHistoryView() }
        .sheet(isPresented: $state.showAnalysis) { AnalysisView() }
        .sheet(isPresented: $state.showChatbot)  { GeminiChatView() }
        .onAppear {
            setupTimers()
            Task { await loadInitialData() }
        }
        .onDisappear {
            bacRefreshTimer?.invalidate()
            autoTimer.stop()
        }
    }

    // MARK: - Home Tab

    private var homeTab: some View {
        @Bindable var state = appState
        return ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Dashboard")
                        .font(AppTheme.Fonts.title(38))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    Spacer()
                    Menu {
                        Button("Sign Out", role: .destructive) {
                            try? Auth.auth().signOut()
                        }
                    } label: {
                        Image(systemName: "person.circle")
                            .font(.system(size: 22))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                }
                .padding(.top, 16)
                .padding(.horizontal, 20)

                SectionHeader(title: "Calendar View", onPlus: { state.showAddDrink = true })
                    .padding(.top, 24)
                    .padding(.horizontal, 20)

                CalendarCard(currentMonth: $currentMonth, drinkLogs: appState.drinkLogs)
                    .padding(.horizontal, 16)
                    .padding(.top, 10)

                SectionHeader(title: "AI Summary", showPlus: false)
                    .padding(.top, 24)
                    .padding(.horizontal, 20)

                AISummaryCard(summary: appState.analysisLogs.last?.geminiSummary)
                    .padding(.horizontal, 16)
                    .padding(.top, 10)

                Spacer(minLength: 140)
            }
        }
    }

    // MARK: - Data Loading

    private func setupTimers() {
        bacRefreshTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            appState.refreshBAC()
        }
        autoTimer.onFire = { appState.showAnalysis = true }
        if appState.isSessionActive { autoTimer.start() }
    }

    private func loadInitialData() async {
        guard !appState.userId.isEmpty else { return }
        async let profile = try? SupabaseService.shared.fetchProfile(userId: appState.userId)
        async let logs   = try? SupabaseService.shared.fetchDrinkLogs(userId: appState.userId)
        let (p, l) = await (profile, logs)
        if let p { appState.userProfile = p }
        if let l { appState.drinkLogs   = l }
        appState.refreshBAC()
        await HealthKitService.shared.refreshAll()
        appState.latestHeartRate = HealthKitService.shared.latestHeartRate
        appState.latestHRV       = HealthKitService.shared.latestHRV
        appState.latestSpO2      = HealthKitService.shared.latestSpO2
    }
}

// MARK: - Section Header

struct SectionHeader: View {
    let title: String
    var showPlus: Bool = true
    var onPlus: () -> Void = {}
    var showSettings: Bool = false
    var onSettings: () -> Void = {}

    var body: some View {
        HStack {
            Text(title)
                .font(AppTheme.Fonts.mono(15))
                .foregroundColor(AppTheme.Colors.textPrimary)

            Rectangle()
                .fill(AppTheme.Colors.divider)
                .frame(height: 0.8)
                .padding(.leading, 8)

            if showPlus {
                Button(action: onPlus) {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
                .padding(.leading, 4)
            }

            if showSettings {
                Button(action: onSettings) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 14))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
                .padding(.leading, 4)
            }
        }
    }
}

// MARK: - Calendar Card

struct CalendarCard: View {
    @Binding var currentMonth: Date
    let drinkLogs: [DrinkLog]

    private let calendar = Calendar.current
    private let columns  = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
    private let weekdays = ["S", "M", "T", "W", "T", "F", "S"]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(monthName)
                    .font(AppTheme.Fonts.mono(15))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                Spacer()
                HStack(spacing: 16) {
                    Button { changeMonth(-1) } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                    Button { changeMonth(1) } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 10)

            HStack(spacing: 0) {
                ForEach(Array(weekdays.enumerated()), id: \.offset) { _, day in
                    Text(day)
                        .font(AppTheme.Fonts.mono(11))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 6)

            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(0..<firstWeekdayOffset, id: \.self) { _ in Color.clear.frame(height: 36) }
                ForEach(1...daysInMonth, id: \.self) { day in
                    DayCell(day: day, dotColor: dotColor(for: day))
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 14)
        }
        .background(AppTheme.Colors.cardBackground)
        .cornerRadius(AppTheme.Radius.card)
        .cardShadow()
    }

    private var monthName: String {
        let f = DateFormatter(); f.dateFormat = "MMMM yyyy"
        return f.string(from: currentMonth)
    }
    private var firstWeekdayOffset: Int {
        let c = calendar.dateComponents([.year, .month], from: currentMonth)
        return calendar.component(.weekday, from: calendar.date(from: c)!) - 1
    }
    private var daysInMonth: Int { calendar.range(of: .day, in: .month, for: currentMonth)!.count }
    private func changeMonth(_ delta: Int) {
        if let d = calendar.date(byAdding: .month, value: delta, to: currentMonth) { currentMonth = d }
    }
    private func dotColor(for day: Int) -> Color? {
        let c = calendar.dateComponents([.year, .month], from: currentMonth)
        guard let first = calendar.date(from: c),
              let target = calendar.date(byAdding: .day, value: day - 1, to: first) else { return nil }
        let count = drinkLogs.filter { calendar.isDate($0.timestamp, inSameDayAs: target) }.count
        switch count {
        case 0:     return nil
        case 1...2: return AppTheme.Colors.dotGreen
        case 3...4: return AppTheme.Colors.dotYellow
        default:    return AppTheme.Colors.dotRed
        }
    }
}

// MARK: - Day Cell

struct DayCell: View {
    let day: Int
    let dotColor: Color?

    var body: some View {
        ZStack {
            if let color = dotColor { Circle().fill(color).frame(width: 32, height: 32) }
            Text("\(day)")
                .font(AppTheme.Fonts.mono(13))
                .foregroundColor(AppTheme.Colors.textPrimary)
        }
        .frame(height: 36)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - AI Summary Card

struct AISummaryCard: View {
    let summary: String?

    var body: some View {
        HStack(alignment: .top) {
            Text(summary ?? "Run an analysis to see your AI summary here.")
                .font(AppTheme.Fonts.mono(14))
                .foregroundColor(summary != nil ? AppTheme.Colors.textPrimary : AppTheme.Colors.textTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "cpu")
                .font(.system(size: 20))
                .foregroundColor(AppTheme.Colors.textSecondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 160, alignment: .topLeading)
        .background(AppTheme.Colors.cardBackground)
        .cornerRadius(AppTheme.Radius.card)
        .cardShadow()
    }
}

// MARK: - Custom Tab Bar

struct CustomTabBar: View {
    @Binding var selectedTab: Int

    private let tabs: [(icon: String, index: Int)] = [
        ("house",         0),
        ("martini.glass", 1),
        ("calendar",      2),
        ("bubble.left",   3),
        ("camera",        4)
    ]

    var body: some View {
        HStack {
            ForEach(tabs, id: \.index) { tab in
                Spacer()
                Button { selectedTab = tab.index } label: {
                    Image(systemName: tab.icon)
                        .font(.system(size: 22))
                        .foregroundColor(selectedTab == tab.index
                            ? AppTheme.Colors.tabActive
                            : AppTheme.Colors.tabInactive)
                }
                Spacer()
            }
        }
        .padding(.top, 10)
        .padding(.bottom, 28)
        .background(AppTheme.Colors.background)
    }
}

#Preview { DashboardView().environment(AppState()) }
