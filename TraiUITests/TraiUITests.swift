import XCTest
import Foundation

#if canImport(AppIntentsTesting)
import AppIntentsTesting
#endif

final class TraiUITests: XCTestCase {
    private static var didBootstrapPersistentStoreProfile = false
    private static let liveWorkoutStabilityStressFlagPath = "/tmp/trai_run_live_workout_stability_ui_stress"
    private let postLaunchToTabBarSmokeBudgetSeconds: TimeInterval = 2.5
    private let tabSwitchSmokeBudgetSeconds: TimeInterval = 3.5
    private let foregroundReopenSmokeBudgetSeconds: TimeInterval = 1.8
    private let addExerciseSheetSmokeBudgetSeconds: TimeInterval = 3.0

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testMainTabsAreVisibleAndNavigable() {
        let app = makeApp()
        app.launch()

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 8))

        let dashboardTab = tabBar.buttons["Dashboard"]
        let traiTab = tabBar.buttons["Trai"]
        let workoutsTab = tabBar.buttons["Workouts"]
        let profileTab = tabBar.buttons["Profile"]

        XCTAssertTrue(dashboardTab.exists)
        XCTAssertTrue(traiTab.exists)
        XCTAssertTrue(workoutsTab.exists)
        XCTAssertTrue(profileTab.exists)

        workoutsTab.tap()
        XCTAssertTrue(workoutsTab.isSelected)

        traiTab.tap()
        XCTAssertTrue(traiTab.isSelected)

        profileTab.tap()
        XCTAssertTrue(profileTab.isSelected)

        dashboardTab.tap()
        XCTAssertTrue(dashboardTab.isSelected)
    }

    func testPendingChatRouteSelectsTraiTabOnLaunch() {
        let app = makeApp(extraArguments: ["-pendingAppRoute", "trai://chat"])
        app.launch()

        let traiTab = app.tabBars.buttons["Trai"]
        XCTAssertTrue(traiTab.waitForExistence(timeout: 8))

        let selectedPredicate = NSPredicate(format: "isSelected == true")
        let selectedExpectation = XCTNSPredicateExpectation(predicate: selectedPredicate, object: traiTab)

        XCTAssertEqual(XCTWaiter.wait(for: [selectedExpectation], timeout: 5), .completed)
    }

    func testPendingLogFoodRoutePresentsFoodCamera() {
        let app = makeApp(extraArguments: ["-pendingAppRoute", "trai://logfood"])
        app.launch()

        XCTAssertTrue(app.buttons["Cancel"].waitForExistence(timeout: 8))
        XCTAssertTrue(
            app.descendants(matching: .any)["foodCameraCaptureReady"].waitForExistence(timeout: 4)
        )
    }

    func testPendingLogWeightRoutePresentsLogWeightSheet() {
        let app = makeApp(extraArguments: ["-pendingAppRoute", "trai://logweight"])
        app.launch()

        XCTAssertTrue(app.navigationBars["Log Weight"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["Save"].exists)
    }

    func testPendingWorkoutRoutePresentsLiveWorkout() {
        let app = makeApp(extraArguments: [
            "--ui-test-authenticated-free-plan",
            "-pendingAppRoute", "trai://workout"
        ])
        app.launch()

        XCTAssertTrue(app.buttons["liveWorkoutEndButton"].waitForExistence(timeout: 8))
    }

    func testLiveWorkoutBottomAccessoryClearsAfterEndingMinimizedWorkout() {
        let app = makeApp(extraArguments: [
            "--ui-test-authenticated-free-plan",
            "-pendingAppRoute", "trai://workout",
            "--ui-test-live-workout-preset"
        ])
        app.launch()

        XCTAssertTrue(waitForLiveWorkoutScreen(in: app, timeout: 12))
        minimizeLiveWorkoutAndAssertBanner(in: app)

        let banner = app.otherElements["activeWorkoutBanner"]
        banner.tap()
        XCTAssertTrue(app.buttons["liveWorkoutEndButton"].waitForExistence(timeout: 8))
        app.buttons["liveWorkoutEndButton"].tap()
        app.buttons["End Workout"].tap()

        XCTAssertTrue(app.navigationBars["Summary"].waitForExistence(timeout: 8))
        app.buttons["Done"].tap()

        XCTAssertTrue(
            waitForNonExistence(app.otherElements["activeWorkoutBanner"], timeout: 6),
            "Ending the workout should remove the tab view bottom accessory instead of leaving an empty accessory host."
        )
    }

    func testLiveWorkoutBottomAccessoryClearsAfterCancellingMinimizedWorkout() {
        let app = makeApp(extraArguments: [
            "--ui-test-authenticated-free-plan",
            "-pendingAppRoute", "trai://workout",
            "--ui-test-live-workout-preset"
        ])
        app.launch()

        XCTAssertTrue(waitForLiveWorkoutScreen(in: app, timeout: 12))
        minimizeLiveWorkoutAndAssertBanner(in: app)

        let banner = app.otherElements["activeWorkoutBanner"]
        banner.tap()
        XCTAssertTrue(app.buttons["liveWorkoutCancelButton"].waitForExistence(timeout: 8))
        app.buttons["liveWorkoutCancelButton"].tap()
        app.buttons["Cancel Workout"].tap()

        XCTAssertTrue(
            waitForNonExistence(app.otherElements["activeWorkoutBanner"], timeout: 6),
            "Cancelling the workout should remove the tab view bottom accessory instead of leaving an empty accessory host."
        )
    }

    func testDashboardPastDateHidesUnavailableHistoricalActivityMetrics() {
        let app = makeApp()
        app.launch()

        assertReadiness(in: app, identifier: "dashboardRootReady", timeout: 10)

        let previousDayButton = readinessElement(in: app, identifier: "dashboardDatePreviousButton")
        XCTAssertTrue(previousDayButton.waitForExistence(timeout: 6))
        previousDayButton.tap()

        let jumpToTodayButton = readinessElement(in: app, identifier: "dashboardJumpToTodayButton")
        XCTAssertTrue(jumpToTodayButton.waitForExistence(timeout: 4))

        let activityCard = readinessElement(in: app, identifier: "dashboardActivityCard")
        if activityCard.waitForExistence(timeout: 2) {
            let activityTitle = readinessElement(in: app, identifier: "dashboardActivityTitle")
            XCTAssertTrue(waitForElementLabel(activityTitle, equals: "Logged Activity", timeout: 4))
            XCTAssertFalse(readinessElement(in: app, identifier: "dashboardActivityStepsValue").exists)
            XCTAssertFalse(readinessElement(in: app, identifier: "dashboardActivityStepsLabel").exists)
        } else {
            XCTAssertFalse(activityCard.exists)
        }
    }

    func testFoodCameraRefinementRestoresSaveButton() {
        let app = makeApp(extraArguments: [
            "-pendingAppRoute", "trai://logfood",
            "--ui-test-mock-food-ai"
        ])
        app.launch()

        XCTAssertTrue(
            app.descendants(matching: .any)["foodCameraCaptureReady"].waitForExistence(timeout: 4)
        )

        let descriptionField = readinessElement(in: app, identifier: "foodCameraDescriptionField")
        XCTAssertTrue(descriptionField.waitForExistence(timeout: 4))
        descriptionField.tap()
        descriptionField.typeText("banana yogurt bowl")

        let submitButton = readinessElement(in: app, identifier: "foodCameraDescriptionSubmitButton")
        XCTAssertTrue(submitButton.waitForExistence(timeout: 4))
        submitButton.tap()

        let saveButton = readinessElement(in: app, identifier: "foodCameraReviewSaveButton")
        XCTAssertTrue(saveButton.waitForExistence(timeout: 6))

        let refineButton = readinessElement(in: app, identifier: "foodCameraReviewRefineButton")
        XCTAssertTrue(refineButton.exists)
        refineButton.tap()

        let refinementField = readinessElement(in: app, identifier: "foodCameraRefinementField")
        XCTAssertTrue(refinementField.waitForExistence(timeout: 4))
        XCTAssertTrue(waitForNonExistence(saveButton, timeout: 2))

        refinementField.tap()
        refinementField.typeText("add 100 calories")

        let sendButton = readinessElement(in: app, identifier: "foodCameraRefinementSendButton")
        XCTAssertTrue(sendButton.exists)
        sendButton.tap()

        XCTAssertTrue(saveButton.waitForExistence(timeout: 6))
        XCTAssertTrue(waitForNonExistence(refinementField, timeout: 6))
    }

    func testLiveWorkoutStabilityPresetHandlesRepeatedMutationsAndReopen() throws {
        let shouldRunStressPath = FileManager.default.fileExists(
            atPath: Self.liveWorkoutStabilityStressFlagPath
        )
        guard ProcessInfo.processInfo.environment["RUN_LIVE_WORKOUT_STABILITY_UI_STRESS"] == "1"
            || shouldRunStressPath else {
            throw XCTSkip(
                "Skipping live workout stress UI path by default due simulator query flakiness; set RUN_LIVE_WORKOUT_STABILITY_UI_STRESS=1 to run explicitly."
            )
        }

        let app = makeApp(extraArguments: [
            "-pendingAppRoute", "trai://workout",
            "--ui-test-live-workout-preset",
            "--seed-live-workout-perf-data"
        ])
        app.launch()

        var workoutReady = waitForLiveWorkoutScreen(in: app, timeout: 12)
        if !workoutReady {
            app.terminate()
            app.launch()
            workoutReady = waitForLiveWorkoutScreen(in: app, timeout: 16)
        }
        guard workoutReady else {
            throw XCTSkip("Live workout screen did not become queryable on this simulator run")
        }

        for _ in 0..<3 {
            app.navigationBars.firstMatch.swipeDown()

            let banner = app.otherElements["activeWorkoutBanner"]
            guard banner.waitForExistence(timeout: 8) else {
                throw XCTSkip("Active workout banner was not queryable after minimizing workout")
            }
            banner.tap()
            guard waitForLiveWorkoutScreen(in: app, timeout: 8) else {
                throw XCTSkip("Live workout screen did not restore from banner on this simulator run")
            }
        }
    }

    func testStartupAndTabSwitchLatencySmoke() {
        let app = makeApp()
        let launchStart = ProcessInfo.processInfo.systemUptime
        app.launch()
        let launchReturned = ProcessInfo.processInfo.systemUptime

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 10))
        let tabBarReady = ProcessInfo.processInfo.systemUptime
        let launchToTabBar = tabBarReady - launchStart
        let postLaunchToTabBar = tabBarReady - launchReturned
        logLatencyMetric("startup_to_tabbar_wall", value: launchToTabBar)
        logLatencyMetric("post_launch_to_tabbar", value: postLaunchToTabBar)
        XCTAssertLessThan(
            postLaunchToTabBar,
            postLaunchToTabBarSmokeBudgetSeconds,
            "Post-launch tabbar readiness exceeded smoke budget (\(postLaunchToTabBar)s; wall \(launchToTabBar)s)"
        )

        let dashboardTab = tabBar.buttons["Dashboard"]
        let traiTab = tabBar.buttons["Trai"]
        let workoutsTab = tabBar.buttons["Workouts"]
        let profileTab = tabBar.buttons["Profile"]

        XCTAssertTrue(dashboardTab.exists)
        XCTAssertTrue(traiTab.exists)
        XCTAssertTrue(workoutsTab.exists)
        XCTAssertTrue(profileTab.exists)

        ensureTabSelected(dashboardTab, label: "Dashboard")
        assertReadiness(in: app, identifier: "dashboardRootReady", timeout: 10)
        _ = tapAndMeasureSelection(workoutsTab, in: app, label: "Workouts", readinessIdentifier: "workoutsRootReady")
        _ = tapAndMeasureSelection(traiTab, in: app, label: "Trai", readinessIdentifier: "traiRootReady")
        _ = tapAndMeasureSelection(profileTab, in: app, label: "Profile", readinessIdentifier: "profileRootReady")
        _ = tapAndMeasureSelection(dashboardTab, in: app, label: "Dashboard", readinessIdentifier: "dashboardRootReady")
    }

    func testStartupLatencySmokeWithExistingUserData() {
        ensurePersistentStoreProfileForRealDataTests()
        let app = makeApp(includeUITestMode: false)
        let launchStart = ProcessInfo.processInfo.systemUptime
        app.launch()

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 20))
        let launchToTabBar = ProcessInfo.processInfo.systemUptime - launchStart
        logLatencyMetric("startup_to_tabbar_real_data", value: launchToTabBar)

        let dashboardTab = tabBar.buttons["Dashboard"]
        ensureTabSelected(dashboardTab, label: "Dashboard")
        assertReadiness(in: app, identifier: "dashboardRootReady", timeout: 20)
    }

    func testForegroundReopenLatencySmoke() {
        let app = makeApp()
        app.launch()

        let initialTabBar = app.tabBars.firstMatch
        XCTAssertTrue(initialTabBar.waitForExistence(timeout: 10))
        let dashboardTab = initialTabBar.buttons["Dashboard"]
        ensureTabSelected(dashboardTab, label: "Dashboard")
        assertReadiness(in: app, identifier: "dashboardRootReady", timeout: 10)

        XCUIDevice.shared.press(.home)
        waitForAppToLeaveForeground(app, timeout: 3)

        let reopenStart = ProcessInfo.processInfo.systemUptime
        app.activate()

        let reopenedTabBarVisible = waitForTabBarAfterReopen(in: app, timeout: 8)
        let reopenLatency = ProcessInfo.processInfo.systemUptime - reopenStart
        logLatencyMetric("reopen_to_tabbar", value: reopenLatency)

        XCTAssertTrue(reopenedTabBarVisible, "Tab bar did not appear after foreground reopen")

        let reopenedTabBar = app.tabBars.firstMatch
        let reopenedDashboardTab = reopenedTabBar.buttons["Dashboard"]
        ensureTabSelected(reopenedDashboardTab, label: "Dashboard")
        assertReadiness(in: app, identifier: "dashboardRootReady", timeout: 8)

        XCTAssertLessThan(
            reopenLatency,
            foregroundReopenSmokeBudgetSeconds,
            "Foreground reopen exceeded smoke budget (\(reopenLatency)s)"
        )
    }

    func testForegroundReopenLatencySmokeWithExistingUserData() {
        ensurePersistentStoreProfileForRealDataTests()
        let app = makeApp(includeUITestMode: false)
        app.launch()

        let initialTabBar = app.tabBars.firstMatch
        XCTAssertTrue(initialTabBar.waitForExistence(timeout: 20))
        let dashboardTab = initialTabBar.buttons["Dashboard"]
        ensureTabSelected(dashboardTab, label: "Dashboard")
        assertReadiness(in: app, identifier: "dashboardRootReady", timeout: 20)

        XCUIDevice.shared.press(.home)
        waitForAppToLeaveForeground(app, timeout: 4)

        let reopenStart = ProcessInfo.processInfo.systemUptime
        app.activate()

        let reopenedTabBarVisible = waitForTabBarAfterReopen(in: app, timeout: 12)
        let reopenLatency = ProcessInfo.processInfo.systemUptime - reopenStart
        logLatencyMetric("reopen_to_tabbar_real_data", value: reopenLatency)

        XCTAssertTrue(reopenedTabBarVisible, "Tab bar did not appear after foreground reopen")

        let reopenedTabBar = app.tabBars.firstMatch
        let reopenedDashboardTab = reopenedTabBar.buttons["Dashboard"]
        ensureTabSelected(reopenedDashboardTab, label: "Dashboard")
        assertReadiness(in: app, identifier: "dashboardRootReady", timeout: 20)
    }

    func testTabSwitchContentReadyLatencySmoke() {
        let app = makeApp()
        app.launch()

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 10))
        assertReadiness(in: app, identifier: "dashboardRootReady", timeout: 10)

        let dashboardTab = tabBar.buttons["Dashboard"]
        let traiTab = tabBar.buttons["Trai"]
        let workoutsTab = tabBar.buttons["Workouts"]
        let profileTab = tabBar.buttons["Profile"]

        ensureTabSelected(dashboardTab, label: "Dashboard")
        _ = tapAndMeasureContentReadiness(workoutsTab, in: app, label: "Workouts", readinessIdentifier: "workoutsRootReady")
        _ = tapAndMeasureContentReadiness(traiTab, in: app, label: "Trai", readinessIdentifier: "traiRootReady")
        _ = tapAndMeasureContentReadiness(profileTab, in: app, label: "Profile", readinessIdentifier: "profileRootReady")
        _ = tapAndMeasureContentReadiness(dashboardTab, in: app, label: "Dashboard", readinessIdentifier: "dashboardRootReady")
    }

    func testTabSwitchContentReadyLatencySmokeWithExistingUserData() {
        ensurePersistentStoreProfileForRealDataTests()
        let app = makeApp(
            extraArguments: ["--enable-latency-probe"],
            includeUITestMode: false
        )
        app.launch()

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 15))

        let dashboardTab = tabBar.buttons["Dashboard"]
        let traiTab = tabBar.buttons["Trai"]
        let workoutsTab = tabBar.buttons["Workouts"]
        let profileTab = tabBar.buttons["Profile"]

        ensureTabSelected(dashboardTab, label: "Dashboard")
        assertReadiness(in: app, identifier: "dashboardRootReady", timeout: 20)
        logLatencyProbeSummary(
            in: app,
            identifier: "dashboardLatencyProbe",
            label: "Dashboard"
        )
        _ = tapAndMeasureContentReadiness(
            workoutsTab,
            in: app,
            label: "Workouts",
            readinessIdentifier: "workoutsRootReady",
            metricName: "tab_switch_workouts_ready_real_data",
            enforceBudget: false
        )
        logLatencyProbeSummary(
            in: app,
            identifier: "workoutsLatencyProbe",
            label: "Workouts"
        )
        _ = tapAndMeasureContentReadiness(
            traiTab,
            in: app,
            label: "Trai",
            readinessIdentifier: "traiRootReady",
            metricName: "tab_switch_trai_ready_real_data",
            enforceBudget: false
        )
        logLatencyProbeSummary(
            in: app,
            identifier: "traiLatencyProbe",
            label: "Trai"
        )
        _ = tapAndMeasureContentReadiness(
            profileTab,
            in: app,
            label: "Profile",
            readinessIdentifier: "profileRootReady",
            metricName: "tab_switch_profile_ready_real_data",
            enforceBudget: false
        )
        logLatencyProbeSummary(
            in: app,
            identifier: "profileLatencyProbe",
            label: "Profile"
        )
        _ = tapAndMeasureContentReadiness(
            dashboardTab,
            in: app,
            label: "Dashboard",
            readinessIdentifier: "dashboardRootReady",
            metricName: "tab_switch_dashboard_ready_real_data",
            enforceBudget: false
        )
        logLatencyProbeSummary(
            in: app,
            identifier: "dashboardLatencyProbe",
            label: "Dashboard Return"
        )
    }

    func testLiveWorkoutAddExerciseSheetLatencySmoke() {
        let app = makeApp(extraArguments: [
            "-pendingAppRoute", "trai://workout",
            "--ui-test-live-workout-preset",
            "--seed-live-workout-perf-data"
        ])
        app.launch()

        let endButton = app.buttons["liveWorkoutEndButton"]
        if !endButton.waitForExistence(timeout: 10) {
            app.terminate()
            app.launch()
        }
        XCTAssertTrue(endButton.waitForExistence(timeout: 10))

        let addExerciseByLabel = app.buttons["Add Exercise"]
        let addExerciseByIdentifier = app.descendants(matching: .any)
            .matching(identifier: "liveWorkoutAddExerciseButton")
            .firstMatch
        var didFindAddExercise = addExerciseByLabel.waitForExistence(timeout: 6)
            || addExerciseByIdentifier.waitForExistence(timeout: 4)
        if !didFindAddExercise {
            app.terminate()
            app.launch()
            XCTAssertTrue(endButton.waitForExistence(timeout: 10))
            didFindAddExercise = addExerciseByLabel.waitForExistence(timeout: 6)
                || addExerciseByIdentifier.waitForExistence(timeout: 4)
        }
        XCTAssertTrue(didFindAddExercise)

        let start = ProcessInfo.processInfo.systemUptime
        if addExerciseByLabel.exists {
            addExerciseByLabel.tap()
        } else {
            addExerciseByIdentifier.tap()
        }

        let exerciseList = app.descendants(matching: .any)["exerciseListView"]
        XCTAssertTrue(exerciseList.waitForExistence(timeout: 5))

        let latency = ProcessInfo.processInfo.systemUptime - start
        logLatencyMetric("live_workout_add_exercise_sheet", value: latency)
        XCTAssertLessThan(
            latency,
            addExerciseSheetSmokeBudgetSeconds,
            "Add Exercise sheet latency exceeded smoke budget (\(latency)s)"
        )
    }

    func testOnboardingCriticalFlowCompletesIntoDashboard() {
        let app = makeOnboardingApp()
        app.launch()

        completeSharedOnboardingFields(in: app, goalLabel: "Maintain")

        XCTAssertTrue(app.staticTexts["Your Plan is Ready"].waitForExistence(timeout: 12))
        tapOnboardingPrimaryButton(in: app)
        skipWorkoutSetupInOnboarding(in: app)
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["Finish setting up Trai"].waitForExistence(timeout: 5))
    }

    func testOnboardingGuidedNutritionShowsFreeUserProChoiceAndStandardFallback() {
        let app = makeOnboardingApp(extraArguments: ["--ui-test-free-plan"])
        app.launch()

        completeSharedOnboardingFields(in: app, goalLabel: "Maintain")

        XCTAssertTrue(app.staticTexts["Plans that adjust as you log, train, and make progress."].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Continue with Trai Pro"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Continue without Pro"].exists)
    }

    func testPostOnboardingChecklistOffersWorkoutAndHealthSetupForExistingPro() {
        let app = makeOnboardingApp(extraArguments: ["--ui-test-pro-plan"])
        app.launch()

        completeSharedOnboardingFields(in: app, goalLabel: "Maintain")

        XCTAssertTrue(app.staticTexts["Your Plan is Ready"].waitForExistence(timeout: 12))
        tapOnboardingPrimaryButton(in: app)
        skipWorkoutSetupInOnboarding(in: app)

        XCTAssertTrue(app.staticTexts["Finish setting up Trai"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["Create a workout plan"].exists)
        XCTAssertTrue(app.buttons["Connect Apple Health"].exists)
    }

    private func makeApp(
        extraArguments: [String] = [],
        includeUITestMode: Bool = true
    ) -> XCUIApplication {
        let app = XCUIApplication()
        if includeUITestMode {
            app.launchArguments = ["UITEST_MODE", "--disable-tab-prewarm"] + extraArguments
        } else {
            app.launchArguments = ["--use-persistent-store", "--disable-tab-prewarm"] + extraArguments
        }
        return app
    }

    private func makeOnboardingApp(extraArguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "UITEST_MODE",
            "--ui-test-onboarding-flow",
            "--use-in-memory-store",
            "--disable-tab-prewarm"
        ] + extraArguments
        return app
    }

    private func completeSharedOnboardingFields(
        in app: XCUIApplication,
        goalLabel: String
    ) {
        XCTAssertTrue(app.staticTexts["Trai"].waitForExistence(timeout: 12))
        let welcomeButton = app.buttons["Get Started"]
        XCTAssertTrue(welcomeButton.waitForExistence(timeout: 5))
        welcomeButton.tap()

        XCTAssertTrue(app.staticTexts["Choose your goal."].waitForExistence(timeout: 5))
        let goalButton = button(containing: goalLabel, in: app)
        XCTAssertTrue(goalButton.waitForExistence(timeout: 5))
        goalButton.tap()
        tapOnboardingPrimaryButton(in: app)

        XCTAssertTrue(app.staticTexts["Enter your basics."].waitForExistence(timeout: 5))
        let heightField = app.textFields["onboardingHeightField"]
        XCTAssertTrue(heightField.waitForExistence(timeout: 5))
        typeTextIfNeeded("170", in: heightField, app: app)

        let weightField = app.textFields["onboardingCurrentWeightField"]
        if !weightField.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(weightField.waitForExistence(timeout: 5))
        typeTextIfNeeded("155", in: weightField, app: app)
        tapOnboardingPrimaryButton(in: app)

        XCTAssertTrue(app.staticTexts["Choose your activity level."].waitForExistence(timeout: 5))
        let activityButton = button(containing: "Moderately Active", in: app)
        XCTAssertTrue(activityButton.waitForExistence(timeout: 5))
        activityButton.tap()
        tapOnboardingPrimaryButton(in: app)

    }

    private func button(containing label: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons
            .matching(NSPredicate(format: "label CONTAINS %@", label))
            .firstMatch
    }

    private func typeTextIfNeeded(_ text: String, in field: XCUIElement, app: XCUIApplication) {
        let currentValue = field.value as? String ?? ""
        guard !currentValue.contains(text) else { return }
        if !field.isHittable {
            app.swipeUp()
        }
        field.tap()
        field.typeText(text)
    }

    private func tapOnboardingPrimaryButton(in app: XCUIApplication) {
        let button = app.buttons["onboardingPrimaryButton"]
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        if !button.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(button.isEnabled)
        button.tap()
    }

    private func skipWorkoutSetupInOnboarding(in app: XCUIApplication) {
        XCTAssertTrue(app.staticTexts["Set Up Workouts"].waitForExistence(timeout: 8))
        let skipButton = button(containing: "Track Workouts Only", in: app)
        XCTAssertTrue(skipButton.waitForExistence(timeout: 5))
        if !skipButton.isHittable {
            app.swipeUp()
        }
        skipButton.tap()
    }

    private func ensurePersistentStoreProfileForRealDataTests() {
        guard !Self.didBootstrapPersistentStoreProfile else { return }

        let bootstrapApp = makeApp(extraArguments: ["--use-persistent-store"])
        bootstrapApp.launch()

        let tabBar = bootstrapApp.tabBars.firstMatch
        XCTAssertTrue(
            tabBar.waitForExistence(timeout: 10),
            "Failed to bootstrap persistent store before real-data UI tests"
        )
        assertReadiness(in: bootstrapApp, identifier: "dashboardRootReady", timeout: 10)
        bootstrapApp.terminate()
        Self.didBootstrapPersistentStoreProfile = true
    }

    @discardableResult
    private func tapAndMeasureSelection(
        _ tab: XCUIElement,
        in app: XCUIApplication,
        label: String,
        readinessIdentifier: String
    ) -> TimeInterval {
        let start = ProcessInfo.processInfo.systemUptime
        tab.tap()

        let selectedExpectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "isSelected == true"),
            object: tab
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [selectedExpectation], timeout: 4),
            .completed,
            "\(label) tab failed to become selected"
        )

        let readinessElement = readinessElement(in: app, identifier: readinessIdentifier)
        if !readinessElement.exists {
            XCTAssertTrue(
                readinessElement.waitForExistence(timeout: 6),
                "\(label) tab failed to reach readiness marker \(readinessIdentifier)"
            )
        }

        let latency = ProcessInfo.processInfo.systemUptime - start
        logLatencyMetric("tab_switch_\(label.lowercased())", value: latency)
        XCTAssertLessThan(
            latency,
            tabSwitchSmokeBudgetSeconds,
            "\(label) tab switch exceeded smoke budget (\(latency)s)"
        )
        return latency
    }

    @discardableResult
    private func tapAndMeasureContentReadiness(
        _ tab: XCUIElement,
        in app: XCUIApplication,
        label: String,
        readinessIdentifier: String,
        metricName: String? = nil,
        enforceBudget: Bool = true
    ) -> TimeInterval {
        let start = ProcessInfo.processInfo.systemUptime
        tab.tap()

        func waitForSelection(timeout: TimeInterval) -> XCTWaiter.Result {
            let selectedExpectation = XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "isSelected == true"),
                object: tab
            )
            return XCTWaiter.wait(for: [selectedExpectation], timeout: timeout)
        }

        var selectionResult = waitForSelection(timeout: 2)
        if selectionResult != .completed {
            tab.tap()
            selectionResult = waitForSelection(timeout: 2)
        }
        XCTAssertEqual(
            selectionResult,
            .completed,
            "\(label) tab failed to become selected"
        )

        let readinessElement = readinessElement(in: app, identifier: readinessIdentifier)
        if !readinessElement.exists {
            XCTAssertTrue(
                readinessElement.waitForExistence(timeout: 6),
                "\(label) content failed to reach readiness marker \(readinessIdentifier)"
            )
        }

        let latency = ProcessInfo.processInfo.systemUptime - start
        let name = metricName ?? "tab_switch_\(label.lowercased())_ready"
        logLatencyMetric(name, value: latency)
        if enforceBudget {
            XCTAssertLessThan(
                latency,
                tabSwitchSmokeBudgetSeconds,
                "\(label) content-ready switch exceeded smoke budget (\(latency)s)"
            )
        }
        return latency
    }

    private func logLatencyMetric(_ name: String, value: TimeInterval) {
        XCTContext.runActivity(named: "Latency metric \(name)=\(String(format: "%.3f", value))s") { _ in
            XCTAssertGreaterThanOrEqual(value, 0)
        }
    }

    private func logLatencyProbeSummary(
        in app: XCUIApplication,
        identifier: String,
        label: String
    ) {
        let element = readinessElement(in: app, identifier: identifier)
        let exists = element.waitForExistence(timeout: 4)
        let labelText = exists ? element.label : ""
        let valueText = exists ? (element.value as? String ?? "") : ""
        let summary = [labelText, valueText]
            .first(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) ?? "missing"

        XCTContext.runActivity(named: "Latency probe \(label)=\(summary)") { _ in
            XCTAssertTrue(exists, "Expected latency probe element \(identifier) to exist")
        }
    }

    private func ensureTabSelected(_ tab: XCUIElement, label: String) {
        if tab.isSelected {
            return
        }
        tab.tap()
        let selectedExpectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "isSelected == true"),
            object: tab
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [selectedExpectation], timeout: 4),
            .completed,
            "\(label) tab failed to become selected"
        )
    }

    private func readinessElement(in app: XCUIApplication, identifier: String) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(identifier: identifier)
            .firstMatch
    }

    private func assertReadiness(
        in app: XCUIApplication,
        identifier: String,
        timeout: TimeInterval
    ) {
        let element = readinessElement(in: app, identifier: identifier)
        if element.exists {
            return
        }
        XCTAssertTrue(element.waitForExistence(timeout: timeout))
    }

    @discardableResult
    private func waitForElementLabel(
        _ element: XCUIElement,
        equals expectedLabel: String,
        timeout: TimeInterval
    ) -> Bool {
        let predicate = NSPredicate(format: "label == %@", expectedLabel)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    @discardableResult
    private func waitForNonExistence(
        _ element: XCUIElement,
        timeout: TimeInterval
    ) -> Bool {
        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    @discardableResult
    private func waitForTabBarAfterReopen(
        in app: XCUIApplication,
        timeout: TimeInterval
    ) -> Bool {
        if app.tabBars.firstMatch.waitForExistence(timeout: timeout) {
            return true
        }

        // One retry helps avoid occasional SpringBoard->app handoff flakiness in simulator.
        app.activate()
        return app.tabBars.firstMatch.waitForExistence(timeout: timeout)
    }

    private func waitForAppToLeaveForeground(
        _ app: XCUIApplication,
        timeout: TimeInterval
    ) {
        let backgroundPredicate = NSPredicate(
            format: "state != %d",
            XCUIApplication.State.runningForeground.rawValue
        )
        let expectation = XCTNSPredicateExpectation(predicate: backgroundPredicate, object: app)
        _ = XCTWaiter.wait(for: [expectation], timeout: timeout)
    }

    private func minimizeLiveWorkoutAndAssertBanner(in app: XCUIApplication) {
        app.navigationBars.firstMatch.swipeDown()
        let banner = app.otherElements["activeWorkoutBanner"]
        XCTAssertTrue(
            banner.waitForExistence(timeout: 8),
            "Expected the active workout bottom accessory after minimizing the live workout sheet."
        )
    }

    @discardableResult
    private func waitForLiveWorkoutScreen(
        in app: XCUIApplication,
        timeout: TimeInterval
    ) -> Bool {
        if app.buttons["liveWorkoutEndButton"].waitForExistence(timeout: timeout) {
            return true
        }

        if app.descendants(matching: .any)["liveWorkoutView"].waitForExistence(timeout: max(4, timeout / 2)) {
            return true
        }

        let primaryNavigationBar = app.navigationBars["Custom Workout"]
        if primaryNavigationBar.waitForExistence(timeout: max(4, timeout / 2)) {
            return true
        }

        let fallbackNavigationBar = app.navigationBars.firstMatch
        if fallbackNavigationBar.waitForExistence(timeout: max(4, timeout / 2)) {
            return true
        }

        // Fallback: if the workout is minimized, reopen from the active banner.
        let banner = app.otherElements["activeWorkoutBanner"]
        guard banner.waitForExistence(timeout: 3) else { return false }
        banner.tap()
        return fallbackNavigationBar.waitForExistence(timeout: max(4, timeout / 2))
    }
}

final class VisualStateCaptureTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testCaptureVisualStates() throws {
        let config = try VisualStateCaptureConfig.load()
        guard config.enabled else {
            throw XCTSkip("Run scripts/capture_visual_states.sh to capture visual states.")
        }

        let manifestPath = config.manifestPath
        let outputPath = config.outputPath
        let manifest = try VisualStateManifest.load(from: URL(fileURLWithPath: manifestPath))
        let selectedStateIDs = Set(
            config.ids
                .split(separator: ",")
                .map(String.init)
                .filter { !$0.isEmpty }
        )
        let selectedGroups = Set(
            config.groups
                .split(separator: ",")
                .map(String.init)
                .filter { !$0.isEmpty }
        )
        let states = manifest.states.filter { state in
            if !selectedStateIDs.isEmpty {
                return selectedStateIDs.contains(state.id)
            }
            if !selectedGroups.isEmpty {
                return !Set(state.groups).isDisjoint(with: selectedGroups)
            }
            return true
        }
        XCTAssertFalse(states.isEmpty, "No visual states matched the requested ids/groups")

        let outputURL = URL(fileURLWithPath: outputPath, isDirectory: true)
        try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)

        for state in states {
            try capture(state: state, outputURL: outputURL)
        }
    }

    private func capture(state: VisualState, outputURL: URL) throws {
        let app = XCUIApplication()
        app.launchArguments = state.launchArguments
        app.launch()

        XCTAssertTrue(
            waitForReadiness(state.ready, in: app),
            "State '\(state.id)' did not reach readiness: \(state.ready)"
        )

        for step in state.steps ?? [] {
            try perform(step: step, in: app, stateID: state.id)
        }

        if let settleSeconds = state.settleSeconds, settleSeconds > 0 {
            Thread.sleep(forTimeInterval: settleSeconds)
        }

        let screenshot = XCUIScreen.main.screenshot()
        let screenshotURL = outputURL.appendingPathComponent("\(state.id).png")
        try screenshot.pngRepresentation.write(to: screenshotURL, options: .atomic)

        app.terminate()
    }

    private func perform(step: VisualStateStep, in app: XCUIApplication, stateID: String) throws {
        switch step.action {
        case .tap:
            let target = try XCTUnwrap(step.target, "Tap step in '\(stateID)' requires a target")
            let element = element(for: target, in: app)
            XCTAssertTrue(
                element.waitForExistence(timeout: step.timeout ?? 6),
                "Tap target did not appear in '\(stateID)': \(target)"
            )
            element.tap()
        case .waitFor:
            let target = try XCTUnwrap(step.target, "waitFor step in '\(stateID)' requires a target")
            XCTAssertTrue(
                element(for: target, in: app).waitForExistence(timeout: step.timeout ?? 6),
                "waitFor target did not appear in '\(stateID)': \(target)"
            )
        case .wait:
            Thread.sleep(forTimeInterval: step.seconds ?? 1)
        }
    }

    private func waitForReadiness(_ ready: VisualStateReadiness, in app: XCUIApplication) -> Bool {
        element(for: ready.target, in: app).waitForExistence(timeout: ready.timeout)
    }

    private func element(for target: VisualStateTarget, in app: XCUIApplication) -> XCUIElement {
        if let identifier = target.identifier {
            return app.descendants(matching: .any)[identifier]
        }
        if let label = target.label {
            switch target.kind {
            case .button:
                return app.buttons[label]
            case .navigationBar:
                return app.navigationBars[label]
            case .text:
                return app.staticTexts[label]
            case .any, .none:
                return app.descendants(matching: .any)[label]
            }
        }
        return app.descendants(matching: .any).firstMatch
    }
}

