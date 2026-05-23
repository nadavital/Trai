import XCTest
import SwiftData
@testable import Trai

@MainActor
final class WorkoutTemplateServiceTests: XCTestCase {
    private var service: WorkoutTemplateService!

    override func setUpWithError() throws {
        try super.setUpWithError()
        service = WorkoutTemplateService()
    }

    override func tearDownWithError() throws {
        service = nil
        try super.tearDownWithError()
    }

    private func makeInMemoryContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: UserProfile.self, ExerciseHistory.self,
            configurations: ModelConfiguration(
                isStoredInMemoryOnly: true,
                cloudKitDatabase: .none
            )
        )
        return ModelContext(container)
    }

    func testCreateCustomWorkoutUsesProvidedValues() {
        let workout = service.createCustomWorkout(
            name: "Conditioning Circuit",
            type: .cardio,
            muscles: [.quads, .glutes],
            focusAreas: ["Bouldering", "Grip endurance"]
        )

        XCTAssertEqual(workout.name, "Conditioning Circuit")
        XCTAssertEqual(workout.type, .cardio)
        XCTAssertEqual(workout.muscleGroups, [.quads, .glutes])
        XCTAssertEqual(workout.focusAreas, ["Bouldering", "Grip endurance"])
    }

    func testTrainingBlockPrimitiveFallbacksUseUserFacingLabels() {
        XCTAssertEqual(WorkoutPlan.TrainingBlock.BlockKind.skill.displayName, "Sport")
        XCTAssertEqual(WorkoutPlan.TrainingBlock.BlockKind.sportPractice.displayName, "Sport")
        XCTAssertEqual(WorkoutPlan.TrainingBlock.BlockKind.custom.displayName, "Activity")
        XCTAssertEqual(WorkoutPlan.TrainingBlock.Role.accessory.displayName, "Support")
        XCTAssertEqual(WorkoutPlan.TrainingBlock.Role.finisher.displayName, "Finish")
        XCTAssertEqual(WorkoutPlan.TrainingBlock.Role.cooldown.displayName, "Cool down")
    }

    func testModalityProgressionPrimitiveFallbacksUseUserFacingLabels() {
        XCTAssertEqual(WorkoutPlan.ModalityProgression.ProgressionFocus.skill.displayName, "Technique")
    }

    func testCreateStartWorkoutFromTemplateMapsMuscleGroups() {
        let template = WorkoutPlan.WorkoutTemplate(
            name: "Upper Push",
            targetMuscleGroups: ["chest", "triceps"],
            exercises: [],
            estimatedDurationMinutes: 45,
            order: 0
        )

        let workout = service.createStartWorkout(from: template)

        XCTAssertEqual(workout.name, "Upper Push")
        XCTAssertEqual(workout.type, .strength)
        XCTAssertEqual(workout.muscleGroups, [.chest, .triceps])
    }

    func testCreateStartWorkoutFromTemplateInfersMusclesFromBlockExercises() {
        let lift = WorkoutPlan.ExerciseTemplate(
            exerciseName: "Bench Press",
            muscleGroup: "chest",
            defaultSets: 3,
            defaultReps: 8,
            order: 0
        )
        let template = WorkoutPlan.WorkoutTemplate(
            name: "Upper Push",
            sessionType: .strength,
            focusAreas: ["Push"],
            targetMuscleGroups: [],
            exercises: [],
            blocks: [
                WorkoutPlan.TrainingBlock(
                    kind: .strength,
                    title: "Main work",
                    detail: "Pressing",
                    exercises: [lift],
                    order: 0
                )
            ],
            estimatedDurationMinutes: 45,
            order: 0
        )

        let workout = service.createStartWorkout(from: template)

        XCTAssertEqual(template.resolvedTargetMuscleGroups, ["chest"])
        XCTAssertEqual(workout.muscleGroups, [.chest])
    }

    func testCreateStartWorkoutFromTemplatePreservesBlockActivityFocuses() {
        let template = WorkoutPlan.WorkoutTemplate(
            name: "Mixed Week Day",
            sessionType: .mixed,
            focusAreas: ["Strength"],
            targetMuscleGroups: [],
            exercises: [],
            blocks: [
                WorkoutPlan.TrainingBlock(
                    kind: .strength,
                    title: "Strength",
                    detail: "Main lifts",
                    activityTypeName: "Strength",
                    activityTags: ["Strength"],
                    order: 0
                ),
                WorkoutPlan.TrainingBlock(
                    kind: .skill,
                    title: "Limit Bouldering",
                    detail: "Work short problems with full rest.",
                    activityTypeName: "Bouldering",
                    activityTags: ["Climbing", "Grip endurance"],
                    durationMinutes: 30,
                    order: 1
                )
            ],
            estimatedDurationMinutes: 60,
            order: 0
        )

        let workout = service.createStartWorkout(from: template)

        XCTAssertEqual(workout.focusAreas, ["Strength", "Bouldering", "Climbing", "Grip endurance"])
    }

    func testCreateWorkoutFromTemplateKeepsSupportiveCardioBlockAsActivity() throws {
        let context = try makeInMemoryContext()
        let lift = WorkoutPlan.ExerciseTemplate(
            exerciseName: "Bench Press",
            muscleGroup: "chest",
            defaultSets: 3,
            defaultReps: 8,
            order: 0
        )
        let template = WorkoutPlan.WorkoutTemplate(
            name: "Upper Strength",
            sessionType: .mixed,
            focusAreas: ["Upper", "Cardio finisher"],
            targetMuscleGroups: ["chest"],
            exercises: [lift],
            blocks: [
                WorkoutPlan.TrainingBlock(
                    kind: .strength,
                    title: "Upper Strength",
                    detail: "Bench work",
                    exercises: [lift],
                    durationMinutes: 35,
                    order: 0
                ),
                WorkoutPlan.TrainingBlock(
                    kind: .cardio,
                    role: .finisher,
                    title: "Bike Finisher",
                    detail: "Easy steady spin",
                    durationMinutes: 10,
                    intensity: "Easy",
                    target: "Conversational pace",
                    order: 1
                )
            ],
            estimatedDurationMinutes: 45,
            order: 0
        )

        let workout = service.createWorkoutFromTemplate(
            template,
            progressionStrategy: .defaultStrategy,
            modelContext: context
        )

        let entries = try XCTUnwrap(workout.entries)
        XCTAssertEqual(entries.map(\.exerciseName), ["Bench Press", "Bike Finisher"])
        XCTAssertEqual(entries.last?.exerciseType, "activity")
        XCTAssertEqual(entries.last?.activityKind, .cardio)
        XCTAssertEqual(entries.last?.activityRole, .finisher)
        XCTAssertNil(entries.last?.durationSeconds)
        XCTAssertEqual(entries.last?.plannedDurationSeconds, 600)
        XCTAssertEqual(entries.last?.isPlannedActivityGuidance, true)
        XCTAssertEqual(entries.last?.plannedIntensity, "Easy")
        XCTAssertEqual(entries.last?.plannedTarget, "Conversational pace")
        XCTAssertEqual(entries.last?.notes, "")
    }

    func testCreateWorkoutFromTemplateKeepsSupportiveConditioningBlockAsActivity() throws {
        let context = try makeInMemoryContext()
        let lift = WorkoutPlan.ExerciseTemplate(
            exerciseName: "Leg Press",
            muscleGroup: "quads",
            defaultSets: 3,
            defaultReps: 8,
            order: 0
        )
        let template = WorkoutPlan.WorkoutTemplate(
            name: "Legs + Conditioning",
            sessionType: .mixed,
            focusAreas: ["Legs", "Conditioning"],
            targetMuscleGroups: ["quads"],
            exercises: [],
            blocks: [
                WorkoutPlan.TrainingBlock(
                    kind: .strength,
                    title: "Leg Strength",
                    detail: "Leg work",
                    exercises: [lift],
                    durationMinutes: 30,
                    order: 0
                ),
                WorkoutPlan.TrainingBlock(
                    kind: .conditioning,
                    role: .accessory,
                    title: "Conditioning Support",
                    detail: "Bike intervals",
                    durationMinutes: 8,
                    intensity: "Moderate",
                    target: "Work capacity",
                    order: 1
                )
            ],
            estimatedDurationMinutes: 45,
            order: 0
        )

        let workout = service.createWorkoutFromTemplate(
            template,
            progressionStrategy: .defaultStrategy,
            modelContext: context
        )

        let entries = try XCTUnwrap(workout.entries)
        XCTAssertEqual(entries.map(\.exerciseName), ["Leg Press", "Conditioning Support"])
        XCTAssertEqual(entries.last?.exerciseType, "activity")
        XCTAssertEqual(entries.last?.activityKind, .conditioning)
        XCTAssertEqual(entries.last?.activityRole, .accessory)
        XCTAssertNil(entries.last?.durationSeconds)
        XCTAssertEqual(entries.last?.plannedDurationSeconds, 480)
        XCTAssertEqual(entries.last?.isPlannedActivityGuidance, true)
        XCTAssertEqual(entries.last?.notes, "")
    }

    func testCreateWorkoutFromTemplateCreatesEntriesForCardioSessionBlocks() throws {
        let context = try makeInMemoryContext()
        let template = WorkoutPlan.WorkoutTemplate(
            name: "Steady Ride",
            sessionType: .cardio,
            focusAreas: ["Endurance"],
            targetMuscleGroups: [],
            exercises: [],
            blocks: [
                WorkoutPlan.TrainingBlock(
                    kind: .cardio,
                    title: "Bike Ride",
                    detail: "Steady aerobic work",
                    durationMinutes: 35,
                    intensity: "Easy",
                    target: "Conversational pace",
                    order: 0
                ),
                WorkoutPlan.TrainingBlock(
                    kind: .recovery,
                    role: .cooldown,
                    title: "Cooldown",
                    detail: "Easy spin",
                    durationMinutes: 5,
                    order: 1
                )
            ],
            estimatedDurationMinutes: 40,
            order: 0
        )

        let workout = service.createWorkoutFromTemplate(
            template,
            progressionStrategy: .defaultStrategy,
            modelContext: context
        )

        let entries = try XCTUnwrap(workout.entries)
        XCTAssertEqual(entries.map(\.exerciseName), ["Bike Ride", "Cooldown"])
        XCTAssertEqual(entries.map(\.exerciseType), ["cardio", "flexibility"])
        XCTAssertEqual(entries.map(\.durationSeconds), [nil, nil])
        XCTAssertEqual(entries.map(\.plannedDurationSeconds), [2100, 300])
        XCTAssertEqual(entries.map(\.isPlannedActivityGuidance), [true, true])
    }

    func testCreateWorkoutFromTemplatePreservesGeneratedActivityIdentityAndTags() throws {
        let context = try makeInMemoryContext()
        let template = WorkoutPlan.WorkoutTemplate(
            name: "Climbing Session",
            sessionType: .climbing,
            focusAreas: ["Bouldering", "Grip endurance"],
            targetMuscleGroups: [],
            exercises: [],
            blocks: [
                WorkoutPlan.TrainingBlock(
                    kind: .skill,
                    role: .main,
                    title: "Limit Bouldering",
                    detail: "Work short problems with full rest.",
                    activityTypeName: "Bouldering",
                    activityTags: ["Bouldering", "Climbing", "Grip endurance"],
                    durationMinutes: 35,
                    intensity: "Hard",
                    target: "Power and precision",
                    order: 0
                )
            ],
            estimatedDurationMinutes: 45,
            order: 0
        )

        let workout = service.createWorkoutFromTemplate(
            template,
            progressionStrategy: .defaultStrategy,
            modelContext: context
        )

        let entry = try XCTUnwrap(workout.entries?.first)
        XCTAssertEqual(workout.focusAreas, ["Bouldering", "Grip endurance", "Climbing"])
        XCTAssertEqual(entry.exerciseName, "Limit Bouldering")
        XCTAssertEqual(entry.exerciseType, "activity")
        XCTAssertEqual(entry.activityKind, WorkoutPlan.TrainingBlock.BlockKind.skill)
        XCTAssertEqual(entry.activityRole, WorkoutPlan.TrainingBlock.Role.main)
        XCTAssertEqual(entry.activityTypeName, "Bouldering")
        XCTAssertEqual(entry.targetTags, ["Bouldering", "Climbing", "Grip endurance"])
        XCTAssertEqual(entry.plannedDurationSeconds, 2100)
        XCTAssertNil(entry.durationSeconds)
        XCTAssertTrue(entry.isPlannedActivityGuidance)
        XCTAssertFalse(entry.hasExercisePreferenceSignal)
        XCTAssertEqual(entry.plannedIntensity, "Hard")
        XCTAssertEqual(entry.plannedTarget, "Power and precision")
    }

    func testCreateWorkoutFromTemplateUsesActivityNameForGenericActivityBlockTitle() throws {
        let context = try makeInMemoryContext()
        let template = WorkoutPlan.WorkoutTemplate(
            name: "Practice Day",
            sessionType: .custom,
            focusAreas: [],
            targetMuscleGroups: [],
            exercises: [],
            blocks: [
                WorkoutPlan.TrainingBlock(
                    kind: .sportPractice,
                    role: .main,
                    title: "Skill",
                    detail: "Hard attempts",
                    activityTypeName: "Bouldering",
                    activityTags: ["Climbing"],
                    durationMinutes: 30,
                    order: 0
                ),
                WorkoutPlan.TrainingBlock(
                    kind: .mobility,
                    role: .cooldown,
                    title: "Shoulder Prep",
                    detail: "Controlled range",
                    activityTypeName: "Shoulder Mobility",
                    durationMinutes: 10,
                    order: 1
                )
            ],
            estimatedDurationMinutes: 40,
            order: 0
        )

        let workout = service.createWorkoutFromTemplate(
            template,
            progressionStrategy: .defaultStrategy,
            modelContext: context
        )

        let entries = try XCTUnwrap(workout.entries)
        XCTAssertEqual(entries.map(\.exerciseName), ["Bouldering", "Shoulder Prep"])
        XCTAssertEqual(entries.map(\.activityTypeName), ["Bouldering", "Shoulder Mobility"])
    }

    func testCreateWorkoutFromTemplateDoesNotDuplicateTopLevelExercisesAcrossEmptyStrengthBlocks() throws {
        let context = try makeInMemoryContext()
        let lift = WorkoutPlan.ExerciseTemplate(
            exerciseName: "Goblet Squat",
            muscleGroup: "quads",
            defaultSets: 3,
            defaultReps: 10,
            order: 0
        )
        let template = WorkoutPlan.WorkoutTemplate(
            name: "Lower Strength",
            sessionType: .strength,
            focusAreas: ["Lower"],
            targetMuscleGroups: ["quads"],
            exercises: [lift],
            blocks: [
                WorkoutPlan.TrainingBlock(kind: .strength, title: "Main Lift", detail: "Squat", order: 0),
                WorkoutPlan.TrainingBlock(kind: .strength, title: "Accessory", detail: "Single leg", order: 1)
            ],
            estimatedDurationMinutes: 45,
            order: 0
        )

        let workout = service.createWorkoutFromTemplate(
            template,
            progressionStrategy: .defaultStrategy,
            modelContext: context
        )

        let entries = try XCTUnwrap(workout.entries)
        XCTAssertEqual(entries.map(\.exerciseName), ["Goblet Squat"])
    }

    func testCreateWorkoutFromTemplateCanSkipPrefilledStrengthExercises() throws {
        let context = try makeInMemoryContext()
        let lift = WorkoutPlan.ExerciseTemplate(
            exerciseName: "Bench Press",
            muscleGroup: "chest",
            defaultSets: 3,
            defaultReps: 8,
            order: 0
        )
        let template = WorkoutPlan.WorkoutTemplate(
            name: "Push Day",
            sessionType: .strength,
            focusAreas: ["Push"],
            targetMuscleGroups: ["chest"],
            exercises: [],
            blocks: [
                WorkoutPlan.TrainingBlock(
                    kind: .mobility,
                    role: .warmup,
                    title: "Warm-up",
                    detail: "Prepare to press",
                    durationMinutes: 5,
                    order: 0
                ),
                WorkoutPlan.TrainingBlock(
                    kind: .strength,
                    title: "Push Strength",
                    detail: "Main work",
                    exercises: [lift],
                    durationMinutes: 30,
                    order: 1
                ),
                WorkoutPlan.TrainingBlock(
                    kind: .mobility,
                    role: .warmup,
                    title: "Shoulder Prep",
                    detail: "Open the shoulders before pressing.",
                    activityTypeName: "Mobility Flow",
                    activityTags: ["Shoulder prep"],
                    durationMinutes: 5,
                    order: 2
                )
            ],
            estimatedDurationMinutes: 45,
            order: 0
        )

        let workout = service.createWorkoutFromTemplate(
            template,
            progressionStrategy: .defaultStrategy,
            modelContext: context,
            prefillStrengthExercises: false
        )

        let entries = try XCTUnwrap(workout.entries)
        XCTAssertEqual(entries.map(\.exerciseName), ["Warm-up", "Shoulder Prep"])
        XCTAssertEqual(entries.map(\.exerciseType), ["flexibility", "flexibility"])
        XCTAssertEqual(entries.map(\.isPlannedActivityGuidance), [true, true])
        XCTAssertTrue(entries.allSatisfy { $0.sets.isEmpty })
        XCTAssertEqual(entries.map(\.plannedDurationSeconds), [300, 300])
        XCTAssertEqual(workout.focusAreas, ["Push", "Mobility Flow", "Shoulder prep"])
    }

    func testCreateWorkoutForIntentMatchesTemplateByCaseInsensitiveContains() throws {
        let context = try makeInMemoryContext()
        let profile = UserProfile()
        profile.workoutPlan = WorkoutPlan(
            splitType: .upperLower,
            daysPerWeek: 4,
            templates: [
                WorkoutPlan.WorkoutTemplate(
                    name: "Upper Body Strength",
                    targetMuscleGroups: ["chest", "back", "shoulders"],
                    exercises: [],
                    estimatedDurationMinutes: 60,
                    order: 0
                )
            ],
            rationale: "Test",
            guidelines: [],
            progressionStrategy: .defaultStrategy,
            warnings: nil
        )
        context.insert(profile)
        try context.save()

        let workout = service.createWorkoutForIntent(
            name: "upper body",
            modelContext: context
        )

        XCTAssertEqual(workout.name, "Upper Body Strength")
        XCTAssertEqual(workout.type, .strength)
        XCTAssertEqual(workout.muscleGroups, [.chest, .back, .shoulders])
    }

    func testCreateWorkoutForIntentFallsBackToCustomNamedWorkout() throws {
        let context = try makeInMemoryContext()
        let workout = service.createWorkoutForIntent(
            name: "Fight Camp",
            modelContext: context
        )

        XCTAssertEqual(workout.name, "Fight Camp")
        XCTAssertEqual(workout.type, .strength)
        XCTAssertEqual(workout.muscleGroups, [])
    }

    func testCreateWorkoutForIntentCustomCreatesDefaultWorkout() throws {
        let context = try makeInMemoryContext()
        let workout = service.createWorkoutForIntent(
            name: "custom",
            modelContext: context
        )

        XCTAssertEqual(workout.name, "Custom Workout")
        XCTAssertEqual(workout.type, .strength)
        XCTAssertEqual(workout.muscleGroups, [])
    }

    func testSuggestedSetDefaultsUsesExplicitAIWeightWhenProvided() throws {
        let context = try makeInMemoryContext()

        let defaults = service.suggestedSetDefaults(
            exerciseName: "Bench Press",
            requestedReps: 8,
            requestedWeightKg: 72.4,
            modelContext: context
        )

        XCTAssertEqual(defaults.reps, 8)
        XCTAssertEqual(defaults.weight.kg, 72.5)
    }

    func testSuggestedSetDefaultsFallsBackToProgressedHistoryWeight() throws {
        let context = try makeInMemoryContext()
        let history = ExerciseHistory()
        history.exerciseName = "Bench Press"
        history.performedAt = Date()
        history.bestSetWeightKg = 60
        history.bestSetWeightLbs = 132.5
        history.bestSetReps = 12
        history.totalSets = 3
        history.repPattern = "12,12,12"
        history.weightPattern = "60,60,60"
        context.insert(history)
        try context.save()

        let defaults = service.suggestedSetDefaults(
            exerciseName: "Bench Press",
            requestedReps: 10,
            requestedWeightKg: nil,
            progressionStrategy: .defaultStrategy,
            modelContext: context
        )

        XCTAssertEqual(defaults.reps, 12)
        XCTAssertEqual(defaults.weight.kg, 62.5)
    }
}

