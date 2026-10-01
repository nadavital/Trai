import XCTest
import Foundation

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

    private func captureMigrationScreen(_ app: XCUIApplication, name: String) {
        // Let section transitions and glass compositing settle before visual evidence.
        RunLoop.current.run(until: Date().addingTimeInterval(0.7))
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testActivityDiscStudy() {
        let app = makeApp(extraArguments: ["--activity-disc-study", "--disc-fitted"])
        app.launch()
        XCTAssertTrue(app.buttons["discPetal0"].waitForExistence(timeout: 15))
        captureMigrationScreen(app, name: "Disc partial")
        app.buttons["discPetal0"].tap()
        XCTAssertTrue(app.buttons["discPetal0"].isSelected)
        captureMigrationScreen(app, name: "Disc selected")
        app.buttons["discReset"].tap()
        captureMigrationScreen(app, name: "Disc empty")
        for _ in 0..<4 { app.buttons["discAdd"].tap() }
        captureMigrationScreen(app, name: "Disc complete")
        app.buttons["discAdd"].tap()
        XCTAssertTrue(app.staticTexts["1 additional training days"].exists)
        captureMigrationScreen(app, name: "Disc extra")
        app.buttons["Flower"].tap()
        captureMigrationScreen(app, name: "Bloom complete")
        app.buttons["discReset"].tap()
        app.buttons["discAdd"].tap()
        app.buttons["discAdd"].tap()
        captureMigrationScreen(app, name: "Bloom partial")
        app.buttons["Glass"].tap()
        captureMigrationScreen(app, name: "Glass partial")
        app.buttons["discAdd"].tap()
        app.buttons["discAdd"].tap()
        captureMigrationScreen(app, name: "Glass complete")
        app.buttons["Switch appearance"].tap()
        captureMigrationScreen(app, name: "Glass dark")
        app.buttons["Petal disc"].tap()
        captureMigrationScreen(app, name: "Disc dark")
        let stepper = app.steppers["discTarget"]
        if !stepper.isHittable { app.swipeUp() }
        for _ in 0..<3 { stepper.buttons["discTarget-Increment"].tap() }
        captureMigrationScreen(app, name: "Disc seven")
        for _ in 0..<6 { stepper.buttons["discTarget-Decrement"].tap() }
        captureMigrationScreen(app, name: "Disc one")
    }

    func testIntegratedActivityDial() {
        let app = makeApp(extraArguments: ["--app-store-screenshot-mode", "--ui-test-mock-food-ai", "--ui-test-dial-sessions"])
        app.launch()
        XCTAssertTrue(app.buttons["dashboardSectionActivity"].waitForExistence(timeout: 20))
        app.buttons["dashboardSectionActivity"].tap()
        XCTAssertTrue(app.buttons["Set weekly goal"].waitForExistence(timeout: 5))
        captureMigrationScreen(app, name: "Activity dial no goal")
        app.buttons["Set weekly goal"].tap()
        XCTAssertTrue(app.navigationBars["Weekly workout goal"].waitForExistence(timeout: 5))
        app.buttons["Save"].tap()
        XCTAssertTrue(app.buttons["Edit weekly goal"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.otherElements["2 / 3 workouts this week"].exists || app.staticTexts["2 / 3 workouts this week"].exists)
        captureMigrationScreen(app, name: "Activity dial connected")
        app.buttons["Edit weekly goal"].tap()
        let field = app.textFields["Workouts per week"]
        field.tap()
        field.typeText(XCUIKeyboardKey.delete.rawValue + "1")
        app.buttons["Save"].tap()
        XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "2 / 1 workouts this week")).firstMatch.waitForExistence(timeout: 5))
        captureMigrationScreen(app, name: "Activity dial over goal")
        app.buttons["dashboardSectionToday"].tap()
        app.swipeUp()
        XCTAssertTrue(app.buttons["Show weight details"].waitForExistence(timeout: 5))
        captureMigrationScreen(app, name: "All visuals connected")
    }

    func testIntegratedWeightScale() {
        let app = makeApp(extraArguments: ["--app-store-screenshot-mode", "--ui-test-mock-food-ai"])
        app.launch()
        XCTAssertTrue(app.buttons["dashboardNutritionLogFood"].firstMatch.waitForExistence(timeout: 20))
        captureMigrationScreen(app, name: "Integrated Today")
        app.swipeUp()
        XCTAssertTrue(app.buttons["Show weight details"].waitForExistence(timeout: 5))
        captureMigrationScreen(app, name: "Integrated context cards")
        app.buttons["Show weight details"].tap()
        XCTAssertTrue(app.buttons["See weight history"].waitForExistence(timeout: 5))
        captureMigrationScreen(app, name: "Integrated Weight")
        app.buttons["Log weight"].tap()
        XCTAssertTrue(app.navigationBars["Log Weight"].waitForExistence(timeout: 5))
        captureMigrationScreen(app, name: "Integrated weight logging")
        let field = app.textFields["0.0"].firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.tap()
        let oldValue = field.value as? String ?? ""
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: oldValue.count) + "178.2")
        app.buttons["Save"].tap()
        XCTAssertTrue(waitForNonExistence(app.navigationBars["Log Weight"], timeout: 5))
        XCTAssertTrue(app.staticTexts["178.2"].firstMatch.waitForExistence(timeout: 5), "Saved weight must update the section")
        captureMigrationScreen(app, name: "Weight section after saving")
        app.buttons["See weight history"].tap()
        XCTAssertTrue(app.buttons["weightHistoryDone"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["178.2"].firstMatch.exists)
        captureMigrationScreen(app, name: "Saved weight in history")
    }

    func testWeightScaleStudy() {
        let app = makeApp(extraArguments: ["--scale-study"])
        app.launch()
        XCTAssertTrue(app.buttons["Log weight from dashboard"].waitForExistence(timeout: 30))
        captureMigrationScreen(app, name: "Scale light")
        app.buttons["Log weight from dashboard"].tap()
        app.buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts["Today’s check-in"].waitForExistence(timeout: 5))
        captureMigrationScreen(app, name: "Scale saved")
        app.buttons["Switch appearance"].tap()
        XCTAssertEqual(app.buttons["Switch appearance"].value as? String, "Dark")
        captureMigrationScreen(app, name: "Scale dark")
    }

    func testRoutineRhythmStudy() {
        let app = makeApp(extraArguments: ["--rhythm-study"])
        app.launch()
        XCTAssertTrue(app.buttons["rhythmRow-weight"].waitForExistence(timeout: 15))
        captureMigrationScreen(app, name: "Rhythm light")
        app.buttons["rhythmRow-weight"].tap()
        app.buttons["Save check-in"].tap()
        XCTAssertTrue(app.staticTexts["Today’s check-ins are complete."].waitForExistence(timeout: 5))
        captureMigrationScreen(app, name: "Rhythm completed")
        app.buttons["Switch appearance"].tap()
        XCTAssertEqual(app.buttons["Switch appearance"].value as? String, "Dark")
        captureMigrationScreen(app, name: "Rhythm dark")
        app.swipeUp()
        app.buttons["rhythmDay"].tap()
        app.buttons["Sun"].tap()
        XCTAssertTrue(app.buttons["rhythmRow-weight"].exists)
        XCTAssertTrue(app.buttons["rhythmRow-plan"].exists)
        XCTAssertTrue(app.staticTexts["Coming up"].exists)
        captureMigrationScreen(app, name: "Rhythm Sunday")
    }

    func testRoutineStudy() {
        let app = makeApp(extraArguments: ["--routine-study"])
        app.launch()
        XCTAssertTrue(app.buttons["routineCheckIn"].waitForExistence(timeout: 15))
        captureMigrationScreen(app, name: "Routine light")
        app.buttons["routineCheckIn"].tap()
        app.buttons["Save check-in"].tap()
        XCTAssertTrue(app.staticTexts["Your week is covered"].waitForExistence(timeout: 5))
        app.buttons["Complete Pack your gym bag"].tap()
        XCTAssertTrue(app.buttons["Undo Pack your gym bag"].exists)
        captureMigrationScreen(app, name: "Routine completed")
        app.buttons["Options for Plan tomorrow’s meals"].tap()
        app.buttons["Snooze until tomorrow"].tap()
        app.buttons["Options for Plan tomorrow’s meals"].tap()
        app.buttons["Edit"].tap()
        XCTAssertEqual(app.textFields["Reminder"].value as? String, "Plan tomorrow’s meals")
        XCTAssertTrue(app.buttons["Save reminder"].isEnabled)
        app.buttons["Save reminder"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", "Tomorrow", "7:30")).firstMatch.waitForExistence(timeout: 5))
        let dismissal = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: app.buttons["Save reminder"])
        XCTAssertEqual(XCTWaiter.wait(for: [dismissal], timeout: 10), .completed)
        let appearance = app.buttons["Switch appearance"]
        let tappable = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true"), object: appearance)
        XCTAssertEqual(XCTWaiter.wait(for: [tappable], timeout: 10), .completed)
        appearance.tap()
        let dark = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", "Dark"), object: appearance)
        XCTAssertEqual(XCTWaiter.wait(for: [dark], timeout: 5), .completed)
        captureMigrationScreen(app, name: "Routine dark")
        app.buttons["routineSection0"].tap()
        captureMigrationScreen(app, name: "Routine today card")
    }

    func testWeightMarkStudy() {
        let app = makeApp(extraArguments: ["--weight-mark-study"])
        app.launch()
        XCTAssertTrue(app.buttons["weightMarkHero"].waitForExistence(timeout: 15))
        captureMigrationScreen(app, name: "Weight fold light")
        app.buttons["weightMarkLog"].tap()
        XCTAssertTrue(app.buttons["Save sample"].waitForExistence(timeout: 5))
        app.buttons["Save sample"].tap()
        XCTAssertTrue(app.staticTexts["Just checked in"].waitForExistence(timeout: 5))
        app.buttons["Imprint"].tap()
        captureMigrationScreen(app, name: "Weight imprint light")
        app.buttons["Switch appearance"].tap()
        captureMigrationScreen(app, name: "Weight imprint dark")
        app.buttons["Fold"].tap()
        captureMigrationScreen(app, name: "Weight fold dark")
        app.switches["weightMarkSample"].tap()
        captureMigrationScreen(app, name: "Weight empty")
    }

    func testActivityGaugeWorkoutCount() {
        let app = makeApp(extraArguments: ["--activity-disc-study", "--disc-gauge", "--disc-single-target", "--disc-extra"])
        app.launch()
        let status = app.descendants(matching: .any)["gaugeStatus"]
        XCTAssertTrue(status.waitForExistence(timeout: 15))
        XCTAssertEqual(status.label, "6 workouts completed this week, weekly goal 1")
        XCTAssertEqual(app.staticTexts["discCompactCount"].label, "6 workouts")
        captureMigrationScreen(app, name: "Workout count six of one")
        app.buttons["discAdd"].tap()
        app.buttons["discAdd"].tap()
        XCTAssertEqual(status.label, "8 workouts completed this week, weekly goal 1")
        XCTAssertEqual(app.staticTexts["discCompactCount"].label, "8 workouts")
        XCTAssertTrue(app.buttons["discAdd"].isEnabled)
        captureMigrationScreen(app, name: "Workout count beyond seven")
    }

    func testActivityGaugeLaps() {
        let app = makeApp(extraArguments: ["--activity-disc-study", "--disc-gauge", "--disc-laps"])
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["gaugeStatus"].waitForExistence(timeout: 15))
        captureMigrationScreen(app, name: "Laps exactly one")
        app.buttons["discAdd"].tap()
        captureMigrationScreen(app, name: "Laps one and a half")
        app.buttons["discAdd"].tap()
        captureMigrationScreen(app, name: "Laps exactly two")
        app.buttons["discAdd"].tap()
        captureMigrationScreen(app, name: "Laps two and a half")
        app.buttons["discAdd"].tap()
        captureMigrationScreen(app, name: "Laps exactly three")
        app.buttons["discAdd"].tap()
        captureMigrationScreen(app, name: "Laps three and a half")
        app.buttons["Switch appearance"].tap()
        captureMigrationScreen(app, name: "Laps dark")
        app.buttons["discReset"].tap()
        captureMigrationScreen(app, name: "Laps reset")
    }

    func testActivityGaugeStudy() {
        let app = makeApp(extraArguments: ["--activity-disc-study", "--disc-gauge"])
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["gaugeStatus"].waitForExistence(timeout: 15))
        captureMigrationScreen(app, name: "Gauge partial glass")
        app.buttons["discReset"].tap()
        captureMigrationScreen(app, name: "Gauge empty")
        for _ in 0..<4 { app.buttons["discAdd"].tap() }
        captureMigrationScreen(app, name: "Gauge complete")
        app.buttons["discAdd"].tap()
        app.buttons["discAdd"].tap()
        captureMigrationScreen(app, name: "Gauge extra")
        app.switches["gaugeGlass"].tap()
        captureMigrationScreen(app, name: "Gauge satin")
        app.switches["gaugeGlass"].tap()
        app.buttons["Switch appearance"].tap()
        captureMigrationScreen(app, name: "Gauge dark")
    }

    func testActivityOrbitStudy() {
        let app = makeApp(extraArguments: ["--activity-disc-study", "--disc-orbit"])
        app.launch()
        XCTAssertTrue(app.buttons["discPetal0"].waitForExistence(timeout: 15))
        captureMigrationScreen(app, name: "Orbit partial")
        app.buttons["discPetal0"].tap()
        XCTAssertTrue(app.buttons["discPetal0"].isSelected)
        app.buttons["discReset"].tap()
        captureMigrationScreen(app, name: "Orbit empty")
        for _ in 0..<5 { app.buttons["discAdd"].tap() }
        captureMigrationScreen(app, name: "Orbit complete")
        app.buttons["discAdd"].tap()
        captureMigrationScreen(app, name: "Orbit extra")
        app.buttons["discBonus0"].tap()
        XCTAssertTrue(app.buttons["discBonus0"].isSelected)
        app.buttons["discAdd"].tap()
        captureMigrationScreen(app, name: "Orbit two extras")
        app.buttons["Switch appearance"].tap()
        captureMigrationScreen(app, name: "Orbit dark")
        let stepper = app.steppers["discTarget"]
        stepper.buttons["discTarget-Increment"].tap()
        stepper.buttons["discTarget-Increment"].tap()
        captureMigrationScreen(app, name: "Orbit seven")
        for _ in 0..<3 { stepper.buttons["discTarget-Decrement"].tap() }
        captureMigrationScreen(app, name: "Orbit four")
        app.swipeUp()
        captureMigrationScreen(app, name: "Orbit identity comparison")
    }

    func testActivityFlowerStudy() {
        let app = makeApp(extraArguments: ["--activity-disc-study", "--disc-bloom"])
        app.launch()
        XCTAssertTrue(app.buttons["discPetal0"].waitForExistence(timeout: 15))
        captureMigrationScreen(app, name: "Flower partial")
        app.buttons["discPetal0"].tap()
        XCTAssertTrue(app.buttons["discPetal0"].isSelected)
        captureMigrationScreen(app, name: "Flower selected")
        app.buttons["discReset"].tap()
        captureMigrationScreen(app, name: "Flower empty")
        for _ in 0..<4 { app.buttons["discAdd"].tap() }
        captureMigrationScreen(app, name: "Flower complete")
        app.buttons["discAdd"].tap()
        captureMigrationScreen(app, name: "Flower one extra")
        app.buttons["discAdd"].tap()
        captureMigrationScreen(app, name: "Flower two extras")
        app.buttons["discBonus1"].tap()
        XCTAssertTrue(app.buttons["discBonus1"].isSelected)
        app.buttons["discBonus1"].tap()
        app.buttons["Switch appearance"].tap()
        captureMigrationScreen(app, name: "Flower dark extras")
        let stepper = app.steppers["discTarget"]
        for _ in 0..<3 { stepper.buttons["discTarget-Increment"].tap() }
        XCTAssertTrue(app.buttons["discPetal6"].exists)
        captureMigrationScreen(app, name: "Flower seven")
        for _ in 0..<6 { stepper.buttons["discTarget-Decrement"].tap() }
        XCTAssertFalse(app.buttons["discPetal1"].exists)
        captureMigrationScreen(app, name: "Flower one goal five extras")
        stepper.buttons["discTarget-Increment"].tap()
        captureMigrationScreen(app, name: "Flower two goal four extras")
        stepper.buttons["discTarget-Increment"].tap()
        app.buttons["discAdd"].tap()
        captureMigrationScreen(app, name: "Flower three goal four extras")
    }

    func testActivitySymbolTargets() {
        let app = makeApp(extraArguments: ["--symbol-exploration"])
        app.launch()
        let stepper = app.steppers["studyTarget"]
        XCTAssertTrue(stepper.waitForExistence(timeout: 15))
        if !stepper.isHittable { app.swipeUp() }
        for _ in 0..<3 { stepper.buttons["studyTarget-Increment"].tap() }
        XCTAssertTrue(app.buttons["studyPetal6"].exists)
        captureMigrationScreen(app, name: "Symbol Activity seven")
        for _ in 0..<6 { stepper.buttons["studyTarget-Decrement"].tap() }
        XCTAssertFalse(app.buttons["studyPetal1"].exists)
        captureMigrationScreen(app, name: "Symbol Activity one extra")
        app.buttons["studyReset"].tap()
        captureMigrationScreen(app, name: "Symbol Activity empty")
    }

    func testSymbolExploration() {
        let app = makeApp(extraArguments: ["--symbol-exploration"])
        app.launch()
        XCTAssertTrue(app.buttons["studyPetal0"].waitForExistence(timeout: 15))
        captureMigrationScreen(app, name: "Symbol Activity open")
        app.buttons["studyPetal0"].tap()
        XCTAssertTrue(app.buttons["studyPetal0"].isSelected)
        app.buttons["Folded petals"].tap()
        captureMigrationScreen(app, name: "Symbol Activity folded")
        app.buttons["studyAddDay"].tap()
        app.buttons["studyAddDay"].tap()
        captureMigrationScreen(app, name: "Symbol Activity complete")
        app.buttons["Switch appearance"].tap()
        captureMigrationScreen(app, name: "Symbol Activity dark")
        app.buttons["Weight"].tap()
        captureMigrationScreen(app, name: "Symbol Weight dark")
        app.buttons["Switch appearance"].tap()
        captureMigrationScreen(app, name: "Symbol Weight light")
        app.buttons["weightPebble-large-0"].tap()
        XCTAssertTrue(app.buttons["weightPebble-large-0"].isSelected)
        app.buttons["Fanned"].tap()
        captureMigrationScreen(app, name: "Symbol Weight fanned")
        app.buttons["One"].tap()
        captureMigrationScreen(app, name: "Symbol Weight one")
        app.buttons["Empty"].tap()
        XCTAssertTrue(app.staticTexts["No check-ins yet"].exists)
        captureMigrationScreen(app, name: "Symbol Weight empty")

    }

    func testPersonalActivityAndWeightCheckIn() {
        let app = makeApp(extraArguments: ["--app-store-screenshot-mode", "--ui-test-mock-food-ai"])
        app.launch()
        XCTAssertTrue(app.buttons["dashboardNutritionLogFood"].firstMatch.waitForExistence(timeout: 15))
        app.swipeUp()
        captureMigrationScreen(app, name: "Personal Today context")
        // Move through adjacent sections so enlarged header pills are on screen.
        app.buttons["dashboardSectionNutrition"].tap()
        app.buttons["dashboardSectionActivity"].tap()
        let day = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "activityRhythmDay-")).firstMatch
        XCTAssertTrue(day.waitForExistence(timeout: 5))
        day.tap()
        XCTAssertTrue(day.isSelected)
        captureMigrationScreen(app, name: "Personal Activity")
        app.buttons["dashboardSectionWeight"].tap()
        XCTAssertTrue(app.buttons["Log weight"].waitForExistence(timeout: 5))
        captureMigrationScreen(app, name: "Personal Weight")
        if !app.buttons["See weight history"].isHittable { app.swipeUp() }
        app.buttons["See weight history"].tap()
        XCTAssertTrue(app.buttons["weightHistoryDone"].waitForExistence(timeout: 5))
        app.buttons["weightHistoryDone"].tap()
        XCTAssertTrue(app.buttons["Log weight"].waitForExistence(timeout: 5))
    }

    func testVisualCleanupLargeText() {
        let app = makeApp(extraArguments: ["--app-store-screenshot-mode", "--ui-test-mock-food-ai",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        app.launch()
        XCTAssertTrue(app.buttons["dashboardAccount"].waitForExistence(timeout: 20))
        captureMigrationScreen(app, name: "Large text Today")
        for section in ["Nutrition", "Activity", "Weight"] {
            app.buttons["dashboardSectionMenu"].tap()
            app.buttons["dashboardSection" + section].tap()
            captureMigrationScreen(app, name: "Large text " + section)
        }
        app.tabBars.buttons["Workouts"].tap()
        XCTAssertTrue(app.buttons["workoutSection-Train"].waitForExistence(timeout: 10))
        captureMigrationScreen(app, name: "Large text Train")
        app.tabBars.buttons["Trai"].tap()
        captureMigrationScreen(app, name: "Large text Chat")
    }

    func testMigrationScreenTour() {
        let app = makeApp(extraArguments: ["--app-store-screenshot-mode", "--ui-test-mock-food-ai"])
        app.launch()
        XCTAssertTrue(app.buttons["dashboardNutritionLogFood"].firstMatch.waitForExistence(timeout: 15))
        captureMigrationScreen(app, name: "Migration Today")
        app.swipeUp()
        captureMigrationScreen(app, name: "Migration Today context")
        app.buttons["dashboardSectionNutrition"].tap()
        XCTAssertTrue(app.buttons["dashboardNutritionDetails"].firstMatch.waitForExistence(timeout: 5))
        captureMigrationScreen(app, name: "Migration Nutrition")
        app.buttons["dashboardNutritionDetails"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Nutrition details"].waitForExistence(timeout: 5))
        captureMigrationScreen(app, name: "Migration nutrition detail")
        app.buttons["Done"].firstMatch.tap()
        for section in ["Activity", "Weight"] {
            app.buttons["dashboardSection" + section].tap()
            if section == "Activity" {
                XCTAssertTrue(app.buttons["Set weekly goal"].waitForExistence(timeout: 5))
            }
            captureMigrationScreen(app, name: "Migration Dashboard " + section)
        }
        app.buttons["See weight history"].tap()
        XCTAssertTrue(app.buttons["weightHistoryDone"].waitForExistence(timeout: 5))
        captureMigrationScreen(app, name: "Migration Weight history")
        app.buttons["weightHistoryDone"].tap()
        app.tabBars.buttons["Workouts"].tap()
        XCTAssertTrue(app.buttons["workoutSection-Train"].waitForExistence(timeout: 10))
        print("WORKOUT_HEADER_FRAME \(app.buttons["workoutSection-Train"].frame) hittable=\(app.buttons["workoutSection-Train"].isHittable)")
        captureMigrationScreen(app, name: "Migration Workout Train")
        for section in ["Plan", "Progress", "History"] {
            app.buttons["workoutSection-" + section].tap()
            XCTAssertTrue(app.buttons["workoutSection-" + section].isSelected)
            captureMigrationScreen(app, name: "Migration Workout " + section)
        }
        app.tabBars.buttons["Dashboard"].tap()
        XCTAssertTrue(app.buttons["dashboardAccount"].waitForExistence(timeout: 10))
        app.buttons["dashboardAccount"].tap()
        XCTAssertTrue(app.buttons["accountSettings"].waitForExistence(timeout: 10))
        captureMigrationScreen(app, name: "Migration Account")
        app.buttons["accountSettings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        captureMigrationScreen(app, name: "Migration Settings")
        app.navigationBars["Settings"].buttons["Done"].tap()
        XCTAssertTrue(app.buttons["accountDone"].waitForExistence(timeout: 5))
        app.buttons["accountDone"].tap()
        app.tabBars.buttons["Trai"].tap()
        XCTAssertTrue(app.navigationBars["Trai"].waitForExistence(timeout: 10))
        captureMigrationScreen(app, name: "Migration Chat")
    }

    func testFocusedWorkoutLoggingAndCompletion() {
        let app = makeApp(extraArguments: ["--ui-test-authenticated-free-plan", "-pendingAppRoute", "trai://workout", "--ui-test-live-workout-preset"])
        app.launch()
        if !waitForLiveWorkoutScreen(in: app, timeout: 15) {
            app.terminate()
            app.launch()
        }
        XCTAssertTrue(waitForLiveWorkoutScreen(in: app, timeout: 15))
        captureMigrationScreen(app, name: "Focused live workout")
        let editor = app.otherElements["focusedExerciseEditor"]
        app.buttons["liveExercise-Incline Press"].tap()
        XCTAssertTrue(editor.textFields["Set 3 repetitions"].waitForExistence(timeout: 5))
        editor.buttons["liveWorkoutAddSetButton"].tap()
        XCTAssertTrue(editor.textFields["Set 4 repetitions"].waitForExistence(timeout: 5))
        app.buttons["liveExercise-Bench Press"].tap()
        editor.buttons["liveWorkoutAddSetButton"].tap()
        XCTAssertTrue(editor.textFields["Set 5 repetitions"].waitForExistence(timeout: 5))
        captureMigrationScreen(app, name: "Focused workout added set")
        let weight = editor.textFields["Set 1 weight"]
        weight.doubleTap()
        weight.typeText("200")
        let confirmWeight = app.buttons.matching(NSPredicate(format: "label == %@", "Use 200 kg")).firstMatch
        XCTAssertTrue(confirmWeight.waitForExistence(timeout: 5))
        confirmWeight.tap()
        app.buttons["liveWorkoutEndButton"].tap()
        app.buttons["End Workout"].tap()
        XCTAssertTrue(app.navigationBars["Summary"].waitForExistence(timeout: 8))
        captureMigrationScreen(app, name: "Workout completion overview")
        let details = app.buttons["workoutSummaryDetails"]
        XCTAssertTrue(details.waitForExistence(timeout: 5))
        details.tap()
        XCTAssertTrue(app.staticTexts["Bench Press"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Incline Press"].exists)
        captureMigrationScreen(app, name: "Workout completion details")
    }

    func testWorkoutLargeTextLayout() {
        let app = makeApp(extraArguments: [
            "--ui-test-authenticated-free-plan", "-pendingAppRoute", "trai://workout",
            "--ui-test-live-workout-preset", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityM"
        ])
        app.launch()
        XCTAssertTrue(waitForLiveWorkoutScreen(in: app, timeout: 15))
        captureMigrationScreen(app, name: "Live workout large text")
        let add = app.otherElements["focusedExerciseEditor"].buttons["liveWorkoutAddSetButton"]
        XCTAssertTrue(add.exists)
        add.tap()
        captureMigrationScreen(app, name: "Large text logging controls")
    }

    func testWorkoutSectionsInlineTour() {
        let app = XCUIApplication()
        app.launchArguments = ["--test-persona", "consistent", "--test-persona-ai", "deterministic", "--disable-tab-prewarm", "-selectedTab", "dashboard"]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Workouts"].waitForExistence(timeout: 15))
        app.tabBars.buttons["Workouts"].tap()
        XCTAssertTrue(app.buttons["workoutSection-Train"].waitForExistence(timeout: 15))
        app.buttons["workoutSection-Train"].tap()
        captureMigrationScreen(app, name: "Workout Train")
        for section in ["Plan", "Progress", "History"] {
            let button = app.buttons["workoutSection-\(section)"]
            if !button.isHittable {
                app.buttons["workoutSection-Progress"].swipeLeft()
            }
            button.tap()
            let content: XCUIElement
            switch section {
            case "Plan": content = app.buttons["Edit plan"].firstMatch
            case "Progress": content = app.buttons["workoutAllRecords"]
            default: content = app.staticTexts["Strength training"].firstMatch
            }
            let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isHittable == true"), object: content)
            XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 8), .completed)
            captureMigrationScreen(app, name: "Workout \(section)")
            XCTAssertFalse(app.sheets.firstMatch.exists)
        }
    }

    func testMigrationLiveWorkoutLayout() {
        let app = makeApp(extraArguments: ["--ui-test-authenticated-free-plan", "-pendingAppRoute", "trai://workout", "--ui-test-live-workout-preset"])
        app.launch()
        XCTAssertTrue(waitForLiveWorkoutScreen(in: app, timeout: 15))
        captureMigrationScreen(app, name: "Migration Live Workout")
        app.swipeUp()
        captureMigrationScreen(app, name: "Migration Live Workout sets")
    }

    func testMainTabsAreVisibleAndNavigable() {
        let app = makeApp()
        app.launch()

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 8))

        let dashboardTab = tabBar.buttons["Dashboard"]
        let traiTab = tabBar.buttons["Trai"]
        let workoutsTab = tabBar.buttons["Workouts"]

        XCTAssertTrue(dashboardTab.exists)
        XCTAssertTrue(traiTab.exists)
        XCTAssertTrue(workoutsTab.exists)
        XCTAssertFalse(tabBar.buttons["Profile"].exists)

        workoutsTab.tap()
        XCTAssertTrue(workoutsTab.isSelected)

        traiTab.tap()
        XCTAssertTrue(traiTab.isSelected)

        dashboardTab.tap()
        XCTAssertTrue(dashboardTab.isSelected)
    }

    func testAccountSheetReplacesProfileTabAndKeepsSettingsAccessible() {
        let app = makeApp()
        app.launch()
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 10))
        for title in ["Dashboard", "Workouts", "Trai"] {
            XCTAssertTrue(tabBar.buttons[title].exists)
        }
        XCTAssertFalse(tabBar.buttons["Profile"].exists)
        XCTAssertEqual(tabBar.buttons.count, 3)

        let accountButton = app.buttons["dashboardAccount"]
        XCTAssertTrue(accountButton.waitForExistence(timeout: 10))
        accountButton.tap()
        XCTAssertTrue(app.navigationBars["Account"].waitForExistence(timeout: 5))
        let settingsButton = app.buttons["accountSettings"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))
        settingsButton.tap()
        let settingsNavigation = app.navigationBars["Settings"]
        XCTAssertTrue(settingsNavigation.waitForExistence(timeout: 5))
        settingsNavigation.buttons["Done"].tap()
        let accountDone = app.buttons["accountDone"]
        XCTAssertTrue(accountDone.waitForExistence(timeout: 5))
        accountDone.tap()
        XCTAssertTrue(waitForNonExistence(accountDone, timeout: 5))
        XCTAssertTrue(tabBar.buttons["Dashboard"].isSelected)
        XCTAssertTrue(accountButton.isHittable)
    }

    func testPlansRemainAccessibleFromNutritionAndWorkouts() {
        let app = makeApp(extraArguments: ["--app-store-screenshot-mode"])
        app.launch()
        XCTAssertTrue(app.buttons["dashboardSectionNutrition"].waitForExistence(timeout: 10))
        app.buttons["dashboardSectionNutrition"].tap()
        let nutritionOptions = app.buttons["Nutrition options"]
        for _ in 0..<4 where !nutritionOptions.isHittable { app.swipeUp() }
        nutritionOptions.tap()
        let nutritionPlan = app.buttons["Nutrition plan"]
        XCTAssertTrue(nutritionPlan.waitForExistence(timeout: 5))
        XCTAssertTrue(nutritionPlan.isHittable)
        nutritionPlan.tap()
        XCTAssertTrue(app.navigationBars["Nutrition plan"].waitForExistence(timeout: 5))
        app.buttons["profileDestinationDone"].tap()

        app.tabBars.buttons["Workouts"].tap()
        XCTAssertTrue(app.buttons["workoutSection-Plan"].waitForExistence(timeout: 10))
        app.buttons["workoutSection-Plan"].tap()
        let workoutPlan = app.buttons["workoutManagePlan"]
        for _ in 0..<4 where !workoutPlan.isHittable { app.swipeUp() }
        XCTAssertTrue(workoutPlan.waitForExistence(timeout: 5))
        XCTAssertTrue(workoutPlan.isHittable)
        captureMigrationScreen(app, name: "Workout plan bottom actions")
        workoutPlan.tap()
        XCTAssertTrue(app.navigationBars["Workout plan"].waitForExistence(timeout: 5))
        app.buttons["profileDestinationDone"].tap()
        XCTAssertTrue(app.tabBars.buttons["Workouts"].isSelected)
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

        XCTAssertTrue(app.buttons["compactFoodClose"].waitForExistence(timeout: 8))
        XCTAssertTrue(
            app.buttons["compactFoodCapture"].waitForExistence(timeout: 4)
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

    func testDashboardResumeActionOpensExistingWorkout() {
        let app = makeApp(extraArguments: [
            "--ui-test-authenticated-free-plan",
            "-pendingAppRoute", "trai://workout",
            "--ui-test-live-workout-preset"
        ])
        app.launch()
        XCTAssertTrue(waitForLiveWorkoutScreen(in: app, timeout: 12))
        minimizeLiveWorkoutAndAssertBanner(in: app)
        let dashboard = app.tabBars.buttons["Dashboard"]
        if !dashboard.isHittable {
            app.navigationBars.firstMatch.swipeDown()
        }
        let visible = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isHittable == true"), object: dashboard)
        XCTAssertEqual(XCTWaiter.wait(for: [visible], timeout: 6), .completed)
        dashboard.tap()
        let resume = app.buttons["Resume workout"]
        XCTAssertTrue(resume.waitForExistence(timeout: 6))
        resume.tap()
        XCTAssertTrue(waitForLiveWorkoutScreen(in: app, timeout: 6))
    }

    func testDashboardContextCardsOpenWeightLogging() {
        let app = makeApp(extraArguments: ["-selectedTab", "dashboard"])
        app.launch()
        XCTAssertTrue(app.buttons["dashboardNutritionLogFood"].firstMatch.waitForExistence(timeout: 10))
        captureMigrationScreen(app, name: "Dashboard food and Add actions")
        app.swipeUp()
        XCTAssertTrue(app.buttons["Show activity details"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.buttons["Show weight details"].exists)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Contextual activity and weight cards"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        app.buttons["Log weight"].tap()
        XCTAssertTrue(app.navigationBars["Log Weight"].waitForExistence(timeout: 5))
    }

    func testCameraRecentMealSuggestionOpensReviewBeforeSave() {
        let app = makeApp(extraArguments: ["--ui-test-mock-food-ai", "--ui-test-food-suggestions"])
        app.launch()
        app.buttons["dashboardNutritionLogFood"].firstMatch.tap()
        let recent = app.buttons["Salmon rice bowl"]
        XCTAssertTrue(recent.waitForExistence(timeout: 8))
        let capture = XCTAttachment(screenshot: app.screenshot())
        capture.name = "Camera with direct meal pills"
        capture.lifetime = .keepAlways
        add(capture)
        recent.tap()
        let save = app.buttons["compactFoodSave"]
        XCTAssertTrue(save.waitForExistence(timeout: 6))
        XCTAssertTrue(app.staticTexts["≈ 620 kcal"].exists)
        captureMigrationScreen(app, name: "Camera suggestion review")
        app.buttons["compactFoodClose"].tap()
        let calories = app.descendants(matching: .any)["dashboardNutritionCalories"].firstMatch
        XCTAssertTrue(calories.waitForExistence(timeout: 5))
        XCTAssertFalse((calories.value as? String ?? "").contains("620"), "Selecting a suggestion must not save without confirmation")
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

    func testDashboardNutritionCardNavigatesToSectionWithoutSheet() {
        let app = makeApp()
        app.launch()
        let log = app.buttons["dashboardNutritionLogFood"].firstMatch
        XCTAssertTrue(log.waitForExistence(timeout: 10))
        XCTAssertTrue(log.isHittable)
        app.buttons["dashboardNutritionDetails"].firstMatch.tap()
        let section = app.buttons["dashboardSectionNutrition"]
        let selected = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isSelected == true"), object: section)
        XCTAssertEqual(XCTWaiter.wait(for: [selected], timeout: 4), .completed)
        XCTAssertFalse(app.sheets.firstMatch.exists)
        XCTAssertTrue(app.descendants(matching: .any)["dashboardPageNutrition"].firstMatch.exists)
        app.swipeRight()
        XCTAssertTrue(log.waitForExistence(timeout: 4))
        XCTAssertTrue(log.isHittable)
    }

    func testDashboardCameraLogAutomaticallyAnalyzesAndUpdatesNutrition() {
        let app = makeApp(extraArguments: ["--ui-test-mock-food-ai"])
        app.launch()

        let logFood = app.buttons["dashboardNutritionLogFood"].firstMatch
        XCTAssertTrue(logFood.waitForExistence(timeout: 12))
        let before = XCTAttachment(screenshot: app.screenshot())
        before.name = "Connected dashboard before logging"
        before.lifetime = .keepAlways
        add(before)
        logFood.tap()

        let shutter = app.buttons["compactFoodCapture"]
        XCTAssertTrue(shutter.waitForExistence(timeout: 6))
        shutter.tap()

        let save = app.buttons["compactFoodSave"]
        XCTAssertTrue(save.waitForExistence(timeout: 12), "Photo should analyze without an Analyze tap")
        let review = XCTAttachment(screenshot: app.screenshot())
        review.name = "Automatic photo estimate"
        review.lifetime = .keepAlways
        add(review)
        save.tap()

        XCTAssertTrue(logFood.waitForExistence(timeout: 8))
        let calories = app.descendants(matching: .any)["dashboardNutritionCalories"].firstMatch
        XCTAssertTrue(calories.waitForExistence(timeout: 4))
        XCTAssertTrue((calories.value as? String ?? "").contains("430"), "Saved meal must update the real dashboard totals")
        app.swipeLeft()
        let nutritionSection = app.buttons["dashboardSectionNutrition"]
        let selected = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isSelected == true"), object: nutritionSection)
        XCTAssertEqual(XCTWaiter.wait(for: [selected], timeout: 4), .completed)
        XCTAssertTrue(app.staticTexts["Ui Test Meal"].firstMatch.waitForExistence(timeout: 6))
        let after = XCTAttachment(screenshot: app.screenshot())
        after.name = "Saved food in connected nutrition page"
        after.lifetime = .keepAlways
        add(after)
        app.swipeUp()
        let meals = XCTAttachment(screenshot: app.screenshot())
        meals.name = "Refreshed meal timeline"
        meals.lifetime = .keepAlways
        add(meals)
    }

    func testFoodSheetSavesEditedPortion() {
        let app = makeApp(extraArguments: ["--ui-test-mock-food-ai"])
        app.launch()
        let log = app.buttons["dashboardNutritionLogFood"].firstMatch
        XCTAssertTrue(log.waitForExistence(timeout: 12))
        log.tap()
        let capture = app.buttons["compactFoodCapture"]
        XCTAssertTrue(capture.waitForExistence(timeout: 6))
        let camera = XCTAttachment(screenshot: app.screenshot())
        camera.name = "Connected half-sheet capture"
        camera.lifetime = .keepAlways
        add(camera)
        capture.tap()
        let save = app.buttons["compactFoodSave"]
        XCTAssertTrue(save.waitForExistence(timeout: 12))
        let portion = app.steppers["compactFoodPortion"]
        XCTAssertTrue(portion.exists)
        portion.buttons["compactFoodPortion-Increment"].tap()
        XCTAssertTrue(app.staticTexts["≈ 645 kcal"].waitForExistence(timeout: 3))
        let review = XCTAttachment(screenshot: app.screenshot())
        review.name = "Connected half-sheet edited estimate"
        review.lifetime = .keepAlways
        add(review)
        save.tap()
        let dismissed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: save)
        XCTAssertEqual(XCTWaiter.wait(for: [dismissed], timeout: 8), .completed)
        let calories = app.descendants(matching: .any)["dashboardNutritionCalories"].firstMatch
        XCTAssertTrue(calories.waitForExistence(timeout: 4))
        XCTAssertTrue((calories.value as? String ?? "").contains("645"), "Edited portion must persist and update dashboard")
        app.swipeLeft()
        XCTAssertTrue(app.staticTexts["Ui Test Meal"].firstMatch.waitForExistence(timeout: 6))
    }

    func testFoodSheetRefinesAdjustedPortion() {
        let app = makeApp(extraArguments: ["--ui-test-mock-food-ai"])
        app.launch()
        let log = app.buttons["dashboardNutritionLogFood"].firstMatch
        XCTAssertTrue(log.waitForExistence(timeout: 12))
        log.tap()
        let capture = app.buttons["compactFoodCapture"]
        XCTAssertTrue(capture.waitForExistence(timeout: 6))
        capture.tap()
        XCTAssertTrue(app.buttons["compactFoodSave"].waitForExistence(timeout: 12))
        app.steppers["compactFoodPortion"].buttons["compactFoodPortion-Increment"].tap()
        app.buttons["Adjust estimate"].tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3), "Adjust should focus the correction without an extra tap")
        let correction = app.textFields["What should change?"].firstMatch
        let multiline = app.textViews.firstMatch
        let input = correction.exists ? correction : multiline
        XCTAssertTrue(input.waitForExistence(timeout: 3))
        input.tap()
        input.typeText("Add 100 calories")
        app.buttons["Update estimate"].tap()
        XCTAssertTrue(app.staticTexts["≈ 745 kcal"].waitForExistence(timeout: 8), "Correction must use the locally adjusted 645-calorie estimate")
        XCTAssertTrue(waitForNonExistence(app.keyboards.firstMatch, timeout: 3), "Updating should reveal the estimate and save action")
        captureMigrationScreen(app, name: "Food correction completed without keyboard")
    }

    func testFoodSheetRetakeAndCancelDoNotSave() {
        let app = makeApp(extraArguments: ["--ui-test-mock-food-ai"])
        app.launch()
        let log = app.buttons["dashboardNutritionLogFood"].firstMatch
        XCTAssertTrue(log.waitForExistence(timeout: 12))
        log.tap()
        let capture = app.buttons["compactFoodCapture"]
        XCTAssertTrue(capture.waitForExistence(timeout: 6))
        capture.tap()
        XCTAssertTrue(app.buttons["compactFoodSave"].waitForExistence(timeout: 12))
        app.buttons["compactFoodRetake"].tap()
        XCTAssertTrue(capture.waitForExistence(timeout: 4))
        app.buttons["compactFoodClose"].tap()
        let dismissed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: capture)
        XCTAssertEqual(XCTWaiter.wait(for: [dismissed], timeout: 5), .completed)
        let calories = app.descendants(matching: .any)["dashboardNutritionCalories"].firstMatch
        XCTAssertFalse((calories.value as? String ?? "").contains("430"))
        log.tap()
        XCTAssertTrue(capture.waitForExistence(timeout: 4), "Reopening must start with a fresh capture")
        XCTAssertFalse(app.buttons["compactFoodSave"].exists)
    }

    func testFoodCameraRefinementRestoresSaveButton() {
        let app = makeApp(extraArguments: [
            "-pendingAppRoute", "trai://logfood",
            "--ui-test-mock-food-ai"
        ])
        app.launch()

        XCTAssertTrue(
            app.buttons["compactFoodCapture"].waitForExistence(timeout: 4)
        )

        app.buttons["Describe food"].tap()
        let descriptionField = app.descendants(matching: .any)["compactFoodDescription"].firstMatch
        XCTAssertTrue(descriptionField.waitForExistence(timeout: 4))
        captureMigrationScreen(app, name: "Glass meal description input")
        descriptionField.tap()
        descriptionField.typeText("banana yogurt bowl")
        app.buttons["compactFoodAnalyze"].tap()
        let save = app.buttons["compactFoodSave"]
        XCTAssertTrue(save.waitForExistence(timeout: 8))
        app.buttons["Adjust estimate"].tap()
        let input = app.descendants(matching: .any)["compactFoodCorrection"].firstMatch
        XCTAssertTrue(input.waitForExistence(timeout: 4))
        input.tap()
        input.typeText("add 100 calories")
        app.buttons["Update estimate"].tap()
        XCTAssertTrue(app.staticTexts["≈ 530 kcal"].waitForExistence(timeout: 8))
        XCTAssertTrue(save.isEnabled)
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
            "--seed-live-workout-perf-data",
            "--ui-test-live-workout-stress-controls"
        ])
        app.launch()

        XCTAssertTrue(app.buttons["liveWorkoutEndButton"].waitForExistence(timeout: 12))
        app.buttons["Pause"].tap()
        XCTAssertTrue(app.buttons["Resume"].waitForExistence(timeout: 3))
        app.buttons["Resume"].tap()
        XCTAssertTrue(app.buttons["Pause"].waitForExistence(timeout: 3))

        for iteration in 1...3 {
            app.buttons["liveWorkoutStressAddSetBurst"].tap()
            XCTAssertTrue(app.staticTexts["\(4 + iteration * 4) sets"].firstMatch.waitForExistence(timeout: 4))
            minimizeLiveWorkoutAndAssertBanner(in: app)
            app.otherElements["activeWorkoutBanner"].tap()
            XCTAssertTrue(app.buttons["liveWorkoutEndButton"].waitForExistence(timeout: 8))
            XCTAssertTrue(app.staticTexts["\(4 + iteration * 4) sets"].firstMatch.exists,
                          "Added sets must survive minimizing and reopening the workout")
        }
        captureMigrationScreen(app, name: "Workout after repeated mutations and reopen")
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

        XCTAssertTrue(dashboardTab.exists)
        XCTAssertTrue(traiTab.exists)
        XCTAssertTrue(workoutsTab.exists)
        XCTAssertFalse(tabBar.buttons["Profile"].exists)

        ensureTabSelected(dashboardTab, label: "Dashboard")
        assertReadiness(in: app, identifier: "dashboardRootReady", timeout: 10)
        _ = tapAndMeasureSelection(workoutsTab, in: app, label: "Workouts", readinessIdentifier: "workoutsRootReady")
        _ = tapAndMeasureSelection(traiTab, in: app, label: "Trai", readinessIdentifier: "traiRootReady")
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

        ensureTabSelected(dashboardTab, label: "Dashboard")
        _ = tapAndMeasureContentReadiness(workoutsTab, in: app, label: "Workouts", readinessIdentifier: "workoutsRootReady")
        _ = tapAndMeasureContentReadiness(traiTab, in: app, label: "Trai", readinessIdentifier: "traiRootReady")
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
            "--seed-live-workout-perf-data",
            "--ui-test-live-workout-stress-controls"
        ])
        app.launch()

        let endButton = app.buttons["liveWorkoutEndButton"]
        if !endButton.waitForExistence(timeout: 10) {
            app.terminate()
            app.launch()
        }
        XCTAssertTrue(endButton.waitForExistence(timeout: 10))

        captureMigrationScreen(app, name: "Add exercise ready")
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
        let setupChecklist = app.staticTexts["Finish setting up Trai"]
        for _ in 0..<4 where !setupChecklist.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(setupChecklist.waitForExistence(timeout: 5))
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
        app.buttons["dashboardSetupToggle"].tap()
        XCTAssertTrue(app.buttons["Create a workout plan"].exists)
        XCTAssertTrue(app.buttons["Connect Apple Health"].exists)
    }

    func testRefinedTodayAndWorkoutEntry() {
        let app = XCUIApplication()
        app.launchArguments = ["--test-persona", "consistent", "--test-persona-ai", "deterministic", "--disable-tab-prewarm", "-selectedTab", "dashboard"]
        app.launch()
        XCTAssertTrue(app.buttons["dashboardNutritionLogFood"].firstMatch.waitForExistence(timeout: 15))
        captureMigrationScreen(app, name: "Refined Today entry")
        app.tabBars.buttons["Workouts"].tap()
        XCTAssertTrue(app.buttons["workoutSection-Train"].waitForExistence(timeout: 10))
        app.buttons["workoutSection-Train"].tap()
        XCTAssertTrue(app.buttons["Start workout"].waitForExistence(timeout: 5))
        captureMigrationScreen(app, name: "Refined workout entry")
    }

    func testDashboardSectionsShowDetailsInline() {
        let app = XCUIApplication()
        app.launchArguments = ["--test-persona", "consistent", "--test-persona-ai", "deterministic", "--disable-tab-prewarm", "-selectedTab", "dashboard"]
        app.launch()
        XCTAssertTrue(app.buttons["dashboardSectionNutrition"].waitForExistence(timeout: 15))
        captureMigrationScreen(app, name: "Today contextual entry")
        app.buttons["dashboardSectionNutrition"].tap()
        captureMigrationScreen(app, name: "Nutrition page with direct logging")
        app.buttons["Nutrition options"].tap()
        app.buttons["Trends"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["dashboardNutritionTrends"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertFalse(app.sheets.firstMatch.exists)
        captureMigrationScreen(app, name: "Inline nutrition trends")
        app.buttons["dashboardSectionActivity"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["dashboardWorkoutHistory"].firstMatch.waitForExistence(timeout: 5))
        captureMigrationScreen(app, name: "Activity sessions inline")
        app.buttons["dashboardSectionWeight"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["weightInlineHistory"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Recent entries"].exists)
        XCTAssertFalse(app.buttons["See weight history"].exists)
        XCTAssertFalse(app.sheets.firstMatch.exists)
        captureMigrationScreen(app, name: "Weight history inline")
        app.swipeUp()
        let finalWeight = app.staticTexts["72.8 kg"].firstMatch
        XCTAssertTrue(finalWeight.waitForExistence(timeout: 5))
        XCTAssertTrue(finalWeight.isHittable)
        XCTAssertLessThanOrEqual(finalWeight.frame.maxY, app.tabBars.firstMatch.frame.minY,
                                 "The final history entry must scroll clear of the floating tab bar")
        captureMigrationScreen(app, name: "Weight history bottom clearance")
        app.swipeDown()
        app.buttons["Log weight"].tap()
        XCTAssertTrue(app.navigationBars["Log Weight"].waitForExistence(timeout: 5))
    }

    func testPersonaLocalLiveFoodPhotoUsesRealAIAndSavesResult() throws {
        guard ProcessInfo.processInfo.environment["RUN_PERSONA_LOCAL_LIVE_AI_UI_TEST"] == "1" else {
            throw XCTSkip("Set RUN_PERSONA_LOCAL_LIVE_AI_UI_TEST=1 with a configured local AI backend to run this paid request.")
        }

        let app = XCUIApplication()
        app.launchArguments = [
            "--test-persona", "consistent",
            "--test-persona-ai", "local-live",
            "--disable-tab-prewarm"
        ]
        if let imagePath = ProcessInfo.processInfo.environment["TRAI_TEST_FOOD_IMAGE_PATH"],
           !imagePath.isEmpty {
            app.launchArguments += ["--test-food-image-path", imagePath]
        }
        app.launch()

        let logFood = app.buttons["dashboardNutritionLogFood"].firstMatch
        XCTAssertTrue(logFood.waitForExistence(timeout: 35),
                      "Local backend authentication must finish before the dashboard appears")
        logFood.tap()

        let shutter = app.buttons["compactFoodCapture"]
        XCTAssertTrue(shutter.waitForExistence(timeout: 8))
        shutter.tap()

        let save = app.buttons["compactFoodSave"]
        XCTAssertTrue(save.waitForExistence(timeout: 90),
                      "A real AI food estimate should reach the review step")
        let name = app.textFields["compactFoodName"]
        XCTAssertTrue(name.exists)
        let mealName = name.value as? String ?? ""
        XCTAssertFalse(mealName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        XCTAssertNotEqual(mealName, "Ui Test Meal", "The local mock response must not be used")
        let kcal = app.staticTexts.matching(NSPredicate(format: "label MATCHES %@", "≈ [1-9][0-9]* kcal")).firstMatch
        XCTAssertTrue(kcal.exists, "A nonzero estimate must be visible before saving")

        let review = XCTAttachment(screenshot: app.screenshot())
        review.name = "Local live AI estimate"
        review.lifetime = .keepAlways
        add(review)
        save.tap()

        XCTAssertTrue(logFood.waitForExistence(timeout: 15))
        app.swipeLeft()
        XCTAssertTrue(app.staticTexts[mealName].firstMatch.waitForExistence(timeout: 10),
                      "The reviewed AI meal must appear in Nutrition after saving")
        let saved = XCTAttachment(screenshot: app.screenshot())
        saved.name = "Local live AI saved meal"
        saved.lifetime = .keepAlways
        add(saved)
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
            "-dashboardActivationChecklistDismissed", "NO",
            "-dashboardActivationChecklistHasLoggedFood", "NO",
            "-dashboardActivationChecklistHasWorkoutPlan", "NO",
            "-dashboardActivationChecklistHasHealthAccess", "NO",
            "-dashboardActivationChecklistHasReminders", "NO",
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

        XCTAssertTrue(app.staticTexts["What would you like to focus on?"].waitForExistence(timeout: 5))
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

        XCTAssertTrue(app.staticTexts["How active is a typical week?"].waitForExistence(timeout: 5))
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
        let skipButton = button(containing: "Start Without a Plan", in: app)
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
        let start = app.navigationBars.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.92))
        start.press(forDuration: 0.1, thenDragTo: end)
        XCTAssertTrue(waitForNonExistence(app.buttons["liveWorkoutEndButton"], timeout: 6),
                      "The workout must actually be minimized before testing Resume")
        let banner = app.otherElements["activeWorkoutBanner"]
        XCTAssertTrue(banner.waitForExistence(timeout: 8))
        let hittable = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isHittable == true"), object: banner)
        XCTAssertEqual(XCTWaiter.wait(for: [hittable], timeout: 6), .completed)
        captureMigrationScreen(app, name: "Minimized workout ready to resume")
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

        // A different screen's navigation bar is not evidence that a workout opened.
        let banner = app.otherElements["activeWorkoutBanner"]
        guard banner.waitForExistence(timeout: 3) else { return false }
        banner.tap()
        return app.buttons["liveWorkoutEndButton"].waitForExistence(timeout: max(4, timeout / 2))
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
