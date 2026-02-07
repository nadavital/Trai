//
//  GeminiService+Plan.swift
//  Trai
//
//  Nutrition plan generation and refinement
//

import Foundation
import os

extension GeminiService {

    // MARK: - Plan Refinement Response

    struct PlanRefinementResponse {
        let responseType: ResponseType
        let message: String
        let proposedPlan: NutritionPlan?
        let updatedPlan: NutritionPlan?

        enum ResponseType: String {
            case message
            case proposePlan
            case planUpdate
        }
    }

    // MARK: - Nutrition Plan Generation

    /// Generate a personalized nutrition plan during onboarding
    func generateNutritionPlan(request: PlanGenerationRequest) async throws -> NutritionPlan {
        isLoading = true
        lastError = nil
        defer { isLoading = false }

        log("🎯 Starting nutrition plan generation for: \(request.name)", type: .info)
        log("📊 User data - Age: \(request.age), Gender: \(request.gender.rawValue), Weight: \(request.weightKg)kg, Height: \(request.heightCm)cm", type: .info)
        log("🏃 Activity: \(request.activityLevel.rawValue), Goal: \(request.goal.rawValue)", type: .info)

        let prompt = GeminiPromptBuilder.buildPlanGenerationPrompt(request: request)
        logPrompt(prompt)

        do {
            let plan = try await executePlanGenerationPipeline(
                prompt: prompt,
                schema: GeminiPromptBuilder.nutritionPlanSchema,
                fallback: { NutritionPlan.createDefault(from: request) },
                decodeFailureLabel: "nutrition plan"
            )
            log("✅ Successfully parsed nutrition plan - Calories: \(plan.dailyTargets.calories)", type: .info)
            return plan
        } catch {
            log("Failed to generate plan: \(error.localizedDescription)", type: .error)
            throw error
        }
    }

    // MARK: - Plan Refinement (Chat)

    /// Refine/discuss the nutrition plan through chat
    func refinePlan(
        currentPlan: NutritionPlan,
        request: PlanGenerationRequest,
        userMessage: String,
        conversationHistory: [PlanChatMessage]
    ) async throws -> PlanRefinementResponse {
        isLoading = true
        lastError = nil
        defer { isLoading = false }

        log("💬 Plan refinement request: \(userMessage)", type: .info)

        let prompt = GeminiPromptBuilder.buildPlanRefinementPrompt(
            currentPlan: currentPlan,
            request: request,
            userMessage: userMessage,
            conversationHistory: conversationHistory
        )
        logPrompt(prompt)

        do {
            let envelope: PlanPipelineRefinementEnvelope<NutritionPlan> = try await executePlanRefinementPipeline(
                prompt: prompt,
                schema: GeminiPromptBuilder.planRefinementSchema
            )

            let responseType = PlanRefinementResponse.ResponseType(rawValue: envelope.responseType) ?? .message
            return PlanRefinementResponse(
                responseType: responseType,
                message: envelope.message,
                proposedPlan: envelope.proposedPlan,
                updatedPlan: envelope.updatedPlan
            )
        } catch {
            log("Failed to refine plan: \(error.localizedDescription)", type: .error)
            throw error
        }
    }
}
