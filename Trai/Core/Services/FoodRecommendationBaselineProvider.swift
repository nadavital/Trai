import Foundation

nonisolated struct FoodRecommendationRecentRepeatBaselineProvider {
    func suggestions(
        entries: [FoodEntry],
        now: Date,
        limit: Int
    ) -> [FoodSuggestion] {
        guard limit > 0 else { return [] }
        let observations = FoodObservationBuilder()
            .observations(from: entries)
            .filter { $0.loggedAt < now }
        let grouped = Dictionary(grouping: observations, by: baselineSignature)
        let candidates = grouped.values.compactMap { observations -> FoodObservation? in
            let distinctDays = Set(observations.map { Calendar.current.startOfDay(for: $0.loggedAt) }).count
            guard observations.count >= 2, distinctDays >= 2 else { return nil }
            return observations.max { $0.loggedAt < $1.loggedAt }
        }

        return candidates
            .sorted { $0.loggedAt > $1.loggedAt }
            .prefix(limit)
            .map(baselineSuggestion)
    }

    private func baselineSignature(for observation: FoodObservation) -> String {
        let components = observation.components.map(\.canonicalName).filter { !$0.isEmpty }.sorted()
        if !components.isEmpty {
            return components.joined(separator: "|")
        }
        return observation.normalizedName
    }

    private func baselineSuggestion(from observation: FoodObservation) -> FoodSuggestion {
        let suggestedEntry = SuggestedFoodEntry(
            id: observation.entryID.uuidString,
            name: observation.displayName,
            calories: observation.calories,
            proteinGrams: observation.proteinGrams,
            carbsGrams: observation.carbsGrams,
            fatGrams: observation.fatGrams,
            fiberGrams: observation.fiberGrams,
            sugarGrams: observation.sugarGrams,
            servingSize: observation.servingText,
            emoji: observation.emoji,
            components: observation.components.map {
                SuggestedFoodComponent(
                    id: $0.id,
                    displayName: $0.displayName,
                    role: $0.role.rawValue,
                    calories: $0.calories,
                    proteinGrams: $0.proteinGrams,
                    carbsGrams: $0.carbsGrams,
                    fatGrams: $0.fatGrams,
                    fiberGrams: $0.fiberGrams,
                    sugarGrams: $0.sugarGrams,
                    confidence: "medium"
                )
            },
            mealKind: observation.kind.rawValue,
            notes: nil,
            confidence: "medium",
            schemaVersion: 2
        )
        return FoodSuggestion(
            memoryID: observation.linkedMemoryID ?? observation.entryID,
            title: observation.displayName,
            subtitle: "Recent repeat",
            detail: "\(Int(observation.proteinGrams.rounded()))g protein - \(observation.calories) cal",
            emoji: observation.emoji ?? "Food",
            relevanceScore: 0.5,
            suggestedEntry: suggestedEntry
        )
    }
}

