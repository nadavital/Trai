//
//  LiveActivityActionIntents.swift
//  Shared
//
//  Shared Live Activity actions compiled into both the app and widget targets.
//

import ActivityKit
import AppIntents
import Foundation

/// Intent for adding a set to the current strength exercise from Live Activity.
struct AddSetIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Add Set"
    static let description = IntentDescription("Add a set to the current strength exercise")
    static let openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult {
        if let defaults = UserDefaults(suiteName: SharedStorageKeys.AppGroup.suiteName) {
            let timestamp = Date().timeIntervalSince1970
            defaults.set(timestamp, forKey: SharedStorageKeys.AppGroup.liveActivityAddSetTimestamp)
            Self.appendLiveActivityIntentTimestamp(
                timestamp,
                key: SharedStorageKeys.AppGroup.liveActivityAddSetTimestamps,
                defaults: defaults
            )
            defaults.set(AppRoute.workout(templateID: nil, templateName: nil).urlString, forKey: SharedStorageKeys.AppRouting.pendingRoute)
        }
        await LiveActivityIntentUpdater.applyAddSetFeedback()
        return .result()
    }
}

/// Intent for toggling workout pause state from Live Activity.
struct TogglePauseIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Toggle Pause"
    static let description = IntentDescription("Pause or resume the current workout")
    static let openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult {
        if let defaults = UserDefaults(suiteName: SharedStorageKeys.AppGroup.suiteName) {
            let timestamp = Date().timeIntervalSince1970
            defaults.set(timestamp, forKey: SharedStorageKeys.AppGroup.liveActivityTogglePauseTimestamp)
            AddSetIntent.appendLiveActivityIntentTimestamp(
                timestamp,
                key: SharedStorageKeys.AppGroup.liveActivityTogglePauseTimestamps,
                defaults: defaults
            )
            defaults.set(AppRoute.workout(templateID: nil, templateName: nil).urlString, forKey: SharedStorageKeys.AppRouting.pendingRoute)
        }
        await LiveActivityIntentUpdater.applyTogglePauseFeedback()
        return .result()
    }
}

/// Intent for moving from the current exercise to the next one from Live Activity.
struct AdvanceExerciseIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Up Next"
    static let description = IntentDescription("Move to the next exercise in the active workout")
    static let openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult {
        if let defaults = UserDefaults(suiteName: SharedStorageKeys.AppGroup.suiteName) {
            let timestamp = Date().timeIntervalSince1970
            defaults.set(timestamp, forKey: SharedStorageKeys.AppGroup.liveActivityAdvanceExerciseTimestamp)
            AddSetIntent.appendLiveActivityIntentTimestamp(
                timestamp,
                key: SharedStorageKeys.AppGroup.liveActivityAdvanceExerciseTimestamps,
                defaults: defaults
            )
            defaults.set(AppRoute.workout(templateID: nil, templateName: nil).urlString, forKey: SharedStorageKeys.AppRouting.pendingRoute)
        }
        await LiveActivityIntentUpdater.applyAdvanceExerciseFeedback()
        return .result()
    }
}

private extension AddSetIntent {
    static func appendLiveActivityIntentTimestamp(_ timestamp: TimeInterval, key: String, defaults: UserDefaults) {
        var timestamps = defaults.array(forKey: key) as? [Double] ?? []
        timestamps.append(timestamp)
        defaults.set(Array(timestamps.suffix(20)), forKey: key)
    }
}

private enum LiveActivityIntentUpdater {
    static func applyAddSetFeedback() async {
        guard let activity = currentWorkoutActivity() else { return }
        let state = activity.content.state
        let updatedState = state.copy(
            totalSets: state.totalSets + 1,
            currentExerciseTotalSets: (state.currentExerciseTotalSets ?? 0) + 1
        )
        await activity.update(ActivityContent(state: updatedState, staleDate: Date().addingTimeInterval(60)))
    }

