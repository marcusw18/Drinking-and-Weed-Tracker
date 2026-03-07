import Foundation
import Supabase

/// Centralised Supabase client. Call methods with the Firebase UID as userId.
@Observable
final class SupabaseService {

    static let shared = SupabaseService()

    private let client: SupabaseClient

    private init() {
        client = SupabaseClient(
            supabaseURL: URL(string: Config.supabaseURL)!,
            supabaseKey: Config.supabaseAnonKey
        )
    }

    // MARK: - User Profile

    func fetchProfile(userId: String) async throws -> UserProfile? {
        let results: [UserProfile] = try await client
            .from("user_profiles")
            .select()
            .eq("user_id", value: userId)
            .limit(1)
            .execute()
            .value
        return results.first
    }

    func upsertProfile(_ profile: UserProfile) async throws {
        try await client
            .from("user_profiles")
            .upsert(profile)
            .execute()
    }

    // MARK: - Drink Logs

    func fetchDrinkLogs(userId: String, limit: Int = 100) async throws -> [DrinkLog] {
        let results: [DrinkLog] = try await client
            .from("drink_logs")
            .select()
            .eq("user_id", value: userId)
            .order("timestamp", ascending: false)
            .limit(limit)
            .execute()
            .value
        return results
    }

    func insertDrinkLog(_ log: DrinkLog) async throws {
        try await client
            .from("drink_logs")
            .insert(log)
            .execute()
    }

    func deleteDrinkLog(id: UUID) async throws {
        try await client
            .from("drink_logs")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }

    // MARK: - Analysis Logs

    func fetchAnalysisLogs(userId: String, limit: Int = 50) async throws -> [AnalysisLog] {
        let results: [AnalysisLog] = try await client
            .from("analysis_logs")
            .select()
            .eq("user_id", value: userId)
            .order("timestamp", ascending: false)
            .limit(limit)
            .execute()
            .value
        return results
    }

    func insertAnalysisLog(_ log: AnalysisLog) async throws {
        try await client
            .from("analysis_logs")
            .insert(log)
            .execute()
    }
}
