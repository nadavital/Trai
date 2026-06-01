//
//  AIPromptBuilder.swift
//  Trai
//
//  Core prompts: food analysis, workout suggestions, system prompt, nutrition advice
//  See also: AIChatPrompts.swift, AIPlanPrompts.swift
//

import Foundation

/// Builds prompts for Trai AI requests
enum AIPromptBuilder {

    // MARK: - Food Analysis

    static func buildFoodAnalysisPrompt(description: String?) -> String {
        var prompt = """
        Analyze this food and provide accurate nutritional information.

        You are an expert nutrition coach and food logger. Be decisive and professionally confident when the primary food is identifiable.
        Your top priority is producing the most accurate loggable estimate possible from the image and any user notes.
        Treat the photo and notes as one combined meal log. Use visual evidence for photographed items, and use the notes for extra eaten items, portion details, substitutions, preparation details, or corrections that are not visible.

        Rules:
        - Focus on the food or drink the user most likely intends to log (main/foreground item or plated meal).
        - Ignore incidental/background foods, nearby items, other people's meals, and unopened packaging unless clearly part of what they ate.
        - If the notes mention additional food or drink the user ate, include it with the photographed food in the same total estimate even when it is not visible in the image.
        - If the notes contradict the photo, trust explicit user notes for what they ate while still using the photo for portion and visual context where useful.
        - Estimate portion size from visible cues such as plate size, bowl size, cup size, packaging, hand scale, cut pieces, fill level, and common serving presentations.
        - If the food appears cooked in a recognizable way, infer the most likely cooking method when it materially affects calories or macros. Use visual cues like grill marks, breading, frying texture, roasting, sauteed appearance, sauces, oil sheen, or visible preparation style.
        - You may infer common included components when they are strongly implied by the visible food presentation, but do NOT add speculative extras that are not reasonably supported by the image or notes.
        - If one meal contains multiple clear components from either the photo or notes, include those components together.
        - When a meal has multiple clear components, return a structured components array describing the major items that make up the meal.
        - If the image is a beverage, identify the beverage directly. For plain water or plain sparkling water with no visible additions, return water with 0 calories and 0g macros.
        - Prefer the most specific food name that is actually supported by the image. Do not guess a polished dish name when multiple materially different foods are still plausible.
        - When the primary food is identifiable, give your best expert estimate instead of hesitating. Use normal real-world assumptions about preparation and serving size unless the image contradicts them.
        - In notes, briefly capture the main assumptions that materially affected calories, macros, or serving size.
        - Only use the failure fallback when no identifiable food or drink is visible at all.
        - Do NOT use the failure fallback just because portion size, recipe details, or cooking method are uncertain. If the food or drink is identifiable, choose a generic visible label and give the best estimate.
        - If there is no identifiable loggable food or drink visible at all, return the sentinel result with:
          name: "Unclear food or drink"
          calories: 0
          proteinGrams: 0
          carbsGrams: 0
          fatGrams: 0
          confidence: "low"
          notes: "The image is not clear enough for a reliable food estimate."
          emoji: "🍽️"

        Estimation guidance:
        - Be realistic and nutritionally useful. Use typical portion sizes only when visually plausible.
        - If quantity is uncertain, estimate the most likely visible serving instead of refusing, unless the food itself is too unclear to identify.
        - If preparation style is visually likely and meaningfully changes calories or macros, incorporate that into the estimate.
        - Macros and calories should reflect the total serving the user is most likely trying to log, including both visible items and explicitly noted items.
        - Include sugarGrams whenever sugar content is reasonably inferable, especially for foods or drinks where sugar is a primary nutrient such as table sugar, honey, syrup, juice, soda, candy, or sweetened coffee/tea.
        - Use confidence "high" or "medium" for most identifiable meals and drinks. Use confidence "low" only when the primary item itself is genuinely hard to identify.
        """

        if let description {
            prompt += "\n\nUser notes: \(description)"
        }

        return prompt
    }

