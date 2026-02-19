//
//  LiveWorkoutUpdatePolicy.swift
//  Trai
//
//  Centralized timing and publish rules for active workout update loops.
//

import Foundation

struct LiveWorkoutUpdatePolicy {
    var foregroundIntentPollInterval: TimeInterval = 2.0
    var interactionBoostIntentPollInterval: TimeInterval = 0.75
    var backgroundIntentPollInterval: TimeInterval = 0.5
    var interactionBoostWindow: TimeInterval = 8.0

    struct WatchPayload: Equatable {
        var roundedHeartRate: Int?
        var heartRateUpdatedAt: Date?
        var roundedCalories: Int
        var caloriesUpdatedAt: Date?
    }

    func intentPollingInterval(
        appState: LiveWorkoutAppState,
        lastInteractionAt: Date?,
        now: Date = Date()
    ) -> TimeInterval {
        if appState != .active {
            return backgroundIntentPollInterval
        }

        if let lastInteractionAt,
           now.timeIntervalSince(lastInteractionAt) <= interactionBoostWindow {
            return interactionBoostIntentPollInterval
        }

        return foregroundIntentPollInterval
    }

    func shouldPublishWatchPayload(previous: WatchPayload?, next: WatchPayload) -> Bool {
        previous != next
    }
}

enum LiveWorkoutAppState {
    case active
    case inactive
    case background
}
