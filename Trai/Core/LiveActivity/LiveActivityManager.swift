//
//  LiveActivityManager.swift
//  Trai
//
//  Live Activity manager for workout tracking.
//

import ActivityKit
import Foundation

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
        startedAt: Date,
        initialState: TraiWorkoutAttributes.ContentState? = nil
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

        let state = initialState ?? TraiWorkoutAttributes.ContentState(
            elapsedSeconds: 0,
            currentExercise: nil,
            completedSets: 0,
            totalSets: 0,
            heartRate: nil,
            isPaused: false,
            supportsSetShortcut: false
        )

        let content = ActivityContent(state: state, staleDate: Date().addingTimeInterval(60))

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
        currentDetail: String? = nil,
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
        usesMetricWeight: Bool = true,
        progressCompleted: Int? = nil,
        progressTotal: Int? = nil,
        progressLabel: String? = nil,
        supportsSetShortcut: Bool = true,
        supportsAdvanceShortcut: Bool? = nil
    ) {
        let updatedState = TraiWorkoutAttributes.ContentState(
            elapsedSeconds: elapsedSeconds,
            currentExercise: currentExercise,
            currentEquipment: currentEquipment,
            currentDetail: currentDetail,
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
            usesMetricWeight: usesMetricWeight,
            progressCompleted: progressCompleted,
            progressTotal: progressTotal,
            progressLabel: progressLabel,
            supportsSetShortcut: supportsSetShortcut,
            supportsAdvanceShortcut: supportsAdvanceShortcut
        )

        updateActivity(state: updatedState)
    }

    func updateActivity(state: TraiWorkoutAttributes.ContentState) {
        guard let activity = currentActivity else { return }

        let content = ActivityContent(state: state, staleDate: Date().addingTimeInterval(60))

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
