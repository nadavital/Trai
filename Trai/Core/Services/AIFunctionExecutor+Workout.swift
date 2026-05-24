//
//  AIFunctionExecutor+Workout.swift
//  Trai
//
//  Muscle recovery and workout suggestion function execution
//

import Foundation
import SwiftData

extension AIFunctionExecutor {

    // MARK: - Muscle Recovery

    func executeGetMuscleRecoveryStatus() -> ExecutionResult {
        let recoveryService = MuscleRecoveryService.shared
        let summary = recoveryService.getRecoverySummary(modelContext: modelContext)

        return .dataResponse(FunctionResult(
            name: "get_muscle_recovery_status",
            response: summary
        ))
    }

    // MARK: - Workout Suggestions

    func executeSuggestWorkout(_ args: [String: Any]) -> ExecutionResult {
        let recoveryService = MuscleRecoveryService.shared

        // Get workout preferences from args
        let workoutTypeString = args["workout_type"] as? String
        let requestedActivityFocuses = stringArray(from: args["activity_focuses"])
        let targetMuscleStrings = args["target_muscle_groups"] as? [String] ?? []
        let hasExplicitWorkoutType = workoutTypeString?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty == false
        let workoutType: LiveWorkout.WorkoutType
        if let workoutTypeString, hasExplicitWorkoutType {
            let trimmedWorkoutType = workoutTypeString.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let stableWorkoutType = LiveWorkout.WorkoutType(rawValue: trimmedWorkoutType) else {
                return .dataResponse(FunctionResult(
                    name: "suggest_workout",
                    response: ["error": "workout_type must be a stable workout mode enum. Put user-facing activity names in activity_focuses."]
                ))
            }
            workoutType = stableWorkoutType
        } else {
            workoutType = requestedActivityFocuses.isEmpty ? .strength : .custom
        }
        let durationMinutes = numericInt(from: args["duration_minutes"]) ?? 45

        if !hasExplicitWorkoutType,
           requestedActivityFocuses.isEmpty,
           targetMuscleStrings.isEmpty,
           let planSuggestion = recommendedPlanWorkoutSuggestion(recoveryService: recoveryService) {
            return .suggestedWorkoutStart(planSuggestion)
        }

        if !requestedActivityFocuses.isEmpty || !workoutType.supportsMuscleTargets {
            return .suggestedWorkoutStart(buildActivityWorkoutStartSuggestion(
                workoutType: workoutType,
                activityFocuses: requestedActivityFocuses,
                durationMinutes: durationMinutes
            ))
        }

        // Get target muscles - either from args or from recovery recommendations
        let targetMuscles: [LiveWorkout.MuscleGroup]

        if targetMuscleStrings.isEmpty, requestedActivityFocuses.isEmpty {
            // Use recovery-based recommendations
            targetMuscles = recoveryService.getRecommendedMuscleGroups(modelContext: modelContext)
        } else {
            // Use specified muscles
            targetMuscles = LiveWorkout.MuscleGroup.fromTargetStrings(targetMuscleStrings)
        }

        // Build workout suggestion based on target muscles
        let suggestion = buildWorkoutSuggestion(
            workoutType: workoutType,
            targetMuscles: targetMuscles,
            durationMinutes: durationMinutes
        )

        return .suggestedWorkoutStart(workoutStartSuggestion(from: suggestion))
    }

    private func recommendedPlanWorkoutSuggestion(
        recoveryService: MuscleRecoveryService
    ) -> SuggestedWorkoutEntry? {
        guard let plan = userProfile?.workoutPlan,
              !plan.templates.isEmpty else {
            return nil
        }

        let scoredTemplate = recoveryService.getBestTemplateForToday(
            plan: plan,
            modelContext: modelContext
        )
        let template = scoredTemplate?.template ?? plan.templates.first
        guard let template else { return nil }

        return workoutStartSuggestion(
            from: template,
            recoveryReason: scoredTemplate?.reason
        )
    }

