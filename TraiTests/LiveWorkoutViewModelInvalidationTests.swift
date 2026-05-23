import Observation
import HealthKit
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

    func testLiveWorkoutReviewPromptIncludesActivitySegmentMetrics() {
        let workout = LiveWorkout(name: "Strength + Climbing", workoutType: .mixed)
        workout.completedAt = Date()

        let entry = LiveWorkoutEntry(
            exerciseName: "Limit Bouldering",
            orderIndex: 0,
            exerciseType: "skill"
        )
        entry.activityTypeName = "Bouldering"
        entry.targetTags = ["Climbing", "Grip power"]
        entry.activitySegments = [
            LiveWorkoutEntry.ActivitySegment(durationSeconds: 600, reps: 4, notes: "Overhang attempts"),
            LiveWorkoutEntry.ActivitySegment(durationSeconds: 480, reps: 3)
        ]
        workout.entries = [entry]

        let prompt = workout.traiReviewPrompt

        XCTAssertTrue(prompt.contains("Limit Bouldering"))
        XCTAssertTrue(prompt.contains("Bouldering"))
        XCTAssertTrue(prompt.contains("18:00"))
        XCTAssertTrue(prompt.contains("2 segments"))
        XCTAssertTrue(prompt.contains("7 attempts"))
        XCTAssertFalse(prompt.contains("7 reps"))
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
        XCTAssertEqual(history.activityTypeName, "Bouldering")
        XCTAssertEqual(history.activityKind, .skill)
        XCTAssertEqual(history.activityTags, ["Climbing", "Grip endurance"])
        XCTAssertEqual(history.trackingFields, [.duration, .reps, .notes])
        XCTAssertEqual(history.durationSeconds, 1_200)
        XCTAssertEqual(history.totalSets, 1)
        XCTAssertEqual(history.totalReps, 8)
        XCTAssertEqual(history.bestSetReps, 8)
        XCTAssertEqual(history.repPatternArray, [8])
        XCTAssertFalse(history.hasStrengthMetrics)
        XCTAssertNil(ExercisePerformanceService.snapshot(exerciseName: history.exerciseName, history: records))
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

    func testPlannedActivityCountsAfterUserLogsData() {
        let workout = LiveWorkout(name: "Strength + Mobility", workoutType: .mixed)
        workout.completedAt = Date()
        let entry = LiveWorkoutEntry(
            exerciseName: "Shoulder Mobility",
            orderIndex: 0,
            exerciseType: "mobility"
        )
        entry.activityTypeName = "Mobility Flow"
        entry.sourcePlanBlockID = UUID()
        entry.plannedDurationSeconds = 300
        entry.trackingFields = [.duration, .notes]
        entry.workout = workout
        workout.entries = [entry]

        XCTAssertTrue(entry.isPlannedActivityGuidance)
        XCTAssertFalse(entry.hasExercisePreferenceSignal)
        XCTAssertFalse(entry.isLoggedActivity)

        entry.activitySegments = [
            LiveWorkoutEntry.ActivitySegment(durationSeconds: 300, notes: "Shoulder prep")
        ]

        XCTAssertFalse(entry.isPlannedActivityGuidance)
        XCTAssertTrue(entry.hasExercisePreferenceSignal)
        XCTAssertTrue(entry.isLoggedActivity)
        XCTAssertEqual(workout.entrySummaryStats.activityEntryCount, 1)
        XCTAssertEqual(ExerciseHistory.records(from: workout).count, 1)
    }

    func testMixedWorkoutHistorySummarySeparatesExercisesAndActivities() {
        let workout = LiveWorkout(name: "Strength + Climb", workoutType: .mixed)
        workout.startedAt = Date(timeIntervalSince1970: 1_000)
        workout.completedAt = Date(timeIntervalSince1970: 4_600)

        let strengthEntry = LiveWorkoutEntry(exerciseName: "Back Squat", orderIndex: 0)
        strengthEntry.addSet(LiveWorkoutEntry.SetData(reps: 8, weight: .zero, completed: true))
        strengthEntry.addSet(LiveWorkoutEntry.SetData(reps: 8, weight: .zero, completed: false))

        let activityEntry = LiveWorkoutEntry(
            exerciseName: "Bouldering",
            orderIndex: 1,
            exerciseType: "skill"
        )
        activityEntry.activityTypeName = "Bouldering"
        activityEntry.completedAt = workout.completedAt

        let plannedActivity = LiveWorkoutEntry(
            exerciseName: "Mobility Cooldown",
            orderIndex: 2,
            exerciseType: "mobility"
        )
        plannedActivity.activityTypeName = "Mobility"
        plannedActivity.sourcePlanBlockID = UUID()

        strengthEntry.workout = workout
        activityEntry.workout = workout
        plannedActivity.workout = workout
        workout.entries = [strengthEntry, activityEntry, plannedActivity]

        XCTAssertEqual(workout.entrySummaryStats.strengthEntryCount, 1)
        XCTAssertEqual(workout.entrySummaryStats.activityEntryCount, 1)
        XCTAssertEqual(workout.entrySummaryStats.loggedActivityCount, 1)
        XCTAssertEqual(
            workout.historySummarySegments,
            ["1 exercise", "1 activity", "1 set", "60 min"]
        )
    }

    func testWorkoutHistorySummaryIncludesLoggedActivityCounts() {
        let workout = LiveWorkout(name: "Climbing Session", workoutType: .climbing)
        workout.startedAt = Date(timeIntervalSince1970: 1_000)
        workout.completedAt = Date(timeIntervalSince1970: 3_400)

        let entry = LiveWorkoutEntry(
            exerciseName: "Limit Bouldering",
            orderIndex: 0,
            exerciseType: "sportPractice"
        )
        entry.activityTypeName = "Bouldering"
        entry.activitySegments = [
            LiveWorkoutEntry.ActivitySegment(durationSeconds: 600, reps: 4),
            LiveWorkoutEntry.ActivitySegment(durationSeconds: 600, reps: 3)
        ]
        entry.workout = workout
        workout.entries = [entry]

        XCTAssertEqual(
            workout.historySummarySegments,
            ["1 activity", "7 attempts", "40 min"]
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

    func testHealthKitLiveWorkoutMetadataIncludesActivitySummary() {
        let workout = LiveWorkout(
            name: "Strength + Climb",
            workoutType: .mixed,
            focusAreas: ["Climbing", "Power"]
        )
        workout.startedAt = Date(timeIntervalSince1970: 1_000)
        workout.completedAt = Date(timeIntervalSince1970: 4_600)

        let strengthEntry = LiveWorkoutEntry(exerciseName: "Back Squat", orderIndex: 0)
        strengthEntry.addSet(LiveWorkoutEntry.SetData(reps: 8, weight: .zero, completed: true))

        let activityEntry = LiveWorkoutEntry(
            exerciseName: "Limit Bouldering",
            orderIndex: 1,
            exerciseType: "skill"
        )
        activityEntry.activityTypeName = "Bouldering"
        activityEntry.targetTags = ["Climbing", "Grip endurance"]
        activityEntry.activitySegments = [
            LiveWorkoutEntry.ActivitySegment(durationSeconds: 1_200, reps: 8, notes: "Limit attempts")
        ]
        activityEntry.completedAt = workout.completedAt

        let plannedActivity = LiveWorkoutEntry(
            exerciseName: "Easy Spin",
            orderIndex: 2,
            exerciseType: "cardio"
        )
        plannedActivity.activityTypeName = "Cycling"
        plannedActivity.targetTags = ["Recovery"]
        plannedActivity.sourcePlanBlockID = UUID()

        workout.entries = [strengthEntry, activityEntry, plannedActivity]

        let metadata = HealthKitService.liveWorkoutMetadata(for: workout)

        XCTAssertEqual(metadata[HKMetadataKeyWorkoutBrandName] as? String, "Trai")
        XCTAssertEqual(metadata["summary_segments"] as? String, "1 exercise | 1 activity | 8 attempts | 1 set | 60 min")
        XCTAssertEqual(metadata["exercise_count"] as? Int, 1)
        XCTAssertEqual(metadata["activity_count"] as? Int, 1)
        XCTAssertEqual(metadata["logged_activity_count"] as? Int, 1)
        XCTAssertEqual(metadata["activity_names"] as? String, "Bouldering")
        XCTAssertEqual(metadata["activity_tags"] as? String, "Climbing,Power,Grip endurance")
        XCTAssertEqual(metadata["activity_duration_minutes"] as? Int, 20)
    }

    func testHealthKitActivityTypeDoesNotTreatStrengthRowsAsRowing() {
        let workout = LiveWorkout(name: "Custom Pull", workoutType: .custom)
        let entry = LiveWorkoutEntry(
            exerciseName: "Seated Cable Row",
            orderIndex: 0,
            exerciseType: "strength"
        )
        entry.addSet(LiveWorkoutEntry.SetData(reps: 10, weight: .zero, completed: true))
        workout.entries = [entry]

        XCTAssertEqual(HealthKitService.healthKitActivityType(for: workout), .other)
    }

    func testHealthKitActivityTypeUsesActivityIdentityForFlexibleMixedWorkouts() {
        let workout = LiveWorkout(name: "Easy Cardio", workoutType: .mixed)
        let entry = LiveWorkoutEntry(
            exerciseName: "Outdoor Run",
            orderIndex: 0,
            exerciseType: "cardio"
        )
        entry.activityTypeName = "Running"
        entry.activitySegments = [
            LiveWorkoutEntry.ActivitySegment(durationSeconds: 1_800, distanceMeters: 4_000)
        ]
        entry.completedAt = Date()
        workout.entries = [entry]

        XCTAssertEqual(HealthKitService.healthKitActivityType(for: workout), .running)
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

    func testActivityScopedGoalCanProgressInsideMixedWorkoutWithDifferentBroadType() {
        let workout = LiveWorkout(name: "Strength + Climbing", workoutType: .mixed)
        workout.completedAt = Date()

        let strengthEntry = LiveWorkoutEntry(exerciseName: "Back Squat", orderIndex: 0)
        strengthEntry.addSet(LiveWorkoutEntry.SetData(reps: 6, weight: .zero, completed: true))

        let climbingEntry = LiveWorkoutEntry(
            exerciseName: "Limit Bouldering",
            orderIndex: 1,
            exerciseType: "skill"
        )
        climbingEntry.activityTypeName = "Bouldering"
        climbingEntry.targetTags = ["Climbing", "Grip power"]
        climbingEntry.durationSeconds = 1_200

        workout.entries = [strengthEntry, climbingEntry]

        let goal = WorkoutGoal(
            title: "Keep climbing in the plan",
            goalKind: .frequency,
            linkedWorkoutType: .climbing,
            linkedActivityTags: ["Climbing"],
            targetValue: 1,
            targetUnit: "session",
            periodUnit: .week,
            periodCount: 1,
            successCriteria: "You log one climbing block this week."
        )

        let insight = WorkoutGoalProgressResolver.insights(
            goals: [goal],
            workouts: [workout],
            exerciseHistory: [],
            useLbs: false
        ).first

        XCTAssertTrue(goal.matches(workout: workout))
        XCTAssertEqual(insight?.currentValueText, "1")
        XCTAssertEqual(insight?.progressFraction, 1)
    }

    func testActivityNameGoalCanMatchBroaderEntryTargetTag() {
        let workout = LiveWorkout(name: "Practice", workoutType: .mixed)
        workout.startedAt = Date().addingTimeInterval(-1_800)
        workout.completedAt = Date()

        let entry = LiveWorkoutEntry(
            exerciseName: "Limit Bouldering",
            orderIndex: 0,
            exerciseType: "sportPractice"
        )
        entry.activityTypeName = "Bouldering"
        entry.targetTags = ["Climbing", "Grip power"]
        entry.activitySegments = [
            .init(durationSeconds: 900, reps: 5)
        ]
        workout.entries = [entry]

        let goal = WorkoutGoal(
            title: "Build weekly climbing attempts",
            goalKind: .count,
            linkedActivityName: "Climbing",
            targetValue: 5,
            targetUnit: "attempts",
            periodUnit: .week,
            periodCount: 1,
            successCriteria: "You log five climbing attempts in one week."
        )

        let insight = WorkoutGoalProgressResolver.insights(
            goals: [goal],
            workouts: [workout],
            exerciseHistory: [],
            useLbs: false
        ).first

        XCTAssertTrue(goal.matches(entry: entry))
        XCTAssertEqual(insight?.currentValueText, "5 attempts")
        XCTAssertEqual(insight?.progressFraction, 1)
    }

    func testPeriodDurationGoalSumsMatchingActivityWork() {
        let firstWorkout = LiveWorkout(name: "Strength + Bike", workoutType: .mixed)
        firstWorkout.startedAt = Date().addingTimeInterval(-3_600)
        firstWorkout.completedAt = Date().addingTimeInterval(-2_400)
        let firstEntry = LiveWorkoutEntry(
            exerciseName: "Easy Bike",
            orderIndex: 0,
            exerciseType: "cardio"
        )
        firstEntry.activityKind = .cardio
        firstEntry.durationSeconds = 1_200
        firstEntry.workout = firstWorkout
        firstWorkout.entries = [firstEntry]

        let secondWorkout = LiveWorkout(name: "Cardio Support", workoutType: .mixed)
        secondWorkout.startedAt = Date().addingTimeInterval(-1_800)
        secondWorkout.completedAt = Date().addingTimeInterval(-600)
        let secondEntry = LiveWorkoutEntry(
            exerciseName: "Incline Walk",
            orderIndex: 0,
            exerciseType: "cardio"
        )
        secondEntry.activityKind = .cardio
        secondEntry.durationSeconds = 1_800
        secondEntry.workout = secondWorkout
        secondWorkout.entries = [secondEntry]

        let goal = WorkoutGoal(
            title: "Build weekly cardio support",
            goalKind: .duration,
            linkedActivityKind: .cardio,
            targetValue: 45,
            targetUnit: "min",
            periodUnit: .week,
            periodCount: 1,
            successCriteria: "You log 45 minutes of cardio support in one week."
        )

        let insight = WorkoutGoalProgressResolver.insights(
            goals: [goal],
            workouts: [firstWorkout, secondWorkout],
            exerciseHistory: [],
            useLbs: false
        ).first

        XCTAssertEqual(goal.trackingSummary, "45 min / week")
        XCTAssertEqual(insight?.currentValueText, "50 min")
        XCTAssertEqual(insight?.progressFraction, 1)
    }

    func testPeriodCountGoalSumsActivityAttemptsInsideMixedWorkouts() {
        let firstWorkout = LiveWorkout(name: "Strength + Climbing", workoutType: .mixed)
        firstWorkout.startedAt = Date().addingTimeInterval(-3_600)
        firstWorkout.completedAt = Date().addingTimeInterval(-2_400)
        let firstEntry = LiveWorkoutEntry(
            exerciseName: "Limit Bouldering",
            orderIndex: 0,
            exerciseType: "sportPractice"
        )
        firstEntry.activityTypeName = "Bouldering"
        firstEntry.targetTags = ["Climbing"]
        firstEntry.activitySegments = [
            .init(durationSeconds: 600, reps: 4),
            .init(durationSeconds: 600, reps: 3)
        ]
        firstEntry.workout = firstWorkout
        firstWorkout.entries = [firstEntry]

        let secondWorkout = LiveWorkout(name: "Climb Practice", workoutType: .mixed)
        secondWorkout.startedAt = Date().addingTimeInterval(-1_800)
        secondWorkout.completedAt = Date().addingTimeInterval(-600)
        let secondEntry = LiveWorkoutEntry(
            exerciseName: "Bouldering Volume",
            orderIndex: 0,
            exerciseType: "sportPractice"
        )
        secondEntry.activityTypeName = "Bouldering"
        secondEntry.targetTags = ["Climbing"]
        secondEntry.activitySegments = [
            .init(durationSeconds: 900, reps: 5)
        ]
        secondEntry.workout = secondWorkout
        secondWorkout.entries = [secondEntry]

        let goal = WorkoutGoal(
            title: "Build weekly climbing attempts",
            goalKind: .count,
            linkedActivityTags: ["Climbing"],
            targetValue: 12,
            targetUnit: "attempts",
            periodUnit: .week,
            periodCount: 1,
            successCriteria: "You log 12 climbing attempts in one week."
        )

        let insight = WorkoutGoalProgressResolver.insights(
            goals: [goal],
            workouts: [firstWorkout, secondWorkout],
            exerciseHistory: [],
            useLbs: false
        ).first

        XCTAssertEqual(goal.trackingSummary, "12 attempts / week")
        XCTAssertEqual(insight?.currentValueText, "12 attempts")
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
