import Foundation
import SwiftData

nonisolated struct FoodSuggestion: Identifiable, Sendable, Equatable {
    let memoryID: UUID
    let title: String
    let subtitle: String
    let detail: String
    let emoji: String
    let relevanceScore: Double
    let suggestedEntry: SuggestedFoodEntry

    var id: UUID { memoryID }

    func replacingMemoryID(_ memoryID: UUID) -> FoodSuggestion {
        FoodSuggestion(
            memoryID: memoryID,
            title: title,
            subtitle: subtitle,
            detail: detail,
            emoji: emoji,
            relevanceScore: relevanceScore,
            suggestedEntry: suggestedEntry
        )
    }
}

nonisolated struct FoodSuggestionDebugSummary: Sendable {
    let totalMemories: Int
    let totalObservations: Int
    let patternCount: Int
    let candidateCountBySource: [String: Int]
    let suppressedOneOffCount: Int
    let suppressedAlreadyTodayCount: Int
    let demotedAlreadyTodayCount: Int
    let directMemoryCandidateCount: Int
    let directSuppressedAlreadyTodayCount: Int
    let directDemotedAlreadyTodayCount: Int
    let directPassiveExposureDemotedCount: Int
    let retrievedCandidateCount: Int
    let suppressedNegativeFeedbackCount: Int
    let suppressedLowConfidenceCount: Int
    let recallFallbackCount: Int
    let occasionAlternateCount: Int
    let semanticSubstituteCount: Int
    let completeMealPromotionCount: Int
    let finalEligibleCount: Int
    let shownSuggestionTitles: [String]
}