    private func workoutStartSuggestion(
        from template: WorkoutPlan.WorkoutTemplate,
        recoveryReason: String?
    ) -> SuggestedWorkoutEntry {
        let targetMuscles = template.sessionType.supportsMuscleTargets
            ? template.resolvedTargetMuscleGroups
            : []
        let activityFocuses = template.sessionType.supportsMuscleTargets
            ? nil
            : activityFocuses(from: template)
        let exercises = suggestedStartExercises(from: template)
        let reason = recoveryReason?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty
        let rationale = reason.map { "Recommended from your plan: \($0)." }
            ?? "Recommended from your workout plan."

        return SuggestedWorkoutEntry(
            name: template.name,
            workoutType: template.sessionType.rawValue,
            targetMuscleGroups: targetMuscles,
            activityFocuses: activityFocuses,
            exercises: exercises,
            sourcePlanTemplateID: template.id,
            durationMinutes: template.estimatedDurationMinutes,
            rationale: rationale
        )
    }

    private func workoutStartSuggestion(from suggestion: WorkoutSuggestion) -> SuggestedWorkoutEntry {
        SuggestedWorkoutEntry(
            name: suggestion.name,
            workoutType: suggestion.workoutType.rawValue,
            targetMuscleGroups: suggestion.targetMuscleGroups.map(\.rawValue),
            exercises: suggestion.exercises.map { exercise in
                SuggestedWorkoutEntry.SuggestedExercise(
                    name: exercise.name,
                    category: Exercise.Category.strength.rawValue,
                    activityTypeName: Exercise.defaultActivityTypeName(for: exercise.name, category: .strength),
                    targetTags: [],
                    trackingFields: Exercise.defaultTrackingFields(for: .strength).map(\.rawValue),
                    sets: exercise.sets,
                    reps: exercise.reps,
                    weightKg: exercise.weightKg
                )
            },
            durationMinutes: suggestion.durationMinutes,
            rationale: suggestion.rationale
        )
    }

    private func suggestedStartExercises(
        from template: WorkoutPlan.WorkoutTemplate
    ) -> [SuggestedWorkoutEntry.SuggestedExercise] {
        var suggestions: [SuggestedWorkoutEntry.SuggestedExercise] = []
        let displayBlocks = template.displayBlocks.sorted { $0.order < $1.order }
        let hasBlockLevelExercises = displayBlocks.contains { !$0.exercises.isEmpty }
        var usedTopLevelExerciseFallback = false

        for block in displayBlocks {
            var blockExercises = block.exercises.sorted { $0.order < $1.order }
            if blockExercises.isEmpty,
               block.kind == .strength,
               !hasBlockLevelExercises,
               !usedTopLevelExerciseFallback {
                blockExercises = template.structuredExercises.sorted { $0.order < $1.order }
                usedTopLevelExerciseFallback = !blockExercises.isEmpty
            }

            if block.kind == .strength, !blockExercises.isEmpty {
                for exercise in blockExercises {
                    suggestions.append(SuggestedWorkoutEntry.SuggestedExercise(
                        id: exercise.id,
                        name: exercise.exerciseName,
                        category: Exercise.Category.strength.rawValue,
                        activityTypeName: Exercise.defaultActivityTypeName(for: exercise.exerciseName, category: .strength),
                        activityRole: block.role.rawValue,
                        targetTags: block.resolvedStartSuggestionTags(including: exercise.muscleGroup),
                        trackingFields: Exercise.defaultTrackingFields(for: .strength).map(\.rawValue),
                        sets: exercise.defaultSets,
                        reps: exercise.defaultReps,
                        weightKg: nil,
                        notes: block.notes
                    ))
                }
            } else if block.shouldCreateStartSuggestionItem {
                let category = exerciseCategory(for: block.kind)
                let activityName = block.liveWorkoutSuggestionName
                suggestions.append(SuggestedWorkoutEntry.SuggestedExercise(
                    id: block.id,
                    name: activityName,
                    category: category.rawValue,
                    activityTypeName: block.displayActivityName,
                    activityRole: block.role.rawValue,
                    targetTags: block.resolvedStartSuggestionTags(),
                    trackingFields: Exercise.defaultTrackingFields(for: category).map(\.rawValue),
                    sets: 0,
                    reps: 0,
                    durationMinutes: block.durationMinutes ?? template.estimatedDurationMinutes,
                    notes: block.notes
                ))
            }
        }

        return suggestions
    }

