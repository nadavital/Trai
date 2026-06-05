import XCTest
@testable import Trai

@MainActor
final class FoodRecommendationGoldenReplayTests: XCTestCase {
    func testGoldenReplaySuiteQuantifiesCurrentProviderAgainstBaselines() async throws {
        let results = try await evaluate([
            balancedWeeklyHabitsScenario(),
            sessionCompletionScenario(),
            weekdayWeekendScenario(),
            anonymizedRealisticHistoryScenario()
        ])

        print(suiteScoreboard(results))

        let balanced = try XCTUnwrap(result(named: "balanced-weekly-habits", in: results))
        XCTAssertGreaterThanOrEqual(balanced.current.metrics.evaluatedCases, 12)
        XCTAssertGreaterThanOrEqual(balanced.current.metrics.hitAt3, balanced.baseline.metrics.hitAt3 + 0.25)
        XCTAssertGreaterThanOrEqual(balanced.current.metrics.meanReciprocalRank, balanced.baseline.metrics.meanReciprocalRank + 0.20)
        XCTAssertLessThanOrEqual(balanced.current.metrics.noSuggestionRate, 0.20)
        XCTAssertGreaterThanOrEqual(balanced.current.metrics.completeMealCoverageRate, 0.70)
        XCTAssertLessThanOrEqual(balanced.current.metrics.oneOffFalsePositiveRate, 0.05)
        XCTAssertLessThanOrEqual(balanced.current.metrics.beverageDominationRate, 0.05)
        XCTAssertLessThanOrEqual(balanced.current.metrics.duplicateSuggestionRate, 0.05)

        let sessionCompletion = try XCTUnwrap(result(named: "session-completion", in: results))
        XCTAssertGreaterThanOrEqual(sessionCompletion.current.metrics.hitAt1, 0.95)
        XCTAssertLessThanOrEqual(sessionCompletion.current.metrics.noSuggestionRate, 0.05)
        XCTAssertLessThanOrEqual(sessionCompletion.current.metrics.beverageDominationRate, 0.05)

        let weekdayWeekend = try XCTUnwrap(result(named: "weekday-weekend-split", in: results))
        XCTAssertGreaterThanOrEqual(weekdayWeekend.current.metrics.hitAt3, weekdayWeekend.baseline.metrics.hitAt3)
        XCTAssertLessThanOrEqual(weekdayWeekend.current.metrics.oneOffFalsePositiveRate, 0.05)
        XCTAssertLessThanOrEqual(weekdayWeekend.current.metrics.duplicateSuggestionRate, 0.05)

        let realistic = try XCTUnwrap(result(named: "anonymized-realistic-history", in: results))
        XCTAssertGreaterThanOrEqual(realistic.current.metrics.hitAt3, 0.80)
        XCTAssertGreaterThanOrEqual(realistic.current.metrics.hitAt5, 0.88)
        XCTAssertGreaterThanOrEqual(realistic.current.metrics.hitAt3, realistic.baseline.metrics.hitAt3 + 0.50)
        XCTAssertGreaterThanOrEqual(realistic.current.metrics.meanReciprocalRank, realistic.baseline.metrics.meanReciprocalRank + 0.10)
        XCTAssertLessThanOrEqual(realistic.current.metrics.noSuggestionRate, 0.20)
        XCTAssertLessThanOrEqual(realistic.current.metrics.oneOffFalsePositiveRate, 0.05)
        XCTAssertLessThanOrEqual(realistic.current.metrics.beverageDominationRate, 0.05)
        XCTAssertLessThanOrEqual(realistic.current.metrics.duplicateSuggestionRate, 0.05)
        XCTAssertLessThanOrEqual(realistic.current.debugReport.missReasonCounts["noCloseEquivalent"] ?? 0, 3)
    }

