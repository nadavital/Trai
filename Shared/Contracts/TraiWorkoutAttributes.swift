//
//  TraiWorkoutAttributes.swift
//  Shared
//
//  Live Activity attributes shared by app and widget extension.
//

import ActivityKit
import Foundation

struct TraiWorkoutAttributes: ActivityAttributes {
    let workoutName: String
    let targetMuscles: [String]
    let startedAt: Date

    struct ContentState: Codable, Hashable {
        let elapsedSeconds: Int
        let currentExercise: String?
        let currentEquipment: String?
        let currentDetail: String?
        let completedSets: Int
        let totalSets: Int
        let heartRate: Int?
        let isPaused: Bool
        let currentWeightKg: Double?
        let currentWeightLbs: Double?
        let currentReps: Int?
        let totalVolumeKg: Double?
        let totalVolumeLbs: Double?
        let nextExercise: String?
        let usesMetricWeight: Bool
        let progressCompleted: Int?
        let progressTotal: Int?
        let progressLabel: String?
        let supportsSetShortcut: Bool?
        let currentExerciseCompletedSets: Int?
        let currentExerciseTotalSets: Int?
        let currentExerciseIndex: Int?
        let exerciseTotal: Int?

        init(
            elapsedSeconds: Int,
            currentExercise: String? = nil,
            currentEquipment: String? = nil,
            currentDetail: String? = nil,
            completedSets: Int,
            totalSets: Int,
            heartRate: Int? = nil,
            isPaused: Bool,
            currentWeightKg: Double? = nil,
            currentWeightLbs: Double? = nil,
            currentReps: Int? = nil,
            totalVolumeKg: Double? = nil,
            totalVolumeLbs: Double? = nil,
            nextExercise: String? = nil,
            usesMetricWeight: Bool = true,
            progressCompleted: Int? = nil,
            progressTotal: Int? = nil,
            progressLabel: String? = nil,
            supportsSetShortcut: Bool = true,
            currentExerciseCompletedSets: Int? = nil,
            currentExerciseTotalSets: Int? = nil,
            currentExerciseIndex: Int? = nil,
            exerciseTotal: Int? = nil
        ) {
            self.elapsedSeconds = elapsedSeconds
            self.currentExercise = currentExercise
            self.currentEquipment = currentEquipment
            self.currentDetail = currentDetail
            self.completedSets = completedSets
            self.totalSets = totalSets
            self.heartRate = heartRate
            self.isPaused = isPaused
            self.currentWeightKg = currentWeightKg
            self.currentWeightLbs = currentWeightLbs
            self.currentReps = currentReps
            self.totalVolumeKg = totalVolumeKg
            self.totalVolumeLbs = totalVolumeLbs
            self.nextExercise = nextExercise
            self.usesMetricWeight = usesMetricWeight
            self.progressCompleted = progressCompleted
            self.progressTotal = progressTotal
            self.progressLabel = progressLabel
            self.supportsSetShortcut = supportsSetShortcut
            self.currentExerciseCompletedSets = currentExerciseCompletedSets
            self.currentExerciseTotalSets = currentExerciseTotalSets
            self.currentExerciseIndex = currentExerciseIndex
            self.exerciseTotal = exerciseTotal
        }

        var formattedTime: String {
            let hours = elapsedSeconds / 3600
            let minutes = (elapsedSeconds % 3600) / 60
            let seconds = elapsedSeconds % 60

            if hours > 0 {
                return String(format: "%d:%02d:%02d", hours, minutes, seconds)
            }
            return String(format: "%02d:%02d", minutes, seconds)
        }

        var progress: Double {
            guard progressTotalValue > 0 else { return 0 }
            return Double(progressCompletedValue) / Double(progressTotalValue)
        }

        var hasProgressTarget: Bool {
            progressTotalValue > 0
        }

        var setsDisplay: String {
            progressDisplay
        }

        var progressCompletedValue: Int {
            progressCompleted ?? completedSets
        }

