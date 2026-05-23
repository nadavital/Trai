import XCTest
@testable import Trai

final class UserProfileWorkoutPlanRequestTests: XCTestCase {
    func testBuildWorkoutPlanRequestFallsBackToStoredSessionDuration() {
        let profile = UserProfile()
        profile.workoutTimePerSession = 55

        let request = profile.buildWorkoutPlanRequest()

        XCTAssertEqual(request.timePerWorkout, 55)
    }

    func testBuildWorkoutPlanRequestPrefersExplicitSessionDurationOverride() {
        let profile = UserProfile()
        profile.workoutTimePerSession = 55

        let request = profile.buildWorkoutPlanRequest(timePerWorkout: 40)

        XCTAssertEqual(request.timePerWorkout, 40)
    }

    func testOnboardingWorkoutDraftMapsMultipleFocusesToMixedRequest() {
        var draft = OnboardingWorkoutPlanDraft()
        draft.focuses = [.strength, .mobility, .climbing]
        draft.schedule = .fourDays
        draft.duration = .sixtyMinutes
        draft.equipment = .homeBasic
        draft.experience = .intermediate
        draft.constraints = [.includeCardio, .variety]
        draft.notes = "I want better pull-up strength."

        let request = draft.buildRequest(
            context: OnboardingWorkoutPlanUserContext(
                name: "Sam",
                age: 32,
                gender: .notSpecified,
                goal: .recomposition,
                activityLevel: .moderate
            )
        )

        XCTAssertEqual(request.name, "Sam")
        XCTAssertEqual(request.workoutType, .mixed)
        XCTAssertEqual(Set(request.selectedWorkoutTypes ?? []), [.strength, .flexibility])
        XCTAssertEqual(request.cardioTypes, [.anyCardio])
        XCTAssertEqual(request.customWorkoutType, "Climbing")
        XCTAssertTrue(request.requiredVisibleActivityIdentityGroups.contains { $0 == ["Climbing"] })
        XCTAssertEqual(request.availableDays, 4)
        XCTAssertEqual(request.timePerWorkout, 60)
        XCTAssertEqual(request.equipmentAccess, .homeBasic)
        XCTAssertEqual(request.experienceLevel, .intermediate)
        XCTAssertEqual(request.preferences, "Include cardio • Add variety • I want better pull-up strength.")
    }

    func testOnboardingWorkoutDraftFlexibleScheduleLeavesDaysNil() {
        var draft = OnboardingWorkoutPlanDraft()
        draft.focuses = [.strength]
        draft.schedule = .flexible
        draft.duration = .fortyFiveMinutes
        draft.equipment = .fullGym
        draft.experience = .beginner

        let request = draft.buildRequest(
            context: OnboardingWorkoutPlanUserContext(
                name: "Taylor",
                age: 29,
                gender: .female,
                goal: .buildMuscle,
                activityLevel: .light
            )
        )

        XCTAssertEqual(request.workoutType, .strength)
        XCTAssertEqual(request.selectedWorkoutTypes, [.strength])
        XCTAssertNil(request.availableDays)
        XCTAssertEqual(request.timePerWorkout, 45)
        XCTAssertEqual(request.equipmentAccess, .fullGym)
        XCTAssertEqual(request.experienceLevel, .beginner)
    }

    func testOnboardingWorkoutDraftTreatsClimbingAsNamedActivityInsteadOfCardio() {
        var draft = OnboardingWorkoutPlanDraft()
        draft.focuses = [.climbing]
        draft.schedule = .threeDays
        draft.duration = .fortyFiveMinutes

        let request = draft.buildRequest(
            context: OnboardingWorkoutPlanUserContext(
                name: "Riley",
                age: 27,
                gender: .notSpecified,
                goal: .health,
                activityLevel: .moderate
            )
        )

        XCTAssertEqual(request.workoutType, .mixed)
        XCTAssertNil(request.selectedWorkoutTypes)
        XCTAssertNil(request.cardioTypes)
        XCTAssertEqual(request.customWorkoutType, "Climbing")
        XCTAssertFalse(request.includesCardio)
        XCTAssertTrue(request.requiredVisibleActivityIdentityGroups.contains { $0 == ["Climbing"] })
    }

