//
//  OnboardingView+DraftPersistence.swift
//  Trai
//
//  Persists in-progress onboarding state so users can resume later.
//

import Foundation

extension OnboardingView {
    struct OnboardingDraft: Codable, Equatable {
        var currentStep: Int
        var userName: String
        var dateOfBirth: Date
        var genderRawValue: String?
        var heightValue: String
        var weightValue: String
        var targetWeightValue: String
        var usesMetricHeight: Bool
        var usesMetricWeight: Bool
        var activityLevelRawValue: String?
        var activityNotes: String
        var selectedGoalRawValue: String?
        var additionalGoalNotes: String
        var enabledMacros: Set<MacroType>
        var syncFoodToHealthKit: Bool
        var syncWeightToHealthKit: Bool
        var healthSyncError: String?
        var generatedPlan: NutritionPlan?
        var adjustedCalories: String
        var adjustedProtein: String
        var adjustedCarbs: String
        var adjustedFat: String
        var lastGeneratedPlanInputSignature: String?
        var generatedWorkoutPlan: WorkoutPlan?
        var generatedWorkoutGoals: [WorkoutGoalDraft]?
        var workoutPlanDraft: OnboardingWorkoutPlanDraft?
    }

    struct WorkoutGoalDraft: Codable, Equatable {
        var title: String
        var goalKindRaw: String
        var statusRaw: String
        var linkedWorkoutTypeRaw: String?
        var linkedActivityName: String?
        var linkedActivityTags: [String]
        var linkedActivityKindRaw: String?
        var linkedActivityRoleRaw: String?
        var targetValue: Double?
        var targetUnit: String
        var periodUnitRaw: String?
        var periodCount: Int?
        var successCriteria: String
        var notes: String
        var targetDate: Date?
        var checkInCadenceDays: Int?
        var baselineValue: Double?
        var tracksGeneratedPlanAdherence: Bool
        var generatedPlanTemplateIDsRaw: String
        var generatedPlanBlockIDsRaw: String?
        var requiresGeneratedPlanBlockScope: Bool?
        var createdAt: Date
        var updatedAt: Date
        var completedAt: Date?
        var lastCheckInPromptAt: Date?
        var lastCelebratedAt: Date?

        init(goal: WorkoutGoal) {
            title = goal.title
            goalKindRaw = goal.goalKindRaw
            statusRaw = goal.statusRaw
            linkedWorkoutTypeRaw = goal.linkedWorkoutTypeRaw
            linkedActivityName = goal.linkedActivityName
            linkedActivityTags = goal.linkedActivityTags
            linkedActivityKindRaw = goal.linkedActivityKindRaw
            linkedActivityRoleRaw = goal.linkedActivityRoleRaw
            targetValue = goal.targetValue
            targetUnit = goal.targetUnit
            periodUnitRaw = goal.periodUnitRaw
            periodCount = goal.periodCount
            successCriteria = goal.successCriteria
            notes = goal.notes
            targetDate = goal.targetDate
            checkInCadenceDays = goal.checkInCadenceDays
            baselineValue = goal.baselineValue
            tracksGeneratedPlanAdherence = goal.tracksGeneratedPlanAdherence
            generatedPlanTemplateIDsRaw = goal.generatedPlanTemplateIDsRaw
            generatedPlanBlockIDsRaw = goal.generatedPlanBlockIDsRaw
            requiresGeneratedPlanBlockScope = goal.requiresGeneratedPlanBlockScope
            createdAt = goal.createdAt
            updatedAt = goal.updatedAt
            completedAt = goal.completedAt
            lastCheckInPromptAt = goal.lastCheckInPromptAt
            lastCelebratedAt = goal.lastCelebratedAt
        }

        func workoutGoal() -> WorkoutGoal {
            let goal = WorkoutGoal(
                title: title,
                goalKind: WorkoutGoal.GoalKind(rawValue: goalKindRaw) ?? .milestone,
                status: WorkoutGoal.GoalStatus(rawValue: statusRaw) ?? .active,
                linkedWorkoutType: linkedWorkoutTypeRaw.flatMap(WorkoutMode.init(rawValue:)),
                linkedActivityName: linkedActivityName,
                linkedActivityTags: linkedActivityTags,
                linkedActivityKind: linkedActivityKindRaw.flatMap(WorkoutPlan.TrainingBlock.BlockKind.init(rawValue:)),
                linkedActivityRole: linkedActivityRoleRaw.flatMap(WorkoutPlan.TrainingBlock.Role.init(rawValue:)),
                targetValue: targetValue,
                targetUnit: targetUnit,
                periodUnit: periodUnitRaw.flatMap(WorkoutGoal.PeriodUnit.init(rawValue:)),
                periodCount: periodCount,
                successCriteria: successCriteria,
                notes: notes,
                targetDate: targetDate,
                checkInCadenceDays: checkInCadenceDays,
                baselineValue: baselineValue,
                tracksGeneratedPlanAdherence: tracksGeneratedPlanAdherence
            )
            goal.generatedPlanTemplateIDsRaw = generatedPlanTemplateIDsRaw
            goal.generatedPlanBlockIDsRaw = generatedPlanBlockIDsRaw ?? ""
            goal.requiresGeneratedPlanBlockScope = requiresGeneratedPlanBlockScope ?? !goal.generatedPlanBlockIDs.isEmpty
            goal.createdAt = createdAt
            goal.updatedAt = updatedAt
            goal.completedAt = completedAt
            goal.lastCheckInPromptAt = lastCheckInPromptAt
            goal.lastCelebratedAt = lastCelebratedAt
            return goal
        }
    }

