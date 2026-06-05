import XCTest
@testable import Trai

@MainActor
final class FoodPatternRecommendationTests: XCTestCase {
    func testOneOffAcceptedFoodIsNotProactive() {
        let entries = [
            chickenRice("Chicken Rice Bowl", day: 0),
            chickenRice("Grilled Chicken With Rice", day: 1),
            chickenRice("Chicken and rice", day: 2),
            pastrami(day: 2)
        ]

        let result = FoodPatternRecommendationEngine().recommendationsSync(
            for: request(entries: entries, targetDay: 3)
        )

        XCTAssertTrue(result.suggestions.contains {
            Set($0.suggestedEntry.components.map(\.displayName)) == Set(["Chicken", "Rice"])
        })
        XCTAssertFalse(result.suggestions.contains { $0.suggestedEntry.name == "Katz Pastrami Sandwich" })
    }

    func testRecentOneOffCanOnlyAppearAsSessionCompletionWithAnchor() {
        let sessionID = UUID()
        let entries = [
            chickenRice("Chicken Rice Bowl", day: 0),
            FoodRecommendationTestSupport.entry(
                name: "Chicken",
                loggedAt: FoodRecommendationTestSupport.day(2),
                components: [FoodRecommendationTestSupport.component("chicken", role: .protein, calories: 240, protein: 38, carbs: 0, fat: 5)],
                sessionID: sessionID
            )
        ]

        let blankResult = FoodPatternRecommendationEngine().recommendationsSync(
            for: request(entries: entries, targetDay: 3)
        )
        let anchoredResult = FoodPatternRecommendationEngine().recommendationsSync(
            for: request(entries: entries, targetDay: 3, sessionID: sessionID)
        )

        XCTAssertTrue(blankResult.suggestions.isEmpty)
        XCTAssertTrue(anchoredResult.suggestions.contains { $0.suggestedEntry.name == "Chicken Rice Bowl" })
        XCTAssertEqual(anchoredResult.suggestions.first?.source, .continueSession)
    }

    func testEvidenceControlsLatteSuggestionsWithoutHardcodedMorningException() {
        let singleLatte = [
            latte(day: 2, hour: 8)
        ]
        let repeatedLatte = [
            latte(day: 0, hour: 8),
            latte(day: 1, hour: 8)
        ]

        let singleResult = FoodPatternRecommendationEngine().recommendationsSync(
            for: request(entries: singleLatte, targetDay: 3, targetHour: 8)
        )
        let repeatedResult = FoodPatternRecommendationEngine().recommendationsSync(
            for: request(entries: repeatedLatte, targetDay: 3, targetHour: 8)
        )

        XCTAssertFalse(singleResult.suggestions.contains { $0.suggestedEntry.name == "Latte" })
        XCTAssertTrue(repeatedResult.suggestions.contains { $0.suggestedEntry.name == "Latte" })
    }

    func testEverySuggestionIncludesProvenance() {
        let result = FoodPatternRecommendationEngine().recommendationsSync(
            for: request(entries: [
                chickenRice("Chicken Rice Bowl", day: 0),
                chickenRice("Grilled Chicken With Rice", day: 1)
            ], targetDay: 2)
        )

        let suggestion = result.suggestions.first
        XCTAssertFalse(suggestion?.provenance.sourceEntryIDs.isEmpty ?? true)
        XCTAssertFalse(suggestion?.provenance.sourceTitles.isEmpty ?? true)
        XCTAssertFalse(suggestion?.provenance.sourceLoggedAt.isEmpty ?? true)
        XCTAssertTrue(suggestion?.provenance.reasonCodes.contains("repeated-history") ?? false)
    }

    func testSubstantialPatternsStayCompetitiveWithFrequentSimpleDrinks() {
        let entries = [
            drink("Latte", component: "latte", day: 0, hour: 12),
            drink("Latte", component: "latte", day: 1, hour: 12),
            drink("Cappuccino", component: "cappuccino", day: 0, hour: 12),
            drink("Cappuccino", component: "cappuccino", day: 1, hour: 12),
            drink("Iced Latte", component: "iced latte", day: 0, hour: 12),
            drink("Iced Latte", component: "iced latte", day: 1, hour: 12),
            chickenRice("Chicken Rice Bowl", day: 0),
            chickenRice("Chicken Rice Bowl", day: 1)
        ]

        let result = FoodPatternRecommendationEngine().recommendationsSync(
            for: request(entries: entries, targetDay: 2, targetHour: 12)
        )

        XCTAssertEqual(result.suggestions.first?.suggestedEntry.name, "Chicken Rice Bowl")
        XCTAssertTrue(result.suggestions.contains { $0.pattern.componentProfile.allSatisfy { $0.role == .drink } })
    }

    func testMorningLatteHabitRanksFirstWithoutBreakfastBias() {
        var entries: [FoodEntry] = []
        for day in 0..<7 {
            entries.append(drink("Iced Latte", component: "iced latte", day: day, hour: 8))
            entries.append(chickenRice("Chicken Rice Bowl", day: day, hour: 19))
        }

        let result = FoodPatternRecommendationEngine().recommendationsSync(
            for: request(entries: entries, targetDay: 7, targetHour: 8)
        )

        XCTAssertEqual(result.suggestions.first?.suggestedEntry.name, "Iced Latte")
    }

