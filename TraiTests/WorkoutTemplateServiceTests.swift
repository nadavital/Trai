import XCTest
import SwiftData
@testable import Trai

@MainActor
final class WorkoutTemplateServiceTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!
    private var service: WorkoutTemplateService!

    override func setUpWithError() throws {
        try super.setUpWithError()
        container = try ModelContainer(
            for: UserProfile.self,
            LiveWorkout.self,
            LiveWorkoutEntry.self,
            ExerciseHistory.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        context = ModelContext(container)
        service = WorkoutTemplateService()
    }

    override func tearDownWithError() throws {
        service = nil
        context = nil
        container = nil
        try super.tearDownWithError()
    }

    func testCreateCustomWorkoutUsesProvidedValues() {
        let workout = service.createCustomWorkout(
            name: "Conditioning Circuit",
            type: .cardio,
            muscles: [.quads, .glutes]
        )

        XCTAssertEqual(workout.name, "Conditioning Circuit")
        XCTAssertEqual(workout.type, .cardio)
        XCTAssertEqual(workout.muscleGroups, [.quads, .glutes])
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

    func testCreateWorkoutForIntentMatchesTemplateByCaseInsensitiveContains() throws {
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

    func testCreateWorkoutForIntentFallsBackToCustomNamedWorkout() {
        let workout = service.createWorkoutForIntent(
            name: "Fight Camp",
            modelContext: context
        )

        XCTAssertEqual(workout.name, "Fight Camp")
        XCTAssertEqual(workout.type, .strength)
        XCTAssertEqual(workout.muscleGroups, [])
    }

    func testCreateWorkoutForIntentCustomCreatesDefaultWorkout() {
        let workout = service.createWorkoutForIntent(
            name: "custom",
            modelContext: context
        )

        XCTAssertEqual(workout.name, "Custom Workout")
        XCTAssertEqual(workout.type, .strength)
        XCTAssertEqual(workout.muscleGroups, [])
    }
}