    private func activityFocuses(
        from template: WorkoutPlan.WorkoutTemplate,
        including block: WorkoutPlan.TrainingBlock? = nil
    ) -> [String] {
        var seen: Set<String> = []
        var values: [String] = []

        func append(_ rawValue: String?) {
            guard let rawValue else { return }
            let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
            let key = trimmed.goalNormalizedKey
            guard !trimmed.isEmpty, !key.isEmpty, seen.insert(key).inserted else { return }
            values.append(trimmed)
        }

        template.focusAreas.forEach(append)
        if let block {
            append(block.activityTypeName)
            append(block.displayActivityName)
            append(block.target)
            block.activityTags.forEach(append)
        } else {
            for block in template.displayBlocks {
                append(block.activityTypeName)
                append(block.displayActivityName)
                append(block.target)
                block.activityTags.forEach(append)
            }
        }

        return values
    }

    private func exerciseCategory(
        for blockKind: WorkoutPlan.TrainingBlock.BlockKind
    ) -> Exercise.Category {
        switch blockKind {
        case .strength:
            return .strength
        case .cardio:
            return .cardio
        case .conditioning:
            return .conditioning
        case .skill, .sportPractice:
            return .sportPractice
        case .mobility:
            return .mobility
        case .recovery:
            return .recovery
        case .custom:
            return .custom
        }
    }

    private func buildActivityWorkoutStartSuggestion(
        workoutType: LiveWorkout.WorkoutType,
        activityFocuses: [String],
        durationMinutes: Int
    ) -> SuggestedWorkoutEntry {
        let focuses = activityFocuses.isEmpty ? [workoutType.displayName] : activityFocuses
        let exercises = activitySuggestedExercises(
            for: focuses,
            workoutType: workoutType,
            durationMinutes: durationMinutes
        )
        let name = focuses.isEmpty
            ? "\(workoutType.displayName) Session"
            : "\(focuses.prefix(2).joined(separator: " + ")) Session"
        let rationale = focuses.isEmpty
            ? "Built as a trackable \(workoutType.displayName.lowercased()) session."
            : "Built around \(focuses.prefix(3).joined(separator: ", ")) with tracking fields that match the activity."

        return SuggestedWorkoutEntry(
            name: name,
            workoutType: workoutType.rawValue,
            targetMuscleGroups: [],
            activityFocuses: focuses,
            exercises: exercises,
            durationMinutes: durationMinutes,
            rationale: rationale
        )
    }

    private func activitySuggestedExercises(
        for focuses: [String],
        workoutType: LiveWorkout.WorkoutType,
        durationMinutes: Int
    ) -> [SuggestedWorkoutEntry.SuggestedExercise] {
        let exerciseDescriptor = FetchDescriptor<Exercise>()
        let libraryExercises = (try? modelContext.fetch(exerciseDescriptor)) ?? []
        let perActivityDuration = max(5, durationMinutes / max(focuses.count, 1))

        var suggestions: [SuggestedWorkoutEntry.SuggestedExercise] = []
        var seen = Set<String>()

        for focus in focuses {
            let matches = libraryExercises
                .filter { exercise in
                    exercise.exerciseCategory != .strength && exercise.matchesActivityFocus(focus)
                }
                .sorted { lhs, rhs in
                    lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
                }

            if matches.isEmpty {
                let synthetic = syntheticActivitySuggestion(
                    focus: focus,
                    workoutType: workoutType,
                    durationMinutes: perActivityDuration
                )
                if seen.insert(synthetic.name.goalNormalizedKey).inserted {
                    suggestions.append(synthetic)
                }
                continue
            }

            for exercise in matches.prefix(2) {
                guard seen.insert(exercise.name.goalNormalizedKey).inserted else { continue }
                let category = exercise.exerciseCategory.userFacingEquivalent
                suggestions.append(SuggestedWorkoutEntry.SuggestedExercise(
                    name: exercise.name,
                    category: category.rawValue,
                    activityTypeName: exercise.activityTypeName,
                    targetTags: exercise.targetTags,
                    trackingFields: exercise.trackingFields.map(\.rawValue),
                    sets: 0,
                    reps: 0,
                    durationMinutes: exercise.trackingFields.contains(.duration) ? perActivityDuration : nil
                ))
            }
        }

        if suggestions.isEmpty {
            suggestions.append(syntheticActivitySuggestion(
                focus: workoutType.displayName,
                workoutType: workoutType,
                durationMinutes: durationMinutes
            ))
        }

        return Array(suggestions.prefix(4))
    }

