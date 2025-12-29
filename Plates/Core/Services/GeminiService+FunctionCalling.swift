//
//  GeminiService+FunctionCalling.swift
//  Plates
//
//  Gemini function calling for tool use
//

import Foundation
import SwiftData
import os

extension GeminiService {

    // MARK: - Types

    /// Context for function calling chat
    struct ChatFunctionContext: Sendable {
        let profile: UserProfile?
        let todaysFoodEntries: [FoodEntry]
        let currentDateTime: String
        let conversationHistory: String
    }

    /// Result from function calling chat
    struct ChatFunctionResult: Sendable {
        let message: String
        let suggestedFood: SuggestedFoodEntry?
        let planUpdate: GeminiFunctionExecutor.PlanUpdateSuggestion?
        let functionsCalled: [String]
    }

    // MARK: - Function Calling Chat

    /// Chat using Gemini function calling for tool use
    func chatWithFunctions(
        message: String,
        imageData: Data?,
        context: ChatFunctionContext,
        conversationHistory: [ChatMessage],
        modelContext: ModelContext,
        onTextChunk: ((String) -> Void)? = nil
    ) async throws -> ChatFunctionResult {
        isLoading = true
        defer { isLoading = false }

        log("🔧 Starting function calling chat", type: .info)

        let systemPrompt = buildFunctionCallingSystemPrompt(context: context)
        var contents: [[String: Any]] = []

        // Add system prompt
        contents.append([
            "role": "user",
            "parts": [["text": systemPrompt]]
        ])
        contents.append([
            "role": "model",
            "parts": [["text": "I understand. I'm your AI fitness coach with access to tools for logging food, checking progress, and managing your nutrition plan. How can I help?"]]
        ])

        // Add conversation history
        for msg in conversationHistory.suffix(10) {
            let parts: [[String: Any]] = [["text": msg.content]]
            contents.append([
                "role": msg.isFromUser ? "user" : "model",
                "parts": parts
            ])
        }

        // Build user message with optional image
        var userParts: [[String: Any]] = []
        if let imageData {
            userParts.append([
                "inline_data": [
                    "mime_type": "image/jpeg",
                    "data": imageData.base64EncodedString()
                ]
            ])
            log("📸 Image attached to message", type: .info)
        }
        userParts.append(["text": message.isEmpty ? "What is this?" : message])

        contents.append([
            "role": "user",
            "parts": userParts
        ])

        // Build request with function declarations
        var config = buildGenerationConfig(thinkingLevel: .medium, maxTokens: 2048)
        if imageData != nil {
            config["mediaResolution"] = "MEDIA_RESOLUTION_HIGH"
        }

        let requestBody: [String: Any] = [
            "contents": contents,
            "tools": [["function_declarations": GeminiFunctionDeclarations.chatFunctions]],
            "generationConfig": config
        ]

        // Use streaming API
        let url = URL(string: "\(baseURL)/models/\(model):streamGenerateContent?alt=sse&key=\(Secrets.geminiAPIKey)")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let startTime = Date()
        let (bytes, response) = try await URLSession.shared.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GeminiError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            log("❌ API Error: status \(httpResponse.statusCode)", type: .error)
            throw GeminiError.apiError(statusCode: httpResponse.statusCode, message: "Streaming request failed")
        }

