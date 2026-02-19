import XCTest
import SwiftData
@testable import Trai

@MainActor
final class LiveWorkoutPerformanceDataSeederTests: XCTestCase {
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

    func testSeedDeterministicWorkoutCountAndEntryShape() throws {
        let seeder = LiveWorkoutPerformanceDataSeeder()
        let config = LiveWorkoutPerformanceDataSeeder.Configuration(
            runIdentifier: "unit-deterministic",
            workoutCount: 24,
            activeWorkoutCount: 3,
            exercisesPerWorkout: 4,
            setsPerExercise: 5,
            baseSeed: 42,
            startDate: Date(timeIntervalSince1970: 1_735_689_600),
            clearExistingForRunIdentifier: true
        )

        let summary = try seeder.seed(modelContext: context, configuration: config)

        let workouts = try context.fetch(FetchDescriptor<LiveWorkout>())
        let allEntries = workouts.flatMap { $0.entries ?? [] }

        XCTAssertEqual(summary.totalWorkoutsInserted, config.workoutCount)
        XCTAssertEqual(workouts.count, config.workoutCount)
        XCTAssertTrue(workouts.allSatisfy { ($0.entries ?? []).count == config.exercisesPerWorkout })
        XCTAssertTrue(allEntries.allSatisfy { $0.sets.count == config.setsPerExercise })
        XCTAssertEqual(summary.totalEntriesInserted, config.workoutCount * config.exercisesPerWorkout)
    }

    func testSeedGeneratesCompletedAndActiveWorkoutMix() throws {
        let seeder = LiveWorkoutPerformanceDataSeeder()
        let config = LiveWorkoutPerformanceDataSeeder.Configuration(
            runIdentifier: "unit-mix",
            workoutCount: 30,
            activeWorkoutCount: 4,
            exercisesPerWorkout: 3,
            setsPerExercise: 4,
            baseSeed: 7,
            startDate: Date(timeIntervalSince1970: 1_735_689_600),
            clearExistingForRunIdentifier: true
        )

        let summary = try seeder.seed(modelContext: context, configuration: config)
        let workouts = try context.fetch(FetchDescriptor<LiveWorkout>())
        let completed = workouts.filter { $0.completedAt != nil }
        let active = workouts.filter { $0.completedAt == nil }
        let history = try context.fetch(FetchDescriptor<ExerciseHistory>())

        XCTAssertEqual(summary.completedWorkouts, config.workoutCount - config.activeWorkoutCount)
        XCTAssertEqual(summary.activeWorkouts, config.activeWorkoutCount)
        XCTAssertEqual(completed.count, config.workoutCount - config.activeWorkoutCount)
        XCTAssertEqual(active.count, config.activeWorkoutCount)
        XCTAssertFalse(history.isEmpty)
    }
}