    private func syntheticActivitySuggestion(
        focus: String,
        workoutType: LiveWorkout.WorkoutType,
        durationMinutes: Int
    ) -> SuggestedWorkoutEntry.SuggestedExercise {
        let category = defaultExerciseCategory(for: workoutType)
        let activityName = Exercise.defaultActivityTypeName(for: focus, category: category)
        let targetTags = [focus, activityName]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .dedupedByGoalKey()
        let trackingFields = Exercise.defaultTrackingFields(for: category)

        return SuggestedWorkoutEntry.SuggestedExercise(
            name: focus.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? activityName,
            category: category.rawValue,
            activityTypeName: activityName,
            targetTags: targetTags,
            trackingFields: trackingFields.map(\.rawValue),
            sets: 0,
            reps: 0,
            durationMinutes: trackingFields.contains(.duration) ? durationMinutes : nil
        )
    }

    private func defaultExerciseCategory(for workoutType: LiveWorkout.WorkoutType) -> Exercise.Category {
        switch workoutType {
        case .cardio:
            return .cardio
        case .hiit:
            return .conditioning
        case .climbing:
            return .sportPractice
        case .yoga, .pilates, .flexibility, .mobility:
            return .mobility
        case .recovery:
            return .recovery
        case .strength, .mixed, .custom:
            return .custom
        }
    }

    private func buildWorkoutSuggestion(
        workoutType: LiveWorkout.WorkoutType,
        targetMuscles: [LiveWorkout.MuscleGroup],
        durationMinutes: Int
    ) -> WorkoutSuggestion {
        // Generate workout name based on muscles
        let name = generateWorkoutName(for: targetMuscles, workoutType: workoutType)

        // Get exercises for target muscles
        let exercises = getExercisesForMuscles(targetMuscles, workoutType: workoutType)

        // Build rationale
        let muscleNames = targetMuscles.map(\.displayName).joined(separator: ", ")
        let rationale = targetMuscles.isEmpty
            ? "A general \(workoutType.displayName.lowercased()) workout based on your fitness level."
            : "Targeting \(muscleNames) which are recovered and ready to train."

        return WorkoutSuggestion(
            name: name,
            workoutType: workoutType,
            targetMuscleGroups: targetMuscles,
            exercises: exercises,
            durationMinutes: durationMinutes,
            rationale: rationale
        )
    }

    private func generateWorkoutName(for muscles: [LiveWorkout.MuscleGroup]) -> String {
        generateWorkoutName(for: muscles, workoutType: .strength)
    }

    private func generateWorkoutName(
        for muscles: [LiveWorkout.MuscleGroup],
        workoutType: LiveWorkout.WorkoutType
    ) -> String {
        if muscles.isEmpty, workoutType != .strength {
            return "\(workoutType.displayName) Session"
        }

        let muscleSet = Set(muscles)

        // Check for common workout splits
        if Set(LiveWorkout.MuscleGroup.pushMuscles).isSubset(of: muscleSet) {
            return "Push Day"
        }
        if Set(LiveWorkout.MuscleGroup.pullMuscles).isSubset(of: muscleSet) {
            return "Pull Day"
        }
        if Set(LiveWorkout.MuscleGroup.legMuscles).isSubset(of: muscleSet) {
            return "Leg Day"
        }
        if muscles.contains(.fullBody) || muscles.count >= 6 {
            return "Full Body Workout"
        }
        if muscles.count == 1 {
            return "\(muscles[0].displayName) Focus"
        }

        // Generic name based on first muscle
        if let first = muscles.first {
            return "\(first.displayName) & More"
        }

        return workoutType == .strength ? "Custom Workout" : "\(workoutType.displayName) Session"
    }