@MainActor
final class MuscleRecoveryServicePerformanceTests: XCTestCase {
    private var service: MuscleRecoveryService!

    override func setUpWithError() throws {
        try super.setUpWithError()
        service = .shared
    }

    override func tearDownWithError() throws {
        service = nil
        try super.tearDownWithError()
    }

    func testRecoveryCacheHitBehaviorUsesFreshTTLWindow() {
        let now = Date()

        service.debugSeedRecoveryCacheForTests(generatedAt: now.addingTimeInterval(-45))
        XCTAssertTrue(service.debugShouldUseRecoveryCache(forceRefresh: false, now: now))
        XCTAssertFalse(service.debugShouldUseRecoveryCache(forceRefresh: true, now: now))

        service.debugSeedRecoveryCacheForTests(generatedAt: now.addingTimeInterval(-100))
        XCTAssertFalse(service.debugShouldUseRecoveryCache(forceRefresh: false, now: now))
    }

    func testExerciseLookupCacheExpiresWithinBoundedWindow() {
        let now = Date()

        service.debugSeedExerciseLookupCacheForTests(generatedAt: now.addingTimeInterval(-120))
        XCTAssertTrue(service.debugShouldUseExerciseLookupCache(now: now))

        service.debugSeedExerciseLookupCacheForTests(generatedAt: now.addingTimeInterval(-400))
        XCTAssertFalse(service.debugShouldUseExerciseLookupCache(now: now))
    }

    func testScoreTemplateUsesBlockExerciseMusclesWhenTargetsAreMissing() {
        let lift = WorkoutPlan.ExerciseTemplate(
            exerciseName: "Bench Press",
            muscleGroup: "chest",
            defaultSets: 3,
            defaultReps: 8,
            order: 0
        )
        let template = WorkoutPlan.WorkoutTemplate(
            name: "Upper Push",
            sessionType: .strength,
            focusAreas: ["Push"],
            targetMuscleGroups: [],
            exercises: [],
            blocks: [
                WorkoutPlan.TrainingBlock(
                    kind: .strength,
                    title: "Main work",
                    detail: "Pressing",
                    exercises: [lift],
                    order: 0
                )
            ],
            estimatedDurationMinutes: 45,
            order: 0
        )

        let result = service.scoreTemplate(
            template,
            recoveryInfo: [
                MuscleRecoveryService.MuscleRecoveryInfo(
                    muscleGroup: .chest,
                    status: .tired,
                    lastTrainedAt: Date(),
                    hoursSinceTraining: 4
                )
            ]
        )

        XCTAssertEqual(result.score, 0.2)
        XCTAssertTrue(result.reason.contains("Chest"))
    }
}