    func testSessionContextImprovesCompletionReplay() async throws {
        let entries = sessionCompletionEntries(dayCount: 7)
        let observations = FoodObservationBuilder().observations(from: entries)

        let withSession = try await evaluateCurrent(
            observations: observations,
            entries: entries,
            config: FoodRecommendationReplayConfig(
                minimumTrainingObservations: 13,
                maximumCases: nil,
                includeSessionContext: true
            )
        )
        let withoutSession = try await evaluateCurrent(
            observations: observations,
            entries: entries,
            config: FoodRecommendationReplayConfig(
                minimumTrainingObservations: 12,
                maximumCases: nil,
                includeSessionContext: false
            )
        )

        print(sessionContextScoreboard(withSession: withSession.metrics, withoutSession: withoutSession.metrics))
        XCTAssertGreaterThanOrEqual(withSession.metrics.hitAt1, withoutSession.metrics.hitAt1)
        XCTAssertGreaterThanOrEqual(withSession.metrics.meanReciprocalRank, withoutSession.metrics.meanReciprocalRank)
        XCTAssertLessThanOrEqual(withSession.metrics.noSuggestionRate, withoutSession.metrics.noSuggestionRate)
    }

    func testSparsePersonalCompleteMealCanUseTopThreeAfterOnePriorContextualOccurrence() throws {
        let targetDate = FoodRecommendationTestSupport.day(7, hour: 19)
        var entries: [FoodEntry] = [
            sushiDinner(day: 0, hour: 19)
        ]
        for day in 1..<7 {
            entries.append(oatmealBreakfast(day: day, hour: 7))
            entries.append(chickenDeskBowl(day: day, hour: 12))
            if day % 2 == 0 {
                entries.append(proteinShake(day: day, hour: 16))
            }
            entries.append(tofuStirFry(day: day, hour: 19))
        }

        let suggestions = FoodRecommendationEngine().recommendationsSync(
            for: FoodRecommendationRequest(
                now: targetDate,
                targetDate: targetDate,
                sessionID: nil,
                limit: 3,
                entries: entries.filter { $0.loggedAt < targetDate },
                memories: []
            )
        ).suggestions

        let topThreeNames = suggestions.prefix(3).map { $0.title.lowercased() }
        XCTAssertTrue(topThreeNames.contains { $0.contains("sushi") }, "top three: \(topThreeNames)")
        XCTAssertFalse(suggestions.prefix(3).allSatisfy { $0.suggestedEntry.components.contains { $0.role == FoodComponentRole.drink.rawValue } })
    }

    func testSemanticallySimilarCompleteMealCanUseTopThreeAsAlternative() throws {
        let targetDate = FoodRecommendationTestSupport.day(8, hour: 19)
        var entries: [FoodEntry] = [
            salmonRice(name: "Salmon Rice Bowl", day: 0, hour: 14)
        ]
        for day in 1..<8 {
            entries.append(sushiDinner(day: day, hour: 19))
            entries.append(proteinShake(day: day, hour: 16))
        }

        let suggestions = FoodRecommendationEngine().recommendationsSync(
            for: FoodRecommendationRequest(
                now: targetDate,
                targetDate: targetDate,
                sessionID: nil,
                limit: 3,
                entries: entries.filter { $0.loggedAt < targetDate },
                memories: []
            )
        ).suggestions

        let topThreeNames = suggestions.prefix(3).map { $0.title.lowercased() }
        XCTAssertTrue(topThreeNames.contains { $0.contains("salmon rice") }, "top three: \(topThreeNames)")
        XCTAssertFalse(suggestions.prefix(3).allSatisfy { $0.suggestedEntry.components.contains { $0.role == FoodComponentRole.drink.rawValue } })
    }