    private func getExercisesForMuscles(
        _ muscles: [LiveWorkout.MuscleGroup],
        workoutType: LiveWorkout.WorkoutType
    ) -> [WorkoutSuggestion.SuggestedExercise] {
        var exercises: [WorkoutSuggestion.SuggestedExercise] = []

        // Fetch existing exercises from library
        let exerciseDescriptor = FetchDescriptor<Exercise>()
        let libraryExercises = (try? modelContext.fetch(exerciseDescriptor)) ?? []

        for muscle in muscles {
            // Find exercises that target this muscle group
            let muscleString = mapLiveWorkoutMuscleToExerciseMuscle(muscle)
            let matchingExercises = libraryExercises.filter { $0.muscleGroup == muscleString }

            // Add 2-3 exercises per muscle group
            let exercisesToAdd = matchingExercises.isEmpty
                ? getDefaultExercises(for: muscle)
                : matchingExercises.prefix(3).map { exercise in
                    WorkoutSuggestion.SuggestedExercise(
                        name: exercise.name,
                        sets: 3,
                        reps: workoutType == .strength ? 10 : 15,
                        weightKg: nil
                    )
                }

            exercises.append(contentsOf: exercisesToAdd)
        }

        // Limit to reasonable number of exercises
        return Array(exercises.prefix(8))
    }

    private func mapLiveWorkoutMuscleToExerciseMuscle(_ muscle: LiveWorkout.MuscleGroup) -> String {
        switch muscle {
        case .chest: return "chest"
        case .back: return "back"
        case .shoulders: return "shoulders"
        case .biceps: return "biceps"
        case .triceps: return "triceps"
        case .forearms: return "biceps"  // Map to closest
        case .core: return "core"
        case .quads, .hamstrings, .glutes, .calves: return "legs"
        case .fullBody: return "fullBody"
        }
    }

    private func getDefaultExercises(for muscle: LiveWorkout.MuscleGroup) -> [WorkoutSuggestion.SuggestedExercise] {
        switch muscle {
        case .chest:
            return [
                WorkoutSuggestion.SuggestedExercise(name: "Bench Press", sets: 4, reps: 8, weightKg: nil),
                WorkoutSuggestion.SuggestedExercise(name: "Incline Dumbbell Press", sets: 3, reps: 10, weightKg: nil)
            ]
        case .back:
            return [
                WorkoutSuggestion.SuggestedExercise(name: "Lat Pulldown", sets: 4, reps: 10, weightKg: nil),
                WorkoutSuggestion.SuggestedExercise(name: "Bent Over Row", sets: 3, reps: 10, weightKg: nil)
            ]
        case .shoulders:
            return [
                WorkoutSuggestion.SuggestedExercise(name: "Overhead Press", sets: 4, reps: 8, weightKg: nil),
                WorkoutSuggestion.SuggestedExercise(name: "Lateral Raises", sets: 3, reps: 12, weightKg: nil)
            ]
        case .biceps:
            return [
                WorkoutSuggestion.SuggestedExercise(name: "Bicep Curls", sets: 3, reps: 12, weightKg: nil),
                WorkoutSuggestion.SuggestedExercise(name: "Hammer Curls", sets: 3, reps: 10, weightKg: nil)
            ]
        case .triceps:
            return [
                WorkoutSuggestion.SuggestedExercise(name: "Tricep Pushdown", sets: 3, reps: 12, weightKg: nil),
                WorkoutSuggestion.SuggestedExercise(name: "Skull Crushers", sets: 3, reps: 10, weightKg: nil)
            ]
        case .forearms:
            return [
                WorkoutSuggestion.SuggestedExercise(name: "Wrist Curls", sets: 3, reps: 15, weightKg: nil)
            ]
        case .core:
            return [
                WorkoutSuggestion.SuggestedExercise(name: "Plank", sets: 3, reps: 60, weightKg: nil),
                WorkoutSuggestion.SuggestedExercise(name: "Russian Twists", sets: 3, reps: 20, weightKg: nil)
            ]
        case .quads:
            return [
                WorkoutSuggestion.SuggestedExercise(name: "Squat", sets: 4, reps: 8, weightKg: nil),
                WorkoutSuggestion.SuggestedExercise(name: "Leg Press", sets: 3, reps: 12, weightKg: nil)
            ]
        case .hamstrings:
            return [
                WorkoutSuggestion.SuggestedExercise(name: "Romanian Deadlift", sets: 3, reps: 10, weightKg: nil),
                WorkoutSuggestion.SuggestedExercise(name: "Leg Curl", sets: 3, reps: 12, weightKg: nil)
            ]
        case .glutes:
            return [
                WorkoutSuggestion.SuggestedExercise(name: "Hip Thrusts", sets: 4, reps: 12, weightKg: nil),
                WorkoutSuggestion.SuggestedExercise(name: "Lunges", sets: 3, reps: 10, weightKg: nil)
            ]
        case .calves:
            return [
                WorkoutSuggestion.SuggestedExercise(name: "Calf Raises", sets: 4, reps: 15, weightKg: nil)
            ]
        case .fullBody:
            return [
                WorkoutSuggestion.SuggestedExercise(name: "Deadlift", sets: 3, reps: 8, weightKg: nil),
                WorkoutSuggestion.SuggestedExercise(name: "Squat", sets: 3, reps: 8, weightKg: nil),
                WorkoutSuggestion.SuggestedExercise(name: "Bench Press", sets: 3, reps: 8, weightKg: nil)
            ]
        }
    }

