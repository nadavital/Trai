//
//  LiveActivityIntents.swift
//  Trai
//
//  App Intents for Live Activity buttons (Add Set, Toggle Pause)
//  Note: The actual intents are defined in TraiWidgets/AppIntent.swift
//  This file contains the main app's handling logic.
//

import Foundation

// MARK: - App Group Constants

/// Constants for Live Activity intent communication via App Groups
enum LiveActivityIntentKeys {
    static let suiteName = "group.com.nadav.trai"
    static let addSetTimestamp = "liveActivityAddSetTimestamp"
    static let togglePauseTimestamp = "liveActivityTogglePauseTimestamp"
}