nonisolated struct FoodSuggestionService {
    private static let cameraEntryFetchLimit = 180
    private let matcher = FoodMemoryMatcher()
    private let normalizationService = FoodNormalizationService()
    private let semanticScorer = FoodSemanticSatisfactionScorer()

    @MainActor
    func cameraSuggestions(
        limit: Int,
        now: Date = .now,
        targetDate: Date? = nil,
        sessionId: UUID? = nil,
        modelContext: ModelContext
    ) throws -> [FoodSuggestion] {
        try cameraSuggestionsOnCurrentActor(
            limit: limit,
            now: now,
            targetDate: targetDate,
            sessionId: sessionId,
            modelContext: modelContext
        )
    }

    func cameraSuggestions(
        limit: Int,
        now: Date = .now,
        targetDate: Date? = nil,
        sessionId: UUID? = nil,
        modelContainer: ModelContainer
    ) async throws -> [FoodSuggestion] {
        try await FoodSuggestionWorker().cameraSuggestions(
            limit: limit,
            now: now,
            targetDate: targetDate,
            sessionId: sessionId,
            modelContainer: modelContainer
        )
    }

    fileprivate func cameraSuggestionsOnCurrentActor(
        limit: Int,
        now: Date,
        targetDate: Date?,
        sessionId: UUID?,
        modelContext: ModelContext
    ) throws -> [FoodSuggestion] {
        guard limit > 0 else { return [] }
        let referenceDate = targetDate ?? now
        let memories = try fetchMemories(modelContext: modelContext)
        let entries = try fetchEntries(modelContext: modelContext)
        let suggestionFeedback = fetchSuggestionFeedback(modelContext: modelContext)
        let directSuggestions = directMemorySuggestions(
            memories: memories,
            entries: entries,
            now: now,
            targetDate: referenceDate,
            limit: limit
        )

        if sessionId == nil, directSuggestions.count >= limit {
            return Array(directSuggestions.prefix(limit))
        }

        let engineResult = FoodRecommendationEngine().recommendationsSync(
            for: FoodRecommendationRequest(
                now: now,
                targetDate: referenceDate,
                sessionID: sessionId,
                limit: limit,
                entries: entries,
                memories: memories,
                suggestionFeedback: suggestionFeedback
            )
        )
        let suggestions = try materializedEngineSuggestions(
            engineResult.suggestions,
            memories: memories
        )
        let completedSuggestions = completedSuggestions(
            engineSuggestions: suggestions,
            directSuggestions: directSuggestions,
            memories: memories,
            entries: entries,
            now: now,
            targetDate: referenceDate,
            sessionId: sessionId,
            limit: limit
        )
        return completedSuggestions
    }

    @MainActor
    func recordOutcome(
        _ outcome: FoodSuggestionOutcome,
        for memoryID: UUID,
        at: Date = .now,
        modelContext: ModelContext
    ) throws {
        try recordOutcomes(outcome, for: [memoryID], at: at, modelContext: modelContext)
    }

    @MainActor
    func recordOutcome(
        _ outcome: FoodSuggestionOutcome,
        for memoryIDs: [UUID],
        at: Date = .now,
        modelContext: ModelContext
    ) throws {
        try recordOutcomes(outcome, for: memoryIDs, at: at, modelContext: modelContext)
    }

    func recordOutcome(
        _ outcome: FoodSuggestionOutcome,
        for memoryIDs: [UUID],
        at: Date = .now,
        modelContainer: ModelContainer
    ) async throws {
        try await FoodSuggestionWorker().recordOutcome(
            outcome,
            for: memoryIDs,
            at: at,
            modelContainer: modelContainer
        )
    }

    @MainActor
    func reconcileShownSuggestions(
        _ shownMemoryIDs: [UUID],
        preferredMemoryID: UUID?,
        with savedSnapshot: AcceptedFoodSnapshot,
        isRefined: Bool,
        modelContext: ModelContext
    ) throws {
        let uniqueShownIDs = Array(Set(shownMemoryIDs))
        guard !uniqueShownIDs.isEmpty else { return }

        let shownIDSet = Set(uniqueShownIDs)
        let memories = try modelContext.fetch(FetchDescriptor<FoodMemory>())
        let shownMemories = memories.filter { shownIDSet.contains($0.id) }

        var matchedMemoryIDs = shownMemories.compactMap { memory in
            matcher.matches(memory: memory, snapshot: savedSnapshot) ? memory.id : nil
        }

        if matchedMemoryIDs.isEmpty,
           let preferredMemoryID,
           shownIDSet.contains(preferredMemoryID),
           !shownMemories.contains(where: { $0.id == preferredMemoryID }) {
            matchedMemoryIDs = memories.compactMap { memory in
                matcher.matches(memory: memory, snapshot: savedSnapshot) ? memory.id : nil
            }
        }

        if matchedMemoryIDs.isEmpty,
           let preferredMemoryID,
           shownIDSet.contains(preferredMemoryID),
           !isRefined {
            matchedMemoryIDs = [preferredMemoryID]
        }

        guard !matchedMemoryIDs.isEmpty else { return }

        try recordOutcomes(
            isRefined ? .refined : .accepted,
            for: matchedMemoryIDs,
            at: savedSnapshot.loggedAt,
            modelContext: modelContext
        )

        if matchedMemoryIDs.count > 1 {
            _ = try FoodMemoryService().consolidateDuplicateMemories(
                memoryIDs: matchedMemoryIDs,
                modelContext: modelContext
            )
        }
    }

    func debugCameraSuggestions(
        limit: Int = 3,
        now: Date = .now,
        targetDate: Date? = nil,
        sessionId: UUID? = nil,
        modelContext: ModelContext
    ) throws -> FoodSuggestionDebugSummary {
        let referenceDate = targetDate ?? now
        guard limit > 0 else {
            return emptyDebugSummary()
        }

        let memories = try fetchMemories(modelContext: modelContext)
        let entries = try fetchEntries(modelContext: modelContext)
        let suggestionFeedback = fetchSuggestionFeedback(modelContext: modelContext)
        let engineDebugReport = FoodRecommendationEngine().recommendationsSync(
            for: FoodRecommendationRequest(
                now: now,
                targetDate: referenceDate,
                sessionID: sessionId,
                limit: limit,
                entries: entries,
                memories: memories,
                suggestionFeedback: suggestionFeedback
            )
        ).debugReport

        let directDiagnostics = sessionId == nil
            ? directSuggestionDiagnostics(memories: memories, entries: entries, now: now, targetDate: referenceDate)
            : .empty

        return FoodSuggestionDebugSummary(
            totalMemories: memories.count,
            totalObservations: engineDebugReport.observationCount,
            patternCount: engineDebugReport.patternCount,
            candidateCountBySource: engineDebugReport.candidateCountBySource.reduce(into: [String: Int]()) {
                $0[$1.key.rawValue] = $1.value
            },
            suppressedOneOffCount: engineDebugReport.suppressedOneOffCount,
            suppressedAlreadyTodayCount: engineDebugReport.suppressedAlreadyTodayCount,
            demotedAlreadyTodayCount: engineDebugReport.demotedAlreadyTodayCount,
            directMemoryCandidateCount: directDiagnostics.candidateCount,
            directSuppressedAlreadyTodayCount: directDiagnostics.suppressedAlreadyTodayCount,
            directDemotedAlreadyTodayCount: directDiagnostics.demotedAlreadyTodayCount,
            directPassiveExposureDemotedCount: directDiagnostics.passiveExposureDemotedCount,
            retrievedCandidateCount: engineDebugReport.candidateCountBySource.values.reduce(0, +),
            suppressedNegativeFeedbackCount: engineDebugReport.suppressedNegativeFeedbackCount,
            suppressedLowConfidenceCount: engineDebugReport.suppressedLowConfidenceCount,
            recallFallbackCount: engineDebugReport.recallFallbackCount,
            occasionAlternateCount: engineDebugReport.occasionAlternateCount,
            semanticSubstituteCount: engineDebugReport.semanticSubstituteCount,
            completeMealPromotionCount: engineDebugReport.completeMealPromotionCount,
            finalEligibleCount: engineDebugReport.finalShownTitles.count,
            shownSuggestionTitles: engineDebugReport.finalShownTitles
        )
    }

    func debugCameraSuggestions(
        limit: Int = 3,
        now: Date = .now,
        targetDate: Date? = nil,
        sessionId: UUID? = nil,
        modelContainer: ModelContainer
    ) async throws -> FoodSuggestionDebugSummary {
        try await FoodSuggestionWorker().debugCameraSuggestions(
            limit: limit,
            now: now,
            targetDate: targetDate,
            sessionId: sessionId,
            modelContainer: modelContainer
        )
    }

    private func fetchMemories(modelContext: ModelContext) throws -> [FoodMemory] {
        try modelContext.fetch(
            FetchDescriptor<FoodMemory>(
                sortBy: [SortDescriptor(\FoodMemory.updatedAt, order: .reverse)]
            )
        )
    }

    private func fetchEntries(modelContext: ModelContext) throws -> [FoodEntry] {
        var descriptor = FetchDescriptor<FoodEntry>(
            sortBy: [SortDescriptor(\FoodEntry.loggedAt, order: .reverse)]
        )
        descriptor.fetchLimit = Self.cameraEntryFetchLimit
        return try modelContext.fetch(descriptor)
    }

    private func fetchSuggestionFeedback(modelContext: ModelContext) -> [FoodSuggestionFeedbackSnapshot] {
        do {
            return try modelContext.fetch(FetchDescriptor<FoodSuggestionFeedback>()).compactMap { feedback in
                guard let suggestionID = feedback.suggestionID,
                      let stats = feedback.stats
                else { return nil }
                return FoodSuggestionFeedbackSnapshot(suggestionID: suggestionID, stats: stats)
            }
        } catch {
            return []
        }
    }

    private func materializedEngineSuggestions(
        _ suggestions: [FoodSuggestion],
        memories: [FoodMemory]
    ) throws -> [FoodSuggestion] {
        guard !suggestions.isEmpty else { return [] }

        return suggestions.map { suggestion in
            guard !memories.contains(where: { $0.id == suggestion.memoryID }),
                  let existingMemory = memories.first(where: { memoryMatches($0, suggestion: suggestion) })
            else {
                return suggestion
            }
            return suggestion.replacingMemoryID(existingMemory.id)
        }
    }

    private func completedSuggestions(
        engineSuggestions: [FoodSuggestion],
        directSuggestions: [FoodSuggestion]? = nil,
        memories: [FoodMemory],
        entries: [FoodEntry],
        now: Date,
        targetDate: Date,
        sessionId: UUID?,
        limit: Int
    ) -> [FoodSuggestion] {
        guard limit > 0 else { return [] }
        let directSuggestions = directSuggestions ?? directMemorySuggestions(
            memories: memories,
            entries: entries,
            now: now,
            targetDate: targetDate,
            limit: limit
        )
        let merged = deduplicatedSuggestions(directSuggestions + engineSuggestions)
            .filter { sessionId != nil || isStandaloneSuggestion($0) }
            .sorted {
                if $0.relevanceScore != $1.relevanceScore {
                    return $0.relevanceScore > $1.relevanceScore
                }
                return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
        }
        return Array(merged.prefix(limit))
    }

    private func directMemorySuggestions(
        memories: [FoodMemory],
        entries: [FoodEntry],
        now: Date,
        targetDate: Date,
        limit: Int
    ) -> [FoodSuggestion] {
        guard limit > 0 else { return [] }
        return memories
            .compactMap { directSuggestion(from: $0, now: now, targetDate: targetDate, existingEntries: entries) }
            .sorted {
                if $0.relevanceScore != $1.relevanceScore {
                    return $0.relevanceScore > $1.relevanceScore
                }
                return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }
            .reduce(into: [FoodSuggestion]()) { output, suggestion in
                guard output.count < max(limit * 2, limit) else { return }
                if let existingIndex = output.firstIndex(where: { suggestionsOverlap($0, suggestion) }) {
                    if suggestion.relevanceScore > output[existingIndex].relevanceScore {
                        output[existingIndex] = suggestion
                    }
                } else {
                    output.append(suggestion)
                }
            }
    }

    private func directSuggestionDiagnostics(
        memories: [FoodMemory],
        entries: [FoodEntry],
        now: Date,
        targetDate: Date
    ) -> FoodDirectMemorySuggestionDiagnostics {
        return memories
            .reduce(into: FoodDirectMemorySuggestionDiagnostics.empty) { diagnostics, memory in
                guard isSuggestibleMemory(memory),
                      !isStale(memory, targetDate: targetDate) || hasPositiveFeedback(memory)
                else {
                    return
                }
                guard !hasRecentNegativeFeedback(memory, now: now) else { return }
                diagnostics.candidateCount += 1

                let opportunityState = opportunityState(for: memory, targetDate: targetDate, entries: entries)
                switch opportunityState.availability {
                case .eligible:
                    break
                case .demote:
                    diagnostics.demotedAlreadyTodayCount += 1
                case .suppress:
                    diagnostics.suppressedAlreadyTodayCount += 1
                    return
                }

                if passiveExposurePenalty(memory) > 0 {
                    diagnostics.passiveExposureDemotedCount += 1
                }
            }
    }

    private func directSuggestion(
        from memory: FoodMemory,
        now: Date,
        targetDate: Date,
        existingEntries: [FoodEntry]
    ) -> FoodSuggestion? {
        guard isSuggestibleMemory(memory) else { return nil }
        guard !hasRecentNegativeFeedback(memory, now: now) else { return nil }
        guard !isStale(memory, targetDate: targetDate) || hasPositiveFeedback(memory) else { return nil }
        let opportunityState = opportunityState(for: memory, targetDate: targetDate, entries: existingEntries)
        guard opportunityState.availability != .suppress else { return nil }

        let timeSupport = memoryTimeSupport(memory, targetDate: targetDate)
        let bucketSupport = memoryBucketSupport(memory, targetDate: targetDate)
        let strongHabit = isStrongUsefulHabit(memory)
        let shouldShow = timeSupport >= 0.20
            || bucketSupport >= 0.12
            || strongHabit
            || hasPositiveFeedback(memory)
            || (isEmergingUsefulMemory(memory) && max(timeSupport, bucketSupport) >= 0.15)
        guard shouldShow else { return nil }

        let entry = suggestedEntry(from: memory)
        let score = directSuggestionScore(
            memory: memory,
            now: now,
            targetDate: targetDate,
            timeSupport: timeSupport,
            bucketSupport: bucketSupport,
            opportunityState: opportunityState
        )
        return FoodSuggestion(
            memoryID: memory.id,
            title: memory.displayName,
            subtitle: directSuggestionSubtitle(targetDate: targetDate, timeSupport: timeSupport, bucketSupport: bucketSupport),
            detail: "\(Int(entry.proteinGrams.rounded()))g protein • \(entry.calories) cal",
            emoji: memory.emoji ?? "🍽️",
            relevanceScore: score,
            suggestedEntry: entry
        )
    }

    private func deduplicatedSuggestions(_ suggestions: [FoodSuggestion]) -> [FoodSuggestion] {
        suggestions.reduce(into: [FoodSuggestion]()) { output, suggestion in
            if let existingIndex = output.firstIndex(where: { suggestionsOverlap($0, suggestion) }) {
                if suggestion.relevanceScore > output[existingIndex].relevanceScore {
                    output[existingIndex] = suggestion
                }
            } else {
                output.append(suggestion)
            }
        }
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
        if !lhsTitle.isEmpty && lhsTitle == rhsTitle {
            return true
        }
        return suggestionsSemanticallyOverlap(
            lhs,
            rhs,
            lhsComponents: lhsComponents,
            rhsComponents: rhsComponents,
            lhsTitle: lhsTitle,
            rhsTitle: rhsTitle
        )
    }

    private func suggestionsSemanticallyOverlap(
        _ lhs: FoodSuggestion,
        _ rhs: FoodSuggestion,
        lhsComponents: Set<String>,
        rhsComponents: Set<String>,
        lhsTitle: String,
        rhsTitle: String
    ) -> Bool {
        let exactComponentScore = FoodSemanticSatisfactionScorer.jaccard(lhs: lhsComponents, rhs: rhsComponents)
        let componentSemanticScore = semanticScorer.componentSemanticSimilarity(
            candidateComponents: Array(lhsComponents),
            loggedComponents: Array(rhsComponents)
        )
        let nameScore = semanticScorer.nameSimilarity(
            candidateNames: [lhsTitle].filter { !$0.isEmpty },
            loggedName: rhsTitle
        )
        let macroScore = semanticScorer.macroSimilarity(
            candidate: semanticNutritionProfile(for: lhs.suggestedEntry),
            logged: semanticNutritionProfile(for: rhs.suggestedEntry)
        )
        let servingScore = semanticScorer.servingSimilarity(
            candidate: semanticServingProfile(for: lhs.suggestedEntry),
            logged: semanticServingProfile(for: rhs.suggestedEntry)
        )
        let decision = semanticScorer.decision(
            exactComponentScore: exactComponentScore,
            componentSemanticScore: componentSemanticScore,
            nameScore: nameScore,
            macroScore: macroScore,
            servingScore: servingScore
        )
        return decision.isSatisfied
            && max(exactComponentScore, componentSemanticScore, nameScore) >= 0.28
            && macroScore >= 0.70
    }

    private func semanticNutritionProfile(for entry: SuggestedFoodEntry) -> FoodSemanticNutritionProfile {
        FoodSemanticNutritionProfile(
            calories: Double(entry.calories),
            proteinGrams: entry.proteinGrams,
            carbsGrams: entry.carbsGrams,
            fatGrams: entry.fatGrams
        )
    }

    private func semanticServingProfile(for entry: SuggestedFoodEntry) -> FoodSemanticServingProfile {
        FoodSemanticServingProfile(
            servingText: entry.servingSize,
            quantity: nil,
            unit: nil
        )
    }

    private func isStandaloneSuggestion(_ suggestion: FoodSuggestion) -> Bool {
        let isCarbSide = !suggestion.suggestedEntry.components.isEmpty
            && suggestion.suggestedEntry.components.allSatisfy { $0.role == FoodComponentRole.carb.rawValue }
            && suggestion.suggestedEntry.proteinGrams < 14
        return !isCarbSide
    }

    private func hasSufficientEvidence(_ memory: FoodMemory) -> Bool {
        memory.observationCount >= 2
            || memory.confirmedReuseCount > 0
            || hasPositiveFeedback(memory)
    }

    private func isSuggestibleMemory(_ memory: FoodMemory) -> Bool {
        switch memory.status {
        case .confirmed:
            return hasSufficientEvidence(memory)
        case .candidate:
            return isEmergingUsefulMemory(memory)
        case .retired, .merged:
            return false
        }
    }

    private func isEmergingUsefulMemory(_ memory: FoodMemory) -> Bool {
        guard memory.observationCount >= 2 else { return hasPositiveFeedback(memory) }
        guard memory.confidenceScore >= 0.72 || hasPositiveFeedback(memory) else { return false }
        let distinctDays = memory.qualitySignals?.distinctObservationDays
            ?? memory.repeatPattern?.distinctConsumptionDays
            ?? 1
        let repeatedTimeBucketScore = memory.qualitySignals?.repeatedTimeBucketScore
            ?? memoryTimeConsistencyEstimate(memory)
        let hasRepeatedBehavior = distinctDays >= 2
            || (memory.repeatPattern?.daysWithMultipleUses ?? 0) > 0
            || hasPositiveFeedback(memory)
        return hasRepeatedBehavior
            && (repeatedTimeBucketScore >= 0.45 || memory.observationCount >= 3 || hasPositiveFeedback(memory))
    }

    private func memoryTimeConsistencyEstimate(_ memory: FoodMemory) -> Double {
        guard let profile = memory.timeProfile else { return 0 }
        let total = max(profile.hourCounts.reduce(0, +), memory.observationCount, 1)
        let strongestBucket = profile.bucketCounts.values.max() ?? 0
        var strongestHourWindow = 0
        for hour in 0..<24 {
            let window = [-1, 0, 1].reduce(0) { partial, offset in
                partial + hourCount(profile.hourCounts, at: (hour + offset + 24) % 24)
            }
            strongestHourWindow = max(strongestHourWindow, window)
        }
        return max(Double(strongestBucket), Double(strongestHourWindow)) / Double(total)
    }

    private func hasPositiveFeedback(_ memory: FoodMemory) -> Bool {
        let stats = memory.suggestionStats
        return (stats?.timesAccepted ?? 0) > 0 || (stats?.timesRefined ?? 0) > 0
    }

    private func hasRecentNegativeFeedback(_ memory: FoodMemory, now: Date) -> Bool {
        guard let stats = memory.suggestionStats else { return false }
        guard stats.timesDismissed > stats.timesAccepted else { return false }
        guard let lastDismissedAt = stats.lastDismissedAt else { return stats.timesDismissed >= 3 }
        let hours = Calendar.current.dateComponents([.hour], from: lastDismissedAt, to: now).hour ?? 999
        return hours < 12
    }

    private func isStale(_ memory: FoodMemory, targetDate: Date) -> Bool {
        let days = Calendar.current.dateComponents([.day], from: memory.lastObservedAt, to: targetDate).day ?? 999
        return days > 45
    }

    private func opportunityState(
        for memory: FoodMemory,
        targetDate: Date,
        entries: [FoodEntry]
    ) -> FoodMemoryOpportunityState {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: targetDate)
        let memoryComponents = Set(memory.components.map { normalizationService.normalizeComponentName($0.normalizedName) }.filter { !$0.isEmpty })
        let satisfiedDates = entries.compactMap { entry -> Date? in
            guard entry.loggedAt >= startOfDay, entry.loggedAt < targetDate else { return nil }
            if entry.foodMemoryIdString == memory.id.uuidString {
                return entry.loggedAt
            }
            if matcher.matches(entry: entry, memory: memory) || semanticallySatisfies(memory: memory, entry: entry) {
                return entry.loggedAt
            }
            let entryName = normalizationService.normalizeFoodName(entry.name)
            if !entryName.isEmpty, entryName == memory.primaryNormalizedName {
                return entry.loggedAt
            }
            if entry.acceptedSnapshot == nil,
               !entryName.isEmpty,
               !memory.primaryNormalizedName.isEmpty,
               (entryName.contains(memory.primaryNormalizedName) || memory.primaryNormalizedName.contains(entryName)),
               nutritionLooksSimilar(entry: entry, memory: memory) {
                return entry.loggedAt
            }
            guard let snapshot = entry.acceptedSnapshot, !memoryComponents.isEmpty else { return nil }
            let entryComponents = Set(snapshot.components.map { normalizationService.normalizeComponentName($0.displayName) }.filter { !$0.isEmpty })
            return entryComponents == memoryComponents ? entry.loggedAt : nil
        }
        guard let lastSatisfiedAt = satisfiedDates.max() else {
            return FoodMemoryOpportunityState(availability: .eligible, rankingPenalty: passiveExposurePenalty(memory))
        }

        guard let repeatPattern = memory.repeatPattern else {
            return FoodMemoryOpportunityState(availability: .suppress, rankingPenalty: 1)
        }

        let minutesSinceLast = calendar.dateComponents([.minute], from: lastSatisfiedAt, to: targetDate).minute ?? 0
        let learnedSpacing = learnedRepeatSpacingMinutes(repeatPattern)
        if hasStrongSameDayRepeatEvidence(repeatPattern), minutesSinceLast >= learnedSpacing {
            return FoodMemoryOpportunityState(availability: .eligible, rankingPenalty: passiveExposurePenalty(memory))
        }

        if hasEmergingSameDayRepeatEvidence(repeatPattern), minutesSinceLast >= max(90, learnedSpacing - 60) {
            return FoodMemoryOpportunityState(availability: .demote, rankingPenalty: max(0.20, passiveExposurePenalty(memory)))
        }

        return FoodMemoryOpportunityState(availability: .suppress, rankingPenalty: 1)
    }

    private func learnedRepeatSpacingMinutes(_ repeatPattern: FoodMemoryRepeatPattern) -> Int {
        guard let averageRepeatGapMinutes = repeatPattern.averageRepeatGapMinutes,
              averageRepeatGapMinutes.isFinite,
              averageRepeatGapMinutes > 0
        else {
            return 120
        }
        return max(90, min(Int(averageRepeatGapMinutes.rounded()), 360))
    }

    private func hasStrongSameDayRepeatEvidence(_ repeatPattern: FoodMemoryRepeatPattern) -> Bool {
        repeatPattern.daysWithMultipleUses >= 2
            && repeatPattern.repeatGapObservationCount >= 2
            || repeatPattern.maxUsesInDay >= 3
            || repeatPattern.averageUsesPerDay >= 1.45
    }

    private func hasEmergingSameDayRepeatEvidence(_ repeatPattern: FoodMemoryRepeatPattern) -> Bool {
        repeatPattern.daysWithMultipleUses >= 1
            || repeatPattern.maxUsesInDay > 1
            || repeatPattern.averageUsesPerDay >= 1.20
    }

    private func semanticallySatisfies(memory: FoodMemory, entry: FoodEntry) -> Bool {
        guard let snapshot = entry.acceptedSnapshot else { return false }
        let memoryComponents = memory.components.map(\.normalizedName).filter { !$0.isEmpty }
        let snapshotComponents = snapshot.components.map(\.normalizedName).filter { !$0.isEmpty }
        let memoryNames = ([memory.displayName, memory.primaryNormalizedName] + memory.aliases.map(\.displayName) + memory.aliases.map(\.normalizedName))
            .map(normalizationService.normalizeFoodName)
        let snapshotName = snapshot.normalizedDisplayName.isEmpty
            ? normalizationService.normalizeFoodName(snapshot.displayName)
            : snapshot.normalizedDisplayName
        let nutrition = memory.nutritionProfile
        return semanticScorer.decision(
            exactComponentScore: FoodSemanticSatisfactionScorer.jaccard(
                lhs: Set(memoryComponents),
                rhs: Set(snapshotComponents)
            ),
            componentSemanticScore: semanticScorer.componentSemanticSimilarity(
                candidateComponents: memoryComponents,
                loggedComponents: snapshotComponents
            ),
            nameScore: semanticScorer.nameSimilarity(candidateNames: memoryNames, loggedName: snapshotName),
            macroScore: semanticScorer.macroSimilarity(
                candidate: nutrition.map {
                    FoodSemanticNutritionProfile(
                        calories: Double($0.medianCalories),
                        proteinGrams: $0.medianProteinGrams,
                        carbsGrams: $0.medianCarbsGrams,
                        fatGrams: $0.medianFatGrams
                    )
                },
                logged: FoodSemanticNutritionProfile(
                    calories: Double(snapshot.totalCalories),
                    proteinGrams: snapshot.totalProteinGrams,
                    carbsGrams: snapshot.totalCarbsGrams,
                    fatGrams: snapshot.totalFatGrams
                )
            ),
            servingScore: semanticScorer.servingSimilarity(
                candidate: memory.servingProfile.map {
                    FoodSemanticServingProfile(
                        servingText: $0.commonServingText,
                        quantity: $0.commonQuantity,
                        unit: $0.commonUnit
                    )
                },
                logged: FoodSemanticServingProfile(
                    servingText: snapshot.servingText,
                    quantity: snapshot.servingQuantity,
                    unit: snapshot.servingUnit
                )
            )
        ).isSatisfied
    }

    private func memoryTimeSupport(_ memory: FoodMemory, targetDate: Date) -> Double {
        guard let profile = memory.timeProfile else { return 0 }
        let hour = Calendar.current.component(.hour, from: targetDate)
        let weights = [0: 1.0, 1: 0.75, 2: 0.45, 3: 0.20]
        let total = max(profile.hourCounts.reduce(0, +), memory.observationCount, 1)
        let weighted = weights.reduce(0.0) { partial, item in
            let offset = item.key
            let weight = item.value
            if offset == 0 {
                return partial + Double(hourCount(profile.hourCounts, at: hour)) * weight
            }
            let before = (hour - offset + 24) % 24
            let after = (hour + offset) % 24
            return partial
                + Double(hourCount(profile.hourCounts, at: before)) * weight
                + Double(hourCount(profile.hourCounts, at: after)) * weight
        }
        return min(weighted / Double(total), 1)
    }

    private func hourCount(_ counts: [Int], at index: Int) -> Int {
        counts.indices.contains(index) ? counts[index] : 0
    }

    private func memoryBucketSupport(_ memory: FoodMemory, targetDate: Date) -> Double {
        let bucket = normalizationService.mealTimeBucket(for: targetDate)
        let explicitSupport = Double(memory.timeProfile?.bucketCounts[bucket.rawValue] ?? 0) / Double(max(memory.observationCount, 1))
        let nameSupport = normalizationService.normalizeFoodName(memory.displayName).contains(bucket.rawValue) ? 0.35 : 0
        return max(explicitSupport, nameSupport)
    }

    private func isStrongUsefulHabit(_ memory: FoodMemory) -> Bool {
        memory.observationCount >= 6
            && memory.confidenceScore >= 0.9
    }

    private func directSuggestionScore(
        memory: FoodMemory,
        now: Date,
        targetDate: Date,
        timeSupport: Double,
        bucketSupport: Double,
        opportunityState: FoodMemoryOpportunityState
    ) -> Double {
        let days = Double(max(Calendar.current.dateComponents([.day], from: memory.lastObservedAt, to: targetDate).day ?? 0, 0))
        let recency = max(0, 1 - min(days / 45.0, 1))
        let repetition = min(Double(max(memory.observationCount, memory.confirmedReuseCount + 1)) / 8.0, 1)
        let confidence = min(max(memory.confidenceScore, 0), 1)
        let feedback = hasPositiveFeedback(memory) ? 0.12 : 0
        let score = 0.30 * max(timeSupport, bucketSupport)
            + 0.22 * repetition
            + 0.18 * recency
            + 0.18 * confidence
            + feedback
            - opportunityState.rankingPenalty
            - ignoredFeedbackPenalty(for: memory, now: now)
        return min(max(score, 0), 1)
    }

    private func ignoredFeedbackPenalty(for memory: FoodMemory, now: Date) -> Double {
        guard let stats = memory.suggestionStats,
              stats.timesIgnored > stats.timesAccepted + stats.timesRefined
        else {
            return 0
        }
        guard let lastIgnoredAt = stats.lastIgnoredAt else {
            return min(Double(stats.timesIgnored) * 0.04, 0.16)
        }
        let hours = Double(Calendar.current.dateComponents([.hour], from: lastIgnoredAt, to: now).hour ?? 999)
        if hours < 6 {
            return min(Double(stats.timesIgnored) * 0.06, 0.24)
        }
        if hours < 48 {
            return min(Double(stats.timesIgnored) * 0.04, 0.16)
        }
        return 0
    }

    private func passiveExposurePenalty(_ memory: FoodMemory) -> Double {
        guard let stats = memory.suggestionStats,
              stats.timesShown >= 4,
              stats.timesAccepted == 0,
              stats.timesDismissed == 0
        else {
            return 0
        }
        return min(Double(stats.timesShown - 3) * 0.04, 0.18)
    }

    private func nutritionLooksSimilar(entry: FoodEntry, memory: FoodMemory) -> Bool {
        guard let nutrition = memory.nutritionProfile else { return false }
        return abs(Double(entry.calories - nutrition.medianCalories)) <= max(Double(nutrition.medianCalories) * 0.35, 80)
            && abs(entry.proteinGrams - nutrition.medianProteinGrams) <= max(nutrition.medianProteinGrams * 0.45, 10)
            && abs(entry.carbsGrams - nutrition.medianCarbsGrams) <= max(nutrition.medianCarbsGrams * 0.45, 12)
            && abs(entry.fatGrams - nutrition.medianFatGrams) <= max(nutrition.medianFatGrams * 0.45, 8)
    }

    private func directSuggestionSubtitle(targetDate: Date, timeSupport: Double, bucketSupport: Double) -> String {
        if timeSupport >= 0.20 || bucketSupport >= 0.20 {
            return "Common around \(normalizationService.mealTimeBucket(for: targetDate).rawValue)"
        }
        return "Remembered food"
    }

    private func suggestedEntry(from memory: FoodMemory) -> SuggestedFoodEntry {
        let nutrition = memory.nutritionProfile
        let components = memory.components.map { component in
            SuggestedFoodComponent(
                id: normalizationService.normalizeComponentName(component.normalizedName),
                displayName: component.normalizedName,
                role: component.role.rawValue,
                calories: component.typicalCalories,
                proteinGrams: component.typicalProteinGrams,
                carbsGrams: component.typicalCarbsGrams,
                fatGrams: component.typicalFatGrams,
                confidence: "medium"
            )
        }
        return SuggestedFoodEntry(
            id: memory.id.uuidString,
            name: memory.displayName,
            calories: nutrition?.medianCalories ?? components.map(\.calories).reduce(0, +),
            proteinGrams: nutrition?.medianProteinGrams ?? components.map(\.proteinGrams).reduce(0, +),
            carbsGrams: nutrition?.medianCarbsGrams ?? components.map(\.carbsGrams).reduce(0, +),
            fatGrams: nutrition?.medianFatGrams ?? components.map(\.fatGrams).reduce(0, +),
            fiberGrams: nutrition?.medianFiberGrams,
            sugarGrams: nutrition?.medianSugarGrams,
            servingSize: memory.servingProfile?.commonServingText,
            emoji: memory.emoji,
            components: components,
            mealKind: nil,
            notes: nil,
            confidence: memory.confidenceScore >= 0.9 ? "high" : "medium",
            schemaVersion: 2
        )
    }

    private func memoryMatches(_ memory: FoodMemory, suggestion: FoodSuggestion) -> Bool {
        let memoryComponents = Set(
            memory.components
                .map { normalizationService.normalizeComponentName($0.normalizedName) }
                .filter { !$0.isEmpty }
        )
        let suggestionComponents = canonicalComponentSet(from: suggestion.suggestedEntry.components)
        if !memoryComponents.isEmpty, !suggestionComponents.isEmpty, memoryComponents == suggestionComponents {
            return nutritionLooksCompatible(memory: memory, suggestion: suggestion)
        }

        let normalizedSuggestionTitle = normalizationService.normalizeFoodName(suggestion.title)
        return !normalizedSuggestionTitle.isEmpty
            && Set(memory.aliases.map(\.normalizedName)).union([memory.primaryNormalizedName]).contains(normalizedSuggestionTitle)
            && nutritionLooksCompatible(memory: memory, suggestion: suggestion)
    }


    private func canonicalComponentSet(from components: [SuggestedFoodComponent]) -> Set<String> {
        Set(components.map { normalizationService.normalizeComponentName($0.displayName) }.filter { !$0.isEmpty })
    }

    private func nutritionLooksCompatible(memory: FoodMemory, suggestion: FoodSuggestion) -> Bool {
        guard let nutrition = memory.nutritionProfile else { return true }
        return nutritionLooksCompatible(
            calories: nutrition.medianCalories,
            protein: nutrition.medianProteinGrams,
            carbs: nutrition.medianCarbsGrams,
            fat: nutrition.medianFatGrams,
            suggestion: suggestion
        )
    }

    private func nutritionLooksCompatible(
        calories: Int,
        protein: Double,
        carbs: Double,
        fat: Double,
        suggestion: FoodSuggestion
    ) -> Bool {
        let suggestedEntry = suggestion.suggestedEntry
        return abs(Double(calories - suggestedEntry.calories)) <= max(Double(suggestedEntry.calories) * 0.4, 120)
            && abs(protein - suggestedEntry.proteinGrams) <= max(suggestedEntry.proteinGrams * 0.5, 12)
            && abs(carbs - suggestedEntry.carbsGrams) <= max(suggestedEntry.carbsGrams * 0.5, 18)
            && abs(fat - suggestedEntry.fatGrams) <= max(suggestedEntry.fatGrams * 0.5, 10)
    }

    fileprivate func recordOutcomes(
        _ outcome: FoodSuggestionOutcome,
        for memoryIDs: [UUID],
        at: Date,
        modelContext: ModelContext
    ) throws {
        let ids = Set(memoryIDs)
        guard !ids.isEmpty else { return }

        let memories = try modelContext.fetch(FetchDescriptor<FoodMemory>())
        let existingMemoryIDs = Set(memories.map(\.id))
        var didChange = false

        for memory in memories where ids.contains(memory.id) {
            memory.suggestionStats = updatedSuggestionStats(
                existing: memory.suggestionStats,
                outcome: outcome,
                at: at
            )
            didChange = true
        }

        let missingIDs = ids.subtracting(existingMemoryIDs)
        if !missingIDs.isEmpty {
            do {
                let existingFeedback = try modelContext.fetch(FetchDescriptor<FoodSuggestionFeedback>())
                for suggestionID in missingIDs {
                    if let feedback = existingFeedback.first(where: { $0.suggestionID == suggestionID }) {
                        feedback.stats = updatedSuggestionStats(
                            existing: feedback.stats,
                            outcome: outcome,
                            at: at
                        )
                        feedback.updatedAt = at
                    } else {
                        let feedback = FoodSuggestionFeedback(
                            suggestionID: suggestionID,
                            stats: updatedSuggestionStats(existing: nil, outcome: outcome, at: at),
                            createdAt: at,
                            updatedAt: at
                        )
                        modelContext.insert(feedback)
                    }
                    didChange = true
                }
            } catch {
                // Feedback for generated suggestions is auxiliary. Keep suggestion actions usable in previews and tests
                // that intentionally construct narrower SwiftData schemas.
            }
        }

        if didChange {
            try modelContext.save()
        }
    }

    private func updatedSuggestionStats(
        existing: FoodMemorySuggestionStats?,
        outcome: FoodSuggestionOutcome,
        at: Date
    ) -> FoodMemorySuggestionStats {
        var timesShown = existing?.timesShown ?? 0
        var timesTapped = existing?.timesTapped ?? 0
        var timesIgnored = existing?.timesIgnored ?? 0
        var timesAccepted = existing?.timesAccepted ?? 0
        var timesDismissed = existing?.timesDismissed ?? 0
        var timesRefined = existing?.timesRefined ?? 0
        var lastShownAt = existing?.lastShownAt
        var lastTappedAt = existing?.lastTappedAt
        var lastIgnoredAt = existing?.lastIgnoredAt
        var lastAcceptedAt = existing?.lastAcceptedAt
        var lastDismissedAt = existing?.lastDismissedAt
        var lastRefinedAt = existing?.lastRefinedAt

        switch outcome {
        case .shown:
            timesShown += 1
            lastShownAt = at
        case .tapped:
            timesTapped += 1
            lastTappedAt = at
        case .ignored:
            timesIgnored += 1
            lastIgnoredAt = at
        case .accepted:
            timesAccepted += 1
            lastAcceptedAt = at
        case .refined:
            timesAccepted += 1
            timesRefined += 1
            lastAcceptedAt = at
            lastRefinedAt = at
        case .dismissed:
            timesDismissed += 1
            lastDismissedAt = at
        }

        return FoodMemorySuggestionStats(
            timesShown: timesShown,
            timesTapped: timesTapped,
            timesIgnored: timesIgnored,
            timesAccepted: timesAccepted,
            timesDismissed: timesDismissed,
            timesRefined: timesRefined,
            lastShownAt: lastShownAt,
            lastTappedAt: lastTappedAt,
            lastIgnoredAt: lastIgnoredAt,
            lastAcceptedAt: lastAcceptedAt,
            lastDismissedAt: lastDismissedAt,
            lastRefinedAt: lastRefinedAt
        )
    }

    private func emptyDebugSummary() -> FoodSuggestionDebugSummary {
        FoodSuggestionDebugSummary(
            totalMemories: 0,
            totalObservations: 0,
            patternCount: 0,
            candidateCountBySource: [:],
            suppressedOneOffCount: 0,
            suppressedAlreadyTodayCount: 0,
            demotedAlreadyTodayCount: 0,
            directMemoryCandidateCount: 0,
            directSuppressedAlreadyTodayCount: 0,
            directDemotedAlreadyTodayCount: 0,
            directPassiveExposureDemotedCount: 0,
            retrievedCandidateCount: 0,
            suppressedNegativeFeedbackCount: 0,
            suppressedLowConfidenceCount: 0,
            recallFallbackCount: 0,
            occasionAlternateCount: 0,
            semanticSubstituteCount: 0,
            completeMealPromotionCount: 0,
            finalEligibleCount: 0,
            shownSuggestionTitles: []
        )
    }
}

