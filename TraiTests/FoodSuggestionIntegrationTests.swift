import SwiftData
import XCTest
@testable import Trai

@MainActor
final class FoodSuggestionIntegrationTests: XCTestCase {
    func testCameraSuggestionsUseHabitEngineForFragmentedStaples() throws {
        let context = try modelContext()
        for entry in [
            entry("Chicken Rice Bowl", day: 0),
            entry("Roasted Chicken Breast With Rice", day: 1),
            entry("Grilled Chicken With Brown Rice", day: 2),
            FoodRecommendationTestSupport.entry(
                name: "Katz Pastrami Sandwich",
                loggedAt: FoodRecommendationTestSupport.day(3),
                calories: 850,
                protein: 35,
                carbs: 75,
                fat: 38,
                components: pastramiComponents()
            )
        ] {
            context.insert(entry)
        }
        try context.save()

        let suggestions = try FoodSuggestionService().cameraSuggestions(
            limit: 3,
            now: FoodRecommendationTestSupport.day(4),
            targetDate: FoodRecommendationTestSupport.day(4),
            modelContext: context
        )

        XCTAssertEqual(suggestions.first?.suggestedEntry.components.map(\.displayName).sorted(), ["Chicken", "Rice"])
    }

    func testCameraSuggestionsDoNotRequireFoodMemoryObservationCounts() throws {
        let context = try modelContext()
        let first = entry("Chicken Rice Bowl", day: 0)
        let second = entry("Grilled Chicken With Rice", day: 1)
        first.foodMemoryIdString = UUID().uuidString
        second.foodMemoryIdString = UUID().uuidString
        context.insert(first)
        context.insert(second)
        try context.save()

        let suggestions = try FoodSuggestionService().cameraSuggestions(
            limit: 3,
            now: FoodRecommendationTestSupport.day(2),
            targetDate: FoodRecommendationTestSupport.day(2),
            modelContext: context
        )

        XCTAssertFalse(suggestions.isEmpty)
        XCTAssertEqual(suggestions.first?.suggestedEntry.components.map(\.displayName).sorted(), ["Chicken", "Rice"])
    }

    func testCameraSuggestionsDoNotRecordShownUntilExposureIsRecorded() throws {
        let context = try modelContext()
        let first = entry("Chicken Rice Bowl", day: 0)
        let second = entry("Chicken Rice Bowl", day: 1)
        let persistedMemory = memory(title: "Chicken Rice Bowl", entries: [first, second])
        first.foodMemoryIdString = persistedMemory.id.uuidString
        second.foodMemoryIdString = persistedMemory.id.uuidString
        context.insert(first)
        context.insert(second)
        context.insert(persistedMemory)
        try context.save()
        let suggestion = try XCTUnwrap(
            FoodSuggestionService().cameraSuggestions(
                limit: 1,
                now: FoodRecommendationTestSupport.day(2),
                targetDate: FoodRecommendationTestSupport.day(2),
                modelContext: context
            ).first
        )

        XCTAssertNil(try context.fetch(FetchDescriptor<FoodMemory>()).first { $0.id == suggestion.memoryID }?.suggestionStats)

        try FoodSuggestionService().recordOutcome(.shown, for: suggestion.memoryID, modelContext: context)
        XCTAssertNoThrow(
            try FoodSuggestionService().recordOutcome(.accepted, for: suggestion.memoryID, modelContext: context)
        )
        let memories = try context.fetch(FetchDescriptor<FoodMemory>())
        let memory = try XCTUnwrap(memories.first { $0.id == suggestion.memoryID })
        XCTAssertGreaterThan(memory.suggestionStats?.timesShown ?? 0, 0)
        XCTAssertEqual(memory.suggestionStats?.timesAccepted, 1)
    }

    func testObservationBuiltSuggestionRecordsShownOnPersistedMemoryWhenExplicitlyRecorded() throws {
        let context = try modelContext()
        let first = entry("Chicken Rice Bowl", day: 0)
        let second = entry("Chicken Rice Bowl", day: 1)
        let persistedMemory = memory(title: "Chicken Rice Bowl", entries: [first, second])
        first.foodMemoryIdString = persistedMemory.id.uuidString
        second.foodMemoryIdString = persistedMemory.id.uuidString
        context.insert(first)
        context.insert(second)
        context.insert(persistedMemory)
        try context.save()

        let suggestion = try XCTUnwrap(
            FoodSuggestionService().cameraSuggestions(
                limit: 1,
                now: FoodRecommendationTestSupport.day(2),
                targetDate: FoodRecommendationTestSupport.day(2),
                modelContext: context
            ).first
        )
        try FoodSuggestionService().recordOutcome(.shown, for: suggestion.memoryID, modelContext: context)
        let memories = try context.fetch(FetchDescriptor<FoodMemory>())
        let memory = try XCTUnwrap(memories.first { $0.id == suggestion.memoryID })

        XCTAssertGreaterThan(memory.suggestionStats?.timesShown ?? 0, 0)
        XCTAssertTrue(memory.representativeEntryIds.isEmpty == false)
    }

