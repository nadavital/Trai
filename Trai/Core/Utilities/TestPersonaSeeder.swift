import Foundation
import SwiftData

/// Ephemeral, simulator-only sample history for computer-driven product walkthroughs.
/// The caller supplies an in-memory ModelContainer; no sample record is exported to Health.
@MainActor
enum TestPersonaSeeder {
    static func seed(_ persona: AppLaunchArguments.TestPersona, in container: ModelContainer) {
        let context = container.mainContext
        guard ((try? context.fetch(FetchDescriptor<UserProfile>())) ?? []).isEmpty else { return }

        let profile = UserProfile()
        profile.name = switch persona {
        case .new: "Avery"
        case .consistent: "Jordan"
        case .returning: "Casey"
        }
        profile.hasCompletedOnboarding = persona != .new
        profile.goal = persona == .returning ? .health : .recomposition
        profile.activityLevel = persona == .consistent ? "active" : "moderate"
        profile.workoutExperienceLevel = persona == .consistent ? "intermediate" : "beginner"
        profile.preferredWorkoutDays = persona == .consistent ? 4 : 3
        profile.weeklyWorkoutSessionGoal = persona == .consistent ? 4 : 3
        profile.currentWeightKg = persona == .consistent ? 72.4 : 81.2
        profile.dailyCalorieGoal = persona == .consistent ? 2250 : 2050
        profile.dailyProteinGoal = persona == .consistent ? 145 : 125
        profile.dailyCarbsGoal = persona == .consistent ? 240 : 215
        profile.dailyFatGoal = persona == .consistent ? 70 : 65
        profile.syncFoodToHealthKit = false
        profile.syncWeightToHealthKit = false
        if persona == .consistent {
            profile.workoutPlan = consistentWorkoutPlan()
            profile.defaultWorkoutActionValue = .recommendedWorkout
            profile.workoutPlanGeneratedAt = date(daysAgo: 20, hour: 10)
        }
        context.insert(profile)

        switch persona {
        case .new:
            break
        case .consistent:
            addFood("Greek yogurt, berries and oats", meal: "breakfast", daysAgo: 0,
                    calories: 420, protein: 29, carbs: 56, fat: 10, context: context)
            addFood("Chicken and rice bowl", meal: "lunch", daysAgo: 0,
                    calories: 640, protein: 43, carbs: 72, fat: 18, context: context)
            addFood("Egg toast and fruit", meal: "breakfast", daysAgo: 1,
                    calories: 480, protein: 24, carbs: 58, fat: 17, context: context)
            addFood("Salmon, potatoes and greens", meal: "dinner", daysAgo: 1,
                    calories: 710, protein: 44, carbs: 62, fat: 28, context: context)
            addWorkout("Strength training", daysAgo: 0, minutes: 48, context: context)
            addWorkout("Outdoor run", daysAgo: 3, minutes: 32, context: context)
            addWorkout("Strength training", daysAgo: 5, minutes: 45, context: context)
            for (name, kilograms, repetitions) in [("Bench Press", 70.0, 8), ("Goblet Squat", 24.0, 12), ("Pull Up", 0.0, 8)] {
                let history = ExerciseHistory()
                history.exerciseName = name
                history.performedAt = date(daysAgo: 2, hour: 17)
                history.bestSetWeightKg = kilograms
                history.bestSetWeightLbs = kilograms * WeightUtility.kgToLbs
                history.bestSetReps = repetitions
                history.totalSets = 3
                history.totalReps = repetitions * 3
                history.totalVolume = kilograms * Double(repetitions * 3)
                context.insert(history)
            }
            context.insert(WeightEntry(weightKg: 72.4, loggedAt: date(daysAgo: 1, hour: 8)))
            context.insert(WeightEntry(weightKg: 72.8, loggedAt: date(daysAgo: 8, hour: 8)))
        case .returning:
            addFood("Turkey sandwich and apple", meal: "lunch", daysAgo: 12,
                    calories: 560, protein: 31, carbs: 63, fat: 20, context: context)
            addFood("Vegetable pasta", meal: "dinner", daysAgo: 13,
                    calories: 620, protein: 19, carbs: 82, fat: 23, context: context)
            addWorkout("Walking", daysAgo: 14, minutes: 30, context: context)
            context.insert(WeightEntry(weightKg: 81.2, loggedAt: date(daysAgo: 15, hour: 8)))
        }

        do {
            try context.save()
            NSLog("Test persona seeded: %@ (ephemeral)", persona.rawValue)
        } catch {
            assertionFailure("Could not seed test persona: \(error)")
        }
    }

