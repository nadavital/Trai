import Foundation

nonisolated struct FoodPatternRankerDiagnostics: Sendable, Equatable {
    let suppressedOneOffCount: Int
    let suppressedAlreadyTodayCount: Int
    let demotedAlreadyTodayCount: Int
    let suppressedNegativeFeedbackCount: Int
    let suppressedLowConfidenceCount: Int
    let recallFallbackCount: Int
    let completeMealPromotionCount: Int
}

nonisolated struct FoodPatternRanker {
    private let normalizationService = FoodNormalizationService()
    private let semanticScorer = FoodSemanticSatisfactionScorer()

    func rank(_ candidates: [FoodPatternSuggestion], context: FoodPatternRecommendationContext) -> [FoodPatternSuggestion] {
        selectionDetails(for: candidates, context: context).finalSelected
    }

    private func selectionDetails(
        for candidates: [FoodPatternSuggestion],
        context: FoodPatternRecommendationContext
    ) -> FoodPatternSelectionDetails {
        let precisionEligible = candidates.filter { !suppressionReasons(for: $0, context: context).isSuppressed }
        let sorted = bestPrecisionCandidateByPattern(precisionEligible)
        let precisionSelected = applyDiversityPolicy(to: sorted, limit: context.limit)
        var selected = applyCompleteMealProtection(selected: precisionSelected, candidates: sorted, limit: context.limit)

        guard selected.count < context.limit else {
            return FoodPatternSelectionDetails(precisionSelected: precisionSelected, finalSelected: selected)
        }

        let selectedPatternIDs = Set(selected.map(\.pattern.id))
        let recallEligible = candidates.filter { candidate in
            guard !selectedPatternIDs.contains(candidate.pattern.id) else { return false }
            return isRecallEligible(candidate, context: context)
        }
        let recallSorted = bestRecallCandidateByPattern(recallEligible).filter { recallScore($0.features) >= 0.52 }
        guard !recallSorted.isEmpty else {
            return FoodPatternSelectionDetails(precisionSelected: precisionSelected, finalSelected: selected)
        }

        selected = applyDiversityPolicy(to: selected + recallSorted, limit: context.limit)
        selected = applyCompleteMealProtection(selected: selected, candidates: sorted + recallSorted, limit: context.limit)
        return FoodPatternSelectionDetails(precisionSelected: precisionSelected, finalSelected: selected)
    }

    private func bestPrecisionCandidateByPattern(_ candidates: [FoodPatternSuggestion]) -> [FoodPatternSuggestion] {
        let bestByPattern = Dictionary(grouping: candidates, by: \.pattern.id).compactMap { _, candidates in
            candidates.max { $0.score < $1.score }
        }
        return bestByPattern.sorted {
            if $0.score != $1.score {
                return $0.score > $1.score
            }
            return $0.pattern.lastObservedAt > $1.pattern.lastObservedAt
        }
    }

    private func bestRecallCandidateByPattern(_ candidates: [FoodPatternSuggestion]) -> [FoodPatternSuggestion] {
        let bestByPattern = Dictionary(grouping: candidates, by: \.pattern.id).compactMap { _, candidates in
            candidates.max { recallScore($0.features) < recallScore($1.features) }
        }
        return bestByPattern.sorted {
            let lhsRecall = recallScore($0.features)
            let rhsRecall = recallScore($1.features)
            if lhsRecall != rhsRecall {
                return lhsRecall > rhsRecall
            }
            return $0.pattern.lastObservedAt > $1.pattern.lastObservedAt
        }
    }

    func diagnostics(
        for candidates: [FoodPatternSuggestion],
        context: FoodPatternRecommendationContext
    ) -> FoodPatternRankerDiagnostics {
        var oneOff = Set<String>()
        var alreadyToday = Set<String>()
        var demotedAlreadyToday = Set<String>()
        var negative = Set<String>()
        var lowConfidence = Set<String>()

        for candidate in candidates {
            let reasons = suppressionReasons(for: candidate, context: context)
            if reasons.oneOff { oneOff.insert(candidate.pattern.id) }
            if reasons.alreadyToday { alreadyToday.insert(candidate.pattern.id) }
            if reasons.demotedAlreadyToday { demotedAlreadyToday.insert(candidate.pattern.id) }
            if reasons.negativeFeedback { negative.insert(candidate.pattern.id) }
            if reasons.lowConfidence { lowConfidence.insert(candidate.pattern.id) }
        }

        let selectionDetails = selectionDetails(for: candidates, context: context)
        let precisionSelectedIDs = Set(selectionDetails.precisionSelected.map(\.pattern.id))
        let finalSelectedIDs = Set(selectionDetails.finalSelected.map(\.pattern.id))
        let precisionMealIDs = Set(selectionDetails.precisionSelected.filter { isCompleteMeal($0.pattern) }.map(\.pattern.id))
        let finalMealIDs = Set(selectionDetails.finalSelected.filter { isCompleteMeal($0.pattern) }.map(\.pattern.id))

        return FoodPatternRankerDiagnostics(
            suppressedOneOffCount: oneOff.count,
            suppressedAlreadyTodayCount: alreadyToday.count,
            demotedAlreadyTodayCount: demotedAlreadyToday.count,
            suppressedNegativeFeedbackCount: negative.count,
            suppressedLowConfidenceCount: lowConfidence.count,
            recallFallbackCount: finalSelectedIDs.subtracting(precisionSelectedIDs).count,
            completeMealPromotionCount: finalMealIDs.subtracting(precisionMealIDs).count
        )
    }

    func features(
        for pattern: FoodPattern,
        sourceBoost: Double,
        context: FoodPatternRecommendationContext
    ) -> FoodPatternRankingFeatures {
        FoodPatternRankingFeatures(
            repetition: min(Double(pattern.distinctDays) / 6.0, 1),
            recency: Self.recencyScore(for: pattern, targetDate: context.targetDate),
            timeSupport: Self.timeSupport(for: pattern, targetDate: context.targetDate),
            temporalMismatchPenalty: temporalMismatchPenalty(for: pattern, targetDate: context.targetDate),
            opportunityPenalty: opportunityState(for: pattern, context: context).rankingPenalty,
            dayTypeSupport: Self.dayTypeSupport(for: pattern, targetDate: context.targetDate),
            sessionSupport: Self.sessionSupport(for: pattern, context: context),
            patternConfidence: patternConfidence(for: pattern),
            practicalUtility: practicalUtility(for: pattern),
            positiveFeedback: min(Double(pattern.feedbackProfile.timesAccepted + pattern.feedbackProfile.timesRefined) / 3.0, 1),
            negativeFeedbackPenalty: negativeFeedbackPenalty(for: pattern, now: context.now),
            sourceBoost: sourceBoost
        )
    }

    func score(_ features: FoodPatternRankingFeatures) -> Double {
        let rawScore =
            0.16 * features.repetition +
            0.10 * features.recency +
            0.24 * features.timeSupport +
            0.06 * features.dayTypeSupport +
            0.15 * features.sessionSupport +
            0.12 * features.patternConfidence +
            0.11 * features.practicalUtility +
            0.08 * features.positiveFeedback +
            features.sourceBoost -
            features.temporalMismatchPenalty -
            features.opportunityPenalty -
            features.negativeFeedbackPenalty
        return min(max(rawScore, 0), 1)
    }

    func recallScore(_ features: FoodPatternRankingFeatures) -> Double {
        let temporalEvidence = max(features.timeSupport, features.dayTypeSupport * 0.65)
        let rawScore =
            0.24 * features.repetition +
            0.16 * features.recency +
            0.20 * temporalEvidence +
            0.11 * features.sessionSupport +
            0.13 * features.patternConfidence +
            0.13 * features.practicalUtility +
            0.06 * features.positiveFeedback +
            features.sourceBoost -
            min(features.temporalMismatchPenalty, 0.08) -
            features.opportunityPenalty -
            features.negativeFeedbackPenalty
        return min(max(rawScore, 0), 1)
    }

    private func suppressionReasons(
        for suggestion: FoodPatternSuggestion,
        context: FoodPatternRecommendationContext
    ) -> FoodPatternSuppressionReasons {
        let pattern = suggestion.pattern
        let opportunityState = opportunityState(for: pattern, context: context)
        let oneOff = suggestion.source != .continueSession
            && pattern.distinctDays < 2
            && pattern.feedbackProfile.timesAccepted == 0
            && pattern.feedbackProfile.timesRefined == 0
        let alreadyToday = opportunityState.availability == .suppress
        let demotedAlreadyToday = opportunityState.availability == .demote
        let negativeFeedback = suggestion.features.negativeFeedbackPenalty >= 1.0
        let lowConfidence = suggestion.features.patternConfidence < 0.42
            && suggestion.features.sessionSupport < 0.55
            && suggestion.features.positiveFeedback == 0
        let weakSimpleRepeat = isLowSubstantiality(pattern)
            && suggestion.features.timeSupport < 0.18
            && suggestion.features.sessionSupport == 0
            && pattern.distinctDays < 4
            && suggestion.features.positiveFeedback == 0

        return FoodPatternSuppressionReasons(
            oneOff: oneOff,
            alreadyToday: alreadyToday,
            demotedAlreadyToday: demotedAlreadyToday,
            negativeFeedback: negativeFeedback,
            lowConfidence: lowConfidence || weakSimpleRepeat
        )
    }

    private func isRecallEligible(
        _ suggestion: FoodPatternSuggestion,
        context: FoodPatternRecommendationContext
    ) -> Bool {
        let reasons = suppressionReasons(for: suggestion, context: context)
        guard !reasons.oneOff,
              !reasons.alreadyToday,
              !reasons.negativeFeedback
        else {
            return false
        }
        guard suggestion.pattern.distinctDays >= 2 || suggestion.features.positiveFeedback > 0 else {
            return false
        }
        return recallScore(suggestion.features) >= 0.52
    }

    private func applyDiversityPolicy(
        to sorted: [FoodPatternSuggestion],
        limit: Int
    ) -> [FoodPatternSuggestion] {
        guard limit > 0 else { return [] }
        let hasSubstantial = sorted.contains { isSubstantial($0.pattern) }
        let bestSubstantialScore = sorted.first(where: { isSubstantial($0.pattern) })?.score
        var selected: [FoodPatternSuggestion] = []
        var deferred: [FoodPatternSuggestion] = []
        var lowSubstantialityCount = 0
        let lowSubstantialityLimit = hasSubstantial ? max(1, limit - 1) : limit

        for suggestion in sorted {
            let lowSubstantiality = isLowSubstantiality(suggestion.pattern)

            if lowSubstantiality && lowSubstantialityCount >= lowSubstantialityLimit {
                deferred.append(suggestion)
                continue
            }
            if hasSubstantial,
               selected.isEmpty,
               lowSubstantiality,
               bestSubstantialScore.map({ $0 >= suggestion.score - 0.08 }) == true {
                deferred.append(suggestion)
                continue
            }

            selected.append(suggestion)
            if lowSubstantiality { lowSubstantialityCount += 1 }
            if selected.count >= limit { break }
        }

        guard selected.count < limit else { return selected }
        for suggestion in deferred where !selected.contains(where: { $0.pattern.id == suggestion.pattern.id }) {
            let lowSubstantiality = isLowSubstantiality(suggestion.pattern)
            if lowSubstantiality && lowSubstantialityCount >= lowSubstantialityLimit {
                continue
            }
            selected.append(suggestion)
            if lowSubstantiality { lowSubstantialityCount += 1 }
            if selected.count >= limit { break }
        }
        return selected
    }

    private func applyCompleteMealProtection(
        selected: [FoodPatternSuggestion],
        candidates: [FoodPatternSuggestion],
        limit: Int
    ) -> [FoodPatternSuggestion] {
        guard limit > 0,
              !selected.prefix(limit).contains(where: { isCompleteMeal($0.pattern) }),
              let protectedMeal = candidates.first(where: { candidate in
                  isCompleteMeal(candidate.pattern)
                      && !selected.contains(where: { $0.pattern.id == candidate.pattern.id })
                      && isCompleteMealProtectionEligible(candidate, selected: Array(selected.prefix(limit)))
              })
        else {
            return selected
        }

        var output = selected
        if output.count < limit {
            output.append(protectedMeal)
            return output
        }

        guard let replacementIndex = output.lastIndex(where: { !isCompleteMeal($0.pattern) && isLowSubstantiality($0.pattern) }) else {
            return output
        }
        output[replacementIndex] = protectedMeal
        return output
    }

    private func isCompleteMealProtectionEligible(
        _ candidate: FoodPatternSuggestion,
        selected: [FoodPatternSuggestion]
    ) -> Bool {
        let hasContextualSupport = candidate.source == .continueSession
            || candidate.features.timeSupport >= 0.18
            || candidate.features.sessionSupport >= 0.55
        guard hasContextualSupport else { return false }

        guard !selected.isEmpty else { return true }
        let weakestSelectedScore = selected.map(\.score).min() ?? 0
        let allSelectedAreLowSubstantiality = selected.allSatisfy { isLowSubstantiality($0.pattern) }
        if candidate.score >= max(0.45, weakestSelectedScore - 0.08) {
            return true
        }
        return allSelectedAreLowSubstantiality && candidate.score >= 0.42
    }

    private func opportunityState(
        for pattern: FoodPattern,
        context: FoodPatternRecommendationContext
    ) -> FoodPatternOpportunityState {
        let satisfiedTodayDates = context.todayObservations
            .filter { semanticallySatisfies(pattern: pattern, observation: $0) }
            .map(\.loggedAt)
            .sorted()
        guard let lastSatisfiedAt = satisfiedTodayDates.last else {
            return FoodPatternOpportunityState(availability: .eligible, rankingPenalty: 0)
        }

        let repeatEvidence = sameDayRepeatEvidence(for: pattern)
        guard repeatEvidence.repeatDayCount > 0 else {
            return FoodPatternOpportunityState(availability: .suppress, rankingPenalty: 1)
        }

        let minutesSinceLast = Calendar.current.dateComponents([.minute], from: lastSatisfiedAt, to: context.targetDate).minute ?? 0
        let learnedSpacing = repeatEvidence.learnedSpacingMinutes
        if repeatEvidence.repeatDayCount >= 2, minutesSinceLast >= learnedSpacing {
            return FoodPatternOpportunityState(availability: .eligible, rankingPenalty: 0)
        }

        let emergingRepeatWindow = max(90, learnedSpacing - 60)
        if minutesSinceLast >= emergingRepeatWindow {
            return FoodPatternOpportunityState(availability: .demote, rankingPenalty: 0.20)
        }

        return FoodPatternOpportunityState(availability: .suppress, rankingPenalty: 1)
    }

    private func sameDayRepeatEvidence(for pattern: FoodPattern) -> FoodPatternSameDayRepeatEvidence {
        let groupedByDay = Dictionary(grouping: pattern.observations) {
            Calendar.current.startOfDay(for: $0.loggedAt)
        }
        let repeatDays = groupedByDay.values.filter { observations in
            observations.count > 1 && minimumSpacingMinutes(in: observations) >= 90
        }
        return FoodPatternSameDayRepeatEvidence(
            repeatDayCount: repeatDays.count,
            learnedSpacingMinutes: learnedSameDayRepeatSpacingMinutes(for: repeatDays)
        )
    }

    private func minimumSpacingMinutes(in observations: [FoodObservation]) -> Int {
        let sortedDates = observations.map(\.loggedAt).sorted()
        guard sortedDates.count > 1 else { return 0 }
        return zip(sortedDates, sortedDates.dropFirst())
            .map { Calendar.current.dateComponents([.minute], from: $0, to: $1).minute ?? 0 }
            .min() ?? 0
    }

    private func learnedSameDayRepeatSpacingMinutes(for repeatDays: [[FoodObservation]]) -> Int {
        let spacings = repeatDays
            .map(minimumSpacingMinutes(in:))
            .filter { $0 > 0 }
            .sorted()
        guard !spacings.isEmpty else { return 120 }
        let middle = spacings.count / 2
        let median = spacings.count.isMultiple(of: 2)
            ? (spacings[middle - 1] + spacings[middle]) / 2
            : spacings[middle]
        return max(90, min(median, 360))
    }

    private func semanticallySatisfies(pattern: FoodPattern, observation: FoodObservation) -> Bool {
        let patternComponents = pattern.componentProfile.map(\.canonicalName).filter { !$0.isEmpty }
        let observationComponents = observation.components.map(\.canonicalName).filter { !$0.isEmpty }
        let exactComponentScore = FoodSemanticSatisfactionScorer.jaccard(
            lhs: Set(patternComponents),
            rhs: Set(observationComponents)
        )
        let componentSemanticScore = semanticScorer.componentSemanticSimilarity(
            candidateComponents: patternComponents,
            loggedComponents: observationComponents
        )
        let observationName = observation.normalizedName.isEmpty
            ? normalizationService.normalizeFoodName(observation.displayName)
            : observation.normalizedName
        let candidateNames = ([pattern.canonicalTitle] + pattern.aliases.map(\.displayName) + pattern.aliases.map(\.normalizedName))
            .map(normalizationService.normalizeFoodName)
        let nutrition = pattern.nutritionProfile
        return semanticScorer.decision(
            exactComponentScore: exactComponentScore,
            componentSemanticScore: componentSemanticScore,
            nameScore: semanticScorer.nameSimilarity(candidateNames: candidateNames, loggedName: observationName),
            macroScore: semanticScorer.macroSimilarity(
                candidate: FoodSemanticNutritionProfile(
                    calories: Double(nutrition.medianCalories),
                    proteinGrams: nutrition.medianProteinGrams,
                    carbsGrams: nutrition.medianCarbsGrams,
                    fatGrams: nutrition.medianFatGrams
                ),
                logged: FoodSemanticNutritionProfile(
                    calories: Double(observation.calories),
                    proteinGrams: observation.proteinGrams,
                    carbsGrams: observation.carbsGrams,
                    fatGrams: observation.fatGrams
                )
            ),
            servingScore: semanticScorer.servingSimilarity(
                candidate: pattern.servingProfile.map {
                    FoodSemanticServingProfile(
                        servingText: $0.commonServingText,
                        quantity: $0.commonQuantity,
                        unit: $0.commonUnit
                    )
                },
                logged: FoodSemanticServingProfile(
                    servingText: observation.servingText,
                    quantity: observation.servingQuantity,
                    unit: observation.servingUnit
                )
            )
        ).isSatisfied
    }

    private func temporalMismatchPenalty(for pattern: FoodPattern, targetDate: Date) -> Double {
        let topHourCount = pattern.timeProfile.hourCounts.max() ?? 0
        let specificity = Double(topHourCount) / Double(max(pattern.observationCount, 1))
        guard specificity >= 0.55 else { return 0 }
        let support = Self.timeSupport(for: pattern, targetDate: targetDate)
        guard support < 0.18 else { return 0 }
        return min((specificity - support) * 0.34, 0.30)
    }

    private func patternConfidence(for pattern: FoodPattern) -> Double {
        let componentStability = componentStability(for: pattern)
        let macroStability = macroStability(for: pattern)
        let identity = (
            pattern.identityEvidence.averageComponentAgreement +
            pattern.identityEvidence.averageMacroCompatibility +
            pattern.identityEvidence.averageServingCompatibility
        ) / 3.0
        return min(max((componentStability + macroStability + identity) / 3.0, 0), 1)
    }

    private func practicalUtility(for pattern: FoodPattern) -> Double {
        let nutrition = pattern.nutritionProfile
        let componentCount = pattern.componentProfile.count
        let roleCount = Set(pattern.componentProfile.map(\.role)).count
        let calorieScore = min(Double(nutrition.medianCalories) / 650.0, 1)
        let proteinScore = min(nutrition.medianProteinGrams / 38.0, 1)
        let structureScore = min(Double(componentCount) / 3.0, 1)
        let roleDiversityScore = min(Double(roleCount) / 3.0, 1)
        let base = 0.34 * calorieScore
            + 0.30 * proteinScore
            + 0.22 * structureScore
            + 0.14 * roleDiversityScore
        return min(max(base, 0), 1)
    }

    private func isSubstantial(_ pattern: FoodPattern) -> Bool {
        let nutrition = pattern.nutritionProfile
        let componentCount = pattern.componentProfile.count
        let hasMultipleFoodComponents = componentCount >= 2 && !isLiquidOnly(pattern)
        return nutrition.medianCalories >= 320 && nutrition.medianProteinGrams >= 14
            || nutrition.medianProteinGrams >= 22
            || hasMultipleFoodComponents && nutrition.medianCalories >= 260
    }

    private func isCompleteMeal(_ pattern: FoodPattern) -> Bool {
        let roles = Set(pattern.componentProfile.map(\.role))
        return roles.contains(.protein)
            && (roles.contains(.carb) || roles.contains(.vegetable) || roles.contains(.fruit) || roles.contains(.mixed))
            || pattern.nutritionProfile.medianCalories >= 450 && pattern.componentProfile.count >= 2
    }

    private func isLowSubstantiality(_ pattern: FoodPattern) -> Bool {
        !isSubstantial(pattern)
    }

    private func isLiquidOnly(_ pattern: FoodPattern) -> Bool {
        !pattern.componentProfile.isEmpty && pattern.componentProfile.allSatisfy { $0.role == .drink }
    }

    private func componentStability(for pattern: FoodPattern) -> Double {
        guard pattern.observationCount > 0 else { return 0 }
        let coreComponents = pattern.componentProfile.filter { $0.observationCount >= max(1, pattern.observationCount / 2) }
        return min(Double(coreComponents.count) / Double(max(pattern.componentProfile.count, 1)), 1)
    }

    private func macroStability(for pattern: FoodPattern) -> Double {
        let nutrition = pattern.nutritionProfile
        let calorieRange = Double(nutrition.upperCaloriesBound - nutrition.lowerCaloriesBound)
        let proteinRange = nutrition.upperProteinBound - nutrition.lowerProteinBound
        let carbsRange = nutrition.upperCarbsBound - nutrition.lowerCarbsBound
        let fatRange = nutrition.upperFatBound - nutrition.lowerFatBound
        let calorieScore = 1 - min(calorieRange / Double(max(nutrition.medianCalories, 1)), 1)
        let proteinScore = 1 - min(proteinRange / max(nutrition.medianProteinGrams, 1), 1)
        let carbsScore = 1 - min(carbsRange / max(nutrition.medianCarbsGrams, 1), 1)
        let fatScore = 1 - min(fatRange / max(nutrition.medianFatGrams, 1), 1)
        return max(0, (calorieScore + proteinScore + carbsScore + fatScore) / 4)
    }

    private func negativeFeedbackPenalty(for pattern: FoodPattern, now: Date) -> Double {
        if pattern.feedbackProfile.timesShown >= 4,
           pattern.feedbackProfile.timesAccepted == 0,
           pattern.feedbackProfile.timesDismissed == 0 {
            return 0.18
        }
        let ignoredPenalty = ignoredFeedbackPenalty(for: pattern, now: now)
        guard pattern.feedbackProfile.timesDismissed > pattern.feedbackProfile.timesAccepted else { return ignoredPenalty }
        guard let lastDismissedAt = pattern.feedbackProfile.lastDismissedAt else {
            return min(Double(pattern.feedbackProfile.timesDismissed) * 0.12, 0.5) + ignoredPenalty
        }
        let hours = Double(Calendar.current.dateComponents([.hour], from: lastDismissedAt, to: now).hour ?? 999)
        return (hours < 12 ? 1.0 : min(Double(pattern.feedbackProfile.timesDismissed) * 0.12, 0.5)) + ignoredPenalty
    }

    private func ignoredFeedbackPenalty(for pattern: FoodPattern, now: Date) -> Double {
        guard pattern.feedbackProfile.timesIgnored > pattern.feedbackProfile.timesAccepted + pattern.feedbackProfile.timesRefined else {
            return 0
        }
        guard let lastIgnoredAt = pattern.feedbackProfile.lastIgnoredAt else {
            return min(Double(pattern.feedbackProfile.timesIgnored) * 0.04, 0.16)
        }
        let hours = Double(Calendar.current.dateComponents([.hour], from: lastIgnoredAt, to: now).hour ?? 999)
        if hours < 6 {
            return min(Double(pattern.feedbackProfile.timesIgnored) * 0.06, 0.24)
        }
        if hours < 48 {
            return min(Double(pattern.feedbackProfile.timesIgnored) * 0.04, 0.16)
        }
        return 0
    }

    static func timeSupport(for pattern: FoodPattern, targetDate: Date) -> Double {
        let hour = Calendar.current.component(.hour, from: targetDate)
        let weights = [0: 1.0, 1: 0.75, 2: 0.45, 3: 0.20]
        let total = max(pattern.observationCount, 1)
        let weighted = weights.reduce(0.0) { partial, item in
            let offset = item.key
            let weight = item.value
            if offset == 0 {
                return partial + Double(pattern.timeProfile.hourCounts[safe: hour] ?? 0) * weight
            }
            let before = (hour - offset + 24) % 24
            let after = (hour + offset) % 24
            return partial
                + Double(pattern.timeProfile.hourCounts[safe: before] ?? 0) * weight
                + Double(pattern.timeProfile.hourCounts[safe: after] ?? 0) * weight
        }
        return min(weighted / Double(total), 1)
    }

    static func sessionSupport(for pattern: FoodPattern, context: FoodPatternRecommendationContext) -> Double {
        guard !context.currentSessionObservations.isEmpty else { return 0 }
        let patternComponents = Set(pattern.componentProfile.map(\.canonicalName).filter { !$0.isEmpty })
        guard !patternComponents.isEmpty else { return 0 }
        let currentComponentSets = context.currentSessionObservations.map {
            Set($0.components.map(\.canonicalName).filter { !$0.isEmpty })
        }
        if currentComponentSets.contains(where: { !$0.isEmpty && $0 == patternComponents }) {
            return 0
        }
        if currentComponentSets.contains(where: { !$0.isEmpty && $0.isSubset(of: patternComponents) && $0 != patternComponents }) {
            return min(max(Double(pattern.distinctDays) / 4.0, 0.55), 0.85)
        }

        let historicalSessions = Dictionary(
            grouping: context.observations.filter {
                guard let observedSessionID = $0.sessionID else { return false }
                return observedSessionID != context.sessionID
            },
            by: { $0.sessionID! }
        )
        var anchorSessionCount = 0
        var completionCount = 0
        for observations in historicalSessions.values {
            let sessionComponents = observations.map { Set($0.components.map(\.canonicalName).filter { !$0.isEmpty }) }
            guard currentComponentSets.allSatisfy({ current in
                sessionComponents.contains { componentSimilarity(lhs: current, rhs: $0) >= 0.67 }
            }) else {
                continue
            }
            anchorSessionCount += 1
            if sessionComponents.contains(where: { componentSimilarity(lhs: $0, rhs: patternComponents) >= 0.67 }) {
                completionCount += 1
            }
        }
        guard anchorSessionCount > 0 else { return 0 }
        return min(Double(completionCount) / Double(anchorSessionCount), 1)
    }

    private static func recencyScore(for pattern: FoodPattern, targetDate: Date) -> Double {
        let daysSinceLast = Double(max(Calendar.current.dateComponents([.day], from: pattern.lastObservedAt, to: targetDate).day ?? 0, 0))
        return max(0, 1 - min(daysSinceLast / 45.0, 1))
    }

    private static func dayTypeSupport(for pattern: FoodPattern, targetDate: Date) -> Double {
        let requestedWeekend = Calendar.current.isDateInWeekend(targetDate)
        let matching = requestedWeekend ? pattern.timeProfile.weekendCount : pattern.timeProfile.weekdayCount
        return min(Double(matching) / Double(max(pattern.observationCount, 1)), 1)
    }

    private static func componentSimilarity(lhs: Set<String>, rhs: Set<String>) -> Double {
        FoodSemanticSatisfactionScorer.jaccard(lhs: lhs, rhs: rhs)
    }
}

nonisolated private struct FoodPatternSuppressionReasons {
    let oneOff: Bool
    let alreadyToday: Bool
    let demotedAlreadyToday: Bool
    let negativeFeedback: Bool
    let lowConfidence: Bool

    var isSuppressed: Bool {
        oneOff || alreadyToday || negativeFeedback || lowConfidence
    }
}

nonisolated private struct FoodPatternSelectionDetails {
    let precisionSelected: [FoodPatternSuggestion]
    let finalSelected: [FoodPatternSuggestion]
}

nonisolated private enum FoodPatternOpportunityAvailability {
    case eligible
    case demote
    case suppress
}

nonisolated private struct FoodPatternOpportunityState {
    let availability: FoodPatternOpportunityAvailability
    let rankingPenalty: Double
}

nonisolated private struct FoodPatternSameDayRepeatEvidence {
    let repeatDayCount: Int
    let learnedSpacingMinutes: Int
}

nonisolated private extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}
