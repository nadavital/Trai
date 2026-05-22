import Observation
import SwiftData
import XCTest
@testable import Trai

@MainActor
final class LiveWorkoutViewModelInvalidationTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUpWithError() throws {
        try super.setUpWithError()
        container = try ModelContainer(
            for: LiveWorkout.self,
            LiveWorkoutEntry.self,
            ExerciseHistory.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        context = ModelContext(container)
    }

    override func tearDownWithError() throws {
        context = nil
        container = nil
        try super.tearDownWithError()
    }

    func testRepEditDoesNotInvalidateEntryListObservation() {
        let (workout, entry) = makeWorkout(initialReps: 8)
        context.insert(workout)

        let viewModel = LiveWorkoutViewModel(workout: workout)
        let entryListInvalidationCount = InvalidationCounter()

        withObservationTracking {
            _ = viewModel.entries.count
        } onChange: {
            entryListInvalidationCount.increment()
        }

        viewModel.updateSet(at: 0, in: entry, reps: 9)

        XCTAssertEqual(entry.sets.first?.reps, 9)
        XCTAssertEqual(entryListInvalidationCount.value, 0)
    }

    func testRepEditAcrossZeroBoundaryStillUpdatesProgressMetrics() {
        let (workout, entry) = makeWorkout(initialReps: 0)
        context.insert(workout)

        let viewModel = LiveWorkoutViewModel(workout: workout)

        XCTAssertEqual(viewModel.completedSets, 0)

        viewModel.updateSet(at: 0, in: entry, reps: 9)

        XCTAssertEqual(viewModel.completedSets, 1)
    }

    func testGeneralActivityEntryWithLoggedDataCountsAsComplete() {
        let workout = LiveWorkout(name: "Recovery Session", workoutType: .mobility)
        let entry = LiveWorkoutEntry(
            exerciseName: "Hip Mobility",
            orderIndex: 0,
            exerciseType: "flexibility"
        )
        entry.durationSeconds = 600
        entry.workout = workout
        workout.entries = [entry]
        context.insert(workout)

        let viewModel = LiveWorkoutViewModel(workout: workout)

        XCTAssertTrue(viewModel.isWorkoutComplete)
    }

    func testActivitySegmentTotalsCountAsLoggedData() {
        let workout = LiveWorkout(name: "Rowing Intervals", workoutType: .cardio)
        let entry = LiveWorkoutEntry(
            exerciseName: "Rowing",
            orderIndex: 0,
            exerciseType: "cardio"
        )
        entry.trackingFields = [.duration, .distance]
        entry.activitySegments = [
            LiveWorkoutEntry.ActivitySegment(durationSeconds: 300, distanceMeters: 1_000),
            LiveWorkoutEntry.ActivitySegment(durationSeconds: 240, distanceMeters: 850)
        ]
        entry.workout = workout
        workout.entries = [entry]
        context.insert(workout)

        let viewModel = LiveWorkoutViewModel(workout: workout)

        XCTAssertEqual(entry.trackedDurationSeconds, 540)
        XCTAssertEqual(entry.trackedDistanceMeters, 1_850)
        XCTAssertTrue(entry.hasExercisePreferenceSignal)
        XCTAssertTrue(viewModel.isWorkoutComplete)
    }

    func testExerciseHistoryRecordsIncludeGeneralActivitiesWithLoggedData() {
        let workout = LiveWorkout(
            name: "Bouldering Session",
            workoutType: .climbing,
            focusAreas: ["Bouldering", "Climbing"]
        )
        workout.completedAt = Date()
        let entry = LiveWorkoutEntry(
            exerciseName: "Limit Bouldering",
            orderIndex: 0,
            exerciseType: "skill"
        )
        entry.activityTypeName = "Bouldering"
        entry.targetTags = ["Climbing", "Grip endurance"]
        entry.trackingFields = [.duration, .reps, .notes]
        entry.activitySegments = [
            LiveWorkoutEntry.ActivitySegment(durationSeconds: 1_200, reps: 8, notes: "Limit attempts")
        ]
        entry.workout = workout
        workout.entries = [entry]

        let records = ExerciseHistory.records(from: workout)

        XCTAssertEqual(records.count, 1)
        guard let history = records.first else {
            return XCTFail("Expected one history record")
        }
        XCTAssertEqual(history.exerciseName, "Limit Bouldering")
        XCTAssertEqual(history.sourceWorkoutEntryId, entry.id)
        XCTAssertEqual(history.totalSets, 0)
        XCTAssertEqual(history.totalReps, 0)
    }

