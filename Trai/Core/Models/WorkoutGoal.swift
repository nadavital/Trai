//
//  WorkoutGoal.swift
//  Trai
//

import Foundation
import SwiftData

@Model
final class WorkoutGoal {
    var id: UUID = UUID()
    var title: String = ""
    var goalKindRaw: String = GoalKind.milestone.rawValue
    var statusRaw: String = GoalStatus.active.rawValue
    var linkedWorkoutTypeRaw: String?
    var linkedActivityName: String?
    var linkedActivityTagsRaw: String = ""
    var linkedActivityKindRaw: String?
    var linkedActivityRoleRaw: String?
    var targetValue: Double?
    var targetUnit: String = ""
    var periodUnitRaw: String?
    var periodCount: Int?
    var successCriteria: String = ""
    var notes: String = ""
    var targetDate: Date?
    var checkInCadenceDays: Int?
    var baselineValue: Double?
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var completedAt: Date?
    var lastCheckInPromptAt: Date?
    var lastCelebratedAt: Date?

    init() {}

    init(
        title: String,
        goalKind: GoalKind = .milestone,
        status: GoalStatus = .active,
        linkedWorkoutType: WorkoutMode? = nil,
        linkedActivityName: String? = nil,
        linkedActivityTags: [String] = [],
        linkedActivityKind: WorkoutPlan.TrainingBlock.BlockKind? = nil,
        linkedActivityRole: WorkoutPlan.TrainingBlock.Role? = nil,
        targetValue: Double? = nil,
        targetUnit: String = "",
        periodUnit: PeriodUnit? = nil,
        periodCount: Int? = nil,
        successCriteria: String = "",
        notes: String = "",
        targetDate: Date? = nil,
        checkInCadenceDays: Int? = nil,
        baselineValue: Double? = nil
    ) {
        self.title = title
        self.goalKindRaw = goalKind.rawValue
        self.statusRaw = status.rawValue
        self.linkedWorkoutTypeRaw = linkedWorkoutType?.rawValue
        self.linkedActivityName = linkedActivityName?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.linkedActivityTags = linkedActivityTags
        self.linkedActivityKindRaw = linkedActivityKind?.rawValue
        self.linkedActivityRoleRaw = linkedActivityRole?.rawValue
        self.targetValue = targetValue
        self.targetUnit = targetUnit
        self.periodUnitRaw = periodUnit?.rawValue
        self.periodCount = periodCount
        self.successCriteria = successCriteria.trimmingCharacters(in: .whitespacesAndNewlines)
        self.notes = notes
        self.targetDate = targetDate
        self.checkInCadenceDays = checkInCadenceDays
        self.baselineValue = baselineValue
    }
}

