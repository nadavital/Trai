//
//  OnboardingView+PlanGeneration.swift
//  Trai
//
//  Plan generation logic for onboarding (nutrition plan)
//

import Foundation

enum OnboardingPlanInputInvalidation {
    static func shouldResetGeneratedPlanState(
        oldSignature: String?,
        newSignature: String?,
        hasNutritionState: Bool,
        hasWorkoutReviewState: Bool
    ) -> Bool {
        oldSignature != newSignature && (hasNutritionState || hasWorkoutReviewState)
    }
}

extension OnboardingView {
    // MARK: - Plan Generation

    func generatePlan() {
        guard let request = buildPlanRequest() else {
            resetGeneratedPlanState()
            planError = "Please check your profile information and try again."
            return
        }

        let requestSignature = planInputSignature(for: request)
        let clock = ContinuousClock()
        let generationStartedAt = clock.now
        let minimumLoadingDuration: Duration = .seconds(1.8)

        resetGeneratedPlanState()
        isGeneratingPlan = true
        planError = nil

        Task { @MainActor in
            let plan: NutritionPlan

            #if DEBUG
            if AppLaunchArguments.shouldRunOnboardingFlowUITest {
                plan = NutritionPlan.createDefault(from: request)
            } else if !(monetizationService?.canAccessAIFeatures ?? true) {
                plan = NutritionPlan.createDefault(from: request)
            } else {
                do {
                    plan = try await aiService.generateNutritionPlan(request: request)
                } catch {
                    // Fall back to calculated plan
                    print("⚠️ Plan generation failed, using fallback: \(error.localizedDescription)")
                    plan = NutritionPlan.createDefault(from: request)
                }
            }
            #else
            if !(monetizationService?.canAccessAIFeatures ?? true) {
                plan = NutritionPlan.createDefault(from: request)
            } else {
                do {
                    plan = try await aiService.generateNutritionPlan(request: request)
                } catch {
                    // Fall back to calculated plan
                    print("⚠️ Plan generation failed, using fallback: \(error.localizedDescription)")
                    plan = NutritionPlan.createDefault(from: request)
                }
            }
            #endif

            let elapsed = generationStartedAt.duration(to: clock.now)
            if elapsed < minimumLoadingDuration {
                try? await Task.sleep(for: minimumLoadingDuration - elapsed)
            }

            guard currentPlanInputSignature == requestSignature else {
                isGeneratingPlan = false
                return
            }

            generatedPlan = plan
            populateAdjustedValues(from: plan)
            lastGeneratedPlanInputSignature = requestSignature
            isGeneratingPlan = false
        }
    }

    func populateAdjustedValues(from plan: NutritionPlan) {
        adjustedCalories = String(plan.dailyTargets.calories)
        adjustedProtein = String(plan.dailyTargets.protein)
        adjustedCarbs = String(plan.dailyTargets.carbs)
        adjustedFat = String(plan.dailyTargets.fat)
    }

    // MARK: - Parsing Helpers

    func calculateAge() -> Int? {
        let components = Calendar.current.dateComponents([.year], from: dateOfBirth, to: Date())
        return components.year
    }

    func parseHeight() -> Double? {
        guard let value = Double(heightValue) else { return nil }
        return value
    }

    func parseWeight(_ value: String) -> Double? {
        guard !value.isEmpty, let parsed = Double(value) else { return nil }
        return usesMetricWeight ? parsed : parsed * 0.453592
    }

    func buildPlanRequest() -> PlanGenerationRequest? {
        guard let age = calculateAge(),
              let heightCm = parseHeight(),
              let weightKg = parseWeight(weightValue) else {
            return nil
        }

        return PlanGenerationRequest(
            name: resolvedProfileName,
            age: age,
            gender: gender ?? .notSpecified,
            heightCm: heightCm,
            weightKg: weightKg,
            targetWeightKg: parseWeight(targetWeightValue),
            activityLevel: activityLevel ?? .moderate,
            activityNotes: activityNotes,
            goal: selectedGoal ?? .health,
            additionalNotes: additionalGoalNotes,
            enabledMacros: enabledMacros
        )
    }

    var currentPlanInputSignature: String? {
        guard let request = buildPlanRequest() else { return nil }
        return planInputSignature(for: request)
    }

    func handlePlanInputChange(from oldValue: String?, to newValue: String?) {
        guard oldValue != newValue else { return }
        guard OnboardingPlanInputInvalidation.shouldResetGeneratedPlanState(
            oldSignature: oldValue,
            newSignature: newValue,
            hasNutritionState: generatedPlan != nil || lastGeneratedPlanInputSignature != nil || planError != nil,
            hasWorkoutReviewState: generatedWorkoutPlan != nil || !generatedWorkoutGoals.isEmpty
        ) else { return }
        resetGeneratedPlanState()
        resetGeneratedWorkoutPlanReviewState()
    }

    func resetGeneratedPlanState() {
        generatedPlan = nil
        planError = nil
        adjustedCalories = ""
        adjustedProtein = ""
        adjustedCarbs = ""
        adjustedFat = ""
        lastGeneratedPlanInputSignature = nil
    }

    func resetGeneratedWorkoutPlanReviewState() {
        generatedWorkoutPlan = nil
        generatedWorkoutGoals = []
    }

    func planInputSignature(for request: PlanGenerationRequest) -> String {
        let generationMode = (monetizationService?.canAccessAIFeatures ?? true) ? "ai" : "standard"
        let macroSignature = request.enabledMacros
            .map(\.rawValue)
            .sorted()
            .joined(separator: ",")

        return [
            request.name.trimmingCharacters(in: .whitespacesAndNewlines),
            String(request.age),
            request.gender.rawValue,
            String(format: "%.2f", request.heightCm),
            String(format: "%.2f", request.weightKg),
            request.targetWeightKg.map { String(format: "%.2f", $0) } ?? "nil",
            request.activityLevel.rawValue,
            request.activityNotes.trimmingCharacters(in: .whitespacesAndNewlines),
            request.goal.rawValue,
            request.additionalNotes.trimmingCharacters(in: .whitespacesAndNewlines),
            macroSignature,
            generationMode
        ].joined(separator: "|")
    }
}
