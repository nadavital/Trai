//
//  SharedStorageKeys.swift
//  Shared
//
//  Cross-target storage keys used by app and widget extension.
//

import Foundation

nonisolated enum SharedStorageKeys {
    enum AppGroup {
        static let suiteName = "group.com.nadav.trai"
        static let widgetData = "widgetData"
        static let pendingFoodLogs = "pendingFoodLogs"
        static let liveActivityAddSetTimestamp = "liveActivityAddSetTimestamp"
        static let liveActivityTogglePauseTimestamp = "liveActivityTogglePauseTimestamp"
        static let liveActivityAdvanceExerciseTimestamp = "liveActivityAdvanceExerciseTimestamp"
        static let liveActivityAddSetTimestamps = "liveActivityAddSetTimestamps"
        static let liveActivityTogglePauseTimestamps = "liveActivityTogglePauseTimestamps"
        static let liveActivityAdvanceExerciseTimestamps = "liveActivityAdvanceExerciseTimestamps"
    }

    enum Chat {
        static let currentSessionId = "currentChatSessionId"
        static let pendingOpenSessionId = "pendingTraiChatOpenSessionId"
        static let pendingPrompt = "pendingTraiChatPrompt"
        static let pendingLaunchLabel = "pendingTraiChatLaunchLabel"
        static let pendingFocusedFoodEntryId = "pendingTraiChatFocusedFoodEntryId"
        static let pendingActionKind = "pendingTraiChatActionKind"
    }

    enum AppRouting {
        static let pendingRoute = "pendingAppRoute"
    }

    enum LegacyLaunchIntents {
        static let openFoodCamera = "openFoodCameraFromIntent"
        static let startWorkout = "startWorkoutFromIntent"
    }
}

nonisolated enum PendingTraiChatActionKind: String {
    case nutritionPlanReview
}