    // MARK: - Start Live Workout

    /// Returns a workout suggestion for user approval (not auto-started)
    func executeStartLiveWorkout(_ args: [String: Any]) -> ExecutionResult {
        guard let name = args["name"] as? String,
              let rawWorkoutType = args["workout_type"] as? String else {
            return .dataResponse(FunctionResult(
                name: "start_live_workout",
                response: ["error": "Missing required parameters: name and workout_type"]
            ))
        }
        let trimmedWorkoutType = rawWorkoutType.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let workoutType = LiveWorkout.WorkoutType(rawValue: trimmedWorkoutType) else {
            return .dataResponse(FunctionResult(
                name: "start_live_workout",
                response: ["error": "workout_type must be a stable workout mode enum. Put user-facing activity names in activity_focuses or activity_name."]
            ))
        }

        // Parse target muscle groups
        let muscleStrings = args["target_muscle_groups"] as? [String] ?? []
        let requestedActivityFocuses = stringArray(from: args["activity_focuses"])
        let sourcePlanTemplateID: UUID?
        if let rawSourcePlanTemplateID = args["source_plan_template_id"] as? String,
           !rawSourcePlanTemplateID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let trimmedSourcePlanTemplateID = rawSourcePlanTemplateID.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let parsedSourcePlanTemplateID = UUID(uuidString: trimmedSourcePlanTemplateID) else {
                return .dataResponse(FunctionResult(
                    name: "start_live_workout",
                    response: ["error": "source_plan_template_id must be an exact template id from the current workout plan."]
                ))
            }
            guard userProfile?.workoutPlan?.templates.contains(where: { $0.id == parsedSourcePlanTemplateID }) == true else {
                return .dataResponse(FunctionResult(
                    name: "start_live_workout",
                    response: ["error": "source_plan_template_id must match an existing session in the current workout plan."]
                ))
            }
            sourcePlanTemplateID = parsedSourcePlanTemplateID
        } else {
            sourcePlanTemplateID = nil
        }

        if let sourcePlanTemplateID {
            guard let template = userProfile?.workoutPlan?.templates.first(where: { $0.id == sourcePlanTemplateID }) else {
                return .dataResponse(FunctionResult(
                    name: "start_live_workout",
                    response: ["error": "source_plan_template_id must match an existing session in the current workout plan."]
                ))
            }

            return .suggestedWorkoutStart(workoutStartSuggestion(
                from: template,
                recoveryReason: nil
            ))
        }