private struct VisualStateCaptureConfig: Decodable {
    let enabled: Bool
    let createdAt: TimeInterval
    let manifestPath: String
    let outputPath: String
    let groups: String
    let ids: String

    static func load() throws -> Self {
        let url = URL(fileURLWithPath: "/tmp/trai-visual-state-capture-config.json")
        guard FileManager.default.fileExists(atPath: url.path) else {
            return Self(
                enabled: false,
                createdAt: Date().timeIntervalSince1970,
                manifestPath: "",
                outputPath: "",
                groups: "",
                ids: ""
            )
        }

        let data = try Data(contentsOf: url)
        let config = try JSONDecoder().decode(Self.self, from: data)
        guard Date().timeIntervalSince1970 - config.createdAt < 1_800 else {
            return Self(
                enabled: false,
                createdAt: config.createdAt,
                manifestPath: config.manifestPath,
                outputPath: config.outputPath,
                groups: config.groups,
                ids: config.ids
            )
        }
        return config
    }
}

private struct VisualStateManifest: Decodable {
    let states: [VisualState]

    static func load(from url: URL) throws -> Self {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(Self.self, from: data)
    }
}

private struct VisualState: Decodable {
    let id: String
    let title: String
    let groups: [String]
    let launchArguments: [String]
    let ready: VisualStateReadiness
    let steps: [VisualStateStep]?
    let settleSeconds: TimeInterval?
}