nonisolated private enum FoodMemoryOpportunityAvailability {
    case eligible
    case demote
    case suppress
}

nonisolated private struct FoodMemoryOpportunityState {
    let availability: FoodMemoryOpportunityAvailability
    let rankingPenalty: Double
}

nonisolated private struct FoodDirectMemorySuggestionDiagnostics {
    var candidateCount: Int
    var suppressedAlreadyTodayCount: Int
    var demotedAlreadyTodayCount: Int
    var passiveExposureDemotedCount: Int

    static let empty = FoodDirectMemorySuggestionDiagnostics(
        candidateCount: 0,
        suppressedAlreadyTodayCount: 0,
        demotedAlreadyTodayCount: 0,
        passiveExposureDemotedCount: 0
    )
}

private actor FoodSuggestionWorker {
    func cameraSuggestions(
        limit: Int,
        now: Date,
        targetDate: Date?,
        sessionId: UUID?,
        modelContainer: ModelContainer
    ) throws -> [FoodSuggestion] {
        let modelContext = ModelContext(modelContainer)
        return try FoodSuggestionService().cameraSuggestionsOnCurrentActor(
            limit: limit,
            now: now,
            targetDate: targetDate,
            sessionId: sessionId,
            modelContext: modelContext
        )
    }

    func recordOutcome(
        _ outcome: FoodSuggestionOutcome,
        for memoryIDs: [UUID],
        at: Date,
        modelContainer: ModelContainer
    ) throws {
        let modelContext = ModelContext(modelContainer)
        try FoodSuggestionService().recordOutcomes(
            outcome,
            for: memoryIDs,
            at: at,
            modelContext: modelContext
        )
    }

    func debugCameraSuggestions(
        limit: Int,
        now: Date,
        targetDate: Date?,
        sessionId: UUID?,
        modelContainer: ModelContainer
    ) throws -> FoodSuggestionDebugSummary {
        let modelContext = ModelContext(modelContainer)
        return try FoodSuggestionService().debugCameraSuggestions(
            limit: limit,
            now: now,
            targetDate: targetDate,
            sessionId: sessionId,
            modelContext: modelContext
        )
    }
}

