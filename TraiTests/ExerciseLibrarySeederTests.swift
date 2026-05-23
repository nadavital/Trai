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

    func testExercisePhotoAnalysisCanDecodeActivitySetupSuggestions() throws {
        let json = """
        {
          "equipmentName": "Climbing Wall",
          "description": "A visible climbing setup for bouldering practice.",
          "tips": "Warm up fingers and shoulders before hard attempts.",
          "suggestedExercises": [
            {
              "name": "Limit Bouldering",
              "category": "sportPractice",
              "activityTypeName": "Climbing",
              "activityAliases": ["Bouldering", "Climb"],
              "muscleGroup": null,
              "targetTags": ["Technique", "Power", "Grip"],
              "trackingFields": ["duration", "reps", "notes"],
              "howTo": "Track focused attempts and note the problem style."
            }
          ]
        }
        """.data(using: .utf8)!

        let analysis = try JSONDecoder().decode(ExercisePhotoAnalysis.self, from: json)
        let exercise = try XCTUnwrap(analysis.suggestedExercises.first)

        XCTAssertEqual(analysis.equipmentName, "Climbing Wall")
        XCTAssertEqual(exercise.category, "sportPractice")
        XCTAssertEqual(exercise.activityTypeName, "Climbing")
        XCTAssertEqual(exercise.activityAliases ?? [], ["Bouldering", "Climb"])
        XCTAssertEqual(exercise.targetTags ?? [], ["Technique", "Power", "Grip"])
        XCTAssertEqual(exercise.trackingFields ?? [], ["duration", "reps", "notes"])
    }

    func testTrackingFieldNormalizationPreservesSelectedMetrics() {
        XCTAssertEqual(
            Exercise.normalizedTrackingFields([.duration, .distance, .reps, .weight, .notes], for: .conditioning),
            [.duration, .distance, .reps, .weight, .notes]
        )
        XCTAssertEqual(
            Exercise.normalizedTrackingFields([.duration, .reps, .weight], for: .cardio),
            [.duration, .reps, .weight]
        )
        XCTAssertEqual(
            Exercise.normalizedTrackingFields([.sets, .weight, .reps, .duration, .notes], for: .strength),
            [.sets, .weight, .reps, .notes]
        )
    }

    func testNonStrengthTrackingFieldsAreUserConfigurableAcrossCategories() {
        XCTAssertEqual(
            Exercise.trackingFieldOptions(for: .cardio),
            [.sets, .reps, .weight, .duration, .distance, .notes]
        )
        XCTAssertEqual(
            Exercise.trackingFieldOptions(for: .sportPractice),
            [.sets, .reps, .weight, .duration, .distance, .notes]
        )
        XCTAssertEqual(
            Exercise.trackingFieldOptions(for: .mobility),
            [.sets, .reps, .weight, .duration, .distance, .notes]
        )
        XCTAssertEqual(
            Exercise.normalizedTrackingFields([.duration, .distance, .weight, .notes], for: .sportPractice),
            [.duration, .distance, .weight, .notes]
        )
    }

    func testExerciseTrackingFieldsDoNotExposeManualCalories() {
        XCTAssertFalse(Exercise.TrackingField.allCases.map(\.rawValue).contains("calories"))

        let exercise = Exercise(name: "Cycling", category: .cardio)
        exercise.trackingFieldsRaw = "duration,calories,distance,notes"

        XCTAssertEqual(exercise.trackingFields, [.duration, .distance, .notes])
        XCTAssertEqual(
            Exercise.trackingFieldOptions(for: .cardio),
            [.sets, .reps, .weight, .duration, .distance, .notes]
        )
    }

    func testHiddenStablePrimitivesMapToVisibleTrackingStyles() {
        XCTAssertEqual(Exercise.Category.skill.userFacingEquivalent, .sportPractice)
        XCTAssertEqual(Exercise.Category.flexibility.userFacingEquivalent, .mobility)
        XCTAssertTrue(Exercise.Category.sportPractice.suggestionCategories.contains(.skill))
        XCTAssertTrue(Exercise.Category.mobility.suggestionCategories.contains(.flexibility))
        XCTAssertEqual(Exercise.Category.sportPractice.trackingTemplateName, "Attempts")
        XCTAssertEqual(Exercise.Category.cardio.trackingTemplateName, "Timed distance")
    }

    func testCustomTargetsStayOutcomeBasedInsteadOfBroadCategories() {
        XCTAssertEqual(
            Exercise.targetOptions(for: .custom),
            ["Technique", "Endurance", "Power", "Speed", "Consistency", "Control"]
        )
        XCTAssertFalse(Exercise.targetOptions(for: .custom).contains("Cardio"))
        XCTAssertFalse(Exercise.targetOptions(for: .custom).contains("Sport"))
    }

    func testExerciseCategoryNormalizationAcceptsUserFacingActivityNames() {
        XCTAssertEqual(Exercise.Category.normalized(from: "sport"), .sportPractice)
        XCTAssertEqual(Exercise.Category.normalized(from: "sport practice"), .sportPractice)
        XCTAssertEqual(Exercise.Category.normalized(from: "climbing"), .sportPractice)
        XCTAssertEqual(Exercise.Category.normalized(from: "Outdoor Run"), .cardio)
        XCTAssertEqual(Exercise.Category.normalized(from: "Padel drills"), .sportPractice)
        XCTAssertEqual(Exercise.Category.normalized(from: "yoga"), .mobility)
        XCTAssertEqual(Exercise.Category.normalized(from: "activity"), .custom)
        XCTAssertNil(Exercise.Category.normalized(from: "Cable Row"))
        XCTAssertEqual(Exercise.defaultActivityTypeName(for: "Padel drills", category: .sportPractice), "Padel")
        XCTAssertEqual(Exercise.defaultActivityTypeName(for: "Seated Cable Row", category: .strength), "Strength")

        let hiddenPrimitive = Exercise(name: "Limit Bouldering", category: .skill)
        XCTAssertEqual(hiddenPrimitive.exerciseCategory, .skill)

        let userFacingCategory = Exercise(name: "Padel", category: "sport")
        XCTAssertEqual(userFacingCategory.exerciseCategory, .sportPractice)

        let liveEntry = LiveWorkoutEntry(exerciseName: "Padel", orderIndex: 0, exerciseType: "sport")
        XCTAssertEqual(liveEntry.trackingFields, [.duration, .reps, .notes])
    }

    func testRepCountActivitySessionDoesNotBecomeStrength() {
        let exercise = Exercise(name: "Limit Bouldering", category: .sportPractice)
        exercise.activityTypeName = "Climbing"
        exercise.targetTags = ["Power", "Technique"]

        let session = WorkoutSession(exercise: exercise, sets: 2, reps: 8, weightKg: 20)
        session.durationMinutes = 45

        XCTAssertFalse(session.isStrengthTraining)
        XCTAssertEqual(session.displayTypeName, "Climbing")
        XCTAssertEqual(session.inferredWorkoutMode, .climbing)
        XCTAssertNil(session.totalVolume)
        XCTAssertEqual(session.setMetricLabel, "Segments")
        XCTAssertEqual(session.repMetricLabel, "Attempts")
        XCTAssertEqual(session.setMetricPhrase, "2 segments")
        XCTAssertEqual(session.repMetricPhrase, "8 attempts")
        XCTAssertTrue(session.traiReviewPrompt.contains("2 segments"))
        XCTAssertTrue(session.traiReviewPrompt.contains("8 attempts"))
        XCTAssertFalse(session.traiReviewPrompt.contains("2 sets"))
        XCTAssertFalse(session.traiReviewPrompt.contains("8 reps"))
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
        XCTAssertTrue(names.contains("Seated Cable Row"))
        XCTAssertFalse(names.contains("Rowing Machine"))
        XCTAssertEqual(exercises.filter { $0.name == "Running" }.count, 1)

        let running = try XCTUnwrap(exercises.first { $0.name == "Running" })
        XCTAssertEqual(running.exerciseCategory, .cardio)
        XCTAssertEqual(running.trackingFields, [.duration, .distance])
        XCTAssertTrue(running.targetTags.isEmpty)

        let mobility = try XCTUnwrap(exercises.first { $0.name == "Hip Mobility Flow" })
        XCTAssertEqual(mobility.exerciseCategory, .mobility)
        XCTAssertEqual(mobility.trackingFields, [.duration, .notes])
        XCTAssertTrue(mobility.targetTags.isEmpty)

        let bouldering = try XCTUnwrap(exercises.first { $0.name == "Bouldering" })
        XCTAssertEqual(bouldering.exerciseCategory, .sportPractice)
        XCTAssertEqual(bouldering.activityTypeName, "Climbing")
    }

    func testEnsureDefaultsRenamesLegacyStrengthRowingMachine() throws {
        let container = try ModelContainer(
            for: Exercise.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)

        let legacy = Exercise(name: "Rowing Machine", category: .strength, muscleGroup: .back)
        legacy.isCustom = false
        legacy.equipmentName = "Cable Row Machine"
        context.insert(legacy)
        try context.save()

        _ = ExerciseLibrarySeeder.ensureDefaults(in: context)
        let exercises = try context.fetch(FetchDescriptor<Exercise>())

        XCTAssertNil(exercises.first { $0.name == "Rowing Machine" })
        let renamed = try XCTUnwrap(exercises.first { $0.name == "Seated Cable Row" })
        XCTAssertEqual(renamed.exerciseCategory, .strength)
        XCTAssertEqual(renamed.targetMuscleGroup, .back)
    }
}
