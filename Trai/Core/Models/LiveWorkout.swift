//
//  LiveWorkout.swift
//  Trai
//

import Foundation
import SwiftData

/// Represents an in-progress or completed workout session with detailed exercise tracking
@Model
final class LiveWorkout {
    var id: UUID = UUID()
    var name: String = ""
    var startedAt: Date = Date()
    var completedAt: Date?

    /// Workout type: "strength", "cardio", "mixed"
    var workoutType: String = "strength"

    /// Target muscle groups (comma-separated for AI context)
    /// e.g., "chest,triceps,shoulders"
    var targetMuscleGroups: String = ""

    /// Flexible focus labels for non-strength sessions, e.g. "Yoga Flow, Recovery"
    var sessionFocus: String = ""

    /// Notes added by user during workout
    var notes: String = ""

    /// HealthKit workout ID if merged with Apple Watch data
    var mergedHealthKitWorkoutID: String?

    /// Calories from HealthKit (if available)
    var healthKitCalories: Double?

    /// Average heart rate from HealthKit (if available)
    var healthKitAvgHeartRate: Double?

    /// Relationship to workout entries (exercises performed)
    @Relationship(deleteRule: .cascade, inverse: \LiveWorkoutEntry.workout)
    var entries: [LiveWorkoutEntry]?

    init() {}

    init(
        name: String,
        workoutType: WorkoutType,
        targetMuscleGroups: [MuscleGroup] = [],
        focusAreas: [String] = []
    ) {
        self.name = name
        self.workoutType = workoutType.rawValue
        self.targetMuscleGroups = targetMuscleGroups.map(\.rawValue).joined(separator: ",")
        self.focusAreas = focusAreas
    }
}

// MARK: - Workout Type

extension LiveWorkout {
    typealias WorkoutType = WorkoutMode

    var type: WorkoutType {
        get { WorkoutType(rawValue: workoutType) ?? .strength }
        set { workoutType = newValue.rawValue }
    }
}

// MARK: - Muscle Groups

