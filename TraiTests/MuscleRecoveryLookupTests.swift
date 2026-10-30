import XCTest
import SwiftData
@testable import Trai

@MainActor
final class MuscleRecoveryLookupTests: XCTestCase {
    private func exercise(_ name: String, group: String?, age: TimeInterval = 0, id: UUID = UUID()) -> Exercise {
        let value = Exercise(name: name, category: "strength", muscleGroup: group)
        value.id = id
        value.createdAt = Date(timeIntervalSince1970: age)
        return value
    }

    func testDuplicateAndCaseVariantNamesDoNotTrapOrDeleteRecords() {
        let originals = [exercise("Pull-ups", group: "back"), exercise("Pull-ups", group: "back"), exercise("PULL-UPS", group: "back")]
        let ids = originals.map(\.id)
        let lookup = MuscleRecoveryService.makeExerciseLookup(originals)
        XCTAssertEqual(lookup.byName, ["pull-ups": "back"])
        XCTAssertEqual(lookup.byId.count, 3)
        XCTAssertEqual(originals.map(\.id), ids)
        XCTAssertEqual(originals.map(\.name), ["Pull-ups", "Pull-ups", "PULL-UPS"])
    }

    func testDuplicateIDsUseOldestClassificationIndependentOfFetchOrder() {
        let id = UUID()
        let older = exercise("Row", group: "back", age: 1, id: id)
        let newer = exercise("Row", group: "shoulders", age: 2, id: id)
        for rows in [[newer, older], [older, newer]] {
            let lookup = MuscleRecoveryService.makeExerciseLookup(rows)
            XCTAssertEqual(lookup.byId[id], "back")
            XCTAssertEqual(lookup.byName["row"], "back")
        }
        XCTAssertEqual(newer.muscleGroup, "shoulders")
        XCTAssertEqual(older.muscleGroup, "back")
    }

    func testSameNameDifferentIDsUsesOldestWhileRetainingIDClassifications() {
        let older = exercise("Press", group: "chest", age: 1)
        let newer = exercise("PRESS", group: "shoulders", age: 2)
        let lookup = MuscleRecoveryService.makeExerciseLookup([newer, older])
        XCTAssertEqual(lookup.byName["press"], "chest")
        XCTAssertEqual(lookup.byId[newer.id], "shoulders")
        XCTAssertEqual(lookup.byId[older.id], "chest")
    }

    func testNilClassificationDoesNotShadowUsableDuplicate() {
        let id = UUID()
        let unknown = exercise("Row", group: nil, age: 0, id: id)
        let known = exercise("ROW", group: "back", age: 1, id: id)
        let lookup = MuscleRecoveryService.makeExerciseLookup([unknown, known])
        XCTAssertEqual(lookup.byId[id], "back")
        XCTAssertEqual(lookup.byName["row"], "back")
        XCTAssertNil(unknown.muscleGroup)
    }

    func testIdenticalDateAndIDHaveStableConflictTieBreaker() {
        let id = UUID()
        let a = exercise("Row", group: "back", id: id)
        let b = exercise("Row", group: "shoulders", id: id)
        XCTAssertEqual(MuscleRecoveryService.makeExerciseLookup([a,b]).byId, MuscleRecoveryService.makeExerciseLookup([b,a]).byId)
        XCTAssertEqual(MuscleRecoveryService.makeExerciseLookup([b,a]).byId[id], "back")
    }

    func testEmptyLookup() {
        let lookup = MuscleRecoveryService.makeExerciseLookup([])
        XCTAssertTrue(lookup.byId.isEmpty)
        XCTAssertTrue(lookup.byName.isEmpty)
    }

    func testWidgetRecoveryHandlesDuplicateNamesAndPreservesStoredRecords() throws {
        let rows = [exercise("Pull-ups", group: "back", age: 1),
                    exercise("Pull-ups", group: "shoulders", age: 2),
                    exercise("PULL-UPS", group: "chest", age: 3)]
        try assertWidgetRecovery(rows: rows, historyID: nil, name: "pull-ups", expected: .back)
    }

    func testWidgetRecoveryHandlesDuplicateIDsWithOldestConflictPolicy() throws {
        let id = UUID()
        let rows = [exercise("Row", group: "shoulders", age: 2, id: id),
                    exercise("ROW", group: "back", age: 1, id: id)]
        try assertWidgetRecovery(rows: rows, historyID: id, name: "Row", expected: .back)
    }

    func testWidgetRecoveryPrefersSpecificIDOverConflictingName() throws {
        let older = exercise("Press", group: "chest", age: 1)
        let newer = exercise("PRESS", group: "shoulders", age: 2)
        try assertWidgetRecovery(rows: [newer, older], historyID: newer.id, name: "Press", expected: .shoulders)
    }

    private func assertWidgetRecovery(rows: [Exercise], historyID: UUID?, name: String,
                                      expected: LiveWorkout.MuscleGroup) throws {
        let container = try ModelContainer(
            for: Exercise.self, ExerciseHistory.self, LiveWorkout.self, LiveWorkoutEntry.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        for row in rows { context.insert(row) }
        let history = ExerciseHistory()
        history.exerciseId = historyID
        history.exerciseName = name
        history.performedAt = Date().addingTimeInterval(-3600)
        context.insert(history)
        try context.save()
        let before = rows.map { "\($0.id)|\($0.name)|\($0.muscleGroup ?? "nil")" }.sorted()

        let dates = WidgetDataSnapshotBuilder().lastTrainedDates(modelContext: context)

        XCTAssertEqual(dates, [expected: history.performedAt])
        let stored = try context.fetch(FetchDescriptor<Exercise>())
        XCTAssertEqual(stored.count, rows.count)
        XCTAssertEqual(stored.map { "\($0.id)|\($0.name)|\($0.muscleGroup ?? "nil")" }.sorted(), before)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<ExerciseHistory>()), 1)
    }

}
