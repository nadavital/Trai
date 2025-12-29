//
//  GeminiFunctionExecutor+PlanWorkout.swift
//  Plates
//
//  Plan and workout function execution
//

import Foundation
import SwiftData

extension GeminiFunctionExecutor {

    // MARK: - Plan Functions

    func executeGetUserPlan() -> ExecutionResult {
        guard let profile = userProfile else {
            return .dataResponse(FunctionResult(
                name: "get_user_plan",
                response: ["error": "No user profile found"]
            ))
        }

        return .dataResponse(FunctionResult(
            name: "get_user_plan",
            response: [
                "goal": profile.goal.rawValue,
                "daily_targets": [
                    "calories": profile.dailyCalorieGoal,
                    "protein": profile.dailyProteinGoal,
                    "carbs": profile.dailyCarbsGoal,
                    "fat": profile.dailyFatGoal
                ],
                "activity_level": profile.activityLevel,
                "current_weight_kg": profile.currentWeightKg ?? 0,
                "target_weight_kg": profile.targetWeightKg ?? 0
            ]
        ))
    }

    func executeUpdateUserPlan(_ args: [String: Any]) -> ExecutionResult {
        let suggestion = PlanUpdateSuggestion(
            calories: args["calories"] as? Int,
            proteinGrams: args["protein_grams"] as? Int,
            carbsGrams: args["carbs_grams"] as? Int,
            fatGrams: args["fat_grams"] as? Int,
            goal: args["goal"] as? String,
            rationale: args["rationale"] as? String
        )

        return .suggestedPlanUpdate(suggestion)
    }

    // MARK: - Workout Functions

    func executeGetRecentWorkouts(_ args: [String: Any]) -> ExecutionResult {
        let limit = args["limit"] as? Int ?? 5

        let descriptor = FetchDescriptor<WorkoutSession>(
            sortBy: [SortDescriptor(\.loggedAt, order: .reverse)]
        )

        var workouts = (try? modelContext.fetch(descriptor)) ?? []
        workouts = Array(workouts.prefix(limit))

        let formattedWorkouts = workouts.map { workout -> [String: Any] in
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "MMM d, h:mm a"
            return [
                "id": workout.id.uuidString,
                "name": workout.displayName,
                "type": workout.isStrengthTraining ? "strength" : "cardio",
                "date": dateFormatter.string(from: workout.loggedAt),
                "duration_minutes": workout.durationMinutes ?? 0,
                "sets": workout.sets,
                "reps": workout.reps,
                "weight_kg": workout.weightKg ?? 0
            ]
        }

        return .dataResponse(FunctionResult(
            name: "get_recent_workouts",
            response: [
                "workouts": formattedWorkouts,
                "count": workouts.count
            ]
        ))
    }

    func executeLogWorkout(_ args: [String: Any]) -> ExecutionResult {
        guard let type = args["type"] as? String else {
            return .dataResponse(FunctionResult(
                name: "log_workout",
                response: ["error": "Missing workout type"]
            ))
        }

        let durationMinutes = args["duration_minutes"] as? Int
        let notes = args["notes"] as? String

        // Create workout session
        let workout = WorkoutSession()
        workout.exerciseName = type.capitalized

        let isStrength = ["strength", "weights", "lifting"].contains(type.lowercased())
        if isStrength {
            workout.sets = 1  // Default to 1 set so isStrengthTraining computed property works
            workout.reps = 1
        }

        if let duration = durationMinutes {
            workout.durationMinutes = Double(duration)
        }

        if let notes = notes {
            workout.notes = notes
        }

        modelContext.insert(workout)
        try? modelContext.save()

        return .dataResponse(FunctionResult(
            name: "log_workout",
            response: [
                "success": true,
                "workout_id": workout.id.uuidString,
                "type": type,
                "duration_minutes": durationMinutes ?? 0
            ]
        ))
    }
}