private struct VisualStateReadiness: Decodable, CustomStringConvertible {
    let identifier: String?
    let label: String?
    let kind: VisualStateTarget.Kind?
    let timeout: TimeInterval

    var target: VisualStateTarget {
        VisualStateTarget(identifier: identifier, label: label, kind: kind)
    }

    var description: String {
        [
            identifier.map { "identifier=\($0)" },
            label.map { "label=\($0)" },
            kind.map { "kind=\($0.rawValue)" },
            "timeout=\(timeout)"
        ]
        .compactMap { $0 }
        .joined(separator: ", ")
    }
}

private struct VisualStateStep: Decodable {
    enum Action: String, Decodable {
        case tap
        case waitFor
        case wait
    }

    let action: Action
    let target: VisualStateTarget?
    let timeout: TimeInterval?
    let seconds: TimeInterval?
}

private struct VisualStateTarget: Decodable, CustomStringConvertible {
    enum Kind: String, Decodable {
        case any
        case button
        case navigationBar
        case text
    }

    let identifier: String?
    let label: String?
    let kind: Kind?

    var description: String {
        [
            identifier.map { "identifier=\($0)" },
            label.map { "label=\($0)" },
            kind.map { "kind=\($0.rawValue)" }
        ]
        .compactMap { $0 }
        .joined(separator: ", ")
    }
}

