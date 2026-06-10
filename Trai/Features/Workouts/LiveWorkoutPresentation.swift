//
//  LiveWorkoutPresentation.swift
//  Trai
//
//  Stable presentation item for opening a live workout surface.
//

import SwiftUI

struct LiveWorkoutPresentation: Identifiable {
    let id: UUID
    let workout: LiveWorkout
    let template: WorkoutPlan.WorkoutTemplate?
    let finishOnPresentation: Bool

    init(
        workout: LiveWorkout,
        template: WorkoutPlan.WorkoutTemplate? = nil,
        finishOnPresentation: Bool = false,
        id: UUID? = nil
    ) {
        // Regular opens must keep the workout id stable across SwiftData insertion/query refreshes.
        // Finish requests intentionally get a fresh id so tapping End can force a new presentation.
        self.id = id ?? (finishOnPresentation ? UUID() : workout.id)
        self.workout = workout
        self.template = template
        self.finishOnPresentation = finishOnPresentation
    }
}

struct LiveWorkoutPresentationAction {
    var present: (LiveWorkout, WorkoutPlan.WorkoutTemplate?) -> Void = { _, _ in }

    func callAsFunction(
        workout: LiveWorkout,
        template: WorkoutPlan.WorkoutTemplate? = nil
    ) {
        present(workout, template)
    }
}

private struct LiveWorkoutPresentationActionKey: EnvironmentKey {
    static let defaultValue = LiveWorkoutPresentationAction()
}

extension EnvironmentValues {
    var presentLiveWorkout: LiveWorkoutPresentationAction {
        get { self[LiveWorkoutPresentationActionKey.self] }
        set { self[LiveWorkoutPresentationActionKey.self] = newValue }
    }
}
