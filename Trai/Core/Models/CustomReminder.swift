//
//  CustomReminder.swift
//  Trai
//
//  User-defined custom reminders with flexible scheduling.
//

import Foundation
import SwiftData

@Model
final class CustomReminder {
    var id: UUID = UUID()
    var title: String = ""
    var body: String = ""
    var hour: Int = 9
    var minute: Int = 0
    /// Comma-separated weekday numbers (1=Sun, 2=Mon, ..., 7=Sat). Empty string = daily.
    var repeatDays: String = ""
    var isEnabled: Bool = true
    var createdAt: Date = Date()

    init(
        title: String = "",
        body: String = "",
        hour: Int = 9,
        minute: Int = 0,
        repeatDays: String = "",
        isEnabled: Bool = true
    ) {
        self.title = title
        self.body = body
        self.hour = hour
        self.minute = minute
        self.repeatDays = repeatDays
        self.isEnabled = isEnabled
        self.createdAt = Date()
    }

    // MARK: - Computed Properties

    /// The repeat days as a set of integers (1-7)
    var repeatDaysSet: Set<Int> {
        get {
            Set(repeatDays.split(separator: ",").compactMap { Int($0) })
        }
        set {
            repeatDays = newValue.sorted().map(String.init).joined(separator: ",")
        }
    }

    /// Whether this reminder repeats daily (no specific days selected)
    var isDaily: Bool {
        repeatDays.isEmpty
    }

    /// Formatted time string (e.g., "9:00 AM")
    var formattedTime: String {
        let components = DateComponents(hour: hour, minute: minute)
        guard let date = Calendar.current.date(from: components) else {
            return "\(hour):\(String(format: "%02d", minute))"
        }
        return date.formatted(date: .omitted, time: .shortened)
    }

    /// Formatted repeat schedule description
    var scheduleDescription: String {
        if isDaily {
            return "Every day"
        }

        let dayNames = ["", "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        let days = repeatDaysSet.sorted().compactMap { dayNames[safe: $0] }

        if days.count == 7 {
            return "Every day"
        } else if days.count == 5 && repeatDaysSet == Set([2, 3, 4, 5, 6]) {
            return "Weekdays"
        } else if days.count == 2 && repeatDaysSet == Set([1, 7]) {
            return "Weekends"
        } else {
            return days.joined(separator: ", ")
        }
    }
}

// MARK: - Array Safe Subscript

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
