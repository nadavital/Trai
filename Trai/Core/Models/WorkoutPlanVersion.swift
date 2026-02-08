//
//  WorkoutPlanVersion.swift
//  Trai
//
//  Historical record of workout plans for tracking changes over time.
//

import Foundation
import SwiftData

@Model
final class WorkoutPlanVersion {
    var id: UUID = UUID()

    /// The full workout plan as JSON (preserves all details)
    var planJSON: String = ""

    /// When this plan version was created/accepted
    var createdAt: Date = Date()

    /// Why this plan was created
    var reason: String = ""

    /// Summary values for list display
    var splitType: String = ""
    var daysPerWeek: Int = 0
    var templateCount: Int = 0
    var averageDurationMinutes: Int = 0

    /// User context at the time of creation
    var userWeightKg: Double?
    var userGoal: String?

    init() {}

    init(
        plan: WorkoutPlan,
        reason: WorkoutPlanChangeReason,
        userWeightKg: Double? = nil,
        userGoal: String? = nil
    ) {
        self.planJSON = plan.toJSON() ?? ""
        self.reason = reason.rawValue
        self.splitType = plan.splitType.rawValue
        self.daysPerWeek = plan.daysPerWeek
        self.templateCount = plan.templates.count

        if plan.templates.isEmpty {
            self.averageDurationMinutes = 0
        } else {
            let totalDuration = plan.templates.map(\.estimatedDurationMinutes).reduce(0, +)
            self.averageDurationMinutes = totalDuration / plan.templates.count
        }

        self.userWeightKg = userWeightKg
        self.userGoal = userGoal
    }

    var plan: WorkoutPlan? {
        WorkoutPlan.fromJSON(planJSON)
    }

    var splitTypeDisplayName: String {
        WorkoutPlan.SplitType(rawValue: splitType)?.displayName ?? splitType
    }

    var displayReason: String {
        WorkoutPlanChangeReason(rawValue: reason)?.displayName ?? reason
    }
}

enum WorkoutPlanChangeReason: String, CaseIterable {
    case onboarding = "onboarding"
    case chatCreate = "chat_create"
    case chatAdjustment = "chat_adjustment"
    case manualEdit = "manual_edit"
    case scheduledReview = "scheduled_review"
    case goalChange = "goal_change"

    var displayName: String {
        switch self {
        case .onboarding: "Initial Plan"
        case .chatCreate: "Trai Creation"
        case .chatAdjustment: "Trai Adjustment"
        case .manualEdit: "Manual Edit"
        case .scheduledReview: "Scheduled Review"
        case .goalChange: "Goal Change"
        }
    }

    var iconName: String {
        switch self {
        case .onboarding: "star.fill"
        case .chatCreate: "sparkles"
        case .chatAdjustment: "bubble.left.fill"
        case .manualEdit: "pencil"
        case .scheduledReview: "calendar"
        case .goalChange: "flag.fill"
        }
    }
}

extension WorkoutPlanVersion {
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: createdAt)
    }

    var summary: String {
        if averageDurationMinutes > 0 {
            return "\(daysPerWeek) days/week • \(templateCount) workouts • ~\(averageDurationMinutes) min"
        }
        return "\(daysPerWeek) days/week • \(templateCount) workouts"
    }
}