extension LiveWorkout {
    nonisolated enum MuscleGroup: String, CaseIterable, Identifiable {
        case chest = "chest"
        case back = "back"
        case shoulders = "shoulders"
        case biceps = "biceps"
        case triceps = "triceps"
        case forearms = "forearms"
        case core = "core"
        case quads = "quads"
        case hamstrings = "hamstrings"
        case glutes = "glutes"
        case calves = "calves"
        case fullBody = "fullBody"

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .chest: "Chest"
            case .back: "Back"
            case .shoulders: "Shoulders"
            case .biceps: "Biceps"
            case .triceps: "Triceps"
            case .forearms: "Forearms"
            case .core: "Core"
            case .quads: "Quads"
            case .hamstrings: "Hamstrings"
            case .glutes: "Glutes"
            case .calves: "Calves"
            case .fullBody: "Full Body"
            }
        }

        var iconName: String {
            switch self {
            case .chest: "figure.arms.open"
            case .back: "figure.yoga"
            case .shoulders: "figure.arms.open"
            case .biceps, .triceps, .forearms: "figure.strengthtraining.traditional"
            case .core: "figure.core.training"
            case .quads, .hamstrings, .glutes, .calves: "figure.walk"
            case .fullBody: "figure.stand"
            }
        }

        /// Common workout split categories
        static var pushMuscles: [MuscleGroup] { [.chest, .shoulders, .triceps] }
        static var pullMuscles: [MuscleGroup] { [.back, .biceps, .forearms] }
        static var legMuscles: [MuscleGroup] { [.quads, .hamstrings, .glutes, .calves] }
        static var upperBodyMuscles: [MuscleGroup] { [.chest, .back, .shoulders, .biceps, .triceps, .forearms] }

        /// Convert to Exercise.MuscleGroup for exercise list filtering
        var toExerciseMuscleGroup: Exercise.MuscleGroup {
            switch self {
            case .chest: .chest
            case .back: .back
            case .shoulders: .shoulders
            case .biceps: .biceps
            case .triceps: .triceps
            case .core: .core
            case .fullBody: .fullBody
            // Map leg sub-groups to "legs"
            case .quads, .hamstrings, .glutes, .calves: .legs
            // Forearms maps to biceps (arm work)
            case .forearms: .biceps
            }
        }

        /// Normalize persisted/API muscle strings into app muscle groups.
        static func fromTargetString(_ raw: String) -> [MuscleGroup] {
            let token = raw
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
                .replacingOccurrences(of: "-", with: "")
                .replacingOccurrences(of: "_", with: "")
                .replacingOccurrences(of: " ", with: "")

            switch token {
            case "chest": return [.chest]
            case "back": return [.back]
            case "shoulders", "shoulder": return [.shoulders]
            case "biceps", "bicep": return [.biceps]
            case "triceps", "tricep": return [.triceps]
            case "forearms", "forearm": return [.forearms]
            case "core", "abs", "abdominals": return [.core]
            case "quads", "quad": return [.quads]
            case "hamstrings", "hamstring": return [.hamstrings]
            case "glutes", "glute": return [.glutes]
            case "calves", "calf": return [.calves]
            case "legs", "lowerbody", "lower": return legMuscles
            case "upperbody", "upper": return upperBodyMuscles
            case "arms", "arm": return [.biceps, .triceps, .forearms]
            case "cardio", "conditioning", "hiit", "intervals", "running", "cycling", "swimming", "rowing", "climbing", "walking", "mobility", "flexibility", "recovery", "zone2", "zone 2":
                return [.fullBody]
            case "fullbody": return [.fullBody]
            default:
                return []
            }
        }

        static func fromTargetStrings(_ rawGroups: [String]) -> [MuscleGroup] {
            var groups: [MuscleGroup] = []
            var seen: Set<MuscleGroup> = []

            for raw in rawGroups {
                for group in fromTargetString(raw) where !seen.contains(group) {
                    groups.append(group)
                    seen.insert(group)
                }
            }

            if groups.isEmpty {
                return [.fullBody]
            }

            if groups.count > 1 {
                return groups.filter { $0 != .fullBody }
            }

            return groups
        }
    }

    var muscleGroups: [MuscleGroup] {
        get {
            guard !targetMuscleGroups.isEmpty else { return [] }
            return MuscleGroup.fromTargetStrings(
                targetMuscleGroups
                    .split(separator: ",")
                    .map(String.init)
            )
        }
        set {
            targetMuscleGroups = newValue.map(\.rawValue).joined(separator: ",")
        }
    }

    var focusAreas: [String] {
        get {
            sessionFocus
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }
        set {
            sessionFocus = newValue
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: ",")
        }
    }

    var displayFocusSummary: String {
        let displayAreas = displayFocusAreas
        if !displayAreas.isEmpty {
            return displayAreas.joined(separator: " • ")
        }
        let muscles = muscleGroups.map(\.displayName)
        return muscles.isEmpty ? type.displayName : muscles.joined(separator: " • ")
    }

    var displayFocusAreas: [String] {
        var seen: Set<String> = []
        let explicitAreas: [String] = focusAreas.compactMap { focus in
            let trimmed = focus.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }

            let displayName = Exercise.Category.allCases.first { category in
                let key = trimmed.goalNormalizedKey
                return category.rawValue.goalNormalizedKey == key || category.displayName.goalNormalizedKey == key
            }?.displayName ?? trimmed
            let key = displayName.goalNormalizedKey
            guard seen.insert(key).inserted else { return nil }
            return displayName
        }

        if !explicitAreas.isEmpty {
            return explicitAreas
        }

        return derivedActivityFocusAreas(seen: &seen)
    }

    private func derivedActivityFocusAreas(seen: inout Set<String>) -> [String] {
        (entries ?? [])
            .filter { !$0.isStrength && !$0.isPlannedActivityGuidance }
            .compactMap { entry in
                let exerciseName = entry.exerciseName.trimmingCharacters(in: .whitespacesAndNewlines)
                let activityName = entry.activityTypeName.trimmingCharacters(in: .whitespacesAndNewlines)
                let title = preferredActivityFocusName(
                    exerciseName: exerciseName,
                    activityName: activityName
                )
                let key = title.goalNormalizedKey
                guard !title.isEmpty, !key.isEmpty, seen.insert(key).inserted else { return nil }
                return title
            }
    }

    private func preferredActivityFocusName(exerciseName: String, activityName: String) -> String {
        let activityKey = activityName.goalNormalizedKey
        let exerciseKey = exerciseName.goalNormalizedKey
        if !activityName.isEmpty,
           activityKey != exerciseKey,
           !Self.broadActivityFocusKeys.contains(activityKey) {
            return activityName
        }
        return exerciseName.isEmpty ? activityName : exerciseName
    }

    private static let broadActivityFocusKeys: Set<String> = {
        let categories = Exercise.Category.allCases.flatMap { category in
            [category.rawValue, category.displayName]
        }
        let blockKinds = WorkoutPlan.TrainingBlock.BlockKind.allCases.flatMap { kind in
            [kind.rawValue, kind.displayName]
        }
        return Set((categories + blockKinds + ["activity", "workout", "custom"])
            .map(\.goalNormalizedKey)
            .filter { !$0.isEmpty })
    }()

    var trimmedNotes: String {
        notes.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var traiReviewPrompt: String {
        var prompt = "Can you review my \(name) workout from \(startedAt.formatted(date: .abbreviated, time: .shortened))?"

        var details: [String] = [type.displayName.lowercased()]

        if !displayFocusSummary.isEmpty {
            details.append("focus \(displayFocusSummary)")
        }

        let durationMinutes = Int(duration / 60)
        if durationMinutes > 0 {
            details.append("duration \(formattedDuration)")
        }

        let loggedEntryCount = entrySummaryStats.entryCount
        if loggedEntryCount > 0 {
            details.append("\(loggedEntryCount) logged \(loggedEntryCount == 1 ? "entry" : "entries")")
        }

        if let healthKitCalories, healthKitCalories > 0 {
            details.append("\(Int(healthKitCalories)) kcal")
        }

        if !details.isEmpty {
            prompt += " It was a \(details.joined(separator: ", "))."
        }

        let activityDetails = (entries ?? [])
            .filter { ($0.isCardio || $0.isGeneralActivity) && $0.hasExercisePreferenceSignal }
            .sorted { $0.orderIndex < $1.orderIndex }
            .prefix(4)
            .map { entry in
                var parts: [String] = [entry.exerciseName]
                if let role = entry.activityRole?.reviewPromptDisplayRole {
                    parts.append(role.placementDisplayName.lowercased())
                }
                parts.append(contentsOf: entry.traiActivitySummarySegments())
                let noteSummary = entry.activityReviewNoteSummary
                if !noteSummary.isEmpty {
                    parts.append("notes \(noteSummary)")
                }
                return parts.joined(separator: " • ")
            }

        if !activityDetails.isEmpty {
            prompt += " Activity blocks: \(activityDetails.joined(separator: "; "))."
        }

        if !trimmedNotes.isEmpty {
            prompt += " I added these notes: \(trimmedNotes)."
        }

        prompt += " Tell me what this says about my progress and what I should focus on next."
        return prompt
    }
}