    private static let onboardingDraftStorageKey = "onboardingDraft"

    @MainActor var onboardingDraftSnapshot: OnboardingDraft {
        OnboardingDraft(
            currentStep: currentStep,
            userName: userName,
            dateOfBirth: dateOfBirth,
            genderRawValue: gender?.rawValue,
            heightValue: heightValue,
            weightValue: weightValue,
            targetWeightValue: targetWeightValue,
            usesMetricHeight: usesMetricHeight,
            usesMetricWeight: usesMetricWeight,
            activityLevelRawValue: activityLevel?.rawValue,
            activityNotes: activityNotes,
            selectedGoalRawValue: selectedGoal?.rawValue,
            additionalGoalNotes: additionalGoalNotes,
            enabledMacros: enabledMacros,
            syncFoodToHealthKit: syncFoodToHealthKit,
            syncWeightToHealthKit: syncWeightToHealthKit,
            healthSyncError: healthSyncError,
            generatedPlan: generatedPlan,
            adjustedCalories: adjustedCalories,
            adjustedProtein: adjustedProtein,
            adjustedCarbs: adjustedCarbs,
            adjustedFat: adjustedFat,
            lastGeneratedPlanInputSignature: lastGeneratedPlanInputSignature,
            generatedWorkoutPlan: generatedWorkoutPlan,
            generatedWorkoutGoals: generatedWorkoutGoals.map(WorkoutGoalDraft.init(goal:)),
            workoutPlanDraft: workoutPlanDraft
        )
    }

    var hasDraftProgress: Bool {
        currentStep > 0 ||
        !userName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !heightValue.isEmpty ||
        !weightValue.isEmpty ||
        !targetWeightValue.isEmpty ||
        gender != nil ||
        activityLevel != nil ||
        selectedGoal != nil ||
        !activityNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !additionalGoalNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        generatedPlan != nil ||
        generatedWorkoutPlan != nil ||
        !generatedWorkoutGoals.isEmpty ||
        workoutPlanDraft != OnboardingWorkoutPlanDraft()
    }

    func restoreDraftIfNeeded() {
        guard !hasRestoredDraft else { return }
        hasRestoredDraft = true

        guard let data = UserDefaults.standard.data(forKey: Self.onboardingDraftStorageKey),
              let draft = try? JSONDecoder().decode(OnboardingDraft.self, from: data) else {
            return
        }

        userName = draft.userName
        dateOfBirth = draft.dateOfBirth
        gender = draft.genderRawValue.flatMap(UserProfile.Gender.init(rawValue:))
        heightValue = draft.heightValue
        weightValue = draft.weightValue
        targetWeightValue = draft.targetWeightValue
        usesMetricHeight = draft.usesMetricHeight
        usesMetricWeight = draft.usesMetricWeight
        activityLevel = draft.activityLevelRawValue.flatMap(UserProfile.ActivityLevel.init(rawValue:))
        activityNotes = draft.activityNotes
        selectedGoal = draft.selectedGoalRawValue.flatMap(UserProfile.GoalType.init(rawValue:))
        additionalGoalNotes = draft.additionalGoalNotes
        enabledMacros = draft.enabledMacros
        syncFoodToHealthKit = draft.syncFoodToHealthKit
        syncWeightToHealthKit = draft.syncWeightToHealthKit
        healthSyncError = draft.healthSyncError
        generatedPlan = draft.generatedPlan
        adjustedCalories = draft.adjustedCalories
        adjustedProtein = draft.adjustedProtein
        adjustedCarbs = draft.adjustedCarbs
        adjustedFat = draft.adjustedFat
        lastGeneratedPlanInputSignature = draft.lastGeneratedPlanInputSignature
        generatedWorkoutPlan = draft.generatedWorkoutPlan
        generatedWorkoutGoals = draft.generatedWorkoutGoals?.map { $0.workoutGoal() } ?? []
        if let restoredWorkoutPlanDraft = draft.workoutPlanDraft {
            workoutPlanDraft = restoredWorkoutPlanDraft
        }

        if let generatedPlan, adjustedCalories.isEmpty {
            populateAdjustedValues(from: generatedPlan)
        }
        if generatedPlan == nil && draft.currentStep >= totalSteps {
            currentStep = max(totalSteps - 2, 0)
        } else {
            currentStep = min(draft.currentStep, totalSteps - 1)
        }

        recoverPlanReviewIfNeededAfterDraftRestore()
    }

    private func recoverPlanReviewIfNeededAfterDraftRestore() {
        guard currentStepID == .nutritionPlan, generatedPlan == nil else { return }

        if buildPlanRequest() != nil {
            generatePlan()
        } else {
            currentStep = onboardingSteps.firstIndex(of: .activity) ?? max(totalSteps - 2, 0)
        }
    }

    func persistOnboardingDraft() {
        guard hasRestoredDraft else { return }

        if !hasDraftProgress {
            clearOnboardingDraft()
            return
        }

        guard let data = try? JSONEncoder().encode(onboardingDraftSnapshot) else { return }
        UserDefaults.standard.set(data, forKey: Self.onboardingDraftStorageKey)
    }

    func clearOnboardingDraft() {
        UserDefaults.standard.removeObject(forKey: Self.onboardingDraftStorageKey)
    }
}