    func testIgnoredSuggestionOutcomeIsTrackedSeparatelyFromDismissal() throws {
        let context = try modelContext()
        let first = entry("Chicken Rice Bowl", day: 0)
        let second = entry("Chicken Rice Bowl", day: 1)
        let persistedMemory = memory(title: "Chicken Rice Bowl", entries: [first, second])
        first.foodMemoryIdString = persistedMemory.id.uuidString
        second.foodMemoryIdString = persistedMemory.id.uuidString
        context.insert(first)
        context.insert(second)
        context.insert(persistedMemory)
        try context.save()

        let suggestion = try XCTUnwrap(
            FoodSuggestionService().cameraSuggestions(
                limit: 1,
                now: FoodRecommendationTestSupport.day(2),
                targetDate: FoodRecommendationTestSupport.day(2),
                modelContext: context
            ).first
        )
        try FoodSuggestionService().recordOutcome(.shown, for: suggestion.memoryID, modelContext: context)
        try FoodSuggestionService().recordOutcome(.ignored, for: suggestion.memoryID, modelContext: context)
        let memory = try XCTUnwrap(try context.fetch(FetchDescriptor<FoodMemory>()).first { $0.id == suggestion.memoryID })

        XCTAssertEqual(memory.suggestionStats?.timesShown, 1)
        XCTAssertEqual(memory.suggestionStats?.timesIgnored, 1)
        XCTAssertEqual(memory.suggestionStats?.timesDismissed, 0)
        XCTAssertNotNil(memory.suggestionStats?.lastIgnoredAt)
    }

    func testObservationBuiltSuggestionReconcileRecordsAcceptance() throws {
        let context = try modelContext()
        let accepted = entry("Chicken Rice Bowl", day: 2)
        let first = entry("Chicken Rice Bowl", day: 0)
        let second = entry("Chicken Rice Bowl", day: 1)
        let persistedMemory = memory(title: "Chicken Rice Bowl", entries: [first, second])
        first.foodMemoryIdString = persistedMemory.id.uuidString
        second.foodMemoryIdString = persistedMemory.id.uuidString
        context.insert(first)
        context.insert(second)
        context.insert(persistedMemory)
        try context.save()
        let suggestion = try XCTUnwrap(
            FoodSuggestionService().cameraSuggestions(
                limit: 1,
                now: FoodRecommendationTestSupport.day(2),
                targetDate: FoodRecommendationTestSupport.day(2),
                modelContext: context
            ).first
        )

        try FoodSuggestionService().reconcileShownSuggestions(
            [suggestion.memoryID],
            preferredMemoryID: suggestion.memoryID,
            with: try XCTUnwrap(accepted.acceptedSnapshot),
            isRefined: false,
            modelContext: context
        )
        let memory = try XCTUnwrap(try context.fetch(FetchDescriptor<FoodMemory>()).first { $0.id == suggestion.memoryID })

        XCTAssertEqual(memory.suggestionStats?.timesAccepted, 1)
    }

    func testObservationBuiltSuggestionFeedbackSuppressesLaterRanking() throws {
        let context = try modelContext()
        let first = entry("Chicken Rice Bowl", day: 0)
        let second = entry("Chicken Rice Bowl", day: 1)
        let persistedMemory = memory(title: "Chicken Rice Bowl", entries: [first, second])
        first.foodMemoryIdString = persistedMemory.id.uuidString
        second.foodMemoryIdString = persistedMemory.id.uuidString
        context.insert(first)
        context.insert(second)
        context.insert(persistedMemory)
        try context.save()
        let suggestion = try XCTUnwrap(
            FoodSuggestionService().cameraSuggestions(
                limit: 1,
                now: FoodRecommendationTestSupport.day(2, hour: 9),
                targetDate: FoodRecommendationTestSupport.day(2, hour: 9),
                modelContext: context
            ).first
        )

        try FoodSuggestionService().recordOutcome(.dismissed, for: suggestion.memoryID, at: FoodRecommendationTestSupport.day(2, hour: 9), modelContext: context)
        let laterSuggestions = try FoodSuggestionService().cameraSuggestions(
            limit: 1,
            now: FoodRecommendationTestSupport.day(2, hour: 10),
            targetDate: FoodRecommendationTestSupport.day(2, hour: 10),
            modelContext: context
        )

        XCTAssertFalse(laterSuggestions.contains { $0.memoryID == suggestion.memoryID })
    }

    func testPatternSuggestionsDoNotMaterializeFoodMemoryRowsOnShow() throws {
        let context = try modelContext()
        context.insert(entry("Chicken Rice Bowl", day: 0))
        context.insert(entry("Chicken Rice Bowl", day: 1))
        try context.save()

        let suggestions = try FoodSuggestionService().cameraSuggestions(
            limit: 1,
            now: FoodRecommendationTestSupport.day(2),
            targetDate: FoodRecommendationTestSupport.day(2),
            modelContext: context
        )
        let memories = try context.fetch(FetchDescriptor<FoodMemory>())

        XCTAssertFalse(suggestions.isEmpty)
        XCTAssertTrue(memories.isEmpty)
    }

    func testPatternSuggestionFeedbackPersistsWithoutFoodMemoryRow() throws {
        let context = try modelContext()
        context.insert(entry("Chicken Rice Bowl", day: 0))
        context.insert(entry("Chicken Rice Bowl", day: 1))
        try context.save()

        let suggestion = try XCTUnwrap(
            FoodSuggestionService().cameraSuggestions(
                limit: 1,
                now: FoodRecommendationTestSupport.day(2, hour: 12),
                targetDate: FoodRecommendationTestSupport.day(2, hour: 12),
                modelContext: context
            ).first
        )
        try FoodSuggestionService().recordOutcome(.shown, for: suggestion.memoryID, at: FoodRecommendationTestSupport.day(2, hour: 12), modelContext: context)
        try FoodSuggestionService().recordOutcome(.ignored, for: suggestion.memoryID, at: FoodRecommendationTestSupport.day(2, hour: 12), modelContext: context)

        let memories = try context.fetch(FetchDescriptor<FoodMemory>())
        let feedback = try XCTUnwrap(try context.fetch(FetchDescriptor<FoodSuggestionFeedback>()).first { $0.suggestionID == suggestion.memoryID })
        let laterSuggestions = try FoodSuggestionService().cameraSuggestions(
            limit: 3,
            now: FoodRecommendationTestSupport.day(3, hour: 12),
            targetDate: FoodRecommendationTestSupport.day(3, hour: 12),
            modelContext: context
        )

        XCTAssertTrue(memories.isEmpty)
        XCTAssertEqual(feedback.stats?.timesShown, 1)
        XCTAssertEqual(feedback.stats?.timesIgnored, 1)
        XCTAssertTrue(laterSuggestions.contains { $0.memoryID == suggestion.memoryID })
    }

