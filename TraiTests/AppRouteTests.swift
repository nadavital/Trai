import XCTest
@testable import Trai

final class AppRouteTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUpWithError() throws {
        try super.setUpWithError()
        suiteName = "AppRouteTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDownWithError() throws {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        try super.tearDownWithError()
    }

    func testURLRoundTripForCanonicalRoutes() {
        let routes: [AppRoute] = [
            .logFood,
            .logWeight,
            .workout(templateName: nil),
            .workout(templateName: "Push Pull Legs"),
            .chat
        ]

        for route in routes {
            let parsed = AppRoute(urlString: route.urlString)
            XCTAssertEqual(parsed, route)
        }
    }

    func testWorkoutRouteParsesTemplateFromQuery() {
        let route = AppRoute(urlString: "trai://workout?template=Upper%20Body")
        XCTAssertEqual(route, .workout(templateName: "Upper Body"))
    }

    func testInitRejectsUnknownSchemeOrHost() {
        XCTAssertNil(AppRoute(urlString: "https://example.com/workout"))
        XCTAssertNil(AppRoute(urlString: "trai://unknown"))
        XCTAssertNil(AppRoute(urlString: "not a url"))
    }

    func testPendingRouteStoreConsumesAndClearsStoredRoute() {
        PendingAppRouteStore.setPendingRoute(.chat, defaults: defaults)

        let consumed = PendingAppRouteStore.consumePendingRoute(defaults: defaults)
        XCTAssertEqual(consumed, .chat)
        XCTAssertNil(defaults.string(forKey: SharedStorageKeys.AppRouting.pendingRoute))
        XCTAssertNil(PendingAppRouteStore.consumePendingRoute(defaults: defaults))
    }

    func testPendingRouteStorePrefersPendingRouteOverLegacyFlags() {
        defaults.set(true, forKey: SharedStorageKeys.LegacyLaunchIntents.openFoodCamera)
        PendingAppRouteStore.setPendingRoute(.logWeight, defaults: defaults)

        let consumed = PendingAppRouteStore.consumePendingRoute(defaults: defaults)
        XCTAssertEqual(consumed, .logWeight)

        // Legacy value should remain for the next consume cycle since pending route wins first.
        XCTAssertEqual(PendingAppRouteStore.consumePendingRoute(defaults: defaults), .logFood)
    }

    func testPendingRouteStoreConsumesLegacyFoodCameraFlag() {
        defaults.set(true, forKey: SharedStorageKeys.LegacyLaunchIntents.openFoodCamera)

        let consumed = PendingAppRouteStore.consumePendingRoute(defaults: defaults)
        XCTAssertEqual(consumed, .logFood)
        XCTAssertFalse(defaults.bool(forKey: SharedStorageKeys.LegacyLaunchIntents.openFoodCamera))
    }

    func testPendingRouteStoreConsumesLegacyWorkoutFlagCustomAsNilTemplate() {
        defaults.set("custom", forKey: SharedStorageKeys.LegacyLaunchIntents.startWorkout)

        let consumed = PendingAppRouteStore.consumePendingRoute(defaults: defaults)
        XCTAssertEqual(consumed, .workout(templateName: nil))
        XCTAssertNil(defaults.string(forKey: SharedStorageKeys.LegacyLaunchIntents.startWorkout))
    }

    func testPendingRouteStoreConsumesLegacyWorkoutFlagWithTemplateName() {
        defaults.set("Leg Day", forKey: SharedStorageKeys.LegacyLaunchIntents.startWorkout)

        let consumed = PendingAppRouteStore.consumePendingRoute(defaults: defaults)
        XCTAssertEqual(consumed, .workout(templateName: "Leg Day"))
    }

    func testPendingRouteStoreReturnsNilWhenNoPendingData() {
        XCTAssertNil(PendingAppRouteStore.consumePendingRoute(defaults: defaults))
    }
}

@MainActor
final class AppStartupCoordinatorTests: XCTestCase {
    func testSchedulesDeferredWorkOncePerProcess() {
        var coordinator = AppStartupCoordinator()

        XCTAssertTrue(coordinator.claimDeferredStartupWork())
        XCTAssertFalse(coordinator.claimDeferredStartupWork())

        XCTAssertTrue(coordinator.claimStartupMigration())
        XCTAssertFalse(coordinator.claimStartupMigration())
    }

