//
//  WorkoutPlanHistoryService.swift
//  Trai
//
//  Centralized archive helpers for workout plan history.
//

import Foundation
import SwiftData

@MainActor
enum WorkoutPlanHistoryService {
    /// Archives the current plan if it exists and is different from the replacement.
    static func archiveCurrentPlanIfExists(
        profile: UserProfile,
        reason: WorkoutPlanChangeReason,
        modelContext: ModelContext,
        replacingWith newPlan: WorkoutPlan? = nil
    ) {
        guard let currentPlan = profile.workoutPlan else { return }
        if let newPlan, currentPlan == newPlan { return }
        archivePlan(currentPlan, profile: profile, reason: reason, modelContext: modelContext)
    }

    /// Archives a specific workout plan snapshot.
    static func archivePlan(
        _ plan: WorkoutPlan,
        profile: UserProfile,
        reason: WorkoutPlanChangeReason,
        modelContext: ModelContext
    ) {
        let version = WorkoutPlanVersion(
            plan: plan,
            reason: reason,
            userWeightKg: profile.currentWeightKg,
            userGoal: profile.goal.rawValue
        )
        modelContext.insert(version)
    }
}
