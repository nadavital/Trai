//
//  StartWorkoutIntent.swift
//  Trai
//
//  App Intent for starting a workout
//

import AppIntents
import SwiftData

/// Intent for starting a workout (opens app to workout view)
struct StartWorkoutIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Workout"
    static let description = IntentDescription("Start a new workout session")

    @Parameter(title: "Workout", default: nil)
    var workout: WorkoutNameEntity?

    /// Workout setup always continues in Trai's foreground UI.
    static var supportedModes: IntentModes { .foreground(.immediate) }

    @available(iOS 27.0, *)
    static var allowedExecutionTargets: ExecutionTargets { .main }

    static var parameterSummary: some ParameterSummary {
        Summary("Start \(\.$workout) workout")
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        let templateID = workout.flatMap { UUID(uuidString: $0.id) }
        let templateName = workout?.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let route = AppRoute.workout(
            templateID: templateID,
            templateName: (templateName?.isEmpty == false) ? templateName : nil
        )
        PendingAppRouteStore.setPendingRoute(route)

        if let container = TraiApp.sharedModelContainer {
            BehaviorTracker(modelContext: container.mainContext).record(
                actionKey: BehaviorActionKey.startWorkout,
                domain: .workout,
                surface: .intent,
                outcome: .opened,
                metadata: [
                    "source": "start_workout_intent",
                    "template_name": templateName ?? ""
                ]
            )
        }

        return .result()
    }
}

// MARK: - Workout Name Entity

/// Entity for workout template names (enables Siri to suggest workouts)
struct WorkoutNameEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Workout"
    static let defaultQuery = WorkoutNameQuery()

    var id: String
    var name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

/// Query for workout names from user's workout plan
struct WorkoutNameQuery: EntityStringQuery {
    @MainActor
    func entities(for identifiers: [String]) async throws -> [WorkoutNameEntity] {
        guard let container = TraiApp.sharedModelContainer else { return [] }
        let context = container.mainContext

        let profileDescriptor = FetchDescriptor<UserProfile>()
        guard let profile = try? context.fetch(profileDescriptor).first,
              let plan = profile.workoutPlan else { return [] }

        return plan.templates
            .filter { identifiers.contains($0.id.uuidString) }
            .map { WorkoutNameEntity(id: $0.id.uuidString, name: $0.name) }
    }

    @MainActor
    func suggestedEntities() async throws -> [WorkoutNameEntity] {
        guard let container = TraiApp.sharedModelContainer else { return [] }
        let context = container.mainContext

        let profileDescriptor = FetchDescriptor<UserProfile>()
        guard let profile = try? context.fetch(profileDescriptor).first,
              let plan = profile.workoutPlan else { return [] }

        return plan.templates.map { WorkoutNameEntity(id: $0.id.uuidString, name: $0.name) }
    }

    @MainActor
    func entities(matching string: String) async throws -> [WorkoutNameEntity] {
        let candidates = try await suggestedEntities()
        let query = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return candidates }

        return candidates.filter {
            $0.name.localizedStandardContains(query)
        }
    }

    @MainActor
    func defaultResult() async -> WorkoutNameEntity? {
        nil
    }
}
