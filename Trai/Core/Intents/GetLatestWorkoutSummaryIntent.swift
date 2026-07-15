//
//  GetLatestWorkoutSummaryIntent.swift
//  Trai
//
//  A privacy-conscious summary of the user's latest completed workout.
//

import AppIntents
import SwiftData

/// A return-only workout snapshot. It deliberately does not conform to
/// `IndexedEntity`, so workout details never enter Spotlight's index.
struct CompletedWorkoutSummaryEntity: TransientAppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Completed Workout Summary"

    @Property(title: "Workout Name")
    var workoutName: String

    @Property(title: "Completed At")
    var completedAt: Date

    @Property(title: "Duration")
    var durationMinutes: Int

    @Property(title: "Exercises and Activities")
    var entryCount: Int

    @Property(title: "Completed Sets")
    var completedSets: Int

    @Property(title: "Active Calories")
    var activeCalories: Int?

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(workoutName)",
            subtitle: "\(durationMinutes) minutes"
        )
    }

    init() {
        workoutName = "Workout"
        completedAt = .now
        durationMinutes = 0
        entryCount = 0
        completedSets = 0
        activeCalories = nil
    }

    init(workout: LiveWorkout) {
        let stats = workout.entrySummaryStats
        workoutName = workout.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? workout.type.displayName
            : workout.name
        completedAt = workout.completedAt ?? workout.startedAt
        durationMinutes = stats.durationMinutes
        entryCount = stats.entryCount
        completedSets = stats.totalSets
        activeCalories = workout.healthKitCalories.map { Int($0.rounded()) }
    }
}

struct GetLatestWorkoutSummaryIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Latest Workout Summary"
    static let description = IntentDescription(
        "Get a summary of your most recently completed workout in Trai"
    )
    static var supportedModes: IntentModes { .background }
    static var authenticationPolicy: IntentAuthenticationPolicy { .requiresAuthentication }

    @available(iOS 27.0, *)
    static var allowedExecutionTargets: ExecutionTargets { .main }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<CompletedWorkoutSummaryEntity> {
        guard let container = TraiApp.sharedModelContainer else {
            throw WorkoutSummaryIntentError.storeUnavailable
        }

        var descriptor = FetchDescriptor<LiveWorkout>(
            predicate: #Predicate { $0.completedAt != nil },
            sortBy: [SortDescriptor(\LiveWorkout.completedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1

        let workout: LiveWorkout
        do {
            guard let completedWorkout = try container.mainContext.fetch(descriptor).first else {
                throw WorkoutSummaryIntentError.noCompletedWorkout
            }
            workout = completedWorkout
        } catch let error as WorkoutSummaryIntentError {
            throw error
        } catch {
            throw WorkoutSummaryIntentError.readFailed
        }

        let summary = CompletedWorkoutSummaryEntity(workout: workout)
        var details = ["\(summary.durationMinutes) minutes"]
        if summary.entryCount > 0 {
            let entryLabel = summary.entryCount == 1 ? "exercise or activity" : "exercises or activities"
            details.append("\(summary.entryCount) \(entryLabel)")
        }
        if summary.completedSets > 0 {
            details.append("\(summary.completedSets) completed set\(summary.completedSets == 1 ? "" : "s")")
        }
        if let calories = summary.activeCalories {
            details.append("\(calories) active calories")
        }

        let message = "Your latest completed workout was \(summary.workoutName): "
            + details.joined(separator: ", ")
            + "."
        return .result(value: summary, dialog: IntentDialog(stringLiteral: message))
    }
}

private enum WorkoutSummaryIntentError: Error, CustomLocalizedStringResourceConvertible {
    case storeUnavailable
    case noCompletedWorkout
    case readFailed

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .storeUnavailable:
            "Open Trai once so Siri can access your workout history."
        case .noCompletedWorkout:
            "You don't have a completed workout in Trai yet."
        case .readFailed:
            "Trai couldn't read your workout history right now. Please try again."
        }
    }
}
