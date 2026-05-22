import XCTest
import SwiftData
@testable import Trai

@MainActor
final class WorkoutSemanticParsingTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUpWithError() throws {
        try super.setUpWithError()
        container = try ModelContainer(
            for: WorkoutGoal.self,
            configurations: ModelConfiguration(
                isStoredInMemoryOnly: true,
                cloudKitDatabase: .none
            )
        )
        context = ModelContext(container)
    }

    override func tearDownWithError() throws {
        context = nil
        container = nil
        try super.tearDownWithError()
    }

    func testWorkoutModeNormalizationHandlesCommonPhrases() {
        XCTAssertEqual(WorkoutMode.normalized(from: "running"), .cardio)
        XCTAssertEqual(WorkoutMode.normalized(from: "strength training"), .strength)
        XCTAssertEqual(WorkoutMode.normalized(from: "weight-lifting"), .strength)
        XCTAssertEqual(WorkoutMode.normalized(from: "bouldering"), .climbing)
        XCTAssertEqual(WorkoutMode.normalized(from: "stretching"), .flexibility)
    }

    func testTargetMuscleParsingHandlesDisplayNames() {
        XCTAssertEqual(LiveWorkout.MuscleGroup.fromTargetStrings(["Full Body"]), [.fullBody])
        XCTAssertEqual(
            LiveWorkout.MuscleGroup.fromTargetStrings(["Lower Body"]),
            LiveWorkout.MuscleGroup.legMuscles
        )
    }

    func testCreateWorkoutGoalNormalizesRunningToCardio() async throws {
        let executor = AIFunctionExecutor(modelContext: context, userProfile: nil)
        let result = await executor.execute(
            .init(
                name: "create_workout_goal",
                arguments: [
                    "title": "Run three times per week",
                    "goal_kind": "frequency",
                    "workout_type": "running",
                    "period_unit": "week",
                    "period_count": 1,
                    "success_criteria": "Complete three cardio sessions in one week."
                ]
            )
        )

        guard case .dataResponse(let functionResult) = result,
              let goal = functionResult.response["goal"] as? [String: Any] else {
            return XCTFail("Expected workout goal response")
        }

        XCTAssertEqual(goal["workout_type"] as? String, WorkoutMode.cardio.rawValue)
        XCTAssertEqual(goal["success_criteria"] as? String, "Complete three cardio sessions in one week.")
    }

    func testUpdateWorkoutGoalNormalizesWeightLiftingToStrength() async throws {
        let goal = WorkoutGoal(
            title: "Move more",
            goalKind: .frequency,
            linkedWorkoutType: .cardio
        )
        context.insert(goal)
        try context.save()

        let executor = AIFunctionExecutor(modelContext: context, userProfile: nil)
        let result = await executor.execute(
            .init(
                name: "update_workout_goal",
                arguments: [
                    "goal_id": goal.id.uuidString,
                    "workout_type": "weight lifting"
                ]
            )
        )

        guard case .dataResponse(let functionResult) = result,
              let updatedGoal = functionResult.response["goal"] as? [String: Any] else {
            return XCTFail("Expected updated workout goal response")
        }

        XCTAssertEqual(updatedGoal["workout_type"] as? String, WorkoutMode.strength.rawValue)
        XCTAssertEqual(goal.linkedWorkoutType, .strength)
    }

    func testLogWorkoutNormalizesRunningType() async {
        let executor = AIFunctionExecutor(modelContext: context, userProfile: nil)
        let result = await executor.execute(
            .init(
                name: "log_workout",
                arguments: [
                    "type": "running",
                    "name": "Morning run",
                    "duration_minutes": 35
                ]
            )
        )

        guard case .suggestedWorkoutLog(let workoutLog) = result else {
            return XCTFail("Expected suggested workout log")
        }

        XCTAssertEqual(workoutLog.workoutType, WorkoutMode.cardio.rawValue)
    }

    func testLogWorkoutAcceptsNonStrengthActivityWithoutSets() async {
        let executor = AIFunctionExecutor(modelContext: context, userProfile: nil)
        let result = await executor.execute(
            .init(
                name: "log_workout",
                arguments: [
                    "type": "sports",
                    "name": "Bouldering session",
                    "activity_name": "Bouldering",
                    "activity_tags": ["Climbing", "Grip"],
                    "exercises": [
                        [
                            "name": "Limit bouldering",
                            "category": "sportPractice",
                            "activity_name": "Bouldering",
                            "target_tags": ["Climbing", "Technique"],
                            "tracking_fields": ["duration", "notes"],
                            "duration_minutes": 45,
                            "segments": [
                                [
                                    "duration_minutes": 20,
                                    "notes": "Warm-up problems"
                                ],
                                [
                                    "duration_minutes": 25,
                                    "notes": "Limit attempts"
                                ]
                            ]
                        ]
                    ]
                ]
            )
        )

        guard case .suggestedWorkoutLog(let workoutLog) = result,
              let exercise = workoutLog.exercises.first else {
            return XCTFail("Expected suggested workout log with activity")
        }

        XCTAssertEqual(workoutLog.activityName, "Bouldering")
        XCTAssertEqual(workoutLog.activityTags ?? [], ["Climbing", "Grip"])
        XCTAssertEqual(exercise.category, "sportPractice")
        XCTAssertEqual(exercise.activityTypeName, "Bouldering")
        XCTAssertEqual(exercise.targetTags ?? [], ["Climbing", "Technique"])
        XCTAssertEqual(exercise.trackingFields ?? [], ["duration", "notes"])
        XCTAssertEqual(exercise.durationMinutes, 45)
        XCTAssertEqual(exercise.segments?.count, 2)
    }

    func testLogWorkoutFunctionSchemaDoesNotRequireSetsForEveryActivity() throws {
        let schema = AIFunctionDeclarations.logWorkout
        let parameters = try XCTUnwrap(schema["parameters"] as? [String: Any])
        let properties = try XCTUnwrap(parameters["properties"] as? [String: Any])
        let exercises = try XCTUnwrap(properties["exercises"] as? [String: Any])
        let items = try XCTUnwrap(exercises["items"] as? [String: Any])
        let required = try XCTUnwrap(items["required"] as? [String])

        XCTAssertEqual(required, ["name"])
    }

    func testWorkoutFunctionSchemasSupportAllStableActivityPrimitives() throws {
        let expected = Set(["strength", "cardio", "conditioning", "mobility", "skill", "sportPractice", "recovery", "flexibility", "custom"])

        let logWorkoutCategories = try exerciseCategoryEnum(in: AIFunctionDeclarations.logWorkout, exercisesKey: "exercises")
        XCTAssertTrue(expected.isSubset(of: Set(logWorkoutCategories)))

        let startLiveWorkoutCategories = try exerciseCategoryEnum(in: AIFunctionDeclarations.startLiveWorkout, exercisesKey: "suggested_exercises")
        XCTAssertTrue(expected.isSubset(of: Set(startLiveWorkoutCategories)))
    }

    func testRecentWorkoutsExposeLiveWorkoutActivityFocusesAndSegments() async throws {
        let context = try makeWorkoutHistoryContext()
        let workout = LiveWorkout(
            name: "Bouldering Session",
            workoutType: .climbing,
            focusAreas: ["Bouldering", "Climbing", "Grip endurance"]
        )
        workout.startedAt = Date().addingTimeInterval(-3_600)
        workout.completedAt = Date()

        let entry = LiveWorkoutEntry(
            exerciseName: "Limit Bouldering",
            orderIndex: 0,
            exerciseType: "skill"
        )
        entry.activityTypeName = "Bouldering"
        entry.targetTags = ["Climbing", "Grip endurance"]
        entry.activitySegments = [
            LiveWorkoutEntry.ActivitySegment(durationSeconds: 1_200, reps: 8, notes: "Limit attempts")
        ]
        entry.completedAt = Date()
        entry.workout = workout
        workout.entries = [entry]
        context.insert(workout)
        try context.save()

        let result = await AIFunctionExecutor(modelContext: context, userProfile: nil).execute(
            .init(name: "get_recent_workouts", arguments: ["limit": 5])
        )

        guard case .dataResponse(let functionResult) = result,
              let workouts = functionResult.response["workouts"] as? [[String: Any]],
              let payload = workouts.first(where: { $0["id"] as? String == workout.id.uuidString }),
              let activities = payload["activities"] as? [[String: Any]],
              let activity = activities.first,
              let segments = activity["segments"] as? [[String: Any]],
              let segment = segments.first else {
            return XCTFail("Expected recent workout payload with activity segment metadata")
        }

        XCTAssertEqual(payload["focus_areas"] as? [String], ["Bouldering", "Climbing", "Grip endurance"])
        XCTAssertEqual(activity["activity_type"] as? String, "Bouldering")
        XCTAssertEqual(activity["activity_tags"] as? [String], ["Climbing", "Grip endurance"])
        XCTAssertEqual(segment["duration_minutes"] as? Int, 20)
        XCTAssertEqual(segment["reps"] as? Int, 8)
        XCTAssertEqual(segment["notes"] as? String, "Limit attempts")
    }

    func testRecentWorkoutsExposeManualSessionSemanticTags() async throws {
        let context = try makeWorkoutHistoryContext()
        let exercise = Exercise(name: "Limit Bouldering", category: .skill)
        exercise.activityTypeName = "Bouldering"
        exercise.targetTags = ["Climbing", "Grip endurance"]

        let session = WorkoutSession(exercise: exercise, sets: 0, reps: 0, weightKg: nil)
        session.durationMinutes = 45
        session.loggedAt = Date()
        context.insert(exercise)
        context.insert(session)
        try context.save()

        let result = await AIFunctionExecutor(modelContext: context, userProfile: nil).execute(
            .init(name: "get_recent_workouts", arguments: ["limit": 5])
        )

        guard case .dataResponse(let functionResult) = result,
              let workouts = functionResult.response["workouts"] as? [[String: Any]],
              let payload = workouts.first(where: { $0["id"] as? String == session.id.uuidString }) else {
            return XCTFail("Expected recent manual workout payload")
        }

        XCTAssertEqual(payload["display_type"] as? String, "Bouldering")
        XCTAssertEqual(payload["activity_tags"] as? [String], ["Bouldering", "skill", "Climbing", "Grip endurance"])
    }

    private func exerciseCategoryEnum(in schema: [String: Any], exercisesKey: String) throws -> [String] {
        let parameters = try XCTUnwrap(schema["parameters"] as? [String: Any])
        let properties = try XCTUnwrap(parameters["properties"] as? [String: Any])
        let exercises = try XCTUnwrap(properties[exercisesKey] as? [String: Any])
        let items = try XCTUnwrap(exercises["items"] as? [String: Any])
        let itemProperties = try XCTUnwrap(items["properties"] as? [String: Any])
        let category = try XCTUnwrap(itemProperties["category"] as? [String: Any])
        return try XCTUnwrap(category["enum"] as? [String])
    }

    private func makeWorkoutHistoryContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: LiveWorkout.self,
            LiveWorkoutEntry.self,
            WorkoutSession.self,
            Exercise.self,
            configurations: ModelConfiguration(
                isStoredInMemoryOnly: true,
                cloudKitDatabase: .none
            )
        )
        return ModelContext(container)
    }
}