extension WorkoutGoal {
    enum GoalKind: String, CaseIterable, Identifiable {
        case milestone = "milestone"
        case frequency = "frequency"
        case duration = "duration"
        case distance = "distance"
        case count = "count"
        case weight = "weight"

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .milestone: "Milestone"
            case .frequency: "Frequency"
            case .duration: "Duration"
            case .distance: "Distance"
            case .count: "Count"
            case .weight: "Weight"
            }
        }

        var iconName: String {
            switch self {
            case .milestone: "flag.checkered"
            case .frequency: "calendar.badge.clock"
            case .duration: "clock.badge"
            case .distance: "point.topleft.down.curvedto.point.bottomright.up"
            case .count: "number"
            case .weight: "dumbbell.fill"
            }
        }

        var supportsNumericTarget: Bool {
            self != .milestone
        }

        var usesPeriodTarget: Bool {
            self == .frequency || self == .duration || self == .distance || self == .count
        }
    }

    enum PeriodUnit: String, CaseIterable, Identifiable {
        case day = "day"
        case week = "week"
        case month = "month"

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .day: "Day"
            case .week: "Week"
            case .month: "Month"
            }
        }
    }

    enum GoalStatus: String, CaseIterable, Identifiable {
        case active = "active"
        case completed = "completed"
        case paused = "paused"

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .active: "Active"
            case .completed: "Completed"
            case .paused: "Paused"
            }
        }
    }

    var goalKind: GoalKind {
        get { GoalKind(rawValue: goalKindRaw) ?? .milestone }
        set { goalKindRaw = newValue.rawValue }
    }

    var status: GoalStatus {
        get { GoalStatus(rawValue: statusRaw) ?? .active }
        set { statusRaw = newValue.rawValue }
    }

    var linkedWorkoutType: WorkoutMode? {
        get { linkedWorkoutTypeRaw.flatMap(WorkoutMode.init(rawValue:)) }
        set { linkedWorkoutTypeRaw = newValue?.rawValue }
    }

    var periodUnit: PeriodUnit? {
        get { periodUnitRaw.flatMap(PeriodUnit.init(rawValue:)) }
        set { periodUnitRaw = newValue?.rawValue }
    }

    var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedActivityName: String? {
        let trimmed = linkedActivityName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    var linkedActivityTags: [String] {
        get {
            linkedActivityTagsRaw
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }
        set {
            linkedActivityTagsRaw = newValue
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: ",")
        }
    }

    var linkedActivityKind: WorkoutPlan.TrainingBlock.BlockKind? {
        get { linkedActivityKindRaw.flatMap(WorkoutPlan.TrainingBlock.BlockKind.init(rawValue:)) }
        set { linkedActivityKindRaw = newValue?.rawValue }
    }

    var linkedActivityRole: WorkoutPlan.TrainingBlock.Role? {
        get { linkedActivityRoleRaw.flatMap(WorkoutPlan.TrainingBlock.Role.init(rawValue:)) }
        set { linkedActivityRoleRaw = newValue?.rawValue }
    }

    var hasActivityScope: Bool {
        trimmedActivityName != nil || !linkedActivityTags.isEmpty || linkedActivityKind != nil || linkedActivityRole != nil
    }

    var trimmedNotes: String {
        notes.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedSuccessCriteria: String {
        successCriteria.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var supportingSummary: String? {
        let criteria = trimmedSuccessCriteria
        if !criteria.isEmpty {
            return criteria
        }

        let notes = trimmedNotes
        return notes.isEmpty ? nil : notes
    }

    var isActive: Bool {
        status == .active
    }

    var effectiveCheckInCadenceDays: Int {
        if let checkInCadenceDays, checkInCadenceDays > 0 {
            return checkInCadenceDays
        }

        switch goalKind {
        case .milestone:
            return 21
        case .frequency:
            return periodUnit == .month ? 28 : 14
        case .duration, .distance, .count, .weight:
            return 21
        }
    }

    var scopeSummary: String {
        var parts: [String] = []
        if let linkedWorkoutType {
            parts.append(linkedWorkoutType.displayName)
        }
        if let activityName = trimmedActivityName {
            parts.append(activityName)
        }
        if !linkedActivityTags.isEmpty {
            parts.append(linkedActivityTags.prefix(2).joined(separator: ", "))
        }
        let hasSemanticActivityScope = trimmedActivityName != nil || !linkedActivityTags.isEmpty
        if !hasSemanticActivityScope, let linkedActivityKind {
            parts.append(linkedActivityKind.displayName)
        }
        if !hasSemanticActivityScope, let linkedActivityRole {
            parts.append(linkedActivityRole.placementDisplayName)
        }
        return parts.isEmpty ? "Any session" : parts.joined(separator: " • ")
    }

    var trackingSummary: String? {
        switch goalKind {
        case .frequency:
            guard let targetValue, targetValue > 0 else { return nil }
            let roundedTarget = Int(targetValue.rounded())
            let periodLabel = periodLabelText
            return "\(roundedTarget)x per \(periodLabel)"
        case .milestone:
            let criteria = trimmedSuccessCriteria
            return criteria.isEmpty ? nil : criteria
        case .duration, .distance, .count, .weight:
            guard let targetValue, targetValue > 0 else { return nil }
            let target = formattedTargetValue(targetValue, unit: targetUnit)
            guard goalKind != .weight, periodUnit != nil else { return target }
            return "\(target) / \(periodLabelText)"
        }
    }

    var periodLabelText: String {
        let count = max(periodCount ?? 1, 1)
        let base = periodUnit ?? .week
        if count == 1 {
            return base.rawValue
        }
        return "\(count) \(base.rawValue)s"
    }

    var horizonSummary: String? {
        guard let targetDate else { return nil }
        return "By \(targetDate.formatted(date: .abbreviated, time: .omitted))"
    }

    var planSetupDeduplicationKey: String {
        let scopeParts: [String] = [
            linkedWorkoutTypeRaw?.goalNormalizedKey ?? "any",
            trimmedActivityName?.goalNormalizedKey ?? "",
            linkedActivityTags.map(\.goalNormalizedKey).filter { !$0.isEmpty }.sorted().joined(separator: ","),
            linkedActivityKindRaw?.goalNormalizedKey ?? "",
            linkedActivityRoleRaw?.goalNormalizedKey ?? ""
        ]

        let targetParts: [String] = [
            targetValue.map(Self.normalizedTargetValue) ?? "",
            targetUnit.goalNormalizedKey,
            periodUnitRaw?.goalNormalizedKey ?? "",
            periodCount.map(String.init) ?? ""
        ]

        if goalKind != .milestone {
            return ([goalKind.rawValue] + scopeParts + targetParts)
                .joined(separator: "|")
        }

        return ([goalKind.rawValue] + scopeParts + [
            trimmedTitle.goalNormalizedKey,
            trimmedSuccessCriteria.goalNormalizedKey
        ])
        .joined(separator: "|")
    }

    var hasValidTrackingCriteria: Bool {
        guard !trimmedSuccessCriteria.isEmpty else { return false }

        switch goalKind {
        case .milestone:
            return true
        case .frequency:
            return targetValue.map { $0 > 0 } == true &&
                periodUnit != nil &&
                !(targetUnit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        case .duration, .distance, .weight:
            return targetValue.map { $0 > 0 } == true &&
                !(targetUnit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        case .count:
            return targetValue.map { $0 > 0 } == true &&
                periodUnit != nil &&
                !(targetUnit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    func matches(workout: LiveWorkout) -> Bool {
        guard hasActivityScope else {
            if let linkedWorkoutType {
                return linkedWorkoutType == workout.type
            }
            return true
        }

        let activityName = trimmedActivityName?.goalNormalizedKey
        let nameMatches = activityName.map {
            Set(workout.focusAreas.map(\.goalNormalizedKey)).contains($0)
                || workout.name.goalNormalizedKey == $0
        } ?? false

        let tagMatches: Bool = {
            let tags = normalizedLinkedActivityTags
            guard !tags.isEmpty else { return false }
            let workoutTokens = Set(workout.focusAreas.map(\.goalNormalizedKey) + [workout.name.goalNormalizedKey])
            return !tags.isDisjoint(with: workoutTokens)
        }()

        if (workout.entries ?? []).contains(where: { matches(entry: $0) }) || nameMatches || tagMatches {
            return true
        }

        if trimmedActivityName == nil,
           normalizedLinkedActivityTags.isEmpty,
           linkedActivityRole == nil,
           let linkedActivityKind,
           Self.matches(workout: workout, activityKind: linkedActivityKind) {
            return true
        }

        if let linkedWorkoutType {
            return linkedWorkoutType == workout.type
        }

        return false
    }

    func matches(entry: LiveWorkoutEntry) -> Bool {
        let entryTokens = Set(
            ([entry.exerciseName, entry.activityTypeName] + entry.targetTags)
                .map(\.goalNormalizedKey)
                .filter { !$0.isEmpty }
        )

        if let activityName = trimmedActivityName?.goalNormalizedKey,
           !entryTokens.contains(activityName) {
            return false
        }

        let activityTags = normalizedLinkedActivityTags
        if !activityTags.isEmpty {
            guard !activityTags.isDisjoint(with: entryTokens) else { return false }
        }

        if let linkedActivityKind {
            let entryKind = entry.activityKind ?? WorkoutPlan.TrainingBlock.BlockKind.liveWorkoutFallbackKind(for: entry.exerciseType)
            if entryKind != linkedActivityKind {
                return false
            }
        }

        if let linkedActivityRole,
           entry.activityRole != linkedActivityRole {
            return false
        }

        return true
    }

    func matches(session: WorkoutSession) -> Bool {
        if let linkedWorkoutType, linkedWorkoutType != session.inferredWorkoutMode {
            return false
        }

        guard hasActivityScope else {
            return true
        }

        let tags = normalizedLinkedActivityTags
        if trimmedActivityName == nil,
           tags.isEmpty,
           linkedActivityRole == nil,
           let linkedActivityKind,
           Self.matches(session: session, activityKind: linkedActivityKind) {
            return true
        }

        guard let activityName = trimmedActivityName?.goalNormalizedKey else {
            guard !tags.isEmpty else { return false }
            return !tags.isDisjoint(with: session.goalMatchingTokens)
        }

        if !tags.isEmpty, !tags.isDisjoint(with: session.goalMatchingTokens) {
            return true
        }

        guard !activityName.isEmpty else {
            return false
        }

        return session.goalMatchingTokens.contains(activityName)
    }

    func markCompleted() {
        status = .completed
        completedAt = Date()
        updatedAt = Date()
    }

    func markActive() {
        status = .active
        completedAt = nil
        updatedAt = Date()
    }

    func markCheckedIn() {
        lastCheckInPromptAt = Date()
    }

    func markCelebrated() {
        lastCelebratedAt = Date()
    }

    private func formattedTargetValue(_ value: Double, unit: String) -> String {
        let trimmedUnit = unit.trimmingCharacters(in: .whitespacesAndNewlines)
        let formattedValue: String
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            formattedValue = "\(Int(value.rounded()))"
        } else {
            formattedValue = String(format: "%.1f", value)
        }
        return trimmedUnit.isEmpty ? formattedValue : "\(formattedValue) \(trimmedUnit)"
    }

    private var normalizedLinkedActivityTags: Set<String> {
        Set(linkedActivityTags.map(\.goalNormalizedKey).filter { !$0.isEmpty })
    }

    private static func matches(
        workout: LiveWorkout,
        activityKind: WorkoutPlan.TrainingBlock.BlockKind
    ) -> Bool {
        let candidates = [workout.workoutType, workout.name] + workout.focusAreas
        if candidates.contains(where: { rawValue in
            Exercise.Category.normalized(from: rawValue)?
                .userFacingEquivalent
                .liveWorkoutActivityKind == activityKind
        }) {
            return true
        }

        return WorkoutPlan.TrainingBlock.BlockKind(sessionType: workout.type) == activityKind
    }

    private static func matches(
        session: WorkoutSession,
        activityKind: WorkoutPlan.TrainingBlock.BlockKind
    ) -> Bool {
        if let exerciseKind = session.exercise?
            .exerciseCategory
            .userFacingEquivalent
            .liveWorkoutActivityKind {
            return exerciseKind == activityKind
        }

        let candidates = [
            session.healthKitWorkoutType,
            session.displayTypeName,
            session.displayName
        ] + session.semanticActivityTags

        if candidates.compactMap({ $0 }).contains(where: { rawValue in
            Exercise.Category.normalized(from: rawValue)?
                .userFacingEquivalent
                .liveWorkoutActivityKind == activityKind
        }) {
            return true
        }

        return WorkoutPlan.TrainingBlock.BlockKind(sessionType: session.inferredWorkoutMode) == activityKind
    }

    private static func normalizedTargetValue(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(Int(value.rounded()))
        }
        return String(format: "%.2f", value)
    }
}

extension String {
    var goalNormalizedKey: String {
        let scalars = trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .unicodeScalars
            .filter { CharacterSet.alphanumerics.contains($0) }
        return String(String.UnicodeScalarView(scalars))
    }
}
