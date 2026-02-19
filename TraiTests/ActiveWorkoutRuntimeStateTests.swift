import XCTest
@testable import Trai

final class ActiveWorkoutRuntimeStateTests: XCTestCase {
    func testMarksActiveWhileLiveWorkoutSheetPresented() {
        var tracker = ActiveWorkoutPresentationTracker()

        XCTAssertFalse(tracker.isLiveWorkoutPresented)

        tracker.begin(now: Date(timeIntervalSince1970: 1_736_000_000))

        XCTAssertTrue(tracker.isLiveWorkoutPresented)
        XCTAssertNotNil(tracker.lastActivatedAt)

        tracker.end()

        XCTAssertFalse(tracker.isLiveWorkoutPresented)
        XCTAssertNil(tracker.lastActivatedAt)
    }

    func testDashboardRefreshPolicySkipsRecoveryWhenWorkoutActive() {
        XCTAssertFalse(DashboardRefreshPolicy.shouldRefreshRecovery(isWorkoutRuntimeActive: true))
        XCTAssertTrue(DashboardRefreshPolicy.shouldRefreshRecovery(isWorkoutRuntimeActive: false))
    }
}