    func testExerciseHistoryRecordsIgnoreBlankGeneralActivityGuidance() {
        let workout = LiveWorkout(name: "Cardio Guidance", workoutType: .cardio)
        workout.completedAt = Date()
        let entry = LiveWorkoutEntry(
            exerciseName: "Steady Run",
            orderIndex: 0,
            exerciseType: "cardio"
        )
        entry.trackingFields = [.duration, .distance]
        entry.activitySegments = [LiveWorkoutEntry.ActivitySegment()]
        entry.workout = workout
        workout.entries = [entry]

        XCTAssertTrue(ExerciseHistory.records(from: workout).isEmpty)
    }

    func testMixedWorkoutHistorySummarySeparatesExercisesAndActivities() {
        let workout = LiveWorkout(name: "Strength + Climb", workoutType: .mixed)
        workout.startedAt = Date(timeIntervalSince1970: 1_000)
        workout.completedAt = Date(timeIntervalSince1970: 4_600)

        let strengthEntry = LiveWorkoutEntry(exerciseName: "Back Squat", orderIndex: 0)
        strengthEntry.addSet(LiveWorkoutEntry.SetData(reps: 8, weight: .zero, completed: true))

        let activityEntry = LiveWorkoutEntry(
            exerciseName: "Bouldering",
            orderIndex: 1,
            exerciseType: "skill"
        )
        activityEntry.activityTypeName = "Bouldering"
        activityEntry.completedAt = workout.completedAt

        strengthEntry.workout = workout
        activityEntry.workout = workout
        workout.entries = [strengthEntry, activityEntry]

        XCTAssertEqual(workout.entrySummaryStats.strengthEntryCount, 1)
        XCTAssertEqual(workout.entrySummaryStats.activityEntryCount, 1)
        XCTAssertEqual(workout.entrySummaryStats.loggedActivityCount, 1)
        XCTAssertEqual(
            workout.historySummarySegments,
            ["1 exercise", "1 activity", "1 set", "60 min"]
        )
    }

    func testWorkoutTrendAggregationCountsLoggedItemsOnly() {
        let workout = LiveWorkout(name: "Strength + Planned Climb", workoutType: .mixed)
        workout.startedAt = Date()
        workout.completedAt = Date()

        let strengthEntry = LiveWorkoutEntry(exerciseName: "Back Squat", orderIndex: 0)
        strengthEntry.addSet(LiveWorkoutEntry.SetData(reps: 8, weight: .zero, completed: true))

        let loggedActivity = LiveWorkoutEntry(
            exerciseName: "Bouldering",
            orderIndex: 1,
            exerciseType: "skill"
        )
        loggedActivity.activityTypeName = "Bouldering"
        loggedActivity.durationSeconds = 1_200

        let plannedGuidance = LiveWorkoutEntry(
            exerciseName: "Mobility Cooldown",
            orderIndex: 2,
            exerciseType: "activity"
        )
        plannedGuidance.activityTypeName = "Mobility"
        plannedGuidance.sourcePlanBlockID = UUID()

        workout.entries = [strengthEntry, loggedActivity, plannedGuidance]

        let day = TrendsService.aggregateWorkoutsByDay(workouts: [workout], days: 1).first

        XCTAssertEqual(day?.workoutCount, 1)
        XCTAssertEqual(day?.totalEntries, 2)
        XCTAssertEqual(day?.totalSets, 1)
    }

    func testRepsOnlyActivitySegmentCountsAsLoggedData() {
        let workout = LiveWorkout(name: "Conditioning", workoutType: .hiit)
        let entry = LiveWorkoutEntry(
            exerciseName: "Battle Ropes",
            orderIndex: 0,
            exerciseType: "conditioning"
        )
        entry.trackingFields = [.reps, .notes]
        entry.activitySegments = [
            LiveWorkoutEntry.ActivitySegment(reps: 40, notes: "Hard round")
        ]
        entry.workout = workout
        workout.entries = [entry]
        context.insert(workout)

        let viewModel = LiveWorkoutViewModel(workout: workout)

        XCTAssertTrue(entry.hasExercisePreferenceSignal)
        XCTAssertTrue(viewModel.isWorkoutComplete)
    }

