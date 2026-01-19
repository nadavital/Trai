//
//  NutritionPlanVersion.swift
//  Trai
//
//  Historical record of nutrition plans for tracking changes over time.
//

import Foundation
import SwiftData

/// Represents a historical version of a nutrition plan
@Model
final class NutritionPlanVersion {
    var id: UUID = UUID()

    /// The full plan as JSON (preserves all details)
    var planJSON: String = ""

    /// When this plan version was created/accepted
    var createdAt: Date = Date()

    /// Why this plan was created
    var reason: String = ""

    /// Summary of key metrics for quick display
    var calorieTarget: Int = 0
    var proteinTarget: Int = 0
    var carbsTarget: Int = 0
    var fatTarget: Int = 0

    /// User's weight when this plan was created (for context)
    var userWeightKg: Double?

    /// User's goal at the time
    var userGoal: String?

    init() {}

    init(
        plan: NutritionPlan,
        reason: PlanChangeReason,
        userWeightKg: Double? = nil,
        userGoal: String? = nil
    ) {
        self.planJSON = plan.toJSON() ?? ""
        self.reason = reason.rawValue
        self.calorieTarget = plan.dailyTargets.calories
        self.proteinTarget = plan.dailyTargets.protein
        self.carbsTarget = plan.dailyTargets.carbs
        self.fatTarget = plan.dailyTargets.fat
        self.userWeightKg = userWeightKg
        self.userGoal = userGoal
    }

    /// Deserialize the full plan
    var plan: NutritionPlan? {
        NutritionPlan.fromJSON(planJSON)
    }

    /// Display-friendly reason
    var displayReason: String {
        PlanChangeReason(rawValue: reason)?.displayName ?? reason
    }
}

// MARK: - Plan Change Reasons

enum PlanChangeReason: String, CaseIterable {
    case onboarding = "onboarding"
    case chatAdjustment = "chat_adjustment"
    case manualEdit = "manual_edit"
    case weightReview = "weight_review"
    case scheduledReview = "scheduled_review"
    case goalChange = "goal_change"

    var displayName: String {
        switch self {
        case .onboarding: "Initial Plan"
        case .chatAdjustment: "Trai Adjustment"
        case .manualEdit: "Manual Edit"
        case .weightReview: "Weight-Based Review"
        case .scheduledReview: "Scheduled Review"
        case .goalChange: "Goal Change"
        }
    }

    var iconName: String {
        switch self {
        case .onboarding: "star.fill"
        case .chatAdjustment: "bubble.left.fill"
        case .manualEdit: "pencil"
        case .weightReview: "scalemass.fill"
        case .scheduledReview: "calendar"
        case .goalChange: "flag.fill"
        }
    }
}

// MARK: - Convenience Extensions

extension NutritionPlanVersion {
    /// Format date for display
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: createdAt)
    }

    /// Short summary of the plan
    var summary: String {
        "\(calorieTarget) kcal • \(proteinTarget)g protein"
    }

    /// Calculate change from a previous version
    func calorieChange(from previous: NutritionPlanVersion) -> Int {
        calorieTarget - previous.calorieTarget
    }
}
