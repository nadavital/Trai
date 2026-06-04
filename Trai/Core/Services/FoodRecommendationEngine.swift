import Foundation

nonisolated struct FoodRecommendationRequest: @unchecked Sendable {
    let now: Date
    let targetDate: Date
    let sessionID: UUID?
    let limit: Int
    let entries: [FoodEntry]
    let memories: [FoodMemory]

    let suggestionFeedback: [FoodSuggestionFeedbackSnapshot]

    init(
        now: Date,
        targetDate: Date,
        sessionID: UUID?,
        limit: Int,
        entries: [FoodEntry],
        memories: [FoodMemory],
        suggestionFeedback: [FoodSuggestionFeedbackSnapshot] = []
    ) {
        self.now = now
        self.targetDate = targetDate
        self.sessionID = sessionID
        self.limit = limit
        self.entries = entries
        self.memories = memories
        self.suggestionFeedback = suggestionFeedback
    }
}

nonisolated struct FoodRecommendationContext: @unchecked Sendable {
    let now: Date
    let targetDate: Date
    let sessionID: UUID?
    let limit: Int
    let observations: [FoodObservation]
    let currentSessionObservations: [FoodObservation]
    let todayObservations: [FoodObservation]
    let recentObservations: [FoodObservation]
    let memories: [FoodMemory]

    init(
        now: Date,
        targetDate: Date,
        sessionID: UUID?,
        limit: Int,
        observations: [FoodObservation],
        memories: [FoodMemory]
    ) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: targetDate)
        let recentStart = calendar.date(byAdding: .day, value: -30, to: startOfDay) ?? startOfDay

        self.now = now
        self.targetDate = targetDate
        self.sessionID = sessionID
        self.limit = limit
        self.observations = observations
        self.currentSessionObservations = observations.filter {
            $0.sessionID == sessionID && sessionID != nil && $0.loggedAt < targetDate
        }
        self.todayObservations = observations.filter { $0.loggedAt >= startOfDay && $0.loggedAt < targetDate }
        self.recentObservations = observations.filter { $0.loggedAt >= recentStart && $0.loggedAt < targetDate }
        self.memories = memories
    }
}

nonisolated enum FoodRecommendationSource: String, Sendable {
    case likelyNow
    case continueSession
    case recentAgain
    case occasionAlternate
    case semanticSubstitute
}

nonisolated struct FoodRecommendationResult: Sendable, Equatable {
    let suggestions: [FoodSuggestion]
    let debugReport: FoodRecommendationDebugReport
}

nonisolated struct FoodRecommendationDebugReport: Sendable, Equatable {
    let observationCount: Int
    let patternCount: Int
    let candidateCountBySource: [FoodRecommendationSource: Int]
    let suppressedOneOffCount: Int
    let suppressedAlreadyTodayCount: Int
    let demotedAlreadyTodayCount: Int
    let suppressedNegativeFeedbackCount: Int
    let suppressedLowConfidenceCount: Int
    let recallFallbackCount: Int
    let occasionAlternateCount: Int
    let semanticSubstituteCount: Int
    let completeMealPromotionCount: Int
    let finalShownTitles: [String]
}

