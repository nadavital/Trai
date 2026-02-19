import XCTest
@testable import Trai

@MainActor
final class LiveWorkoutPersistenceCoordinatorTests: XCTestCase {
    func testCoalescesRapidEditBurstsIntoSingleSaveWindow() async {
        var saveCount = 0
        let coordinator = LiveWorkoutPersistenceCoordinator(
            configuration: .init(coalescingDelay: .milliseconds(120), maxUnsavedInterval: .seconds(2)),
            saveHandler: {
                saveCount += 1
            }
        )

        coordinator.requestSave()
        coordinator.requestSave()
        coordinator.requestSave()

        try? await Task.sleep(for: .milliseconds(60))
        XCTAssertEqual(saveCount, 0)

        try? await Task.sleep(for: .milliseconds(120))
        XCTAssertEqual(saveCount, 1)
    }

    func testCriticalEventsForceImmediateFlush() {
        var saveCount = 0
        let coordinator = LiveWorkoutPersistenceCoordinator(
            configuration: .init(coalescingDelay: .seconds(5), maxUnsavedInterval: .seconds(10)),
            saveHandler: {
                saveCount += 1
            }
        )

        coordinator.requestSave()
        coordinator.flushNow(trigger: .finishWorkout)
        XCTAssertEqual(saveCount, 1)

        coordinator.requestSave()
        coordinator.flushNow(trigger: .appBackground)
        XCTAssertEqual(saveCount, 2)

        coordinator.requestSave()
        coordinator.flushNow(trigger: .stopWorkout)
        XCTAssertEqual(saveCount, 3)
    }
}