    func testBeverageOnlyHabitsCanFillTopSuggestionsWhenThatIsTheUserPattern() {
        var entries: [FoodEntry] = []
        for day in 0..<4 {
            entries.append(drink("Iced Latte", component: "iced latte", day: day, hour: 8))
            entries.append(drink("Coffee", component: "coffee", day: day, hour: 8))
            entries.append(drink("Protein Shake", component: "protein shake", day: day, hour: 8))
        }

        let result = FoodPatternRecommendationEngine().recommendationsSync(
            for: request(entries: entries, targetDay: 4, targetHour: 8)
        )

        XCTAssertEqual(result.suggestions.count, 3)
        XCTAssertTrue(result.suggestions.allSatisfy { $0.pattern.componentProfile.allSatisfy { $0.role == .drink } })
    }

    func testSemanticallySatisfiedPatternDoesNotCrowdOutCurrentOpportunity() {
        let entries = [
            oatsYogurt("Oats Yogurt Bowl", day: 0, hour: 8),
            oatsYogurt("Oats Yogurt Bowl", day: 1, hour: 8),
            chickenRice("Chicken Rice Bowl", day: 0),
            chickenRice("Chicken Rice Bowl", day: 1),
            FoodRecommendationTestSupport.entry(
                name: "Oats Yogurt",
                loggedAt: FoodRecommendationTestSupport.day(2, hour: 8),
                calories: 360,
                protein: 24,
                carbs: 48,
                fat: 8,
                components: [
                    FoodRecommendationTestSupport.component("oats", role: .carb, calories: 210, protein: 6, carbs: 38, fat: 4),
                    FoodRecommendationTestSupport.component("greek yogurt", role: .protein, calories: 150, protein: 18, carbs: 10, fat: 4)
                ]
            )
        ]

        let result = FoodPatternRecommendationEngine().recommendationsSync(
            for: request(entries: entries, targetDay: 2, targetHour: 12)
        )

        XCTAssertFalse(result.suggestions.contains { $0.suggestedEntry.name == "Oats Yogurt Bowl" })
        XCTAssertEqual(result.suggestions.first?.suggestedEntry.name, "Chicken Rice Bowl")
    }

    func testPartialComponentOverlapDoesNotCountAsAlreadySatisfied() {
        let entries = [
            chickenRice("Chicken Rice Bowl", day: 0),
            chickenRice("Chicken Rice Bowl", day: 1),
            chickenSalad(day: 2, hour: 9)
        ]

        let result = FoodPatternRecommendationEngine().recommendationsSync(
            for: request(entries: entries, targetDay: 2, targetHour: 12)
        )

        XCTAssertEqual(result.debugReport.suppressedAlreadyTodayCount, 0)
        XCTAssertTrue(result.suggestions.contains { $0.suggestedEntry.name == "Chicken Rice Bowl" })
    }

    func testEmbeddingSatisfiedSingleItemDoesNotRemainSuggestedAllDay() {
        let entries = [
            drink("Coffee", component: "coffee", day: 0, hour: 8),
            drink("Coffee", component: "coffee", day: 1, hour: 8),
            chickenRice("Chicken Rice Bowl", day: 0),
            chickenRice("Chicken Rice Bowl", day: 1),
            drink("Iced Latte", component: "latte", day: 2, hour: 8)
        ]

        let result = FoodPatternRecommendationEngine().recommendationsSync(
            for: request(entries: entries, targetDay: 2, targetHour: 12)
        )

        XCTAssertFalse(result.suggestions.contains { $0.suggestedEntry.name == "Coffee" })
        XCTAssertEqual(result.suggestions.first?.suggestedEntry.name, "Chicken Rice Bowl")
    }

    func testLearnedSameDayRepeatCanStillSuggestAfterHistoricalSpacing() {
        let targetDay = 2
        let entries = [
            oatsYogurt("Oats Yogurt Bowl", day: 0, hour: 8),
            oatsYogurt("Oats Yogurt Bowl", day: 0, hour: 15),
            oatsYogurt("Oats Yogurt Bowl", day: 1, hour: 8),
            oatsYogurt("Oats Yogurt Bowl", day: 1, hour: 15),
            oatsYogurt("Oats Yogurt Bowl", day: targetDay, hour: 8)
        ]

        let result = FoodPatternRecommendationEngine().recommendationsSync(
            for: request(entries: entries, targetDay: targetDay, targetHour: 15)
        )

        XCTAssertTrue(result.suggestions.contains { $0.suggestedEntry.name == "Oats Yogurt Bowl" })
    }