nonisolated struct FoodRecommendationSafeRecallProvider {
    func suggestions(
        entries: [FoodEntry],
        now: Date,
        limit: Int
    ) -> [FoodSuggestion] {
        guard limit > 0 else { return [] }
        let observations = FoodObservationBuilder()
            .observations(from: entries)
        return suggestions(observations: observations, now: now, limit: limit)
    }

    func suggestions(
        observations: [FoodObservation],
        now: Date,
        limit: Int
    ) -> [FoodSuggestion] {
        guard limit > 0 else { return [] }
        let eligibleObservations = observations.filter { $0.loggedAt < now }
        let grouped = Dictionary(grouping: eligibleObservations, by: recallSignature)
        let candidates = grouped.values.compactMap { observations -> RecallCandidate? in
            let sorted = observations.sorted { $0.loggedAt < $1.loggedAt }
            let distinctDays = Set(sorted.map { Calendar.current.startOfDay(for: $0.loggedAt) }).count
            guard sorted.count >= 2, distinctDays >= 2, let representative = sorted.last else { return nil }
            guard !wasAlreadyLoggedToday(sorted, now: now) else { return nil }

            let score = recallScore(observations: sorted, representative: representative, now: now)
            guard score >= 0.40 else { return nil }
            if isLiquidOnly(representative), timeSupport(observations: sorted, now: now) < 0.35 {
                return nil
            }
            return RecallCandidate(observation: representative, score: score)
        }

        return candidates
            .sorted {
                if $0.score != $1.score { return $0.score > $1.score }
                return $0.observation.loggedAt > $1.observation.loggedAt
            }
            .prefix(limit)
            .map(recallSuggestion)
    }

    private func recallSignature(for observation: FoodObservation) -> String {
        let components = observation.components.map(\.canonicalName).filter { !$0.isEmpty }.sorted()
        if !components.isEmpty {
            return components.joined(separator: "|")
        }
        return observation.normalizedName
    }

    private func wasAlreadyLoggedToday(_ observations: [FoodObservation], now: Date) -> Bool {
        let startOfDay = Calendar.current.startOfDay(for: now)
        return observations.contains { $0.loggedAt >= startOfDay && $0.loggedAt < now }
    }

    private func recallScore(
        observations: [FoodObservation],
        representative: FoodObservation,
        now: Date
    ) -> Double {
        let repetition = min(Double(Set(observations.map { Calendar.current.startOfDay(for: $0.loggedAt) }).count) / 6.0, 1)
        let daysSinceLast = Double(max(Calendar.current.dateComponents([.day], from: representative.loggedAt, to: now).day ?? 0, 0))
        let recency = max(0, 1 - min(daysSinceLast / 30.0, 1))
        let temporal = max(timeSupport(observations: observations, now: now), dayTypeSupport(observations: observations, now: now) * 0.7)
        let utility = practicalUtility(representative)
        let score = 0.25 * repetition
            + 0.22 * recency
            + 0.23 * temporal
            + 0.30 * utility
        return min(max(score, 0), 1)
    }

    private func timeSupport(observations: [FoodObservation], now: Date) -> Double {
        let hour = Calendar.current.component(.hour, from: now)
        let weights = [0: 1.0, 1: 0.75, 2: 0.45, 3: 0.20]
        let weighted = observations.reduce(0.0) { partial, observation in
            let observedHour = Calendar.current.component(.hour, from: observation.loggedAt)
            let distance = min(abs(observedHour - hour), 24 - abs(observedHour - hour))
            return partial + (weights[distance] ?? 0)
        }
        return min(weighted / Double(max(observations.count, 1)), 1)
    }

    private func dayTypeSupport(observations: [FoodObservation], now: Date) -> Double {
        let targetIsWeekend = Calendar.current.isDateInWeekend(now)
        let matching = observations.filter { Calendar.current.isDateInWeekend($0.loggedAt) == targetIsWeekend }
        return Double(matching.count) / Double(max(observations.count, 1))
    }

    private func practicalUtility(_ observation: FoodObservation) -> Double {
        let roles = Set(observation.components.map(\.role))
        let componentCount = observation.components.count
        let calorieScore = min(Double(observation.calories) / 650.0, 1)
        let proteinScore = min(observation.proteinGrams / 38.0, 1)
        let structureScore = min(Double(componentCount) / 3.0, 1)
        let roleDiversityScore = min(Double(roles.count) / 3.0, 1)
        let base = 0.34 * calorieScore
            + 0.30 * proteinScore
            + 0.22 * structureScore
            + 0.14 * roleDiversityScore
        return isLiquidOnly(observation) ? min(base, 0.42) : min(max(base, 0), 1)
    }

    private func isLiquidOnly(_ observation: FoodObservation) -> Bool {
        !observation.components.isEmpty && observation.components.allSatisfy { $0.role == .drink }
    }

    private func recallSuggestion(from candidate: RecallCandidate) -> FoodSuggestion {
        let observation = candidate.observation
        let suggestedEntry = SuggestedFoodEntry(
            id: observation.entryID.uuidString,
            name: observation.displayName,
            calories: observation.calories,
            proteinGrams: observation.proteinGrams,
            carbsGrams: observation.carbsGrams,
            fatGrams: observation.fatGrams,
            fiberGrams: observation.fiberGrams,
            sugarGrams: observation.sugarGrams,
            servingSize: observation.servingText,
            emoji: observation.emoji,
            components: observation.components.map {
                SuggestedFoodComponent(
                    id: $0.id,
                    displayName: $0.displayName,
                    role: $0.role.rawValue,
                    calories: $0.calories,
                    proteinGrams: $0.proteinGrams,
                    carbsGrams: $0.carbsGrams,
                    fatGrams: $0.fatGrams,
                    fiberGrams: $0.fiberGrams,
                    sugarGrams: $0.sugarGrams,
                    confidence: "medium"
                )
            },
            mealKind: observation.kind.rawValue,
            notes: nil,
            confidence: "medium",
            schemaVersion: 2
        )
        return FoodSuggestion(
            memoryID: observation.linkedMemoryID ?? observation.entryID,
            title: observation.displayName,
            subtitle: "Likely repeat",
            detail: "\(Int(observation.proteinGrams.rounded()))g protein - \(observation.calories) cal",
            emoji: observation.emoji ?? "Food",
            relevanceScore: 0.42 + min(candidate.score, 1) * 0.20,
            suggestedEntry: suggestedEntry
        )
    }
}