    func testGeneratedPatternFeedbackSurvivesNormalPortionDrift() throws {
        let context = try modelContext()
        context.insert(entry("Chicken Rice Bowl", day: 0, calories: 490, protein: 38, carbs: 54, fat: 12))
        context.insert(entry("Chicken Rice Bowl", day: 1, calories: 490, protein: 38, carbs: 54, fat: 12))
        try context.save()

        let originalSuggestion = try XCTUnwrap(
            FoodSuggestionService().cameraSuggestions(
                limit: 1,
                now: FoodRecommendationTestSupport.day(2, hour: 12),
                targetDate: FoodRecommendationTestSupport.day(2, hour: 12),
                modelContext: context
            ).first
        )
        try FoodSuggestionService().recordOutcome(
            .ignored,
            for: originalSuggestion.memoryID,
            at: FoodRecommendationTestSupport.day(2, hour: 12),
            modelContext: context
        )

        context.insert(entry("Chicken Rice Bowl", day: 3, calories: 520, protein: 40, carbs: 58, fat: 13))
        context.insert(entry("Chicken Rice Bowl", day: 4, calories: 520, protein: 40, carbs: 58, fat: 13))
        try context.save()

        let driftedSuggestion = try XCTUnwrap(
            FoodSuggestionService().cameraSuggestions(
                limit: 3,
                now: FoodRecommendationTestSupport.day(5, hour: 12),
                targetDate: FoodRecommendationTestSupport.day(5, hour: 12),
                modelContext: context
            ).first(where: { Set($0.suggestedEntry.components.map(\.displayName)) == Set(["Chicken", "Rice"]) })
        )
        let feedback = try XCTUnwrap(try context.fetch(FetchDescriptor<FoodSuggestionFeedback>()).first { $0.suggestionID == originalSuggestion.memoryID })

        XCTAssertEqual(driftedSuggestion.memoryID, originalSuggestion.memoryID)
        XCTAssertEqual(feedback.stats?.timesIgnored, 1)
    }

    func testDuplicateGeneratedFeedbackRowsAreMergedForPatternRanking() throws {
        let context = try modelContext()
        context.insert(entry("Chicken Rice Bowl", day: 0))
        context.insert(entry("Chicken Rice Bowl", day: 1))
        try context.save()

        let suggestion = try XCTUnwrap(
            FoodSuggestionService().cameraSuggestions(
                limit: 1,
                now: FoodRecommendationTestSupport.day(2, hour: 12),
                targetDate: FoodRecommendationTestSupport.day(2, hour: 12),
                modelContext: context
            ).first
        )
        context.insert(FoodSuggestionFeedback(
            suggestionID: suggestion.memoryID,
            stats: FoodMemorySuggestionStats(
                timesShown: 1,
                timesTapped: 0,
                timesIgnored: 1,
                timesAccepted: 0,
                timesDismissed: 0,
                timesRefined: 0,
                lastShownAt: nil,
                lastTappedAt: nil,
                lastIgnoredAt: FoodRecommendationTestSupport.day(2, hour: 12),
                lastAcceptedAt: nil,
                lastDismissedAt: nil,
                lastRefinedAt: nil
            )
        ))
        context.insert(FoodSuggestionFeedback(
            suggestionID: suggestion.memoryID,
            stats: FoodMemorySuggestionStats(
                timesShown: 2,
                timesTapped: 0,
                timesIgnored: 2,
                timesAccepted: 0,
                timesDismissed: 0,
                timesRefined: 0,
                lastShownAt: nil,
                lastTappedAt: nil,
                lastIgnoredAt: FoodRecommendationTestSupport.day(2, hour: 13),
                lastAcceptedAt: nil,
                lastDismissedAt: nil,
                lastRefinedAt: nil
            )
        ))
        try context.save()

        let laterSuggestions = try FoodSuggestionService().cameraSuggestions(
            limit: 3,
            now: FoodRecommendationTestSupport.day(2, hour: 14),
            targetDate: FoodRecommendationTestSupport.day(2, hour: 14),
            modelContext: context
        )

        XCTAssertFalse(laterSuggestions.isEmpty)
    }

    func testGeneratedFeedbackGracefullySkipsPartialSchemas() throws {
        let context = try partialModelContext()
        context.insert(entry("Chicken Rice Bowl", day: 0))
        context.insert(entry("Chicken Rice Bowl", day: 1))
        try context.save()

        let suggestion = try XCTUnwrap(
            FoodSuggestionService().cameraSuggestions(
                limit: 1,
                now: FoodRecommendationTestSupport.day(2, hour: 12),
                targetDate: FoodRecommendationTestSupport.day(2, hour: 12),
                modelContext: context
            ).first
        )

        XCTAssertNoThrow(
            try FoodSuggestionService().recordOutcome(
                .ignored,
                for: suggestion.memoryID,
                at: FoodRecommendationTestSupport.day(2, hour: 12),
                modelContext: context
            )
        )

        let laterSuggestions = try FoodSuggestionService().cameraSuggestions(
            limit: 3,
            now: FoodRecommendationTestSupport.day(3, hour: 12),
            targetDate: FoodRecommendationTestSupport.day(3, hour: 12),
            modelContext: context
        )

        XCTAssertTrue(laterSuggestions.contains { $0.memoryID == suggestion.memoryID })
    }