    /// JSON schema for food analysis structured output
    static var foodAnalysisSchema: [String: Any] {
        [
            "type": "object",
            "properties": [
                "name": [
                    "type": "string",
                    "description": "Name of the food or drink being logged from the photo and user notes. Use a generic label if uncertain, not a specific guess."
                ],
                "calories": [
                    "type": "integer",
                    "description": "Estimated total calories for the serving being logged, including visible and explicitly noted items. Use 0 only when the item is clearly zero-calorie, such as plain water, or no loggable item can be identified."
                ],
                "proteinGrams": [
                    "type": "number",
                    "description": "Estimated protein in grams for the serving being logged"
                ],
                "carbsGrams": [
                    "type": "number",
                    "description": "Estimated carbohydrates in grams for the serving being logged"
                ],
                "fatGrams": [
                    "type": "number",
                    "description": "Estimated fat in grams for the serving being logged"
                ],
                "fiberGrams": [
                    "type": "number",
                    "description": "Estimated dietary fiber in grams if reasonably inferable",
                    "nullable": true
                ],
                "sugarGrams": [
                    "type": "number",
                    "description": "Estimated sugar in grams if reasonably inferable",
                    "nullable": true
                ],
                "servingSize": [
                    "type": "string",
                    "description": "Estimated serving size such as '1 medium bowl', '16 oz bottle', or a combined serving from the photo and notes",
                    "nullable": true
                ],
                "confidence": [
                    "type": "string",
                    "enum": ["high", "medium", "low"],
                    "description": "Confidence level of the identification and nutrition estimate. Use low when the primary item itself is hard to identify.",
                    "nullable": true
                ],
                "notes": [
                    "type": "string",
                    "description": "Short explanation of uncertainty, assumptions, or what is not visible. If confidence is low, explain why.",
                    "nullable": true
                ],
                "emoji": [
                    "type": "string",
                    "description": "A single relevant emoji for the identified food or drink. Use 🍽️ for unclear items.",
                    "nullable": true
                ],
                "mealKind": [
                    "type": "string",
                    "enum": ["food", "meal"],
                    "description": "Use 'meal' when the logged item includes multiple meaningful components from the photo or notes, otherwise 'food'.",
                    "nullable": true
                ],
                "components": [
                    "type": "array",
                    "description": "Major meal components from the photo and user notes. Omit or return an empty array for a simple single-item food.",
                    "items": [
                        "type": "object",
                        "properties": [
                            "id": [
                                "type": "string",
                                "description": "Stable identifier for this component within the response"
                            ],
                            "displayName": [
                                "type": "string",
                                "description": "Component name from the photo or user notes"
                            ],
                            "role": [
                                "type": "string",
                                "enum": ["protein", "carb", "fat", "vegetable", "fruit", "sauce", "drink", "mixed", "other"],
                                "nullable": true
                            ],
                            "quantity": [
                                "type": "number",
                                "nullable": true
                            ],
                            "unit": [
                                "type": "string",
                                "nullable": true
                            ],
                            "calories": [
                                "type": "integer"
                            ],
                            "proteinGrams": [
                                "type": "number"
                            ],
                            "carbsGrams": [
                                "type": "number"
                            ],
                            "fatGrams": [
                                "type": "number"
                            ],
                            "fiberGrams": [
                                "type": "number",
                                "nullable": true
                            ],
                            "sugarGrams": [
                                "type": "number",
                                "nullable": true
                            ],
                            "confidence": [
                                "type": "string",
                                "enum": ["high", "medium", "low"],
                                "nullable": true
                            ]
                        ],
                        "required": ["id", "displayName", "calories", "proteinGrams", "carbsGrams", "fatGrams"]
                    ],
                    "nullable": true
                ]
            ],
            "required": ["name", "calories", "proteinGrams", "carbsGrams", "fatGrams"]
        ]
    }

    // MARK: - Workout Suggestions

    static func buildWorkoutSuggestionPrompt(
        history: [WorkoutSession],
        goal: String,
        availableTime: Int?,
        tone: TraiCoachTone = .sharedPreference
    ) -> String {
        var prompt = """
        User's Goal: \(goal)
        """

        if let time = availableTime {
            prompt += "\nAvailable Time: \(time) minutes"
        }

        if !history.isEmpty {
            prompt += "\n\nRecent Workouts:\n"
            for session in history.suffix(5) {
                prompt += "- \(workoutSuggestionHistoryLine(for: session))\n"
            }
        }

        prompt += """

        Provide a specific workout plan with:
        1. Warm-up (5 minutes)
        2. Main work using the right structure for the activity: sets/reps/rest for lifting, or duration, distance, segments, targets, and notes for cardio, sport, mobility, recovery, conditioning, or custom activities
        3. Cool-down (5 minutes)

        Keep the response concise and actionable.
        """

        return prompt
    }

