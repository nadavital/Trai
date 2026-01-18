//
//  ChatViewActions.swift
//  Trai
//
//  Chat view action handlers for suggestions
//

import SwiftUI
import SwiftData

// MARK: - Meal Suggestion Actions

extension ChatView {
    func acceptMealSuggestion(_ meal: SuggestedFoodEntry, for message: ChatMessage) {
        let messageIndex = currentSessionMessages.firstIndex(where: { $0.id == message.id }) ?? 0
        let userMessage = messageIndex > 0 ? currentSessionMessages[messageIndex - 1] : nil
        let imageData = userMessage?.imageData

        let entry = FoodEntry()
        entry.name = meal.name
        entry.calories = meal.calories
        entry.proteinGrams = meal.proteinGrams
        entry.carbsGrams = meal.carbsGrams
        entry.fatGrams = meal.fatGrams
        entry.fiberGrams = meal.fiberGrams
        entry.servingSize = meal.servingSize
        entry.emoji = meal.emoji
        entry.imageData = imageData
        entry.inputMethod = "chat"

        if let loggedAt = meal.loggedAtDate {
            entry.loggedAt = loggedAt
        }

        modelContext.insert(entry)

        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            message.loggedFoodEntryId = entry.id
        }

        HapticManager.success()
    }

    func dismissMealSuggestion(for message: ChatMessage) {
        withAnimation(.easeOut(duration: 0.2)) {
            message.suggestedMealDismissed = true
        }
        HapticManager.lightTap()
    }
}

// MARK: - Plan Suggestion Actions

extension ChatView {
    func acceptPlanSuggestion(_ plan: PlanUpdateSuggestionEntry, for message: ChatMessage) {
        guard let profile else { return }

        if let calories = plan.calories {
            profile.dailyCalorieGoal = calories
        }
        if let protein = plan.proteinGrams {
            profile.dailyProteinGoal = protein
        }
        if let carbs = plan.carbsGrams {
            profile.dailyCarbsGoal = carbs
        }
        if let fat = plan.fatGrams {
            profile.dailyFatGoal = fat
        }
        if let goalString = plan.goal {
            // Convert goal string to GoalType (handles various formats)
            let normalizedGoal = goalString.lowercased().replacing("_", with: "")
            if let goalType = UserProfile.GoalType.allCases.first(where: {
                $0.rawValue.lowercased() == normalizedGoal
            }) {
                profile.goal = goalType
            }
        }

        // Update assessment state - marks plan as reviewed with current weight as new baseline
        let currentWeight = weightEntries.first?.weightKg
        planAssessmentService.markPlanReviewed(profile: profile, currentWeightKg: currentWeight)

        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            message.planUpdateApplied = true
        }

        HapticManager.success()
    }

    func dismissPlanSuggestion(for message: ChatMessage) {
        withAnimation(.easeOut(duration: 0.2)) {
            message.suggestedPlanDismissed = true
        }
        HapticManager.lightTap()
    }
}

// MARK: - Workout Log Suggestion Actions

extension ChatView {
    func acceptWorkoutLogSuggestion(_ workoutLog: SuggestedWorkoutLog, for message: ChatMessage) {
        // Create a LiveWorkout with proper exercise details
        let workout = LiveWorkout(
            name: workoutLog.displayName,
            workoutType: workoutLog.isStrength ? .strength : .cardio,
            targetMuscleGroups: []
        )

        // Add exercises as entries
        var entries: [LiveWorkoutEntry] = []
        for (index, exercise) in workoutLog.exercises.enumerated() {
            let entry = LiveWorkoutEntry(exerciseName: exercise.name, orderIndex: index)

            // Add each set with its specific reps/weight
            for setData in exercise.sets {
                entry.addSet(LiveWorkoutEntry.SetData(
                    reps: setData.reps,
                    weightKg: setData.weightKg ?? 0,
                    completed: true,
                    isWarmup: false
                ))
            }

            entries.append(entry)
        }
        workout.entries = entries

        // Set duration by adjusting start time
        if let duration = workoutLog.durationMinutes {
            workout.startedAt = Date().addingTimeInterval(-Double(duration) * 60)
        }

        // Mark as completed
        workout.completedAt = Date()

        if let notes = workoutLog.notes {
            workout.notes = notes
        }

        // Save to database
        modelContext.insert(workout)
        try? modelContext.save()

        // Update message state
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            message.workoutLogSaved = true
        }

        HapticManager.success()
    }

    func dismissWorkoutLogSuggestion(for message: ChatMessage) {
        withAnimation(.easeOut(duration: 0.2)) {
            message.suggestedWorkoutLogDismissed = true
        }
        HapticManager.lightTap()
    }
}

// MARK: - Workout Suggestion Actions