    func testOldIgnoredPatternFeedbackDoesNotHideLongTermHabit() throws {
        let context = try modelContext()
        for day in 0..<8 {
            context.insert(entry(day % 2 == 0 ? "Chicken Rice Bowl" : "Grilled Chicken With Rice", day: day))
        }
        try context.save()

        let suggestion = try XCTUnwrap(
            FoodSuggestionService().cameraSuggestions(
                limit: 1,
                now: FoodRecommendationTestSupport.day(8, hour: 12),
                targetDate: FoodRecommendationTestSupport.day(8, hour: 12),
                modelContext: context
            ).first
        )
        for day in 8..<11 {
            try FoodSuggestionService().recordOutcome(.shown, for: suggestion.memoryID, at: FoodRecommendationTestSupport.day(day, hour: 12), modelContext: context)
            try FoodSuggestionService().recordOutcome(.ignored, for: suggestion.memoryID, at: FoodRecommendationTestSupport.day(day, hour: 12), modelContext: context)
        }

        let recoveredSuggestions = try FoodSuggestionService().cameraSuggestions(
            limit: 3,
            now: FoodRecommendationTestSupport.day(14, hour: 12),
            targetDate: FoodRecommendationTestSupport.day(14, hour: 12),
            modelContext: context
        )

        XCTAssertEqual(recoveredSuggestions.first?.memoryID, suggestion.memoryID)
        XCTAssertEqual(recoveredSuggestions.first?.suggestedEntry.components.map(\.displayName).sorted(), ["Chicken", "Rice"])
    }

    func testAcceptedPatternSuggestionCreditsResolvedMemory() throws {
        let context = try modelContext()
        context.insert(entry("Chicken Rice Bowl", day: 0))
        context.insert(entry("Chicken Rice Bowl", day: 1))
        try context.save()
        let suggestion = try XCTUnwrap(
            FoodSuggestionService().cameraSuggestions(
                limit: 1,
                now: FoodRecommendationTestSupport.day(2),
                targetDate: FoodRecommendationTestSupport.day(2),
                modelContext: context
            ).first
        )

        let accepted = entry("Chicken Rice Bowl", day: 2)
        context.insert(accepted)
        try context.save()
        XCTAssertTrue(try FoodMemoryService().resolveEntry(id: accepted.id, modelContext: context))

        try FoodSuggestionService().reconcileShownSuggestions(
            [suggestion.memoryID],
            preferredMemoryID: suggestion.memoryID,
            with: try XCTUnwrap(accepted.acceptedSnapshot),
            isRefined: false,
            modelContext: context
        )
        let memories = try context.fetch(FetchDescriptor<FoodMemory>())
        let resolvedMemory = try XCTUnwrap(memories.first)

        XCTAssertNotEqual(resolvedMemory.id, suggestion.memoryID)
        XCTAssertEqual(resolvedMemory.suggestionStats?.timesAccepted, 1)
    }

    func testFutureSameDayDinnerDoesNotSuppressNoonRecommendation() throws {
        let context = try modelContext()
        context.insert(entry("Chicken Rice Bowl", day: 0))
        context.insert(entry("Chicken Rice Bowl", day: 1))
        context.insert(
            FoodRecommendationTestSupport.entry(
                name: "Katz Pastrami Sandwich",
                loggedAt: FoodRecommendationTestSupport.day(2, hour: 19),
                calories: 850,
                protein: 35,
                carbs: 75,
                fat: 38,
                components: pastramiComponents()
            )
        )
        try context.save()

        let suggestions = try FoodSuggestionService().cameraSuggestions(
            limit: 3,
            now: FoodRecommendationTestSupport.day(2, hour: 12),
            targetDate: FoodRecommendationTestSupport.day(2, hour: 12),
            modelContext: context
        )

        XCTAssertEqual(suggestions.first?.title, "Chicken Rice Bowl")
        XCTAssertFalse(suggestions.contains { $0.title == "Katz Pastrami Sandwich" })
    }

    func testFutureOneOffDoesNotBecomeCandidateOrDebugObservationForTargetInstant() throws {
        let context = try modelContext()
        context.insert(entry("Chicken Rice Bowl", day: 0))
        context.insert(entry("Chicken Rice Bowl", day: 1))
        context.insert(
            FoodRecommendationTestSupport.entry(
                name: "Katz Pastrami Sandwich",
                loggedAt: FoodRecommendationTestSupport.day(2, hour: 13),
                calories: 850,
                protein: 35,
                carbs: 75,
                fat: 38,
                components: pastramiComponents()
            )
        )
        try context.save()

        let summary = try FoodSuggestionService().debugCameraSuggestions(
            limit: 3,
            now: FoodRecommendationTestSupport.day(2, hour: 12),
            targetDate: FoodRecommendationTestSupport.day(2, hour: 12),
            modelContext: context
        )

        XCTAssertEqual(summary.totalObservations, 2)
        XCTAssertFalse(summary.shownSuggestionTitles.contains("Katz Pastrami Sandwich"))
    }