    func testSameDaySemanticCompleteMealSuppressesSimilarAlternative() throws {
        let targetDate = FoodRecommendationTestSupport.day(8, hour: 19)
        var entries: [FoodEntry] = [
            salmonRice(name: "Salmon Rice Bowl", day: 0, hour: 14)
        ]
        for day in 1..<8 {
            entries.append(sushiDinner(day: day, hour: 19))
            entries.append(proteinShake(day: day, hour: 16))
        }
        entries.append(sushiDinner(day: 8, hour: 18))

        let suggestions = FoodRecommendationEngine().recommendationsSync(
            for: FoodRecommendationRequest(
                now: targetDate,
                targetDate: targetDate,
                sessionID: nil,
                limit: 3,
                entries: entries.filter { $0.loggedAt < targetDate },
                memories: []
            )
        ).suggestions

        let topThreeNames = suggestions.prefix(3).map { $0.title.lowercased() }
        XCTAssertFalse(topThreeNames.contains { $0.contains("salmon rice") }, "top three: \(topThreeNames)")
    }

    func testUnrelatedOneOffCompleteMealDoesNotCrowdTopThreeAlternative() throws {
        let targetDate = FoodRecommendationTestSupport.day(8, hour: 19)
        var entries: [FoodEntry] = [
            pastrami(day: 0, hour: 14)
        ]
        for day in 1..<8 {
            entries.append(sushiDinner(day: day, hour: 19))
            entries.append(proteinShake(day: day, hour: 16))
        }

        let suggestions = FoodRecommendationEngine().recommendationsSync(
            for: FoodRecommendationRequest(
                now: targetDate,
                targetDate: targetDate,
                sessionID: nil,
                limit: 3,
                entries: entries.filter { $0.loggedAt < targetDate },
                memories: []
            )
        ).suggestions

        let topThreeNames = suggestions.prefix(3).map { $0.title.lowercased() }
        XCTAssertFalse(topThreeNames.contains { $0.contains("pastrami") }, "top three: \(topThreeNames)")
        XCTAssertTrue(topThreeNames.contains { $0.contains("sushi") }, "top three: \(topThreeNames)")
    }

    private func evaluate(_ scenarios: [GoldenReplayScenario]) async throws -> [GoldenReplayScenarioResult] {
        var results: [GoldenReplayScenarioResult] = []
        for scenario in scenarios {
            let entries = scenario.entries()
            let observations = FoodObservationBuilder().observations(from: entries)
            let config = FoodRecommendationReplayConfig(
                minimumTrainingObservations: scenario.minimumTrainingObservations,
                maximumCases: scenario.maximumCases,
                includeSessionContext: scenario.includeSessionContext
            )

            let current = try await evaluateCurrent(
                observations: observations,
                entries: entries,
                config: config
            )
            let baseline = try await FoodRecommendationReplayRunner().evaluate(
                observations: observations,
                entries: entries,
                memories: [],
                provider: { trainingEntries, _, now, limit, _, _ in
                    FoodRecommendationRecentRepeatBaselineProvider().suggestions(
                        entries: trainingEntries,
                        now: now,
                        limit: limit
                    )
                },
                config: config
            )

            results.append(
                GoldenReplayScenarioResult(
                    name: scenario.name,
                    current: current,
                    baseline: baseline
                )
            )
        }
        return results
    }

    private func evaluateCurrent(
        observations: [FoodObservation],
        entries: [FoodEntry],
        config: FoodRecommendationReplayConfig
    ) async throws -> (metrics: FoodRecommendationReplayMetrics, debugReport: FoodRecommendationReplayDebugReport) {
        try await FoodRecommendationReplayRunner().evaluate(
            observations: observations,
            entries: entries,
            memories: [],
            provider: { trainingEntries, memories, now, limit, sessionID, _ in
                FoodRecommendationEngine().recommendationsSync(
                    for: FoodRecommendationRequest(
                        now: now,
                        targetDate: now,
                        sessionID: sessionID,
                        limit: limit,
                        entries: trainingEntries,
                        memories: memories
                    )
                ).suggestions
            },
            config: config
        )
    }

    private func result(named name: String, in results: [GoldenReplayScenarioResult]) -> GoldenReplayScenarioResult? {
        results.first { $0.name == name }
    }

