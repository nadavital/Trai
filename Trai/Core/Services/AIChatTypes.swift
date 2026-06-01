//
//  AIChatTypes.swift
//  Trai
//
//  Types for AI function-calling chat
//

import Foundation

extension AIService {

    // MARK: - Workout Context

    /// Context about an active workout for contextual chat
    struct WorkoutContext: Sendable {
        let workoutName: String
        let workoutType: String
        let focusAreas: [String]
        let elapsedMinutes: Int
        let entriesLogged: Int
        let exercisesTotal: Int
        let currentExercise: String?
        let setsLogged: Int
        let totalVolume: Double
        let targetMuscleGroups: [String]
        let sessionNotes: String?
        let activeGoals: [String]
        let entryDetails: [String]

        var description: String {
            var parts: [String] = []
            let hasActivityEntries = entryDetails.contains { detail in
                detail.localizedStandardContains("tracks ")
            }
            let progressLabel = hasActivityEntries ? "workout entries" : "exercises"
            let currentLabel = hasActivityEntries ? "Current item" : "Current exercise"
            parts.append("Currently doing: \(workoutName)")
            parts.append("Workout type: \(workoutType)")
            if !focusAreas.isEmpty {
                parts.append("Focus areas: \(focusAreas.joined(separator: ", "))")
            }
            parts.append("Time: \(elapsedMinutes) minutes")
            if !targetMuscleGroups.isEmpty {
                parts.append("Target muscles: \(targetMuscleGroups.joined(separator: ", "))")
            }
            if exercisesTotal > 0 {
                parts.append("Logged/added: \(entriesLogged)/\(exercisesTotal) \(progressLabel)")
            }
            if let current = currentExercise {
                parts.append("\(currentLabel): \(current)")
            }
            if setsLogged > 0 {
                parts.append("Strength sets logged: \(setsLogged)")
            }
            if totalVolume > 0 {
                parts.append("Total volume: \(Int(totalVolume)) kg")
            }
            if !entryDetails.isEmpty {
                parts.append("Workout entries:\n- \(entryDetails.joined(separator: "\n- "))")
            }
            if let sessionNotes, !sessionNotes.isEmpty {
                parts.append("Session notes: \(sessionNotes)")
            }
            if !activeGoals.isEmpty {
                parts.append("Active workout goals: \(activeGoals.joined(separator: ", "))")
            }
            return parts.joined(separator: "\n")
        }
    }

    // MARK: - Activity Data

    /// Today's activity data from Apple Health
    struct ActivityData: Sendable {
        let steps: Int
        let activeCalories: Int
        let exerciseMinutes: Int

        nonisolated static let empty = ActivityData(steps: 0, activeCalories: 0, exerciseMinutes: 0)
    }

    // MARK: - Focused Food Entry Context

    struct FocusedFoodEntryContext: Sendable {
        let entryId: UUID
        let name: String
        let loggedAt: Date
        let semanticMeal: String
        let calories: Int
        let proteinGrams: Double
        let carbsGrams: Double
        let fatGrams: Double
        let fiberGrams: Double?
        let sugarGrams: Double?
        let servingSize: String?
        let notes: String?
    }

    // MARK: - Chat Context

    /// Context for function calling chat
    struct ChatFunctionContext: Sendable {
        let profile: UserProfile?
        let todaysFoodEntries: [FoodEntry]
        let currentDateTime: String
        let coachTone: TraiCoachTone
        let memoriesContext: String
        let coachContext: String
        let pendingSuggestion: SuggestedFoodEntry?
        let pendingNutritionPlanSuggestion: PlanUpdateSuggestionEntry?
        let pendingWorkoutPlanSuggestion: WorkoutPlanSuggestionEntry?
        let isIncognitoMode: Bool
        let activeWorkout: WorkoutContext?
        let activityData: ActivityData
        let hasWorkoutToday: Bool
        let focusedFoodEntry: FocusedFoodEntryContext?

