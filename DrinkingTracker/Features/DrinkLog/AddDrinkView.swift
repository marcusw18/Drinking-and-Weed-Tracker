import SwiftUI

struct AddDrinkView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: DrinkLogViewModel? = nil

    var body: some View {
        let vm = viewModel ?? DrinkLogViewModel(appState: appState)

        NavigationStack {
            Form {
                // Drink type picker
                Section("Drink Type") {
                    Picker("Type", selection: Binding(
                        get: { vm.alcoholType },
                        set: { vm.alcoholType = $0; vm.onTypeChanged() }
                    )) {
                        ForEach(AlcoholType.allCases, id: \.self) { type in
                            Label(type.rawValue.capitalized, systemImage: "cup.and.saucer")
                                .tag(type)
                        }
                    }
                    .pickerStyle(.wheel)
                }

                // Percentage
                Section("Alcohol Percentage") {
                    HStack {
                        Slider(value: Binding(get: { vm.percentage }, set: { vm.percentage = $0 }),
                               in: 0.5...80.0, step: 0.5)
                        Text(String(format: "%.1f%%", vm.percentage))
                            .monospacedDigit()
                            .frame(width: 50)
                    }
                }

                // Volume
                Section("Volume (mL)") {
                    HStack {
                        Slider(value: Binding(get: { vm.volumeMl }, set: { vm.volumeMl = $0 }),
                               in: 30...750, step: 10)
                        Text("\(Int(vm.volumeMl)) mL")
                            .monospacedDigit()
                            .frame(width: 70)
                    }
                }

                // Summary
                Section {
                    let grams = vm.volumeMl * (vm.percentage / 100.0) * 0.789
                    LabeledContent("Pure alcohol", value: String(format: "%.1f g", grams))
                    LabeledContent("Standard drinks", value: String(format: "%.1f", grams / 14.0))
                }

                if let error = vm.errorMessage {
                    Text(error).foregroundStyle(.red).font(.caption)
                }
            }
            .navigationTitle("Add Drink")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        Task {
                            await vm.addDrink()
                            if vm.errorMessage == nil { dismiss() }
                        }
                    }
                    .disabled(vm.isLoading)
                }
            }
        }
        .onAppear {
            if viewModel == nil { viewModel = vm }
        }
    }
}