    func testForegroundReopenDoesNotReplayColdLaunchWork() {
        var coordinator = AppStartupCoordinator()

        XCTAssertFalse(
            coordinator.shouldScheduleForegroundHealthKitSync(
                hasActiveWorkoutInProgress: false
            )
        )

        XCTAssertTrue(coordinator.claimDeferredStartupWork())
        coordinator.markDeferredStartupWorkCompleted()

        // Cold-launch deferral work remains one-shot even after foreground reopen.
        XCTAssertFalse(coordinator.claimDeferredStartupWork())
        XCTAssertTrue(
            coordinator.shouldScheduleForegroundHealthKitSync(
                hasActiveWorkoutInProgress: false
            )
        )
        XCTAssertFalse(
            coordinator.shouldScheduleForegroundHealthKitSync(
                hasActiveWorkoutInProgress: true
            )
        )
    }
}

final class TabActivationPolicyTests: XCTestCase {
    func testDefersHeavyRefreshUntilMinimumDwell() {
        var policy = TabActivationPolicy(minimumDwellMilliseconds: 500)
        let start = Date(timeIntervalSinceReferenceDate: 1000)
        let token = policy.activate(now: start)

        XCTAssertEqual(policy.effectiveDelayMilliseconds(requested: 120, now: start), 500)
        XCTAssertFalse(policy.shouldRunHeavyRefresh(for: token, now: start.addingTimeInterval(0.49)))
        XCTAssertTrue(policy.shouldRunHeavyRefresh(for: token, now: start.addingTimeInterval(0.5)))
    }

    func testCancelsDeferredRefreshWhenTabLosesFocus() {
        var policy = TabActivationPolicy(minimumDwellMilliseconds: 300)
        let start = Date(timeIntervalSinceReferenceDate: 2000)
        let staleToken = policy.activate(now: start)

        policy.deactivate()
        let reactivatedToken = policy.activate(now: start.addingTimeInterval(1))

        XCTAssertFalse(policy.shouldRunHeavyRefresh(for: staleToken, now: start.addingTimeInterval(2)))
        XCTAssertTrue(policy.shouldRunHeavyRefresh(for: reactivatedToken, now: start.addingTimeInterval(1.4)))
    }
}

final class TabPrewarmPolicyTests: XCTestCase {
    func testPrewarmOrderPrioritizesLikelyNextTabsFromDashboard() {
        let policy = TabPrewarmPolicy(initialDelayMilliseconds: 900, interTabDelayMilliseconds: 700)
        let order = policy.preloadOrder(for: .dashboard, loadedTabs: [.dashboard])

        XCTAssertEqual(order, [.workouts, .trai, .profile])
    }

    func testPrewarmOrderSkipsAlreadyLoadedTabsAndClampsDelays() {
        let policy = TabPrewarmPolicy(initialDelayMilliseconds: -100, interTabDelayMilliseconds: -20)
        let order = policy.preloadOrder(for: .profile, loadedTabs: [.profile, .dashboard, .workouts])

        XCTAssertEqual(policy.initialDelayMilliseconds, 0)
        XCTAssertEqual(policy.interTabDelayMilliseconds, 0)
        XCTAssertEqual(order, [.trai])
    }
}

final class ChatActivationWorkTests: XCTestCase {
    func testFullActivationRunsOnFirstAppearThenRespectsCooldown() {
        var policy = ChatActivationWorkPolicy(
            fullActivationCooldownSeconds: 45,
            recommendationCooldownSeconds: 90
        )
        let start = Date(timeIntervalSinceReferenceDate: 10_000)

        XCTAssertTrue(
            policy.shouldRunFullActivation(
                hasPendingStartupActions: false,
                now: start
            )
        )
        policy.markFullActivationRun(at: start)

        XCTAssertFalse(
            policy.shouldRunFullActivation(
                hasPendingStartupActions: false,
                now: start.addingTimeInterval(20)
            )
        )
        XCTAssertTrue(
            policy.shouldRunFullActivation(
                hasPendingStartupActions: false,
                now: start.addingTimeInterval(46)
            )
        )
    }

    func testRecommendationCheckDeduplicatesWithinCooldown() {
        var policy = ChatActivationWorkPolicy(
            fullActivationCooldownSeconds: 45,
            recommendationCooldownSeconds: 90
        )
        let start = Date(timeIntervalSinceReferenceDate: 20_000)

        XCTAssertTrue(policy.shouldRunRecommendationCheck(now: start))
        policy.markRecommendationCheckRun(at: start)

        XCTAssertFalse(policy.shouldRunRecommendationCheck(now: start.addingTimeInterval(30)))
        XCTAssertTrue(policy.shouldRunRecommendationCheck(now: start.addingTimeInterval(95)))
    }
}