    static func applyTogglePauseFeedback() async {
        guard let activity = currentWorkoutActivity() else { return }
        let state = activity.content.state
        let elapsedSeconds = state.isPaused
            ? state.elapsedSeconds
            : max(state.elapsedSeconds, Int(Date().timeIntervalSince(activity.attributes.startedAt)))
        let updatedState = state.copy(
            elapsedSeconds: elapsedSeconds,
            isPaused: !state.isPaused
        )
        await activity.update(ActivityContent(state: updatedState, staleDate: Date().addingTimeInterval(60)))
    }

    static func applyAdvanceExerciseFeedback() async {
        guard let activity = currentWorkoutActivity() else { return }
        let state = activity.content.state
        guard let nextExercise = state.nextExercise else { return }
        let updatedState = state.copy(
            currentExercise: nextExercise,
            currentExerciseCompletedSets: 0,
            resetCurrentWork: true
        )
        await activity.update(ActivityContent(state: updatedState, staleDate: Date().addingTimeInterval(60)))
    }

    private static func currentWorkoutActivity() -> Activity<TraiWorkoutAttributes>? {
        Activity<TraiWorkoutAttributes>.activities.max { lhs, rhs in
            let lhsState = lhs.content.state
            let rhsState = rhs.content.state
            let lhsHasWorkoutContext = lhsState.currentExercise != nil || lhsState.canUseSetShortcut
            let rhsHasWorkoutContext = rhsState.currentExercise != nil || rhsState.canUseSetShortcut
            if lhsHasWorkoutContext != rhsHasWorkoutContext {
                return !lhsHasWorkoutContext && rhsHasWorkoutContext
            }
            return lhs.attributes.startedAt < rhs.attributes.startedAt
        }
    }
}

private extension TraiWorkoutAttributes.ContentState {
    func copy(
        elapsedSeconds: Int? = nil,
        currentExercise: String? = nil,
        currentDetail: String? = nil,
        totalSets: Int? = nil,
        isPaused: Bool? = nil,
        currentWeightKg: Double? = nil,
        currentWeightLbs: Double? = nil,
        currentReps: Int? = nil,
        currentExerciseCompletedSets: Int? = nil,
        currentExerciseTotalSets: Int? = nil,
        resetCurrentWork: Bool = false
    ) -> TraiWorkoutAttributes.ContentState {
        TraiWorkoutAttributes.ContentState(
            elapsedSeconds: elapsedSeconds ?? self.elapsedSeconds,
            currentExercise: currentExercise ?? self.currentExercise,
            currentEquipment: currentEquipment,
            currentDetail: resetCurrentWork ? nil : (currentDetail ?? self.currentDetail),
            completedSets: completedSets,
            totalSets: totalSets ?? self.totalSets,
            heartRate: heartRate,
            isPaused: isPaused ?? self.isPaused,
            currentWeightKg: resetCurrentWork ? nil : (currentWeightKg ?? self.currentWeightKg),
            currentWeightLbs: resetCurrentWork ? nil : (currentWeightLbs ?? self.currentWeightLbs),
            currentReps: resetCurrentWork ? nil : (currentReps ?? self.currentReps),
            totalVolumeKg: totalVolumeKg,
            totalVolumeLbs: totalVolumeLbs,
            nextExercise: nextExercise,
            usesMetricWeight: usesMetricWeight,
            progressCompleted: progressCompleted,
            progressTotal: progressTotal,
            progressLabel: progressLabel,
            supportsSetShortcut: supportsSetShortcut ?? true,
            currentExerciseCompletedSets: currentExerciseCompletedSets ?? self.currentExerciseCompletedSets,
            currentExerciseTotalSets: resetCurrentWork ? nil : (currentExerciseTotalSets ?? self.currentExerciseTotalSets),
            currentExerciseIndex: currentExerciseIndex,
            exerciseTotal: exerciseTotal
        )
    }
}
