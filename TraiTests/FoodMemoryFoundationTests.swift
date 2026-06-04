import XCTest
@testable import Trai

final class FoodMemoryFoundationTests: XCTestCase {
    func testSuggestedFoodEntryDecodesLegacyPayloadWithoutStructuredFields() throws {
        let legacyPayload = """
        {
          "id": "meal-1",
          "name": "Greek Yogurt",
          "calories": 180,
          "proteinGrams": 17,
          "carbsGrams": 9,
          "fatGrams": 5,
          "servingSize": "1 cup",
          "emoji": "🥣"
        }
        """

        let entry = try JSONDecoder().decode(SuggestedFoodEntry.self, from: Data(legacyPayload.utf8))

        XCTAssertEqual(entry.id, "meal-1")
        XCTAssertEqual(entry.name, "Greek Yogurt")
        XCTAssertEqual(entry.components, [])
        XCTAssertEqual(entry.schemaVersion, 1)
        XCTAssertNil(entry.mealKind)
    }

    func testSnapshotBuilderPreservesStructuredComponentsForSuggestions() {
        let suggestion = SuggestedFoodEntry(
            name: "Chicken Rice Bowl",
            calories: 620,
            proteinGrams: 42,
            carbsGrams: 58,
            fatGrams: 16,
            fiberGrams: 5,
            sugarGrams: 4,
            servingSize: "1 bowl",
            emoji: "🍚",
            components: [
                SuggestedFoodComponent(
                    id: "protein",
                    displayName: "Grilled Chicken",
                    role: "protein",
                    quantity: 5,
                    unit: "oz",
                    calories: 240,
                    proteinGrams: 38,
                    carbsGrams: 0,
                    fatGrams: 5,
                    confidence: "high"
                ),
                SuggestedFoodComponent(
                    id: "carb",
                    displayName: "White Rice",
                    role: "carb",
                    quantity: 1,
                    unit: "cup",
                    calories: 205,
                    proteinGrams: 4,
                    carbsGrams: 45,
                    fatGrams: 0,
                    fiberGrams: 1,
                    confidence: "high"
                )
            ],
            mealKind: "meal",
            notes: "Chicken, rice, and vegetables with light sauce.",
            confidence: "high",
            schemaVersion: 2
        )

        let snapshot = FoodSnapshotBuilder().buildAcceptedSnapshot(
            from: suggestion,
            source: .camera,
            loggedAt: Date(timeIntervalSince1970: 1_714_000_000),
            userEditedFields: ["refinement"]
        )

        XCTAssertEqual(snapshot.kind, .meal)
        XCTAssertEqual(snapshot.components.count, 2)
        XCTAssertEqual(snapshot.components.first?.normalizedName, "grilled chicken")
        XCTAssertEqual(snapshot.nameAliases.first, "chicken rice bowl")
        XCTAssertTrue(snapshot.nameAliases.contains("bowl chicken rice"))
        XCTAssertTrue(snapshot.wasUserEdited)
        XCTAssertEqual(snapshot.userEditedFields, ["refinement"])
        XCTAssertEqual(snapshot.servingQuantity, 1)
        XCTAssertEqual(snapshot.servingUnit, "bowl")
    }

    func testSnapshotBuilderFallsBackToDerivedComponentForFlatEntries() {
        let entry = FoodEntry(
            name: "Protein Shake",
            mealType: FoodEntry.MealType.snack.rawValue,
            calories: 230,
            proteinGrams: 30,
            carbsGrams: 12,
            fatGrams: 5
        )
        entry.servingSize = "1 bottle"
        entry.loggedAt = Date(timeIntervalSince1970: 1_714_010_000)

        let snapshot = FoodSnapshotBuilder().buildAcceptedSnapshot(
            from: entry,
            source: .manual,
            userEditedFields: ["manualEntry"]
        )

        XCTAssertEqual(snapshot.kind, .food)
        XCTAssertEqual(snapshot.components.count, 1)
        XCTAssertEqual(snapshot.components[0].source, .derived)
        XCTAssertEqual(snapshot.components[0].normalizedName, "protein shake")
        XCTAssertEqual(snapshot.mealLabel, FoodEntry.MealType.snack.rawValue)
        XCTAssertEqual(snapshot.servingQuantity, 1)
        XCTAssertEqual(snapshot.servingUnit, "bottle")
    }

