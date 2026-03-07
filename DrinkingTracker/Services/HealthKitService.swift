import Foundation
import HealthKit

@Observable
final class HealthKitService {

    static let shared = HealthKitService()
    private let store = HKHealthStore()

    var isAuthorized = false
    var latestHeartRate: Double? = nil
    var latestHRV: Double? = nil
    var latestSpO2: Double? = nil

    private init() {}

    // MARK: - Authorization

    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        let readTypes: Set<HKObjectType> = [
            HKQuantityType(.heartRate),
            HKQuantityType(.heartRateVariabilitySDNN),
            HKQuantityType(.oxygenSaturation)
        ]

        try await store.requestAuthorization(toShare: [], read: readTypes)
        isAuthorized = true
    }

    // MARK: - Queries

    func fetchLatestHeartRate() async throws -> Double? {
        let value = try await fetchMostRecentSample(
            type: HKQuantityType(.heartRate),
            unit: HKUnit(from: "count/min")
        )
        latestHeartRate = value
        return value
    }

    func fetchLatestHRV() async throws -> Double? {
        let value = try await fetchMostRecentSample(
            type: HKQuantityType(.heartRateVariabilitySDNN),
            unit: .secondUnit(with: .milli)
        )
        latestHRV = value
        return value
    }

    func fetchLatestSpO2() async throws -> Double? {
        let value = try await fetchMostRecentSample(
            type: HKQuantityType(.oxygenSaturation),
            unit: .percent()
        )
        latestSpO2 = value
        return value
    }

    /// Fetches all three metrics and updates local state.
    func refreshAll() async {
        async let hr = try? fetchLatestHeartRate()
        async let hrv = try? fetchLatestHRV()
        async let spo2 = try? fetchLatestSpO2()
        _ = await (hr, hrv, spo2)
    }

    // MARK: - Private helpers

    private func fetchMostRecentSample(type: HKQuantityType, unit: HKUnit) async throws -> Double? {
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let predicate = HKQuery.predicateForSamples(
            withStart: Date().addingTimeInterval(-3600),   // last 1 hour
            end: Date()
        )

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: 1,
                sortDescriptors: [sort]
            ) { _, samples, error in
                if let error { continuation.resume(throwing: error); return }
                let value = (samples?.first as? HKQuantitySample)?.quantity.doubleValue(for: unit)
                continuation.resume(returning: value)
            }
            store.execute(query)
        }
    }
}
