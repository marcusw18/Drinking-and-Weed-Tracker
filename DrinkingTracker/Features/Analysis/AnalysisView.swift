import SwiftUI

struct AnalysisView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: AnalysisViewModel? = nil
    @State private var showSurvey = false
    @State private var showCamera = false
    @State private var isManual = true

    private var vm: AnalysisViewModel {
        viewModel ?? AnalysisViewModel(appState: appState)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if vm.isRunning {
                    runningView
                } else if vm.currentStep == .complete, let result = vm.result {
                    resultView(result)
                } else {
                    startView
                }
            }
            .padding()
            .navigationTitle("Analysis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showSurvey) {
                PreAnalysisSurveyView(survey: Binding(
                    get: { vm.survey },
                    set: { vm.survey = $0 }
                )) {
                    Task { await vm.runAnalysis(isManual: isManual) }
                }
            }
        }
        .onAppear { if viewModel == nil { viewModel = AnalysisViewModel(appState: appState) } }
    }

    // MARK: - Start

    private var startView: some View {
        VStack(spacing: 20) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 60))
                .foregroundStyle(.orange)

            Text("Run Analysis")
                .font(.title2.bold())

            Text("Combine voice, face, watch health data, and your BAC for an accurate intoxication assessment.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            VStack(spacing: 12) {
                Button {
                    isManual = true
                    showSurvey = true
                } label: {
                    Label("Manual Analysis", systemImage: "person.crop.circle.badge.questionmark")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Button {
                    isManual = false
                    Task { await vm.runAnalysis(isManual: false) }
                } label: {
                    Label("Quick Analysis (Watch Only)", systemImage: "applewatch")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .foregroundStyle(.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    // MARK: - Running

    private var runningView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text(vm.currentStep.rawValue)
                .font(.headline)
            Text("Please keep the app open and your watch nearby.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Result

    private func resultView(_ log: AnalysisLog) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                StageVisualView(stage: log.stage)

                if let summary = log.geminiSummary {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Gemini Summary", systemImage: "sparkles")
                            .font(.headline)
                        Text(summary)
                            .font(.body)
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                // Score breakdown
                VStack(spacing: 8) {
                    if let slur = log.slurScore {
                        ScoreRow(label: "Slur Score", value: slur, color: .orange)
                    }
                    if let blush = log.blushScore {
                        ScoreRow(label: "Facial Redness", value: blush, color: .red)
                    }
                    if let hr = log.heartRate {
                        LabeledContent("Heart Rate", value: "\(Int(hr)) bpm")
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                Button("Run Again") {
                    vm.reset()
                }
                .padding()
            }
        }
    }
}

struct ScoreRow: View {
    let label: String
    let value: Double
    let color: Color

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            ProgressView(value: value)
                .tint(color)
                .frame(width: 100)
            Text(String(format: "%.0f%%", value * 100))
                .font(.caption)
                .monospacedDigit()
                .frame(width: 36)
        }
    }
}