    func testEarlierTodayLogStillSuppressesAlreadyLoggedSuggestion() throws {
        let context = try modelContext()
        context.insert(entry("Chicken Rice Bowl", day: 0))
        context.insert(entry("Chicken Rice Bowl", day: 1))
        context.insert(
            FoodRecommendationTestSupport.entry(
                name: "Chicken Rice Bowl",
                loggedAt: FoodRecommendationTestSupport.day(2, hour: 8),
                components: chickenRiceComponents()
            )
        )
        try context.save()

        let summary = try FoodSuggestionService().debugCameraSuggestions(
            limit: 3,
            now: FoodRecommendationTestSupport.day(2, hour: 12),
            targetDate: FoodRecommendationTestSupport.day(2, hour: 12),
            modelContext: context
        )

        XCTAssertGreaterThan(summary.suppressedAlreadyTodayCount, 0)
        XCTAssertFalse(summary.shownSuggestionTitles.contains("Chicken Rice Bowl"))
    }

    func testPersistedMemorySuggestionIsSuppressedBySemanticTodayLog() throws {
        let context = try modelContext()
        context.insert(drinkEntry("Coffee", component: "coffee", day: 0, hour: 8))
        context.insert(drinkEntry("Coffee", component: "coffee", day: 1, hour: 8))
        context.insert(drinkEntry("Iced Latte", component: "latte", day: 2, hour: 8))
        context.insert(drinkMemory(title: "Coffee", component: "coffee"))
        try context.save()

        let suggestions = try FoodSuggestionService().cameraSuggestions(
            limit: 3,
            now: FoodRecommendationTestSupport.day(2, hour: 9),
            targetDate: FoodRecommendationTestSupport.day(2, hour: 9),
            modelContext: context
        )

        XCTAssertFalse(suggestions.contains { $0.title == "Coffee" })

        let summary = try FoodSuggestionService().debugCameraSuggestions(
            limit: 3,
            now: FoodRecommendationTestSupport.day(2, hour: 9),
            targetDate: FoodRecommendationTestSupport.day(2, hour: 9),
            modelContext: context
        )
        XCTAssertEqual(summary.directMemoryCandidateCount, 1)
        XCTAssertGreaterThan(summary.directSuppressedAlreadyTodayCount, 0)
    }

    func testSemanticDrinkSatisfactionDoesNotHideCurrentMealOpportunity() throws {
        let context = try modelContext()
        context.insert(drinkEntry("Coffee", component: "coffee", day: 0, hour: 8))
        context.insert(drinkEntry("Coffee", component: "coffee", day: 1, hour: 8))
        context.insert(drinkMemory(title: "Coffee", component: "coffee"))
        context.insert(entry("Chicken Rice Bowl", day: 0))
        context.insert(entry("Chicken Rice Bowl", day: 1))
        context.insert(drinkEntry("Iced Latte", component: "latte", day: 2, hour: 8))
        try context.save()

        let suggestions = try FoodSuggestionService().cameraSuggestions(
            limit: 3,
            now: FoodRecommendationTestSupport.day(2, hour: 12),
            targetDate: FoodRecommendationTestSupport.day(2, hour: 12),
            modelContext: context
        )

        XCTAssertEqual(suggestions.first?.title, "Chicken Rice Bowl")
        XCTAssertFalse(suggestions.contains { $0.title == "Coffee" })

        let summary = try FoodSuggestionService().debugCameraSuggestions(
            limit: 3,
            now: FoodRecommendationTestSupport.day(2, hour: 12),
            targetDate: FoodRecommendationTestSupport.day(2, hour: 12),
            modelContext: context
        )
        XCTAssertGreaterThan(summary.directSuppressedAlreadyTodayCount, 0)
        XCTAssertEqual(summary.shownSuggestionTitles.first, "Chicken Rice Bowl")
    }

    func testPartialComponentOverlapDoesNotSuppressPersistedMealOpportunity() throws {
        let context = try modelContext()
        let first = entry("Chicken Rice Bowl", day: 0)
        let second = entry("Chicken Rice Bowl", day: 1)
        context.insert(first)
        context.insert(second)
        context.insert(memory(title: "Chicken Rice Bowl", entries: [first, second]))
        context.insert(chickenSalad(day: 2, hour: 9))
        try context.save()

        let suggestions = try FoodSuggestionService().cameraSuggestions(
            limit: 3,
            now: FoodRecommendationTestSupport.day(2, hour: 12),
            targetDate: FoodRecommendationTestSupport.day(2, hour: 12),
            modelContext: context
        )

        XCTAssertTrue(suggestions.contains { $0.title == "Chicken Rice Bowl" })

        let summary = try FoodSuggestionService().debugCameraSuggestions(
            limit: 3,
            now: FoodRecommendationTestSupport.day(2, hour: 12),
            targetDate: FoodRecommendationTestSupport.day(2, hour: 12),
            modelContext: context
        )
        XCTAssertEqual(summary.suppressedAlreadyTodayCount, 0)
        XCTAssertEqual(summary.directSuppressedAlreadyTodayCount, 0)
    }

    func testPersistedMemoryRepeatCadenceKeepsSuggestionAvailableAfterSameDayUse() throws {
        let context = try modelContext()
        context.insert(drinkEntry("Vanilla Shake", component: "shake", day: 2, hour: 8))
        context.insert(
            drinkMemory(
                title: "Protein Shake",
                component: "shake",
                hourCounts: [8: 3, 12: 3],
                bucketCounts: ["breakfast": 3, "lunch": 3],
                repeatPattern: FoodMemoryRepeatPattern(
                    distinctConsumptionDays: 3,
                    daysWithMultipleUses: 3,
                    maxUsesInDay: 2,
                    averageUsesPerDay: 2,
                    averageRepeatGapMinutes: 240,
                    repeatGapObservationCount: 3,
                    currentDayUseCount: 1,
                    currentDayAnchor: FoodRecommendationTestSupport.day(2),
                    lastConsumptionAt: FoodRecommendationTestSupport.day(2, hour: 8)
                )
            )
        )
        try context.save()

        let suggestions = try FoodSuggestionService().cameraSuggestions(
            limit: 3,
            now: FoodRecommendationTestSupport.day(2, hour: 12),
            targetDate: FoodRecommendationTestSupport.day(2, hour: 12),
            modelContext: context
        )

        XCTAssertTrue(suggestions.contains { $0.title == "Protein Shake" })
    }

