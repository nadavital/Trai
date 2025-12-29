//
//  GeminiService+Plan.swift
//  Plates
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

        let requestBody: [String: Any] = [
            "contents": [["parts": [["text": prompt]]]],
            "generationConfig": buildGenerationConfig(
                thinkingLevel: .medium,
                maxTokens: 2048,
                jsonSchema: GeminiPromptBuilder.nutritionPlanSchema
            )
        ]

        do {
            let responseText = try await makeRequest(body: requestBody)
            logResponse(responseText)
            let plan = try parseNutritionPlan(from: responseText, fallbackRequest: request)
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

        let requestBody: [String: Any] = [
            "contents": [["parts": [["text": prompt]]]],
            "generationConfig": buildGenerationConfig(
                thinkingLevel: .low,
                maxTokens: 2048,
                jsonSchema: GeminiPromptBuilder.planRefinementSchema
            )
        ]

        do {
            let responseText = try await makeRequest(body: requestBody)
            logResponse(responseText)
            return try parsePlanRefinementResponse(from: responseText)
        } catch {
            log("Failed to refine plan: \(error.localizedDescription)", type: .error)
            throw error
        }
    }

    // MARK: - Parsing

    private func parsePlanRefinementResponse(from text: String) throws -> PlanRefinementResponse {
        var cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanText.hasPrefix("```json") {
            cleanText = String(cleanText.dropFirst(7))
        } else if cleanText.hasPrefix("```") {
            cleanText = String(cleanText.dropFirst(3))
        }
        if cleanText.hasSuffix("```") {
            cleanText = String(cleanText.dropLast(3))
        }
        cleanText = cleanText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = cleanText.data(using: .utf8) else {
            throw GeminiError.parsingError
        }

        struct RefinementJSON: Codable {
            let responseType: String
            let message: String
            let proposedPlan: NutritionPlan?
            let updatedPlan: NutritionPlan?
        }

        let decoded = try JSONDecoder().decode(RefinementJSON.self, from: data)
        let responseType = PlanRefinementResponse.ResponseType(rawValue: decoded.responseType) ?? .message

        return PlanRefinementResponse(
            responseType: responseType,
            message: decoded.message,
            proposedPlan: decoded.proposedPlan,
            updatedPlan: decoded.updatedPlan
        )
    }

    private func parseNutritionPlan(from text: String, fallbackRequest: PlanGenerationRequest) throws -> NutritionPlan {
        log("🔄 Parsing nutrition plan response...", type: .info)

        var cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanText.hasPrefix("```json") {
            log("📝 Stripping ```json prefix", type: .debug)
            cleanText = String(cleanText.dropFirst(7))
        } else if cleanText.hasPrefix("```") {
            log("📝 Stripping ``` prefix", type: .debug)
            cleanText = String(cleanText.dropFirst(3))
        }
        if cleanText.hasSuffix("```") {
            log("📝 Stripping ``` suffix", type: .debug)
            cleanText = String(cleanText.dropLast(3))
        }
        cleanText = cleanText.trimmingCharacters(in: .whitespacesAndNewlines)

        log("📋 Cleaned JSON:", type: .debug)
        if debugLoggingEnabled {
            print(cleanText)
        }

        guard let data = cleanText.data(using: .utf8) else {
            log("⚠️ Failed to convert response to UTF8 data, using fallback plan", type: .error)
            let fallback = NutritionPlan.createDefault(from: fallbackRequest)
            log("📦 Fallback plan created - Calories: \(fallback.dailyTargets.calories)", type: .info)
            return fallback
        }

        do {
            let plan = try JSONDecoder().decode(NutritionPlan.self, from: data)
            log("✅ JSON decoded successfully!", type: .info)
            return plan
        } catch let decodingError {
            log("⚠️ JSON decoding failed: \(decodingError)", type: .error)
            if let decodingError = decodingError as? DecodingError {
                logDecodingError(decodingError)
            }
            let fallback = NutritionPlan.createDefault(from: fallbackRequest)
            log("📦 Using fallback plan - Calories: \(fallback.dailyTargets.calories)", type: .info)
            return fallback
        }
    }

    private func logDecodingError(_ error: DecodingError) {
        switch error {
        case .keyNotFound(let key, let context):
            log("   Missing key: '\(key.stringValue)' at path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))", type: .error)
        case .typeMismatch(let type, let context):
            log("   Type mismatch: expected \(type) at path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))", type: .error)
        case .valueNotFound(let type, let context):
            log("   Value not found: \(type) at path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))", type: .error)
        case .dataCorrupted(let context):
            log("   Data corrupted: \(context.debugDescription)", type: .error)
        @unknown default:
            break
        }
    }
}
