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
        let memoriesContext: String  // Formatted memories for system prompt
        let pendingSuggestion: SuggestedFoodEntry?  // Current unconfirmed meal suggestion

        init(
            profile: UserProfile?,
            todaysFoodEntries: [FoodEntry],
            currentDateTime: String,
            conversationHistory: String,
            memoriesContext: String,
            pendingSuggestion: SuggestedFoodEntry? = nil
        ) {
            self.profile = profile
            self.todaysFoodEntries = todaysFoodEntries
            self.currentDateTime = currentDateTime
            self.conversationHistory = conversationHistory
            self.memoriesContext = memoriesContext
            self.pendingSuggestion = pendingSuggestion
        }
    }

    /// Result from function calling chat
    struct ChatFunctionResult: Sendable {
        let message: String
        let suggestedFood: SuggestedFoodEntry?
        let planUpdate: GeminiFunctionExecutor.PlanUpdateSuggestion?
        let suggestedFoodEdit: SuggestedFoodEdit?
        let functionsCalled: [String]
        let savedMemories: [String]  // Memory contents that were saved during this response
    }

    // MARK: - Function Calling Chat

    /// Chat using Gemini function calling for tool use
    func chatWithFunctions(
        message: String,
        imageData: Data?,
        context: ChatFunctionContext,
        conversationHistory: [ChatMessage],
        modelContext: ModelContext,
        onTextChunk: ((String) -> Void)? = nil,
        onFunctionCall: ((String) -> Void)? = nil
    ) async throws -> ChatFunctionResult {
        isLoading = true
        defer { isLoading = false }

        let systemPrompt = buildFunctionCallingSystemPrompt(context: context)
        var contents: [[String: Any]] = []

        // Add system prompt
        contents.append([
            "role": "user",
            "parts": [["text": systemPrompt]]
        ])
        contents.append([
            "role": "model",
            "parts": [["text": "Hey! What's going on?"]]
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
            onTextChunk: onTextChunk,
            onFunctionCall: onFunctionCall
        )
    }

    // MARK: - Private Helpers

    private func buildFunctionCallingSystemPrompt(context: ChatFunctionContext) -> String {
        var prompt = """
        You are Trai, a friendly and knowledgeable fitness coach. You're casual, encouraging, and genuinely care about helping people reach their goals. You speak like a supportive friend who happens to be a nutrition and fitness expert.

        Personality traits:
        - Warm and encouraging, but not over-the-top
        - Speak naturally, like texting a friend (use contractions, casual language)
        - Celebrate wins, no matter how small
        - Give straight talk when needed - you're honest but kind
        - Curious about their day and how they're feeling

        Never refer to yourself as an AI, Gemini, or an assistant. You're just Trai, their coach.

        You have access to tools for:
        - Logging food the user has eaten (suggest_food_log)
        - Checking today's food log and nutrition progress (get_todays_food_log)
        - Viewing and updating the user's nutrition plan (get_user_plan, update_user_plan)
        - Checking workout history (get_recent_workouts)
        - Logging workouts (log_workout)
        - Remembering facts about the user (save_memory, delete_memory)

        Current date/time: \(context.currentDateTime)

        """

        if let profile = context.profile {
            // Add personalization info
            var userInfo: [String] = []
            if !profile.name.isEmpty {
                userInfo.append("Name: \(profile.name)")
            }
            if let age = profile.age {
                userInfo.append("Age: \(age)")
            }
            if let weight = profile.currentWeightKg {
                let weightStr = profile.usesMetricWeight
                    ? "\(Int(weight)) kg"
                    : "\(Int(weight * 2.205)) lbs"
                userInfo.append("Current weight: \(weightStr)")
            }

            if !userInfo.isEmpty {
                prompt += """
                USER INFO:
                \(userInfo.joined(separator: ", "))

                """
            }

            prompt += """
            User's Goal: \(profile.goal.displayName)
            Daily Targets: \(profile.dailyCalorieGoal) kcal, \(profile.dailyProteinGoal)g protein, \(profile.dailyCarbsGoal)g carbs, \(profile.dailyFatGoal)g fat, \(profile.dailyFiberGoal)g fiber

            """
        }

        // Add memories if available
        if !context.memoriesContext.isEmpty {
            prompt += """

            WHAT YOU KNOW ABOUT THIS USER:
            \(context.memoriesContext)

            Use this knowledge to personalize your responses. For example, don't suggest fish if they don't like it.

            """
        }

        // Add pending meal suggestion context for corrections
        if let pending = context.pendingSuggestion {
            prompt += """

            PENDING MEAL SUGGESTION (not yet logged):
            - Name: \(pending.name)
            - Calories: \(pending.calories) kcal
            - Protein: \(Int(pending.proteinGrams))g, Carbs: \(Int(pending.carbsGrams))g, Fat: \(Int(pending.fatGrams))g
            \(pending.servingSize.map { "- Serving: \($0)" } ?? "")

            If the user says this is wrong or wants corrections (e.g., "that's actually a wrap", "it's closer to 400 calories", "add the sauce"), provide an UPDATED suggest_food_log with the corrected values. Acknowledge their correction naturally.

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
        8. When using update_user_plan to suggest plan changes, ALWAYS include a conversational message explaining WHY you're suggesting the changes. Never just return the plan update without context - the user needs to understand your reasoning before seeing the suggestion card.

        MEMORY USAGE:
        - Use save_memory to remember important facts about the user that will help you be a better coach.
        - Save preferences ("doesn't like fish", "prefers morning workouts"), restrictions ("allergic to nuts", "knee injury"), habits ("usually skips breakfast"), goals ("training for marathon"), and context ("works night shifts").
        - Be proactive about saving memories - if the user mentions something that would help future conversations, save it.
        - Use delete_memory when the user indicates something has changed (e.g., "I actually like fish now").
        - Don't save trivial or one-time information - focus on persistent facts and preferences.
        - You can call save_memory in parallel with other function calls when appropriate.
        """

        return prompt
    }

    private func parseStreamingFunctionResponse(
        bytes: URLSession.AsyncBytes,
        startTime: Date,
        context: ChatFunctionContext,
        modelContext: ModelContext,
        contents: [[String: Any]],
        onTextChunk: ((String) -> Void)?,
        onFunctionCall: ((String) -> Void)?
    ) async throws -> ChatFunctionResult {
        var functionsCalled: [String] = []
        var textResponse = ""
        var suggestedFood: SuggestedFoodEntry?
        var planUpdate: GeminiFunctionExecutor.PlanUpdateSuggestion?
        var suggestedFoodEdit: SuggestedFoodEdit?
        var savedMemories: [String] = []
        var accumulatedParts: [[String: Any]] = []

        let executor = GeminiFunctionExecutor(modelContext: modelContext, userProfile: context.profile)

        // Collect all function calls for parallel processing
        var pendingFunctionCalls: [(name: String, args: [String: Any])] = []
        var pendingFunctionResults: [GeminiFunctionExecutor.FunctionResult] = []

        // Parse streaming response - collect ALL function calls first
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

                // Collect function calls (don't process yet)
                if let functionCall = part["functionCall"] as? [String: Any],
                   let functionName = functionCall["name"] as? String {
                    let args = functionCall["args"] as? [String: Any] ?? [:]
                    let argsPreview = args.keys.joined(separator: ", ")
                    log("🔧 \(functionName)(\(argsPreview))", type: .info)
                    functionsCalled.append(functionName)

                    // Notify UI about the function being called
                    onFunctionCall?(functionName)

                    pendingFunctionCalls.append((name: functionName, args: args))
                }
            }
        }

        // Now process all collected function calls
        if !pendingFunctionCalls.isEmpty {
            for (functionName, args) in pendingFunctionCalls {
                let call = GeminiFunctionExecutor.FunctionCall(name: functionName, arguments: args)
                let result = executor.execute(call)

                // Capture saved memory content
                if functionName == "save_memory", let content = args["content"] as? String {
                    savedMemories.append(content)
                    log("🧠 Saved: \(content.prefix(50))...", type: .info)
                }

                switch result {
                case .suggestedFood(let food):
                    suggestedFood = food
                    log("🍽️ Suggest: \(food.name) (\(food.calories) kcal)", type: .info)

                case .suggestedPlanUpdate(let update):
                    planUpdate = update
                    log("📊 Plan update suggested", type: .info)

                case .suggestedFoodEdit(let edit):
                    suggestedFoodEdit = edit
                    log("✏️ Edit: \(edit.name) - \(edit.changes.count) changes", type: .info)

                case .dataResponse(let functionResult):
                    pendingFunctionResults.append(functionResult)
                    log("📊 Data: \(functionResult.name)", type: .debug)

                case .noAction:
                    break
                }
            }

            // Send all function results back together
            if !pendingFunctionResults.isEmpty {
                log("📤 Sending \(pendingFunctionResults.count) result(s) to model", type: .debug)
                let followUp = try await sendParallelFunctionResults(
                    functionResults: pendingFunctionResults,
                    previousContents: contents,
                    originalParts: accumulatedParts,
                    executor: executor,
                    previousText: textResponse,
                    onTextChunk: onTextChunk
                )
                // Append follow-up text (don't replace - preserves streamed text)
                if !followUp.text.isEmpty {
                    textResponse += followUp.text
                    onTextChunk?(textResponse)
                }
                // Capture any suggestions from chained function calls
                if let food = followUp.suggestedFood {
                    suggestedFood = food
                }
                if let plan = followUp.planUpdate {
                    planUpdate = plan
                }
                if let edit = followUp.suggestedFoodEdit {
                    suggestedFoodEdit = edit
                }
                savedMemories.append(contentsOf: followUp.savedMemories)
            }
        }

        // If we got a food suggestion, send result back for conversational response
        if let food = suggestedFood, textResponse.isEmpty {
            let foodResult = GeminiFunctionExecutor.FunctionResult(
                name: "suggest_food_log",
                response: [
                    "status": "suggestion_ready",
                    "food_name": food.name,
                    "calories": food.calories,
                    "protein": food.proteinGrams,
                    "instruction": "The user will see a card with this food suggestion. Please write a brief, friendly message acknowledging what they ate. Be conversational and encouraging."
                ]
            )
            let followUp = try await sendFunctionResult(
                functionResult: foodResult,
                previousContents: contents,
                originalParts: accumulatedParts,
                executor: executor,
                onTextChunk: nil  // Don't stream during follow-up
            )
            textResponse = followUp.text
            onTextChunk?(textResponse)  // Stream combined result
        }

        // If we got a plan update suggestion, send result back for conversational response
        if let plan = planUpdate, textResponse.isEmpty {
            let planResult = GeminiFunctionExecutor.FunctionResult(
                name: "update_user_plan",
                response: [
                    "status": "suggestion_ready",
                    "calories": plan.calories as Any,
                    "protein": plan.proteinGrams as Any,
                    "carbs": plan.carbsGrams as Any,
                    "fat": plan.fatGrams as Any,
                    "instruction": "The user will see a card with these plan changes. Please write a brief message explaining why you're suggesting these adjustments. Be conversational and explain your reasoning."
                ]
            )
            let followUp = try await sendFunctionResult(
                functionResult: planResult,
                previousContents: contents,
                originalParts: accumulatedParts,
                executor: executor,
                onTextChunk: nil  // Don't stream during follow-up
            )
            textResponse = followUp.text
            onTextChunk?(textResponse)  // Stream combined result
        }

        // If we got a food edit suggestion, send result back for conversational response
        if let edit = suggestedFoodEdit, textResponse.isEmpty {
            let changesDescription = edit.changes.map { "\($0.field): \($0.oldValue) → \($0.newValue)" }.joined(separator: ", ")
            let editResult = GeminiFunctionExecutor.FunctionResult(
                name: "edit_food_entry",
                response: [
                    "status": "suggestion_ready",
                    "entry_name": edit.name,
                    "changes": changesDescription,
                    "instruction": "The user will see a card with these proposed changes. Please write a brief, friendly message explaining what you're suggesting to update and why. Be conversational."
                ]
            )
            let followUp = try await sendFunctionResult(
                functionResult: editResult,
                previousContents: contents,
                originalParts: accumulatedParts,
                executor: executor,
                onTextChunk: nil
            )
            textResponse = followUp.text
            onTextChunk?(textResponse)
        }

        log("✅ Complete: \(textResponse.count) chars, functions: \(functionsCalled.joined(separator: ", "))", type: .info)

        return ChatFunctionResult(
            message: textResponse,
            suggestedFood: suggestedFood,
            planUpdate: planUpdate,
            suggestedFoodEdit: suggestedFoodEdit,
            functionsCalled: functionsCalled,
            savedMemories: savedMemories
        )
    }

    /// Result from sending a function result back to Gemini
    private struct FunctionFollowUpResult {
        var text: String = ""
        var suggestedFood: SuggestedFoodEntry?
        var planUpdate: GeminiFunctionExecutor.PlanUpdateSuggestion?
        var suggestedFoodEdit: SuggestedFoodEdit?
        var savedMemories: [String] = []
        var accumulatedParts: [[String: Any]] = []
    }

    /// Send multiple function results back in parallel
    private func sendParallelFunctionResults(
        functionResults: [GeminiFunctionExecutor.FunctionResult],
        previousContents: [[String: Any]],
        originalParts: [[String: Any]],
        executor: GeminiFunctionExecutor,
        previousText: String = "",
        onTextChunk: ((String) -> Void)?,
        depth: Int = 0
    ) async throws -> FunctionFollowUpResult {
        // Prevent infinite recursion - max 5 levels of chained function calls
        guard depth < 5 else {
            log("⚠️ Max function call depth reached, stopping chain", type: .info)
            return FunctionFollowUpResult()
        }

        var contents = previousContents
        var result = FunctionFollowUpResult()
        let accumulatedPreviousText = previousText

        // Add model's function call parts
        contents.append([
            "role": "model",
            "parts": originalParts
        ])

        // Build all function responses in one parts array
        var responseParts: [[String: Any]] = []
        for funcResult in functionResults {
            responseParts.append([
                "functionResponse": [
                    "name": funcResult.name,
                    "response": funcResult.response
                ]
            ])
        }

        // Send all function responses together
        contents.append([
            "role": "user",
            "parts": responseParts
        ])

        let requestBody: [String: Any] = [
            "contents": contents,
            "tools": [["function_declarations": GeminiFunctionDeclarations.chatFunctions]],
            "generationConfig": buildGenerationConfig(thinkingLevel: .low, maxTokens: 1024)
        ]

        let url = URL(string: "\(baseURL)/models/\(model):streamGenerateContent?alt=sse&key=\(Secrets.geminiAPIKey)")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (bytes, response) = try await URLSession.shared.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            log("❌ Parallel function response request failed", type: .error)
            return result
        }

        // Collect any additional function calls from the response
        var additionalFunctionResults: [GeminiFunctionExecutor.FunctionResult] = []

        for try await line in bytes.lines {
            guard line.hasPrefix("data: ") else { continue }
            let jsonString = String(line.dropFirst(6))

            guard let data = jsonString.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let candidates = json["candidates"] as? [[String: Any]],
                  let firstCandidate = candidates.first else {
                continue
            }

            guard let content = firstCandidate["content"] as? [String: Any],
                  let parts = content["parts"] as? [[String: Any]] else {
                continue
            }

            for part in parts {
                result.accumulatedParts.append(part)

                // Handle text - stream it immediately
                if let text = part["text"] as? String {
                    result.text += text
                    // Stream to UI: combine previous text with new text
                    if let onTextChunk {
                        onTextChunk(accumulatedPreviousText + result.text)
                    }
                }

                // Handle chained function calls
                if let functionCall = part["functionCall"] as? [String: Any],
                   let functionName = functionCall["name"] as? String {
                    // If we already have a suggestion, skip further function calls
                    if result.suggestedFood != nil || result.planUpdate != nil || result.suggestedFoodEdit != nil {
                        log("⏭️ Skipping \(functionName) - already have suggestion", type: .info)
                        continue
                    }

                    let args = functionCall["args"] as? [String: Any] ?? [:]
                    let argsPreview = args.keys.joined(separator: ", ")
                    log("🔗 Chain[\(depth)]: \(functionName)(\(argsPreview))", type: .info)

                    let call = GeminiFunctionExecutor.FunctionCall(name: functionName, arguments: args)
                    let execResult = executor.execute(call)

                    // Capture saved memory content
                    if functionName == "save_memory", let content = args["content"] as? String {
                        result.savedMemories.append(content)
                    }

                    switch execResult {
                    case .suggestedFood(let food):
                        result.suggestedFood = food
                        log("🍽️ Got food suggestion - stopping chain", type: .info)

                    case .suggestedPlanUpdate(let update):
                        result.planUpdate = update
                        log("📊 Got plan update - stopping chain", type: .info)

                    case .suggestedFoodEdit(let edit):
                        result.suggestedFoodEdit = edit
                        log("✏️ Got edit suggestion - stopping chain", type: .info)

                    case .dataResponse(let nextFuncResult):
                        additionalFunctionResults.append(nextFuncResult)

                    case .noAction:
                        break
                    }
                }
            }
        }

        // If there are additional chained function calls, recurse (but not if we have a suggestion)
        let hasSuggestion = result.suggestedFood != nil || result.planUpdate != nil || result.suggestedFoodEdit != nil
        if !additionalFunctionResults.isEmpty && !hasSuggestion {
            let chainedResult = try await sendParallelFunctionResults(
                functionResults: additionalFunctionResults,
                previousContents: contents,
                originalParts: result.accumulatedParts,
                executor: executor,
                previousText: accumulatedPreviousText + result.text,
                onTextChunk: onTextChunk,
                depth: depth + 1
            )
            // Append chained text (don't replace)
            if !chainedResult.text.isEmpty {
                result.text += chainedResult.text
            }
            if let food = chainedResult.suggestedFood {
                result.suggestedFood = food
            }
            if let plan = chainedResult.planUpdate {
                result.planUpdate = plan
            }
            if let edit = chainedResult.suggestedFoodEdit {
                result.suggestedFoodEdit = edit
            }
            result.savedMemories.append(contentsOf: chainedResult.savedMemories)
        }

        return result
    }

    private func sendFunctionResult(
        functionResult: GeminiFunctionExecutor.FunctionResult,
        previousContents: [[String: Any]],
        originalParts: [[String: Any]],
        executor: GeminiFunctionExecutor,
        onTextChunk: ((String) -> Void)?
    ) async throws -> FunctionFollowUpResult {
        var contents = previousContents
        var currentParts = originalParts
        var result = FunctionFollowUpResult()
        var pendingFunctionResult: GeminiFunctionExecutor.FunctionResult? = functionResult

        // Loop to handle multi-turn function calling (max 5 iterations for safety)
        for iteration in 0..<5 {
            guard let funcResult = pendingFunctionResult else { break }
            pendingFunctionResult = nil

            contents.append([
                "role": "model",
                "parts": currentParts
            ])

            // Send function response back - response should be a direct object, not stringified
            contents.append([
                "role": "user",
                "parts": [[
                    "functionResponse": [
                        "name": funcResult.name,
                        "response": funcResult.response
                    ]
                ]]
            ])

            // Don't include tools - we just want a text response for the suggestion
            let requestBody: [String: Any] = [
                "contents": contents,
                "generationConfig": buildGenerationConfig(thinkingLevel: .low, maxTokens: 1024)
            ]

            let url = URL(string: "\(baseURL)/models/\(model):streamGenerateContent?alt=sse&key=\(Secrets.geminiAPIKey)")!

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

            let (bytes, response) = try await URLSession.shared.bytes(for: request)

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                log("❌ Follow-up streaming request failed (iteration \(iteration))", type: .error)
                break
            }

            currentParts = []
            var receivedAnyContent = false

            for try await line in bytes.lines {
                guard line.hasPrefix("data: ") else { continue }
                let jsonString = String(line.dropFirst(6))

                guard let data = jsonString.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let candidates = json["candidates"] as? [[String: Any]],
                      let firstCandidate = candidates.first else {
                    continue
                }

                guard let content = firstCandidate["content"] as? [String: Any],
                      let parts = content["parts"] as? [[String: Any]] else {
                    continue
                }

                receivedAnyContent = true

                for part in parts {
                    currentParts.append(part)

                    if let text = part["text"] as? String {
                        result.text += text
                    }

                    // Skip function calls in follow-up - we just want text
                    if let functionCall = part["functionCall"] as? [String: Any],
                       let functionName = functionCall["name"] as? String {
                        log("⏭️ Ignoring follow-up function call: \(functionName)", type: .debug)
                    }
                }
            }

            result.accumulatedParts = currentParts

            if !receivedAnyContent {
                log("⚠️ No response at iteration \(iteration)", type: .info)
            }
        }

        return result
    }
}
