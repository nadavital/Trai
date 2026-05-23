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

    func testWorkoutSuggestionPromptIncludesGeneralActivityContext() {
        let exercise = Exercise(name: "Limit Bouldering", category: .sportPractice)
        exercise.activityTypeName = "Bouldering"
        exercise.targetTags = ["Climbing", "Grip power"]

        let session = WorkoutSession(exercise: exercise, sets: 2, reps: 8, weightKg: 20)
        session.durationMinutes = 45
        session.notes = "Avoids slab, wants overhang power."

        let prompt = AIPromptBuilder.buildWorkoutSuggestionPrompt(
            history: [session],
            goal: "Build a useful mixed workout",
            availableTime: 45
        )

        XCTAssertTrue(prompt.contains("Limit Bouldering"))
        XCTAssertTrue(prompt.contains("Bouldering"))
        XCTAssertTrue(prompt.contains("45m"))
        XCTAssertTrue(prompt.contains("2 segments"))
        XCTAssertTrue(prompt.contains("8 attempts"))
        XCTAssertTrue(prompt.contains("Grip power"))
        XCTAssertTrue(prompt.contains("Avoids slab"))
        XCTAssertFalse(prompt.contains("2 sets x 8 reps"))
    }

    func testWorkoutSuggestionPromptIncludesImportedWorkoutDistance() {
        let session = WorkoutSession(
            healthKitWorkoutID: "run-1",
            workoutType: "running",
            durationMinutes: 32,
            caloriesBurned: nil,
            distanceMeters: 5100,
            loggedAt: Date()
        )

        let prompt = AIPromptBuilder.buildWorkoutSuggestionPrompt(
            history: [session],
            goal: "Keep improving cardio",
            availableTime: nil
        )

        XCTAssertTrue(prompt.contains("Running"))
        XCTAssertTrue(prompt.contains("32m"))
        XCTAssertTrue(prompt.contains("5.10 km"))
    }

    func testSuggestedWorkoutLogSummaryPreservesActivityItems() {
        let log = SuggestedWorkoutLog(
            name: "Climb + Conditioning",
            workoutType: "mixed",
            durationMinutes: 55,
            exercises: [
                SuggestedWorkoutLog.LoggedExercise(
                    name: "Back Squat",
                    category: "strength",
                    sets: [
                        .init(reps: 5, weightKg: 100),
                        .init(reps: 5, weightKg: 100)
                    ]
                ),
                SuggestedWorkoutLog.LoggedExercise(
                    name: "Limit Bouldering",
                    category: "skill",
                    activityTypeName: "Bouldering",
                    targetTags: ["Climbing", "Power"],
                    trackingFields: ["duration", "reps", "notes"],
                    durationMinutes: 30,
                    notes: "Hard attempts",
                    segments: [
                        .init(durationMinutes: 10, reps: 4, notes: "V4 attempts")
                    ],
                    sets: []
                )
            ],
            notes: nil
        )

        XCTAssertEqual(log.strengthExerciseCount, 1)
        XCTAssertEqual(log.activityCount, 1)
        XCTAssertEqual(log.totalSets, 2)
        XCTAssertEqual(log.summary, "1 exercise • 1 activity • 2 sets • 55 min")
        XCTAssertEqual(
            log.exercises[1].activitySummarySegments,
            ["30 min", "4 attempts", "Hard attempts"]
        )
    }

    func testActivityLogsWithRoundsDoNotBecomeStrengthLogs() {
        let log = SuggestedWorkoutLog(
            name: "Conditioning Rounds",
            workoutType: "mixed",
            durationMinutes: 20,
            exercises: [
                SuggestedWorkoutLog.LoggedExercise(
                    name: "Boxing Rounds",
                    category: "sportPractice",
                    activityTypeName: "Boxing",
                    targetTags: ["Boxing", "Footwork"],
                    trackingFields: ["reps", "duration", "notes"],
                    durationMinutes: 20,
                    notes: "Six focused rounds",
                    segments: [
                        .init(durationMinutes: 3, reps: 1, notes: "Round 1")
                    ],
                    sets: [
                        .init(reps: 6, weightKg: nil)
                    ]
                )
            ],
            notes: nil
        )

        XCTAssertEqual(log.strengthExerciseCount, 0)
        XCTAssertEqual(log.activityCount, 1)
        XCTAssertEqual(log.totalSets, 0)
        XCTAssertEqual(log.summary, "1 activity • 20 min")
    }

    func testLogWorkoutExecutorKeepsActivityWithRoundsAsActivitySuggestion() async throws {
        let result = await AIFunctionExecutor(modelContext: context, userProfile: nil).execute(
            .init(
                name: "log_workout",
                arguments: [
                    "name": "Boxing Skill Work",
                    "type": "mixed",
                    "activity_name": "Boxing",
                    "activity_tags": ["Boxing", "Footwork"],
                    "duration_minutes": 20,
                    "exercises": [
                        [
                            "name": "Boxing Rounds",
                            "category": "sportPractice",
                            "activity_name": "Boxing",
                            "target_tags": ["Boxing", "Footwork"],
                            "tracking_fields": ["reps", "duration", "notes"],
                            "duration_minutes": 20,
                            "sets": [
                                ["reps": 6]
                            ],
                            "segments": [
                                ["duration_minutes": 3, "reps": 1, "notes": "Round 1"]
                            ]
                        ]
                    ]
                ]
            )
        )

        guard case .suggestedWorkoutLog(let suggestion) = result else {
            return XCTFail("Expected workout log suggestion")
        }

        XCTAssertEqual(suggestion.strengthExerciseCount, 0)
        XCTAssertEqual(suggestion.activityCount, 1)
        XCTAssertEqual(suggestion.totalSets, 0)
        XCTAssertEqual(suggestion.exercises.first?.category, "sportPractice")
        XCTAssertEqual(suggestion.exercises.first?.activityTypeName, "Boxing")
    }

    func testStartLiveWorkoutKeepsActivitySuggestionsSetFree() async throws {
        let result = await AIFunctionExecutor(modelContext: context, userProfile: nil).execute(
            .init(
                name: "start_live_workout",
                arguments: [
                    "name": "Easy Run",
                    "workout_type": "cardio",
                    "activity_focuses": ["Running", "Aerobic base"],
                    "suggested_exercises": [
                        [
                            "name": "Easy Run",
                            "category": "cardio",
                            "activity_name": "Running",
                            "tracking_fields": ["duration", "distance"],
                            "duration_minutes": 30
                        ]
                    ]
                ]
            )
        )

        guard case .suggestedWorkoutStart(let suggestion) = result else {
            return XCTFail("Expected start workout suggestion")
        }

        XCTAssertEqual(suggestion.exercisesSummary, "1 activity")
        XCTAssertEqual(suggestion.activityFocuses, ["Running", "Aerobic base"])
        XCTAssertEqual(suggestion.exercises.first?.sets, 0)
        XCTAssertEqual(suggestion.exercises.first?.durationMinutes, 30)
    }

    func testStartLiveWorkoutInfersActivityCategoryFromActivityName() async throws {
        let result = await AIFunctionExecutor(modelContext: context, userProfile: nil).execute(
            .init(
                name: "start_live_workout",
                arguments: [
                    "name": "Climbing Power",
                    "workout_type": "mixed",
                    "activity_focuses": ["Climbing", "Power"],
                    "suggested_exercises": [
                        [
                            "name": "Limit Bouldering",
                            "activity_name": "Bouldering",
                            "target_tags": ["Climbing", "Power"],
                            "tracking_fields": ["duration", "reps", "notes"],
                            "duration_minutes": 30,
                            "segments": [
                                ["duration_minutes": 15, "reps": 4],
                                ["duration_minutes": 15, "reps": 3]
                            ]
                        ]
                    ]
                ]
            )
        )

        guard case .suggestedWorkoutStart(let suggestion) = result,
              let exercise = suggestion.exercises.first else {
            return XCTFail("Expected start workout suggestion")
        }

        XCTAssertEqual(suggestion.exercisesSummary, "1 activity")
        XCTAssertEqual(exercise.category, "sportPractice")
        XCTAssertEqual(exercise.sets, 0)
        XCTAssertEqual(exercise.startSummarySegments, ["Bouldering", "30 min", "2 segments", "7 attempts"])
    }

    func testStartWorkoutActivitySummaryUsesActivityMetrics() {
        let exercise = SuggestedWorkoutEntry.SuggestedExercise(
            name: "Limit Bouldering",
            category: "sportPractice",
            activityTypeName: "Bouldering",
            targetTags: ["Climbing", "Grip power"],
            trackingFields: ["duration", "reps", "notes"],
            sets: 0,
            reps: 0,
            weightKg: nil,
            durationMinutes: 40,
            distanceMeters: nil,
            notes: nil,
            segments: [
                .init(durationMinutes: 20, reps: 4),
                .init(durationMinutes: 20, reps: 3)
            ]
        )

        XCTAssertEqual(
            exercise.startSummarySegments,
            ["Bouldering", "40 min", "2 segments", "7 attempts"]
        )
    }

    func testCustomActivitySummaryPluralizesGenericCounts() {
        let exercise = SuggestedWorkoutEntry.SuggestedExercise(
            name: "Custom Drill",
            category: "custom",
            activityTypeName: "Custom Drill",
            targetTags: [],
            trackingFields: ["reps"],
            sets: 0,
            reps: 3,
            weightKg: nil,
            durationMinutes: nil,
            distanceMeters: nil,
            notes: nil,
            segments: []
        )

        XCTAssertEqual(exercise.startSummarySegments, ["3 counts"])
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
                    "target_value": 3,
                    "target_unit": "sessions",
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

    func testCreateWorkoutGoalRejectsDurationGoalWithoutPeriod() async throws {
        let executor = AIFunctionExecutor(modelContext: context, userProfile: nil)
        let result = await executor.execute(
            .init(
                name: "create_workout_goal",
                arguments: [
                    "title": "Build cardio support",
                    "goal_kind": "duration",
                    "target_value": 45,
                    "target_unit": "min",
                    "success_criteria": "You log 45 minutes of cardio support in one week."
                ]
            )
        )

        guard case .dataResponse(let functionResult) = result else {
            return XCTFail("Expected workout goal error response")
        }

        XCTAssertEqual(functionResult.response["error"] as? String, "period_unit is required for duration goals")
    }

    func testUpdateWorkoutGoalNormalizesWeightLiftingToStrength() async throws {
        let goal = WorkoutGoal(
            title: "Move more",
            goalKind: .frequency,
            linkedWorkoutType: .cardio,
            targetValue: 3,
            targetUnit: "sessions",
            periodUnit: .week,
            periodCount: 1,
            successCriteria: "Complete three cardio sessions in one week."
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

    func testUpdateWorkoutGoalRejectsDistanceGoalWithoutPeriod() async throws {
        let goal = WorkoutGoal(
            title: "Run more",
            goalKind: .frequency,
            linkedWorkoutType: .cardio,
            targetValue: 3,
            targetUnit: "sessions",
            periodUnit: .week,
            periodCount: 1,
            successCriteria: "You complete three cardio sessions in one week."
        )
        context.insert(goal)
        try context.save()

        let executor = AIFunctionExecutor(modelContext: context, userProfile: nil)
        let result = await executor.execute(
            .init(
                name: "update_workout_goal",
                arguments: [
                    "goal_id": goal.id.uuidString,
                    "goal_kind": "distance",
                    "target_value": 10,
                    "target_unit": "km",
                    "period_unit": "",
                    "period_count": NSNull(),
                    "success_criteria": "You log 10 km of running in one week."
                ]
            )
        )

        guard case .dataResponse(let functionResult) = result else {
            return XCTFail("Expected workout goal error response")
        }

        XCTAssertEqual(functionResult.response["error"] as? String, "period_unit is required for distance goals")
        XCTAssertEqual(goal.goalKind, .frequency)
        XCTAssertEqual(goal.periodUnit, .week)
        XCTAssertEqual(goal.periodCount, 1)
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

    func testPlanBlockSchemasUseRoleForPlacementNotKind() throws {
        XCTAssertEqual(
            Set(AIPromptBuilder.workoutGoalActivityKindRawValues),
            Set(["strength", "cardio", "conditioning", "skill", "mobility", "recovery", "sportPractice", "custom"])
        )
        XCTAssertFalse(AIPromptBuilder.workoutGoalActivityKindRawValues.contains("warmup"))
        XCTAssertFalse(AIPromptBuilder.workoutGoalActivityKindRawValues.contains("cooldown"))
        XCTAssertTrue(AIPromptBuilder.workoutGoalActivityRoleRawValues.contains("warmup"))
        XCTAssertTrue(AIPromptBuilder.workoutGoalActivityRoleRawValues.contains("cooldown"))
        XCTAssertFalse(WorkoutPlan.TrainingBlock.BlockKind.allCases.map(\.rawValue).contains("warmup"))
        XCTAssertFalse(WorkoutPlan.TrainingBlock.BlockKind.allCases.map(\.rawValue).contains("cooldown"))

        for schema in [AIPromptBuilder.workoutPlanSchema, AIPromptBuilder.workoutPlanRefinementSchema] {
            let kindValues = try blockEnum(in: schema, field: "kind")
            XCTAssertFalse(kindValues.contains("warmup"))
            XCTAssertFalse(kindValues.contains("cooldown"))
            XCTAssertTrue(kindValues.contains("mobility"))
            XCTAssertTrue(kindValues.contains("recovery"))

            let roleValues = try blockEnum(in: schema, field: "role")
            XCTAssertTrue(roleValues.contains("warmup"))
            XCTAssertTrue(roleValues.contains("cooldown"))
            XCTAssertTrue(roleValues.contains("finisher"))
        }

        let suggestionProperties = try XCTUnwrap(AIPromptBuilder.workoutGoalSuggestionSchema["properties"] as? [String: Any])
        let suggestionKind = try XCTUnwrap(suggestionProperties["linkedActivityKindRaw"] as? [String: Any])
        let suggestionKindValues = try XCTUnwrap(suggestionKind["enum"] as? [String])
        XCTAssertEqual(Set(suggestionKindValues), Set(AIPromptBuilder.workoutGoalActivityKindRawValues))
        XCTAssertFalse(suggestionKindValues.contains("warmup"))
        XCTAssertFalse(suggestionKindValues.contains("cooldown"))

        let createGoalKinds = try propertyEnum(in: AIFunctionDeclarations.createWorkoutGoal, property: "activity_kind")
        XCTAssertEqual(Set(createGoalKinds), Set(AIPromptBuilder.workoutGoalActivityKindRawValues))

        let updateGoalKinds = try propertyEnum(in: AIFunctionDeclarations.updateWorkoutGoal, property: "activity_kind")
        XCTAssertFalse(updateGoalKinds.contains("warmup"))
        XCTAssertFalse(updateGoalKinds.contains("cooldown"))
        XCTAssertTrue(updateGoalKinds.contains(""))
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

        let plannedGuidance = LiveWorkoutEntry(
            exerciseName: "Easy Spin",
            orderIndex: 1,
            exerciseType: "cardio"
        )
        plannedGuidance.activityTypeName = "Cycling"
        plannedGuidance.targetTags = ["Recovery"]
        plannedGuidance.sourcePlanBlockID = UUID()
        plannedGuidance.workout = workout

        workout.entries = [entry, plannedGuidance]
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
        XCTAssertEqual(payload["summary_segments"] as? [String], ["1 activity", "8 attempts", "60 min"])
        XCTAssertEqual(payload["exercise_count"] as? Int, 0)
        XCTAssertEqual(payload["activity_count"] as? Int, 1)
        XCTAssertEqual(activity["activity_type"] as? String, "Bouldering")
        XCTAssertEqual(activity["activity_tags"] as? [String], ["Climbing", "Grip endurance"])
        XCTAssertEqual(activity["logged"] as? Bool, true)
        XCTAssertEqual(segment["duration_minutes"] as? Int, 20)
        XCTAssertEqual(segment["reps"] as? Int, 8)
        XCTAssertEqual(segment["notes"] as? String, "Limit attempts")
    }

    func testRecentWorkoutsExcludeUnloggedPlannedItemsAndIncompleteSets() async throws {
        let context = try makeWorkoutHistoryContext()
        let workout = LiveWorkout(name: "Strength + Support", workoutType: .mixed)
        workout.startedAt = Date().addingTimeInterval(-3_600)
        workout.completedAt = Date()

        let strengthEntry = LiveWorkoutEntry(exerciseName: "Back Squat", orderIndex: 0)
        strengthEntry.addSet(LiveWorkoutEntry.SetData(reps: 8, weight: .zero, completed: true))
        strengthEntry.addSet(LiveWorkoutEntry.SetData(reps: 8, weight: .zero, completed: false))
        strengthEntry.workout = workout

        let plannedGuidance = LiveWorkoutEntry(
            exerciseName: "Mobility Cooldown",
            orderIndex: 1,
            exerciseType: "mobility"
        )
        plannedGuidance.activityTypeName = "Mobility"
        plannedGuidance.sourcePlanBlockID = UUID()
        plannedGuidance.workout = workout

        workout.entries = [strengthEntry, plannedGuidance]
        context.insert(workout)
        try context.save()

        let result = await AIFunctionExecutor(modelContext: context, userProfile: nil).execute(
            .init(name: "get_recent_workouts", arguments: ["limit": 5])
        )

        guard case .dataResponse(let functionResult) = result,
              let workouts = functionResult.response["workouts"] as? [[String: Any]],
              let payload = workouts.first(where: { $0["id"] as? String == workout.id.uuidString }),
              let exercises = payload["exercises"] as? [[String: Any]],
              let exercise = exercises.first,
              let setDetails = exercise["sets_detail"] as? [[String: Any]] else {
            return XCTFail("Expected recent workout payload with one completed strength set")
        }

        XCTAssertNil(payload["activities"])
        XCTAssertEqual(payload["summary_segments"] as? [String], ["1 exercise", "1 set", "60 min"])
        XCTAssertEqual(payload["exercise_count"] as? Int, 1)
        XCTAssertEqual(payload["activity_count"] as? Int, 0)
        XCTAssertEqual(exercise["sets_count"] as? Int, 1)
        XCTAssertEqual(setDetails.count, 1)
        XCTAssertEqual(setDetails.first?["reps"] as? Int, 8)
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

    private func blockEnum(in schema: [String: Any], field: String) throws -> [String] {
        let rootProperties = try XCTUnwrap(schema["properties"] as? [String: Any])
        let planSchema = (rootProperties["templates"] == nil)
            ? try XCTUnwrap(rootProperties["proposedPlan"] as? [String: Any])
            : schema
        let properties = try XCTUnwrap(planSchema["properties"] as? [String: Any])
        let templates = try XCTUnwrap(properties["templates"] as? [String: Any])
        let templateItems = try XCTUnwrap(templates["items"] as? [String: Any])
        let templateProperties = try XCTUnwrap(templateItems["properties"] as? [String: Any])
        let blocks = try XCTUnwrap(templateProperties["blocks"] as? [String: Any])
        let blockItems = try XCTUnwrap(blocks["items"] as? [String: Any])
        let blockProperties = try XCTUnwrap(blockItems["properties"] as? [String: Any])
        let fieldSchema = try XCTUnwrap(blockProperties[field] as? [String: Any])
        return try XCTUnwrap(fieldSchema["enum"] as? [String])
    }

    private func propertyEnum(in schema: [String: Any], property: String) throws -> [String] {
        let parameters = try XCTUnwrap(schema["parameters"] as? [String: Any])
        let properties = try XCTUnwrap(parameters["properties"] as? [String: Any])
        let propertySchema = try XCTUnwrap(properties[property] as? [String: Any])
        return try XCTUnwrap(propertySchema["enum"] as? [String])
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
