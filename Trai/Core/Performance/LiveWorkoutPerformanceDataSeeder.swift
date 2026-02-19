//
//  LiveWorkoutPerformanceDataSeeder.swift
//  Trai
//
//  Deterministic synthetic data seeding for on-device live-workout profiling.
//

import Foundation
import SwiftData

struct LiveWorkoutPerformanceDataSeeder {
    struct Configuration {
        var runIdentifier: String
        var workoutCount: Int
        var activeWorkoutCount: Int
        var exercisesPerWorkout: Int
        var setsPerExercise: Int
        var baseSeed: UInt64
        var startDate: Date
        var clearExistingForRunIdentifier: Bool

        nonisolated static let defaultHeavyDeviceProfile = Configuration(
            runIdentifier: "device-heavy",
            workoutCount: 260,
            activeWorkoutCount: 1,
            exercisesPerWorkout: 6,
            setsPerExercise: 5,
            baseSeed: 73_421,
            startDate: Date(timeIntervalSince1970: 1_720_000_000),
            clearExistingForRunIdentifier: true
        )
    }

    struct Summary: Equatable {
        let runIdentifier: String
        let totalWorkoutsInserted: Int
        let activeWorkouts: Int
        let completedWorkouts: Int
        let totalEntriesInserted: Int
        let totalSetsInserted: Int
    }

    enum SeederError: LocalizedError {
        case invalidConfiguration(String)

        var errorDescription: String? {
            switch self {
            case .invalidConfiguration(let reason):
                return "Invalid seeder configuration: \(reason)"
            }
        }
    }

    private let exerciseCatalog: [String] = [
        "Bench Press", "Incline Dumbbell Press", "Cable Fly",
        "Overhead Press", "Lateral Raise", "Rear Delt Fly",
        "Lat Pulldown", "Seated Cable Row", "Pull-Up",
        "Barbell Row", "Biceps Curl", "Hammer Curl",
        "Triceps Pushdown", "Overhead Triceps Extension",
        "Back Squat", "Front Squat", "Leg Press",
        "Romanian Deadlift", "Leg Curl", "Leg Extension",
        "Bulgarian Split Squat", "Hip Thrust", "Calf Raise",
        "Cable Crunch", "Plank"
    ]

    @MainActor
    @discardableResult
    func seed(
        modelContext: ModelContext,
        configuration: Configuration = .defaultHeavyDeviceProfile
    ) throws -> Summary {
        try validate(configuration: configuration)

        if configuration.clearExistingForRunIdentifier {
            try clearExistingSeedData(modelContext: modelContext, runIdentifier: configuration.runIdentifier)
        }

        var generator = SeededGenerator(seed: configuration.baseSeed)

        let activeStartIndex = configuration.workoutCount - configuration.activeWorkoutCount
        var totalEntriesInserted = 0
        var totalSetsInserted = 0

        for workoutIndex in 0..<configuration.workoutCount {
            let isActive = workoutIndex >= activeStartIndex
            let workout = buildWorkout(
                workoutIndex: workoutIndex,
                isActive: isActive,
                configuration: configuration,
                generator: &generator
            )

            var workoutEntries: [LiveWorkoutEntry] = []
            workoutEntries.reserveCapacity(configuration.exercisesPerWorkout)

            for exerciseIndex in 0..<configuration.exercisesPerWorkout {
                let entry = buildEntry(
                    workoutIndex: workoutIndex,
                    exerciseIndex: exerciseIndex,
                    exercisesPerWorkout: configuration.exercisesPerWorkout,
                    isActiveWorkout: isActive,
                    setsPerExercise: configuration.setsPerExercise,
                    generator: &generator
                )
                entry.workout = workout
                workoutEntries.append(entry)

                totalEntriesInserted += 1
                totalSetsInserted += entry.sets.count

                if !isActive {
                    let history = ExerciseHistory(from: entry, performedAt: workout.completedAt ?? workout.startedAt)
                    modelContext.insert(history)
                }
            }

            workout.entries = workoutEntries
            modelContext.insert(workout)
        }

        try modelContext.save()

        return Summary(
            runIdentifier: configuration.runIdentifier,
            totalWorkoutsInserted: configuration.workoutCount,
            activeWorkouts: configuration.activeWorkoutCount,
            completedWorkouts: configuration.workoutCount - configuration.activeWorkoutCount,
            totalEntriesInserted: totalEntriesInserted,
            totalSetsInserted: totalSetsInserted
        )
    }

    @MainActor
    private func clearExistingSeedData(modelContext: ModelContext, runIdentifier: String) throws {
        let marker = seedMarker(for: runIdentifier)
        let workoutDescriptor = FetchDescriptor<LiveWorkout>()
        let allWorkouts = try modelContext.fetch(workoutDescriptor)
        let workoutsToDelete = allWorkouts.filter { $0.notes.contains(marker) }
        guard !workoutsToDelete.isEmpty else { return }

        var seededEntryIDs: Set<UUID> = []
        for workout in workoutsToDelete {
            for entry in workout.entries ?? [] {
                seededEntryIDs.insert(entry.id)
            }
            modelContext.delete(workout)
        }

        if !seededEntryIDs.isEmpty {
            let historyDescriptor = FetchDescriptor<ExerciseHistory>()
            let allHistory = try modelContext.fetch(historyDescriptor)
            for history in allHistory {
                guard let sourceWorkoutEntryId = history.sourceWorkoutEntryId else { continue }
                if seededEntryIDs.contains(sourceWorkoutEntryId) {
                    modelContext.delete(history)
                }
            }
        }

        try modelContext.save()
    }