    func testLearnedSameDayRepeatDoesNotSuggestTooEarlyAfterTodayUse() {
        let targetDay = 2
        let entries = [
            oatsYogurt("Oats Yogurt Bowl", day: 0, hour: 8),
            oatsYogurt("Oats Yogurt Bowl", day: 0, hour: 15),
            oatsYogurt("Oats Yogurt Bowl", day: 1, hour: 8),
            oatsYogurt("Oats Yogurt Bowl", day: 1, hour: 15),
            oatsYogurt("Oats Yogurt Bowl", day: targetDay, hour: 8)
        ]

        let result = FoodPatternRecommendationEngine().recommendationsSync(
            for: request(entries: entries, targetDay: targetDay, targetHour: 10)
        )

        XCTAssertGreaterThan(result.debugReport.suppressedAlreadyTodayCount, 0)
        XCTAssertFalse(result.suggestions.contains { $0.suggestedEntry.name == "Oats Yogurt Bowl" })
    }

    func testEmergingSameDayRepeatIsDemotedInsteadOfSuppressed() {
        let targetDay = 1
        let entries = [
            oatsYogurt("Oats Yogurt Bowl", day: 0, hour: 8),
            oatsYogurt("Oats Yogurt Bowl", day: 0, hour: 14),
            oatsYogurt("Oats Yogurt Bowl", day: targetDay, hour: 8)
        ]

        let result = FoodPatternRecommendationEngine().recommendationsSync(
            for: request(entries: entries, targetDay: targetDay, targetHour: 13)
        )

        XCTAssertEqual(result.debugReport.suppressedAlreadyTodayCount, 0)
        XCTAssertGreaterThan(result.debugReport.demotedAlreadyTodayCount, 0)
        XCTAssertTrue(result.suggestions.contains { $0.suggestedEntry.name == "Oats Yogurt Bowl" })
    }

    private func request(
        entries: [FoodEntry],
        targetDay: Int,
        targetHour: Int = 12,
        sessionID: UUID? = nil
    ) -> FoodRecommendationRequest {
        FoodRecommendationRequest(
            now: FoodRecommendationTestSupport.day(targetDay, hour: targetHour),
            targetDate: FoodRecommendationTestSupport.day(targetDay, hour: targetHour),
            sessionID: sessionID,
            limit: 3,
            entries: entries,
            memories: []
        )
    }

    private func chickenRice(_ name: String, day: Int, hour: Int = 12) -> FoodEntry {
        FoodRecommendationTestSupport.entry(
            name: name,
            loggedAt: FoodRecommendationTestSupport.day(day, hour: hour),
            components: [
                FoodRecommendationTestSupport.component("chicken", role: .protein, calories: 240, protein: 38, carbs: 0, fat: 5),
                FoodRecommendationTestSupport.component("rice", role: .carb, calories: 205, protein: 4, carbs: 45, fat: 0)
            ]
        )
    }

    private func chickenSalad(day: Int, hour: Int) -> FoodEntry {
        FoodRecommendationTestSupport.entry(
            name: "Chicken Salad",
            loggedAt: FoodRecommendationTestSupport.day(day, hour: hour),
            calories: 430,
            protein: 38,
            carbs: 14,
            fat: 22,
            components: [
                FoodRecommendationTestSupport.component("chicken", role: .protein, calories: 240, protein: 38, carbs: 0, fat: 5),
                FoodRecommendationTestSupport.component("greens", role: .vegetable, calories: 70, protein: 0, carbs: 14, fat: 2),
                FoodRecommendationTestSupport.component("dressing", role: .fat, calories: 120, protein: 0, carbs: 0, fat: 15)
            ]
        )
    }

    private func pastrami(day: Int) -> FoodEntry {
        FoodRecommendationTestSupport.entry(
            name: "Katz Pastrami Sandwich",
            loggedAt: FoodRecommendationTestSupport.day(day),
            calories: 850,
            protein: 35,
            carbs: 75,
            fat: 38,
            components: [
                FoodRecommendationTestSupport.component("pastrami", role: .protein, calories: 420, protein: 30, carbs: 0, fat: 30),
                FoodRecommendationTestSupport.component("rye bread", role: .carb, calories: 220, protein: 6, carbs: 40, fat: 3)
            ]
        )
    }

    private func latte(day: Int, hour: Int) -> FoodEntry {
        drink("Latte", component: "latte", day: day, hour: hour)
    }

    private func oatsYogurt(_ name: String, day: Int, hour: Int) -> FoodEntry {
        FoodRecommendationTestSupport.entry(
            name: name,
            loggedAt: FoodRecommendationTestSupport.day(day, hour: hour),
            calories: 360,
            protein: 24,
            carbs: 48,
            fat: 8,
            components: [
                FoodRecommendationTestSupport.component("oats", role: .carb, calories: 210, protein: 6, carbs: 38, fat: 4),
                FoodRecommendationTestSupport.component("yogurt", role: .protein, calories: 150, protein: 18, carbs: 10, fat: 4)
            ]
        )
    }

    private func drink(_ name: String, component: String, day: Int, hour: Int) -> FoodEntry {
        FoodRecommendationTestSupport.entry(
            name: name,
            loggedAt: FoodRecommendationTestSupport.day(day, hour: hour),
            calories: 150,
            protein: 8,
            carbs: 12,
            fat: 5,
            components: [
                FoodRecommendationTestSupport.component(component, role: .drink, calories: 150, protein: 8, carbs: 12, fat: 5)
            ]
        )
    }
}
