import XCTest
@testable import Trai

@MainActor
final class WorkoutArtworkTests: XCTestCase {
    private func template(_ mode: WorkoutMode, focus: [String]) -> WorkoutPlan.WorkoutTemplate {
        .init(name: "Session", sessionType: mode, focusAreas: focus, targetMuscleGroups: [],
              exercises: [], estimatedDurationMinutes: 30, order: 0)
    }
    func testArtworkRequiresMatchingActivityEvidence() {
        XCTAssertEqual(WorkoutTemplateArtwork.activityKey(for: template(.cardio, focus: ["cycling"])), "Cycling")
        XCTAssertEqual(WorkoutTemplateArtwork.activityKey(for: template(.cardio, focus: ["running"])), "Footwear")
        XCTAssertEqual(WorkoutTemplateArtwork.activityKey(for: template(.mobility, focus: [])), "Mobility")
        XCTAssertEqual(WorkoutTemplateArtwork.activityKey(for: template(.custom, focus: [])), "Custom")
        XCTAssertNil(WorkoutTemplateArtwork.activityKey(for: template(.cardio, focus: [])))
        XCTAssertNil(WorkoutTemplateArtwork.activityKey(for: template(.cardio, focus: ["swimming"])))
    }
    func testLowerUsesPreservedBarbellIdentity() {
        XCTAssertEqual(WorkoutSplitIdentity.resolve(name: "Lower Power", muscleTargets: ["quads"]), .lower)
        XCTAssertEqual(WorkoutSplitIdentity.resolve(name: "Legs", muscleTargets: []), .legs)
    }
}