    private func buildWorkout(
        workoutIndex: Int,
        isActive: Bool,
        configuration: Configuration,
        generator: inout SeededGenerator
    ) -> LiveWorkout {
        let workout = LiveWorkout()
        workout.name = "Perf \(workoutIndex + 1)"
        workout.type = .strength
        workout.notes = "\(seedMarker(for: configuration.runIdentifier)) index=\(workoutIndex)"

        let dayOffset = workoutIndex / 2
        let hourOffset = (workoutIndex % 2 == 0) ? 7 : 18
        let minuteJitter = Int(generator.next() % 25)
        let startedAt = Calendar.current.date(
            byAdding: .day,
            value: dayOffset,
            to: configuration.startDate
        )?.addingTimeInterval(TimeInterval((hourOffset * 3600) + (minuteJitter * 60)))
            ?? configuration.startDate
        workout.startedAt = startedAt

        if !isActive {
            let durationMinutes = 38 + Int(generator.next() % 37)
            workout.completedAt = startedAt.addingTimeInterval(TimeInterval(durationMinutes * 60))
        } else {
            workout.completedAt = nil
        }

        let targetMuscles = randomTargetMuscles(generator: &generator)
        workout.muscleGroups = targetMuscles
        return workout
    }

    private func buildEntry(
        workoutIndex: Int,
        exerciseIndex: Int,
        exercisesPerWorkout: Int,
        isActiveWorkout: Bool,
        setsPerExercise: Int,
        generator: inout SeededGenerator
    ) -> LiveWorkoutEntry {
        let exerciseNameIndex = (workoutIndex * 5 + exerciseIndex * 3 + Int(generator.next() % 7)) % exerciseCatalog.count
        let entry = LiveWorkoutEntry(
            exerciseName: exerciseCatalog[exerciseNameIndex],
            orderIndex: exerciseIndex,
            exerciseType: "strength"
        )

        let baseWeightKg = 20 + Double((workoutIndex + exerciseIndex) % 7) * 5 + Double(generator.next() % 5)

        for setIndex in 0..<setsPerExercise {
            let shouldLeaveIncomplete = isActiveWorkout
                && exerciseIndex == max(0, exercisesPerWorkout - 1)
                && setIndex == setsPerExercise - 1

            let reps = shouldLeaveIncomplete ? 0 : max(4, 12 - (setIndex % 3) - Int(generator.next() % 2))
            let weightKg = shouldLeaveIncomplete ? 0 : baseWeightKg + Double(setIndex) * 2.5
            let set = LiveWorkoutEntry.SetData(
                reps: reps,
                weight: WeightUtility.cleanWeightFromKg(weightKg),
                completed: !shouldLeaveIncomplete,
                isWarmup: setIndex == 0 && generator.next() % 4 == 0
            )
            entry.addSet(set)
        }

        return entry
    }

    private func randomTargetMuscles(generator: inout SeededGenerator) -> [LiveWorkout.MuscleGroup] {
        let pools: [[LiveWorkout.MuscleGroup]] = [
            [.chest, .shoulders, .triceps],
            [.back, .biceps, .forearms],
            [.quads, .hamstrings, .glutes, .calves],
            [.core, .shoulders, .back],
            [.fullBody]
        ]
        let index = Int(generator.next() % UInt64(pools.count))
        return pools[index]
    }

    private func validate(configuration: Configuration) throws {
        if configuration.workoutCount <= 0 {
            throw SeederError.invalidConfiguration("workoutCount must be > 0")
        }
        if configuration.exercisesPerWorkout <= 0 {
            throw SeederError.invalidConfiguration("exercisesPerWorkout must be > 0")
        }
        if configuration.setsPerExercise <= 0 {
            throw SeederError.invalidConfiguration("setsPerExercise must be > 0")
        }
        if configuration.activeWorkoutCount < 0 || configuration.activeWorkoutCount > configuration.workoutCount {
            throw SeederError.invalidConfiguration("activeWorkoutCount must be between 0 and workoutCount")
        }
        if configuration.runIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw SeederError.invalidConfiguration("runIdentifier must not be empty")
        }
    }

    private func seedMarker(for runIdentifier: String) -> String {
        "[PerfSeed:\(runIdentifier)]"
    }
}

private struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 0xFEED_FACE_CAFE_BEEF : seed
    }

    mutating func next() -> UInt64 {
        state = 6_364_136_223_846_793_005 &* state &+ 1_442_695_040_888_963_407
        return state
    }
}