        init(
            profile: UserProfile?,
            todaysFoodEntries: [FoodEntry],
            currentDateTime: String,
            coachTone: TraiCoachTone = .encouraging,
            memoriesContext: String,
            coachContext: String = "",
            pendingSuggestion: SuggestedFoodEntry? = nil,
            pendingNutritionPlanSuggestion: PlanUpdateSuggestionEntry? = nil,
            pendingWorkoutPlanSuggestion: WorkoutPlanSuggestionEntry? = nil,
            isIncognitoMode: Bool = false,
            activeWorkout: WorkoutContext? = nil,
            activityData: ActivityData = .empty,
            hasWorkoutToday: Bool = false,
            focusedFoodEntry: FocusedFoodEntryContext? = nil
        ) {
            self.profile = profile
            self.todaysFoodEntries = todaysFoodEntries
            self.currentDateTime = currentDateTime
            self.coachTone = coachTone
            self.memoriesContext = memoriesContext
            self.coachContext = coachContext
            self.pendingSuggestion = pendingSuggestion
            self.pendingNutritionPlanSuggestion = pendingNutritionPlanSuggestion
            self.pendingWorkoutPlanSuggestion = pendingWorkoutPlanSuggestion
            self.isIncognitoMode = isIncognitoMode
            self.activeWorkout = activeWorkout
            self.activityData = activityData
            self.hasWorkoutToday = hasWorkoutToday
            self.focusedFoodEntry = focusedFoodEntry
        }
    }

    // MARK: - Chat Result

    /// Result from function calling chat
    struct ChatFunctionResult: Sendable {
        let message: String
        let suggestedFoods: [SuggestedFoodEntry]
        let planUpdate: PlanUpdateSuggestion?
        let suggestedFoodEdit: SuggestedFoodEdit?
        let suggestedFoodComponentEdit: SuggestedFoodComponentEdit?
        let suggestedWorkoutPlan: WorkoutPlanSuggestionEntry?
        let suggestedWorkout: SuggestedWorkoutEntry?
        let suggestedWorkoutLog: SuggestedWorkoutLog?
        let suggestedReminder: SuggestedReminder?
        let functionsCalled: [String]
        let savedMemories: [String]
    }

    // MARK: - Internal Types

    /// Result from sending a function result back to the AI backend
    struct FunctionFollowUpResult {
        var text: String = ""
        var suggestedFoods: [SuggestedFoodEntry] = []
        var planUpdate: PlanUpdateSuggestion?
        var suggestedFoodEdit: SuggestedFoodEdit?
        var suggestedFoodComponentEdit: SuggestedFoodComponentEdit?
        var suggestedWorkoutPlan: WorkoutPlanSuggestionEntry?
        var suggestedWorkout: SuggestedWorkoutEntry?
        var suggestedWorkoutLog: SuggestedWorkoutLog?
        var suggestedReminder: SuggestedReminder?
        var savedMemories: [String] = []
        var accumulatedParts: [TraiAIPart] = []

        var hasSuggestion: Bool {
            !suggestedFoods.isEmpty ||
            planUpdate != nil ||
            suggestedFoodEdit != nil ||
            suggestedFoodComponentEdit != nil ||
            suggestedWorkoutPlan != nil ||
            suggestedWorkout != nil ||
            suggestedWorkoutLog != nil ||
            suggestedReminder != nil
        }

        mutating func mergeChainedResult(_ chainedResult: FunctionFollowUpResult) {
            if !chainedResult.text.isEmpty {
                text += chainedResult.text
            }
            suggestedFoods.append(contentsOf: chainedResult.suggestedFoods)
            if let plan = chainedResult.planUpdate {
                planUpdate = plan
            }
            if let edit = chainedResult.suggestedFoodEdit {
                suggestedFoodEdit = edit
            }
            if let componentEdit = chainedResult.suggestedFoodComponentEdit {
                suggestedFoodComponentEdit = componentEdit
            }
            if let workoutPlan = chainedResult.suggestedWorkoutPlan {
                suggestedWorkoutPlan = workoutPlan
            }
            if let workout = chainedResult.suggestedWorkout {
                suggestedWorkout = workout
            }
            if let workoutLog = chainedResult.suggestedWorkoutLog {
                suggestedWorkoutLog = workoutLog
            }
            if let reminder = chainedResult.suggestedReminder {
                suggestedReminder = reminder
            }
            savedMemories.append(contentsOf: chainedResult.savedMemories)
        }
    }
}