    func testDirectMemoryDebugReportsEmergingSameDayRepeatDemotion() throws {
        let context = try modelContext()
        context.insert(drinkEntry("Vanilla Shake", component: "shake", day: 2, hour: 8))
        context.insert(
            drinkMemory(
                title: "Protein Shake",
                component: "shake",
                hourCounts: [8: 2, 10: 2],
                bucketCounts: ["breakfast": 4],
                repeatPattern: FoodMemoryRepeatPattern(
                    distinctConsumptionDays: 2,
                    daysWithMultipleUses: 1,
                    maxUsesInDay: 2,
                    averageUsesPerDay: 1.25,
                    averageRepeatGapMinutes: 180,
                    repeatGapObservationCount: 1,
                    currentDayUseCount: 1,
                    currentDayAnchor: FoodRecommendationTestSupport.day(2),
                    lastConsumptionAt: FoodRecommendationTestSupport.day(2, hour: 8)
                )
            )
        )
        try context.save()

        let summary = try FoodSuggestionService().debugCameraSuggestions(
            limit: 3,
            now: FoodRecommendationTestSupport.day(2, hour: 10),
            targetDate: FoodRecommendationTestSupport.day(2, hour: 10),
            modelContext: context
        )

        XCTAssertEqual(summary.directMemoryCandidateCount, 1)
        XCTAssertGreaterThan(summary.directDemotedAlreadyTodayCount, 0)
    }

    func testPassiveShownWithoutExplicitDismissalDoesNotBlacklistPersistedMemory() throws {
        let context = try modelContext()
        let memory = drinkMemory(
            title: "Protein Shake",
            component: "shake",
            hourCounts: [12: 4],
            bucketCounts: ["lunch": 4]
        )
        memory.suggestionStats = FoodMemorySuggestionStats(
            timesShown: 4,
            timesTapped: 0,
            timesAccepted: 0,
            timesDismissed: 0,
            timesRefined: 0,
            lastShownAt: FoodRecommendationTestSupport.day(1, hour: 12),
            lastTappedAt: nil,
            lastAcceptedAt: nil,
            lastDismissedAt: nil,
            lastRefinedAt: nil
        )
        context.insert(memory)
        try context.save()

        let suggestions = try FoodSuggestionService().cameraSuggestions(
            limit: 3,
            now: FoodRecommendationTestSupport.day(2, hour: 12),
            targetDate: FoodRecommendationTestSupport.day(2, hour: 12),
            modelContext: context
        )

        XCTAssertTrue(suggestions.contains { $0.title == "Protein Shake" })

        let summary = try FoodSuggestionService().debugCameraSuggestions(
            limit: 3,
            now: FoodRecommendationTestSupport.day(2, hour: 12),
            targetDate: FoodRecommendationTestSupport.day(2, hour: 12),
            modelContext: context
        )
        XCTAssertEqual(summary.directMemoryCandidateCount, 1)
        XCTAssertGreaterThan(summary.directPassiveExposureDemotedCount, 0)
    }

    func testRecentIgnoredPersistedMemoryDemotesButDecays() throws {
        let context = try modelContext()
        let ignoredMemory = drinkMemory(
            title: "Protein Shake",
            component: "shake",
            hourCounts: [12: 6],
            bucketCounts: ["lunch": 6]
        )
        ignoredMemory.suggestionStats = FoodMemorySuggestionStats(
            timesShown: 3,
            timesTapped: 0,
            timesIgnored: 3,
            timesAccepted: 0,
            timesDismissed: 0,
            timesRefined: 0,
            lastShownAt: FoodRecommendationTestSupport.day(2, hour: 12),
            lastTappedAt: nil,
            lastIgnoredAt: FoodRecommendationTestSupport.day(2, hour: 12),
            lastAcceptedAt: nil,
            lastDismissedAt: nil,
            lastRefinedAt: nil
        )
        let alternativeMemory = drinkMemory(
            title: "Zucchini Smoothie",
            component: "smoothie",
            hourCounts: [12: 6],
            bucketCounts: ["lunch": 6]
        )
        context.insert(ignoredMemory)
        context.insert(alternativeMemory)
        try context.save()

        let recentSuggestions = try FoodSuggestionService().cameraSuggestions(
            limit: 2,
            now: FoodRecommendationTestSupport.day(2, hour: 13),
            targetDate: FoodRecommendationTestSupport.day(2, hour: 13),
            modelContext: context
        )
        let recoveredSuggestions = try FoodSuggestionService().cameraSuggestions(
            limit: 2,
            now: FoodRecommendationTestSupport.day(5, hour: 13),
            targetDate: FoodRecommendationTestSupport.day(5, hour: 13),
            modelContext: context
        )

        XCTAssertEqual(recentSuggestions.map(\.title), ["Zucchini Smoothie", "Protein Shake"])
        XCTAssertEqual(recoveredSuggestions.map(\.title), ["Protein Shake", "Zucchini Smoothie"])
    }

