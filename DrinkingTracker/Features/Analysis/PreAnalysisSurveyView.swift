import SwiftUI

struct PreAnalysisSurvey {
    var drinksInLastHour: Int = 0
    var ateFood: Bool = false
    var drinkingWater: Bool = false
    var feelingDizzy: Bool = false
    var canWalkStraight: Bool = true
}

struct PreAnalysisSurveyView: View {
    @Binding var survey: PreAnalysisSurvey
    let onContinue: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("In the last hour") {
                    Stepper("Drinks consumed: \(survey.drinksInLastHour)",
                            value: $survey.drinksInLastHour, in: 0...20)
                }

                Section("Current state") {
                    Toggle("Eaten food recently", isOn: $survey.ateFood)
                    Toggle("Drinking water", isOn: $survey.drinkingWater)
                    Toggle("Feeling dizzy", isOn: $survey.feelingDizzy)
                    Toggle("Can walk straight", isOn: $survey.canWalkStraight)
                }
            }
            .navigationTitle("Pre-Analysis Check")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Skip") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Continue") {
                        onContinue()
                        dismiss()
                    }
                }
            }
        }
    }
}
