//
//  ReminderCompletion.swift
//  Trai
//
//  Tracks when a user marks a reminder as complete.
//

import Foundation
import SwiftData

@Model
final class ReminderCompletion {
    var id: UUID = UUID()
    var reminderId: UUID = UUID()
    var completedAt: Date = Date()
    /// Whether the reminder was completed on time (before or within 30 min of scheduled time)
    var wasOnTime: Bool = true

    init(
        reminderId: UUID,
        completedAt: Date = Date(),
        wasOnTime: Bool = true
    ) {
        self.id = UUID()
        self.reminderId = reminderId
        self.completedAt = completedAt
        self.wasOnTime = wasOnTime
    }
}

// MARK: - Helpers

extension ReminderCompletion {
    /// Check if this completion is for a specific date (ignoring time)
    func isForDate(_ date: Date) -> Bool {
        Calendar.current.isDate(completedAt, inSameDayAs: date)
    }
}
