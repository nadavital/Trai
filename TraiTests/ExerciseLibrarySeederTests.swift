import SwiftData
import XCTest
@testable import Trai

@MainActor
final class ExerciseLibrarySeederTests: XCTestCase {
    func testExercisePhotoAnalysisCanDecodeCategoryTargetsAndTrackingFields() throws {
        let json = """
        {
          "equipmentName": "Rowing Machine",
          "description": "A cardio machine for rowing intervals.",
          "tips": "Keep the stroke smooth.",
          "suggestedExercises": [
            {
              "name": "Rowing",
              "category": "cardio",
              "muscleGroup": null,
              "targetTags": ["Intervals", "Endurance"],
              "trackingFields": ["duration", "distance", "notes"],
              "howTo": "Use a steady drive and controlled recovery."
            }
          ]
        }
        """.data(using: .utf8)!

        let analysis = try JSONDecoder().decode(ExercisePhotoAnalysis.self, from: json)
        let exercise = try XCTUnwrap(analysis.suggestedExercises.first)

        XCTAssertEqual(exercise.category, "cardio")
        XCTAssertNil(exercise.muscleGroup)
        XCTAssertEqual(exercise.targetTags ?? [], ["Intervals", "Endurance"])
        XCTAssertEqual(exercise.trackingFields ?? [], ["duration", "distance", "notes"])
    }

    func testTrackingFieldNormalizationKeepsRowsScannable() {
        XCTAssertEqual(
            Exercise.normalizedTrackingFields([.duration, .distance, .reps, .weight, .notes], for: .conditioning),
            [.duration, .distance, .reps, .notes]
        )
        XCTAssertEqual(
            Exercise.normalizedTrackingFields([.duration, .reps, .weight], for: .cardio),
            [.duration]
        )
        XCTAssertEqual(
            Exercise.normalizedTrackingFields([.sets, .weight, .reps, .duration, .notes], for: .strength),
            [.sets, .weight, .reps, .notes]
        )
    }

    func testHiddenStablePrimitivesMapToVisibleTrackingStyles() {
        XCTAssertEqual(Exercise.Category.skill.userFacingEquivalent, .sportPractice)
        XCTAssertEqual(Exercise.Category.flexibility.userFacingEquivalent, .mobility)
        XCTAssertTrue(Exercise.Category.sportPractice.suggestionCategories.contains(.skill))
        XCTAssertTrue(Exercise.Category.mobility.suggestionCategories.contains(.flexibility))
    }

    func testExerciseCategoryNormalizationAcceptsUserFacingActivityNames() {
        XCTAssertEqual(Exercise.Category.normalized(from: "sport"), .sportPractice)
        XCTAssertEqual(Exercise.Category.normalized(from: "sport practice"), .sportPractice)
        XCTAssertEqual(Exercise.Category.normalized(from: "climbing"), .sportPractice)
        XCTAssertEqual(Exercise.Category.normalized(from: "yoga"), .mobility)
        XCTAssertEqual(Exercise.Category.normalized(from: "activity"), .custom)

        let hiddenPrimitive = Exercise(name: "Limit Bouldering", category: .skill)
        XCTAssertEqual(hiddenPrimitive.exerciseCategory, .skill)

        let userFacingCategory = Exercise(name: "Padel", category: "sport")
        XCTAssertEqual(userFacingCategory.exerciseCategory, .sportPractice)
    }

    func testEnsureDefaultsSeedsBroadExerciseLibraryOnce() throws {
        let container = try ModelContainer(
            for: Exercise.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)

        let inserted = ExerciseLibrarySeeder.ensureDefaults(in: context)
        let secondPassInserted = ExerciseLibrarySeeder.ensureDefaults(in: context)
        let exercises = try context.fetch(FetchDescriptor<Exercise>())
        let names = Set(exercises.map(\.name))

        XCTAssertGreaterThan(inserted, 0)
        XCTAssertEqual(secondPassInserted, 0)
        XCTAssertTrue(names.contains("Bench Press"))
        XCTAssertTrue(names.contains("Running"))
        XCTAssertTrue(names.contains("Hip Mobility Flow"))
        XCTAssertTrue(names.contains("Bouldering"))
        XCTAssertEqual(exercises.filter { $0.name == "Running" }.count, 1)

        let running = try XCTUnwrap(exercises.first { $0.name == "Running" })
        XCTAssertEqual(running.exerciseCategory, .cardio)
        XCTAssertEqual(running.trackingFields, [.duration, .distance])
        XCTAssertTrue(running.targetTags.isEmpty)

        let mobility = try XCTUnwrap(exercises.first { $0.name == "Hip Mobility Flow" })
        XCTAssertEqual(mobility.exerciseCategory, .mobility)
        XCTAssertEqual(mobility.trackingFields, [.duration, .notes])
        XCTAssertTrue(mobility.targetTags.isEmpty)
    }
}
