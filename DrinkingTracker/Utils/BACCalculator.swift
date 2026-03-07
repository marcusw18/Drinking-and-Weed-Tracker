import Foundation

/// Blood Alcohol Content calculator using the Widmark formula.
///
/// BAC = (A / (W × r)) × 100 - (β × t)
///
/// Where:
///   A = mass of alcohol consumed (grams)
///   W = body weight (grams)
///   r = Widmark factor (0.68 male, 0.55 female)
///   β = elimination rate per hour (≈ 0.015% / hr)
///   t = hours since first drink
enum BACCalculator {

    static let eliminationRatePerHour: Double = 0.015  // % per hour

    /// Compute current estimated BAC from a list of drink logs and a user profile.
    static func currentBAC(drinks: [DrinkLog], profile: UserProfile, now: Date = Date()) -> Double {
        guard !drinks.isEmpty else { return 0.0 }

        let weightGrams = profile.weightKg * 1000.0
        let r = profile.biologicalSex.widmarkR

        let bac = drinks.reduce(0.0) { total, drink in
            let hoursAgo = now.timeIntervalSince(drink.timestamp) / 3600.0
            guard hoursAgo >= 0 else { return total }

            // BAC contribution of this individual drink at time t after drinking
            let drinkBAC = (drink.gramsOfAlcohol / (weightGrams * r)) * 100.0
            let decayed = drinkBAC - (eliminationRatePerHour * hoursAgo)
            return total + max(0, decayed)
        }

        return max(0, bac)
    }

    /// Hours remaining until BAC returns to 0 from current value.
    static func hoursUntilSober(currentBAC: Double) -> Double {
        guard currentBAC > 0 else { return 0 }
        return currentBAC / eliminationRatePerHour
    }

    /// Estimated time when BAC will reach zero.
    static func soberTime(drinks: [DrinkLog], profile: UserProfile, now: Date = Date()) -> Date? {
        let bac = currentBAC(drinks: drinks, profile: profile, now: now)
        guard bac > 0 else { return nil }
        let hours = hoursUntilSober(currentBAC: bac)
        return now.addingTimeInterval(hours * 3600)
    }

    /// Grams of ethanol in a standard drink by type (for display purposes)
    static func standardDrinkEquivalents(drinks: [DrinkLog]) -> Double {
        // A standard drink = 14g of pure alcohol (US standard)
        let totalGrams = drinks.reduce(0.0) { $0 + $1.gramsOfAlcohol }
        return totalGrams / 14.0
    }
}
