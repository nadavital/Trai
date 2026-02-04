//
//  TraiWorkoutAttributes.swift
//  Trai
//
//  ActivityAttributes for Live Activity workout tracking
//

import ActivityKit
import Foundation

/// Attributes for the Trai workout Live Activity
struct TraiWorkoutAttributes: ActivityAttributes {
    /// Static content that doesn't change during the workout
    let workoutName: String
    let targetMuscles: [String]
    let startedAt: Date

    /// Dynamic content that updates during the workout
    struct ContentState: Codable, Hashable {
        let elapsedSeconds: Int
        let currentExercise: String?
        let currentEquipment: String?
        let completedSets: Int
        let totalSets: Int
        let heartRate: Int?
        let isPaused: Bool
        // Dual-unit weight storage (pre-cleaned to avoid rounding errors)
        let currentWeightKg: Double?
        let currentWeightLbs: Double?
        let currentReps: Int?
        let totalVolumeKg: Double?
        let totalVolumeLbs: Double?
        let nextExercise: String?
        // User's weight unit preference
        let usesMetricWeight: Bool

        init(
            elapsedSeconds: Int,
            currentExercise: String? = nil,
            currentEquipment: String? = nil,
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
            usesMetricWeight: Bool = true
        ) {
            self.elapsedSeconds = elapsedSeconds
            self.currentExercise = currentExercise
            self.currentEquipment = currentEquipment
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
        }

        /// Formatted elapsed time string (MM:SS or H:MM:SS)
        var formattedTime: String {
            let hours = elapsedSeconds / 3600
            let minutes = (elapsedSeconds % 3600) / 60
            let seconds = elapsedSeconds % 60

            if hours > 0 {
                return String(format: "%d:%02d:%02d", hours, minutes, seconds)
            }
            return String(format: "%02d:%02d", minutes, seconds)
        }

        /// Progress as a fraction (0.0 to 1.0)
        var progress: Double {
            guard totalSets > 0 else { return 0 }
            return Double(completedSets) / Double(totalSets)
        }

        /// Sets display string (e.g., "8/12 sets")
        var setsDisplay: String {
            "\(completedSets)/\(totalSets) sets"
        }

        /// Volume display string (e.g., "2.5k kg" or "5.5k lbs")
        var volumeDisplay: String? {
            // Use pre-cleaned volume values to avoid rounding errors
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

        /// Current set display (e.g., "80kg × 8" or "175lbs × 8")
        var currentSetDisplay: String? {
            guard let reps = currentReps else { return nil }
            // Use pre-cleaned weight values to avoid rounding errors (200 lbs showing as 199)
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
    }
}

// MARK: - Live Activity Manager

/// Manages the Live Activity lifecycle for workouts (Singleton to prevent duplicates)
@MainActor @Observable
final class LiveActivityManager {
    /// Shared singleton instance
    static let shared = LiveActivityManager()

    private var currentActivity: Activity<TraiWorkoutAttributes>?

    /// Private init to enforce singleton usage
    private init() {}

    /// Whether a Live Activity is currently running
    var isActivityActive: Bool {
        currentActivity != nil
    }

    /// Start a new Live Activity for a workout
    func startActivity(
        workoutName: String,
        targetMuscles: [String],
        startedAt: Date
    ) {
        // Guard: Don't start if already have an active activity
        guard currentActivity == nil else {
            print("Live Activity already active - skipping duplicate")
            return
        }

        // Check if Live Activities are supported and enabled
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("Live Activities not enabled")
            return
        }

        let attributes = TraiWorkoutAttributes(
            workoutName: workoutName,
            targetMuscles: targetMuscles,
            startedAt: startedAt
        )

        let initialState = TraiWorkoutAttributes.ContentState(
            elapsedSeconds: 0,
            currentExercise: nil,
            completedSets: 0,
            totalSets: 0,
            heartRate: nil,
            isPaused: false
        )

        let content = ActivityContent(state: initialState, staleDate: Date().addingTimeInterval(60))

        do {
            currentActivity = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
            print("Live Activity started: \(currentActivity?.id ?? "unknown")")
        } catch {
            print("Failed to start Live Activity: \(error)")
        }
    }

    /// Update the Live Activity with new state
    func updateActivity(
        elapsedSeconds: Int,
        currentExercise: String?,
        currentEquipment: String? = nil,
        completedSets: Int,
        totalSets: Int,
        heartRate: Int?,
        isPaused: Bool,
        currentWeightKg: Double? = nil,
        currentWeightLbs: Double? = nil,
        currentReps: Int? = nil,
        totalVolumeKg: Double? = nil,
        totalVolumeLbs: Double? = nil,
        nextExercise: String? = nil,
        usesMetricWeight: Bool = true
    ) {
        guard let activity = currentActivity else { return }

        let updatedState = TraiWorkoutAttributes.ContentState(
            elapsedSeconds: elapsedSeconds,
            currentExercise: currentExercise,
            currentEquipment: currentEquipment,
            completedSets: completedSets,
            totalSets: totalSets,
            heartRate: heartRate,
            isPaused: isPaused,
            currentWeightKg: currentWeightKg,
            currentWeightLbs: currentWeightLbs,
            currentReps: currentReps,
            totalVolumeKg: totalVolumeKg,
            totalVolumeLbs: totalVolumeLbs,
            nextExercise: nextExercise,
            usesMetricWeight: usesMetricWeight
        )

        let content = ActivityContent(state: updatedState, staleDate: Date().addingTimeInterval(60))

        Task {
            await activity.update(content)
        }
    }

    /// End the Live Activity
    func endActivity(showSummary: Bool = true) {
        guard let activity = currentActivity else { return }

        Task {
            if showSummary {
                // Show final state briefly before dismissing
                await activity.end(nil, dismissalPolicy: .after(.now + 5))
            } else {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
            currentActivity = nil
        }
    }

    /// Cancel all active workout activities (cleanup)
    func cancelAllActivities() {
        Task {
            for activity in Activity<TraiWorkoutAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
            currentActivity = nil
        }
    }
}
