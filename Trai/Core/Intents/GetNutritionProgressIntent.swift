//
//  GetNutritionProgressIntent.swift
//  Trai
//
//  Aggregate-only nutrition progress for authenticated Siri and Shortcuts requests.
//

import AppIntents
import SwiftData

/// A return-only snapshot. Transient entities cannot be browsed or resolved later,
/// which keeps private nutrition data out of Spotlight and entity suggestions.
struct NutritionProgressEntity: TransientAppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Nutrition Progress"

    @Property(title: "Calories Consumed")
    var caloriesConsumed: Int

    @Property(title: "Calorie Target")
    var calorieTarget: Int

    @Property(title: "Protein Consumed")
    var proteinConsumedGrams: Int

    @Property(title: "Protein Target")
    var proteinTargetGrams: Int

    @Property(title: "Carbohydrates Consumed")
    var carbohydratesConsumedGrams: Int

    @Property(title: "Fat Consumed")
    var fatConsumedGrams: Int

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "Today's nutrition",
            subtitle: "\(caloriesConsumed) of \(calorieTarget) calories"
        )
    }

    init() {
        caloriesConsumed = 0
        calorieTarget = 0
        proteinConsumedGrams = 0
        proteinTargetGrams = 0
        carbohydratesConsumedGrams = 0
        fatConsumedGrams = 0
    }

    init(
        caloriesConsumed: Int,
        calorieTarget: Int,
        proteinConsumedGrams: Int,
        proteinTargetGrams: Int,
        carbohydratesConsumedGrams: Int,
        fatConsumedGrams: Int
    ) {
        self.caloriesConsumed = caloriesConsumed
        self.calorieTarget = calorieTarget
        self.proteinConsumedGrams = proteinConsumedGrams
        self.proteinTargetGrams = proteinTargetGrams
        self.carbohydratesConsumedGrams = carbohydratesConsumedGrams
        self.fatConsumedGrams = fatConsumedGrams
    }
}

struct GetNutritionProgressIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Nutrition Progress"
    static var description = IntentDescription(
        "Get today's aggregate nutrition progress from Trai"
    )
    static var supportedModes: IntentModes { .background }
    static var authenticationPolicy: IntentAuthenticationPolicy { .requiresAuthentication }

    @available(iOS 27.0, *)
    static var allowedExecutionTargets: ExecutionTargets { .main }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<NutritionProgressEntity> {
        guard let container = TraiApp.sharedModelContainer else {
            throw NutritionProgressIntentError.storeUnavailable
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

        let foodEntries: [FoodEntry]
        let hasWorkoutToday: Bool
        let profile: UserProfile
        do {
            foodEntries = try context.fetch(foodDescriptor)
            hasWorkoutToday = try context.fetchCount(workoutDescriptor) > 0
            guard let storedProfile = try context.fetch(FetchDescriptor<UserProfile>()).first else {
                throw NutritionProgressIntentError.profileUnavailable
            }
            profile = storedProfile
        } catch let error as NutritionProgressIntentError {
            throw error
        } catch {
            throw NutritionProgressIntentError.readFailed
        }

        let progress = NutritionProgressEntity(
            caloriesConsumed: foodEntries.reduce(0) { $0 + $1.calories },
            calorieTarget: profile.effectiveCalorieGoal(hasWorkoutToday: hasWorkoutToday),
            proteinConsumedGrams: Int(foodEntries.reduce(0.0) { $0 + $1.proteinGrams }.rounded()),
            proteinTargetGrams: profile.dailyProteinGoal,
            carbohydratesConsumedGrams: Int(foodEntries.reduce(0.0) { $0 + $1.carbsGrams }.rounded()),
            fatConsumedGrams: Int(foodEntries.reduce(0.0) { $0 + $1.fatGrams }.rounded())
        )

        let message = "You've logged \(progress.caloriesConsumed) of \(progress.calorieTarget) calories and \(progress.proteinConsumedGrams) of \(progress.proteinTargetGrams) grams of protein today."
        return .result(value: progress, dialog: IntentDialog(stringLiteral: message))
    }
}

private enum NutritionProgressIntentError: Error, CustomLocalizedStringResourceConvertible {
    case storeUnavailable
    case profileUnavailable
    case readFailed

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .storeUnavailable:
            "Open Trai once so Siri can access your nutrition progress."
        case .profileUnavailable:
            "Finish setting up Trai before asking for nutrition progress."
        case .readFailed:
            "Trai couldn't read your nutrition progress right now. Please try again."
        }
    }
}
