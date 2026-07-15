//
//  GetDailySummaryIntent.swift
//  Trai
//
//  A privacy-conscious, structured daily summary for Siri and Shortcuts.
//

import AppIntents
import SwiftData

struct GetDailySummaryIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Daily Summary"
    static let description = IntentDescription(
        "Get today's logged nutrition and workout progress from Trai"
    )
    static var supportedModes: IntentModes { .background }
    static var authenticationPolicy: IntentAuthenticationPolicy { .requiresAuthentication }

    @available(iOS 27.0, *)
    static var allowedExecutionTargets: ExecutionTargets { .main }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<String> {
        guard let container = TraiApp.sharedModelContainer else {
            let message = "Open Trai once so Siri can access your daily summary."
            return .result(value: message, dialog: IntentDialog(stringLiteral: message))
        }

        let context = container.mainContext
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? .distantFuture

        let foodDescriptor = FetchDescriptor<FoodEntry>(
            predicate: #Predicate { $0.loggedAt >= startOfDay && $0.loggedAt < endOfDay }
        )
        let workoutDescriptor = FetchDescriptor<LiveWorkout>(
            predicate: #Predicate { $0.startedAt >= startOfDay && $0.startedAt < endOfDay }
        )
        let profile: UserProfile?
        let foodEntries: [FoodEntry]
        let workouts: [LiveWorkout]
        do {
            profile = try context.fetch(FetchDescriptor<UserProfile>()).first
            foodEntries = try context.fetch(foodDescriptor)
            workouts = try context.fetch(workoutDescriptor)
        } catch {
            let message = "Trai couldn't read your daily summary right now. Please try again."
            return .result(value: message, dialog: IntentDialog(stringLiteral: message))
        }

        let calories = foodEntries.reduce(0) { $0 + $1.calories }
        let protein = foodEntries.reduce(0.0) { $0 + $1.proteinGrams }
        let completedWorkouts = workouts.filter { $0.completedAt != nil }.count
        let calorieTarget = profile?.effectiveCalorieGoal(hasWorkoutToday: !workouts.isEmpty)

        var parts = ["You've logged \(calories) calories and \(Int(protein.rounded())) grams of protein today"]
        if let calorieTarget {
            parts.append("your calorie target is \(calorieTarget)")
        }
        if completedWorkouts > 0 {
            parts.append("you completed \(completedWorkouts) workout\(completedWorkouts == 1 ? "" : "s")")
        } else if !workouts.isEmpty {
            parts.append("you have a workout in progress")
        }

        let message = parts.joined(separator: ", ") + "."
        return .result(value: message, dialog: IntentDialog(stringLiteral: message))
    }
}
