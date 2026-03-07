import SwiftUI

struct DrinkHistoryView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    private var grouped: [(String, [DrinkLog])] {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        let dict = Dictionary(grouping: appState.drinkLogs) {
            formatter.string(from: $0.timestamp)
        }
        return dict.sorted { $0.key > $1.key }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(grouped, id: \.0) { date, logs in
                    Section(date) {
                        ForEach(logs) { log in
                            DrinkRowView(log: log)
                        }
                        .onDelete { offsets in
                            Task {
                                let vm = DrinkLogViewModel(appState: appState)
                                for index in offsets {
                                    await vm.deleteDrink(logs[index])
                                }
                            }
                        }
                    }
                }
            }
            .overlay {
                if appState.drinkLogs.isEmpty {
                    ContentUnavailableView("No drinks logged", systemImage: "wineglass", description: Text("Tap + to add your first drink."))
                }
            }
            .navigationTitle("Drink History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct DrinkRowView: View {
    let log: DrinkLog

    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        HStack {
            Text(log.alcoholType.icon)
                .font(.title2)
            VStack(alignment: .leading, spacing: 2) {
                Text(log.alcoholType.rawValue.capitalized)
                    .fontWeight(.medium)
                Text("\(Int(log.volumeMl)) mL · \(String(format: "%.1f", log.percentage))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(timeFormatter.string(from: log.timestamp))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(String(format: "%.1f g", log.gramsOfAlcohol))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
