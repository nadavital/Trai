import XCTest
@testable import Trai

final class TraiCoachContextAssemblerTests: XCTestCase {
    func testAssembleAddsNutritionPlanActionForWeightChangeTrigger() {
        let context = makeContext(
            planReviewTrigger: "weight_change",
            planReviewDaysSince: 45,
            weightRecentRangeKg: 2.6
        )

        let packet = TraiCoachContextAssembler.assemble(
            patternProfile: .empty,
            activeSignals: [],
            context: context
        )

        XCTAssertTrue(packet.suggestedActions.contains("Review Nutrition Plan"))
    }

    func testAssembleRanksReminderCandidatesByScoreThenTime() {
        let candidates = [
            TraiCoachReminderCandidate(id: "a", title: "Hydrate", time: "09:30 AM", hour: 9, minute: 30),
            TraiCoachReminderCandidate(id: "b", title: "Stretch", time: "08:15 AM", hour: 8, minute: 15),
            TraiCoachReminderCandidate(id: "c", title: "Walk", time: "10:00 AM", hour: 10, minute: 0)
        ]

        let context = makeContext(
            pendingReminderCandidates: candidates,
            pendingReminderCandidateScores: [
                "a": 0.9,
                "b": 0.9,
                "c": 0.4
            ]
        )

        let packet = TraiCoachContextAssembler.assemble(
            patternProfile: .empty,
            activeSignals: [],
            context: context
        )

        XCTAssertEqual(packet.suggestedActions.count, 2)
        XCTAssertEqual(packet.suggestedActions[0], "Complete Stretch at 08:15 AM")
        XCTAssertEqual(packet.suggestedActions[1], "Complete Hydrate at 09:30 AM")
    }

    func testAssemblePrioritizesWorkoutGoalWhenWorkoutNotStarted() {
        let context = TraiCoachInputContext(
            now: Date(timeIntervalSince1970: 1_736_208_000),
            hasWorkoutToday: false,
            hasActiveWorkout: false,
            caloriesConsumed: 0,
            calorieGoal: 2_000,
            proteinConsumed: 0,
            proteinGoal: 120,
            readyMuscleCount: 4,
            recommendedWorkoutName: nil,
            workoutWindowStartHour: 6,
            workoutWindowEndHour: 22,
            activeSignals: [],
            tomorrowWorkoutMinutes: 45,
            trend: nil,
            patternProfile: .empty,
            contextPacket: nil
        )

        let packet = TraiCoachContextAssembler.assemble(
            patternProfile: .empty,
            activeSignals: [],
            context: context
        )

        XCTAssertEqual(packet.goal, "Complete your workout in today's available window")
    }

    private func makeContext(
        planReviewTrigger: String? = nil,
        planReviewDaysSince: Int? = nil,
        weightRecentRangeKg: Double? = nil,
        pendingReminderCandidates: [TraiCoachReminderCandidate] = [],
        pendingReminderCandidateScores: [String: Double] = [:]
    ) -> TraiCoachInputContext {
        TraiCoachInputContext(
            now: Date(timeIntervalSince1970: 1_736_208_000),
            hasWorkoutToday: true,
            hasActiveWorkout: false,
            caloriesConsumed: 0,
            calorieGoal: 2_000,
            proteinConsumed: 0,
            proteinGoal: 0,
            readyMuscleCount: 4,
            recommendedWorkoutName: nil,
            workoutWindowStartHour: 6,
            workoutWindowEndHour: 22,
            activeSignals: [],
            tomorrowWorkoutMinutes: 45,
            trend: nil,
            patternProfile: .empty,
            weightLoggedThisWeek: true,
            weightRecentRangeKg: weightRecentRangeKg,
            planReviewTrigger: planReviewTrigger,
            planReviewDaysSince: planReviewDaysSince,
            pendingReminderCandidates: pendingReminderCandidates,
            pendingReminderCandidateScores: pendingReminderCandidateScores,
            contextPacket: nil
        )
    }
}