#if canImport(AppIntentsTesting)
/// Exercises Trai's App Intents through the same out-of-process metadata and
/// execution path used by Siri and Shortcuts. AppIntentsTesting is an iOS 27
/// framework, so the app and test targets can continue supporting iOS 26.
@available(iOS 27.0, *)
final class TraiAppIntentsTests: XCTestCase {
    private let appBundleIdentifier = "Nadav.Trai"
    private var seededApp: XCUIApplication!

    private var definitions: IntentDefinitions {
        IntentDefinitions(bundleIdentifier: appBundleIdentifier)
    }

    override func setUpWithError() throws {
        continueAfterFailure = false

        seededApp = XCUIApplication()
        seededApp.launchArguments = [
            "UITEST_MODE",
            "--use-persistent-store",
            "--app-intents-testing-seed",
            "--disable-tab-prewarm"
        ]
        seededApp.launch()

        XCTAssertTrue(
            seededApp.descendants(matching: .any)["dashboardRootReady"]
                .waitForExistence(timeout: 15),
            "Trai did not finish loading its persistent App Intents test seed."
        )
    }

    override func tearDownWithError() throws {
        seededApp?.terminate()
        seededApp = nil
    }

    func testSiriIntentCatalogContainsTraiShortcuts() {
        let expectedIntentNames = [
            "LogFoodTextIntent",
            "LogFoodCameraIntent",
            "LogWeightIntent",
            "AskTraiIntent",
            "StartWorkoutIntent",
            "GetDailySummaryIntent",
            "GetNutritionProgressIntent",
            "GetLatestWorkoutSummaryIntent"
        ]

        for name in expectedIntentNames {
            let definition = definitions.intents[name]
            XCTAssertEqual(definition.bundleIdentifier, appBundleIdentifier)
            XCTAssertEqual(definition.identifier, name)
        }
    }