    func testBlankActivitySegmentDoesNotCountAsLoggedData() {
        let workout = LiveWorkout(name: "Rowing Intervals", workoutType: .cardio)
        let entry = LiveWorkoutEntry(
            exerciseName: "Rowing",
            orderIndex: 0,
            exerciseType: "cardio"
        )
        entry.trackingFields = [.duration, .distance]
        entry.activitySegments = [LiveWorkoutEntry.ActivitySegment()]
        entry.workout = workout
        workout.entries = [entry]
        context.insert(workout)

        let viewModel = LiveWorkoutViewModel(workout: workout)

        XCTAssertFalse(entry.hasExercisePreferenceSignal)
        XCTAssertFalse(viewModel.isWorkoutComplete)
    }

    func testRemovingLastLoggedActivitySegmentClearsTrackedTotals() {
        let workout = LiveWorkout(name: "Rowing Intervals", workoutType: .cardio)
        let entry = LiveWorkoutEntry(
            exerciseName: "Rowing",
            orderIndex: 0,
            exerciseType: "cardio"
        )
        entry.trackingFields = [.duration, .distance]
        entry.activitySegments = [
            LiveWorkoutEntry.ActivitySegment(durationSeconds: 300, distanceMeters: 1_000)
        ]
        entry.durationSeconds = 300
        entry.distanceMeters = 1_000
        entry.workout = workout
        workout.entries = [entry]
        context.insert(workout)

        let viewModel = LiveWorkoutViewModel(workout: workout)
        viewModel.removeActivitySegment(from: entry, at: 0)

        XCTAssertNil(entry.durationSeconds)
        XCTAssertNil(entry.distanceMeters)
        XCTAssertFalse(entry.hasExercisePreferenceSignal)
        XCTAssertFalse(viewModel.isWorkoutComplete)
    }

    func testActivityScopedFrequencyGoalCountsCompletedMatchingEntries() {
        let workout = LiveWorkout(name: "Legs + Support", workoutType: .strength)
        workout.completedAt = Date()
        let strengthEntry = LiveWorkoutEntry(exerciseName: "Back Squat", orderIndex: 0)
        strengthEntry.addSet(LiveWorkoutEntry.SetData(reps: 8, weight: .zero, completed: true))
        let supportEntry = LiveWorkoutEntry(
            exerciseName: "Easy Bike",
            orderIndex: 1,
            exerciseType: "cardio"
        )
        supportEntry.activityKind = .cardio
        supportEntry.activityRole = .finisher
        supportEntry.durationSeconds = 600
        supportEntry.completedAt = Date()
        workout.entries = [strengthEntry, supportEntry]

        let unmatchedWorkout = LiveWorkout(name: "Push", workoutType: .strength)
        unmatchedWorkout.completedAt = Date()
        let unmatchedEntry = LiveWorkoutEntry(exerciseName: "Bench Press", orderIndex: 0)
        unmatchedEntry.addSet(LiveWorkoutEntry.SetData(reps: 8, weight: .zero, completed: true))
        unmatchedWorkout.entries = [unmatchedEntry]

        let goal = WorkoutGoal(
            title: "Complete weekly support work",
            goalKind: .frequency,
            linkedWorkoutType: .strength,
            linkedActivityKind: .cardio,
            linkedActivityRole: .finisher,
            targetValue: 1,
            targetUnit: "entries",
            periodUnit: .week,
            periodCount: 1,
            successCriteria: "You complete one matching support entry this week."
        )

        let insight = WorkoutGoalProgressResolver.insights(
            goals: [goal],
            workouts: [workout, unmatchedWorkout],
            exerciseHistory: [],
            useLbs: false
        ).first

        XCTAssertEqual(insight?.currentValueText, "1")
        XCTAssertEqual(insight?.progressFraction, 1)
    }

