import XCTest
@testable import Trai

final class QOLFeatureTests: XCTestCase {
    func testRestTimerStartAddAndStop() {
        let now = Date(timeIntervalSince1970: 1_000)
        var timer = LiveWorkoutRestTimer()

        timer.start(seconds: 90, exerciseName: "Bench Press", now: now)

        XCTAssertTrue(timer.isActive)
        XCTAssertEqual(timer.exerciseName, "Bench Press")
        XCTAssertEqual(timer.remainingSeconds(at: now.addingTimeInterval(30)), 60)

        timer.add(seconds: 30)
        XCTAssertEqual(timer.remainingSeconds(at: now.addingTimeInterval(30)), 90)

        timer.stop()
        XCTAssertFalse(timer.isActive)
        XCTAssertEqual(timer.remainingSeconds(at: now), 0)
        XCTAssertNil(timer.exerciseName)
    }

    func testFoodSnapshotRestoresIdentityMetadataAndImage() {
        let entry = makeFoodEntry()
        let imageData = Data([0x89, 0x50, 0x4E, 0x47])
        entry.imageData = imageData
        let snapshot = FoodEntrySnapshot(entry: entry)

        entry.imageData = nil
        let restored = snapshot.makeRestoredEntry()

        XCTAssertEqual(restored.id, entry.id)
        XCTAssertEqual(restored.sessionId, entry.sessionId)
        XCTAssertEqual(restored.inputMethod, "camera")
        XCTAssertEqual(restored.acceptedSnapshotData, Data([1, 2, 3]))
        XCTAssertEqual(restored.loggedComponentsData, Data([4, 5, 6]))
        XCTAssertEqual(restored.foodMemoryIdString, "memory-id")
        XCTAssertEqual(restored.foodMemoryResolutionStateRaw, "resolved")
        XCTAssertEqual(restored.imageData, imageData)

        restored.imageData = nil
    }

    func testFoodReplayGetsFreshLogIdentityWithoutAliasingImage() {
        let entry = makeFoodEntry()
        entry.imageData = Data([1, 2, 3])
        let snapshot = FoodEntrySnapshot(entry: entry)
        let replayID = UUID()
        let sessionID = UUID()
        let loggedAt = Date(timeIntervalSince1970: 2_000)

        let replay = snapshot.makeReplayEntry(
            id: replayID,
            loggedAt: loggedAt,
            sessionId: sessionID,
            sessionOrder: 2
        )

        XCTAssertEqual(replay.id, replayID)
        XCTAssertEqual(replay.loggedAt, loggedAt)
        XCTAssertEqual(replay.sessionId, sessionID)
        XCTAssertEqual(replay.sessionOrder, 2)
        XCTAssertEqual(replay.input, .memorySuggestion)
        XCTAssertNil(replay.imageStorageKey)
        XCTAssertNil(replay.imageData)
        XCTAssertEqual(replay.calories, entry.calories)
        XCTAssertEqual(replay.loggedComponentsData, entry.loggedComponentsData)

        entry.imageData = nil
    }

    private func makeFoodEntry() -> FoodEntry {
        let entry = FoodEntry(
            name: "Yogurt Bowl",
            mealType: "breakfast",
            calories: 420,
            proteinGrams: 32,
            carbsGrams: 48,
            fatGrams: 11
        )
        entry.sessionId = UUID()
        entry.sessionOrder = 1
        entry.inputMethod = "camera"
        entry.fiberGrams = 7
        entry.sugarGrams = 14
        entry.servingSize = "1 bowl"
        entry.servingQuantity = 1.5
        entry.userDescription = "Extra berries"
        entry.aiAnalysis = "Balanced meal"
        entry.acceptedSnapshotData = Data([1, 2, 3])
        entry.acceptedComponentsData = Data([3, 2, 1])
        entry.originalLoggedComponentsData = Data([6, 5, 4])
        entry.loggedComponentsData = Data([4, 5, 6])
        entry.foodMemoryIdString = "memory-id"
        entry.foodMemoryMatchConfidence = 0.91
        entry.foodMemoryMatchVersion = 3
        entry.foodMemoryResolutionStateRaw = "resolved"
        entry.foodMemoryResolvedAt = Date(timeIntervalSince1970: 900)
        entry.foodMemoryNeedsResolution = false
        entry.foodMemoryWasUserEdited = true
        entry.foodMemoryResolutionExplanationData = Data([9, 9])
        entry.loggedAt = Date(timeIntervalSince1970: 1_500)
        return entry
    }
}