    func testRepeatedMorningDrinkHabitCanRankFirstWhenThatIsTheUserPattern() throws {
        let context = try modelContext()
        let latte = drinkMemory(
            title: "Iced Latte",
            component: "latte",
            hourCounts: [8: 8],
            bucketCounts: ["breakfast": 8]
        )
        let lunch = memory(
            title: "Chicken Rice Bowl",
            entries: [
                entry("Chicken Rice Bowl", day: 0),
                entry("Chicken Rice Bowl", day: 1)
            ]
        )
        lunch.timeProfile = FoodMemoryTimeProfile(
            hourCounts: hourCounts([12: 2]),
            bucketCounts: ["lunch": 2],
            weekdayCount: 2,
            weekendCount: 0
        )
        context.insert(latte)
        context.insert(lunch)
        try context.save()

        let suggestions = try FoodSuggestionService().cameraSuggestions(
            limit: 3,
            now: FoodRecommendationTestSupport.day(2, hour: 8),
            targetDate: FoodRecommendationTestSupport.day(2, hour: 8),
            modelContext: context
        )

        XCTAssertEqual(suggestions.first?.title, "Iced Latte")
    }

    func testLinkedHistoricalMemoryStillSurfacesAsLearnedHabit() throws {
        let context = try modelContext()
        let latte = drinkMemory(
            title: "Iced Latte",
            component: "latte",
            hourCounts: [8: 4],
            bucketCounts: ["breakfast": 4]
        )
        let first = drinkEntry("Iced Latte", component: "latte", day: 0, hour: 8)
        let second = drinkEntry("Low-fat Iced Latte", component: "latte", day: 1, hour: 8)
        first.foodMemoryIdString = latte.id.uuidString
        second.foodMemoryIdString = latte.id.uuidString
        context.insert(first)
        context.insert(second)
        context.insert(latte)
        try context.save()

        let suggestions = try FoodSuggestionService().cameraSuggestions(
            limit: 3,
            now: FoodRecommendationTestSupport.day(2, hour: 8),
            targetDate: FoodRecommendationTestSupport.day(2, hour: 8),
            modelContext: context
        )

        XCTAssertEqual(suggestions.first?.title, "Iced Latte")
    }

    func testEmergingMultiDayMemoryCanSurfaceWithoutRawPatternHistory() throws {
        let context = try modelContext()
        let latte = drinkMemory(
            title: "Iced Latte",
            component: "latte",
            hourCounts: [8: 2],
            bucketCounts: ["breakfast": 2]
        )
        latte.status = .candidate
        latte.observationCount = 2
        latte.confidenceScore = 0.86
        latte.qualitySignals = FoodMemoryQualitySignals(
            proportionUserEdited: 0,
            proportionWithStructuredComponents: 1,
            distinctObservationDays: 2,
            repeatedTimeBucketScore: 1
        )
        context.insert(latte)
        try context.save()

        let suggestions = try FoodSuggestionService().cameraSuggestions(
            limit: 3,
            now: FoodRecommendationTestSupport.day(2, hour: 8),
            targetDate: FoodRecommendationTestSupport.day(2, hour: 8),
            modelContext: context
        )
        let summary = try FoodSuggestionService().debugCameraSuggestions(
            limit: 3,
            now: FoodRecommendationTestSupport.day(2, hour: 8),
            targetDate: FoodRecommendationTestSupport.day(2, hour: 8),
            modelContext: context
        )

        XCTAssertEqual(suggestions.first?.title, "Iced Latte")
        XCTAssertEqual(summary.totalObservations, 0)
        XCTAssertEqual(summary.directMemoryCandidateCount, 1)
    }

    func testDebugCameraSuggestionsReportsNewEngineStages() throws {
        let context = try modelContext()
        context.insert(entry("Chicken Rice Bowl", day: 0))
        context.insert(entry("Chicken Rice Bowl", day: 1))
        try context.save()

        let summary = try FoodSuggestionService().debugCameraSuggestions(
            limit: 3,
            now: FoodRecommendationTestSupport.day(2),
            targetDate: FoodRecommendationTestSupport.day(2),
            modelContext: context
        )

        XCTAssertEqual(summary.totalObservations, 2)
        XCTAssertEqual(summary.patternCount, 1)
        XCTAssertFalse(summary.candidateCountBySource.isEmpty)
        XCTAssertEqual(summary.suppressedOneOffCount, 0)
        XCTAssertEqual(summary.directMemoryCandidateCount, 0)
        XCTAssertEqual(summary.shownSuggestionTitles.first, "Chicken Rice Bowl")
    }

