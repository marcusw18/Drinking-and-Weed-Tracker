import Foundation

@Observable
final class DrinkLogViewModel {

    @ObservationIgnored private let appState: AppState

    var alcoholType: AlcoholType = .beer
    var percentage: Double = 5.0
    var volumeMl: Double = 355
    var isLoading = false
    var errorMessage: String? = nil

    init(appState: AppState) {
        self.appState = appState
    }

    func onTypeChanged() {
        percentage = alcoholType.defaultPercentage
        volumeMl = alcoholType.defaultVolumeMl
    }

    func addDrink() async {
        guard !appState.userId.isEmpty else { return }
        isLoading = true
        errorMessage = nil

        let log = DrinkLog(
            userId: appState.userId,
            alcoholType: alcoholType,
            percentage: percentage,
            volumeMl: volumeMl
        )

        do {
            try await SupabaseService.shared.insertDrinkLog(log)
            appState.drinkLogs.insert(log, at: 0)
            appState.refreshBAC()
        } catch {
            errorMessage = "Failed to save drink: \(error.localizedDescription)"
        }

        isLoading = false
    }

    func deleteDrink(_ log: DrinkLog) async {
        do {
            try await SupabaseService.shared.deleteDrinkLog(id: log.id)
            appState.drinkLogs.removeAll { $0.id == log.id }
            appState.refreshBAC()
        } catch {
            // Silently handle; could add error UI
        }
    }
}
