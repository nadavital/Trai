import XCTest
@testable import Trai

final class LiveWorkoutUpdatePolicyTests: XCTestCase {
    func testLiveActivityIntentPollingBacksOffWhenAppForegrounded() {
        let policy = LiveWorkoutUpdatePolicy(
            foregroundIntentPollInterval: 2.0,
            interactionBoostIntentPollInterval: 0.75,
            backgroundIntentPollInterval: 0.5,
            interactionBoostWindow: 8.0
        )

        let now = Date(timeIntervalSince1970: 1_736_000_000)
        let staleInteraction = now.addingTimeInterval(-30)
        let recentInteraction = now.addingTimeInterval(-2)

        let foregroundInterval = policy.intentPollingInterval(
            appState: .active,
            lastInteractionAt: staleInteraction,
            now: now
        )
        let boostedForegroundInterval = policy.intentPollingInterval(
            appState: .active,
            lastInteractionAt: recentInteraction,
            now: now
        )
        let backgroundInterval = policy.intentPollingInterval(
            appState: .background,
            lastInteractionAt: nil,
            now: now
        )

        XCTAssertEqual(foregroundInterval, 2.0, accuracy: 0.001)
        XCTAssertEqual(boostedForegroundInterval, 0.75, accuracy: 0.001)
        XCTAssertEqual(backgroundInterval, 0.5, accuracy: 0.001)
        XCTAssertGreaterThan(foregroundInterval, backgroundInterval)
    }

    func testWatchDataPublishSkipsUnchangedPayloads() {
        let policy = LiveWorkoutUpdatePolicy()
        let heartbeat = Date(timeIntervalSince1970: 1_736_000_100)

        let initial = LiveWorkoutUpdatePolicy.WatchPayload(
            roundedHeartRate: 145,
            heartRateUpdatedAt: heartbeat,
            roundedCalories: 133,
            caloriesUpdatedAt: heartbeat
        )

        XCTAssertTrue(policy.shouldPublishWatchPayload(previous: nil, next: initial))
        XCTAssertFalse(policy.shouldPublishWatchPayload(previous: initial, next: initial))

        let changed = LiveWorkoutUpdatePolicy.WatchPayload(
            roundedHeartRate: 146,
            heartRateUpdatedAt: heartbeat.addingTimeInterval(2),
            roundedCalories: 135,
            caloriesUpdatedAt: heartbeat.addingTimeInterval(2)
        )

        XCTAssertTrue(policy.shouldPublishWatchPayload(previous: initial, next: changed))
    }
}