    func testOnboardingWorkoutDraftPreservesSportAndCustomFocusAsNamedActivity() {
        var draft = OnboardingWorkoutPlanDraft()
        draft.focuses = [.sport]
        draft.customFocus = "Pickleball"

        let request = draft.buildRequest(
            context: OnboardingWorkoutPlanUserContext(
                name: "Jordan",
                age: 35,
                gender: .notSpecified,
                goal: .health,
                activityLevel: .moderate
            )
        )

        XCTAssertEqual(request.workoutType, .mixed)
        XCTAssertNil(request.selectedWorkoutTypes)
        XCTAssertEqual(request.customWorkoutType, "Sport, Pickleball")
        XCTAssertFalse(request.includesCardio)
        XCTAssertTrue(request.requiredVisibleActivityIdentityGroups.contains { $0 == ["Sport"] })
        XCTAssertTrue(request.requiredVisibleActivityIdentityGroups.contains { $0 == ["Pickleball"] })
    }

    func testOnboardingWorkoutDraftPassesProPersonalizationAsHighPriorityContext() {
        var draft = OnboardingWorkoutPlanDraft()
        draft.focuses = [.strength, .cardio]
        draft.schedule = .threeDays
        draft.proCoachingNotes = """
        Split direction: keep strength primary.
        Workout details: add cardio only as a short finisher after one lift.
        """

        let request = draft.buildRequest(
            context: OnboardingWorkoutPlanUserContext(
                name: "Taylor",
                age: 29,
                gender: .notSpecified,
                goal: .recomposition,
                activityLevel: .moderate
            )
        )

        XCTAssertTrue(request.requestsCardioAsAccessory)
        XCTAssertTrue(request.preferences?.contains("Split direction: keep strength primary.") == true)
        XCTAssertTrue(request.specificGoals?.contains { $0.contains("Workout details") } == true)
        XCTAssertTrue(request.conversationContext?.contains {
            $0.contains("Personalization brief (highest priority)") &&
            $0.contains("add cardio only as a short finisher")
        } == true)
    }

    func testManualWorkoutDraftPreservesNonStrengthActivityIdentityInBlocks() throws {
        var draft = OnboardingWorkoutPlanDraft()
        draft.focuses = [.climbing]
        draft.schedule = .threeDays
        draft.duration = .fortyFiveMinutes
        draft.preferredSplit = .fullBody
        draft.manualDays = [
            ManualWorkoutPlanDayDraft(
                name: "Climbing Day",
                sessionType: .climbing,
                focusAreasText: "Bouldering, Grip endurance",
                selectedMuscles: []
            )
        ]

        let plan = draft.buildManualPlan(
            context: OnboardingWorkoutPlanUserContext(
                name: "Riley",
                age: 27,
                gender: .notSpecified,
                goal: .health,
                activityLevel: .moderate
            )
        )

        let template = try XCTUnwrap(plan.templates.first)
        let block = try XCTUnwrap(template.displayBlocks.first)
        XCTAssertEqual(template.sessionType, .climbing)
        XCTAssertEqual(template.focusAreas, ["bouldering", "grip endurance"])
        XCTAssertEqual(block.kind, .sportPractice)
        XCTAssertEqual(block.displayActivityName, "Bouldering")
        XCTAssertEqual(block.activityTags, ["Bouldering", "Climbing", "Grip Endurance"])
        XCTAssertEqual(block.durationMinutes, 45)
    }

    func testManualWorkoutDraftUsesCustomDayNameWhenNoActivityFocusTextExists() throws {
        var draft = OnboardingWorkoutPlanDraft()
        draft.focuses = [.cardio]
        draft.duration = .thirtyMinutes
        draft.manualDays = [
            ManualWorkoutPlanDayDraft(
                name: "Steady Ride",
                sessionType: .cardio,
                selectedMuscles: []
            )
        ]

        let plan = draft.buildManualPlan(
            context: OnboardingWorkoutPlanUserContext(
                name: "Jordan",
                age: 35,
                gender: .notSpecified,
                goal: .health,
                activityLevel: .moderate
            )
        )

        let block = try XCTUnwrap(plan.templates.first?.displayBlocks.first)
        XCTAssertEqual(block.kind, .cardio)
        XCTAssertEqual(block.displayActivityName, "Steady Ride")
        XCTAssertEqual(block.activityTags, ["Steady Ride", "Cardio"])
        XCTAssertEqual(block.detail, "30 min cardio session")
    }
}
