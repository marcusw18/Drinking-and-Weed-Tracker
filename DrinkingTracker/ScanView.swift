import SwiftUI
import AVFoundation
import Combine
import SmartSpectraSwiftSDK

// MARK: - Scan View

struct ScanView: View {
    @Environment(AppState.self) private var appState
    @StateObject private var smartSpectra = SmartSpectraManager()
    @State private var results = ScanResults()
    @State private var isScanning = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // MARK: Title
                VStack(alignment: .leading, spacing: 6) {
                    Text("Scan")
                        .font(AppTheme.Fonts.title(38))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    Rectangle()
                        .fill(AppTheme.Colors.divider)
                        .frame(width: 60, height: 1)
                }
                .padding(.top, 16)
                .padding(.horizontal, 20)

                Text("Hold still — keep your face centered")
                    .font(AppTheme.Fonts.mono(13))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .padding(.top, 8)
                    .padding(.horizontal, 20)

                // MARK: Camera / SmartSpectra Viewfinder
                ZStack {
                    RoundedRectangle(cornerRadius: AppTheme.Radius.card)
                        .fill(Color.black)

                    // SmartSpectraView handles camera, PPG measurement, and session lifecycle
                    SmartSpectraView()
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.card))

                    // Face silhouette overlay
                    FaceSilhouette()
                        .stroke(Color.white.opacity(isScanning ? 0.3 : 0.7), lineWidth: 2)
                        .frame(width: 180, height: 220)
                        .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true),
                                   value: isScanning)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 420)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.Radius.card)
                        .stroke(isScanning ? AppTheme.Colors.dotGreen : AppTheme.Colors.divider,
                                lineWidth: isScanning ? 2 : 1)
                )
                .padding(.horizontal, 16)
                .padding(.top, 20)

                // MARK: Results
                if hasAnyResult {
                    SectionHeader(title: "Results", showPlus: false)
                        .padding(.top, 24)
                        .padding(.horizontal, 20)

                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            ScanMetricCard(
                                icon: "heart.fill",
                                iconColor: AppTheme.Colors.dotRed,
                                title: "Heart Rate",
                                value: results.heartRate.map { String(format: "%.0f bpm", $0) } ?? "--"
                            )
                            ScanMetricCard(
                                icon: "brain.head.profile",
                                iconColor: AppTheme.Colors.dotTeal,
                                title: "Focus",
                                value: results.focusScore.map { focusLabel($0) } ?? "--"
                            )
                        }
                        HStack(spacing: 12) {
                            ScanMetricCard(
                                icon: "eye.fill",
                                iconColor: AppTheme.Colors.dotRed,
                                title: "Red Eyes",
                                value: results.redEyeScore.map { severityLabel($0) } ?? "--"
                            )
                            ScanMetricCard(
                                icon: "eye.slash",
                                iconColor: AppTheme.Colors.dotYellow,
                                title: "Droopy Eyelids",
                                value: results.droopyEyelidScore.map { severityLabel($0) } ?? "--"
                            )
                        }
                        ScanMetricCard(
                            icon: "face.smiling",
                            iconColor: AppTheme.Colors.dotRed,
                            title: "Flushed Face",
                            value: results.flushFaceScore.map { severityLabel($0) } ?? "--"
                        )
                        .padding(.horizontal, 0)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                }

                Spacer(minLength: 140)
            }
        }
        .onAppear {
            isScanning = true
        }
        .onDisappear {
            isScanning = false
            smartSpectra.cancelSubscriptions()
        }
        // Heart rate from SmartSpectra PPG
        .onReceive(smartSpectra.$heartRate) { bpm in
            guard let bpm else { return }
            results.heartRate = bpm
            appState.latestHeartRate = bpm
            pushResultsToAppState()
        }
        // Focus derived from HRV
        .onReceive(smartSpectra.$focusScore) { score in
            guard let score else { return }
            results.focusScore = score
            pushResultsToAppState()
        }
        // Camera frames for Vision face analysis
        .onReceive(smartSpectra.$latestFrame) { frame in
            guard let frame else { return }
            runVisionAnalysis(on: frame)
        }
    }

    // MARK: - Vision Analysis

    private func runVisionAnalysis(on image: UIImage) {
        Task {
            guard let result = try? await FaceAnalyzer.analyze(image: image) else { return }
            await MainActor.run {
                results.redEyeScore       = result.redEyeScore
                results.droopyEyelidScore = 1.0 - result.eyeOpennessScore
                results.flushFaceScore    = result.blushScore
                pushResultsToAppState()
            }
        }
    }

    private func pushResultsToAppState() {
        appState.lastScanResults = results
        appState.refreshBAC()
    }

    // MARK: - Helpers

    private var hasAnyResult: Bool {
        results.heartRate != nil || results.focusScore != nil ||
        results.redEyeScore != nil || results.flushFaceScore != nil
    }

    private func severityLabel(_ score: Double) -> String {
        switch score {
        case ..<0.25: return "None"
        case ..<0.50: return "Mild"
        case ..<0.75: return "Moderate"
        default:      return "High"
        }
    }

    private func focusLabel(_ score: Double) -> String {
        switch score {
        case ..<0.25: return "Poor"
        case ..<0.50: return "Low"
        case ..<0.75: return "Fair"
        default:      return "Good"
        }
    }
}