nonisolated struct FoodRecommendationOccasionAlternateProvider {
    func suggestions(
        entries: [FoodEntry],
        now: Date,
        limit: Int
    ) -> [FoodSuggestion] {
        guard limit > 0 else { return [] }
        let observations = FoodObservationBuilder()
            .observations(from: entries)
        return suggestions(observations: observations, now: now, limit: limit)
    }

    func suggestions(
        observations: [FoodObservation],
        now: Date,
        limit: Int
    ) -> [FoodSuggestion] {
        guard limit > 0 else { return [] }
        let eligibleObservations = observations.filter { $0.loggedAt < now }
        let grouped = Dictionary(grouping: eligibleObservations, by: alternateSignature)
        let candidates = grouped.values.compactMap { observations -> RecallCandidate? in
            let sorted = observations.sorted { $0.loggedAt < $1.loggedAt }
            guard let representative = sorted.last else { return nil }
            guard isCompleteMeal(representative), !isLiquidOnly(representative) else { return nil }
            guard !wasAlreadyLoggedToday(sorted, now: now) else { return nil }
            guard timeSupport(observations: sorted, now: now) >= 0.32 else { return nil }

            let score = alternateScore(observations: sorted, representative: representative, now: now)
            guard score >= 0.58 else { return nil }
            return RecallCandidate(observation: representative, score: score)
        }

        return candidates
            .sorted {
                if $0.score != $1.score { return $0.score > $1.score }
                return $0.observation.loggedAt > $1.observation.loggedAt
            }
            .prefix(limit)
            .map(alternateSuggestion)
    }

    private func alternateSignature(for observation: FoodObservation) -> String {
        let components = observation.components.map(\.canonicalName).filter { !$0.isEmpty }.sorted()
        if !components.isEmpty {
            return components.joined(separator: "|")
        }
        return observation.normalizedName
    }

    private func wasAlreadyLoggedToday(_ observations: [FoodObservation], now: Date) -> Bool {
        let startOfDay = Calendar.current.startOfDay(for: now)
        return observations.contains { $0.loggedAt >= startOfDay && $0.loggedAt < now }
    }

    private func alternateScore(
        observations: [FoodObservation],
        representative: FoodObservation,
        now: Date
    ) -> Double {
        let distinctDays = Set(observations.map { Calendar.current.startOfDay(for: $0.loggedAt) }).count
        let repetition = min(Double(distinctDays) / 4.0, 1)
        let daysSinceLast = Double(max(Calendar.current.dateComponents([.day], from: representative.loggedAt, to: now).day ?? 0, 0))
        let recency = max(0, 1 - min(daysSinceLast / 45.0, 1))
        let temporal = 0.82 * timeSupport(observations: observations, now: now)
            + 0.18 * dayTypeSupport(observations: observations, now: now)
        let utility = practicalUtility(representative)
        let evidenceFloor = distinctDays >= 2 ? 0.12 : 0
        let score = 0.18 * repetition
            + 0.18 * recency
            + 0.34 * temporal
            + 0.26 * utility
            + evidenceFloor
        return min(max(score, 0), 1)
    }

    private func timeSupport(observations: [FoodObservation], now: Date) -> Double {
        let hour = Calendar.current.component(.hour, from: now)
        let weights = [0: 1.0, 1: 0.80, 2: 0.55, 3: 0.32, 4: 0.16]
        let weighted = observations.reduce(0.0) { partial, observation in
            let observedHour = Calendar.current.component(.hour, from: observation.loggedAt)
            let distance = min(abs(observedHour - hour), 24 - abs(observedHour - hour))
            return partial + (weights[distance] ?? 0)
        }
        return min(weighted / Double(max(observations.count, 1)), 1)
    }

    private func dayTypeSupport(observations: [FoodObservation], now: Date) -> Double {
        let targetIsWeekend = Calendar.current.isDateInWeekend(now)
        let matching = observations.filter { Calendar.current.isDateInWeekend($0.loggedAt) == targetIsWeekend }
        return Double(matching.count) / Double(max(observations.count, 1))
    }

    private func practicalUtility(_ observation: FoodObservation) -> Double {
        let roles = Set(observation.components.map(\.role))
        let componentCount = observation.components.count
        let calorieScore = min(Double(observation.calories) / 650.0, 1)
        let proteinScore = min(observation.proteinGrams / 38.0, 1)
        let structureScore = min(Double(componentCount) / 3.0, 1)
        let roleDiversityScore = min(Double(roles.count) / 3.0, 1)
        return min(max(
            0.32 * calorieScore
                + 0.30 * proteinScore
                + 0.22 * structureScore
                + 0.16 * roleDiversityScore,
            0
        ), 1)
    }

    private func isCompleteMeal(_ observation: FoodObservation) -> Bool {
        let roles = Set(observation.components.map(\.role))
        return (roles.contains(.protein) && (roles.contains(.carb) || roles.contains(.vegetable) || roles.contains(.fruit) || roles.contains(.mixed)))
            || (observation.calories >= 450 && observation.components.count >= 2)
    }

    private func isLiquidOnly(_ observation: FoodObservation) -> Bool {
        !observation.components.isEmpty && observation.components.allSatisfy { $0.role == .drink }
    }

    private func alternateSuggestion(from candidate: RecallCandidate) -> FoodSuggestion {
        let observation = candidate.observation
        let suggestedEntry = SuggestedFoodEntry(
            id: observation.entryID.uuidString,
            name: observation.displayName,
            calories: observation.calories,
            proteinGrams: observation.proteinGrams,
            carbsGrams: observation.carbsGrams,
            fatGrams: observation.fatGrams,
            fiberGrams: observation.fiberGrams,
            sugarGrams: observation.sugarGrams,
            servingSize: observation.servingText,
            emoji: observation.emoji,
            components: observation.components.map {
                SuggestedFoodComponent(
                    id: $0.id,
                    displayName: $0.displayName,
                    role: $0.role.rawValue,
                    calories: $0.calories,
                    proteinGrams: $0.proteinGrams,
                    carbsGrams: $0.carbsGrams,
                    fatGrams: $0.fatGrams,
                    fiberGrams: $0.fiberGrams,
                    sugarGrams: $0.sugarGrams,
                    confidence: "medium"
                )
            },
            mealKind: observation.kind.rawValue,
            notes: nil,
            confidence: "medium",
            schemaVersion: 2
        )
        return FoodSuggestion(
            memoryID: observation.linkedMemoryID ?? observation.entryID,
            title: observation.displayName,
            subtitle: "Fits this moment",
            detail: "\(Int(observation.proteinGrams.rounded()))g protein - \(observation.calories) cal",
            emoji: observation.emoji ?? "Food",
            relevanceScore: 0.46 + min(candidate.score, 1) * 0.24,
            suggestedEntry: suggestedEntry
        )
    }
}