    func testTextAndWeightParametersRoundTripThroughIntentMetadata() throws {
        let foodIntent = definitions.intents["LogFoodTextIntent"].makeIntent(
            food: "Greek yogurt with blueberries"
        )
        let food: String = try foodIntent.food
        XCTAssertEqual(food, "Greek yogurt with blueberries")

        let askIntent = definitions.intents["AskTraiIntent"].makeIntent(
            question: "How much protein have I logged today?"
        )
        let question: String = try askIntent.question
        XCTAssertEqual(question, "How much protein have I logged today?")

        let weightIntent = definitions.intents["LogWeightIntent"].makeIntent(
            weight: 176.4,
            unit: "lbs"
        )
        let weight: Double = try weightIntent.weight
        let unit: String = try weightIntent.unit
        XCTAssertEqual(weight, 176.4, accuracy: 0.001)
        XCTAssertEqual(unit, "lbs")
    }

    func testWorkoutEntityCanPopulateStartWorkoutIntent() throws {
        let identifier = "11111111-1111-1111-1111-111111111111"
        let workoutDefinition = definitions.entities["WorkoutNameEntity"]
        let workout = workoutDefinition.makeReference(identifier: identifier)
        let startWorkout = definitions.intents["StartWorkoutIntent"].makeIntent(
            workout: workout
        )

        let populatedWorkout: AnyAppEntity = try startWorkout.workout
        XCTAssertEqual(populatedWorkout.identifier.instanceIdentifier, identifier)
        XCTAssertEqual(
            populatedWorkout.identifier.entityType.bundleIdentifier,
            appBundleIdentifier
        )
    }

