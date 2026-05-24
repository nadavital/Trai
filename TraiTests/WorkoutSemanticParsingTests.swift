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
            Exercise.self,
            UserProfile.self,
            LiveWorkout.self,
            LiveWorkoutEntry.self,
            WorkoutSession.self,
            ExerciseHistory.self,
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
        XCTAssertNil(WorkoutMode.normalized(from: "trunk rotation"))
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
        XCTAssertTrue(prompt.contains("duration, distance, segments, targets, and notes"))
        XCTAssertFalse(prompt.contains("2 sets x 8 reps"))
        XCTAssertFalse(prompt.contains("Main workout (exercises, sets, reps, rest times)"))
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

    func testActiveWorkoutContextUsesActivityLanguageForMixedSessions() {
        let context = AIService.WorkoutContext(
            workoutName: "Climbing Day",
            workoutType: "Climbing",
            focusAreas: ["Bouldering"],
            elapsedMinutes: 18,
            exercisesCompleted: 1,
            exercisesTotal: 2,
            currentExercise: "Limit Bouldering",
            setsCompleted: 0,
            totalVolume: 0,
            targetMuscleGroups: [],
            sessionNotes: nil,
            activeGoals: [],
            entryDetails: [
                "Limit Bouldering • Bouldering • 18 min • tracks Duration/Attempts/Notes"
            ]
        )

        let description = context.description

        XCTAssertTrue(description.contains("Progress: 1/2 workout entries"))
        XCTAssertTrue(description.contains("Current item: Limit Bouldering"))
        XCTAssertFalse(description.contains("Progress: 1/2 exercises"))
        XCTAssertFalse(description.contains("Sets completed"))
    }

    func testActiveWorkoutFunctionPromptUsesActivityNeutralTrainingLanguage() {
        let prompt = AIService.activeWorkoutPriorityInstructions

        XCTAssertTrue(prompt.contains("workout items, sets, or activity blocks"))
        XCTAssertTrue(prompt.contains("activity, exercise, form, alternatives, pacing, or logging"))
        XCTAssertTrue(prompt.contains("activity variation, or recovery adjustment"))
        XCTAssertFalse(prompt.contains("opened chat between sets"))
    }

    func testActiveWorkoutContextKeepsStrengthSetLanguageForStrengthSessions() {
        let context = AIService.WorkoutContext(
            workoutName: "Push Day",
            workoutType: "Strength",
            focusAreas: ["Push"],
            elapsedMinutes: 22,
            exercisesCompleted: 1,
            exercisesTotal: 3,
            currentExercise: "Bench Press",
            setsCompleted: 4,
            totalVolume: 2400,
            targetMuscleGroups: ["Chest", "Shoulders"],
            sessionNotes: nil,
            activeGoals: ["Hit all sessions"],
            entryDetails: [
                "Bench Press • 4 logged sets • 80 kg x 8"
            ]
        )

        let description = context.description

        XCTAssertTrue(description.contains("Progress: 1/3 exercises"))
        XCTAssertTrue(description.contains("Current exercise: Bench Press"))
        XCTAssertTrue(description.contains("Strength sets completed: 4"))
    }

    func testHealthKitImportedActivityTagsDriveGoalMatching() {
        let session = WorkoutSession(
            healthKitWorkoutID: "mobility-1",
            workoutType: "cooldown",
            durationMinutes: 30,
            caloriesBurned: nil,
            distanceMeters: nil,
            loggedAt: Date()
        )
        session.exerciseName = "Mobility Flow"
        session.importedActivityTags = ["Mobility Flow", "Hips"]

        let goal = WorkoutGoal(
            title: "Open up hips",
            goalKind: .duration,
            linkedActivityTags: ["Hips"],
            targetValue: 30,
            targetUnit: "min",
            periodUnit: .week,
            periodCount: 1,
            successCriteria: "You complete 30 minutes of hip mobility this week."
        )

        XCTAssertTrue(session.semanticActivityTags.contains("Hips"))
        XCTAssertEqual(session.activityContextSegments.prefix(2).map { $0 }, ["Hips", "Cooldown"])
        XCTAssertEqual(session.historyDetailSegments.prefix(3).map { $0 }, ["Hips", "Cooldown", "30m"])
        XCTAssertTrue(session.goalMatchingTokens.contains("hips"))
        XCTAssertTrue(goal.matches(session: session))
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
        XCTAssertEqual(log.iconName, WorkoutMode.mixed.iconName)
        XCTAssertEqual(
            log.exercises[1].activitySummarySegments,
            ["Bouldering", "30 min", "4 attempts", "Hard attempts"]
        )
    }

    func testSuggestedWorkoutLogDerivesDurationFromActivityEntriesWhenTopLevelDurationIsMissing() {
        let log = SuggestedWorkoutLog(
            name: "Climb + Mobility",
            workoutType: "mixed",
            durationMinutes: nil,
            exercises: [
                SuggestedWorkoutLog.LoggedExercise(
                    name: "Limit Bouldering",
                    category: "sportPractice",
                    activityTypeName: "Bouldering",
                    durationMinutes: 25,
                    segments: nil,
                    sets: []
                ),
                SuggestedWorkoutLog.LoggedExercise(
                    name: "Cooldown Mobility",
                    category: "mobility",
                    activityTypeName: "Mobility",
                    durationMinutes: nil,
                    segments: [
                        .init(durationMinutes: 8),
                        .init(durationMinutes: 7)
                    ],
                    sets: []
                )
            ],
            notes: nil
        )

        XCTAssertEqual(log.resolvedDurationMinutes, 40)
        XCTAssertEqual(log.summary, "2 activities • 40 min")
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
        XCTAssertEqual(log.iconName, Exercise.Category.sportPractice.iconName)
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
        XCTAssertEqual(suggestion.exercises.first?.reps, 0)
        XCTAssertEqual(suggestion.exercises.first?.durationMinutes, 30)
        XCTAssertEqual(suggestion.exercises.first?.startSummarySegments, ["Running", "30 min"])
        XCTAssertEqual(suggestion.iconName, Exercise.Category.cardio.iconName)
    }

    func testStartLiveWorkoutParsesIntegerWeightKg() async throws {
        let result = await AIFunctionExecutor(modelContext: context, userProfile: nil).execute(
            .init(
                name: "start_live_workout",
                arguments: [
                    "name": "Bench Session",
                    "workout_type": "strength",
                    "suggested_exercises": [
                        [
                            "name": "Bench Press",
                            "category": "strength",
                            "sets": 3,
                            "reps": 5,
                            "weight_kg": 80
                        ]
                    ]
                ]
            )
        )

        guard case .suggestedWorkoutStart(let suggestion) = result,
              let exercise = suggestion.exercises.first else {
            return XCTFail("Expected start workout suggestion")
        }

        XCTAssertEqual(exercise.weightKg, 80)
    }

    func testLogWorkoutPreservesSourcePlanTemplateID() async throws {
        let template = WorkoutPlan.WorkoutTemplate(
            name: "Pull + Climb",
            sessionType: .mixed,
            focusAreas: ["Pull", "Climbing"],
            targetMuscleGroups: ["back"],
            exercises: [],
            blocks: [
                WorkoutPlan.TrainingBlock(
                    kind: .sportPractice,
                    title: "Limit Bouldering",
                    detail: "Planned climbing block",
                    activityTypeName: "Bouldering",
                    activityTags: ["Climbing"],
                    durationMinutes: 35,
                    order: 0
                )
            ],
            estimatedDurationMinutes: 50,
            order: 0
        )
        let profile = UserProfile()
        profile.workoutPlan = WorkoutPlan(
            splitType: .custom,
            daysPerWeek: 1,
            templates: [template],
            rationale: "Mixed climbing plan",
            guidelines: [],
            progressionStrategy: .defaultStrategy
        )

        let result = await AIFunctionExecutor(modelContext: context, userProfile: profile).execute(
            .init(
                name: "log_workout",
                arguments: [
                    "name": "Pull + Climb",
                    "type": "mixed",
                    "activity_name": "Climbing",
                    "source_plan_template_id": template.id.uuidString,
                    "duration_minutes": 50,
                    "exercises": [
                        [
                            "name": "Limit Bouldering",
                            "category": "sportPractice",
                            "activity_name": "Bouldering",
                            "activity_role": "finisher",
                            "duration_minutes": 35,
                            "notes": "Finished the planned climbing block."
                        ]
                    ]
                ]
            )
        )

        guard case .suggestedWorkoutLog(let workoutLog) = result else {
            return XCTFail("Expected workout log suggestion")
        }

        XCTAssertEqual(workoutLog.sourcePlanTemplateID, template.id)
        XCTAssertEqual(workoutLog.exercises.first?.activityRole, "finisher")
    }

    func testLogWorkoutRejectsSourcePlanTemplateIDOutsideCurrentPlan() async throws {
        let template = WorkoutPlan.WorkoutTemplate(
            name: "Plan Pull Day",
            sessionType: .strength,
            targetMuscleGroups: ["back"],
            exercises: [
                .init(exerciseName: "Pull Up", muscleGroup: "back", defaultSets: 4, defaultReps: 6, order: 0)
            ],
            estimatedDurationMinutes: 45,
            order: 0
        )
        let profile = UserProfile()
        profile.workoutPlan = WorkoutPlan(
            splitType: .custom,
            daysPerWeek: 1,
            templates: [template],
            rationale: "Pull plan",
            guidelines: [],
            progressionStrategy: .defaultStrategy
        )

        let result = await AIFunctionExecutor(modelContext: context, userProfile: profile).execute(
            .init(
                name: "log_workout",
                arguments: [
                    "name": "Stale plan workout",
                    "type": "strength",
                    "source_plan_template_id": UUID().uuidString,
                    "exercises": [
                        [
                            "name": "Pull Up",
                            "category": "strength",
                            "sets": [
                                ["reps": 6]
                            ]
                        ]
                    ]
                ]
            )
        )

        guard case .dataResponse(let functionResult) = result else {
            return XCTFail("Expected validation error")
        }

        XCTAssertEqual(functionResult.name, "log_workout")
        XCTAssertEqual(functionResult.response["error"] as? String, "source_plan_template_id must match an existing session in the current workout plan.")
    }

    func testChatSuggestionFreshnessRejectsCardsOlderThanCurrentPlanUpdate() {
        let messageTimestamp = Date(timeIntervalSince1970: 100)
        let currentPlanUpdatedAt = Date(timeIntervalSince1970: 101)

        XCTAssertTrue(ChatSuggestionFreshness.isStale(
            messageTimestamp: messageTimestamp,
            currentPlanUpdatedAt: currentPlanUpdatedAt
        ))
    }

    func testChatSuggestionFreshnessAllowsCurrentOrUnversionedCards() {
        let messageTimestamp = Date(timeIntervalSince1970: 100)

        XCTAssertFalse(ChatSuggestionFreshness.isStale(
            messageTimestamp: messageTimestamp,
            currentPlanUpdatedAt: Date(timeIntervalSince1970: 100)
        ))
        XCTAssertFalse(ChatSuggestionFreshness.isStale(
            messageTimestamp: messageTimestamp,
            currentPlanUpdatedAt: nil
        ))
    }

    func testChatWorkoutStartSuggestionRejectsCardsOlderThanCurrentPlanUpdate() {
        let templateID = UUID()
        let blockID = UUID()
        let suggestion = SuggestedWorkoutEntry(
            name: "Plan Pull Day",
            workoutType: LiveWorkout.WorkoutType.strength.rawValue,
            targetMuscleGroups: ["back"],
            exercises: [
                .init(
                    name: "Pull Up",
                    category: Exercise.Category.strength.rawValue,
                    sourcePlanBlockID: blockID,
                    sets: 4,
                    reps: 6
                )
            ],
            sourcePlanTemplateID: templateID,
            durationMinutes: 45,
            rationale: "From your plan."
        )

        XCTAssertTrue(ChatWorkoutStartSuggestionContext.isStale(
            suggestion: suggestion,
            messageTimestamp: Date(timeIntervalSince1970: 100),
            currentPlanUpdatedAt: Date(timeIntervalSince1970: 101),
            currentTemplateIDs: [templateID]
        ))
        XCTAssertTrue(ChatWorkoutStartFreshness.isCurrent(
            suggestion,
            currentPlan: makeChatWorkoutStartFreshnessPlan(templateID: templateID, blockID: blockID)
        ))
    }

    func testChatWorkoutStartSuggestionRejectsMissingSourceTemplate() {
        let suggestion = SuggestedWorkoutEntry(
            name: "Plan Pull Day",
            workoutType: LiveWorkout.WorkoutType.strength.rawValue,
            targetMuscleGroups: ["back"],
            exercises: [
                .init(
                    name: "Pull Up",
                    category: Exercise.Category.strength.rawValue,
                    sets: 4,
                    reps: 6
                )
            ],
            sourcePlanTemplateID: UUID(),
            durationMinutes: 45,
            rationale: "From your plan."
        )

        XCTAssertTrue(ChatWorkoutStartSuggestionContext.isStale(
            suggestion: suggestion,
            messageTimestamp: Date(timeIntervalSince1970: 100),
            currentPlanUpdatedAt: Date(timeIntervalSince1970: 100),
            currentTemplateIDs: []
        ))
        XCTAssertTrue(ChatWorkoutStartSuggestionContext.isStale(
            suggestion: suggestion,
            messageTimestamp: Date(timeIntervalSince1970: 100),
            currentPlanUpdatedAt: nil,
            currentTemplateIDs: nil
        ))
        XCTAssertFalse(ChatWorkoutStartFreshness.isCurrent(
            suggestion,
            currentPlan: nil as WorkoutPlan?
        ))
        XCTAssertFalse(ChatWorkoutStartFreshness.isCurrent(
            suggestion,
            currentPlan: makeChatWorkoutStartFreshnessPlan(templateID: UUID(), blockID: UUID())
        ))
    }

    func testChatWorkoutStartFreshnessAllowsLegacyExerciseOnlyTemplate() {
        let templateID = UUID()
        let exerciseID = UUID()
        let suggestion = SuggestedWorkoutEntry(
            name: "Legacy Pull Day",
            workoutType: LiveWorkout.WorkoutType.strength.rawValue,
            targetMuscleGroups: ["back"],
            exercises: [
                .init(
                    id: exerciseID,
                    name: "Pull Up",
                    category: Exercise.Category.strength.rawValue,
                    sourcePlanBlockID: UUID(),
                    sets: 4,
                    reps: 6
                )
            ],
            sourcePlanTemplateID: templateID,
            durationMinutes: 45,
            rationale: "From your plan."
        )

        XCTAssertTrue(ChatWorkoutStartFreshness.isCurrent(
            suggestion,
            currentPlan: makeLegacyExerciseOnlyStartFreshnessPlan(templateID: templateID, exerciseID: exerciseID)
        ))
    }

    func testChatWorkoutStartFreshnessRejectsChangedLegacyExerciseOnlyTemplate() {
        let templateID = UUID()
        let suggestion = SuggestedWorkoutEntry(
            name: "Legacy Pull Day",
            workoutType: LiveWorkout.WorkoutType.strength.rawValue,
            targetMuscleGroups: ["back"],
            exercises: [
                .init(
                    id: UUID(),
                    name: "Pull Up",
                    category: Exercise.Category.strength.rawValue,
                    sourcePlanBlockID: UUID(),
                    sets: 4,
                    reps: 6
                )
            ],
            sourcePlanTemplateID: templateID,
            durationMinutes: 45,
            rationale: "From your plan."
        )

        XCTAssertFalse(ChatWorkoutStartFreshness.isCurrent(
            suggestion,
            currentPlan: makeLegacyExerciseOnlyStartFreshnessPlan(templateID: templateID, exerciseID: UUID())
        ))
    }

    func testChatWorkoutStartSuggestionAllowsUnlinkedCustomCardsThroughPlanChanges() {
        let suggestion = SuggestedWorkoutEntry(
            name: "Custom Strength",
            workoutType: LiveWorkout.WorkoutType.strength.rawValue,
            targetMuscleGroups: ["back"],
            exercises: [
                .init(
                    name: "Pull Up",
                    category: Exercise.Category.strength.rawValue,
                    sets: 4,
                    reps: 6
                )
            ],
            sourcePlanTemplateID: nil,
            durationMinutes: 45,
            rationale: "Ready to start."
        )

        XCTAssertFalse(ChatWorkoutStartSuggestionContext.isStale(
            suggestion: suggestion,
            messageTimestamp: Date(timeIntervalSince1970: 100),
            currentPlanUpdatedAt: Date(timeIntervalSince1970: 101),
            currentTemplateIDs: nil
        ))
        XCTAssertTrue(ChatWorkoutStartFreshness.isCurrent(suggestion, currentPlan: nil))
    }

    func testChatWorkoutLogSuggestionRejectsCardsOlderThanCurrentPlanUpdate() {
        let templateID = UUID()
        let suggestion = SuggestedWorkoutLog(
            name: "Plan Pull Day",
            workoutType: LiveWorkout.WorkoutType.strength.rawValue,
            sourcePlanTemplateID: templateID,
            durationMinutes: 45,
            exercises: [
                .init(
                    name: "Pull Up",
                    category: Exercise.Category.strength.rawValue,
                    activityTypeName: "Strength",
                    sets: [.init(reps: 6, weightKg: nil)]
                )
            ],
            notes: nil
        )

        XCTAssertTrue(ChatWorkoutLogSuggestionContext.isStale(
            suggestion: suggestion,
            messageTimestamp: Date(timeIntervalSince1970: 100),
            currentPlanUpdatedAt: Date(timeIntervalSince1970: 101),
            currentTemplateIDs: [templateID]
        ))
    }

    func testChatWorkoutLogSuggestionRejectsMissingSourceTemplate() {
        let suggestion = SuggestedWorkoutLog(
            name: "Plan Pull Day",
            workoutType: LiveWorkout.WorkoutType.strength.rawValue,
            sourcePlanTemplateID: UUID(),
            durationMinutes: 45,
            exercises: [
                .init(
                    name: "Pull Up",
                    category: Exercise.Category.strength.rawValue,
                    activityTypeName: "Strength",
                    sets: [.init(reps: 6, weightKg: nil)]
                )
            ],
            notes: nil
        )

        XCTAssertTrue(ChatWorkoutLogSuggestionContext.isStale(
            suggestion: suggestion,
            messageTimestamp: Date(timeIntervalSince1970: 100),
            currentPlanUpdatedAt: Date(timeIntervalSince1970: 100),
            currentTemplateIDs: []
        ))
        XCTAssertTrue(ChatWorkoutLogSuggestionContext.isStale(
            suggestion: suggestion,
            messageTimestamp: Date(timeIntervalSince1970: 100),
            currentPlanUpdatedAt: nil,
            currentTemplateIDs: nil
        ))
    }

    func testChatWorkoutLogSuggestionAllowsUnlinkedCustomCardsThroughPlanChanges() {
        let suggestion = SuggestedWorkoutLog(
            name: "Custom Strength",
            workoutType: LiveWorkout.WorkoutType.strength.rawValue,
            sourcePlanTemplateID: nil,
            durationMinutes: 45,
            exercises: [
                .init(
                    name: "Pull Up",
                    category: Exercise.Category.strength.rawValue,
                    activityTypeName: "Strength",
                    sets: [.init(reps: 6, weightKg: nil)]
                )
            ],
            notes: nil
        )

        XCTAssertFalse(ChatWorkoutLogSuggestionContext.isStale(
            suggestion: suggestion,
            messageTimestamp: Date(timeIntervalSince1970: 100),
            currentPlanUpdatedAt: Date(timeIntervalSince1970: 101),
            currentTemplateIDs: nil
        ))
    }

    func testChatWorkoutPlanSuggestionContextRejectsExternallyStaleCards() {
        let stalePlan = WorkoutPlan(
            splitType: .custom,
            daysPerWeek: 1,
            templates: [
                WorkoutPlan.WorkoutTemplate(
                    name: "Old Pull",
                    sessionType: .strength,
                    targetMuscleGroups: ["back"],
                    exercises: [],
                    estimatedDurationMinutes: 45,
                    order: 0
                )
            ],
            rationale: "Old plan",
            guidelines: [],
            progressionStrategy: .defaultStrategy
        )
        let freshPlan = WorkoutPlan(
            splitType: .custom,
            daysPerWeek: 1,
            templates: [
                WorkoutPlan.WorkoutTemplate(
                    name: "Fresh Pull",
                    sessionType: .strength,
                    targetMuscleGroups: ["back"],
                    exercises: [],
                    estimatedDurationMinutes: 45,
                    order: 0
                )
            ],
            rationale: "Fresh plan",
            guidelines: [],
            progressionStrategy: .defaultStrategy
        )
        let staleMessage = ChatMessage(content: "", isFromUser: false)
        staleMessage.timestamp = Date(timeIntervalSince1970: 100)
        staleMessage.setSuggestedWorkoutPlan(WorkoutPlanSuggestionEntry(plan: stalePlan, message: "Old"))
        let freshMessage = ChatMessage(content: "", isFromUser: false)
        freshMessage.timestamp = Date(timeIntervalSince1970: 102)
        freshMessage.setSuggestedWorkoutPlan(WorkoutPlanSuggestionEntry(plan: freshPlan, message: "Fresh"))

        XCTAssertNil(ChatWorkoutPlanSuggestionContext.latestFreshSuggestion(
            in: [staleMessage],
            currentPlanUpdatedAt: Date(timeIntervalSince1970: 101)
        ))

        let suggestion = ChatWorkoutPlanSuggestionContext.latestFreshSuggestion(
            in: [staleMessage, freshMessage],
            currentPlanUpdatedAt: Date(timeIntervalSince1970: 101)
        )
        XCTAssertEqual(suggestion?.plan.templates.first?.name, "Fresh Pull")
    }

    func testChatWorkoutPlanSuggestionContextCanUseFreshRetiredSuggestionForRetry() {
        let plan = WorkoutPlan(
            splitType: .custom,
            daysPerWeek: 1,
            templates: [
                WorkoutPlan.WorkoutTemplate(
                    name: "Retry Pull",
                    sessionType: .strength,
                    targetMuscleGroups: ["back"],
                    exercises: [],
                    estimatedDurationMinutes: 45,
                    order: 0
                )
            ],
            rationale: "Fresh retired plan",
            guidelines: [],
            progressionStrategy: .defaultStrategy
        )
        let message = ChatMessage(content: "", isFromUser: false)
        message.timestamp = Date(timeIntervalSince1970: 102)
        message.setSuggestedWorkoutPlan(WorkoutPlanSuggestionEntry(plan: plan, message: "Retry"))
        message.suggestedWorkoutPlanDismissed = true

        XCTAssertNil(ChatWorkoutPlanSuggestionContext.latestFreshSuggestion(
            in: [message],
            currentPlanUpdatedAt: Date(timeIntervalSince1970: 101)
        ))

        let retrySuggestion = ChatWorkoutPlanSuggestionContext.latestFreshSuggestion(
            in: [message],
            currentPlanUpdatedAt: Date(timeIntervalSince1970: 101),
            includeRetired: true
        )
        XCTAssertEqual(retrySuggestion?.plan.templates.first?.name, "Retry Pull")

        message.workoutPlanUpdateApplied = true
        XCTAssertNil(ChatWorkoutPlanSuggestionContext.latestFreshSuggestion(
            in: [message],
            currentPlanUpdatedAt: Date(timeIntervalSince1970: 101),
            includeRetired: true
        ))
    }

    func testChatNutritionPlanSuggestionContextRejectsExternallyStaleCards() {
        let staleMessage = ChatMessage(content: "", isFromUser: false)
        staleMessage.timestamp = Date(timeIntervalSince1970: 100)
        staleMessage.setSuggestedPlan(PlanUpdateSuggestionEntry(
            calories: 2_100,
            proteinGrams: 170,
            carbsGrams: 190,
            fatGrams: 65,
            fiberGrams: nil,
            sugarGrams: nil,
            goal: nil,
            rationale: "Old proposal"
        ))
        let freshMessage = ChatMessage(content: "", isFromUser: false)
        freshMessage.timestamp = Date(timeIntervalSince1970: 102)
        freshMessage.setSuggestedPlan(PlanUpdateSuggestionEntry(
            calories: 2_250,
            proteinGrams: 180,
            carbsGrams: 210,
            fatGrams: 70,
            fiberGrams: nil,
            sugarGrams: nil,
            goal: nil,
            rationale: "Fresh proposal"
        ))

        XCTAssertNil(ChatNutritionPlanSuggestionContext.latestFreshSuggestion(
            in: [staleMessage],
            currentPlanUpdatedAt: Date(timeIntervalSince1970: 101)
        ))

        let suggestion = ChatNutritionPlanSuggestionContext.latestFreshSuggestion(
            in: [staleMessage, freshMessage],
            currentPlanUpdatedAt: Date(timeIntervalSince1970: 101)
        )
        XCTAssertEqual(suggestion?.calories, 2_250)
        XCTAssertEqual(suggestion?.proteinGrams, 180)
    }

    func testChatNutritionPlanSuggestionContextCanUseFreshRetiredSuggestionForRetry() {
        let message = ChatMessage(content: "", isFromUser: false)
        message.timestamp = Date(timeIntervalSince1970: 102)
        message.setSuggestedPlan(PlanUpdateSuggestionEntry(
            calories: 2_300,
            proteinGrams: 185,
            carbsGrams: 220,
            fatGrams: 72,
            fiberGrams: 32,
            sugarGrams: 55,
            goal: "build_muscle",
            rationale: "Fresh retired proposal"
        ))
        message.suggestedPlanDismissed = true

        XCTAssertNil(ChatNutritionPlanSuggestionContext.latestFreshSuggestion(
            in: [message],
            currentPlanUpdatedAt: Date(timeIntervalSince1970: 101)
        ))

        let retrySuggestion = ChatNutritionPlanSuggestionContext.latestFreshSuggestion(
            in: [message],
            currentPlanUpdatedAt: Date(timeIntervalSince1970: 101),
            includeRetired: true
        )
        XCTAssertEqual(retrySuggestion?.calories, 2_300)
        XCTAssertEqual(retrySuggestion?.goal, "build_muscle")

        message.planUpdateApplied = true
        XCTAssertNil(ChatNutritionPlanSuggestionContext.latestFreshSuggestion(
            in: [message],
            currentPlanUpdatedAt: Date(timeIntervalSince1970: 101),
            includeRetired: true
        ))
    }

    func testFunctionCallingPromptIncludesPendingNutritionPlanSuggestion() {
        let suggestion = PlanUpdateSuggestionEntry(
            calories: 2_300,
            proteinGrams: 185,
            carbsGrams: 220,
            fatGrams: 72,
            fiberGrams: 32,
            sugarGrams: 55,
            goal: "build_muscle",
            rationale: "Fuel the current training block"
        )
        let prompt = AIService.pendingNutritionPlanPromptSection(suggestion: suggestion)

        XCTAssertTrue(prompt.contains("PENDING NUTRITION PLAN PROPOSAL"))
        XCTAssertTrue(prompt.contains("Calories: 2300 kcal"))
        XCTAssertTrue(prompt.contains("Protein: 185g"))
        XCTAssertTrue(prompt.contains("Carbs: 220g"))
        XCTAssertTrue(prompt.contains("Goal: Build Muscle"))
        XCTAssertTrue(prompt.contains("treat this pending proposal as the current draft"))
    }

    func testOnboardingPlanInputInvalidationIncludesGeneratedWorkoutReviewState() {
        XCTAssertTrue(OnboardingPlanInputInvalidation.shouldResetGeneratedPlanState(
            oldSignature: "old",
            newSignature: "new",
            hasNutritionState: false,
            hasWorkoutReviewState: true
        ))
        XCTAssertFalse(OnboardingPlanInputInvalidation.shouldResetGeneratedPlanState(
            oldSignature: "old",
            newSignature: "old",
            hasNutritionState: true,
            hasWorkoutReviewState: true
        ))
        XCTAssertFalse(OnboardingPlanInputInvalidation.shouldResetGeneratedPlanState(
            oldSignature: "old",
            newSignature: "new",
            hasNutritionState: false,
            hasWorkoutReviewState: false
        ))
    }

    func testFunctionFollowUpMergePreservesChainedWorkoutStartAndLogSuggestions() {
        var result = AIService.FunctionFollowUpResult()
        let workout = SuggestedWorkoutEntry(
            name: "Plan Pull Day",
            workoutType: "strength",
            targetMuscleGroups: ["back"],
            exercises: [],
            sourcePlanTemplateID: UUID(),
            durationMinutes: 45,
            rationale: "From your current plan"
        )
        let workoutLog = SuggestedWorkoutLog(
            name: "Plan Pull Day",
            workoutType: "strength",
            sourcePlanTemplateID: UUID(),
            durationMinutes: 45,
            exercises: [],
            notes: nil
        )
        var chainedResult = AIService.FunctionFollowUpResult()
        chainedResult.text = "Ready."
        chainedResult.suggestedWorkout = workout
        chainedResult.suggestedWorkoutLog = workoutLog

        result.mergeChainedResult(chainedResult)

        XCTAssertTrue(result.hasSuggestion)
        XCTAssertEqual(result.text, "Ready.")
        XCTAssertEqual(result.suggestedWorkout?.id, workout.id)
        XCTAssertEqual(result.suggestedWorkoutLog?.id, workoutLog.id)
    }

    func testLogWorkoutUsesTopLevelDurationForSingleNonStrengthActivity() async throws {
        let result = await AIFunctionExecutor(modelContext: context, userProfile: nil).execute(
            .init(
                name: "log_workout",
                arguments: [
                    "name": "Easy Run",
                    "type": "cardio",
                    "duration_minutes": 35,
                    "exercises": [
                        [
                            "name": "Easy Run",
                            "category": "cardio",
                            "activity_name": "Running"
                        ]
                    ]
                ]
            )
        )

        guard case .suggestedWorkoutLog(let workoutLog) = result,
              let exercise = workoutLog.exercises.first else {
            return XCTFail("Expected workout log suggestion")
        }

        XCTAssertEqual(workoutLog.durationMinutes, 35)
        XCTAssertEqual(exercise.category, "cardio")
        XCTAssertEqual(exercise.activityTypeName, "Running")
        XCTAssertEqual(exercise.durationMinutes, 35)
    }

    func testSuggestWorkoutUsesActivityFocusesInsteadOfStrengthFallback() async throws {
        let bouldering = Exercise(name: "Limit Bouldering", category: .sportPractice)
        bouldering.activityTypeName = "Bouldering"
        bouldering.targetTags = ["Climbing", "Grip power"]
        bouldering.trackingFields = [.duration, .reps, .notes]
        context.insert(bouldering)

        let result = await AIFunctionExecutor(modelContext: context, userProfile: nil).execute(
            .init(
                name: "suggest_workout",
                arguments: [
                    "workout_type": "mixed",
                    "activity_focuses": ["Bouldering"],
                    "duration_minutes": 30
                ]
            )
        )

        guard case .suggestedWorkoutStart(let suggestion) = result else {
            return XCTFail("Expected start workout suggestion")
        }

        XCTAssertEqual(suggestion.activityFocuses, ["Bouldering"])
        XCTAssertEqual(suggestion.targetMuscleGroups, [])
        XCTAssertEqual(suggestion.exercisesSummary, "1 activity")
        XCTAssertEqual(suggestion.exercises.first?.name, "Limit Bouldering")
        XCTAssertEqual(suggestion.exercises.first?.category, "sportPractice")
        XCTAssertEqual(suggestion.exercises.first?.activityTypeName, "Bouldering")
        XCTAssertEqual(suggestion.exercises.first?.sets, 0)
        XCTAssertEqual(suggestion.exercises.first?.durationMinutes, 30)
    }

    func testSuggestWorkoutCreatesTrackableCustomActivityWhenLibraryHasNoMatch() async throws {
        let result = await AIFunctionExecutor(modelContext: context, userProfile: nil).execute(
            .init(
                name: "suggest_workout",
                arguments: [
                    "workout_type": "custom",
                    "activity_focuses": ["Basketball"],
                    "duration_minutes": 40
                ]
            )
        )

        guard case .suggestedWorkoutStart(let suggestion) = result else {
            return XCTFail("Expected start workout suggestion")
        }

        XCTAssertEqual(suggestion.exercisesSummary, "1 activity")
        XCTAssertEqual(suggestion.exercises.first?.name, "Basketball")
        XCTAssertEqual(suggestion.exercises.first?.category, "custom")
        XCTAssertEqual(suggestion.exercises.first?.activityTypeName, "Basketball")
        XCTAssertEqual(suggestion.exercises.first?.trackingFields, ["duration", "notes"])
        XCTAssertEqual(suggestion.exercises.first?.sets, 0)
        XCTAssertEqual(suggestion.exercises.first?.durationMinutes, 40)
    }

    func testSuggestWorkoutPreservesUnknownCustomActivityIdentityWhenLibraryHasNoMatch() async throws {
        let result = await AIFunctionExecutor(modelContext: context, userProfile: nil).execute(
            .init(
                name: "suggest_workout",
                arguments: [
                    "workout_type": "custom",
                    "activity_focuses": ["Dance"],
                    "duration_minutes": 35
                ]
            )
        )

        guard case .suggestedWorkoutStart(let suggestion) = result,
              let exercise = suggestion.exercises.first else {
            return XCTFail("Expected start workout suggestion")
        }

        XCTAssertEqual(suggestion.activityFocuses, ["Dance"])
        XCTAssertEqual(exercise.name, "Dance")
        XCTAssertEqual(exercise.category, "custom")
        XCTAssertEqual(exercise.activityTypeName, "Dance")
        XCTAssertEqual(exercise.targetTags, ["Dance"])
        XCTAssertEqual(exercise.startSummarySegments, ["35 min"])
    }

    func testSuggestWorkoutUsesSavedPlanWhenNoExplicitPreference() async throws {
        let template = WorkoutPlan.WorkoutTemplate(
            name: "Bouldering Day",
            sessionType: .climbing,
            focusAreas: ["Bouldering"],
            targetMuscleGroups: [],
            exercises: [],
            blocks: [
                WorkoutPlan.TrainingBlock(
                    kind: .skill,
                    title: "Bouldering",
                    detail: "Technique practice",
                    activityTypeName: "Bouldering",
                    activityTags: ["Climbing", "Technique"],
                    durationMinutes: 35,
                    order: 0
                )
            ],
            estimatedDurationMinutes: 35,
            order: 0
        )
        let profile = UserProfile()
        profile.workoutPlan = WorkoutPlan(
            splitType: .custom,
            daysPerWeek: 1,
            templates: [template],
            rationale: "Climbing-specific plan",
            guidelines: [],
            progressionStrategy: .defaultStrategy
        )

        let result = await AIFunctionExecutor(modelContext: context, userProfile: profile).execute(
            .init(name: "suggest_workout", arguments: [:])
        )

        guard case .suggestedWorkoutStart(let suggestion) = result,
              let exercise = suggestion.exercises.first else {
            return XCTFail("Expected start workout suggestion")
        }

        XCTAssertEqual(suggestion.name, "Bouldering Day")
        XCTAssertEqual(suggestion.workoutType, "climbing")
        XCTAssertEqual(suggestion.targetMuscleGroups, [])
        XCTAssertEqual(suggestion.activityFocuses, ["Bouldering", "Climbing", "Technique"])
        XCTAssertEqual(suggestion.sourcePlanTemplateID, template.id)
        XCTAssertEqual(exercise.name, "Bouldering")
        XCTAssertEqual(exercise.category, "sportPractice")
        XCTAssertEqual(exercise.durationMinutes, 35)
        XCTAssertTrue(suggestion.rationale.contains("from your plan"))
    }

    func testSuggestWorkoutPreservesAllSavedPlanBlocksWhenNoExplicitPreference() async throws {
        let template = WorkoutPlan.WorkoutTemplate(
            name: "Strength + Conditioning",
            sessionType: .mixed,
            focusAreas: ["Full Body", "Conditioning"],
            targetMuscleGroups: ["fullBody"],
            exercises: [],
            blocks: [
                WorkoutPlan.TrainingBlock(
                    kind: .strength,
                    title: "Strength",
                    detail: "Primary lifts",
                    exercises: [
                        .init(exerciseName: "Back Squat", muscleGroup: "quads", defaultSets: 3, defaultReps: 5, order: 0),
                        .init(exerciseName: "Bench Press", muscleGroup: "chest", defaultSets: 3, defaultReps: 5, order: 1)
                    ],
                    activityTypeName: "Strength",
                    activityTags: ["Full Body"],
                    order: 0
                ),
                WorkoutPlan.TrainingBlock(
                    kind: .conditioning,
                    role: .finisher,
                    title: "Finisher",
                    detail: "Bike intervals",
                    activityTypeName: "Cycling",
                    activityTags: ["Conditioning"],
                    durationMinutes: 12,
                    order: 1,
                    notes: "Easy warmup, then short hard intervals."
                )
            ],
            estimatedDurationMinutes: 55,
            order: 0
        )
        let profile = UserProfile()
        profile.workoutPlan = WorkoutPlan(
            splitType: .custom,
            daysPerWeek: 1,
            templates: [template],
            rationale: "Mixed plan",
            guidelines: [],
            progressionStrategy: .defaultStrategy
        )

        let result = await AIFunctionExecutor(modelContext: context, userProfile: profile).execute(
            .init(name: "suggest_workout", arguments: [:])
        )

        guard case .suggestedWorkoutStart(let suggestion) = result else {
            return XCTFail("Expected start workout suggestion")
        }

        XCTAssertEqual(suggestion.sourcePlanTemplateID, template.id)
        XCTAssertEqual(suggestion.exercises.map(\.name), ["Back Squat", "Bench Press", "Cycling"])
        XCTAssertEqual(suggestion.exercises.map(\.category), ["strength", "strength", "conditioning"])
        XCTAssertEqual(suggestion.exercises.map(\.activityRole), ["main", "main", "finisher"])
        XCTAssertEqual(suggestion.exercises[0].sourcePlanBlockID, template.blocks[0].id)
        XCTAssertEqual(suggestion.exercises[1].sourcePlanBlockID, template.blocks[0].id)
        XCTAssertEqual(suggestion.exercises[2].sourcePlanBlockID, nil)
        XCTAssertEqual(suggestion.exercises[2].activityTypeName, "Cycling")
        XCTAssertEqual(suggestion.exercises[2].targetTags, ["Conditioning", "Cycling"])
        XCTAssertEqual(suggestion.exercises[2].durationMinutes, 12)
    }

    func testStartLiveWorkoutPreservesAIProvidedActivityCategory() async throws {
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
                            "category": "sportPractice",
                            "activity_name": "Bouldering",
                            "activity_role": "finisher",
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
        XCTAssertEqual(exercise.activityRole, "finisher")
        XCTAssertEqual(exercise.sets, 0)
        XCTAssertEqual(exercise.startSummarySegments, ["Bouldering", "30 min", "2 segments", "7 attempts"])
    }

    func testStartLiveWorkoutPreservesSourcePlanTemplateID() async throws {
        let template = WorkoutPlan.WorkoutTemplate(
            name: "Plan Pull Day",
            sessionType: .strength,
            targetMuscleGroups: ["back"],
            exercises: [
                .init(exerciseName: "Pull Up", muscleGroup: "back", defaultSets: 4, defaultReps: 6, order: 0)
            ],
            estimatedDurationMinutes: 45,
            order: 0
        )
        let profile = UserProfile()
        profile.workoutPlan = WorkoutPlan(
            splitType: .custom,
            daysPerWeek: 1,
            templates: [template],
            rationale: "Pull plan",
            guidelines: [],
            progressionStrategy: .defaultStrategy
        )

        let result = await AIFunctionExecutor(modelContext: context, userProfile: profile).execute(
            .init(
                name: "start_live_workout",
                arguments: [
                    "name": "Start my pull day",
                    "workout_type": "strength",
                    "source_plan_template_id": template.id.uuidString
                ]
            )
        )

        guard case .suggestedWorkoutStart(let suggestion) = result else {
            return XCTFail("Expected start workout suggestion")
        }

        XCTAssertEqual(suggestion.name, "Plan Pull Day")
        XCTAssertEqual(suggestion.sourcePlanTemplateID, template.id)
        XCTAssertEqual(suggestion.exercises.map(\.name), ["Pull Up"])
        XCTAssertEqual(suggestion.exercises.first?.sets, 4)
    }

    func testStartLiveWorkoutRejectsMalformedSourcePlanTemplateID() async throws {
        let result = await AIFunctionExecutor(modelContext: context, userProfile: nil).execute(
            .init(
                name: "start_live_workout",
                arguments: [
                    "name": "Start stale plan workout",
                    "workout_type": "strength",
                    "source_plan_template_id": "not-a-template-id",
                    "suggested_exercises": [
                        [
                            "name": "Pull Up",
                            "category": "strength",
                            "sets": 4,
                            "reps": 6
                        ]
                    ]
                ]
            )
        )

        guard case .dataResponse(let functionResult) = result else {
            return XCTFail("Expected validation error")
        }

        XCTAssertEqual(functionResult.name, "start_live_workout")
        XCTAssertEqual(functionResult.response["error"] as? String, "source_plan_template_id must be an exact template id from the current workout plan.")
    }

    func testStartLiveWorkoutRejectsMissingStableCategory() async throws {
        let result = await AIFunctionExecutor(modelContext: context, userProfile: nil).execute(
            .init(
                name: "start_live_workout",
                arguments: [
                    "name": "Climbing Power",
                    "workout_type": "mixed",
                    "suggested_exercises": [
                        [
                            "name": "Limit Bouldering",
                            "activity_name": "Bouldering",
                            "duration_minutes": 30
                        ]
                    ]
                ]
            )
        )

        guard case .dataResponse(let functionResult) = result else {
            return XCTFail("Expected validation error")
        }

        XCTAssertNotNil(functionResult.response["error"])
    }

    func testStartLiveWorkoutRejectsMissingSuggestedExercises() async throws {
        let result = await AIFunctionExecutor(modelContext: context, userProfile: nil).execute(
            .init(
                name: "start_live_workout",
                arguments: [
                    "name": "Bouldering Session",
                    "workout_type": "climbing",
                    "activity_focuses": ["Bouldering"],
                    "duration_minutes": 45
                ]
            )
        )

        guard case .dataResponse(let functionResult) = result else {
            return XCTFail("Expected validation error")
        }

        XCTAssertEqual(functionResult.response["error"] as? String, "start_live_workout needs at least one suggested exercise/activity item with stable category and activity_name.")
    }

    func testStartLiveWorkoutUsesCustomCategoryForUnknownNamedActivity() async throws {
        let result = await AIFunctionExecutor(modelContext: context, userProfile: nil).execute(
            .init(
                name: "start_live_workout",
                arguments: [
                    "name": "Dance Practice",
                    "workout_type": "mixed",
                    "activity_focuses": ["Dance"],
                    "suggested_exercises": [
                        [
                            "name": "Dance Flow",
                            "category": "custom",
                            "activity_name": "Dance"
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
        XCTAssertEqual(exercise.category, "custom")
        XCTAssertEqual(exercise.activityTypeName, "Dance")
        XCTAssertEqual(exercise.sets, 0)
        XCTAssertEqual(exercise.reps, 0)
        XCTAssertEqual(exercise.trackingFields, ["duration", "notes"])
        XCTAssertFalse(exercise.isStrengthStartItem)
    }

    func testStartLiveWorkoutRejectsNonStrengthWithoutActivityName() async throws {
        let result = await AIFunctionExecutor(modelContext: context, userProfile: nil).execute(
            .init(
                name: "start_live_workout",
                arguments: [
                    "name": "Dance Practice",
                    "workout_type": "mixed",
                    "suggested_exercises": [
                        [
                            "name": "Dance Flow",
                            "category": "sportPractice",
                            "tracking_fields": ["duration", "reps", "notes"],
                            "duration_minutes": 30
                        ]
                    ]
                ]
            )
        )

        guard case .dataResponse(let functionResult) = result else {
            return XCTFail("Expected validation error")
        }

        XCTAssertNotNil(functionResult.response["error"])
    }

    func testStartLiveWorkoutStoresNormalizedActivityCategoryAndTrackingFields() async throws {
        let result = await AIFunctionExecutor(modelContext: context, userProfile: nil).execute(
            .init(
                name: "start_live_workout",
                arguments: [
                    "name": "Run Intervals",
                    "workout_type": "cardio",
                    "suggested_exercises": [
                        [
                            "name": "Run Intervals",
                            "category": "cardio",
                            "activity_name": "Running",
                            "target_tags": ["Cardio", "Intervals"],
                            "tracking_fields": ["duration", "calories", "distance"],
                            "duration_minutes": 28,
                            "distance_meters": 4_000
                        ]
                    ]
                ]
            )
        )

        guard case .suggestedWorkoutStart(let suggestion) = result,
              let exercise = suggestion.exercises.first else {
            return XCTFail("Expected start workout suggestion")
        }

        XCTAssertEqual(exercise.category, "cardio")
        XCTAssertEqual(suggestion.activityFocuses ?? [], ["Running", "Cardio", "Intervals"])
        XCTAssertEqual(exercise.trackingFields ?? [], ["duration", "distance"])
        XCTAssertFalse(exercise.trackingFields?.contains("calories") ?? false)
        XCTAssertEqual(exercise.startSummarySegments, ["Running", "28 min", "4.0 km"])
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

    func testNonStrengthSetMetricsCountAsActivityHistory() {
        let entry = LiveWorkoutEntry(exerciseName: "Limit Bouldering", orderIndex: 0, exerciseType: "sportPractice")
        entry.activityTypeName = "Bouldering"
        entry.activityKind = .sportPractice
        entry.trackingFields = [.sets, .reps]
        entry.addSet(.init(reps: 4, weight: .zero, completed: true, isWarmup: false))
        entry.addSet(.init(reps: 3, weight: .zero, completed: true, isWarmup: false))

        let history = ExerciseHistory(from: entry)

        XCTAssertTrue(entry.hasExercisePreferenceSignal)
        XCTAssertEqual(history.totalSets, 2)
        XCTAssertEqual(history.totalReps, 7)
        XCTAssertEqual(history.repPattern, "4,3")
    }

    func testStartWorkoutActivitySummaryUsesActivityNameForMetricLabels() {
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

    func testSuggestedWorkoutStartUsesStableCategoryOnly() {
        let run = SuggestedWorkoutEntry.SuggestedExercise(
            name: "Outdoor Run",
            category: "cardio",
            activityTypeName: "Running",
            targetTags: ["Cardio"],
            trackingFields: ["duration", "distance"],
            sets: 3,
            reps: 0,
            weightKg: nil,
            durationMinutes: 30,
            distanceMeters: 5_000,
            notes: nil,
            segments: nil
        )

        XCTAssertFalse(run.isStrengthStartItem)
        XCTAssertTrue(run.isActivityStartItem)
        XCTAssertEqual(run.startSummarySegments, ["Running", "30 min", "5.0 km"])
    }

    func testSuggestedWorkoutLogUsesStableCategoryOnly() {
        let padel = SuggestedWorkoutLog.LoggedExercise(
            name: "Padel Drills",
            category: "sportPractice",
            activityTypeName: "Padel",
            targetTags: ["Sport", "Footwork"],
            trackingFields: ["duration", "reps", "notes"],
            durationMinutes: 45,
            distanceMeters: nil,
            notes: nil,
            segments: [
                .init(durationMinutes: 20, reps: 8, notes: "Cross-court volleys"),
                .init(durationMinutes: 20, reps: 6, notes: "Wall returns")
            ],
            sets: []
        )

        XCTAssertFalse(padel.isStrengthLog)
        XCTAssertTrue(padel.isActivityLog)
        XCTAssertEqual(padel.setCount, 0)
        XCTAssertEqual(padel.activitySummarySegments, ["Padel", "45 min", "2 segments", "14 attempts"])
    }

    func testSuggestedWorkoutLogUsesActivityNameForMetricLabels() {
        let padel = SuggestedWorkoutLog.LoggedExercise(
            name: "Padel Drills",
            category: "sportPractice",
            activityTypeName: "Padel",
            targetTags: ["Footwork"],
            trackingFields: ["duration", "reps", "notes"],
            durationMinutes: 45,
            distanceMeters: nil,
            notes: nil,
            segments: [
                .init(durationMinutes: 20, reps: 8, notes: "Cross-court volleys"),
                .init(durationMinutes: 20, reps: 6, notes: "Wall returns")
            ],
            sets: []
        )

        XCTAssertFalse(padel.isStrengthLog)
        XCTAssertTrue(padel.isActivityLog)
        XCTAssertEqual(padel.activitySummarySegments, ["Padel", "45 min", "2 segments", "14 attempts"])
    }

    func testSuggestedWorkoutCategoryNormalizationDoesNotMisclassifyCableRow() {
        let startExercise = SuggestedWorkoutEntry.SuggestedExercise(
            name: "Cable Row",
            category: "Cable Row",
            activityTypeName: nil,
            targetTags: ["Back"],
            trackingFields: ["sets", "weight"],
            sets: 3,
            reps: 10,
            weightKg: 50,
            durationMinutes: nil,
            distanceMeters: nil,
            notes: nil,
            segments: nil
        )
        let loggedExercise = SuggestedWorkoutLog.LoggedExercise(
            name: "Cable Row",
            category: "Cable Row",
            trackingFields: ["sets", "weight"],
            sets: [
                .init(reps: 10, weightKg: 50),
                .init(reps: 10, weightKg: 50),
                .init(reps: 10, weightKg: 50)
            ]
        )

        XCTAssertTrue(startExercise.isStrengthStartItem)
        XCTAssertEqual(startExercise.startSummarySegments, ["3x10", "50 kg"])
        XCTAssertTrue(loggedExercise.isStrengthLog)
        XCTAssertEqual(loggedExercise.setCount, 3)
    }

    func testCustomActivitySummaryUsesRepsInsteadOfGenericCounts() {
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

        XCTAssertEqual(exercise.startSummarySegments, ["3 reps"])
    }

    func testCustomActivityDefaultNameUsesExerciseNameInsteadOfCustomLabel() {
        XCTAssertEqual(
            Exercise.defaultActivityTypeName(for: "Dance", category: .custom),
            "Dance"
        )
        XCTAssertEqual(
            Exercise.defaultActivityTypeName(for: "  Footwork Flow  ", category: .custom),
            "Footwork Flow"
        )
        XCTAssertEqual(
            Exercise.defaultActivityTypeName(for: "Elliptical", category: .cardio),
            "Elliptical"
        )
        XCTAssertEqual(
            Exercise.defaultActivityTypeName(for: "Hip Mobility Flow", category: .mobility),
            "Hip Mobility Flow"
        )
    }

    func testTargetMuscleParsingHandlesDisplayNames() {
        XCTAssertEqual(LiveWorkout.MuscleGroup.fromTargetStrings(["Full Body"]), [.fullBody])
        XCTAssertEqual(
            LiveWorkout.MuscleGroup.fromTargetStrings(["Lower Body"]),
            LiveWorkout.MuscleGroup.legMuscles
        )
    }

    func testCreateWorkoutGoalRejectsFreeTextWorkoutType() async throws {
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

        guard case .dataResponse(let functionResult) = result else {
            return XCTFail("Expected workout goal error response")
        }

        XCTAssertEqual(functionResult.response["error"] as? String, "workout_type must be a stable workout mode enum. Put user-facing activity names in activity_name or activity_tags.")
    }

    func testWorkoutGoalFunctionsPreserveActivityKindAndRoleScope() async throws {
        let executor = AIFunctionExecutor(modelContext: context, userProfile: nil)
        let createResult = await executor.execute(
            .init(
                name: "create_workout_goal",
                arguments: [
                    "title": "Complete weekly mobility support",
                    "goal_kind": "frequency",
                    "workout_type": "mixed",
                    "activity_name": "Mobility Flow",
                    "activity_tags": ["Mobility", "Hips"],
                    "activity_kind": "mobility",
                    "activity_role": "cooldown",
                    "target_value": 1,
                    "target_unit": "blocks",
                    "period_unit": "week",
                    "period_count": 1,
                    "success_criteria": "You log the planned mobility cooldown once per week."
                ]
            )
        )

        guard case .dataResponse(let createFunctionResult) = createResult,
              let createdGoal = createFunctionResult.response["goal"] as? [String: Any],
              let goalId = createdGoal["id"] as? String else {
            return XCTFail("Expected created workout goal response")
        }

        XCTAssertEqual(createdGoal["activity_kind"] as? String, "mobility")
        XCTAssertEqual(createdGoal["activity_role"] as? String, "cooldown")

        let getResult = await executor.execute(
            .init(
                name: "get_workout_goals",
                arguments: ["status": "active"]
            )
        )

        guard case .dataResponse(let getFunctionResult) = getResult,
              let goals = getFunctionResult.response["goals"] as? [[String: Any]],
              let fetchedGoal = goals.first(where: { $0["id"] as? String == goalId }) else {
            return XCTFail("Expected fetched workout goal response")
        }

        XCTAssertEqual(fetchedGoal["activity_kind"] as? String, "mobility")
        XCTAssertEqual(fetchedGoal["activity_role"] as? String, "cooldown")

        let updateResult = await executor.execute(
            .init(
                name: "update_workout_goal",
                arguments: [
                    "goal_id": goalId,
                    "activity_role": "warmup"
                ]
            )
        )

        guard case .dataResponse(let updateFunctionResult) = updateResult,
              let updatedGoal = updateFunctionResult.response["goal"] as? [String: Any] else {
            return XCTFail("Expected updated workout goal response")
        }

        XCTAssertEqual(updatedGoal["activity_kind"] as? String, "mobility")
        XCTAssertEqual(updatedGoal["activity_role"] as? String, "warmup")

        let invalidUpdateResult = await executor.execute(
            .init(
                name: "update_workout_goal",
                arguments: [
                    "goal_id": goalId,
                    "activity_role": "stretch-break"
                ]
            )
        )

        guard case .dataResponse(let invalidUpdateFunctionResult) = invalidUpdateResult else {
            return XCTFail("Expected invalid workout goal response")
        }

        XCTAssertEqual(
            invalidUpdateFunctionResult.response["error"] as? String,
            "activity_role must be a stable training block role enum."
        )

        let refetchResult = await executor.execute(
            .init(
                name: "get_workout_goals",
                arguments: ["status": "active"]
            )
        )

        guard case .dataResponse(let refetchFunctionResult) = refetchResult,
              let refetchedGoals = refetchFunctionResult.response["goals"] as? [[String: Any]],
              let refetchedGoal = refetchedGoals.first(where: { $0["id"] as? String == goalId }) else {
            return XCTFail("Expected refetched workout goal response")
        }

        XCTAssertEqual(refetchedGoal["activity_kind"] as? String, "mobility")
        XCTAssertEqual(refetchedGoal["activity_role"] as? String, "warmup")
    }

    func testCreateWorkoutGoalNormalizesGeneratedPlanAdherenceScope() async throws {
        let template = WorkoutPlan.WorkoutTemplate(
            name: "Pull + Climb",
            sessionType: .mixed,
            focusAreas: ["Pull", "Climbing"],
            targetMuscleGroups: ["back"],
            exercises: [],
            estimatedDurationMinutes: 50,
            order: 0
        )
        let profile = UserProfile()
        profile.workoutPlan = WorkoutPlan(
            splitType: .custom,
            daysPerWeek: 1,
            templates: [template],
            rationale: "Plan",
            guidelines: [],
            progressionStrategy: .defaultStrategy
        )
        let executor = AIFunctionExecutor(modelContext: context, userProfile: profile)

        let result = await executor.execute(
            .init(
                name: "create_workout_goal",
                arguments: [
                    "title": "Complete my generated plan",
                    "goal_kind": "frequency",
                    "tracks_plan_adherence": true,
                    "target_value": 1,
                    "target_unit": "sessions",
                    "period_unit": "week",
                    "period_count": 1,
                    "success_criteria": "Complete the generated weekly plan."
                ]
            )
        )

        guard case .dataResponse(let functionResult) = result,
              functionResult.response["success"] as? Bool == true else {
            return XCTFail("Expected created workout goal response")
        }

        let goals = try context.fetch(FetchDescriptor<WorkoutGoal>())
        let goal = try XCTUnwrap(goals.first)
        XCTAssertEqual(goal.generatedPlanTemplateIDs, [template.id])
        XCTAssertNil(goal.linkedWorkoutType)
        XCTAssertFalse(goal.hasActivityScope)
    }

    func testGeneratedPlanAdherenceGoalReconcilesWhenPlanTemplateIDsChange() {
        let originalTemplate = WorkoutPlan.WorkoutTemplate(
            name: "Original Strength",
            sessionType: .strength,
            targetMuscleGroups: ["Back"],
            exercises: [],
            estimatedDurationMinutes: 45,
            order: 0
        )
        let originalPlan = WorkoutPlan(
            splitType: .custom,
            daysPerWeek: 1,
            templates: [originalTemplate],
            rationale: "Original plan",
            guidelines: [],
            progressionStrategy: .defaultStrategy
        )
        let revisedTemplates = [
            WorkoutPlan.WorkoutTemplate(
                name: "Revised Strength",
                sessionType: .strength,
                targetMuscleGroups: ["Back"],
                exercises: [],
                estimatedDurationMinutes: 45,
                order: 0
            ),
            WorkoutPlan.WorkoutTemplate(
                name: "New Conditioning",
                sessionType: .hiit,
                targetMuscleGroups: [],
                exercises: [],
                blocks: [
                    .init(
                        kind: .conditioning,
                        role: .main,
                        title: "Bike",
                        detail: "Intervals",
                        activityTypeName: "Cycling",
                        durationMinutes: 25,
                        order: 0
                    )
                ],
                estimatedDurationMinutes: 30,
                order: 1
            )
        ]
        let revisedPlan = WorkoutPlan(
            splitType: .custom,
            daysPerWeek: 2,
            templates: revisedTemplates,
            rationale: "Revised plan",
            guidelines: [],
            progressionStrategy: .defaultStrategy
        )
        let goal = WorkoutGoal(
            title: "Complete my generated plan",
            goalKind: .frequency,
            linkedWorkoutType: .strength,
            linkedActivityTags: ["old"],
            targetValue: 1,
            targetUnit: "sessions",
            periodUnit: .week,
            periodCount: 1,
            successCriteria: "Complete all planned sessions.",
            tracksGeneratedPlanAdherence: true
        )

        goal.normalizeGeneratedPlanAdherenceScopeIfNeeded(for: originalPlan)
        XCTAssertEqual(goal.generatedPlanTemplateIDs, [originalTemplate.id])

        goal.normalizeGeneratedPlanAdherenceScopeIfNeeded(for: revisedPlan)

        XCTAssertEqual(goal.targetValue, 2.0)
        XCTAssertEqual(goal.generatedPlanTemplateIDs, revisedPlan.templates.map { $0.id })
        XCTAssertNil(goal.linkedWorkoutType)
        XCTAssertFalse(goal.hasActivityScope)
    }

    func testGeneratedPlanAdherenceGoalAcceptsDaysUnit() {
        let template = WorkoutPlan.WorkoutTemplate(
            name: "Generated Strength",
            sessionType: .strength,
            targetMuscleGroups: ["Back"],
            exercises: [],
            estimatedDurationMinutes: 45,
            order: 0
        )
        let plan = WorkoutPlan(
            splitType: .custom,
            daysPerWeek: 1,
            templates: [template],
            rationale: "Plan",
            guidelines: [],
            progressionStrategy: .defaultStrategy
        )
        let goal = WorkoutGoal(
            title: "Train one day from the plan",
            goalKind: .frequency,
            targetValue: 1,
            targetUnit: "days",
            periodUnit: .week,
            periodCount: 1,
            successCriteria: "Complete the generated plan day.",
            tracksGeneratedPlanAdherence: true
        )

        goal.normalizeGeneratedPlanAdherenceScopeIfNeeded(for: plan)

        XCTAssertEqual(goal.generatedPlanTemplateIDs, [template.id])
        XCTAssertEqual(goal.targetValue, 1.0)
        XCTAssertNil(goal.linkedWorkoutType)
    }

    func testGeneratedPlanAdherenceGoalUsesDurableFlagForFreeFormUnits() {
        let template = WorkoutPlan.WorkoutTemplate(
            name: "Generated Strength",
            sessionType: .strength,
            targetMuscleGroups: ["Back"],
            exercises: [],
            estimatedDurationMinutes: 45,
            order: 0
        )
        let plan = WorkoutPlan(
            splitType: .custom,
            daysPerWeek: 1,
            templates: [template],
            rationale: "Plan",
            guidelines: [],
            progressionStrategy: .defaultStrategy
        )
        let goal = WorkoutGoal(
            title: "Complete the planned session",
            goalKind: .frequency,
            targetValue: 1,
            targetUnit: "planned sessions",
            periodUnit: .week,
            periodCount: 1,
            successCriteria: "Complete the generated plan session.",
            tracksGeneratedPlanAdherence: true
        )

        goal.normalizeGeneratedPlanAdherenceScopeIfNeeded(for: plan)

        XCTAssertEqual(goal.generatedPlanTemplateIDs, [template.id])
        XCTAssertNil(goal.linkedWorkoutType)
        XCTAssertFalse(goal.hasActivityScope)
    }

    func testGeneratedGoalsToInsertUsesStructuredDeduplicationAndNormalizesPlanAdherence() {
        let template = WorkoutPlan.WorkoutTemplate(
            name: "Generated Strength",
            sessionType: .strength,
            targetMuscleGroups: ["Back"],
            exercises: [],
            estimatedDurationMinutes: 45,
            order: 0
        )
        let plan = WorkoutPlan(
            splitType: .custom,
            daysPerWeek: 1,
            templates: [template],
            rationale: "Plan",
            guidelines: [],
            progressionStrategy: .defaultStrategy
        )
        let existingMainGoal = WorkoutGoal(
            title: "Train conditioning",
            goalKind: .frequency,
            linkedActivityKind: .conditioning,
            linkedActivityRole: .main,
            targetValue: 1,
            targetUnit: "session",
            periodUnit: .week,
            periodCount: 1
        )
        let duplicateMainGoal = WorkoutGoal(
            title: "Train conditioning",
            goalKind: .frequency,
            linkedActivityKind: .conditioning,
            linkedActivityRole: .main,
            targetValue: 1,
            targetUnit: "session",
            periodUnit: .week,
            periodCount: 1
        )
        let distinctFinisherGoal = WorkoutGoal(
            title: "Train conditioning",
            goalKind: .frequency,
            linkedActivityKind: .conditioning,
            linkedActivityRole: .finisher,
            targetValue: 1,
            targetUnit: "session",
            periodUnit: .week,
            periodCount: 1
        )
        let adherenceGoal = WorkoutGoal(
            title: "Complete plan",
            goalKind: .frequency,
            targetValue: 1,
            targetUnit: "days",
            periodUnit: .week,
            periodCount: 1,
            tracksGeneratedPlanAdherence: true
        )

        let goalsToInsert = WorkoutGoal.generatedGoalsToInsert(
            [duplicateMainGoal, distinctFinisherGoal, adherenceGoal],
            existingGoals: [existingMainGoal],
            for: plan
        )

        XCTAssertEqual(goalsToInsert.map(\.id), [distinctFinisherGoal.id, adherenceGoal.id])
        XCTAssertEqual(adherenceGoal.generatedPlanTemplateIDs, [template.id])
        XCTAssertEqual(adherenceGoal.targetValue, 1.0)
    }

    func testCreateWorkoutGoalRejectsFreeTextActivityKindAndRole() async throws {
        let executor = AIFunctionExecutor(modelContext: context, userProfile: nil)
        let invalidKindResult = await executor.execute(
            .init(
                name: "create_workout_goal",
                arguments: [
                    "title": "Complete weekly bouldering warmups",
                    "goal_kind": "frequency",
                    "workout_type": "mixed",
                    "activity_name": "Bouldering",
                    "activity_kind": "warmup",
                    "activity_role": "warmup",
                    "target_value": 1,
                    "target_unit": "blocks",
                    "period_unit": "week",
                    "period_count": 1,
                    "success_criteria": "Complete one bouldering warmup each week."
                ]
            )
        )

        guard case .dataResponse(let invalidKindFunctionResult) = invalidKindResult else {
            return XCTFail("Expected invalid activity kind response")
        }

        XCTAssertEqual(
            invalidKindFunctionResult.response["error"] as? String,
            "activity_kind must be a stable training block kind enum."
        )

        let invalidRoleResult = await executor.execute(
            .init(
                name: "create_workout_goal",
                arguments: [
                    "title": "Complete weekly bouldering warmups",
                    "goal_kind": "frequency",
                    "workout_type": "mixed",
                    "activity_name": "Bouldering",
                    "activity_kind": "skill",
                    "activity_role": "bouldering",
                    "target_value": 1,
                    "target_unit": "blocks",
                    "period_unit": "week",
                    "period_count": 1,
                    "success_criteria": "Complete one bouldering warmup each week."
                ]
            )
        )

        guard case .dataResponse(let invalidRoleFunctionResult) = invalidRoleResult else {
            return XCTFail("Expected invalid activity role response")
        }

        XCTAssertEqual(
            invalidRoleFunctionResult.response["error"] as? String,
            "activity_role must be a stable training block role enum."
        )
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

    func testUpdateWorkoutGoalRejectsFreeTextWorkoutType() async throws {
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

        guard case .dataResponse(let functionResult) = result else {
            return XCTFail("Expected workout goal error response")
        }

        XCTAssertEqual(functionResult.response["error"] as? String, "workout_type must be a stable workout mode enum. Put user-facing activity names in activity_name or activity_tags.")
        XCTAssertEqual(goal.linkedWorkoutType, .cardio)
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

    func testLogWorkoutRejectsFreeTextWorkoutType() async {
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

        guard case .dataResponse(let functionResult) = result else {
            return XCTFail("Expected log workout error response")
        }

        XCTAssertEqual(functionResult.response["error"] as? String, "Workout type must be a stable enum value. Put activity names like Running or Bouldering in activity_name.")
    }

    func testLogWorkoutRejectsStrengthItemWithoutCompletedSets() async {
        let executor = AIFunctionExecutor(modelContext: context, userProfile: nil)
        let result = await executor.execute(
            .init(
                name: "log_workout",
                arguments: [
                    "type": "strength",
                    "name": "Upper lift",
                    "exercises": [
                        [
                            "name": "Bench Press",
                            "category": "strength",
                            "tracking_fields": ["sets", "reps", "weight"]
                        ]
                    ]
                ]
            )
        )

        guard case .dataResponse(let functionResult) = result else {
            return XCTFail("Expected log workout error response")
        }

        XCTAssertEqual(functionResult.response["error"] as? String, "Missing completed workout details. Include completed sets for strength work or a non-strength activity item with category, activity_name, and any known duration, distance, segments, or notes.")
    }

    func testLogWorkoutRejectsBareNonStrengthActivityWithoutLoggedMetrics() async {
        let executor = AIFunctionExecutor(modelContext: context, userProfile: nil)
        let result = await executor.execute(
            .init(
                name: "log_workout",
                arguments: [
                    "type": "climbing",
                    "name": "Bouldering",
                    "exercises": [
                        [
                            "name": "Bouldering",
                            "category": "sportPractice",
                            "activity_name": "Bouldering",
                            "target_tags": ["Climbing"]
                        ]
                    ]
                ]
            )
        )

        guard case .dataResponse(let functionResult) = result else {
            return XCTFail("Expected log workout error response")
        }

        XCTAssertEqual(functionResult.response["error"] as? String, "Missing completed workout details. Include completed sets for strength work or a non-strength activity item with category, activity_name, and any known duration, distance, segments, or notes.")
    }

    func testLogWorkoutParsesIntegerWeightKg() async {
        let executor = AIFunctionExecutor(modelContext: context, userProfile: nil)
        let result = await executor.execute(
            .init(
                name: "log_workout",
                arguments: [
                    "type": "strength",
                    "name": "Upper lift",
                    "exercises": [
                        [
                            "name": "Bench Press",
                            "category": "strength",
                            "sets": [
                                ["reps": 5, "weight_kg": 80]
                            ]
                        ]
                    ]
                ]
            )
        )

        guard case .suggestedWorkoutLog(let workoutLog) = result,
              let set = workoutLog.exercises.first?.sets.first else {
            return XCTFail("Expected workout log suggestion")
        }

        XCTAssertEqual(set.weightKg, 80)
    }

    func testLogWorkoutCoercesDoubleDurationAndReps() async {
        let executor = AIFunctionExecutor(modelContext: context, userProfile: nil)
        let result = await executor.execute(
            .init(
                name: "log_workout",
                arguments: [
                    "type": "strength",
                    "name": "Upper lift",
                    "duration_minutes": 35.0,
                    "exercises": [
                        [
                            "name": "Bench Press",
                            "category": "strength",
                            "sets": [
                                ["reps": 12.0, "weight_kg": 80.0]
                            ]
                        ]
                    ]
                ]
            )
        )

        guard case .suggestedWorkoutLog(let workoutLog) = result,
              let exercise = workoutLog.exercises.first,
              let set = exercise.sets.first else {
            return XCTFail("Expected workout log suggestion")
        }

        XCTAssertEqual(workoutLog.durationMinutes, 35)
        XCTAssertEqual(set.reps, 12)
    }

    func testLogWorkoutStoresNormalizedActivityCategoryAndTrackingFields() async {
        let executor = AIFunctionExecutor(modelContext: context, userProfile: nil)
        let result = await executor.execute(
            .init(
                name: "log_workout",
                arguments: [
                    "type": "mixed",
                    "name": "Padel practice",
                    "exercises": [
                        [
                            "name": "Padel Drills",
                            "category": "sportPractice",
                            "activity_name": "Padel",
                            "target_tags": ["Footwork", "Reaction"],
                            "tracking_fields": ["duration", "calories", "reps", "notes"],
                            "duration_minutes": 40,
                            "segments": [
                                ["duration_minutes": 20, "reps": 8],
                                ["duration_minutes": 20, "reps": 6]
                            ]
                        ]
                    ]
                ]
            )
        )

        guard case .suggestedWorkoutLog(let workoutLog) = result,
              let exercise = workoutLog.exercises.first else {
            return XCTFail("Expected suggested workout log")
        }

        XCTAssertEqual(workoutLog.activityTags ?? [], ["Padel", "Footwork", "Reaction"])
        XCTAssertEqual(exercise.category, "sportPractice")
        XCTAssertEqual(exercise.trackingFields ?? [], ["duration", "reps", "notes"])
        XCTAssertFalse(exercise.trackingFields?.contains("calories") ?? false)
        XCTAssertEqual(exercise.activitySummarySegments, ["Padel", "40 min", "2 segments", "14 attempts"])
    }

    func testLogWorkoutAcceptsNonStrengthActivityWithoutSets() async {
        let executor = AIFunctionExecutor(modelContext: context, userProfile: nil)
        let result = await executor.execute(
            .init(
                name: "log_workout",
                arguments: [
                    "type": "climbing",
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

        XCTAssertEqual(required, ["name", "category", "activity_name"])
        XCTAssertEqual(exercises["minItems"] as? Int, 1)
        XCTAssertEqual(parameters["required"] as? [String], ["name", "type", "exercises"])
        XCTAssertNotNil((items["properties"] as? [String: Any])?["notes"])
    }

    func testLogWorkoutRejectsNonStrengthActivityWithoutActivityName() async throws {
        let result = await AIFunctionExecutor(modelContext: context, userProfile: nil).execute(
            .init(
                name: "log_workout",
                arguments: [
                    "name": "Bouldering",
                    "type": "mixed",
                    "exercises": [
                        [
                            "name": "Bouldering",
                            "category": "sportPractice",
                            "duration_minutes": 45
                        ]
                    ]
                ]
            )
        )

        guard case .dataResponse(let functionResult) = result else {
            return XCTFail("Expected validation error")
        }

        XCTAssertNotNil(functionResult.response["error"])
    }

    func testLogWorkoutRejectsNonStrengthSetStyleActivityWithoutActivityName() async throws {
        let result = await AIFunctionExecutor(modelContext: context, userProfile: nil).execute(
            .init(
                name: "log_workout",
                arguments: [
                    "name": "Padel drills",
                    "type": "mixed",
                    "exercises": [
                        [
                            "name": "Padel rallies",
                            "category": "sportPractice",
                            "tracking_fields": ["reps", "notes"],
                            "sets": [
                                ["reps": 30]
                            ]
                        ]
                    ]
                ]
            )
        )

        guard case .dataResponse(let functionResult) = result else {
            return XCTFail("Expected validation error")
        }

        XCTAssertEqual(functionResult.response["error"] as? String, "Non-strength activity logs need activity_name so Trai can preserve the activity identity.")
    }

    func testLogWorkoutRejectsFreeTextCategoryIdentity() async throws {
        let result = await AIFunctionExecutor(modelContext: context, userProfile: nil).execute(
            .init(
                name: "log_workout",
                arguments: [
                    "name": "Padel",
                    "type": "mixed",
                    "exercises": [
                        [
                            "name": "Padel Drills",
                            "category": "padel drills",
                            "activity_name": "Padel",
                            "duration_minutes": 45
                        ]
                    ]
                ]
            )
        )

        guard case .dataResponse(let functionResult) = result else {
            return XCTFail("Expected validation error")
        }

        XCTAssertNotNil(functionResult.response["error"])
    }

    func testLogWorkoutSchemaUsesCurrentWorkoutModes() throws {
        let typeValues = try propertyEnum(in: AIFunctionDeclarations.logWorkout, property: "type")
        XCTAssertEqual(Set(typeValues), Set(WorkoutMode.allCases.map(\.rawValue)))
        XCTAssertFalse(typeValues.contains("running"))
        XCTAssertFalse(typeValues.contains("sports"))
        XCTAssertFalse(typeValues.contains("other"))
    }

    func testLogWorkoutKeepsNoteOnlyCustomActivities() async {
        let executor = AIFunctionExecutor(modelContext: context, userProfile: nil)
        let result = await executor.execute(
            .init(
                name: "log_workout",
                arguments: [
                    "type": "custom",
                    "name": "Technique practice",
                    "activity_name": "Technique",
                    "exercises": [
                        [
                            "name": "Footwork practice",
                            "category": "custom",
                            "activity_name": "Footwork",
                            "tracking_fields": ["notes"],
                            "notes": "Worked on smooth pivots and balance."
                        ]
                    ]
                ]
            )
        )

        guard case .suggestedWorkoutLog(let workoutLog) = result,
              let exercise = workoutLog.exercises.first else {
            return XCTFail("Expected note-only activity log suggestion")
        }

        XCTAssertEqual(workoutLog.workoutType, WorkoutMode.custom.rawValue)
        XCTAssertEqual(exercise.category, "custom")
        XCTAssertEqual(exercise.activityTypeName, "Footwork")
        XCTAssertEqual(exercise.trackingFields ?? [], ["notes"])
        XCTAssertEqual(exercise.notes, "Worked on smooth pivots and balance.")
    }

    func testWorkoutFunctionSchemasSupportAllStableActivityPrimitives() throws {
        let expected = Set(["strength", "cardio", "conditioning", "mobility", "skill", "sportPractice", "recovery", "flexibility", "custom"])

        let logWorkoutCategories = try exerciseCategoryEnum(in: AIFunctionDeclarations.logWorkout, exercisesKey: "exercises")
        XCTAssertTrue(expected.isSubset(of: Set(logWorkoutCategories)))

        let startLiveWorkoutCategories = try exerciseCategoryEnum(in: AIFunctionDeclarations.startLiveWorkout, exercisesKey: "suggested_exercises")
        XCTAssertTrue(expected.isSubset(of: Set(startLiveWorkoutCategories)))

        let startParameters = try XCTUnwrap(AIFunctionDeclarations.startLiveWorkout["parameters"] as? [String: Any])
        XCTAssertEqual(startParameters["required"] as? [String], ["name", "workout_type", "suggested_exercises"])
        let startProperties = try XCTUnwrap(startParameters["properties"] as? [String: Any])
        let suggestedExercises = try XCTUnwrap(startProperties["suggested_exercises"] as? [String: Any])
        XCTAssertEqual(suggestedExercises["minItems"] as? Int, 1)
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

    func testPlanBlockSchemasRequireUserFacingActivityIdentity() throws {
        for schema in [AIPromptBuilder.workoutPlanSchema, AIPromptBuilder.workoutPlanRefinementSchema] {
            let blockSchema = try planBlockSchema(in: schema)
            let required = try XCTUnwrap(blockSchema["required"] as? [String])
            let blockProperties = try XCTUnwrap(blockSchema["properties"] as? [String: Any])
            let activityTypeName = try XCTUnwrap(blockProperties["activityTypeName"] as? [String: Any])

            XCTAssertTrue(required.contains("activityTypeName"))
            XCTAssertEqual(activityTypeName["type"] as? String, "string")
            XCTAssertNil(activityTypeName["nullable"])
        }
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
        entry.trackingFields = [.duration, .reps, .notes]
        entry.activityRole = .main
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
        XCTAssertEqual(payload["workout_item_count"] as? Int, 1)
        XCTAssertEqual(payload["exercise_count"] as? Int, 0)
        XCTAssertEqual(payload["activity_count"] as? Int, 1)
        XCTAssertEqual(activity["activity_type"] as? String, "Bouldering")
        XCTAssertEqual(activity["activity_tags"] as? [String], ["Climbing", "Grip endurance"])
        XCTAssertEqual(activity["tracking_fields"] as? [String], ["duration", "reps", "notes"])
        XCTAssertEqual(activity["role"] as? String, "main")
        XCTAssertEqual(activity["logged"] as? Bool, true)
        XCTAssertEqual(segment["duration_minutes"] as? Int, 20)
        XCTAssertEqual(segment["reps"] as? Int, 8)
        XCTAssertEqual(segment["notes"] as? String, "Limit attempts")
    }

    func testLiveWorkoutDerivesFocusFromLoggedActivitiesWhenNoFocusWasSet() {
        let workout = LiveWorkout(name: "Open Session", workoutType: .custom)
        let entry = LiveWorkoutEntry(
            exerciseName: "Limit Bouldering",
            orderIndex: 0,
            exerciseType: "sportPractice"
        )
        entry.activityTypeName = "Bouldering"
        entry.completedAt = Date()
        entry.workout = workout
        workout.entries = [entry]

        XCTAssertEqual(workout.displayFocusAreas, ["Bouldering"])
        XCTAssertEqual(workout.displayFocusSummary, "Bouldering")
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
        XCTAssertEqual(payload["workout_item_count"] as? Int, 1)
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
        XCTAssertEqual(payload["activity_tags"] as? [String], ["Bouldering", "Climbing", "Grip endurance"])
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

    private func makeChatWorkoutStartFreshnessPlan(templateID: UUID, blockID: UUID) -> WorkoutPlan {
        WorkoutPlan(
            splitType: .custom,
            daysPerWeek: 1,
            templates: [
                WorkoutPlan.WorkoutTemplate(
                    id: templateID,
                    name: "Plan Pull Day",
                    sessionType: .strength,
                    targetMuscleGroups: ["back"],
                    exercises: [],
                    blocks: [
                        WorkoutPlan.TrainingBlock(
                            id: blockID,
                            kind: .strength,
                            title: "Pull Strength",
                            detail: "Planned pulling volume",
                            activityTypeName: "Strength",
                            activityTags: ["Pull"],
                            order: 0
                        )
                    ],
                    estimatedDurationMinutes: 45,
                    order: 0
                )
            ],
            rationale: "Planned workout",
            guidelines: [],
            progressionStrategy: .defaultStrategy
        )
    }

    private func makeLegacyExerciseOnlyStartFreshnessPlan(templateID: UUID, exerciseID: UUID) -> WorkoutPlan {
        WorkoutPlan(
            splitType: .custom,
            daysPerWeek: 1,
            templates: [
                WorkoutPlan.WorkoutTemplate(
                    id: templateID,
                    name: "Legacy Pull Day",
                    sessionType: .strength,
                    targetMuscleGroups: ["back"],
                    exercises: [
                        WorkoutPlan.ExerciseTemplate(
                            id: exerciseID,
                            exerciseName: "Pull Up",
                            muscleGroup: "back",
                            defaultSets: 4,
                            defaultReps: 6,
                            order: 0
                        )
                    ],
                    blocks: [],
                    estimatedDurationMinutes: 45,
                    order: 0
                )
            ],
            rationale: "Legacy workout",
            guidelines: [],
            progressionStrategy: .defaultStrategy
        )
    }

    private func blockEnum(in schema: [String: Any], field: String) throws -> [String] {
        let blockProperties = try XCTUnwrap(try planBlockSchema(in: schema)["properties"] as? [String: Any])
        let fieldSchema = try XCTUnwrap(blockProperties[field] as? [String: Any])
        return try XCTUnwrap(fieldSchema["enum"] as? [String])
    }

    private func planBlockSchema(in schema: [String: Any]) throws -> [String: Any] {
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
        return blockItems
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
