//
//  NotificationDelegate.swift
//  Trai
//
//  Handles notification actions (long-press complete/snooze) and tap behavior.
//

import Foundation
import UserNotifications
import SwiftData

/// Delegate to handle notification interactions
@MainActor
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    private let modelContainer: ModelContainer
    private let notificationService: NotificationService

    /// Callback for when a reminder should be shown (notification tapped)
    var onShowReminders: (() -> Void)?

    init(modelContainer: ModelContainer, notificationService: NotificationService) {
        self.modelContainer = modelContainer
        self.notificationService = notificationService
        super.init()

        UNUserNotificationCenter.current().delegate = self
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// Called when user taps on notification (not an action button)
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let actionIdentifier = response.actionIdentifier
        let userInfo = response.notification.request.content.userInfo
        let categoryIdentifier = response.notification.request.content.categoryIdentifier

        Task { @MainActor in
            switch actionIdentifier {
            case NotificationService.NotificationAction.complete.rawValue:
                await handleCompleteAction(userInfo: userInfo)

            case NotificationService.NotificationAction.snooze.rawValue:
                await handleSnoozeAction(
                    content: response.notification.request.content,
                    categoryIdentifier: categoryIdentifier
                )

            case UNNotificationDefaultActionIdentifier:
                // User tapped on the notification itself - show reminders view
                onShowReminders?()

            default:
                break
            }

            completionHandler()
        }
    }

    /// Called when notification arrives while app is in foreground
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let userInfo = notification.request.content.userInfo
        let categoryIdentifier = notification.request.content.categoryIdentifier

        Task { @MainActor in
            // Check if this reminder was already completed today - if so, suppress notification
            if await isReminderCompletedToday(userInfo: userInfo, categoryIdentifier: categoryIdentifier) {
                completionHandler([])
            } else {
                // Show banner, play sound, and keep in notification center
                completionHandler([.banner, .sound, .list])
            }
        }
    }

    /// Check if the reminder in this notification has already been completed today
    private func isReminderCompletedToday(userInfo: [AnyHashable: Any], categoryIdentifier: String) async -> Bool {
        let context = modelContainer.mainContext
        let startOfDay = Calendar.current.startOfDay(for: Date())

        // Determine the reminder ID based on notification type
        let reminderId: UUID?

        if let reminderIdString = userInfo["reminderId"] as? String {
            // Custom reminder
            reminderId = UUID(uuidString: reminderIdString)
        } else if let mealId = userInfo["mealId"] as? String {
            // Meal reminder - use stable UUID matching TodaysRemindersCard
            reminderId = StableUUID.forMeal(mealId)
        } else if categoryIdentifier == NotificationService.NotificationCategory.workoutReminder.rawValue {
            // Workout reminder - use stable UUID
            reminderId = StableUUID.forWorkoutReminder()
        } else {
            // Weight reminder or unknown - no completion tracking
            reminderId = nil
        }

        guard let id = reminderId else { return false }

        // Check if there's a completion record for this reminder today
        let descriptor = FetchDescriptor<ReminderCompletion>(
            predicate: #Predicate { completion in
                completion.reminderId == id && completion.completedAt >= startOfDay
            }
        )

        let completions = (try? context.fetch(descriptor)) ?? []
        return !completions.isEmpty
    }

    // MARK: - Action Handlers

    private func handleCompleteAction(userInfo: [AnyHashable: Any]) async {
        let context = modelContainer.mainContext

        // Try to get reminder ID from userInfo
        if let reminderIdString = userInfo["reminderId"] as? String,
           let reminderId = UUID(uuidString: reminderIdString) {
            // Custom reminder
            let hour = userInfo["reminderHour"] as? Int ?? 0
            let minute = userInfo["reminderMinute"] as? Int ?? 0
            await completeReminder(id: reminderId, hour: hour, minute: minute, context: context)
        } else if let mealId = userInfo["mealId"] as? String {
            // Meal reminder - use stable UUID matching TodaysRemindersCard
            let reminderId = StableUUID.forMeal(mealId)
            let hour = userInfo["reminderHour"] as? Int ?? 0
            let minute = userInfo["reminderMinute"] as? Int ?? 0
            await completeReminder(id: reminderId, hour: hour, minute: minute, context: context)
        }
    }

    private func completeReminder(id: UUID, hour: Int, minute: Int, context: ModelContext) async {
        let calendar = Calendar.current
        let now = Date()
        let currentHour = calendar.component(.hour, from: now)
        let currentMinute = calendar.component(.minute, from: now)
        let currentMinutes = currentHour * 60 + currentMinute
        let reminderMinutes = hour * 60 + minute

        // We no longer track on-time status meaningfully, just set to true
        let completion = ReminderCompletion(
            reminderId: id,
            completedAt: now,
            wasOnTime: currentMinutes <= reminderMinutes + 30
        )
        context.insert(completion)
        try? context.save()
    }

    private func handleSnoozeAction(
        content: UNNotificationContent,
        categoryIdentifier: String
    ) async {
        guard let category = NotificationService.NotificationCategory(rawValue: categoryIdentifier) else {
            return
        }

        await notificationService.scheduleSnooze(
            title: content.title,
            body: content.body,
            category: category,
            userInfo: content.userInfo
        )
    }

}
