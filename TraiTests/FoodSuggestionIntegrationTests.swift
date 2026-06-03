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

    func testCameraSuggestionsPreserveExistingOutcomeRecording() throws {
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

        XCTAssertNoThrow(
            try FoodSuggestionService().recordOutcome(.accepted, for: suggestion.memoryID, modelContext: context)
        )
        let memories = try context.fetch(FetchDescriptor<FoodMemory>())
        let memory = try XCTUnwrap(memories.first { $0.id == suggestion.memoryID })
        XCTAssertGreaterThan(memory.suggestionStats?.timesShown ?? 0, 0)
        XCTAssertEqual(memory.suggestionStats?.timesAccepted, 1)
    }

    func testObservationBuiltSuggestionRecordsShownOnPersistedMemory() throws {
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
        let memories = try context.fetch(FetchDescriptor<FoodMemory>())
        let memory = try XCTUnwrap(memories.first { $0.id == suggestion.memoryID })

        XCTAssertGreaterThan(memory.suggestionStats?.timesShown ?? 0, 0)
        XCTAssertTrue(memory.representativeEntryIds.isEmpty == false)
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
        let schema = Schema([FoodEntry.self, FoodMemory.self])
        let container = try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        )
        return ModelContext(container)
    }

    private func entry(_ name: String, day: Int) -> FoodEntry {
        FoodRecommendationTestSupport.entry(
            name: name,
            loggedAt: FoodRecommendationTestSupport.day(day),
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
        return memory
    }
}