    private func suiteScoreboard(_ results: [GoldenReplayScenarioResult]) -> String {
        let rows = results.flatMap { result in
            [
                row(name: result.name, provider: "current", metrics: result.current.metrics),
                row(name: result.name, provider: "recent-repeat-baseline", metrics: result.baseline.metrics),
                deltaRow(result)
            ]
        }
        let weakpoints = results.map(weakpointSummary).joined(separator: "\n")
        return """
        Golden food replay suite
        scenario,provider,cases,hit@1,hit@3,hit@5,mrr,oneOffFP,beverageDomination,completeMealCoverage,duplicates,noSuggestions,medianMs,p95Ms
        \(rows.joined(separator: "\n"))

        weakpoints
        \(weakpoints)
        """
    }

    private func row(name: String, provider: String, metrics: FoodRecommendationReplayMetrics) -> String {
        "\(name),\(provider),\(metrics.evaluatedCases),\(format(metrics.hitAt1)),\(format(metrics.hitAt3)),\(format(metrics.hitAt5)),\(format(metrics.meanReciprocalRank)),\(format(metrics.oneOffFalsePositiveRate)),\(format(metrics.beverageDominationRate)),\(format(metrics.completeMealCoverageRate)),\(format(metrics.duplicateSuggestionRate)),\(format(metrics.noSuggestionRate)),\(format(metrics.medianRuntimeMilliseconds)),\(format(metrics.p95RuntimeMilliseconds))"
    }

    private func deltaRow(_ result: GoldenReplayScenarioResult) -> String {
        let current = result.current.metrics
        let baseline = result.baseline.metrics
        return "\(result.name),current_vs_recent-repeat,,,\(format(current.hitAt3 - baseline.hitAt3)),,\(format(current.meanReciprocalRank - baseline.meanReciprocalRank)),,,,,\(format(current.noSuggestionRate - baseline.noSuggestionRate)),\(format(current.medianRuntimeMilliseconds - baseline.medianRuntimeMilliseconds)),\(format(current.p95RuntimeMilliseconds - baseline.p95RuntimeMilliseconds))"
    }