        return try await parseStreamingFunctionResponse(
            bytes: bytes,
            startTime: startTime,
            context: context,
            modelContext: modelContext,
            contents: contents,
            onTextChunk: onTextChunk
        )
    }

    // MARK: - Private Helpers

    private func buildFunctionCallingSystemPrompt(context: ChatFunctionContext) -> String {
        var prompt = """
        You are an AI fitness and nutrition coach. You have access to tools for:
        - Logging food the user has eaten (suggest_food_log)
        - Checking today's food log and nutrition progress (get_todays_food_log)
        - Viewing and updating the user's nutrition plan (get_user_plan, update_user_plan)
        - Checking workout history (get_recent_workouts)
        - Logging workouts (log_workout)

        Current date/time: \(context.currentDateTime)

        """

        if let profile = context.profile {
            prompt += """
            User's Goal: \(profile.goal.displayName)
            Daily Targets: \(profile.dailyCalorieGoal) kcal, \(profile.dailyProteinGoal)g protein, \(profile.dailyCarbsGoal)g carbs, \(profile.dailyFatGoal)g fat

            """
        }

        prompt += """

        IMPORTANT GUIDELINES:
        1. Follow the user's current intent. If they switch topics, follow along naturally.
        2. ONLY use suggest_food_log when the user EXPLICITLY says they ate/had/consumed something (e.g., "I just had an apple", "I ate a sandwich", "Had coffee this morning").
           - Do NOT suggest logging for questions about food ("is this healthy?", "what about bananas?")
           - Do NOT suggest logging when discussing food hypothetically
           - Do NOT suggest logging in follow-up responses unless the user mentions eating something new
        3. When asked about progress or what they've eaten, use get_todays_food_log.
        4. Be conversational and concise. Answer questions directly.
        5. For food photos, analyze and use suggest_food_log with nutritional estimates.
        6. Don't say "I've logged this" - you can only suggest, the user confirms.
        7. Include relevant emojis for food items (☕, 🥗, 🍳, etc.)
        """

        return prompt
    }

    private func parseStreamingFunctionResponse(
        bytes: URLSession.AsyncBytes,
        startTime: Date,
        context: ChatFunctionContext,
        modelContext: ModelContext,
        contents: [[String: Any]],
        onTextChunk: ((String) -> Void)?
    ) async throws -> ChatFunctionResult {
        var functionsCalled: [String] = []
        var textResponse = ""
        var suggestedFood: SuggestedFoodEntry?
        var planUpdate: GeminiFunctionExecutor.PlanUpdateSuggestion?
        var accumulatedParts: [[String: Any]] = []

        let executor = GeminiFunctionExecutor(modelContext: modelContext, userProfile: context.profile)

        // Parse streaming response
        for try await line in bytes.lines {
            guard line.hasPrefix("data: ") else { continue }
            let jsonString = String(line.dropFirst(6))

            guard let data = jsonString.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let candidates = json["candidates"] as? [[String: Any]],
                  let firstCandidate = candidates.first,
                  let content = firstCandidate["content"] as? [String: Any],
                  let parts = content["parts"] as? [[String: Any]] else {
                continue
            }

            for part in parts {
                accumulatedParts.append(part)

                // Handle text chunks - stream them immediately
                if let text = part["text"] as? String {
                    textResponse += text
                    onTextChunk?(textResponse)
                }

                // Handle function calls
                if let functionCall = part["functionCall"] as? [String: Any],
                   let functionName = functionCall["name"] as? String {
                    let elapsed = Date().timeIntervalSince(startTime)
                    log("⏱️ Function call received in \(String(format: "%.2f", elapsed))s", type: .info)
                    log("🔧 Function called: \(functionName)", type: .info)
                    functionsCalled.append(functionName)

                    let args = functionCall["args"] as? [String: Any] ?? [:]
                    let call = GeminiFunctionExecutor.FunctionCall(name: functionName, arguments: args)
                    let result = executor.execute(call)

                    switch result {
                    case .suggestedFood(let food):
                        suggestedFood = food
                        log("🍽️ Food suggestion: \(food.name) - \(food.calories) kcal", type: .info)

                    case .suggestedPlanUpdate(let update):
                        planUpdate = update
                        log("📊 Plan update suggested", type: .info)

                    case .dataResponse(let functionResult):
                        log("📤 Sending function result back to Gemini", type: .info)
                        let followUp = try await sendFunctionResult(
                            functionResult: functionResult,
                            previousContents: contents,
                            originalParts: accumulatedParts,
                            onTextChunk: onTextChunk
                        )
                        textResponse = followUp

                    case .noAction:
                        break
                    }
                }
            }
        }

        let elapsed = Date().timeIntervalSince(startTime)
        log("⏱️ Streaming complete in \(String(format: "%.2f", elapsed))s", type: .info)

        // If we got a food suggestion, send result back for conversational response
        if let food = suggestedFood, textResponse.isEmpty {
            let foodResult = GeminiFunctionExecutor.FunctionResult(
                name: "suggest_food_log",
                response: [
                    "status": "suggestion_shown",
                    "food_name": food.name,
                    "calories": food.calories,
                    "protein": food.proteinGrams,
                    "note": "User will see a card to confirm or edit this suggestion"
                ]
            )
            let followUp = try await sendFunctionResult(
                functionResult: foodResult,
                previousContents: contents,
                originalParts: accumulatedParts,
                onTextChunk: onTextChunk
            )
            textResponse = followUp
        }

        return ChatFunctionResult(
            message: textResponse,
            suggestedFood: suggestedFood,
            planUpdate: planUpdate,
            functionsCalled: functionsCalled
        )
    }

    private func sendFunctionResult(
        functionResult: GeminiFunctionExecutor.FunctionResult,
        previousContents: [[String: Any]],
        originalParts: [[String: Any]],
        onTextChunk: ((String) -> Void)?
    ) async throws -> String {
        var contents = previousContents

        contents.append([
            "role": "model",
            "parts": originalParts
        ])

        let responseJSON = try JSONSerialization.data(withJSONObject: functionResult.response)
        let responseString = String(data: responseJSON, encoding: .utf8) ?? "{}"

        contents.append([
            "role": "user",
            "parts": [[
                "functionResponse": [
                    "name": functionResult.name,
                    "response": ["result": responseString]
                ]
            ]]
        ])

        let requestBody: [String: Any] = [
            "contents": contents,
            "tools": [["function_declarations": GeminiFunctionDeclarations.chatFunctions]],
            "generationConfig": buildGenerationConfig(thinkingLevel: .low, maxTokens: 1024)
        ]

        // Use streaming for the follow-up response
        let url = URL(string: "\(baseURL)/models/\(model):streamGenerateContent?alt=sse&key=\(Secrets.geminiAPIKey)")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        var fullText = ""

        let (bytes, response) = try await URLSession.shared.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            log("❌ Follow-up streaming request failed", type: .error)
            return "I retrieved the information but encountered an error formatting it."
        }

        for try await line in bytes.lines {
            guard line.hasPrefix("data: ") else { continue }
            let jsonString = String(line.dropFirst(6))

            guard let data = jsonString.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let candidates = json["candidates"] as? [[String: Any]],
                  let firstCandidate = candidates.first,
                  let content = firstCandidate["content"] as? [String: Any],
                  let parts = content["parts"] as? [[String: Any]] else {
                continue
            }

            for part in parts {
                if let text = part["text"] as? String {
                    fullText += text
                    onTextChunk?(fullText)
                }
            }
        }

        return fullText
    }
}
