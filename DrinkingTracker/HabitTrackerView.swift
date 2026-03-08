import SwiftUI

struct HabitTrackerView: View {
    @Environment(AppState.self) private var appState
    @State private var currentMonth: Date = {
        let c = Calendar.current
        return c.date(from: c.dateComponents([.year, .month], from: Date())) ?? Date()
    }()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                Text("Habit Tracker")
                    .font(AppTheme.Fonts.title(38))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .padding(.top, 16)
                    .padding(.horizontal, 20)

                HabitCalendarCard(currentMonth: $currentMonth, drinkLogs: appState.drinkLogs)
                    .padding(.horizontal, 16)
                    .padding(.top, 20)

                Button {} label: {
                    HStack {
                        Text("Weekly Average")
                            .font(AppTheme.Fonts.mono(14))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, minHeight: 100, alignment: .topLeading)
                    .background(AppTheme.Colors.cardBackground)
                    .cornerRadius(AppTheme.Radius.card)
                    .cardShadow()
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)

                Spacer(minLength: 100)
            }
        }
    }
}

// MARK: - Habit Calendar Card

struct HabitCalendarCard: View {
    @Binding var currentMonth: Date
    let drinkLogs: [DrinkLog]

    private let calendar = Calendar.current
    private let columns  = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
    private let weekdays = ["S", "M", "T", "W", "T", "F", "S"]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(monthYearName)
                    .font(AppTheme.Fonts.mono(16, weight: .regular))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.top, 16)
            .padding(.bottom, 10)

            HStack(spacing: 0) {
                ForEach(Array(weekdays.enumerated()), id: \.offset) { _, d in
                    Text(d)
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
            .padding(.bottom, 16)
        }
        .background(AppTheme.Colors.cardBackground)
        .cornerRadius(AppTheme.Radius.card)
        .cardShadow()
    }

    private var monthYearName: String {
        let f = DateFormatter(); f.dateFormat = "MMMM yyyy"
        return f.string(from: currentMonth)
    }
    private var firstWeekdayOffset: Int {
        let c = calendar.dateComponents([.year, .month], from: currentMonth)
        return calendar.component(.weekday, from: calendar.date(from: c)!) - 1
    }
    private var daysInMonth: Int { calendar.range(of: .day, in: .month, for: currentMonth)!.count }

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

#Preview { HabitTrackerView().environment(AppState()) }