    func testActivityScopedFrequencyGoalCountsLoggedActivityDataWithoutEntryCompletion() {
        let workout = LiveWorkout(name: "Climbing Session", workoutType: .climbing)
        workout.startedAt = Date().addingTimeInterval(-1_800)
        workout.completedAt = Date()
        let entry = LiveWorkoutEntry(
            exerciseName: "Limit Bouldering",
            orderIndex: 0,
            exerciseType: "skill"
        )
        entry.activityTypeName = "Bouldering"
        entry.targetTags = ["Climbing"]
        entry.durationSeconds = 1_200
        workout.entries = [entry]

        let goal = WorkoutGoal(
            title: "Climb weekly",
            goalKind: .frequency,
            linkedActivityTags: ["Climbing"],
            targetValue: 1,
            targetUnit: "session",
            periodUnit: .week,
            periodCount: 1,
            successCriteria: "You log one climbing session this week."
        )

        let insight = WorkoutGoalProgressResolver.insights(
            goals: [goal],
            workouts: [workout],
            exerciseHistory: [],
            useLbs: false
        ).first

        XCTAssertTrue(entry.hasExercisePreferenceSignal)
        XCTAssertNil(entry.completedAt)
        XCTAssertEqual(insight?.currentValueText, "1")
        XCTAssertEqual(insight?.progressFraction, 1)
    }

    func testActivityScopedGoalIgnoresPlannedGuidanceWithoutLoggedData() {
        let workout = LiveWorkout(name: "Planned Climb", workoutType: .climbing)
        workout.completedAt = Date()
        let entry = LiveWorkoutEntry(
            exerciseName: "Limit Bouldering",
            orderIndex: 0,
            exerciseType: "activity"
        )
        entry.activityTypeName = "Bouldering"
        entry.targetTags = ["Climbing"]
        entry.sourcePlanBlockID = UUID()
        workout.entries = [entry]

        let goal = WorkoutGoal(
            title: "Climb weekly",
            goalKind: .frequency,
            linkedActivityTags: ["Climbing"],
            targetValue: 1,
            targetUnit: "session",
            periodUnit: .week,
            periodCount: 1,
            successCriteria: "You log one climbing session this week."
        )

        XCTAssertTrue(goal.matches(workout: workout))
        XCTAssertTrue(goal.matches(entry: entry))
        XCTAssertFalse(entry.hasExercisePreferenceSignal)
        XCTAssertTrue(WorkoutGoalProgressResolver.matchingCompletedWorkouts(for: goal, in: [workout]).isEmpty)
    }

    func testActivityKindGoalMatchesLegacyCardioEntryType() {
        let workout = LiveWorkout(name: "Conditioning", workoutType: .mixed)
        workout.completedAt = Date()
        let cardioEntry = LiveWorkoutEntry(
            exerciseName: "Bike",
            orderIndex: 0,
            exerciseType: "cardio"
        )
        cardioEntry.durationSeconds = 900
        cardioEntry.completedAt = Date()
        workout.entries = [cardioEntry]

        let goal = WorkoutGoal(
            title: "Do weekly cardio support",
            goalKind: .frequency,
            linkedWorkoutType: .mixed,
            linkedActivityKind: .cardio,
            targetValue: 1,
            targetUnit: "entries",
            periodUnit: .week,
            periodCount: 1,
            successCriteria: "You complete one cardio entry this week."
        )

        let insight = WorkoutGoalProgressResolver.insights(
            goals: [goal],
            workouts: [workout],
            exerciseHistory: [],
            useLbs: false
        ).first

        XCTAssertEqual(insight?.currentValueText, "1")
        XCTAssertEqual(insight?.progressFraction, 1)
    }

