//
//  PlanAssessmentService.swift
//  Trai
//
//  Service for detecting when a user's nutrition plan should be reassessed
//

import Foundation
import SwiftData

@MainActor @Observable
final class PlanAssessmentService {

    // MARK: - Configuration

    /// Threshold for significant weight change (kg)
    static let significantWeightChangeKg: Double = 2.5

    /// Window for plateau detection (days)
    static let plateauWindowDays: Int = 14

    /// Tolerance for weight variance in plateau detection (kg)
    static let plateauToleranceKg: Double = 0.5

    /// Days since last review before suggesting a check-in
    static let planAgeDays: Int = 30

    /// Minimum food entries in plateau window to indicate active user
    static let minimumFoodEntriesForPlateau: Int = 10

    // MARK: - Main Assessment Method

    /// Check if a plan review should be recommended
    /// - Parameters:
    ///   - profile: The user's profile
    ///   - weightEntries: Recent weight entries (sorted by date, newest first)
    ///   - foodEntries: Recent food entries
    /// - Returns: A recommendation if triggers are met, nil otherwise
    func checkForRecommendation(
        profile: UserProfile,
        weightEntries: [WeightEntry],
        foodEntries: [FoodEntry]
    ) -> PlanRecommendation? {
        let state = profile.planAssessmentState

        // Check each trigger in priority order
        if let weightChangeRec = checkWeightChange(
            profile: profile,
            weightEntries: weightEntries,
            state: state
        ) {
            return weightChangeRec
        }

        if let plateauRec = checkWeightPlateau(
            profile: profile,
            weightEntries: weightEntries,
            foodEntries: foodEntries,
            state: state
        ) {
            return plateauRec
        }

        if let ageRec = checkPlanAge(profile: profile, state: state) {
            return ageRec
        }

        return nil
    }

    // MARK: - Weight Change Detection

    private func checkWeightChange(
        profile: UserProfile,
        weightEntries: [WeightEntry],
        state: PlanAssessmentState
    ) -> PlanRecommendation? {
        // Get baseline weight (from assessment state or plan creation weight)
        guard let baselineWeight = state.planBaselineWeightKg ?? profile.lastWeightForPlanKg else {
            return nil
        }

        // Get current weight (most recent entry)
        guard let currentWeight = weightEntries.first?.weightKg else {
            return nil
        }

        let change = currentWeight - baselineWeight

        // Check if change is significant
        guard abs(change) >= Self.significantWeightChangeKg else {
            return nil
        }

        // Check if already dismissed
        if isDismissed(.weightChange, value: currentWeight, state: state) {
            return nil
        }

        return PlanRecommendation(
            trigger: .weightChange,
            details: PlanRecommendation.TriggerDetails(
                weightChangeKg: change,
                baselineWeightKg: baselineWeight,
                currentWeightKg: currentWeight
            )
        )
    }

    // MARK: - Weight Plateau Detection

    private func checkWeightPlateau(
        profile: UserProfile,
        weightEntries: [WeightEntry],
        foodEntries: [FoodEntry],
        state: PlanAssessmentState
    ) -> PlanRecommendation? {
        // Only relevant for weight loss or muscle gain goals
        let relevantGoals: [UserProfile.GoalType] = [.loseWeight, .loseFat, .buildMuscle]
        guard relevantGoals.contains(profile.goal) else {
            return nil
        }

        let calendar = Calendar.current
        let now = Date()

        // Define the plateau window
        guard let windowStart = calendar.date(
            byAdding: .day,
            value: -Self.plateauWindowDays,
            to: now
        ) else { return nil }

        // Get weight entries within the window
        let windowEntries = weightEntries.filter { $0.loggedAt >= windowStart }

        // Must have entries spanning the window (first half and second half)
        guard let midPoint = calendar.date(
            byAdding: .day,
            value: -Self.plateauWindowDays / 2,
            to: now
        ) else { return nil }

        let firstHalfEntries = windowEntries.filter { $0.loggedAt < midPoint }
        let secondHalfEntries = windowEntries.filter { $0.loggedAt >= midPoint }

        // Must have at least one entry in each half
        guard !firstHalfEntries.isEmpty && !secondHalfEntries.isEmpty else {
            return nil
        }

        // Check if user has been actively logging food (indicates they're trying)
        let recentFoodEntries = foodEntries.filter { $0.loggedAt >= windowStart }
        guard recentFoodEntries.count >= Self.minimumFoodEntriesForPlateau else {
            return nil
        }

        // Calculate weight variance across all entries in window
        let weights = windowEntries.map { $0.weightKg }
        let avgWeight = weights.reduce(0, +) / Double(weights.count)
        let maxDeviation = weights.map { abs($0 - avgWeight) }.max() ?? 0

        // Check if it's actually a plateau (low variance)
        guard maxDeviation <= Self.plateauToleranceKg else {
            return nil
        }

        // Calculate days in plateau (from oldest entry to now)
        guard let oldestEntry = windowEntries.last else { return nil }
        let plateauDays = calendar.dateComponents(
            [.day],
            from: oldestEntry.loggedAt,
            to: now
        ).day ?? 0

        // Check if dismissed
        if isDismissed(.weightPlateau, value: avgWeight, state: state) {
            return nil
        }

        return PlanRecommendation(
            trigger: .weightPlateau,
            details: PlanRecommendation.TriggerDetails(
                plateauDays: plateauDays,
                plateauWeightKg: avgWeight
            )
        )
    }

