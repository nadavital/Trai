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
        static let pendingContextAttachment = "pendingTraiChatContextAttachment"
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

nonisolated struct PendingTraiChatLaunchRequest {
    var prompt: String = ""
    var launchLabel: String = ""
    var focusedFoodEntryId: UUID?
    var actionKind: PendingTraiChatActionKind?
    var contextAttachmentStorageValue: String = ""

    func write(to defaults: UserDefaults = .standard) {
        defaults.set(prompt, forKey: SharedStorageKeys.Chat.pendingPrompt)
        defaults.set(launchLabel, forKey: SharedStorageKeys.Chat.pendingLaunchLabel)
        defaults.set(focusedFoodEntryId?.uuidString ?? "", forKey: SharedStorageKeys.Chat.pendingFocusedFoodEntryId)
        defaults.set(actionKind?.rawValue ?? "", forKey: SharedStorageKeys.Chat.pendingActionKind)
        defaults.set(contextAttachmentStorageValue, forKey: SharedStorageKeys.Chat.pendingContextAttachment)
    }

    static func clear(in defaults: UserDefaults = .standard) {
        Self().write(to: defaults)
    }
}
