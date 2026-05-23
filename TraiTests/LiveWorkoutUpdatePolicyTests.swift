import XCTest
@testable import Trai

@MainActor
final class LiveWorkoutUpdatePolicyTests: XCTestCase {
    func testLiveActivityStateUsesDisplayProgressForMixedWorkouts() {
        let state = TraiWorkoutAttributes.ContentState(
            elapsedSeconds: 120,
            completedSets: 4,
            totalSets: 12,
            heartRate: nil,
            isPaused: false,
            progressCompleted: 2,
            progressTotal: 3,
            progressLabel: "done",
            supportsSetShortcut: false
        )

        XCTAssertEqual(state.progressCompletedValue, 2)
        XCTAssertEqual(state.progressTotalValue, 3)
        XCTAssertEqual(state.progressCountDisplay, "2/3")
        XCTAssertEqual(state.progressDisplay, "2/3 done")
        XCTAssertEqual(state.setsDisplay, "2/3 done")
        XCTAssertEqual(state.progress, 2.0 / 3.0, accuracy: 0.001)
        XCTAssertFalse(state.canUseSetShortcut)
    }

    func testLiveActivityStateDecodesLegacySetOnlyPayloads() throws {
        let json = """
        {
          "elapsedSeconds": 90,
          "currentExercise": "Bench Press",
          "currentEquipment": null,
          "completedSets": 2,
          "totalSets": 5,
          "heartRate": null,
          "isPaused": false,
          "currentWeightKg": null,
          "currentWeightLbs": null,
          "currentReps": null,
          "totalVolumeKg": null,
          "totalVolumeLbs": null,
          "nextExercise": null,
          "usesMetricWeight": true
        }
        """
        let data = try XCTUnwrap(json.data(using: .utf8))

        let state = try JSONDecoder().decode(TraiWorkoutAttributes.ContentState.self, from: data)

        XCTAssertEqual(state.progressCompletedValue, 2)
        XCTAssertEqual(state.progressTotalValue, 5)
        XCTAssertEqual(state.progressDisplay, "2/5 sets")
        XCTAssertTrue(state.canUseSetShortcut)
    }

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
