import Foundation
import SwiftData

/// Represents a body weight measurement
@Model
final class WeightEntry {
    var id: UUID = UUID()

    /// Weight in kilograms
    var weightKg: Double = 0

    /// Body fat percentage (if available)
    var bodyFatPercentage: Double?

    /// Lean body mass in kilograms (if available)
    var leanMassKg: Double?

    /// Whether this was imported from HealthKit
    var sourceIsHealthKit: Bool = false

    /// HealthKit sample UUID for deduplication
    var healthKitSampleID: String?

    var loggedAt: Date = Date()
    var notes: String?

    init() {}

    init(weightKg: Double, loggedAt: Date = Date()) {
        self.weightKg = weightKg
        self.loggedAt = loggedAt
    }

    init(
        weightKg: Double,
        bodyFatPercentage: Double?,
        leanMassKg: Double?,
        loggedAt: Date = Date()
    ) {
        self.weightKg = weightKg
        self.bodyFatPercentage = bodyFatPercentage
        self.leanMassKg = leanMassKg
        self.loggedAt = loggedAt
    }
}

// MARK: - Computed Properties

extension WeightEntry {
    /// Weight in pounds
    var weightLbs: Double {
        weightKg * 2.20462
    }

    /// Lean mass in pounds (if available)
    var leanMassLbs: Double? {
        guard let leanMassKg else { return nil }
        return leanMassKg * 2.20462
    }

    /// Fat mass in kilograms (if body fat percentage is available)
    var fatMassKg: Double? {
        guard let bodyFatPercentage else { return nil }
        return weightKg * (bodyFatPercentage / 100)
    }

    /// Calculated lean mass if body fat is available but lean mass isn't directly provided
    var calculatedLeanMassKg: Double? {
        if let leanMassKg {
            return leanMassKg
        }
        guard let fatMassKg else { return nil }
        return weightKg - fatMassKg
    }
}

// MARK: - Unit Conversion

extension WeightEntry {
    enum WeightUnit: String, CaseIterable, Identifiable {
        case kilograms = "kg"
        case pounds = "lbs"

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .kilograms: "Kilograms"
            case .pounds: "Pounds"
            }
        }

        var abbreviation: String { rawValue }
    }

    /// Get weight in the specified unit
    func weight(in unit: WeightUnit) -> Double {
        switch unit {
        case .kilograms: weightKg
        case .pounds: weightLbs
        }
    }

    /// Set weight from the specified unit
    func setWeight(_ value: Double, unit: WeightUnit) {
        switch unit {
        case .kilograms:
            weightKg = value
        case .pounds:
            weightKg = value / 2.20462
        }
    }
}