    private func modelContext() throws -> ModelContext {
        let schema = Schema([FoodEntry.self, FoodMemory.self, FoodSuggestionFeedback.self])
        let container = try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        )
        return ModelContext(container)
    }

    private func partialModelContext() throws -> ModelContext {
        let schema = Schema([FoodEntry.self, FoodMemory.self])
        let container = try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        )
        return ModelContext(container)
    }

    private func entry(
        _ name: String,
        day: Int,
        calories: Int = 620,
        protein: Double = 42,
        carbs: Double = 58,
        fat: Double = 16
    ) -> FoodEntry {
        FoodRecommendationTestSupport.entry(
            name: name,
            loggedAt: FoodRecommendationTestSupport.day(day),
            calories: calories,
            protein: protein,
            carbs: carbs,
            fat: fat,
            components: chickenRiceComponents()
        )
    }

    private func drinkEntry(_ name: String, component: String, day: Int, hour: Int) -> FoodEntry {
        FoodRecommendationTestSupport.entry(
            name: name,
            loggedAt: FoodRecommendationTestSupport.day(day, hour: hour),
            calories: 120,
            protein: 6,
            carbs: 14,
            fat: 4,
            components: [
                FoodRecommendationTestSupport.component(component, role: .drink, calories: 120, protein: 6, carbs: 14, fat: 4)
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

    private func chickenRiceComponents() -> [AcceptedFoodComponent] {
        [
            FoodRecommendationTestSupport.component("chicken", role: .protein, calories: 240, protein: 38, carbs: 0, fat: 5),
            FoodRecommendationTestSupport.component("rice", role: .carb, calories: 205, protein: 4, carbs: 45, fat: 0)
        ]
    }

    private func pastramiComponents() -> [AcceptedFoodComponent] {
        [
            FoodRecommendationTestSupport.component("pastrami", role: .protein, calories: 420, protein: 30, carbs: 0, fat: 30),
            FoodRecommendationTestSupport.component("rye bread", role: .carb, calories: 220, protein: 6, carbs: 40, fat: 3)
        ]
    }

    private func memory(title: String, entries: [FoodEntry]) -> FoodMemory {
        let memory = FoodMemory()
        memory.status = .confirmed
        memory.displayName = title
        memory.primaryNormalizedName = FoodNormalizationService().normalizeFoodName(title)
        memory.aliases = [
            FoodMemoryAlias(
                normalizedName: memory.primaryNormalizedName,
                displayName: title,
                observationCount: entries.count,
                wasUserEdited: false
            )
        ]
        memory.components = [
            FoodMemoryComponentSummary(
                normalizedName: "chicken",
                role: .protein,
                observationCount: entries.count,
                typicalCalories: 240,
                typicalProteinGrams: 38,
                typicalCarbsGrams: 0,
                typicalFatGrams: 5
            ),
            FoodMemoryComponentSummary(
                normalizedName: "rice",
                role: .carb,
                observationCount: entries.count,
                typicalCalories: 205,
                typicalProteinGrams: 4,
                typicalCarbsGrams: 45,
                typicalFatGrams: 0
            )
        ]
        memory.nutritionProfile = FoodMemoryNutritionProfile(
            medianCalories: 620,
            medianProteinGrams: 42,
            medianCarbsGrams: 58,
            medianFatGrams: 16,
            medianFiberGrams: 5,
            medianSugarGrams: 4,
            lowerCaloriesBound: 620,
            upperCaloriesBound: 620,
            lowerProteinBound: 42,
            upperProteinBound: 42
        )
        memory.representativeEntryIds = entries.map { $0.id.uuidString }
        memory.observationCount = entries.count
        memory.lastObservedAt = entries.map(\.loggedAt).max() ?? .now
        return memory
    }

    private func hourCounts(_ counts: [Int: Int]) -> [Int] {
        var output = Array(repeating: 0, count: 24)
        for (hour, count) in counts where output.indices.contains(hour) {
            output[hour] = count
        }
        return output
    }

    private func drinkMemory(
        title: String,
        component: String,
        hourCounts: [Int: Int] = [8: 2],
        bucketCounts: [String: Int] = ["breakfast": 2],
        repeatPattern: FoodMemoryRepeatPattern? = nil
    ) -> FoodMemory {
        let memory = FoodMemory()
        let normalizedTitle = FoodNormalizationService().normalizeFoodName(title)
        let normalizedComponent = FoodNormalizationService().normalizeComponentName(component)
        var normalizedHourCounts = Array(repeating: 0, count: 24)
        for (hour, count) in hourCounts where normalizedHourCounts.indices.contains(hour) {
            normalizedHourCounts[hour] = count
        }
        let observationCount = max(
            normalizedHourCounts.reduce(0, +),
            bucketCounts.values.reduce(0, +),
            2
        )
        memory.status = .confirmed
        memory.displayName = title
        memory.primaryNormalizedName = normalizedTitle
        memory.aliases = [
            FoodMemoryAlias(
                normalizedName: normalizedTitle,
                displayName: title,
                observationCount: observationCount,
                wasUserEdited: false
            )
        ]
        memory.components = [
            FoodMemoryComponentSummary(
                normalizedName: normalizedComponent,
                role: .drink,
                observationCount: observationCount,
                typicalCalories: 120,
                typicalProteinGrams: 6,
                typicalCarbsGrams: 14,
                typicalFatGrams: 4
            )
        ]
        memory.nutritionProfile = FoodMemoryNutritionProfile(
            medianCalories: 120,
            medianProteinGrams: 6,
            medianCarbsGrams: 14,
            medianFatGrams: 4,
            medianFiberGrams: nil,
            medianSugarGrams: nil,
            lowerCaloriesBound: 120,
            upperCaloriesBound: 120,
            lowerProteinBound: 6,
            upperProteinBound: 6
        )
        memory.servingProfile = FoodMemoryServingProfile(
            commonServingText: "1 bowl",
            commonQuantity: 1,
            commonUnit: "bowl",
            quantityVariance: 0
        )
        memory.timeProfile = FoodMemoryTimeProfile(
            hourCounts: normalizedHourCounts,
            bucketCounts: bucketCounts,
            weekdayCount: observationCount,
            weekendCount: 0
        )
        memory.observationCount = observationCount
        memory.repeatPattern = repeatPattern
        memory.lastObservedAt = FoodRecommendationTestSupport.day(1, hour: 8)
        memory.confidenceScore = 0.9
        memory.qualitySignals = FoodMemoryQualitySignals(
            proportionUserEdited: 0,
            proportionWithStructuredComponents: 1,
            distinctObservationDays: min(observationCount, 3),
            repeatedTimeBucketScore: 1
        )
        return memory
    }
}