        var progressTotalValue: Int {
            progressTotal ?? totalSets
        }

        var progressCountDisplay: String {
            guard progressTotalValue > 0 else {
                guard progressCompletedValue > 0 else { return "Live" }
                return "\(progressCompletedValue)"
            }
            return "\(progressCompletedValue)/\(progressTotalValue)"
        }

        var progressDisplay: String {
            let total = progressTotalValue
            let baseLabel = progressLabel?.trimmingCharacters(in: .whitespacesAndNewlines)
            let label = (baseLabel?.isEmpty == false ? baseLabel : "sets") ?? "sets"
            guard total > 0 else {
                guard progressCompletedValue > 0 else { return "Live workout" }
                return "\(progressCompletedValue) \(label)"
            }
            return "\(progressCompletedValue)/\(total) \(label)"
        }

        var canUseSetShortcut: Bool {
            supportsSetShortcut ?? true
        }

        var currentSetOrdinalDisplay: String? {
            guard currentExerciseTotalSets != nil || currentExerciseCompletedSets != nil else { return nil }
            let total = max(currentExerciseTotalSets ?? 0, 1)
            let completed = max(0, currentExerciseCompletedSets ?? 0)
            return "Set \(min(completed + 1, total))"
        }

        var currentSetProgressDisplay: String? {
            guard currentExerciseTotalSets != nil || currentExerciseCompletedSets != nil else { return nil }
            let total = max(currentExerciseTotalSets ?? 0, 1)
            let completed = max(0, currentExerciseCompletedSets ?? 0)
            return "Set \(min(completed + 1, total)) of \(total)"
        }

        var currentExerciseTargetSetsDisplay: String? {
            guard let total = currentExerciseTotalSets, total > 0 else { return nil }
            return "\(total) \(total == 1 ? "set" : "sets")"
        }

        var totalSetsSummaryDisplay: String? {
            guard totalSets > 0 else { return nil }
            return "\(totalSets) \(totalSets == 1 ? "set" : "sets")"
        }

        var exerciseTotalSummaryDisplay: String? {
            guard let total = exerciseTotal, total > 0 else { return nil }
            return "\(total) \(total == 1 ? "exercise" : "exercises")"
        }

        var volumeDisplay: String? {
            let displayVolume: Double?
            let unit: String
            if usesMetricWeight {
                displayVolume = totalVolumeKg
                unit = "kg"
            } else {
                displayVolume = totalVolumeLbs ?? totalVolumeKg.map { $0 * 2.20462 }
                unit = "lbs"
            }
            guard let volume = displayVolume, volume > 0 else { return nil }
            if volume >= 1000 {
                return String(format: "%.1fk %@", volume / 1000, unit)
            }
            return "\(Int(volume.rounded())) \(unit)"
        }

        var currentSetDisplay: String? {
            guard let reps = currentReps else { return nil }
            let displayWeight: Double?
            let unit: String
            if usesMetricWeight {
                displayWeight = currentWeightKg
                unit = "kg"
            } else {
                displayWeight = currentWeightLbs ?? currentWeightKg.map { $0 * 2.20462 }
                unit = "lbs"
            }
            guard let weight = displayWeight, weight > 0 else { return nil }
            return "\(Int(weight.rounded()))\(unit) \u{00D7} \(reps)"
        }

        var currentWeightDisplay: String? {
            let displayWeight: Double?
            let unit: String
            if usesMetricWeight {
                displayWeight = currentWeightKg
                unit = "kg"
            } else {
                displayWeight = currentWeightLbs ?? currentWeightKg.map { $0 * 2.20462 }
                unit = "lbs"
            }
            guard let weight = displayWeight, weight > 0 else { return nil }
            return "\(Int(weight.rounded()))\(unit)"
        }

        var currentRepsDisplay: String? {
            guard let reps = currentReps else { return nil }
            return "\(reps) reps"
        }

        var currentWorkDisplay: String? {
            currentSetDisplay ?? currentDetail
        }
    }
}
