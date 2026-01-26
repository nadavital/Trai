//
//  WeightUtility.swift
//  Trai
//
//  Centralized weight conversion and rounding utility for consistent unit handling
//

import Foundation

// MARK: - Weight Unit

enum WeightUnit: String, Codable {
    case kg
    case lbs

    var symbol: String {
        switch self {
        case .kg: return "kg"
        case .lbs: return "lbs"
        }
    }

    init(usesMetric: Bool) {
        self = usesMetric ? .kg : .lbs
    }
}

// MARK: - Clean Weight (dual-unit storage)

/// Stores both kg and lbs values, each rounded to their respective clean increments
struct CleanWeight: Codable, Equatable {
    /// Weight in kilograms, rounded to 0.5 kg
    let kg: Double
    /// Weight in pounds, rounded to 2.5 lbs
    let lbs: Double

    /// Returns the weight in the user's preferred unit
    func value(for unit: WeightUnit) -> Double {
        unit == .kg ? kg : lbs
    }

    /// Returns formatted string in the user's preferred unit
    func formatted(unit: WeightUnit, showUnit: Bool = true) -> String {
        let value = self.value(for: unit)
        let formatted: String
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            formatted = "\(Int(value))"
        } else {
            formatted = String(format: "%.1f", value)
        }
        return showUnit ? "\(formatted) \(unit.symbol)" : formatted
    }

    /// Returns integer value in the user's preferred unit
    func intValue(for unit: WeightUnit) -> Int {
        Int(value(for: unit))
    }

    /// Zero weight
    static let zero = CleanWeight(kg: 0, lbs: 0)
}

// MARK: - Weight Utility

struct WeightUtility {
    // MARK: - Constants

    /// Conversion factor: kg to lbs
    static let kgToLbs: Double = 2.20462

    /// Conversion factor: lbs to kg
    static let lbsToKg: Double = 0.453592

    /// Rounding increment for kg (0.5 kg)
    static let kgIncrement: Double = 0.5

    /// Rounding increment for lbs (2.5 lbs)
    static let lbsIncrement: Double = 2.5

    // MARK: - Conversion

    /// Convert weight between units
    /// - Parameters:
    ///   - weight: The weight value to convert
    ///   - from: Source unit
    ///   - to: Target unit
    /// - Returns: Converted weight value
    static func convert(_ weight: Double, from: WeightUnit, to: WeightUnit) -> Double {
        switch (from, to) {
        case (.kg, .kg), (.lbs, .lbs):
            return weight
        case (.kg, .lbs):
            return weight * kgToLbs
        case (.lbs, .kg):
            return weight * lbsToKg
        }
    }

    // MARK: - Rounding

    /// Round weight to the nearest increment for the specified unit
    /// - Parameters:
    ///   - weight: Weight value (in the specified unit)
    ///   - unit: The unit the weight is in
    /// - Returns: Rounded weight value
    static func round(_ weight: Double, unit: WeightUnit) -> Double {
        let increment = unit == .kg ? kgIncrement : lbsIncrement
        return (weight / increment).rounded() * increment
    }

    // MARK: - Parse User Input

    /// Parse user input string to kg for storage
    /// - Parameters:
    ///   - input: User-entered weight string
    ///   - inputUnit: The unit the user entered (based on their preference)
    /// - Returns: Weight in kg, rounded appropriately, or nil if parsing fails
    static func parseToKg(_ input: String, inputUnit: WeightUnit) -> Double? {
        guard let value = Double(input) else { return nil }
        let rounded = round(value, unit: inputUnit)
        return convert(rounded, from: inputUnit, to: .kg)
    }

    // MARK: - Display Formatting

    /// Format a kg weight value for display in the user's preferred unit
    /// - Parameters:
    ///   - weightKg: Weight in kilograms (storage format)
    ///   - displayUnit: User's preferred display unit
    ///   - showUnit: Whether to append the unit symbol
    /// - Returns: Formatted string for display
    static func format(_ weightKg: Double, displayUnit: WeightUnit, showUnit: Bool = true) -> String {
        let converted = convert(weightKg, from: .kg, to: displayUnit)
        let rounded = round(converted, unit: displayUnit)

        let formatted: String
        if rounded.truncatingRemainder(dividingBy: 1) == 0 {
            formatted = "\(Int(rounded))"
        } else {
            formatted = String(format: "%.1f", rounded)
        }

        return showUnit ? "\(formatted) \(displayUnit.symbol)" : formatted
    }

    /// Get the display value for a kg weight in the user's preferred unit
    /// - Parameters:
    ///   - weightKg: Weight in kilograms (storage format)
    ///   - displayUnit: User's preferred display unit
    /// - Returns: Rounded weight value in the display unit (for text fields)
    static func displayValue(_ weightKg: Double, displayUnit: WeightUnit) -> Double {
        let converted = convert(weightKg, from: .kg, to: displayUnit)
        return round(converted, unit: displayUnit)
    }

    /// Get the integer display value for a kg weight (for simple Int displays)
    /// - Parameters:
    ///   - weightKg: Weight in kilograms (storage format)
    ///   - displayUnit: User's preferred display unit
    /// - Returns: Rounded integer weight in the display unit
    static func displayInt(_ weightKg: Double, displayUnit: WeightUnit) -> Int {
        Int(displayValue(weightKg, displayUnit: displayUnit))
    }

    // MARK: - Dual-Unit Storage

    /// Compute both clean kg and lbs values from user input
    /// - Parameters:
    ///   - input: User-entered weight string
    ///   - inputUnit: The unit the user entered (based on their preference)
    /// - Returns: CleanWeight with both rounded kg and lbs values, or nil if parsing fails
    static func parseToCleanWeight(_ input: String, inputUnit: WeightUnit) -> CleanWeight? {
        guard let value = Double(input), value > 0 else { return nil }
        return cleanWeight(from: value, inputUnit: inputUnit)
    }

    /// Compute both clean kg and lbs values from a numeric input
    /// - Parameters:
    ///   - value: The weight value
    ///   - inputUnit: The unit of the input value
    /// - Returns: CleanWeight with both rounded kg and lbs values
    static func cleanWeight(from value: Double, inputUnit: WeightUnit) -> CleanWeight {
        // Round the input in its native unit first (this is the "source of truth")
        let roundedInput = round(value, unit: inputUnit)

        // Convert to the other unit and round it too
        let convertedValue = convert(roundedInput, from: inputUnit, to: inputUnit == .kg ? .lbs : .kg)
        let roundedConverted = round(convertedValue, unit: inputUnit == .kg ? .lbs : .kg)

        // Return both clean values
        if inputUnit == .kg {
            return CleanWeight(kg: roundedInput, lbs: roundedConverted)
        } else {
            return CleanWeight(kg: roundedConverted, lbs: roundedInput)
        }
    }

    /// Create CleanWeight from existing kg value (for migration/display of legacy data)
    /// - Parameter weightKg: Weight in kg (possibly from legacy storage)
    /// - Returns: CleanWeight with clean values in both units
    static func cleanWeightFromKg(_ weightKg: Double) -> CleanWeight {
        let cleanKg = round(weightKg, unit: .kg)
        let convertedLbs = convert(cleanKg, from: .kg, to: .lbs)
        let cleanLbs = round(convertedLbs, unit: .lbs)
        return CleanWeight(kg: cleanKg, lbs: cleanLbs)
    }
}