    func testFoodEntryRefreshAcceptedSnapshotAfterUserEditQueuesResolutionAndUsesCurrentTotals() throws {
        let entry = FoodRecommendationTestSupport.entry(
            name: "Chicken Rice Bowl",
            loggedAt: Date(timeIntervalSince1970: 1_714_010_000),
            components: [
                FoodRecommendationTestSupport.component("chicken", role: .protein, calories: 240, protein: 38, carbs: 0, fat: 5),
                FoodRecommendationTestSupport.component("rice", role: .carb, calories: 205, protein: 4, carbs: 45, fat: 0)
            ]
        )
        entry.foodMemoryIdString = UUID().uuidString
        entry.foodMemoryMatchConfidence = 0.94
        entry.foodMemoryResolutionState = .matched

        entry.name = "Turkey Sandwich"
        entry.calories = 430
        entry.proteinGrams = 28
        entry.carbsGrams = 38
        entry.fatGrams = 18
        entry.servingSize = "1 sandwich"
        entry.refreshAcceptedSnapshotAfterUserEdit(
            editedFields: ["name", "calories", "protein", "carbs", "fat", "serving"],
            source: .manual
        )

        let snapshot = try XCTUnwrap(entry.acceptedSnapshot)
        XCTAssertEqual(snapshot.displayName, "Turkey Sandwich")
        XCTAssertEqual(snapshot.totalCalories, 430)
        XCTAssertEqual(snapshot.components.count, 1)
        XCTAssertEqual(snapshot.components[0].source, .derived)
        XCTAssertEqual(snapshot.components[0].normalizedName, "turkey sandwich")
        XCTAssertEqual(snapshot.components[0].calories, 430)
        XCTAssertTrue(snapshot.wasUserEdited)
        XCTAssertEqual(entry.foodMemoryResolutionState, .queued)
        XCTAssertTrue(entry.foodMemoryNeedsResolution)
        XCTAssertNil(entry.foodMemoryIdString)
        XCTAssertEqual(entry.foodMemoryMatchConfidence, 0)
    }

    func testSnapshotBuilderDecodesLegacySnapshotWithoutAliases() throws {
        let legacySnapshot = """
        {
          "version": 1,
          "source": "manual",
          "kind": "food",
          "displayName": "Greek Yogurt",
          "normalizedDisplayName": "greek yogurt",
          "mealLabel": "breakfast",
          "servingText": "1 cup",
          "servingQuantity": 1,
          "servingUnit": "cup",
          "totalCalories": 180,
          "totalProteinGrams": 17,
          "totalCarbsGrams": 9,
          "totalFatGrams": 5,
          "components": [],
          "loggedAt": 1714000000,
          "mealTimeBucket": "breakfast",
          "weekdayBucket": 2,
          "userEditedFields": [],
          "wasUserEdited": false
        }
        """

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let snapshot = try decoder.decode(AcceptedFoodSnapshot.self, from: Data(legacySnapshot.utf8))

        XCTAssertEqual(snapshot.nameAliases, ["greek yogurt"])
    }

    func testNormalizationServiceBuildsServingAndAliasSignals() {
        let normalizationService = FoodNormalizationService()
        let aliases = normalizationService.aliasCandidates(for: "Grilled Chicken Bowl with Rice")
        let serving = normalizationService.normalizeServing(quantity: nil, unit: nil, text: "1/2 cups")

        XCTAssertTrue(aliases.contains("grilled chicken bowl rice"))
        XCTAssertTrue(aliases.contains("chicken bowl rice"))
        XCTAssertTrue(aliases.contains("bowl chicken rice"))
        XCTAssertEqual(serving.quantity ?? 0, 0.5, accuracy: 0.001)
        XCTAssertEqual(serving.unit, "cup")
    }

    func testNormalizationServiceCanonicalizesCoffeeDrinkMilkComponents() {
        let normalizationService = FoodNormalizationService()

        XCTAssertEqual(normalizationService.normalizeComponentName("Iced Latte Milk"), "iced latte")
        XCTAssertEqual(normalizationService.normalizeComponentName("Milk"), "milk")
    }
}
