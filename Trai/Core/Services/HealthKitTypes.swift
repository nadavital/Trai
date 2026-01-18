//
//  HealthKitTypes.swift
//  Trai
//
//  Created by Nadav Avital on 12/25/25.
//

import Foundation
import HealthKit

// MARK: - Errors

enum HealthKitError: LocalizedError {
    case notAvailable
    case notAuthorized

    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "HealthKit is not available on this device"
        case .notAuthorized:
            return "HealthKit access has not been authorized"
        }
    }
}

// MARK: - Workout Activity Type Extension

extension HKWorkoutActivityType {
    var name: String {
        switch self {
        case .running: return "Running"
        case .cycling: return "Cycling"
        case .walking: return "Walking"
        case .swimming: return "Swimming"
        case .hiking: return "Hiking"
        case .yoga: return "Yoga"
        case .functionalStrengthTraining: return "Strength Training"
        case .traditionalStrengthTraining: return "Weight Training"
        case .coreTraining: return "Core Training"
        case .highIntensityIntervalTraining: return "HIIT"
        case .rowing: return "Rowing"
        case .stairClimbing: return "Stair Climbing"
        case .elliptical: return "Elliptical"
        case .dance: return "Dance"
        case .cooldown: return "Cooldown"
        case .flexibility: return "Flexibility"
        case .mixedCardio: return "Mixed Cardio"
        case .pilates: return "Pilates"
        default: return "Workout"
        }
    }
}