    private static func workoutSuggestionHistoryLine(for session: WorkoutSession) -> String {
        let date = session.loggedAt.formatted(date: .abbreviated, time: .omitted)
        let name = session.displayName
        var details: [String] = []

        if session.isStrengthTraining {
            details.append("\(session.sets) sets x \(session.reps) reps")
            if let weight = session.weightKg {
                details.append("@ \(Int(weight))kg")
            }
        } else {
            let typeName = session.displayTypeName.trimmingCharacters(in: .whitespacesAndNewlines)
            if !typeName.isEmpty, typeName.goalNormalizedKey != name.goalNormalizedKey {
                details.append(typeName)
            }
            if let duration = session.formattedDuration {
                details.append(duration)
            }
            if let distance = session.formattedDistance {
                details.append(distance)
            }
            if let setMetricPhrase = session.setMetricPhrase {
                details.append(setMetricPhrase)
            }
            if let repMetricPhrase = session.repMetricPhrase {
                details.append(repMetricPhrase)
            }

            let tags = session.semanticActivityTags.filter { tag in
                let key = tag.goalNormalizedKey
                return key != name.goalNormalizedKey && key != typeName.goalNormalizedKey
            }
            if !tags.isEmpty {
                details.append("context: \(tags.prefix(3).joined(separator: ", "))")
            }
        }

        let note = session.trimmedNotes
        if !note.isEmpty {
            details.append("notes: \(shortPromptSnippet(note))")
        }

        guard !details.isEmpty else {
            return "\(date): \(name)"
        }

        return "\(date): \(name) - \(details.joined(separator: ", "))"
    }

    private static func shortPromptSnippet(_ value: String, maxLength: Int = 120) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > maxLength else { return trimmed }
        let endIndex = trimmed.index(trimmed.startIndex, offsetBy: maxLength)
        return "\(trimmed[..<endIndex])..."
    }

    // MARK: - System Prompt

    static func buildSystemPrompt(
        context: FitnessContext,
        tone: TraiCoachTone = .sharedPreference
    ) -> String {
        var prompt = TraiPromptCore.coachSystemPrompt(
            role: "A friendly fitness and nutrition coach.",
            tone: tone,
            responseStyle: "Keep responses concise, helpful, specific, and actionable."
        )

        prompt += """

        Current context:
        Goal: \(context.userGoal)
        \(context.calorieTargetPromptLine)
        \(context.proteinTargetPromptLine)

        Today's Progress:
        - Calories consumed: \(context.todaysCalories) kcal
        - Protein consumed: \(Int(context.todaysProtein))g
        """

        if let current = context.currentWeight, let target = context.targetWeight {
            prompt += "\n- Current weight: \(Int(current))kg, Target: \(Int(target))kg"
        }

        if !context.recentWorkouts.isEmpty {
            prompt += "\n\nRecent workouts: \(context.recentWorkouts.joined(separator: ", "))"
        }

        prompt += """

        Be specific and actionable in your advice. Keep responses concise and helpful.
        """

        return prompt
    }

    // MARK: - Nutrition Advice

    static func buildNutritionAdvicePrompt(meals: [FoodEntry], profile: UserProfile) -> String {
        let totalCalories = meals.reduce(0) { $0 + $1.calories }
        let totalProtein = meals.reduce(0.0) { $0 + $1.proteinGrams }
        let totalCarbs = meals.reduce(0.0) { $0 + $1.carbsGrams }
        let totalFat = meals.reduce(0.0) { $0 + $1.fatGrams }
        let goalLines = """
        - Calories: \(profile.dailyCalorieGoal) kcal
        - Protein: \(profile.dailyProteinGoal)g
        - Carbs: \(profile.dailyCarbsGoal)g
        - Fat: \(profile.dailyFatGoal)g
        """
        let adviceInstruction = "Based on this, provide brief nutrition advice for the rest of the day. Suggest specific foods or meals that would help them hit their remaining macros."

        return """
        User's Daily Goals:
        \(goalLines)

        Today's intake so far:
        \(nutritionAdviceProgressLines(profile: profile, totalCalories: totalCalories, totalProtein: totalProtein, totalCarbs: totalCarbs, totalFat: totalFat))

        Meals logged:
        \(meals.map { "- \($0.meal.displayName): \($0.name) (\($0.calories) kcal)" }.joined(separator: "\n"))

        \(adviceInstruction)
        """
    }

    private static func nutritionAdviceProgressLines(
        profile: UserProfile,
        totalCalories: Int,
        totalProtein: Double,
        totalCarbs: Double,
        totalFat: Double
    ) -> String {
        return """
        - Calories: \(totalCalories) kcal (\(Int(Double(totalCalories) / Double(max(profile.dailyCalorieGoal, 1)) * 100))%)
        - Protein: \(Int(totalProtein))g (\(Int(totalProtein / Double(max(profile.dailyProteinGoal, 1)) * 100))%)
        - Carbs: \(Int(totalCarbs))g (\(Int(totalCarbs / Double(max(profile.dailyCarbsGoal, 1)) * 100))%)
        - Fat: \(Int(totalFat))g (\(Int(totalFat / Double(max(profile.dailyFatGoal, 1)) * 100))%)
        """
    }
}
