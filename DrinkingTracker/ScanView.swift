import SwiftUI
import AVFoundation
import Vision
import SmartSpectraSwiftSDK

// MARK: - Scan View

struct ScanView: View {
    @Environment(AppState.self) private var appState
    @StateObject private var smartSpectra = SmartSpectraManager()
    @State private var results = ScanResults()
    @State private var isScanning = false
    @State private var capturedImage: UIImage? = nil
    @State private var showCamera = false
    @State private var errorMessage: String? = nil

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

                    // SmartSpectra live view (handles PPG measurement)
                    SmartSpectraView(
                        apiKey: Config.smartSpectraAPIKey,
                        onHeartRate: { bpm in
                            results.heartRate = bpm
                            appState.latestHeartRate = bpm
                            pushResultsToAppState()
                        },
                        onFocusScore: { score in
                            results.focusScore = score
                            pushResultsToAppState()
                        }
                    )
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

                if let error = errorMessage {
                    Text(error)
                        .font(AppTheme.Fonts.mono(12))
                        .foregroundColor(.red)
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                }

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
        .onAppear  { smartSpectra.start() }
        .onDisappear { smartSpectra.stop() }
        .onChange(of: smartSpectra.capturedFrame) { _, frame in
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
        appState.refreshBAC()   // recomputes stage using BAC + scan signals
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

/// Wraps SmartSpectraSwiftSDK session lifecycle and exposes results.
/// Verify callback names against SDK docs after xcodegen + package resolution.
@MainActor
final class SmartSpectraManager: ObservableObject {
    @Published var capturedFrame: UIImage? = nil

    private var session: SmartSpectraSession?

    func start() {
        session = SmartSpectraSession(apiKey: Config.smartSpectraAPIKey)
        session?.onFrameCaptured = { [weak self] image in
            Task { @MainActor in self?.capturedFrame = image }
        }
        session?.start()
    }

    func stop() {
        session?.stop()
        session = nil
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