private extension LiveWorkoutEntry {
    var activityReviewNoteSummary: String {
        var notes: [String] = []
        let entryNote = self.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        if !entryNote.isEmpty {
            notes.append(entryNote)
        }

        let segmentNotes = activitySegments
            .filter(\.hasLoggedData)
            .compactMap { segment -> String? in
                let note = segment.notes.trimmingCharacters(in: .whitespacesAndNewlines)
                return note.isEmpty ? nil : note
            }

        for note in segmentNotes where !notes.contains(note) {
            notes.append(note)
        }

        return notes.prefix(3).joined(separator: "; ")
    }
}

private extension WorkoutPlan.TrainingBlock.Role {
    var reviewPromptDisplayRole: WorkoutPlan.TrainingBlock.Role? {
        switch self {
        case .warmup, .finisher, .cooldown:
            return self
        case .main, .accessory, .custom:
            return nil
        }
    }
}

// MARK: - Computed Properties

extension LiveWorkout {
    struct EntrySummaryStats {
        let strengthEntryCount: Int
        let activityEntryCount: Int
        let loggedActivityCount: Int
        let totalSets: Int
        let activityMetricSegments: [String]
        let durationMinutes: Int

        var entryCount: Int {
            strengthEntryCount + activityEntryCount
        }
    }

    var entrySummaryStats: EntrySummaryStats {
        let entries = entries ?? []
        let strengthEntryCount = entries.filter { $0.isStrength && $0.hasExercisePreferenceSignal }.count
        let activityEntryCount = entries.filter(\.isLoggedActivity).count
        let loggedActivityCount = entries.filter(\.isLoggedActivity).count
        let totalSets = entries.reduce(0) { total, entry in
            total + (entry.completedSets?.count ?? 0)
        }
        let activityMetricSegments = Self.activityMetricSegments(for: entries.filter(\.isLoggedActivity))
        let durationMinutes = Int(duration / 60)

        return EntrySummaryStats(
            strengthEntryCount: strengthEntryCount,
            activityEntryCount: activityEntryCount,
            loggedActivityCount: loggedActivityCount,
            totalSets: totalSets,
            activityMetricSegments: activityMetricSegments,
            durationMinutes: durationMinutes
        )
    }