    func testActivityTagGoalMatchesCustomLiveWorkoutAndSessionIdentity() {
        let workout = LiveWorkout(
            name: "Climbing Session",
            workoutType: .climbing,
            focusAreas: ["Bouldering", "Grip endurance"]
        )
        workout.completedAt = Date()
        let entry = LiveWorkoutEntry(
            exerciseName: "Limit Bouldering",
            orderIndex: 0,
            exerciseType: "skill"
        )
        entry.activityTypeName = "Bouldering"
        entry.targetTags = ["Climbing", "Grip endurance"]
        entry.durationSeconds = 1_800
        entry.completedAt = Date()
        workout.entries = [entry]

        let exercise = Exercise(name: "Limit Bouldering", category: .skill)
        exercise.activityTypeName = "Bouldering"
        exercise.targetTags = ["Climbing", "Grip endurance"]
        let session = WorkoutSession(exercise: exercise, sets: 0, reps: 0, weightKg: nil)
        session.durationMinutes = 30

        let goal = WorkoutGoal(
            title: "Climb twice weekly",
            goalKind: .frequency,
            linkedActivityTags: ["Bouldering"],
            targetValue: 2,
            targetUnit: "sessions",
            periodUnit: .week,
            periodCount: 1,
            successCriteria: "You complete two bouldering sessions this week."
        )

        XCTAssertTrue(goal.matches(workout: workout))
        XCTAssertTrue(goal.matches(entry: entry))
        XCTAssertTrue(goal.matches(session: session))
        XCTAssertEqual(goal.scopeSummary, "Bouldering")
    }

    func testMixedWorkoutSuggestionsIncludeRelevantNonStrengthExercises() throws {
        container = try ModelContainer(
            for: LiveWorkout.self,
            LiveWorkoutEntry.self,
            Exercise.self,
            ExerciseHistory.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        context = ModelContext(container)

        let bench = Exercise(name: "Bench Press", category: .strength, muscleGroup: .chest)
        let run = Exercise(name: "Running", category: .cardio)
        let mobility = Exercise(name: "Hip Mobility Flow", category: .mobility)
        context.insert(bench)
        context.insert(run)
        context.insert(mobility)

        let workout = LiveWorkout(
            name: "Push + Cardio",
            workoutType: .mixed,
            targetMuscleGroups: [.chest],
            focusAreas: ["Push", "cardio"]
        )
        let viewModel = LiveWorkoutViewModel(workout: workout)
        viewModel.debugRebuildSuggestionPoolForTests(modelContext: context)

        XCTAssertTrue(viewModel.availableSuggestions.contains { $0.exerciseName == "Bench Press" })
        XCTAssertTrue(viewModel.availableSuggestions.contains { $0.exerciseName == "Running" && $0.category == .cardio })
        XCTAssertFalse(viewModel.availableSuggestions.contains { $0.exerciseName == "Hip Mobility Flow" })
    }

    func testAddingCardioSuggestionCreatesTrackableCardioEntryWithoutPrefilledStrengthSets() {
        let workout = LiveWorkout(name: "Support", workoutType: .mixed)
        let viewModel = LiveWorkoutViewModel(workout: workout)
        let suggestion = LiveWorkoutViewModel.ExerciseSuggestion(
            exerciseName: "Running",
            muscleGroup: "Cardio",
            category: .cardio,
            activityTypeName: "Running",
            activityMatchingTokens: ["running", "cardio", "endurance"],
            targetTags: ["Endurance"],
            trackingFields: [.duration, .distance],
            defaultSets: 3,
            defaultReps: 10
        )

        viewModel.addExerciseFromSuggestion(suggestion)

        let entry = viewModel.entries.first
        XCTAssertEqual(entry?.exerciseName, "Running")
        XCTAssertEqual(entry?.exerciseType, "cardio")
        XCTAssertTrue(entry?.sets.isEmpty == true)
        XCTAssertEqual(entry?.targetTags, ["Endurance"])
        XCTAssertEqual(entry?.trackingFields, [.duration, .distance])
        XCTAssertFalse(entry?.hasExercisePreferenceSignal ?? true)
    }

    private func makeWorkout(initialReps: Int) -> (LiveWorkout, LiveWorkoutEntry) {
        let workout = LiveWorkout(name: "Push Day", workoutType: .strength)
        let entry = LiveWorkoutEntry(exerciseName: "Bench Press", orderIndex: 0)
        entry.addSet(LiveWorkoutEntry.SetData(
            reps: initialReps,
            weight: CleanWeight(kg: 80, lbs: 176.5),
            completed: false,
            isWarmup: false
        ))
        entry.workout = workout
        workout.entries = [entry]
        return (workout, entry)
    }
}

private final class InvalidationCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0

    var value: Int {
        lock.withLock { count }
    }

    func increment() {
        lock.withLock {
            count += 1
        }
    }
}
