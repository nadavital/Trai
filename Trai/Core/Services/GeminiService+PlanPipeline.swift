//
//  GeminiService+PlanPipeline.swift
//  Trai
//
//  Shared internal pipeline helpers for Gemini plan generation/refinement
//

import Foundation
import os

extension GeminiService {
    struct PlanPipelineRefinementEnvelope<Plan: Decodable>: Decodable {
        let responseType: String
        let message: String
        let proposedPlan: Plan?
        let updatedPlan: Plan?
    }

    func executePlanGenerationPipeline<Plan: Decodable>(
        prompt: String,
        schema: [String: Any],
        fallback: () -> Plan,
        decodeFailureLabel: String
    ) async throws -> Plan {
        let requestBody: [String: Any] = [
            "contents": [["parts": [["text": prompt]]]],
            "generationConfig": buildGenerationConfig(
                thinkingLevel: .medium,
                jsonSchema: schema
            )
        ]

        let responseText = try await makeRequest(body: requestBody)
        logResponse(responseText)
        return parsePlanPayload(
            from: responseText,
            fallback: fallback,
            decodeFailureLabel: decodeFailureLabel
        )
    }

    func executePlanRefinementPipeline<Plan: Decodable>(
        prompt: String,
        schema: [String: Any]
    ) async throws -> PlanPipelineRefinementEnvelope<Plan> {
        let requestBody: [String: Any] = [
            "contents": [["parts": [["text": prompt]]]],
            "generationConfig": buildGenerationConfig(
                thinkingLevel: .low,
                jsonSchema: schema
            )
        ]

        let responseText = try await makeRequest(body: requestBody)
        logResponse(responseText)
        return try parsePlanRefinementEnvelope(from: responseText)
    }

    func cleanJSONResponse(_ text: String) -> String {
        var cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanText.hasPrefix("```json") {
            cleanText = String(cleanText.dropFirst(7))
        } else if cleanText.hasPrefix("```") {
            cleanText = String(cleanText.dropFirst(3))
        }
        if cleanText.hasSuffix("```") {
            cleanText = String(cleanText.dropLast(3))
        }
        return cleanText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func parsePlanPayload<Plan: Decodable>(
        from text: String,
        fallback: () -> Plan,
        decodeFailureLabel: String
    ) -> Plan {
        let cleanText = cleanJSONResponse(text)

        log("📋 Cleaned JSON:", type: .debug)
        if debugLoggingEnabled {
            print(cleanText)
        }

        guard let data = cleanText.data(using: .utf8) else {
            log("⚠️ Failed to convert response to UTF8 data, using fallback \(decodeFailureLabel)", type: .error)
            return fallback()
        }

        do {
            return try JSONDecoder().decode(Plan.self, from: data)
        } catch let decodingError {
            log("⚠️ \(decodeFailureLabel) JSON decoding failed: \(decodingError)", type: .error)
            if let decodingError = decodingError as? DecodingError {
                logPlanPipelineDecodingError(decodingError)
            }
            return fallback()
        }
    }

    private func parsePlanRefinementEnvelope<Plan: Decodable>(
        from text: String
    ) throws -> PlanPipelineRefinementEnvelope<Plan> {
        let cleanText = cleanJSONResponse(text)

        guard let data = cleanText.data(using: .utf8) else {
            throw GeminiError.parsingError
        }

        return try JSONDecoder().decode(PlanPipelineRefinementEnvelope<Plan>.self, from: data)
    }

    private func logPlanPipelineDecodingError(_ error: DecodingError) {
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