    private static func addFood(
        _ name: String, meal: String, daysAgo: Int,
        calories: Int, protein: Double, carbs: Double, fat: Double,
        context: ModelContext
    ) {
        let entry = FoodEntry(name: name, mealType: meal, calories: calories,
                              proteinGrams: protein, carbsGrams: carbs, fatGrams: fat)
        entry.loggedAt = date(daysAgo: daysAgo, hour: meal == "breakfast" ? 8 : meal == "lunch" ? 13 : 19)
        entry.inputMethod = "manual"
        context.insert(entry)
    }

    private static func addWorkout(_ name: String, daysAgo: Int, minutes: Double, context: ModelContext) {
        let workout = WorkoutSession()
        workout.exerciseName = name
        workout.durationMinutes = minutes
        if name == "Strength training" {
            workout.sets = 3
            workout.reps = 8
        }
        workout.loggedAt = min(date(daysAgo: daysAgo, hour: 17), Date())
        workout.notes = "Sample session for simulator testing"
        context.insert(workout)
    }

    private static func date(daysAgo: Int, hour: Int) -> Date {
        let calendar = Calendar.current
        let day = calendar.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
        return calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day) ?? day
    }

    private static func consistentWorkoutPlan() -> WorkoutPlan {
        WorkoutPlan(
            splitType: .upperLower,
            daysPerWeek: 4,
            templates: [
                .init(name: "Upper strength", targetMuscleGroups: ["chest", "back"],
                      exercises: [
                        .init(exerciseName: "Bench Press", muscleGroup: "chest", defaultSets: 3, defaultReps: 8, order: 0),
                        .init(exerciseName: "Seated Row", muscleGroup: "back", defaultSets: 3, defaultReps: 10, order: 1)
                      ], estimatedDurationMinutes: 45, order: 0),
                .init(name: "Lower strength", targetMuscleGroups: ["quads", "hamstrings"],
                      exercises: [
                        .init(exerciseName: "Squat", muscleGroup: "quads", defaultSets: 3, defaultReps: 8, order: 0),
                        .init(exerciseName: "Romanian Deadlift", muscleGroup: "hamstrings", defaultSets: 3, defaultReps: 10, order: 1)
                      ], estimatedDurationMinutes: 45, order: 1),
                .init(name: "Easy run", sessionType: .cardio, focusAreas: ["Aerobic base"], targetMuscleGroups: [],
                      exercises: [
                        .init(exerciseName: "Easy Run", muscleGroup: "cardio", defaultSets: 1, defaultReps: 1, repRange: "30 min", order: 0)
                      ], estimatedDurationMinutes: 30, order: 2),
                .init(name: "Full body", targetMuscleGroups: ["legs", "back", "shoulders"],
                      exercises: [
                        .init(exerciseName: "Lunge", muscleGroup: "legs", defaultSets: 3, defaultReps: 10, order: 0),
                        .init(exerciseName: "Overhead Press", muscleGroup: "shoulders", defaultSets: 3, defaultReps: 8, order: 1)
                      ], estimatedDurationMinutes: 40, order: 3)
            ],
            rationale: "Four practical sessions balance strength and a comfortable run.",
            guidelines: ["Adjust weight when the final reps feel steady."],
            progressionStrategy: .defaultStrategy
        )
    }
}