    private func weakpointSummary(_ result: GoldenReplayScenarioResult) -> String {
        let missReasons = result.current.debugReport.missReasonCounts
            .sorted { lhs, rhs in
                if lhs.value == rhs.value { return lhs.key < rhs.key }
                return lhs.value > rhs.value
            }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: "|")
        let failedCases = result.current.debugReport.failedCases
            .prefix(3)
            .map(failedCaseSummary)
            .joined(separator: " | ")
        return "\(result.name): missReasons=\(missReasons.isEmpty ? "none" : missReasons) failed=\(failedCases.isEmpty ? "none" : failedCases)"
    }

    private func sessionContextScoreboard(
        withSession: FoodRecommendationReplayMetrics,
        withoutSession: FoodRecommendationReplayMetrics
    ) -> String {
        """
        Session context replay
        provider,cases,hit@1,hit@3,hit@5,mrr,noSuggestions
        with-session,\(withSession.evaluatedCases),\(format(withSession.hitAt1)),\(format(withSession.hitAt3)),\(format(withSession.hitAt5)),\(format(withSession.meanReciprocalRank)),\(format(withSession.noSuggestionRate))
        without-session,\(withoutSession.evaluatedCases),\(format(withoutSession.hitAt1)),\(format(withoutSession.hitAt3)),\(format(withoutSession.hitAt5)),\(format(withoutSession.meanReciprocalRank)),\(format(withoutSession.noSuggestionRate))
        """
    }

    private func format(_ value: Double) -> String {
        String(format: "%.3f", value)
    }

    private func failedCaseSummary(_ failedCase: FoodRecommendationReplayFailedCase) -> String {
        let hidden = failedCase.hiddenCanonicalComponents.joined(separator: "+")
        let suggestions = failedCase.topSuggestionTitles.prefix(3).joined(separator: "+")
        return "\(failedCase.hiddenDisplayName)[\(hidden)]=>\(suggestions)#\(failedCase.missReason)"
    }

    private func balancedWeeklyHabitsScenario() -> GoldenReplayScenario {
        GoldenReplayScenario(
            name: "balanced-weekly-habits",
            minimumTrainingObservations: 6,
            maximumCases: nil,
            includeSessionContext: true,
            entries: { self.balancedWeeklyHabitEntries() }
        )
    }

    private func sessionCompletionScenario() -> GoldenReplayScenario {
        GoldenReplayScenario(
            name: "session-completion",
            minimumTrainingObservations: 13,
            maximumCases: nil,
            includeSessionContext: true,
            entries: { self.sessionCompletionEntries(dayCount: 7) }
        )
    }

    private func weekdayWeekendScenario() -> GoldenReplayScenario {
        GoldenReplayScenario(
            name: "weekday-weekend-split",
            minimumTrainingObservations: 10,
            maximumCases: nil,
            includeSessionContext: true,
            entries: { self.weekdayWeekendEntries() }
        )
    }

    private func anonymizedRealisticHistoryScenario() -> GoldenReplayScenario {
        GoldenReplayScenario(
            name: "anonymized-realistic-history",
            minimumTrainingObservations: 12,
            maximumCases: nil,
            includeSessionContext: true,
            entries: { self.anonymizedRealisticEntries() }
        )
    }

    private func balancedWeeklyHabitEntries() -> [FoodEntry] {
        var entries: [FoodEntry] = []
        for day in 0..<6 {
            entries.append(yogurtBowl(name: day == 4 ? "Greek yogurt with berries" : "Greek Yogurt Bowl", day: day, hour: 8))
            entries.append(chickenRice(name: day == 2 ? "Grilled chicken with rice" : "Chicken Rice Bowl", day: day, hour: 12))
            entries.append(salmonRice(name: day == 3 ? "Salmon plate with rice" : "Salmon Rice Bowl", day: day, hour: 19))
            entries.append(latte(day: day, hour: 15))
        }

        for day in 0..<4 {
            let sessionID = UUID()
            entries.append(coffee(day: day, hour: 9, sessionID: sessionID, order: 0))
            entries.append(bagel(day: day, hour: 9, minuteOffset: 5, sessionID: sessionID, order: 1))
        }

        entries.append(pastrami(day: 4, hour: 13))
        entries.append(chickenOnly(day: 5, hour: 16))
        return entries.sorted { $0.loggedAt < $1.loggedAt }
    }

    private func sessionCompletionEntries(dayCount: Int) -> [FoodEntry] {
        var entries: [FoodEntry] = []
        for day in 0..<dayCount {
            let sessionID = UUID()
            entries.append(coffee(day: day, hour: 8, sessionID: sessionID, order: 0))
            entries.append(bagel(day: day, hour: 8, minuteOffset: 5, sessionID: sessionID, order: 1))
        }
        return entries.sorted { $0.loggedAt < $1.loggedAt }
    }

    private func weekdayWeekendEntries() -> [FoodEntry] {
        var entries: [FoodEntry] = []
        for day in 0..<14 {
            let weekday = Calendar.current.component(.weekday, from: FoodRecommendationTestSupport.day(day, hour: 12))
            if weekday == 1 || weekday == 7 {
                entries.append(pancakeBrunch(day: day, hour: 10))
            } else {
                entries.append(turkeyWrap(day: day, hour: 12))
                entries.append(proteinShake(day: day, hour: 16))
            }
        }
        return entries.sorted { $0.loggedAt < $1.loggedAt }
    }

    private func anonymizedRealisticEntries() -> [FoodEntry] {
        var entries: [FoodEntry] = []
        for day in 0..<12 {
            let weekday = Calendar.current.component(.weekday, from: FoodRecommendationTestSupport.day(day, hour: 12))
            if weekday == 1 || weekday == 7 {
                entries.append(eggToastBrunch(day: day, hour: 10))
                entries.append(sushiDinner(day: day, hour: 19))
            } else {
                entries.append(oatmealBreakfast(day: day, hour: 7))
                entries.append(chickenDeskBowl(day: day, hour: 12))
                if day % 2 == 0 {
                    entries.append(proteinShake(day: day, hour: 16))
                }
                entries.append(tofuStirFry(day: day, hour: 19))
            }
        }
        entries.append(pastrami(day: 5, hour: 13))
        entries.append(chickenOnly(day: 8, hour: 15))
        return entries.sorted { $0.loggedAt < $1.loggedAt }
    }

    private func yogurtBowl(name: String, day: Int, hour: Int) -> FoodEntry {
        FoodRecommendationTestSupport.entry(
            name: name,
            loggedAt: FoodRecommendationTestSupport.day(day, hour: hour),
            calories: 340,
            protein: 28,
            carbs: 42,
            fat: 7,
            components: [
                component("greek yogurt", role: .protein, calories: 190, protein: 24, carbs: 10, fat: 4),
                component("berries", role: .fruit, calories: 60, protein: 1, carbs: 15, fat: 0),
                component("granola", role: .carb, calories: 90, protein: 3, carbs: 17, fat: 3)
            ]
        )
    }

    private func chickenRice(name: String, day: Int, hour: Int) -> FoodEntry {
        FoodRecommendationTestSupport.entry(
            name: name,
            loggedAt: FoodRecommendationTestSupport.day(day, hour: hour),
            calories: 620,
            protein: 42,
            carbs: 58,
            fat: 16,
            components: [
                component("chicken", role: .protein, calories: 240, protein: 38, carbs: 0, fat: 5),
                component("rice", role: .carb, calories: 205, protein: 4, carbs: 45, fat: 0),
                component("vegetables", role: .vegetable, calories: 80, protein: 2, carbs: 12, fat: 1)
            ]
        )
    }

    private func salmonRice(name: String, day: Int, hour: Int) -> FoodEntry {
        FoodRecommendationTestSupport.entry(
            name: name,
            loggedAt: FoodRecommendationTestSupport.day(day, hour: hour),
            calories: 670,
            protein: 44,
            carbs: 55,
            fat: 24,
            components: [
                component("salmon", role: .protein, calories: 320, protein: 38, carbs: 0, fat: 18),
                component("rice", role: .carb, calories: 205, protein: 4, carbs: 45, fat: 0),
                component("vegetables", role: .vegetable, calories: 70, protein: 2, carbs: 10, fat: 0)
            ]
        )
    }

    private func latte(day: Int, hour: Int) -> FoodEntry {
        FoodRecommendationTestSupport.entry(
            name: "Latte",
            loggedAt: FoodRecommendationTestSupport.day(day, hour: hour),
            calories: 150,
            protein: 8,
            carbs: 12,
            fat: 5,
            components: [
                component("latte", role: .drink, calories: 150, protein: 8, carbs: 12, fat: 5)
            ]
        )
    }

    private func coffee(day: Int, hour: Int, sessionID: UUID, order: Int) -> FoodEntry {
        FoodRecommendationTestSupport.entry(
            name: "Coffee",
            loggedAt: FoodRecommendationTestSupport.day(day, hour: hour),
            calories: 5,
            protein: 0,
            carbs: 1,
            fat: 0,
            components: [
                component("coffee", role: .drink, calories: 5, protein: 0, carbs: 1, fat: 0)
            ],
            sessionID: sessionID,
            sessionOrder: order
        )
    }

    private func bagel(day: Int, hour: Int, minuteOffset: TimeInterval, sessionID: UUID, order: Int) -> FoodEntry {
        FoodRecommendationTestSupport.entry(
            name: "Bagel",
            loggedAt: FoodRecommendationTestSupport.day(day, hour: hour).addingTimeInterval(minuteOffset * 60),
            calories: 290,
            protein: 10,
            carbs: 56,
            fat: 2,
            components: [
                component("bagel", role: .carb, calories: 290, protein: 10, carbs: 56, fat: 2)
            ],
            sessionID: sessionID,
            sessionOrder: order
        )
    }

    private func pastrami(day: Int, hour: Int) -> FoodEntry {
        FoodRecommendationTestSupport.entry(
            name: "Katz Pastrami Sandwich",
            loggedAt: FoodRecommendationTestSupport.day(day, hour: hour),
            calories: 850,
            protein: 35,
            carbs: 75,
            fat: 38,
            components: [
                component("pastrami", role: .protein, calories: 420, protein: 30, carbs: 0, fat: 30),
                component("rye bread", role: .carb, calories: 220, protein: 6, carbs: 40, fat: 3)
            ]
        )
    }

    private func chickenOnly(day: Int, hour: Int) -> FoodEntry {
        FoodRecommendationTestSupport.entry(
            name: "Chicken",
            loggedAt: FoodRecommendationTestSupport.day(day, hour: hour),
            calories: 240,
            protein: 38,
            carbs: 0,
            fat: 5,
            components: [
                component("chicken", role: .protein, calories: 240, protein: 38, carbs: 0, fat: 5)
            ]
        )
    }

    private func turkeyWrap(day: Int, hour: Int) -> FoodEntry {
        FoodRecommendationTestSupport.entry(
            name: day % 5 == 0 ? "Turkey avocado wrap" : "Turkey Wrap",
            loggedAt: FoodRecommendationTestSupport.day(day, hour: hour),
            calories: 540,
            protein: 36,
            carbs: 48,
            fat: 20,
            components: [
                component("turkey", role: .protein, calories: 210, protein: 32, carbs: 0, fat: 6),
                component("tortilla", role: .carb, calories: 190, protein: 5, carbs: 32, fat: 5),
                component("avocado", role: .fat, calories: 120, protein: 2, carbs: 8, fat: 11),
                component("greens", role: .vegetable, calories: 20, protein: 1, carbs: 4, fat: 0)
            ]
        )
    }

    private func proteinShake(day: Int, hour: Int) -> FoodEntry {
        FoodRecommendationTestSupport.entry(
            name: "Protein Shake",
            loggedAt: FoodRecommendationTestSupport.day(day, hour: hour),
            calories: 220,
            protein: 32,
            carbs: 14,
            fat: 4,
            components: [
                component("protein shake", role: .drink, calories: 220, protein: 32, carbs: 14, fat: 4)
            ]
        )
    }

    private func pancakeBrunch(day: Int, hour: Int) -> FoodEntry {
        FoodRecommendationTestSupport.entry(
            name: day % 2 == 0 ? "Pancake Brunch" : "Weekend pancakes",
            loggedAt: FoodRecommendationTestSupport.day(day, hour: hour),
            calories: 720,
            protein: 22,
            carbs: 104,
            fat: 24,
            components: [
                component("pancakes", role: .carb, calories: 430, protein: 12, carbs: 78, fat: 10),
                component("eggs", role: .protein, calories: 160, protein: 12, carbs: 1, fat: 11),
                component("syrup", role: .sauce, calories: 90, protein: 0, carbs: 24, fat: 0)
            ]
        )
    }

    private func oatmealBreakfast(day: Int, hour: Int) -> FoodEntry {
        FoodRecommendationTestSupport.entry(
            name: day % 3 == 0 ? "Overnight oats with yogurt" : "Oatmeal Yogurt Bowl",
            loggedAt: FoodRecommendationTestSupport.day(day, hour: hour),
            calories: 410,
            protein: 26,
            carbs: 58,
            fat: 9,
            components: [
                component("oats", role: .carb, calories: 210, protein: 6, carbs: 38, fat: 4),
                component("greek yogurt", role: .protein, calories: 150, protein: 18, carbs: 10, fat: 4),
                component("berries", role: .fruit, calories: 50, protein: 1, carbs: 12, fat: 0)
            ]
        )
    }

    private func chickenDeskBowl(day: Int, hour: Int) -> FoodEntry {
        FoodRecommendationTestSupport.entry(
            name: day % 4 == 0 ? "Desk lunch chicken bowl" : "Chicken Quinoa Bowl",
            loggedAt: FoodRecommendationTestSupport.day(day, hour: hour),
            calories: 590,
            protein: 44,
            carbs: 54,
            fat: 17,
            components: [
                component("chicken", role: .protein, calories: 245, protein: 39, carbs: 0, fat: 6),
                component("quinoa", role: .carb, calories: 220, protein: 8, carbs: 39, fat: 4),
                component("greens", role: .vegetable, calories: 45, protein: 2, carbs: 8, fat: 0),
                component("vinaigrette", role: .sauce, calories: 80, protein: 0, carbs: 3, fat: 8)
            ]
        )
    }

    private func tofuStirFry(day: Int, hour: Int) -> FoodEntry {
        FoodRecommendationTestSupport.entry(
            name: day % 5 == 0 ? "Tofu rice stir fry" : "Tofu Stir Fry",
            loggedAt: FoodRecommendationTestSupport.day(day, hour: hour),
            calories: 610,
            protein: 34,
            carbs: 68,
            fat: 22,
            components: [
                component("tofu", role: .protein, calories: 260, protein: 28, carbs: 8, fat: 14),
                component("rice", role: .carb, calories: 205, protein: 4, carbs: 45, fat: 0),
                component("vegetables", role: .vegetable, calories: 75, protein: 2, carbs: 14, fat: 1),
                component("stir fry sauce", role: .sauce, calories: 70, protein: 0, carbs: 10, fat: 3)
            ]
        )
    }

    private func eggToastBrunch(day: Int, hour: Int) -> FoodEntry {
        FoodRecommendationTestSupport.entry(
            name: day % 2 == 0 ? "Egg avocado toast" : "Weekend egg toast",
            loggedAt: FoodRecommendationTestSupport.day(day, hour: hour),
            calories: 520,
            protein: 24,
            carbs: 46,
            fat: 26,
            components: [
                component("eggs", role: .protein, calories: 210, protein: 18, carbs: 2, fat: 14),
                component("sourdough toast", role: .carb, calories: 180, protein: 7, carbs: 34, fat: 2),
                component("avocado", role: .fat, calories: 130, protein: 2, carbs: 8, fat: 12)
            ]
        )
    }

    private func sushiDinner(day: Int, hour: Int) -> FoodEntry {
        FoodRecommendationTestSupport.entry(
            name: day % 2 == 0 ? "Sushi dinner" : "Salmon avocado sushi",
            loggedAt: FoodRecommendationTestSupport.day(day, hour: hour),
            calories: 680,
            protein: 36,
            carbs: 88,
            fat: 20,
            components: [
                component("salmon", role: .protein, calories: 260, protein: 30, carbs: 0, fat: 14),
                component("sushi rice", role: .carb, calories: 300, protein: 5, carbs: 66, fat: 1),
                component("avocado", role: .fat, calories: 90, protein: 1, carbs: 5, fat: 8)
            ]
        )
    }

    private func component(
        _ name: String,
        role: FoodComponentRole,
        calories: Int,
        protein: Double,
        carbs: Double,
        fat: Double
    ) -> AcceptedFoodComponent {
        FoodRecommendationTestSupport.component(
            name,
            role: role,
            calories: calories,
            protein: protein,
            carbs: carbs,
            fat: fat
        )
    }
}

private struct GoldenReplayScenario {
    let name: String
    let minimumTrainingObservations: Int
    let maximumCases: Int?
    let includeSessionContext: Bool
    let entries: () -> [FoodEntry]
}

private struct GoldenReplayScenarioResult {
    let name: String
    let current: (metrics: FoodRecommendationReplayMetrics, debugReport: FoodRecommendationReplayDebugReport)
    let baseline: (metrics: FoodRecommendationReplayMetrics, debugReport: FoodRecommendationReplayDebugReport)
}