        // Parse suggested exercises
        var exercises: [SuggestedWorkoutEntry.SuggestedExercise] = []
        if let suggestedExercises = args["suggested_exercises"] as? [[String: Any]] {
            for exerciseData in suggestedExercises {
                guard let exerciseName = exerciseData["name"] as? String else { continue }
                let category = (exerciseData["category"] as? String)?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .nilIfEmpty
                let activityTypeName = (exerciseData["activity_name"] as? String)?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .nilIfEmpty
                let activityRole: WorkoutPlan.TrainingBlock.Role?
                if let rawActivityRole = exerciseData["activity_role"] as? String {
                    let trimmedRole = rawActivityRole.trimmingCharacters(in: .whitespacesAndNewlines)
                    if trimmedRole.isEmpty {
                        activityRole = nil
                    } else if let stableRole = WorkoutPlan.TrainingBlock.Role(rawValue: trimmedRole) {
                        activityRole = stableRole
                    } else {
                        return .dataResponse(FunctionResult(
                            name: "start_live_workout",
                            response: ["error": "activity_role must be a stable training block role enum."]
                        ))
                    }
                } else {
                    activityRole = nil
                }
                let targetTags = stringArray(from: exerciseData["target_tags"])
                let trackingFields = stringArray(from: exerciseData["tracking_fields"])
                guard let resolvedCategory = category.flatMap({ Exercise.Category(rawValue: $0)?.userFacingEquivalent }) else {
                    return .dataResponse(FunctionResult(
                        name: "start_live_workout",
                        response: ["error": "Each suggested exercise needs a stable category enum value. Put user-facing activity names in activity_name, not category."]
                    ))
                }
                if resolvedCategory != .strength, activityTypeName == nil {
                    return .dataResponse(FunctionResult(
                        name: "start_live_workout",
                        response: ["error": "Non-strength suggested exercises need activity_name so Trai can preserve the activity identity."]
                    ))
                }
                let normalizedTrackingFields = Exercise.normalizedTrackingFields(
                    trackingFields.compactMap(Exercise.TrackingField.init(rawValue:)),
                    for: resolvedCategory
                )
                let sets = numericInt(from: exerciseData["sets"]) ?? (resolvedCategory == .strength ? 3 : 0)
                let reps = numericInt(from: exerciseData["reps"]) ?? (resolvedCategory == .strength ? 10 : 0)
                let weight = numericDouble(from: exerciseData["weight_kg"])
                let durationMinutes = numericInt(from: exerciseData["duration_minutes"])
                let distanceMeters = numericDouble(from: exerciseData["distance_meters"])
                let notes = (exerciseData["notes"] as? String)?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .nilIfEmpty
                let segments = parseSuggestedActivitySegments(exerciseData["segments"])

                exercises.append(SuggestedWorkoutEntry.SuggestedExercise(
                    name: exerciseName,
                    category: resolvedCategory.rawValue,
                    activityTypeName: activityTypeName,
                    activityRole: activityRole?.rawValue,
                    targetTags: targetTags,
                    trackingFields: normalizedTrackingFields.map(\.rawValue),
                    sets: sets,
                    reps: reps,
                    weightKg: weight,
                    durationMinutes: durationMinutes,
                    distanceMeters: distanceMeters,
                    notes: notes,
                    segments: segments
                ))
            }
        }
        guard !exercises.isEmpty else {
            return .dataResponse(FunctionResult(
                name: "start_live_workout",
                response: ["error": "start_live_workout needs at least one suggested exercise/activity item with stable category and activity_name."]
            ))
        }

        let activityFocuses = Self.suggestionActivityFocuses(
            requested: requestedActivityFocuses,
            exercises: exercises
        )

        // Build rationale from recovery status
        let muscleNames = muscleStrings.map { $0.capitalized }.joined(separator: ", ")
        let rationale: String
        if !muscleStrings.isEmpty {
            rationale = "Targeting \(muscleNames) based on your recovery status and preferences."
        } else if !activityFocuses.isEmpty {
            rationale = "Built around \(activityFocuses.joined(separator: ", ")) and ready for you to customize."
        } else {
            rationale = "A \(workoutType.displayName.lowercased()) workout ready for you to customize."
        }

        // Return suggestion for user approval
        let suggestion = SuggestedWorkoutEntry(
            name: name,
            workoutType: workoutType.rawValue,
            targetMuscleGroups: muscleStrings,
            activityFocuses: activityFocuses,
            exercises: exercises,
            sourcePlanTemplateID: sourcePlanTemplateID,
            durationMinutes: numericInt(from: args["duration_minutes"]) ?? 45,
            rationale: rationale
        )