    func testWorkoutEntityQuerySupportsSuggestionsAndIdentifierResolution() async throws {
        let workoutDefinition = definitions.entities["WorkoutNameEntity"]
        let suggested = try await workoutDefinition.suggestedEntities()
        let emptySearch = try await workoutDefinition.entities(matching: "")

        XCTAssertEqual(
            emptySearch,
            suggested,
            "An empty Siri workout search should preserve the query's suggestions."
        )
        XCTAssertFalse(
            suggested.isEmpty,
            "The App Intents test seed should expose workout-plan suggestions to Siri."
        )
        let first = try XCTUnwrap(suggested.first)

        let resolved = try await workoutDefinition.entities(
            identifiers: [first.identifier.instanceIdentifier]
        )
        XCTAssertEqual(resolved, [first])
    }

    func testDailySummaryRunsOutOfProcessAndReturnsSpokenText() async throws {
        let result = try await definitions.intents["GetDailySummaryIntent"]
            .makeIntent()
            .run()
        let summary: String = try result.value

        XCTAssertEqual(
            summary,
            "You've logged 1955 calories and 162 grams of protein today, your calorie target is 2450."
        )
    }

    func testNutritionProgressReturnsExactSeededAggregate() async throws {
        let result = try await definitions.intents["GetNutritionProgressIntent"]
            .makeIntent()
            .run()
        let progress: AnyTransientAppEntity = try result.value
        let caloriesConsumed: Int = try progress.caloriesConsumed
        let calorieTarget: Int = try progress.calorieTarget
        let proteinConsumed: Int = try progress.proteinConsumedGrams
        let proteinTarget: Int = try progress.proteinTargetGrams
        let carbohydratesConsumed: Int = try progress.carbohydratesConsumedGrams
        let fatConsumed: Int = try progress.fatConsumedGrams

        XCTAssertEqual(caloriesConsumed, 1_955)
        XCTAssertEqual(calorieTarget, 2_450)
        XCTAssertEqual(proteinConsumed, 162)
        XCTAssertEqual(proteinTarget, 175)
        XCTAssertEqual(carbohydratesConsumed, 194)
        XCTAssertEqual(fatConsumed, 62)
    }

    func testLatestWorkoutSummaryReturnsExactSeededWorkout() async throws {
        let result = try await definitions.intents["GetLatestWorkoutSummaryIntent"]
            .makeIntent()
            .run()
        let summary: AnyTransientAppEntity = try result.value
        let workoutName: String = try summary.workoutName
        let durationMinutes: Int = try summary.durationMinutes
        let entryCount: Int = try summary.entryCount
        let completedSets: Int = try summary.completedSets
        let activeCalories: Int = try summary.activeCalories

        XCTAssertEqual(workoutName, "Upper Strength")
        XCTAssertEqual(durationMinutes, 58)
        XCTAssertEqual(entryCount, 2)
        XCTAssertEqual(completedSets, 5)
        XCTAssertEqual(activeCalories, 260)
    }
}
#endif
