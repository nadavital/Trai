import XCTest
import SwiftData
@testable import Trai

final class UserProfileNutritionTargetsTests: XCTestCase {
    func testNewProfilesExposeNutritionTargets() {
        let profile = UserProfile()

        XCTAssertEqual(profile.effectiveCalorieGoal(hasWorkoutToday: false), 2_000)
        XCTAssertEqual(profile.dailyProteinGoal, 150)
        XCTAssertEqual(profile.goalFor(.protein), 150)
    }

    func testTrainingAndRestDayCaloriesAdjustEffectiveTarget() {
        let profile = UserProfile()
        profile.dailyCalorieGoal = 2_200
        profile.trainingDayCalories = 2_450
        profile.restDayCalories = 2_050

        XCTAssertEqual(profile.effectiveCalorieGoal(hasWorkoutToday: true), 2_450)
        XCTAssertEqual(profile.effectiveCalorieGoal(hasWorkoutToday: false), 2_050)
    }

    func testNutritionTargetsDoNotBlockWorkoutPlanRequestBuilding() {
        let profile = UserProfile()
        profile.name = "Sam"
        profile.preferredWorkoutDays = 4
        profile.workoutTimePerSession = 50

        let request = profile.buildWorkoutPlanRequest()

        XCTAssertEqual(request.name, "Sam")
        XCTAssertEqual(request.availableDays, 4)
        XCTAssertEqual(request.timePerWorkout, 50)
    }

    func testWidgetSnapshotDoesNotTreatInProgressLiveWorkoutAsCompletedTrainingDay() throws {
        let context = try makeWidgetSnapshotContext()
        let profile = UserProfile()
        profile.dailyCalorieGoal = 2_200
        profile.trainingDayCalories = 2_500
        profile.restDayCalories = 2_000
        context.insert(profile)

        let workout = LiveWorkout(name: "In Progress", workoutType: .strength)
        workout.startedAt = Date()
        context.insert(workout)
        try context.save()

        let snapshot = WidgetDataSnapshotBuilder().build(modelContext: context)

        XCTAssertFalse(snapshot.todayWorkoutCompleted)
        XCTAssertEqual(snapshot.calorieGoal, 2_000)
    }

    func testWidgetSnapshotCountsCompletedLiveWorkoutAsTrainingDay() throws {
        let context = try makeWidgetSnapshotContext()
        let profile = UserProfile()
        profile.dailyCalorieGoal = 2_200
        profile.trainingDayCalories = 2_500
        profile.restDayCalories = 2_000
        context.insert(profile)

        let workout = LiveWorkout(name: "Done", workoutType: .strength)
        workout.startedAt = Date().addingTimeInterval(-45 * 60)
        workout.completedAt = Date()
        context.insert(workout)
        try context.save()

        let snapshot = WidgetDataSnapshotBuilder().build(modelContext: context)

        XCTAssertTrue(snapshot.todayWorkoutCompleted)
        XCTAssertEqual(snapshot.calorieGoal, 2_500)
    }

    func testWidgetWorkoutActionUsesRecommendedTemplateRoute() throws {
        let templateID = UUID()
        let data = WidgetData.empty.updatingWorkoutAction(
            recommendedWorkout: "Upper Strength",
            recommendedWorkoutTemplateID: templateID,
            todayWorkoutCompleted: false
        )

        let route = try XCTUnwrap(data.workoutActionRoute)

        XCTAssertEqual(route, .workout(templateID: templateID, templateName: "Upper Strength"))
        XCTAssertEqual(data.workoutActionURLString, route.urlString)
    }

    func testWidgetWorkoutActionIsDisabledAfterWorkoutComplete() {
        let data = WidgetData.empty.updatingWorkoutAction(
            recommendedWorkout: "Upper Strength",
            recommendedWorkoutTemplateID: UUID(),
            todayWorkoutCompleted: true
        )

        XCTAssertNil(data.workoutActionRoute)
        XCTAssertNil(data.workoutActionURLString)
    }

    private func makeWidgetSnapshotContext() throws -> ModelContext {
        let schema = Schema([
            UserProfile.self,
            FoodEntry.self,
            Exercise.self,
            WorkoutSession.self,
            WeightEntry.self,
            ChatMessage.self,
            LiveWorkout.self,
            LiveWorkoutEntry.self,
            ExerciseHistory.self,
            CoachMemory.self,
            CoachSignal.self,
            NutritionPlanVersion.self,
            WorkoutPlanVersion.self,
            WorkoutGoal.self,
            CustomReminder.self,
            ReminderCompletion.self,
            SuggestionUsage.self,
            BehaviorEvent.self,
            FoodMemory.self
        ])
        let container = try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        )
        return ModelContext(container)
    }
}

private extension WidgetData {
    func updatingWorkoutAction(
        recommendedWorkout: String?,
        recommendedWorkoutTemplateID: UUID?,
        todayWorkoutCompleted: Bool
    ) -> WidgetData {
        WidgetData(
            caloriesConsumed: caloriesConsumed,
            calorieGoal: calorieGoal,
            proteinConsumed: proteinConsumed,
            proteinGoal: proteinGoal,
            carbsConsumed: carbsConsumed,
            carbsGoal: carbsGoal,
            fatConsumed: fatConsumed,
            fatGoal: fatGoal,
            readyMuscleCount: readyMuscleCount,
            recommendedWorkout: recommendedWorkout,
            recommendedWorkoutTemplateID: recommendedWorkoutTemplateID,
            workoutStreak: workoutStreak,
            todayWorkoutCompleted: todayWorkoutCompleted,
            lastUpdated: lastUpdated
        )
    }
}
