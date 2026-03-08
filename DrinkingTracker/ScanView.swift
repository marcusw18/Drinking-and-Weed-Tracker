import SwiftUI
import SmartSpectraSwiftSDK

// MARK: - Scan View
// Uses SmartSpectraView() for camera + PPG measurement.
// SmartSpectraView() owns the entire camera session — do not run AVCaptureSession
// or SmartSpectraVitalsProcessor alongside it.

struct ScanView: View {
    @Environment(AppState.self) private var appState

    // Observe the SDK singleton directly; SmartSpectraView() manages the session lifecycle
    @ObservedObject private var sdk = SmartSpectraSwiftSDK.shared

    @State private var heartRate: Double? = nil
    @State private var breathingRate: Double? = nil
    @State private var isScanning = false

    private let pollTimer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

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

                // MARK: Camera Viewfinder
                // SmartSpectraView() handles camera permission, PPG, and session display.
                ZStack {
                    RoundedRectangle(cornerRadius: AppTheme.Radius.card)
                        .fill(Color.black)

                    SmartSpectraView()
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.card))

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

                // MARK: Live Metrics
                if heartRate != nil || breathingRate != nil {
                    SectionHeader(title: "Live Metrics", showPlus: false)
                        .padding(.top, 24)
                        .padding(.horizontal, 20)

                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            ScanMetricCard(
                                icon: "heart.fill",
                                iconColor: AppTheme.Colors.dotRed,
                                title: "Heart Rate",
                                value: heartRate.map { String(format: "%.0f bpm", $0) } ?? "--"
                            )
                            ScanMetricCard(
                                icon: "lungs.fill",
                                iconColor: AppTheme.Colors.dotTeal,
                                title: "Breathing",
                                value: breathingRate.map { String(format: "%.1f /min", $0) } ?? "--"
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                } else if isScanning {
                    HStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Measuring — keep face in frame")
                            .font(AppTheme.Fonts.mono(12))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                }

                Spacer(minLength: 140)
            }
        }
        .onAppear { isScanning = true }
        .onDisappear {
            isScanning = false
            heartRate = nil
            breathingRate = nil
        }
        // Poll edge metrics every 2 seconds — populated by SmartSpectraView() during measurement
        .onReceive(pollTimer) { _ in
            guard isScanning else { return }
            readMetrics()
        }
    }

    // MARK: - Metrics

    private func readMetrics() {
        // edgeMetrics = real-time during measurement; metricsBuffer = completed session
        let pulse    = sdk.edgeMetrics?.pulse    ?? sdk.metricsBuffer?.pulse
        let breathing = sdk.edgeMetrics?.breathing ?? sdk.metricsBuffer?.breathing

        if let bpm = pulse?.rate.last?.value, bpm > 0 {
            heartRate = bpm
            appState.latestHeartRate = bpm
            // Push HR into scan results so IntoxicationStage composite can use it
            var scan = appState.lastScanResults ?? ScanResults()
            scan.heartRate = bpm
            appState.lastScanResults = scan
            appState.refreshBAC()
        }

        if let br = breathing?.rate.last?.value, br > 0 {
            breathingRate = br
        }
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