    private static func activityMetricSegments(for entries: [LiveWorkoutEntry]) -> [String] {
        var totals: [String: Int] = [:]
        for entry in entries {
            let loggedSegments = entry.activitySegments.filter(\.hasLoggedData)
            let countTotal = loggedSegments
                .compactMap(\.reps)
                .filter { $0 > 0 }
                .reduce(0, +)
            if countTotal > 0 {
                totals[activityCountMetricLabel(for: entry), default: 0] += countTotal
            } else if loggedSegments.count > 1 {
                totals[activitySegmentMetricLabel(for: entry), default: 0] += loggedSegments.count
            }
        }

        return totals
            .sorted { lhs, rhs in
                let lhsRank = activityMetricSortRank(lhs.key)
                let rhsRank = activityMetricSortRank(rhs.key)
                if lhsRank != rhsRank {
                    return lhsRank < rhsRank
                }
                if lhs.value != rhs.value {
                    return lhs.value > rhs.value
                }
                return lhs.key < rhs.key
            }
            .map { label, value in
                "\(value) \(metricName(for: value, pluralLabel: label))"
            }
    }

    private static func activitySegmentMetricLabel(for entry: LiveWorkoutEntry) -> String {
        let category = entry.resolvedActivityCategory
        switch category {
        case .conditioning:
            return "rounds"
        default:
            return "segments"
        }
    }

    private static func activityCountMetricLabel(for entry: LiveWorkoutEntry) -> String {
        let category = entry.resolvedActivityCategory
        switch category {
        case .sportPractice:
            return "attempts"
        case .conditioning:
            return "rounds"
        case .mobility, .recovery:
            return "reps"
        default:
            return "reps"
        }
    }

    private static func activityMetricSortRank(_ label: String) -> Int {
        switch label {
        case "attempts": return 0
        case "rounds": return 1
        case "reps": return 2
        case "segments": return 3
        default: return 4
        }
    }

    private static func metricName(for value: Int, pluralLabel: String) -> String {
        guard value == 1 else { return pluralLabel }
        if pluralLabel.hasSuffix("s") {
            return String(pluralLabel.dropLast())
        }
        return pluralLabel
    }

    var historySummarySegments: [String] {
        let stats = entrySummaryStats
        var segments: [String] = []

        if stats.strengthEntryCount > 0 {
            segments.append("\(stats.strengthEntryCount) \(stats.strengthEntryCount == 1 ? "exercise" : "exercises")")
        }

        if stats.activityEntryCount > 0 {
            segments.append("\(stats.activityEntryCount) \(stats.activityEntryCount == 1 ? "activity" : "activities")")
        }

        segments.append(contentsOf: stats.activityMetricSegments.prefix(2))

        if stats.totalSets > 0 {
            segments.append("\(stats.totalSets) \(stats.totalSets == 1 ? "set" : "sets")")
        }

        if stats.durationMinutes > 0 {
            segments.append("\(stats.durationMinutes) min")
        }

        if let calories = healthKitCalories {
            segments.append("\(Int(calories)) kcal")
        }

        return segments
    }

    /// Whether the workout is still in progress
    var isInProgress: Bool {
        completedAt == nil
    }

    /// Duration of the workout
    var duration: TimeInterval {
        let endTime = completedAt ?? Date()
        return endTime.timeIntervalSince(startedAt)
    }

    /// Formatted duration string
    var formattedDuration: String {
        let minutes = Int(duration / 60)
        if minutes < 60 {
            return "\(minutes) min"
        } else {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            return "\(hours)h \(remainingMinutes)m"
        }
    }

    /// Total number of sets completed
    var totalSets: Int {
        entries?.reduce(0) { total, entry in
            total + (entry.completedSets?.count ?? 0)
        } ?? 0
    }

    /// Total volume (weight × reps) for strength exercises
    var totalVolume: Double {
        entries?.reduce(0) { total, entry in
            total + entry.totalVolume
        } ?? 0
    }
}
