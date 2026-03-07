import SwiftUI

struct HealthMetricsView: View {
    let heartRate: Double?
    let hrv: Double?
    let spo2: Double?

    var body: some View {
        HStack(spacing: 12) {
            MetricCard(
                icon: "heart.fill",
                color: .red,
                label: "Heart Rate",
                value: heartRate.map { "\(Int($0))" } ?? "--",
                unit: "bpm"
            )
            MetricCard(
                icon: "waveform.path.ecg",
                color: .green,
                label: "HRV",
                value: hrv.map { String(format: "%.0f", $0) } ?? "--",
                unit: "ms"
            )
            MetricCard(
                icon: "lungs.fill",
                color: .blue,
                label: "SpO₂",
                value: spo2.map { String(format: "%.0f", $0 * 100) } ?? "--",
                unit: "%"
            )
        }
    }
}

struct MetricCard: View {
    let icon: String
    let color: Color
    let label: String
    let value: String
    let unit: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.title3)
            Text(value)
                .font(.title3.bold())
            Text(unit)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
