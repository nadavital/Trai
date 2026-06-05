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

        let staleActivities = Activity<TraiWorkoutAttributes>.activities
        if let matchingActivity = staleActivities.first(where: { activity in
            activity.attributes.workoutName == workoutName
                && abs(activity.attributes.startedAt.timeIntervalSince(startedAt)) < 2
        }) {
            currentActivity = matchingActivity
            Task {
                for activity in staleActivities where activity.id != matchingActivity.id {
                    await activity.end(nil, dismissalPolicy: .immediate)
                }
            }
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
            isPaused: false,
            supportsSetShortcut: false
        )

        let content = ActivityContent(state: initialState, staleDate: Date().addingTimeInterval(60))

        do {
            currentActivity = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
            print("Live Activity started: \(currentActivity?.id ?? "unknown")")
            Task {
                for activity in staleActivities {
                    await activity.end(nil, dismissalPolicy: .immediate)
                }
            }
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
        currentExerciseCompletedSets: Int? = nil,
        currentExerciseTotalSets: Int? = nil,
        currentExerciseIndex: Int? = nil,
        exerciseTotal: Int? = nil
    ) {
        guard let activity = currentActivity else { return }

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
            currentExerciseCompletedSets: currentExerciseCompletedSets,
            currentExerciseTotalSets: currentExerciseTotalSets,
            currentExerciseIndex: currentExerciseIndex,
            exerciseTotal: exerciseTotal
        )

        let content = ActivityContent(state: updatedState, staleDate: Date().addingTimeInterval(60))

        Task {
            await activity.update(content)
        }
    }

    /// End the Live Activity
    func endActivity(showSummary: Bool = true) {
        let activeActivity = currentActivity
        let dismissalPolicy: ActivityUIDismissalPolicy = showSummary ? .after(.now + 5) : .immediate

        Task {
            if let activeActivity {
                await activeActivity.end(nil, dismissalPolicy: dismissalPolicy)
            }

            for activity in Activity<TraiWorkoutAttributes>.activities where activity.id != activeActivity?.id {
                await activity.end(nil, dismissalPolicy: dismissalPolicy)
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
