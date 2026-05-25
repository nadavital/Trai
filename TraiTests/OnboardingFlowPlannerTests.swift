import XCTest
@testable import Trai

final class OnboardingFlowPlannerTests: XCTestCase {
    func testFirstRunOnboardingKeepsOnlyPlanCriticalSteps() {
        let steps = OnboardingFlowPlanner.steps()

        XCTAssertEqual(steps, [
            .welcome,
            .goals,
            .biometrics,
            .activity,
            .nutritionPlan,
            .workoutSetup
        ])
        XCTAssertFalse(steps.contains(.macroPreferences))
        XCTAssertFalse(steps.contains(.health))
        XCTAssertEqual(steps.last, .workoutSetup)
    }
}