extension ChatView {
    func acceptWorkoutSuggestion(_ workout: SuggestedWorkoutEntry, for message: ChatMessage) {
        // Map workout type string to enum
        let workoutType = LiveWorkout.WorkoutType(rawValue: workout.workoutType) ?? .strength

        // Map target muscle groups
        let targetMuscles = workout.targetMuscleGroups.compactMap {
            LiveWorkout.MuscleGroup(rawValue: $0)
        }

        // Create the LiveWorkout
        let liveWorkout = LiveWorkout(
            name: workout.name,
            workoutType: workoutType,
            targetMuscleGroups: targetMuscles
        )

        // Add suggested exercises as entries
        var entries: [LiveWorkoutEntry] = []
        for (index, exercise) in workout.exercises.enumerated() {
            let entry = LiveWorkoutEntry(exerciseName: exercise.name, orderIndex: index)

            // Pre-populate sets
            for _ in 0..<exercise.sets {
                entry.addSet(LiveWorkoutEntry.SetData(
                    reps: exercise.reps,
                    weightKg: exercise.weightKg ?? 0,
                    completed: false,
                    isWarmup: false
                ))
            }

            entries.append(entry)
        }
        liveWorkout.entries = entries

        // Save to database
        modelContext.insert(liveWorkout)
        try? modelContext.save()

        // Update message state
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            message.workoutStarted = true
            message.startedWorkoutId = liveWorkout.id
        }

        HapticManager.success()
    }

    func dismissWorkoutSuggestion(for message: ChatMessage) {
        withAnimation(.easeOut(duration: 0.2)) {
            message.suggestedWorkoutDismissed = true
        }
        HapticManager.lightTap()
    }
}

// MARK: - Food Edit Suggestion Actions

extension ChatView {
    func acceptFoodEditSuggestion(_ edit: SuggestedFoodEdit, for message: ChatMessage) {
        let descriptor = FetchDescriptor<FoodEntry>(
            predicate: #Predicate { $0.id == edit.entryId }
        )

        guard let entry = try? modelContext.fetch(descriptor).first else { return }

        for change in edit.changes {
            switch change.fieldKey {
            case "calories":
                entry.calories = Int(change.newNumericValue)
            case "proteinGrams":
                entry.proteinGrams = change.newNumericValue
            case "carbsGrams":
                entry.carbsGrams = change.newNumericValue
            case "fatGrams":
                entry.fatGrams = change.newNumericValue
            case "fiberGrams":
                entry.fiberGrams = change.newNumericValue
            default:
                break
            }
        }

        try? modelContext.save()

        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            message.foodEditApplied = true
        }

        HapticManager.success()
    }

    func dismissFoodEditSuggestion(for message: ChatMessage) {
        withAnimation(.easeOut(duration: 0.2)) {
            message.suggestedFoodEditDismissed = true
        }
        HapticManager.lightTap()
    }
}

// MARK: - Plan Reassessment Actions

extension ChatView {
    /// Check if a plan review should be recommended on chat open
    func checkForPlanRecommendation() {
        // Only check if not in incognito mode and we have a profile
        guard let profile, !isTemporarySession else { return }

        // Don't check if we already have a recommendation showing
        guard pendingPlanRecommendation == nil else { return }

        // Check for recommendation triggers
        if let recommendation = planAssessmentService.checkForRecommendation(
            profile: profile,
            weightEntries: Array(weightEntries),
            foodEntries: Array(allFoodEntries)
        ) {
            pendingPlanRecommendation = recommendation
            planRecommendationMessage = planAssessmentService.getRecommendationMessage(
                recommendation,
                useLbs: !profile.usesMetricWeight
            )
        }
    }

    /// Handle when user taps "Review Plan" on recommendation card
    func handlePlanReviewRequest() {
        guard let recommendation = pendingPlanRecommendation else { return }

        // Clear the card first
        withAnimation {
            pendingPlanRecommendation = nil
            planRecommendationMessage = nil
        }

        // Construct a contextual message based on the trigger
        let prompt: String
        switch recommendation.trigger {
        case .weightChange:
            if let change = recommendation.details.weightChangeKg {
                if change > 0 {
                    prompt = "My weight has increased since my plan was created. Can you analyze my progress and suggest plan adjustments?"
                } else {
                    prompt = "I've lost weight since my plan was created. Can you review my plan and suggest updates for continued progress?"
                }
            } else {
                prompt = "My weight has changed. Can you review my plan?"
            }

        case .weightPlateau:
            prompt = "I've hit a weight plateau. Can you analyze why and suggest plan adjustments to break through?"

        case .planAge:
            prompt = "It's been a while since my plan was reviewed. Can you check my progress and suggest any needed updates?"
        }

        // Send the message through the normal chat flow
        sendMessage(prompt)
    }

    /// Handle when user taps "Later" or dismiss on recommendation card
    func handleDismissPlanRecommendation() {
        guard let recommendation = pendingPlanRecommendation,
              let profile else { return }

        // Record the dismissal
        planAssessmentService.dismissRecommendation(recommendation, profile: profile)

        // Clear the card
        withAnimation {
            pendingPlanRecommendation = nil
            planRecommendationMessage = nil
        }

        HapticManager.lightTap()
    }

    /// Check for pending plan review request from Profile (cross-tab navigation)
    func checkForPendingPlanReview() {
        guard pendingPlanReviewRequest else { return }

        // Reset the flag immediately
        pendingPlanReviewRequest = false

        // Send the review request message
        sendMessage("Can you review my nutrition plan and check if any updates are needed based on my progress?")
    }
}