nonisolated struct FoodRecommendationEngine {
    private let patternEngine = FoodPatternRecommendationEngine()
    private let normalizationService = FoodNormalizationService()
    private let semanticScorer = FoodSemanticSatisfactionScorer()

    func recommendations(for request: FoodRecommendationRequest) async throws -> FoodRecommendationResult {
        recommendationsSync(for: request)
    }

    func recommendationsSync(for request: FoodRecommendationRequest) -> FoodRecommendationResult {
        let patternResult = patternEngine.recommendationsSync(for: request)
        let patternSuggestions = patternResult.suggestions.map { suggestion in
            FoodSuggestion(
                memoryID: suggestionID(for: suggestion.pattern),
                title: suggestion.suggestedEntry.name,
                subtitle: subtitle(for: suggestion),
                detail: "\(Int(suggestion.suggestedEntry.proteinGrams.rounded()))g protein • \(suggestion.suggestedEntry.calories) cal",
                emoji: suggestion.suggestedEntry.emoji ?? "🍽️",
                relevanceScore: suggestion.score,
                suggestedEntry: suggestion.suggestedEntry
            )
        }
        let completion = completedSuggestions(patternSuggestions, request: request)

        return FoodRecommendationResult(
            suggestions: completion.suggestions,
            debugReport: FoodRecommendationDebugReport(
                observationCount: patternResult.debugReport.observationCount,
                patternCount: patternResult.debugReport.patternCount,
                candidateCountBySource: recommendationCandidateCounts(from: patternResult.debugReport.candidateCountBySource),
                suppressedOneOffCount: patternResult.debugReport.suppressedOneOffCount,
                suppressedAlreadyTodayCount: patternResult.debugReport.suppressedAlreadyTodayCount,
                demotedAlreadyTodayCount: patternResult.debugReport.demotedAlreadyTodayCount,
                suppressedNegativeFeedbackCount: patternResult.debugReport.suppressedNegativeFeedbackCount,
                suppressedLowConfidenceCount: patternResult.debugReport.suppressedLowConfidenceCount,
                recallFallbackCount: patternResult.debugReport.recallFallbackCount + completion.safeRecallCount,
                occasionAlternateCount: completion.occasionAlternateCount,
                semanticSubstituteCount: completion.semanticSubstituteCount,
                completeMealPromotionCount: patternResult.debugReport.completeMealPromotionCount,
                finalShownTitles: completion.suggestions.map(\.title)
            )
        )
    }

    private func suggestionID(for pattern: FoodPattern) -> UUID {
        let linkedIDs = pattern.observations.compactMap(\.linkedMemoryID)
        guard !linkedIDs.isEmpty else { return pattern.stableUUID }
        return Dictionary(grouping: linkedIDs, by: { $0 })
            .max {
                if $0.value.count != $1.value.count {
                    return $0.value.count < $1.value.count
                }
                return $0.key.uuidString < $1.key.uuidString
            }?
            .key ?? pattern.stableUUID
    }

    private func subtitle(for suggestion: FoodPatternSuggestion) -> String {
        switch suggestion.source {
        case .likelyNow:
            return "Common around this time"
        case .continueSession:
            return "Often logged together"
        case .recentAgain:
            return "Recent repeat"
        }
    }

    private func recommendationCandidateCounts(
        from counts: [FoodPatternSuggestionSource: Int]
    ) -> [FoodRecommendationSource: Int] {
        var output: [FoodRecommendationSource: Int] = [:]
        output[.likelyNow] = counts[.likelyNow]
        output[.continueSession] = counts[.continueSession]
        output[.recentAgain] = counts[.recentAgain]
        return output.filter { $0.value > 0 }
    }

    private func completedSuggestions(
        _ patternSuggestions: [FoodSuggestion],
        request: FoodRecommendationRequest
    ) -> FoodRecommendationCompletion {
        guard request.limit > 0 else {
            return FoodRecommendationCompletion(
                suggestions: [],
                safeRecallCount: 0,
                occasionAlternateCount: 0,
                semanticSubstituteCount: 0
            )
        }

        let observations = FoodObservationBuilder().observations(from: request.entries)
        let startOfDay = Calendar.current.startOfDay(for: request.targetDate)
        let todayObservations = observations.filter {
            $0.loggedAt >= startOfDay && $0.loggedAt < request.targetDate
        }
        let recallSuggestions = FoodRecommendationSafeRecallProvider().suggestions(
            observations: observations,
            now: request.targetDate,
            limit: request.limit
        )
        let occasionSuggestions = FoodRecommendationOccasionAlternateProvider().suggestions(
            observations: observations,
            now: request.targetDate,
            limit: request.limit
        )
        let semanticSubstituteSuggestions = FoodRecommendationSemanticSubstituteProvider().suggestions(
            observations: observations,
            now: request.targetDate,
            limit: request.limit
        )
        var output = Array(patternSuggestions.prefix(request.limit))
        var safeRecallCount = 0
        var occasionAlternateCount = 0
        var semanticSubstituteCount = 0
        for suggestion in recallSuggestions where output.count < request.limit {
            guard !output.contains(where: { suggestionsOverlap($0, suggestion) }) else { continue }
            guard !isSuppressedByFeedback(suggestion, memories: request.memories, suggestionFeedback: request.suggestionFeedback, targetDate: request.targetDate) else { continue }
            guard !isSatisfiedToday(suggestion, todayObservations: todayObservations, targetDate: request.targetDate) else { continue }
            output.append(suggestion)
            safeRecallCount += 1
        }
        for suggestion in occasionSuggestions {
            guard !output.contains(where: { suggestionsOverlap($0, suggestion) }) else { continue }
            guard !isSuppressedByFeedback(suggestion, memories: request.memories, suggestionFeedback: request.suggestionFeedback, targetDate: request.targetDate) else { continue }
            guard !isSatisfiedToday(suggestion, todayObservations: todayObservations, targetDate: request.targetDate) else { continue }
            if output.count < request.limit {
                output.append(suggestion)
                occasionAlternateCount += 1
                continue
            }
            guard shouldPromoteOccasionAlternate(suggestion, over: output) else { continue }
            if let replacementIndex = output.lastIndex(where: isReplaceableByOccasionAlternate) {
                output[replacementIndex] = suggestion
                occasionAlternateCount += 1
            }
        }
        for suggestion in semanticSubstituteSuggestions {
            guard !output.contains(where: { suggestionsOverlap($0, suggestion) }) else { continue }
            guard !isSuppressedByFeedback(suggestion, memories: request.memories, suggestionFeedback: request.suggestionFeedback, targetDate: request.targetDate) else { continue }
            guard !isSatisfiedToday(suggestion, todayObservations: todayObservations, targetDate: request.targetDate) else { continue }
            if output.count < request.limit {
                output.append(suggestion)
                semanticSubstituteCount += 1
                continue
            }
            guard shouldPromoteSemanticSubstitute(suggestion, over: output) else { continue }
            if let replacementIndex = output.lastIndex(where: isReplaceableBySemanticSubstitute) {
                output[replacementIndex] = suggestion
                semanticSubstituteCount += 1
            }
        }
        return FoodRecommendationCompletion(
            suggestions: output.prefix(request.limit).map { $0 },
            safeRecallCount: safeRecallCount,
            occasionAlternateCount: occasionAlternateCount,
            semanticSubstituteCount: semanticSubstituteCount
        )
    }

    private func shouldPromoteOccasionAlternate(_ candidate: FoodSuggestion, over suggestions: [FoodSuggestion]) -> Bool {
        guard isCompleteMeal(candidate.suggestedEntry), !isLiquidOnly(candidate.suggestedEntry.components) else { return false }
        guard let replaceable = suggestions.last(where: isReplaceableByOccasionAlternate) else { return false }
        return candidate.relevanceScore >= replaceable.relevanceScore - 0.08
    }

    private func isReplaceableByOccasionAlternate(_ suggestion: FoodSuggestion) -> Bool {
        isLiquidOnly(suggestion.suggestedEntry.components) || !isCompleteMeal(suggestion.suggestedEntry)
    }

    private func shouldPromoteSemanticSubstitute(_ candidate: FoodSuggestion, over suggestions: [FoodSuggestion]) -> Bool {
        guard isCompleteMeal(candidate.suggestedEntry), !isLiquidOnly(candidate.suggestedEntry.components) else { return false }
        guard let replaceable = suggestions.last(where: isReplaceableBySemanticSubstitute) else { return false }
        return candidate.relevanceScore >= replaceable.relevanceScore - 0.06
    }

    private func isReplaceableBySemanticSubstitute(_ suggestion: FoodSuggestion) -> Bool {
        isLiquidOnly(suggestion.suggestedEntry.components) || !isCompleteMeal(suggestion.suggestedEntry)
    }

    private func isSuppressedByFeedback(
        _ suggestion: FoodSuggestion,
        memories: [FoodMemory],
        suggestionFeedback: [FoodSuggestionFeedbackSnapshot],
        targetDate: Date
    ) -> Bool {
        let stats = memories.first(where: { $0.id == suggestion.memoryID })?.suggestionStats
            ?? suggestionFeedback.first(where: { $0.suggestionID == suggestion.memoryID })?.stats
        guard let stats else { return false }
        guard stats.timesDismissed > stats.timesAccepted,
              let lastDismissedAt = stats.lastDismissedAt
        else {
            return false
        }
        let hoursSinceDismissal = Calendar.current.dateComponents([.hour], from: lastDismissedAt, to: targetDate).hour ?? 999
        return hoursSinceDismissal < 12
    }

    private func isSatisfiedToday(
        _ suggestion: FoodSuggestion,
        todayObservations: [FoodObservation],
        targetDate: Date
    ) -> Bool {
        todayObservations.contains { observation in
            suggestionMatches(suggestion, observation: observation, targetDate: targetDate)
        }
    }

    private func suggestionMatches(_ suggestion: FoodSuggestion, observation: FoodObservation, targetDate: Date) -> Bool {
        let suggestedComponents = canonicalComponentSet(from: suggestion.suggestedEntry.components)
        let observedComponents = Set(observation.components.map(\.canonicalName).filter { !$0.isEmpty })
        if !suggestedComponents.isEmpty, suggestedComponents == observedComponents {
            return true
        }
        let suggestionIsLiquidOnly = isLiquidOnly(suggestion.suggestedEntry.components)
        let observationIsLiquidOnly = isLiquidOnly(observation.components)
        let suggestionIsCompleteMeal = isCompleteMeal(suggestion.suggestedEntry)
        let observationIsCompleteMeal = isCompleteMeal(observation)
        if suggestionIsCompleteMeal,
           observationIsCompleteMeal,
           normalizationService.mealTimeBucket(for: observation.loggedAt) != normalizationService.mealTimeBucket(for: targetDate) {
            return false
        }
        guard (suggestionIsLiquidOnly && observationIsLiquidOnly)
            || (suggestionIsCompleteMeal && observationIsCompleteMeal)
        else { return false }

        let candidateNames = [
            suggestion.title,
            suggestion.suggestedEntry.name
        ].map(normalizationService.normalizeFoodName)
        let observationName = observation.normalizedName.isEmpty
            ? normalizationService.normalizeFoodName(observation.displayName)
            : observation.normalizedName
        let exactComponentScore = FoodSemanticSatisfactionScorer.jaccard(
            lhs: suggestedComponents,
            rhs: observedComponents
        )
        let componentSemanticScore = semanticScorer.componentSemanticSimilarity(
            candidateComponents: Array(suggestedComponents),
            loggedComponents: Array(observedComponents)
        )
        let macroScore = semanticScorer.macroSimilarity(
            candidate: FoodSemanticNutritionProfile(
                calories: Double(suggestion.suggestedEntry.calories),
                proteinGrams: suggestion.suggestedEntry.proteinGrams,
                carbsGrams: suggestion.suggestedEntry.carbsGrams,
                fatGrams: suggestion.suggestedEntry.fatGrams
            ),
            logged: FoodSemanticNutritionProfile(
                calories: Double(observation.calories),
                proteinGrams: observation.proteinGrams,
                carbsGrams: observation.carbsGrams,
                fatGrams: observation.fatGrams
            )
        )
        let servingScore = semanticScorer.servingSimilarity(
            candidate: FoodSemanticServingProfile(
                servingText: suggestion.suggestedEntry.servingSize,
                quantity: nil,
                unit: nil
            ),
            logged: FoodSemanticServingProfile(
                servingText: observation.servingText,
                quantity: observation.servingQuantity,
                unit: observation.servingUnit
            )
        )
        let nameScore = semanticScorer.nameSimilarity(candidateNames: candidateNames, loggedName: observationName)
        let decision = semanticScorer.decision(
            exactComponentScore: exactComponentScore,
            componentSemanticScore: componentSemanticScore,
            nameScore: nameScore,
            macroScore: macroScore,
            servingScore: servingScore
        )
        if decision.isSatisfied {
            return true
        }
        guard suggestionIsCompleteMeal, observationIsCompleteMeal else { return false }
        return completeMealSubstituteMatches(
            suggestion: suggestion,
            observation: observation,
            componentSemanticScore: componentSemanticScore,
            macroScore: macroScore
        )
    }

    private func isCompleteMeal(_ observation: FoodObservation) -> Bool {
        let roles = Set(observation.components.map(\.role))
        return (roles.contains(.protein) && (roles.contains(.carb) || roles.contains(.vegetable) || roles.contains(.fruit) || roles.contains(.mixed)))
            || (observation.calories >= 450 && observation.components.count >= 2)
    }

    private func completeMealSubstituteMatches(
        suggestion: FoodSuggestion,
        observation: FoodObservation,
        componentSemanticScore: Double,
        macroScore: Double
    ) -> Bool {
        let suggestedRoles = Set(suggestion.suggestedEntry.components.compactMap { component in
            component.role.flatMap(FoodComponentRole.init(rawValue:))
        })
        let observedRoles = Set(observation.components.map(\.role))
        let roleScore = FoodSemanticSatisfactionScorer.jaccard(lhs: suggestedRoles, rhs: observedRoles)
        let intentNameScore = semanticScorer.nameSimilarity(
            candidateNames: [completeMealIntentText(for: suggestion.suggestedEntry)],
            loggedName: completeMealIntentText(for: observation)
        )
        let intentScore = max(componentSemanticScore, intentNameScore)
        let substituteScore = 0.42 * componentSemanticScore
            + 0.24 * intentNameScore
            + 0.22 * macroScore
            + 0.12 * roleScore

        return componentSemanticScore >= 0.55
            && intentNameScore >= 0.55
            && macroScore >= 0.55
            && roleScore >= 0.50
            && intentScore >= 0.55
            && substituteScore >= 0.62
    }

    private func completeMealIntentText(for entry: SuggestedFoodEntry) -> String {
        let roles = Set(entry.components.compactMap { $0.role.flatMap(FoodComponentRole.init(rawValue:)) })
        var tokens: [String] = ["complete meal"]
        tokens.append(contentsOf: roles.map(\.rawValue).sorted())
        if entry.calories >= 450 { tokens.append("substantial") }
        if entry.proteinGrams >= 24 { tokens.append("high protein") }
        tokens.append(normalizationService.normalizeFoodName(entry.name))
        tokens.append(contentsOf: entry.components.map { normalizationService.normalizeComponentName($0.displayName) })
        return normalizationService.normalizeFoodName(tokens.filter { !$0.isEmpty }.joined(separator: " "))
    }

    private func completeMealIntentText(for observation: FoodObservation) -> String {
        let roles = Set(observation.components.map(\.role))
        var tokens: [String] = ["complete meal"]
        tokens.append(contentsOf: roles.map(\.rawValue).sorted())
        if observation.calories >= 450 { tokens.append("substantial") }
        if observation.proteinGrams >= 24 { tokens.append("high protein") }
        tokens.append(observation.normalizedName)
        tokens.append(contentsOf: observation.components.map(\.canonicalName))
        return normalizationService.normalizeFoodName(tokens.filter { !$0.isEmpty }.joined(separator: " "))
    }

    private func isLiquidOnly(_ components: [SuggestedFoodComponent]) -> Bool {
        !components.isEmpty && components.allSatisfy { $0.role == FoodComponentRole.drink.rawValue }
    }

    private func isLiquidOnly(_ components: [FoodObservationComponent]) -> Bool {
        !components.isEmpty && components.allSatisfy { $0.role == .drink }
    }

    private func suggestionsOverlap(_ lhs: FoodSuggestion, _ rhs: FoodSuggestion) -> Bool {
        guard lhs.memoryID != rhs.memoryID else { return true }
        let lhsComponents = canonicalComponentSet(from: lhs.suggestedEntry.components)
        let rhsComponents = canonicalComponentSet(from: rhs.suggestedEntry.components)
        if !lhsComponents.isEmpty, lhsComponents == rhsComponents {
            return true
        }
        let lhsTitle = normalizationService.normalizeFoodName(lhs.title)
        let rhsTitle = normalizationService.normalizeFoodName(rhs.title)
        return !lhsTitle.isEmpty && lhsTitle == rhsTitle
    }

    private func canonicalComponentSet(from components: [SuggestedFoodComponent]) -> Set<String> {
        Set(components.map { normalizationService.normalizeComponentName($0.displayName) }.filter { !$0.isEmpty })
    }

    private func isCompleteMeal(_ entry: SuggestedFoodEntry) -> Bool {
        let roles = Set(entry.components.compactMap { $0.role.flatMap(FoodComponentRole.init(rawValue:)) })
        return (roles.contains(.protein) && (roles.contains(.carb) || roles.contains(.vegetable) || roles.contains(.fruit) || roles.contains(.mixed)))
            || (entry.calories >= 450 && entry.components.count >= 2)
    }
}

nonisolated private struct FoodRecommendationCompletion {
    let suggestions: [FoodSuggestion]
    let safeRecallCount: Int
    let occasionAlternateCount: Int
    let semanticSubstituteCount: Int
}