actor FoodSuggestionWarmCache {
    static let shared = FoodSuggestionWarmCache()

    private let cacheTTL: TimeInterval = 10 * 60
    private let targetDateBucketSize: TimeInterval = 15 * 60
    private var cache: [FoodSuggestionWarmCacheKey: CachedFoodSuggestions] = [:]
    private var inFlight: [FoodSuggestionWarmCacheKey: Task<[FoodSuggestion], Never>] = [:]

    func cachedSuggestions(limit: Int, targetDate: Date, sessionId: UUID?) -> [FoodSuggestion]? {
        let key = cacheKey(limit: limit, targetDate: targetDate, sessionId: sessionId)
        pruneExpired(now: Date())
        guard let cached = cache[key], !cached.isExpired(ttl: cacheTTL) else {
            cache[key] = nil
            return nil
        }
        return cached.suggestions
    }

    func suggestions(
        limit: Int,
        targetDate: Date,
        sessionId: UUID?,
        modelContainer: ModelContainer
    ) async -> [FoodSuggestion] {
        let key = cacheKey(limit: limit, targetDate: targetDate, sessionId: sessionId)
        pruneExpired(now: Date())

        if let cached = cache[key], !cached.isExpired(ttl: cacheTTL) {
            return cached.suggestions
        }

        if let task = inFlight[key] {
            let suggestions = await task.value
            store(suggestions: suggestions, key: key)
            return suggestions
        }

        let task = suggestionTask(
            limit: limit,
            targetDate: targetDate,
            sessionId: sessionId,
            modelContainer: modelContainer
        )
        inFlight[key] = task
        let suggestions = await task.value
        store(suggestions: suggestions, key: key)
        return suggestions
    }

    func prewarm(
        limit: Int,
        targetDate: Date,
        sessionId: UUID?,
        modelContainer: ModelContainer
    ) {
        let key = cacheKey(limit: limit, targetDate: targetDate, sessionId: sessionId)
        pruneExpired(now: Date())

        if let cached = cache[key], !cached.isExpired(ttl: cacheTTL) {
            return
        }
        guard inFlight[key] == nil else { return }

        let task = suggestionTask(
            limit: limit,
            targetDate: targetDate,
            sessionId: sessionId,
            modelContainer: modelContainer
        )
        inFlight[key] = task
        Task { [weak self] in
            let suggestions = await task.value
            await self?.store(suggestions: suggestions, key: key)
        }
    }

    func invalidate() {
        cache.removeAll()
        inFlight.values.forEach { $0.cancel() }
        inFlight.removeAll()
    }

    private func store(suggestions: [FoodSuggestion], key: FoodSuggestionWarmCacheKey) {
        inFlight[key] = nil
        cache[key] = CachedFoodSuggestions(suggestions: suggestions, cachedAt: Date())
    }

    private func suggestionTask(
        limit: Int,
        targetDate: Date,
        sessionId: UUID?,
        modelContainer: ModelContainer
    ) -> Task<[FoodSuggestion], Never> {
        Task.detached(priority: .utility) {
            (try? await FoodSuggestionService().cameraSuggestions(
                limit: limit,
                targetDate: targetDate,
                sessionId: sessionId,
                modelContainer: modelContainer
            )) ?? []
        }
    }

    private func cacheKey(limit: Int, targetDate: Date, sessionId: UUID?) -> FoodSuggestionWarmCacheKey {
        FoodSuggestionWarmCacheKey(
            sessionId: sessionId,
            targetDateBucket: Int(targetDate.timeIntervalSinceReferenceDate / targetDateBucketSize),
            limit: limit
        )
    }

    private func pruneExpired(now: Date) {
        cache = cache.filter { now.timeIntervalSince($0.value.cachedAt) <= cacheTTL }
    }
}

nonisolated private struct FoodSuggestionWarmCacheKey: Hashable, Sendable {
    let sessionId: UUID?
    let targetDateBucket: Int
    let limit: Int
}

nonisolated private struct CachedFoodSuggestions: Sendable {
    let suggestions: [FoodSuggestion]
    let cachedAt: Date

    func isExpired(ttl: TimeInterval) -> Bool {
        Date().timeIntervalSince(cachedAt) > ttl
    }
}
