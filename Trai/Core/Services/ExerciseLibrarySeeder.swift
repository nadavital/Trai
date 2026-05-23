//
//  ExerciseLibrarySeeder.swift
//  Trai
//

import Foundation
import SwiftData

@MainActor
enum ExerciseLibrarySeeder {
    @discardableResult
    static func ensureDefaults(in modelContext: ModelContext) -> Int {
        let descriptor = FetchDescriptor<Exercise>()
        let existingExercises = (try? modelContext.fetch(descriptor)) ?? []
        var existingByName: [String: Exercise] = [:]
        for exercise in existingExercises {
            let key = exercise.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !key.isEmpty, existingByName[key] == nil else { continue }
            existingByName[key] = exercise
        }
        var insertedCount = 0
        var didMutate = false

        if let legacyRow = existingByName["rowing machine"],
           !legacyRow.isCustom,
           legacyRow.exerciseCategory == .strength,
           legacyRow.muscleGroup == Exercise.MuscleGroup.back.rawValue {
            legacyRow.name = "Seated Cable Row"
            legacyRow.activityTypeName = "Strength"
            existingByName["seated cable row"] = legacyRow
            existingByName["rowing machine"] = nil
            didMutate = true
        }

        if let legacySportRow = existingByName["sport technique"],
           !legacySportRow.isCustom,
           legacySportRow.exerciseCategory.userFacingEquivalent == .sportPractice {
            modelContext.delete(legacySportRow)
            existingByName["sport technique"] = nil
            didMutate = true
        }

        for (name, category, muscleGroup, equipment) in Exercise.defaultExercises {
            let key = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !key.isEmpty else { continue }

            if let existing = existingByName[key] {
                if existing.equipmentName?.isEmpty ?? true, let equipment {
                    existing.equipmentName = equipment
                    didMutate = true
                }
                if existing.muscleGroup?.isEmpty ?? true, let muscleGroup {
                    existing.muscleGroup = muscleGroup
                    didMutate = true
                }
                if existing.trackingFieldsRaw.isEmpty {
                    existing.trackingFields = Exercise.defaultTrackingFields(for: existing.exerciseCategory)
                    didMutate = true
                }
                if existing.targetTagsRaw.isEmpty {
                    existing.targetTags = defaultTargetTags(category: existing.exerciseCategory, muscleGroup: existing.targetMuscleGroup)
                    didMutate = true
                }
                if shouldRefreshDefaultActivityTypeName(for: existing) {
                    existing.activityTypeName = Exercise.defaultActivityTypeName(for: existing.name, category: existing.exerciseCategory)
                    didMutate = true
                }
                continue
            }

            let exercise = Exercise(name: name, category: category, muscleGroup: muscleGroup)
            exercise.equipmentName = equipment
            exercise.isCustom = false
            exercise.activityTypeName = Exercise.defaultActivityTypeName(for: name, category: exercise.exerciseCategory)
            exercise.trackingFields = Exercise.defaultTrackingFields(for: exercise.exerciseCategory)
            exercise.targetTags = defaultTargetTags(category: exercise.exerciseCategory, muscleGroup: exercise.targetMuscleGroup)
            modelContext.insert(exercise)
            existingByName[key] = exercise
            insertedCount += 1
            didMutate = true
        }

        if didMutate {
            try? modelContext.save()
        }

        return insertedCount
    }

    private static func defaultTargetTags(
        category: Exercise.Category,
        muscleGroup: Exercise.MuscleGroup?
    ) -> [String] {
        if category == .strength, let muscleGroup {
            return [muscleGroup.displayName]
        }
        return Exercise.defaultTargetTags(for: category)
    }

    private static func shouldRefreshDefaultActivityTypeName(for exercise: Exercise) -> Bool {
        let current = exercise.activityTypeNameRaw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !current.isEmpty else { return true }
        guard !exercise.isCustom else { return false }

        let category = exercise.exerciseCategory.userFacingEquivalent
        guard category != .strength else { return false }

        let specificDefault = Exercise.defaultActivityTypeName(for: exercise.name, category: exercise.exerciseCategory)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !specificDefault.isEmpty,
              specificDefault.goalNormalizedKey != current.goalNormalizedKey else {
            return false
        }

        let broadDefaultNames = Set(
            Exercise.Category.userFacingCases.flatMap {
                [$0.rawValue, $0.displayName, $0.trackingTemplateName]
            } + [
                exercise.exerciseCategory.rawValue,
                exercise.exerciseCategory.displayName,
                exercise.exerciseCategory.trackingTemplateName,
                category.rawValue,
                category.displayName,
                category.trackingTemplateName,
            ]
        )
        .map(\.goalNormalizedKey)

        return broadDefaultNames.contains(current.goalNormalizedKey)
    }
}