// MARK: - SmartSpectra Manager

/// Observes SmartSpectraSwiftSDK.shared and SmartSpectraVitalsProcessor.shared.
/// SmartSpectraView() owns the session lifecycle — this class only subscribes to published values.
@MainActor
final class SmartSpectraManager: ObservableObject {
    @Published var heartRate: Double? = nil
    @Published var focusScore: Double? = nil
    /// Camera frame published by SmartSpectraVitalsProcessor (enabled via setImageOutputEnabled).
    @Published var latestFrame: UIImage? = nil

    private var cancellables = Set<AnyCancellable>()

    init() {
        let sdk = SmartSpectraSwiftSDK.shared
        sdk.setApiKey(Config.smartSpectraAPIKey)
        sdk.setSmartSpectraMode(.continuous)
        sdk.setCameraPosition(.front)
        // Enable imageOutput on SmartSpectraVitalsProcessor so Vision can read camera frames
        sdk.setImageOutputEnabled(true)

        subscribeToMetrics()
    }

    private func subscribeToMetrics() {
        let sdk = SmartSpectraSwiftSDK.shared
        let processor = SmartSpectraVitalsProcessor.shared

        // Real-time edge metrics: heart rate from pulse rate
        sdk.$edgeMetrics
            .receive(on: RunLoop.main)
            .sink { [weak self] metrics in
                guard let self, let metrics else { return }
                if let bpm = metrics.pulse.rate.last?.value {
                    self.heartRate = bpm
                }
                // Derive focus from HRV: normalize ~20ms (poor) to ~80ms (good)
                if let hrv = metrics.pulse.rmssd.last?.value {
                    self.focusScore = min(max((hrv - 20.0) / 60.0, 0.0), 1.0)
                }
            }
            .store(in: &cancellables)

        // Also pick up completed session metrics from metricsBuffer
        sdk.$metricsBuffer
            .receive(on: RunLoop.main)
            .sink { [weak self] buffer in
                guard let self, let buffer else { return }
                if let bpm = buffer.pulse.rate.last?.value {
                    self.heartRate = bpm
                }
                if let hrv = buffer.pulse.rmssd.last?.value {
                    self.focusScore = min(max((hrv - 20.0) / 60.0, 0.0), 1.0)
                }
            }
            .store(in: &cancellables)

        // Camera frames for Vision face analysis (throttled — every 3rd emission)
        var frameCount = 0
        processor.$imageOutput
            .receive(on: RunLoop.main)
            .sink { [weak self] image in
                guard let self, let image else { return }
                frameCount += 1
                if frameCount % 3 == 0 {        // ~1 Vision call per 3 frames
                    self.latestFrame = image
                }
            }
            .store(in: &cancellables)
    }

    func cancelSubscriptions() {
        cancellables.removeAll()
    }
}

// MARK: - Scan Metric Card

struct ScanMetricCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(iconColor)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppTheme.Fonts.mono(11))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                Text(value)
                    .font(AppTheme.Fonts.mono(15, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
            }
            Spacer()
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(AppTheme.Colors.cardBackground)
        .cornerRadius(AppTheme.Radius.card)
        .cardShadow()
    }
}

// MARK: - Face Silhouette Shape

struct FaceSilhouette: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width, h = rect.height, cx = rect.midX

        path.addEllipse(in: CGRect(x: cx - w * 0.38, y: rect.minY, width: w * 0.76, height: h * 0.72))

        path.move(to: CGPoint(x: cx - w * 0.18, y: rect.minY + h * 0.70))
        path.addQuadCurve(to: CGPoint(x: cx + w * 0.18, y: rect.minY + h * 0.70),
                          control: CGPoint(x: cx, y: rect.minY + h * 0.78))

        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: cx - w * 0.18, y: rect.minY + h * 0.72),
                          control: CGPoint(x: cx - w * 0.4, y: rect.minY + h * 0.80))
        path.move(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: cx + w * 0.18, y: rect.minY + h * 0.72),
                          control: CGPoint(x: cx + w * 0.4, y: rect.minY + h * 0.80))

        return path
    }
}

#Preview { ScanView().environment(AppState()) }