nonisolated struct FoodRecommendationSemanticSubstituteProvider {
    private let semanticScorer = FoodSemanticSatisfactionScorer()
    private let normalizationService = FoodNormalizationService()

    func suggestions(
        entries: [FoodEntry],
        now: Date,
        limit: Int
    ) -> [FoodSuggestion] {
        guard limit > 0 else { return [] }
        let observations = FoodObservationBuilder()
            .observations(from: entries)
        return suggestions(observations: observations, now: now, limit: limit)
    }

    func suggestions(
        observations: [FoodObservation],
        now: Date,
        limit: Int
    ) -> [FoodSuggestion] {
        guard limit > 0 else { return [] }
        let eligibleObservations = observations.filter { $0.loggedAt < now }
        let groups = Dictionary(grouping: eligibleObservations, by: substituteSignature)
            .values
            .compactMap { SubstituteGroup(observations: $0.sorted { $0.loggedAt < $1.loggedAt }) }
        let anchors = groups.filter { isStrongAnchor($0, now: now) }
        guard !anchors.isEmpty else { return [] }

        let candidates = groups.compactMap { group -> SubstituteCandidate? in
            let representative = group.representative
            guard isCompleteMeal(representative), !isLiquidOnly(representative) else { return nil }
            guard !wasAlreadyLoggedToday(group.observations, now: now) else { return nil }

            let bestAnchor = anchors
                .filter { $0.signature != group.signature }
                .map { anchor in
                    (
                        anchor: anchor,
                        score: substituteScore(candidate: group, anchor: anchor, now: now)
                    )
                }
                .max {
                    if $0.score != $1.score { return $0.score < $1.score }
                    return $0.anchor.representative.loggedAt < $1.anchor.representative.loggedAt
                }
            guard let bestAnchor, bestAnchor.score >= 0.61 else { return nil }
            return SubstituteCandidate(group: group, anchor: bestAnchor.anchor, score: bestAnchor.score)
        }

        return candidates
            .sorted {
                if $0.score != $1.score { return $0.score > $1.score }
                return $0.group.representative.loggedAt > $1.group.representative.loggedAt
            }
            .prefix(limit)
            .map(substituteSuggestion)
    }

    private func substituteSignature(for observation: FoodObservation) -> String {
        let components = observation.components.map(\.canonicalName).filter { !$0.isEmpty }.sorted()
        if !components.isEmpty {
            return components.joined(separator: "|")
        }
        return observation.normalizedName
    }

    private func isStrongAnchor(_ group: SubstituteGroup, now: Date) -> Bool {
        let representative = group.representative
        guard isCompleteMeal(representative), !isLiquidOnly(representative) else { return false }
        guard group.distinctDayCount >= 2 else { return false }
        return timeSupport(observations: group.observations, now: now) >= 0.42
    }

    private func substituteScore(candidate: SubstituteGroup, anchor: SubstituteGroup, now: Date) -> Double {
        let candidateObservation = candidate.representative
        let anchorObservation = anchor.representative

        let semanticSimilarity = foodIntentSimilarity(candidate: candidateObservation, anchor: anchorObservation)
        guard semanticSimilarity >= 0.46 else { return 0 }
        let macroSimilarity = semanticScorer.macroSimilarity(
            candidate: nutritionProfile(for: candidateObservation),
            logged: nutritionProfile(for: anchorObservation)
        )
        let candidateTime = timeSupport(observations: candidate.observations, now: now)
        let anchorTime = timeSupport(observations: anchor.observations, now: now)
        let temporalFit = 0.72 * anchorTime + 0.28 * max(candidateTime, dayTypeSupport(observations: candidate.observations, now: now) * 0.75)
        let candidateEvidence = min(Double(candidate.distinctDayCount) / 3.0, 1)
        let utility = practicalUtility(candidateObservation)
        let recency = recencyScore(candidateObservation.loggedAt, now: now, horizonDays: 45)

        let score = 0.34 * semanticSimilarity
            + 0.18 * macroSimilarity
            + 0.18 * temporalFit
            + 0.12 * utility
            + 0.10 * recency
            + 0.08 * candidateEvidence
        return min(max(score, 0), 1)
    }

    private func foodIntentSimilarity(candidate: FoodObservation, anchor: FoodObservation) -> Double {
        let candidateComponents = candidate.components.map(\.canonicalName).filter { !$0.isEmpty }
        let anchorComponents = anchor.components.map(\.canonicalName).filter { !$0.isEmpty }
        let componentScore = max(
            FoodSemanticSatisfactionScorer.jaccard(lhs: Set(candidateComponents), rhs: Set(anchorComponents)),
            semanticScorer.componentSemanticSimilarity(
                candidateComponents: candidateComponents,
                loggedComponents: anchorComponents
            )
        )
        let nameScore = semanticScorer.nameSimilarity(
            candidateNames: [
                candidate.normalizedName,
                normalizedIntentText(for: candidate)
            ],
            loggedName: normalizedIntentText(for: anchor)
        )
        let roleScore = FoodSemanticSatisfactionScorer.jaccard(
            lhs: Set(candidate.components.map(\.role)),
            rhs: Set(anchor.components.map(\.role))
        )
        return 0.48 * componentScore
            + 0.30 * nameScore
            + 0.22 * roleScore
    }

    private func normalizedIntentText(for observation: FoodObservation) -> String {
        let roles = Set(observation.components.map(\.role))
        var tokens: [String] = []
        if isCompleteMeal(observation) { tokens.append("complete meal") }
        if roles.contains(.protein) { tokens.append("protein") }
        if roles.contains(.carb) { tokens.append("carb") }
        if roles.contains(.vegetable) || roles.contains(.fruit) { tokens.append("produce") }
        if observation.calories >= 450 { tokens.append("substantial") }
        if observation.proteinGrams >= 24 { tokens.append("high protein") }
        tokens.append(observation.normalizedName)
        tokens.append(contentsOf: observation.components.map(\.canonicalName).filter { !$0.isEmpty })
        return normalizationService.normalizeFoodName(tokens.joined(separator: " "))
    }

    private func nutritionProfile(for observation: FoodObservation) -> FoodSemanticNutritionProfile {
        FoodSemanticNutritionProfile(
            calories: Double(observation.calories),
            proteinGrams: observation.proteinGrams,
            carbsGrams: observation.carbsGrams,
            fatGrams: observation.fatGrams
        )
    }

    private func wasAlreadyLoggedToday(_ observations: [FoodObservation], now: Date) -> Bool {
        let startOfDay = Calendar.current.startOfDay(for: now)
        return observations.contains { $0.loggedAt >= startOfDay && $0.loggedAt < now }
    }

    private func timeSupport(observations: [FoodObservation], now: Date) -> Double {
        let hour = Calendar.current.component(.hour, from: now)
        let weights = [0: 1.0, 1: 0.82, 2: 0.58, 3: 0.34, 4: 0.18]
        let weighted = observations.reduce(0.0) { partial, observation in
            let observedHour = Calendar.current.component(.hour, from: observation.loggedAt)
            let distance = min(abs(observedHour - hour), 24 - abs(observedHour - hour))
            return partial + (weights[distance] ?? 0)
        }
        return min(weighted / Double(max(observations.count, 1)), 1)
    }

    private func dayTypeSupport(observations: [FoodObservation], now: Date) -> Double {
        let targetIsWeekend = Calendar.current.isDateInWeekend(now)
        let matching = observations.filter { Calendar.current.isDateInWeekend($0.loggedAt) == targetIsWeekend }
        return Double(matching.count) / Double(max(observations.count, 1))
    }

    private func recencyScore(_ date: Date, now: Date, horizonDays: Double) -> Double {
        let daysSinceLast = Double(max(Calendar.current.dateComponents([.day], from: date, to: now).day ?? 0, 0))
        return max(0, 1 - min(daysSinceLast / horizonDays, 1))
    }

    private func practicalUtility(_ observation: FoodObservation) -> Double {
        let roles = Set(observation.components.map(\.role))
        let calorieScore = min(Double(observation.calories) / 650.0, 1)
        let proteinScore = min(observation.proteinGrams / 38.0, 1)
        let structureScore = min(Double(observation.components.count) / 3.0, 1)
        let roleDiversityScore = min(Double(roles.count) / 3.0, 1)
        return min(max(
            0.32 * calorieScore
                + 0.30 * proteinScore
                + 0.22 * structureScore
                + 0.16 * roleDiversityScore,
            0
        ), 1)
    }

    private func isCompleteMeal(_ observation: FoodObservation) -> Bool {
        let roles = Set(observation.components.map(\.role))
        return (roles.contains(.protein) && (roles.contains(.carb) || roles.contains(.vegetable) || roles.contains(.fruit) || roles.contains(.mixed)))
            || (observation.calories >= 450 && observation.components.count >= 2)
    }

    private func isLiquidOnly(_ observation: FoodObservation) -> Bool {
        !observation.components.isEmpty && observation.components.allSatisfy { $0.role == .drink }
    }

    private func substituteSuggestion(from candidate: SubstituteCandidate) -> FoodSuggestion {
        let observation = candidate.group.representative
        let suggestedEntry = SuggestedFoodEntry(
            id: observation.entryID.uuidString,
            name: observation.displayName,
            calories: observation.calories,
            proteinGrams: observation.proteinGrams,
            carbsGrams: observation.carbsGrams,
            fatGrams: observation.fatGrams,
            fiberGrams: observation.fiberGrams,
            sugarGrams: observation.sugarGrams,
            servingSize: observation.servingText,
            emoji: observation.emoji,
            components: observation.components.map {
                SuggestedFoodComponent(
                    id: $0.id,
                    displayName: $0.displayName,
                    role: $0.role.rawValue,
                    calories: $0.calories,
                    proteinGrams: $0.proteinGrams,
                    carbsGrams: $0.carbsGrams,
                    fatGrams: $0.fatGrams,
                    fiberGrams: $0.fiberGrams,
                    sugarGrams: $0.sugarGrams,
                    confidence: "medium"
                )
            },
            mealKind: observation.kind.rawValue,
            notes: nil,
            confidence: "medium",
            schemaVersion: 2
        )
        return FoodSuggestion(
            memoryID: observation.linkedMemoryID ?? observation.entryID,
            title: observation.displayName,
            subtitle: "Similar fit",
            detail: "\(Int(observation.proteinGrams.rounded()))g protein - \(observation.calories) cal",
            emoji: observation.emoji ?? "Food",
            relevanceScore: 0.48 + min(candidate.score, 1) * 0.22,
            suggestedEntry: suggestedEntry
        )
    }
}

nonisolated private struct RecallCandidate {
    let observation: FoodObservation
    let score: Double
}

nonisolated private struct SubstituteGroup {
    let signature: String
    let observations: [FoodObservation]
    let representative: FoodObservation
    let distinctDayCount: Int

    init?(observations: [FoodObservation]) {
        guard let representative = observations.last else { return nil }
        self.signature = Self.signature(for: representative)
        self.observations = observations
        self.representative = representative
        self.distinctDayCount = Set(observations.map { Calendar.current.startOfDay(for: $0.loggedAt) }).count
    }

    private static func signature(for observation: FoodObservation) -> String {
        let components = observation.components.map(\.canonicalName).filter { !$0.isEmpty }.sorted()
        if !components.isEmpty {
            return components.joined(separator: "|")
        }
        return observation.normalizedName
    }
}

nonisolated private struct SubstituteCandidate {
    let group: SubstituteGroup
    let anchor: SubstituteGroup
    let score: Double
}
