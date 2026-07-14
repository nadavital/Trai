//
//  OnDeviceCoachService.swift
//  Trai
//
//  iOS 27 Foundation Models fallback for short, privacy-sensitive coach answers.
//

import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

enum OnDeviceCoachService {
    private static let enabledKey = "trai.foundationModelsQuickCoachEnabled"

    static var isEnabled: Bool {
        (UserDefaults.standard.object(forKey: enabledKey) as? Bool) ?? true
    }

    static func answer(question: String, userContext: String) async throws -> String? {
        guard isEnabled else { return nil }

        #if canImport(FoundationModels)
        if #available(iOS 27.0, *) {
            return try await answerWithSystemModel(question: question, userContext: userContext)
        }
        #endif

        return nil
    }

    #if canImport(FoundationModels)
    @available(iOS 27.0, *)
    private static func answerWithSystemModel(question: String, userContext: String) async throws -> String? {
        let model = SystemLanguageModel.default
        guard model.isAvailable else { return nil }

        let session = LanguageModelSession(
            model: model,
            instructions: """
            You are Trai, a concise fitness and nutrition coach. Use only the supplied user context.
            Do not diagnose medical conditions. If the context is insufficient, say so clearly.
            Keep voice answers to two or three short sentences.
            """
        )
        let response = try await session.respond(
            to: """
            User context:
            \(userContext)

            Question: \(question)
            """
        )
        return response.content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    #endif
}