        return .suggestedWorkoutStart(suggestion)
    }

    private func parseSuggestedActivitySegments(_ value: Any?) -> [SuggestedWorkoutEntry.SuggestedExercise.ActivitySegment] {
        guard let values = value as? [[String: Any]] else { return [] }
        return values.compactMap { rawSegment -> SuggestedWorkoutEntry.SuggestedExercise.ActivitySegment? in
            let durationMinutes = numericInt(from: rawSegment["duration_minutes"])
            let distanceMeters = numericDouble(from: rawSegment["distance_meters"])
            let reps = numericInt(from: rawSegment["reps"])
            let weightKg = numericDouble(from: rawSegment["weight_kg"])
            let notes = (rawSegment["notes"] as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .nilIfEmpty

            guard durationMinutes != nil || distanceMeters != nil || reps != nil || weightKg != nil || notes != nil else {
                return nil
            }

            return SuggestedWorkoutEntry.SuggestedExercise.ActivitySegment(
                durationMinutes: durationMinutes,
                distanceMeters: distanceMeters,
                reps: reps,
                weightKg: weightKg,
                notes: notes
            )
        }
    }

    private static func suggestionActivityFocuses(
        requested: [String],
        exercises: [SuggestedWorkoutEntry.SuggestedExercise]
    ) -> [String] {
        let derived = exercises
            .filter(\.isActivityStartItem)
            .flatMap { exercise in
                ([exercise.activityTypeName] + (exercise.targetTags ?? []))
                    .compactMap { $0 }
            }
        return (requested + derived).dedupedByGoalKey()
    }

    private func numericInt(from value: Any?) -> Int? {
        switch value {
        case let number as Int:
            return number
        case let number as Double:
            return Int(number.rounded())
        case let number as NSNumber:
            return number.intValue
        case let string as String:
            return Int(string.trimmingCharacters(in: .whitespacesAndNewlines))
        default:
            return nil
        }
    }

    private func numericDouble(from value: Any?) -> Double? {
        switch value {
        case let number as Double:
            return number
        case let number as Int:
            return Double(number)
        case let number as NSNumber:
            return number.doubleValue
        case let string as String:
            return Double(string.trimmingCharacters(in: .whitespacesAndNewlines))
        default:
            return nil
        }
    }

    private func stringArray(from value: Any?) -> [String] {
        switch value {
        case let values as [String]:
            return values
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        case let values as [Any]:
            return values.compactMap { element in
                (element as? String)?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .nilIfEmpty
            }
        case let value as String:
            return value
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        default:
            return []
        }
    }

    private func uuid(from value: Any?) -> UUID? {
        guard let rawValue = value as? String else { return nil }
        return UUID(uuidString: rawValue.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}

private extension Array where Element == String {
    func dedupedByGoalKey() -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for value in self {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            let key = trimmed.goalNormalizedKey
            guard !trimmed.isEmpty, !key.isEmpty, seen.insert(key).inserted else { continue }
            result.append(trimmed)
        }
        return result
    }
}

private extension WorkoutPlan.TrainingBlock {
    var shouldCreateStartSuggestionItem: Bool {
        switch kind {
        case .cardio, .conditioning, .skill, .mobility, .recovery, .sportPractice, .custom:
            true
        case .strength:
            false
        }
    }

    func resolvedStartSuggestionTags(including additionalTag: String? = nil) -> [String] {
        var seen: Set<String> = []
        return (activityTags + [additionalTag, displayActivityName])
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .filter { seen.insert($0.goalNormalizedKey).inserted }
    }

    var liveWorkoutSuggestionName: String {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let activityName = displayActivityName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !activityName.isEmpty else {
            return trimmedTitle.isEmpty ? kind.displayName : trimmedTitle
        }

        let genericTitleKeys = (
            WorkoutPlan.TrainingBlock.BlockKind.allCases.flatMap { [$0.displayName, $0.rawValue] }
            + WorkoutPlan.TrainingBlock.Role.allCases.flatMap { [$0.displayName, $0.rawValue] }
            + [
                "Activity",
                "Block",
                "Session",
                "Sport"
            ]
        )
        .map(\.goalNormalizedKey)

        if trimmedTitle.isEmpty || genericTitleKeys.contains(trimmedTitle.goalNormalizedKey) {
            return activityName
        }

        return trimmedTitle
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