    // MARK: - Plan Age Detection

    private func checkPlanAge(
        profile: UserProfile,
        state: PlanAssessmentState
    ) -> PlanRecommendation? {
        // Get last review date (either from assessment state or plan generation)
        let lastReview = state.lastAssessmentDate ?? profile.aiPlanGeneratedAt

        guard let lastReview else {
            return nil
        }

        let daysSinceReview = Calendar.current.dateComponents(
            [.day],
            from: lastReview,
            to: Date()
        ).day ?? 0

        guard daysSinceReview >= Self.planAgeDays else {
            return nil
        }

        // Check if dismissed
        if isDismissed(.planAge, value: Double(daysSinceReview), state: state) {
            return nil
        }

        return PlanRecommendation(
            trigger: .planAge,
            details: PlanRecommendation.TriggerDetails(
                daysSinceReview: daysSinceReview,
                lastReviewDate: lastReview
            )
        )
    }

    // MARK: - Dismissal Handling

    private func isDismissed(
        _ trigger: PlanRecommendation.RecommendationTrigger,
        value: Double?,
        state: PlanAssessmentState
    ) -> Bool {
        state.dismissedRecommendations.contains { dismissal in
            dismissal.isStillRelevant(for: trigger, currentValue: value)
        }
    }

    /// Dismiss a recommendation (user tapped "Later")
    func dismissRecommendation(
        _ recommendation: PlanRecommendation,
        profile: UserProfile
    ) {
        var state = profile.planAssessmentState

        // Determine the relevant value for this dismissal
        let relevantValue: Double?
        switch recommendation.trigger {
        case .weightChange:
            relevantValue = recommendation.details.currentWeightKg
        case .weightPlateau:
            relevantValue = recommendation.details.plateauWeightKg
        case .planAge:
            relevantValue = Double(recommendation.details.daysSinceReview ?? 0)
        }

        // Add to dismissed list
        let dismissal = DismissedRecommendation(
            trigger: recommendation.trigger,
            relevantValue: relevantValue
        )
        state.dismissedRecommendations.append(dismissal)

        // Clear active recommendation if it matches
        if state.activeRecommendation?.id == recommendation.id {
            state.activeRecommendation = nil
        }

        // Clean up old dismissals (keep last 10)
        if state.dismissedRecommendations.count > 10 {
            state.dismissedRecommendations = Array(state.dismissedRecommendations.suffix(10))
        }

        profile.planAssessmentState = state
    }

    /// Mark the plan as reviewed (clears active recommendation, updates baseline)
    func markPlanReviewed(
        profile: UserProfile,
        currentWeightKg: Double?
    ) {
        var state = profile.planAssessmentState
        state.lastAssessmentDate = Date()
        state.activeRecommendation = nil
        state.planBaselineWeightKg = currentWeightKg

        // Clear weight-related dismissals since we've reviewed
        state.dismissedRecommendations.removeAll {
            $0.trigger == .weightChange || $0.trigger == .weightPlateau
        }

        profile.planAssessmentState = state
    }

    // MARK: - Display Helpers

    /// Get a user-friendly message explaining the recommendation
    func getRecommendationMessage(
        _ recommendation: PlanRecommendation,
        useLbs: Bool
    ) -> String {
        switch recommendation.trigger {
        case .weightChange:
            if let change = recommendation.details.weightChangeKg {
                let absChange = abs(change)
                let displayChange: String
                if useLbs {
                    let lbs = absChange * 2.20462
                    displayChange = String(format: "%.1f lbs", lbs)
                } else {
                    displayChange = String(format: "%.1f kg", absChange)
                }

                if change > 0 {
                    return "You've gained \(displayChange) since your plan was created. Your nutrition targets may need adjustment."
                } else {
                    return "Great progress! You've lost \(displayChange). Let's update your plan to keep the momentum going."
                }
            }
            return "Your weight has changed significantly since your plan was created."

        case .weightPlateau:
            if let days = recommendation.details.plateauDays {
                return "Your weight has stayed consistent for \(days) days. Let's review your plan to help you break through."
            }
            return "You've hit a weight plateau. A plan adjustment might help."

        case .planAge:
            if let days = recommendation.details.daysSinceReview {
                return "It's been \(days) days since your plan was last reviewed. Time for a check-in!"
            }
            return "Your plan hasn't been reviewed in a while."
        }
    }

    /// Get the title for the recommendation card
    func getRecommendationTitle(_ recommendation: PlanRecommendation) -> String {
        switch recommendation.trigger {
        case .weightChange:
            return "Weight Change Detected"
        case .weightPlateau:
            return "Weight Plateau Detected"
        case .planAge:
            return "Time for a Plan Review"
        }
    }
}
