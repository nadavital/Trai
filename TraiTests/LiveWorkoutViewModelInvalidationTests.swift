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

    func testFinishWorkoutDoesNotLogBlankActivityEntry() {
        let workout = LiveWorkout(name: "Mixed Session", workoutType: .mixed)
        let entry = LiveWorkoutEntry(
            exerciseName: "Cycling",
            orderIndex: 0,
            exerciseType: "cardio"
        )
        entry.trackingFields = [.duration, .distance]
        entry.workout = workout
        workout.entries = [entry]
        context.insert(workout)

        let viewModel = LiveWorkoutViewModel(workout: workout)
        viewModel.finishWorkout()

        XCTAssertNotNil(workout.completedAt)
        XCTAssertNil(entry.completedAt)
        XCTAssertFalse(entry.hasExercisePreferenceSignal)
    }

    func testFinishWorkoutDoesNotAutoCompleteSuggestedStrengthSet() {
        let (workout, entry) = makeWorkout(initialReps: 8)
        context.insert(workout)

        let viewModel = LiveWorkoutViewModel(workout: workout)
        XCTAssertEqual(viewModel.completedSets, 0)

        viewModel.finishWorkout()

        XCTAssertNotNil(workout.completedAt)
        XCTAssertEqual(viewModel.completedSets, 0)
        XCTAssertEqual(entry.sets.first?.completed, false)
        XCTAssertFalse(entry.hasExercisePreferenceSignal)
        XCTAssertTrue(ExerciseHistory.records(from: workout).isEmpty)
        XCTAssertEqual(
            entry.traiWorkoutContextDetail(usesMetricExerciseWeight: true),
            "Bench Press • 0 logged sets"
        )
    }

    func testFinishWorkoutPreservesUserCompletedStrengthSet() {
        let (workout, entry) = makeWorkout(initialReps: 8)
        context.insert(workout)

        let viewModel = LiveWorkoutViewModel(workout: workout)
        viewModel.updateSet(at: 0, in: entry, reps: 9)
        viewModel.finishWorkout()

        XCTAssertEqual(viewModel.completedSets, 1)
        XCTAssertEqual(entry.sets.first?.completed, true)
        XCTAssertTrue(entry.hasExercisePreferenceSignal)
        XCTAssertEqual(ExerciseHistory.records(from: workout).count, 1)
    }

    func testFinishWorkoutTimestampsActivityEntryWithLoggedData() {
        let workout = LiveWorkout(name: "Mixed Session", workoutType: .mixed)
        let entry = LiveWorkoutEntry(
            exerciseName: "Cycling",
            orderIndex: 0,
            exerciseType: "cardio"
        )
        entry.durationSeconds = 900
        entry.workout = workout
        workout.entries = [entry]
        context.insert(workout)

        let viewModel = LiveWorkoutViewModel(workout: workout)
        viewModel.finishWorkout()

        XCTAssertNotNil(workout.completedAt)
        XCTAssertNotNil(entry.completedAt)
        XCTAssertTrue(entry.hasExercisePreferenceSignal)
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

    func testPlannedActivitySegmentsDoNotCountAsLoggedData() {
        let workout = LiveWorkout(name: "Bouldering Intervals", workoutType: .mixed)
        let entry = LiveWorkoutEntry(
            exerciseName: "Limit Bouldering",
            orderIndex: 0,
            exerciseType: "sportPractice"
        )
        entry.activityTypeName = "Bouldering"
        entry.trackingFields = [.duration, .reps, .notes]
        entry.plannedActivitySegments = [
            LiveWorkoutEntry.ActivitySegment(durationSeconds: 600, reps: 4),
            LiveWorkoutEntry.ActivitySegment(durationSeconds: 600, reps: 3)
        ]
        entry.workout = workout
        workout.entries = [entry]
        context.insert(workout)

        let viewModel = LiveWorkoutViewModel(workout: workout)

        XCTAssertFalse(entry.hasExercisePreferenceSignal)
        XCTAssertFalse(viewModel.isWorkoutComplete)
        XCTAssertEqual(ExerciseHistory.records(from: workout), [])
        XCTAssertEqual(entry.plannedActivitySummarySegments, ["Bouldering", "2 planned segments"])
    }

    func testAIStartedPlannedActivityDetailsRemainAvailableBeforeLogging() {
        let workout = LiveWorkout(name: "Rowing Session", workoutType: .cardio)
        let entry = LiveWorkoutEntry(
            exerciseName: "Rowing",
            orderIndex: 0,
            exerciseType: "cardio"
        )
        entry.activityTypeName = "Rowing"
        entry.plannedDurationSeconds = 1_200
        entry.plannedTarget = "Steady aerobic work"
        entry.workout = workout
        workout.entries = [entry]
        context.insert(workout)

        XCTAssertFalse(entry.isPlannedActivityGuidance)
        XCTAssertFalse(entry.hasExercisePreferenceSignal)
        XCTAssertEqual(entry.plannedActivitySummarySegments, ["20 min", "Steady aerobic work"])
        XCTAssertEqual(
            entry.traiWorkoutContextDetail(usesMetricExerciseWeight: true),
            "Rowing • 20 min • Steady aerobic work • tracks Duration/Distance"
        )
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

    func testLiveWorkoutReviewPromptIncludesLoggedActivityNotes() {
        let workout = LiveWorkout(name: "Row + Mobility", workoutType: .mixed)
        workout.completedAt = Date()

        let entry = LiveWorkoutEntry(
            exerciseName: "Rowing Intervals",
            orderIndex: 0,
            exerciseType: "conditioning"
        )
        entry.activityTypeName = "Rowing"
        entry.notes = "Keep the stroke rate calmer next time"
        entry.activitySegments = [
            LiveWorkoutEntry.ActivitySegment(durationSeconds: 300, distanceMeters: 1_000, notes: "First interval felt smooth"),
            LiveWorkoutEntry.ActivitySegment(durationSeconds: 240, distanceMeters: 850, notes: "Grip tired near the end")
        ]
        workout.entries = [entry]

        let prompt = workout.traiReviewPrompt

        XCTAssertTrue(prompt.contains("Rowing Intervals"))
        XCTAssertTrue(prompt.contains("notes Keep the stroke rate calmer next time"))
        XCTAssertTrue(prompt.contains("First interval felt smooth"))
        XCTAssertTrue(prompt.contains("Grip tired near the end"))
    }

    func testLiveWorkoutReviewPromptExcludesUnloggedPlannedActivityGuidance() {
        let workout = LiveWorkout(name: "Strength + Mobility", workoutType: .mixed)
        workout.completedAt = Date()

        let loggedActivity = LiveWorkoutEntry(
            exerciseName: "Bike Support",
            orderIndex: 0,
            exerciseType: "cardio"
        )
        loggedActivity.activityTypeName = "Cycling"
        loggedActivity.activityRole = .accessory
        loggedActivity.durationSeconds = 600

        let plannedGuidance = LiveWorkoutEntry(
            exerciseName: "Mobility Cooldown",
            orderIndex: 1,
            exerciseType: "activity"
        )
        plannedGuidance.activityTypeName = "Mobility"
        plannedGuidance.activityRole = .cooldown
        plannedGuidance.sourcePlanBlockID = UUID()

        workout.entries = [loggedActivity, plannedGuidance]

        let prompt = workout.traiReviewPrompt

        XCTAssertTrue(prompt.contains("Bike Support"))
        XCTAssertTrue(prompt.contains("Cycling"))
        XCTAssertTrue(prompt.contains("1 logged entry"))
        XCTAssertFalse(prompt.contains("2 items"))
        XCTAssertFalse(prompt.contains("accessory"))
        XCTAssertFalse(prompt.contains("Mobility Cooldown"))
        XCTAssertFalse(prompt.contains("cooldown"))
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
        XCTAssertTrue(history.hasActivityMetrics)

        let snapshot = ExercisePerformanceService.snapshot(exerciseName: history.exerciseName, history: records)
        XCTAssertEqual(snapshot?.lastSession?.exerciseName, "Limit Bouldering")
        XCTAssertEqual(snapshot?.activityDurationPR?.durationSeconds, 1_200)
        XCTAssertEqual(snapshot?.activityCountPR?.totalReps, 8)
        XCTAssertNil(snapshot?.weightPR)
        XCTAssertEqual(history.suggestionSummary(usesMetricWeight: true), "20m • 8 attempts")

        let pr = snapshot.map { ExercisePR.from(snapshot: $0) }
        XCTAssertEqual(pr?.maxActivityCount, 8)
        XCTAssertEqual(pr?.maxActivityCountLabel, "attempts")
    }

    func testExerciseHistoryRecordsToInsertIncludesLoggedGeneralActivities() {
        let workout = LiveWorkout(name: "Mixed Session", workoutType: .mixed)
        workout.completedAt = Date()

        let entry = LiveWorkoutEntry(
            exerciseName: "Rowing Intervals",
            orderIndex: 0,
            exerciseType: "conditioning"
        )
        entry.activityTypeName = "Rowing"
        entry.trackingFields = [.duration, .distance]
        entry.activitySegments = [
            LiveWorkoutEntry.ActivitySegment(durationSeconds: 300, distanceMeters: 1_000),
            LiveWorkoutEntry.ActivitySegment(durationSeconds: 240, distanceMeters: 850)
        ]
        entry.workout = workout
        workout.entries = [entry]

        let records = ExerciseHistory.recordsToInsert(from: workout, existingHistories: [])

        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.exerciseName, "Rowing Intervals")
        XCTAssertEqual(records.first?.activityTypeName, "Rowing")
        XCTAssertEqual(records.first?.durationSeconds, 540)
        XCTAssertEqual(records.first?.distanceMeters, 1_850)
    }

    func testExerciseHistoryRecordsToInsertSkipsExistingSourceEntryOnly() {
        let workout = LiveWorkout(name: "Repeated Work", workoutType: .mixed)
        let completedAt = Date()
        workout.completedAt = completedAt

        let firstEntry = LiveWorkoutEntry(exerciseName: "Rowing", orderIndex: 0, exerciseType: "conditioning")
        firstEntry.activitySegments = [LiveWorkoutEntry.ActivitySegment(durationSeconds: 300)]
        firstEntry.workout = workout

        let secondEntry = LiveWorkoutEntry(exerciseName: "Rowing", orderIndex: 1, exerciseType: "conditioning")
        secondEntry.activitySegments = [LiveWorkoutEntry.ActivitySegment(durationSeconds: 240)]
        secondEntry.workout = workout

        workout.entries = [firstEntry, secondEntry]
        let existing = ExerciseHistory(from: firstEntry, performedAt: completedAt)

        let records = ExerciseHistory.recordsToInsert(
            from: workout,
            existingHistories: [existing],
            performedAt: completedAt
        )

        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.sourceWorkoutEntryId, secondEntry.id)
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

    func testLiveActivityProgressIgnoresUnloggedPlannedActivityGuidance() {
        let workout = LiveWorkout(name: "Strength + Mobility", workoutType: .mixed)

        let strengthEntry = LiveWorkoutEntry(exerciseName: "Back Squat", orderIndex: 0)
        strengthEntry.addSet(LiveWorkoutEntry.SetData(reps: 8, weight: .zero, completed: true))

        let plannedGuidance = LiveWorkoutEntry(
            exerciseName: "Mobility Cooldown",
            orderIndex: 1,
            exerciseType: "mobility"
        )
        plannedGuidance.activityTypeName = "Mobility"
        plannedGuidance.sourcePlanBlockID = UUID()
        plannedGuidance.plannedDurationSeconds = 300

        let loggedActivity = LiveWorkoutEntry(
            exerciseName: "Bouldering",
            orderIndex: 2,
            exerciseType: "sportPractice"
        )
        loggedActivity.activityTypeName = "Bouldering"
        loggedActivity.activitySegments = [
            LiveWorkoutEntry.ActivitySegment(durationSeconds: 600, reps: 4)
        ]

        workout.entries = [strengthEntry, plannedGuidance, loggedActivity]
        context.insert(workout)

        let viewModel = LiveWorkoutViewModel(workout: workout)

        XCTAssertEqual(
            viewModel.liveActivityProgressSummary,
            LiveWorkoutViewModel.LiveActivityProgressSummary(
                completed: 2,
                total: 2,
                label: "items",
                supportsSetShortcut: false
            )
        )
    }

    func testLiveActivityProgressFallsBackToPlannedActivityGuidanceWhenNoLoggedEntriesExist() {
        let workout = LiveWorkout(name: "Mobility Plan", workoutType: .mobility)

        let plannedGuidance = LiveWorkoutEntry(
            exerciseName: "Hip Mobility",
            orderIndex: 0,
            exerciseType: "mobility"
        )
        plannedGuidance.activityTypeName = "Mobility Flow"
        plannedGuidance.sourcePlanBlockID = UUID()
        plannedGuidance.plannedDurationSeconds = 600

        workout.entries = [plannedGuidance]
        context.insert(workout)

        let viewModel = LiveWorkoutViewModel(workout: workout)

        XCTAssertEqual(
            viewModel.liveActivityProgressSummary,
            LiveWorkoutViewModel.LiveActivityProgressSummary(
                completed: 0,
                total: 1,
                label: "item",
                supportsSetShortcut: false
            )
        )
    }

    func testMixedLiveActivityProgressDoesNotCountUncompletedPrefilledStrengthSets() {
        let workout = LiveWorkout(name: "Strength + Cardio", workoutType: .mixed)

        let strengthEntry = LiveWorkoutEntry(exerciseName: "Back Squat", orderIndex: 0)
        strengthEntry.addSet(LiveWorkoutEntry.SetData(reps: 8, weight: .zero, completed: false))

        let cardioEntry = LiveWorkoutEntry(
            exerciseName: "Easy Run",
            orderIndex: 1,
            exerciseType: "cardio"
        )
        cardioEntry.activityTypeName = "Running"
        cardioEntry.plannedDurationSeconds = 600

        workout.entries = [strengthEntry, cardioEntry]
        context.insert(workout)

        let viewModel = LiveWorkoutViewModel(workout: workout)

        XCTAssertEqual(
            viewModel.liveActivityProgressSummary,
            LiveWorkoutViewModel.LiveActivityProgressSummary(
                completed: 0,
                total: 2,
                label: "items",
                supportsSetShortcut: true
            )
        )
    }

    func testMixedLiveActivityProgressCountsEditedStrengthSets() {
        let workout = LiveWorkout(name: "Strength + Cardio", workoutType: .mixed)

        let strengthEntry = LiveWorkoutEntry(exerciseName: "Back Squat", orderIndex: 0)
        strengthEntry.addSet(LiveWorkoutEntry.SetData(reps: 8, weight: .zero, completed: false))

        let cardioEntry = LiveWorkoutEntry(
            exerciseName: "Easy Run",
            orderIndex: 1,
            exerciseType: "cardio"
        )
        cardioEntry.activityTypeName = "Running"
        cardioEntry.plannedDurationSeconds = 600

        workout.entries = [strengthEntry, cardioEntry]
        context.insert(workout)

        let viewModel = LiveWorkoutViewModel(workout: workout)
        viewModel.updateSet(at: 0, in: strengthEntry, reps: 9)

        XCTAssertTrue(strengthEntry.sets.first?.completed == true)
        XCTAssertEqual(
            viewModel.liveActivityProgressSummary,
            LiveWorkoutViewModel.LiveActivityProgressSummary(
                completed: 1,
                total: 2,
                label: "items",
                supportsSetShortcut: false
            )
        )
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

    func testWorkoutHistoryDistributionUsesActivityIdentityOverStableMode() {
        let workout = LiveWorkout(name: "Open Practice", workoutType: .mixed)
        let entry = LiveWorkoutEntry(
            exerciseName: "Limit Bouldering",
            orderIndex: 0,
            exerciseType: "sportPractice"
        )
        entry.activityTypeName = "Bouldering"
        entry.activitySegments = [
            LiveWorkoutEntry.ActivitySegment(durationSeconds: 600, reps: 4)
        ]
        entry.workout = workout
        workout.entries = [entry]

        XCTAssertEqual(workout.historyDistributionLabel, "Bouldering")
        XCTAssertEqual(workout.historyIconName, WorkoutMode.climbing.iconName)

        let sportWorkout = LiveWorkout(name: "Open Sport", workoutType: .mixed)
        let sportEntry = LiveWorkoutEntry(
            exerciseName: "Padel Points",
            orderIndex: 0,
            exerciseType: "sportPractice"
        )
        sportEntry.activityTypeName = "Padel"
        sportEntry.activitySegments = [
            LiveWorkoutEntry.ActivitySegment(durationSeconds: 600, reps: 8)
        ]
        sportEntry.workout = sportWorkout
        sportWorkout.entries = [sportEntry]

        XCTAssertEqual(sportWorkout.historyDistributionLabel, "Padel")
        XCTAssertEqual(sportWorkout.historyIconName, Exercise.Category.sportPractice.iconName)
    }

    func testWorkoutContextSignalsOmitBroadMixedModeWhenActivityIdentityExists() {
        let workout = LiveWorkout(name: "Open Practice", workoutType: .mixed)
        workout.startedAt = Date(timeIntervalSince1970: 1_000)
        workout.completedAt = Date(timeIntervalSince1970: 2_800)
        workout.notes = "Felt smoother on overhangs."

        let entry = LiveWorkoutEntry(
            exerciseName: "Limit Bouldering",
            orderIndex: 0,
            exerciseType: "sportPractice"
        )
        entry.activityTypeName = "Bouldering"
        entry.activitySegments = [
            LiveWorkoutEntry.ActivitySegment(durationSeconds: 600, reps: 4)
        ]
        entry.workout = workout
        workout.entries = [entry]

        XCTAssertEqual(workout.workoutContextSummarySegments, ["Bouldering", "30 min"])

        let signal = WorkoutGoalProgressResolver.globalRecentSignals(
            from: [workout],
            sessions: []
        ).first

        XCTAssertEqual(signal?.subtitle, "Bouldering • 30 min")
        XCTAssertFalse(signal?.subtitle.contains("Mixed") == true)
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
        XCTAssertEqual(day?.totalVolume, 0)
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
        XCTAssertEqual(metadata["workout_item_count"] as? Int, 2)
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

    func testHealthKitMergeChoosesGreatestActualOverlap() {
        let liveWorkout = LiveWorkout(name: "Strength", workoutType: .strength)
        liveWorkout.startedAt = Date(timeIntervalSince1970: 1_000)
        liveWorkout.completedAt = Date(timeIntervalSince1970: 2_800)

        let shortStrength = WorkoutSession(
            healthKitWorkoutID: "short-strength",
            workoutType: "traditionalStrengthTraining",
            durationMinutes: 10,
            caloriesBurned: 100,
            distanceMeters: nil,
            loggedAt: Date(timeIntervalSince1970: 2_100)
        )
        let longerOverlap = WorkoutSession(
            healthKitWorkoutID: "longer-overlap",
            workoutType: "running",
            durationMinutes: 25,
            caloriesBurned: 200,
            distanceMeters: nil,
            loggedAt: Date(timeIntervalSince1970: 1_200)
        )

        let match = HealthKitService.bestOverlappingWorkout(
            for: liveWorkout,
            from: [shortStrength, longerOverlap],
            searchBufferMinutes: 15
        )

        XCTAssertEqual(match?.healthKitWorkoutID, "longer-overlap")
    }

    func testHealthKitMergeDoesNotUseBufferOnlyCandidate() {
        let liveWorkout = LiveWorkout(name: "Strength", workoutType: .strength)
        liveWorkout.startedAt = Date(timeIntervalSince1970: 1_000)
        liveWorkout.completedAt = Date(timeIntervalSince1970: 2_000)
        let nearbyWorkout = WorkoutSession(
            healthKitWorkoutID: "nearby",
            workoutType: "traditionalStrengthTraining",
            durationMinutes: 5,
            caloriesBurned: 50,
            distanceMeters: nil,
            loggedAt: Date(timeIntervalSince1970: 2_200)
        )

        let match = HealthKitService.bestOverlappingWorkout(
            for: liveWorkout,
            from: [nearbyWorkout],
            searchBufferMinutes: 15
        )

        XCTAssertNil(match)
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

    func testActivityScopedGoalDoesNotMatchOnlyByBroadWorkoutType() {
        let workout = LiveWorkout(name: "Plain Mixed Workout", workoutType: .mixed)
        workout.completedAt = Date()
        let entry = LiveWorkoutEntry(exerciseName: "Bench Press", orderIndex: 0)
        entry.addSet(LiveWorkoutEntry.SetData(reps: 8, weight: .zero, completed: true))
        workout.entries = [entry]

        let goal = WorkoutGoal(
            title: "Climb once this week",
            goalKind: .frequency,
            linkedWorkoutType: .mixed,
            linkedActivityTags: ["Climbing"],
            targetValue: 1,
            targetUnit: "session",
            periodUnit: .week,
            periodCount: 1,
            successCriteria: "You log one climbing activity this week."
        )

        XCTAssertFalse(goal.matches(workout: workout))
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

    func testActivityScopedSessionFrequencyCountsWorkoutOnceNotMatchingEntries() {
        let workout = LiveWorkout(
            name: "Full-Body Strength A",
            workoutType: .mixed,
            focusAreas: ["Full Body", "Strength", "Climbing"]
        )
        workout.completedAt = Date()

        let warmup = LiveWorkoutEntry(
            exerciseName: "Dynamic Warm-Up",
            orderIndex: 0,
            exerciseType: "activity"
        )
        warmup.targetTags = ["Strength"]
        warmup.durationSeconds = 480
        warmup.workout = workout

        let strength = LiveWorkoutEntry(exerciseName: "Balance Drill", orderIndex: 1)
        strength.targetTags = ["Strength"]
        strength.addSet(LiveWorkoutEntry.SetData(reps: 10, weight: .zero, completed: true))
        strength.workout = workout

        let climbing = LiveWorkoutEntry(
            exerciseName: "Limit Bouldering",
            orderIndex: 2,
            exerciseType: "skill"
        )
        climbing.targetTags = ["Climbing"]
        climbing.durationSeconds = 600
        climbing.workout = workout

        workout.entries = [warmup, strength, climbing]

        let goal = WorkoutGoal(
            title: "Complete all 3 weekly sessions",
            goalKind: .frequency,
            linkedWorkoutType: .mixed,
            linkedActivityTags: ["Strength", "Climbing"],
            targetValue: 3,
            targetUnit: "sessions",
            periodUnit: .week,
            periodCount: 1,
            successCriteria: "You complete all three planned sessions each week."
        )

        let insight = WorkoutGoalProgressResolver.insights(
            goals: [goal],
            workouts: [workout],
            exerciseHistory: [],
            useLbs: false
        ).first

        XCTAssertEqual(insight?.currentValueText, "1")
        XCTAssertEqual(insight?.progressFraction ?? 0, 1.0 / 3.0, accuracy: 0.001)
    }

    func testGeneratedMixedPlanAdherenceGoalCountsEachCompletedTemplateSession() {
        let plan = WorkoutPlan(
            splitType: .custom,
            daysPerWeek: 3,
            templates: [
                WorkoutPlan.WorkoutTemplate(
                    name: "Pull Strength",
                    sessionType: .strength,
                    focusAreas: ["Back", "Pull Ups"],
                    targetMuscleGroups: ["back"],
                    exercises: [],
                    estimatedDurationMinutes: 45,
                    order: 0
                ),
                WorkoutPlan.WorkoutTemplate(
                    name: "Climbing Skill",
                    sessionType: .climbing,
                    focusAreas: ["Climbing", "Technique"],
                    targetMuscleGroups: [],
                    exercises: [],
                    estimatedDurationMinutes: 40,
                    order: 1
                ),
                WorkoutPlan.WorkoutTemplate(
                    name: "Mobility Flow",
                    sessionType: .mobility,
                    focusAreas: ["Mobility", "Recovery"],
                    targetMuscleGroups: [],
                    exercises: [],
                    estimatedDurationMinutes: 30,
                    order: 2
                )
            ],
            rationale: "Balance strength, climbing, and mobility.",
            guidelines: [],
            progressionStrategy: .defaultStrategy
        )

        let goal = WorkoutGoal(
            title: "Hit all 3 weekly sessions",
            goalKind: .frequency,
            linkedWorkoutType: .mixed,
            linkedActivityTags: ["Weekly Training Plan", "consistency"],
            targetValue: 3,
            targetUnit: "sessions",
            periodUnit: .week,
            periodCount: 1,
            successCriteria: "You complete 3 planned workouts in a week.",
            tracksGeneratedPlanAdherence: true
        )
        goal.normalizeGeneratedPlanAdherenceScopeIfNeeded(for: plan)

        let workout = LiveWorkout(
            name: "Pull Strength",
            workoutType: .strength,
            focusAreas: ["Back", "Pull Ups"]
        )
        workout.startedAt = Date().addingTimeInterval(-1_800)
        workout.completedAt = Date()
        workout.sourcePlanTemplateID = plan.templates[0].id

        let unrelatedWorkout = LiveWorkout(
            name: "Open Gym",
            workoutType: .strength,
            focusAreas: ["Back", "Pull Ups"]
        )
        unrelatedWorkout.startedAt = Date().addingTimeInterval(-900)
        unrelatedWorkout.completedAt = Date()

        XCTAssertNil(goal.linkedWorkoutType)
        XCTAssertFalse(goal.hasActivityScope)
        XCTAssertEqual(goal.generatedPlanTemplateIDs, plan.templates.map(\.id))

        let insight = WorkoutGoalProgressResolver.insights(
            goals: [goal],
            workouts: [workout, unrelatedWorkout],
            exerciseHistory: [],
            useLbs: false
        ).first

        XCTAssertEqual(insight?.currentValueText, "1")
        XCTAssertEqual(insight?.progressFraction ?? 0, 1.0 / 3.0, accuracy: 0.001)
        XCTAssertEqual(
            WorkoutGoalProgressResolver.matchingCompletedWorkouts(for: goal, in: [workout, unrelatedWorkout]).map(\.id),
            [workout.id]
        )
    }

    func testGeneratedPlanAdherenceGoalClearsActivityTagsEvenWhenTemplatesShareBroadType() {
        let plan = WorkoutPlan(
            splitType: .pushPullLegs,
            daysPerWeek: 3,
            templates: [
                WorkoutPlan.WorkoutTemplate(
                    name: "Legs + Hinge Power",
                    sessionType: .mixed,
                    focusAreas: ["Legs", "Hinge Power"],
                    targetMuscleGroups: ["legs"],
                    exercises: [],
                    estimatedDurationMinutes: 45,
                    order: 0
                ),
                WorkoutPlan.WorkoutTemplate(
                    name: "Push + Mobility",
                    sessionType: .mixed,
                    focusAreas: ["Push", "Mobility Flow"],
                    targetMuscleGroups: ["chest", "shoulders"],
                    exercises: [],
                    estimatedDurationMinutes: 45,
                    order: 1
                ),
                WorkoutPlan.WorkoutTemplate(
                    name: "Pull + Climbing",
                    sessionType: .mixed,
                    focusAreas: ["Pull", "Climbing"],
                    targetMuscleGroups: ["back"],
                    exercises: [],
                    estimatedDurationMinutes: 45,
                    order: 2
                )
            ],
            rationale: "Strength leads with climbing visible.",
            guidelines: [],
            progressionStrategy: .defaultStrategy
        )

        let goal = WorkoutGoal(
            title: "Lock in your 3-day rhythm",
            goalKind: .frequency,
            linkedWorkoutType: .mixed,
            linkedActivityTags: ["3-day mixed plan", "strength", "climbing"],
            targetValue: 3,
            targetUnit: "sessions",
            periodUnit: .week,
            periodCount: 1,
            successCriteria: "You complete all 3 planned sessions in at least 4 of the next 5 weeks.",
            tracksGeneratedPlanAdherence: true
        )
        goal.normalizeGeneratedPlanAdherenceScopeIfNeeded(for: plan)

        let workout = LiveWorkout(
            name: "Legs + Hinge Power",
            workoutType: .mixed,
            focusAreas: ["Legs", "Hinge Power"]
        )
        workout.startedAt = Date().addingTimeInterval(-1_800)
        workout.completedAt = Date()
        workout.sourcePlanTemplateID = plan.templates[0].id

        XCTAssertNil(goal.linkedWorkoutType)
        XCTAssertFalse(goal.hasActivityScope)

        let insight = WorkoutGoalProgressResolver.insights(
            goals: [goal],
            workouts: [workout],
            exerciseHistory: [],
            useLbs: false
        ).first

        XCTAssertEqual(insight?.currentValueText, "1")
        XCTAssertEqual(insight?.progressFraction ?? 0, 1.0 / 3.0, accuracy: 0.001)
    }

    func testWeightGoalIgnoresUncompletedPlannedSetWeights() {
        let workout = LiveWorkout(name: "Leg Strength", workoutType: .strength)
        workout.startedAt = Date().addingTimeInterval(-1_800)
        workout.completedAt = Date()

        let entry = LiveWorkoutEntry(
            exerciseName: "Back Squat",
            orderIndex: 0,
            exerciseType: "strength"
        )
        entry.addSet(.init(reps: 5, weightKg: 40, completed: true, isWarmup: false))
        entry.addSet(.init(reps: 5, weightKg: 100, completed: false, isWarmup: false))
        entry.workout = workout
        workout.entries = [entry]

        let goal = WorkoutGoal(
            title: "Squat 80 kg",
            goalKind: .weight,
            linkedActivityName: "Back Squat",
            targetValue: 80,
            targetUnit: "kg",
            successCriteria: "Back squat 80 kg.",
            baselineValue: 0
        )

        let insight = WorkoutGoalProgressResolver.insights(
            goals: [goal],
            workouts: [workout],
            exerciseHistory: [],
            useLbs: false
        ).first

        XCTAssertEqual(insight?.progressFraction ?? 0, 0.5, accuracy: 0.001)
    }

    func testPlankGoalDoesNotNormalizeAsPlanAdherenceGoal() {
        let plan = WorkoutPlan(
            splitType: .custom,
            daysPerWeek: 3,
            templates: [
                WorkoutPlan.WorkoutTemplate(
                    name: "Core A",
                    sessionType: .strength,
                    focusAreas: ["Core"],
                    targetMuscleGroups: ["abs"],
                    exercises: [],
                    estimatedDurationMinutes: 30,
                    order: 0
                )
            ],
            rationale: "Core work.",
            guidelines: [],
            progressionStrategy: .defaultStrategy
        )

        let goal = WorkoutGoal(
            title: "Complete 3 plank sessions",
            goalKind: .frequency,
            linkedWorkoutType: .strength,
            linkedActivityName: "Plank",
            targetValue: 3,
            targetUnit: "sessions",
            periodUnit: .week,
            periodCount: 1,
            successCriteria: "You complete three plank sessions each week."
        )
        goal.normalizeGeneratedPlanAdherenceScopeIfNeeded(for: plan)

        XCTAssertEqual(goal.linkedWorkoutType, .strength)
        XCTAssertEqual(goal.trimmedActivityName, "Plank")
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

    func testActivityScopedGoalsCountWholeCompletedActivityWorkoutWithoutEntries() {
        let workout = LiveWorkout(
            name: "Mobility Flow",
            workoutType: .mobility,
            focusAreas: ["Mobility Flow"]
        )
        workout.startedAt = Date().addingTimeInterval(-1_800)
        workout.completedAt = Date()

        let frequencyGoal = WorkoutGoal(
            title: "Keep mobility consistent",
            goalKind: .frequency,
            linkedActivityTags: ["Mobility Flow"],
            targetValue: 1,
            targetUnit: "sessions",
            periodUnit: .week,
            periodCount: 1,
            successCriteria: "You complete one mobility flow session this week."
        )
        let durationGoal = WorkoutGoal(
            title: "Build mobility time",
            goalKind: .duration,
            linkedActivityTags: ["Mobility Flow"],
            targetValue: 30,
            targetUnit: "min",
            periodUnit: .week,
            periodCount: 1,
            successCriteria: "You complete 30 minutes of mobility flow this week."
        )

        let insights = WorkoutGoalProgressResolver.insights(
            goals: [frequencyGoal, durationGoal],
            workouts: [workout],
            exerciseHistory: [],
            useLbs: false
        )

        XCTAssertTrue(WorkoutGoalProgressResolver.matchingCompletedWorkouts(for: frequencyGoal, in: [workout]).contains { $0.id == workout.id })
        XCTAssertEqual(insights.first { $0.goal.id == frequencyGoal.id }?.currentValueText, "1")
        XCTAssertEqual(insights.first { $0.goal.id == frequencyGoal.id }?.progressFraction, 1)
        XCTAssertEqual(insights.first { $0.goal.id == durationGoal.id }?.currentValueText, "30 min")
        XCTAssertEqual(insights.first { $0.goal.id == durationGoal.id }?.progressFraction, 1)
    }

    func testActivityScopedGoalIgnoresPlannedGuidanceWithoutLoggedData() {
        let workout = LiveWorkout(name: "Planned Climb", workoutType: .climbing, focusAreas: ["Climbing"])
        workout.startedAt = Date().addingTimeInterval(-1_800)
        workout.completedAt = Date()
        let entry = LiveWorkoutEntry(
            exerciseName: "Limit Bouldering",
            orderIndex: 0,
            exerciseType: "activity"
        )
        entry.activityTypeName = "Bouldering"
        entry.targetTags = ["Climbing"]
        entry.sourcePlanBlockID = UUID()
        entry.plannedDurationSeconds = 1_800
        workout.entries = [entry]

        let frequencyGoal = WorkoutGoal(
            title: "Climb weekly",
            goalKind: .frequency,
            linkedActivityTags: ["Climbing"],
            targetValue: 1,
            targetUnit: "session",
            periodUnit: .week,
            periodCount: 1,
            successCriteria: "You log one climbing session this week."
        )
        let durationGoal = WorkoutGoal(
            title: "Climb 30 minutes",
            goalKind: .duration,
            linkedActivityTags: ["Climbing"],
            targetValue: 30,
            targetUnit: "min",
            periodUnit: .week,
            periodCount: 1,
            successCriteria: "You log 30 minutes of climbing this week."
        )

        XCTAssertTrue(frequencyGoal.matches(workout: workout))
        XCTAssertTrue(frequencyGoal.matches(entry: entry))
        XCTAssertFalse(entry.hasExercisePreferenceSignal)
        XCTAssertTrue(WorkoutGoalProgressResolver.matchingCompletedWorkouts(for: frequencyGoal, in: [workout]).isEmpty)
        XCTAssertTrue(WorkoutGoalProgressResolver.matchingCompletedWorkouts(for: durationGoal, in: [workout]).isEmpty)
    }

    func testActivityScopedGoalIgnoresUnloggedPlannedActivityWithoutPlanBlockID() {
        let workout = LiveWorkout(name: "Strength + Climb", workoutType: .mixed, focusAreas: ["Climbing"])
        workout.completedAt = Date()
        let strengthEntry = LiveWorkoutEntry(exerciseName: "Back Squat", orderIndex: 0)
        strengthEntry.addSet(LiveWorkoutEntry.SetData(reps: 5, weight: .zero, completed: true))
        let plannedActivity = LiveWorkoutEntry(
            exerciseName: "Limit Bouldering",
            orderIndex: 1,
            exerciseType: "skill"
        )
        plannedActivity.activityTypeName = "Bouldering"
        plannedActivity.targetTags = ["Climbing"]
        plannedActivity.plannedDurationSeconds = 1_800
        workout.entries = [strengthEntry, plannedActivity]

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
        XCTAssertTrue(goal.matches(entry: plannedActivity))
        XCTAssertFalse(plannedActivity.hasExercisePreferenceSignal)
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

    func testActivityScopedGoalsNormalizeSpacingAndPunctuation() {
        let entry = LiveWorkoutEntry(
            exerciseName: "Mobility Flow",
            orderIndex: 0,
            exerciseType: "mobility"
        )
        entry.activityTypeName = "Mobility Flow"
        entry.targetTags = ["Hip Mobility", "Warm-Up"]
        entry.durationSeconds = 900
        entry.completedAt = Date()

        let goal = WorkoutGoal(
            title: "Keep mobility consistent",
            goalKind: .frequency,
            linkedActivityName: "mobility-flow",
            linkedActivityTags: ["warm_up"],
            targetValue: 3,
            targetUnit: "sessions",
            periodUnit: .week,
            periodCount: 1,
            successCriteria: "You complete three mobility entries this week."
        )

        XCTAssertTrue(goal.matches(entry: entry))
        XCTAssertEqual("Mobility Flow".goalNormalizedKey, "mobility-flow".goalNormalizedKey)
        XCTAssertEqual("Warm-Up".goalNormalizedKey, "warm_up".goalNormalizedKey)
    }

    func testActivityKindOnlyGoalsMatchWorkoutAndImportedSessions() {
        let workout = LiveWorkout(
            name: "Mixed recovery day",
            workoutType: .mixed,
            focusAreas: ["Mobility"]
        )
        workout.completedAt = Date()

        let importedSession = WorkoutSession(
            healthKitWorkoutID: "yoga-1",
            workoutType: "yoga",
            durationMinutes: 25,
            caloriesBurned: nil,
            distanceMeters: nil,
            loggedAt: Date()
        )

        let goal = WorkoutGoal(
            title: "Keep mobility work consistent",
            goalKind: .frequency,
            linkedActivityKind: .mobility,
            targetValue: 1,
            targetUnit: "sessions",
            periodUnit: .week,
            periodCount: 1,
            successCriteria: "You complete one mobility-focused session this week."
        )

        XCTAssertTrue(goal.matches(workout: workout))
        XCTAssertTrue(goal.matches(session: importedSession))
    }

    func testGoalScopeSummaryHidesPlacementWhenActivityIdentityIsPresent() {
        let taggedGoal = WorkoutGoal(
            title: "Complete support work",
            goalKind: .frequency,
            linkedActivityTags: ["Cardio support"],
            linkedActivityRole: .accessory,
            targetValue: 1,
            targetUnit: "sessions",
            periodUnit: .week,
            periodCount: 1,
            successCriteria: "You log one cardio support entry this week."
        )

        let roleOnlyGoal = WorkoutGoal(
            title: "Complete support work",
            goalKind: .frequency,
            linkedActivityRole: .accessory,
            targetValue: 1,
            targetUnit: "sessions",
            periodUnit: .week,
            periodCount: 1,
            successCriteria: "You log one support entry this week."
        )

        XCTAssertEqual(taggedGoal.scopeSummary, "Cardio support")
        XCTAssertEqual(roleOnlyGoal.scopeSummary, "Support work")
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

    func testNamedActivityTargetCanDriveSuggestionsWithoutBroadCategory() throws {
        container = try ModelContainer(
            for: LiveWorkout.self,
            LiveWorkoutEntry.self,
            Exercise.self,
            ExerciseHistory.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        context = ModelContext(container)

        let dance = Exercise(name: "Footwork Flow", category: .custom)
        dance.activityTypeName = "Dance"
        dance.targetTags = ["Footwork", "Rhythm"]
        dance.trackingFields = [.duration, .reps, .notes]
        context.insert(dance)

        let unrelated = Exercise(name: "Running", category: .cardio)
        context.insert(unrelated)

        let workout = LiveWorkout(
            name: "Dance Practice",
            workoutType: .mixed,
            focusAreas: ["Dance"]
        )
        let viewModel = LiveWorkoutViewModel(workout: workout)
        viewModel.debugRebuildSuggestionPoolForTests(modelContext: context)

        XCTAssertTrue(viewModel.availableSuggestions.contains { $0.exerciseName == "Footwork Flow" })
        XCTAssertFalse(viewModel.availableSuggestions.contains { $0.exerciseName == "Running" })
    }

    func testClimbingWorkoutSuggestionsIncludeSportPracticeExercises() throws {
        container = try ModelContainer(
            for: LiveWorkout.self,
            LiveWorkoutEntry.self,
            Exercise.self,
            ExerciseHistory.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        context = ModelContext(container)

        let bouldering = Exercise(name: "Bouldering", category: .sportPractice)
        bouldering.activityTypeName = "Bouldering"
        bouldering.targetTags = ["Climbing"]
        context.insert(bouldering)

        let running = Exercise(name: "Running", category: .cardio)
        context.insert(running)

        let workout = LiveWorkout(
            name: "Climbing Session",
            workoutType: .climbing
        )
        let viewModel = LiveWorkoutViewModel(workout: workout)
        viewModel.debugRebuildSuggestionPoolForTests(modelContext: context)

        XCTAssertTrue(viewModel.availableSuggestions.contains { $0.exerciseName == "Bouldering" && $0.category == .sportPractice })
        XCTAssertFalse(viewModel.availableSuggestions.contains { $0.exerciseName == "Running" })
    }

    func testActivityTypeTargetsPreserveBroadActivityTargets() {
        let workout = LiveWorkout(
            name: "Mixed",
            workoutType: .mixed,
            focusAreas: ["cardio"]
        )
        let viewModel = LiveWorkoutViewModel(workout: workout)

        viewModel.updateActivityTypeTargets(["Padel"])

        XCTAssertEqual(viewModel.workout.focusAreas, ["cardio", "Padel"])
        XCTAssertEqual(viewModel.targetActivityCategories, [.cardio])
        XCTAssertEqual(viewModel.targetActivityTypes, ["Padel"])
    }

    func testSpecificActivityTypeTargetKeepsUserFacingName() {
        let workout = LiveWorkout(
            name: "Mixed",
            workoutType: .mixed
        )
        let viewModel = LiveWorkoutViewModel(workout: workout)

        viewModel.updateActivityTypeTargets(["Climbing"])

        XCTAssertEqual(viewModel.workout.focusAreas, ["Climbing"])
        XCTAssertEqual(viewModel.targetActivityCategories, [])
        XCTAssertEqual(viewModel.targetActivityTypes, ["Climbing"])
    }

    func testBroadActivityTargetsPreserveSelectedActivityTypes() {
        let workout = LiveWorkout(
            name: "Mixed",
            workoutType: .mixed,
            focusAreas: ["Padel"]
        )
        let viewModel = LiveWorkoutViewModel(workout: workout)

        viewModel.updateActivityTargets([.cardio])

        XCTAssertEqual(viewModel.workout.focusAreas, ["Padel", "Cardio"])
        XCTAssertEqual(viewModel.targetActivityCategories, [.cardio])
        XCTAssertEqual(viewModel.targetActivityTypes, ["Padel"])
    }

    func testPlanTargetPreservesSpecificActivityTypes() {
        let workout = LiveWorkout(name: "Custom Workout", workoutType: .mixed)
        let viewModel = LiveWorkoutViewModel(workout: workout)

        viewModel.applyPlanTarget(
            name: "Climb + Conditioning",
            muscles: [],
            categories: [.sportPractice, .conditioning],
            activityTypes: ["Bouldering", "Sled Push"]
        )

        XCTAssertTrue(viewModel.workout.focusAreas.contains("Conditioning"))
        XCTAssertTrue(viewModel.workout.focusAreas.contains("Sport"))
        XCTAssertFalse(viewModel.workout.focusAreas.contains("skill"))
        XCTAssertFalse(viewModel.workout.focusAreas.contains("sportPractice"))
        XCTAssertEqual(viewModel.workout.focusAreas.suffix(2), ["Bouldering", "Sled Push"])
        XCTAssertEqual(viewModel.targetActivityCategories, [.conditioning, .sportPractice])
        XCTAssertEqual(viewModel.targetActivityTypes, ["Bouldering", "Sled Push"])
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

    func testGoalRecommendationContextUsesActivityKindForSupportBlockMetrics() {
        let workout = LiveWorkout(
            name: "Climb Support",
            workoutType: .mixed,
            focusAreas: ["Bouldering"]
        )
        workout.completedAt = Date()
        let entry = LiveWorkoutEntry(
            exerciseName: "Limit Bouldering",
            orderIndex: 0,
            exerciseType: "activity"
        )
        entry.activityKind = .sportPractice
        entry.activityTypeName = "Bouldering"
        entry.activitySegments = [
            LiveWorkoutEntry.ActivitySegment(reps: 2),
            LiveWorkoutEntry.ActivitySegment(reps: 4)
        ]
        workout.entries = [entry]

        let summaries = WorkoutGoalRecommendationContextBuilder.recentSessionSummaries(
            workouts: [workout],
            sessions: []
        )

        let summary = summaries.joined(separator: " ")
        XCTAssertTrue(summary.contains("6 attempts"))
        XCTAssertFalse(summary.contains("6 counts"))
    }

    func testCustomActivityGoalContextUsesRepsInsteadOfGenericCounts() {
        let workout = LiveWorkout(
            name: "Custom Practice",
            workoutType: .mixed,
            focusAreas: ["Footwork"]
        )
        workout.completedAt = Date()
        let entry = LiveWorkoutEntry(
            exerciseName: "Footwork Drill",
            orderIndex: 0,
            exerciseType: "activity"
        )
        entry.activityKind = .custom
        entry.activityTypeName = "Footwork"
        entry.trackingFields = [.duration, .reps, .notes]
        entry.activitySegments = [
            LiveWorkoutEntry.ActivitySegment(reps: 3),
            LiveWorkoutEntry.ActivitySegment(reps: 4)
        ]
        workout.entries = [entry]

        let summaries = WorkoutGoalRecommendationContextBuilder.recentSessionSummaries(
            workouts: [workout],
            sessions: []
        )

        let summary = summaries.joined(separator: " ")
        XCTAssertTrue(summary.contains("7 reps"))
        XCTAssertFalse(summary.contains("7 counts"))
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
