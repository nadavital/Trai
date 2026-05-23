//
//  ExerciseHistory.swift
//  Trai
//

import Foundation
import SwiftData

/// Tracks per-exercise progress over time for analytics and PR tracking
@Model
final class ExerciseHistory {
    var id: UUID = UUID()

    /// Reference to the exercise by ID (not a relationship for CloudKit compatibility)
    var exerciseId: UUID?

    /// Exercise name (stored for display, in case exercise is deleted)
    var exerciseName: String = ""

    /// When this entry was recorded
    var performedAt: Date = Date()

    /// Best set weight in kg
    var bestSetWeightKg: Double = 0

    /// Best set weight in lbs (pre-computed for clean display)
    var bestSetWeightLbs: Double = 0

    /// Best set reps
    var bestSetReps: Int = 0

    /// Total volume (weight × reps across all sets)
    var totalVolume: Double = 0

    /// Total sets completed
    var totalSets: Int = 0

    /// Total reps across all sets
    var totalReps: Int = 0

    /// Estimated one rep max (calculated at time of workout)
    var estimatedOneRepMax: Double?

    /// Reference to the source workout entry
    var sourceWorkoutEntryId: UUID?

    /// User-facing activity type for non-strength and mixed tracking contexts.
    var activityTypeNameRaw: String = ""

    /// Broad fallback kind copied from the live workout entry.
    var activityKindRaw: String = ""

    /// Comma-separated target tags copied from the live workout entry.
    var activityTagsRaw: String = ""

    /// Comma-separated tracking fields copied from the live workout entry.
    var trackingFieldsRaw: String = ""

    /// Logged duration for non-strength activity entries.
    var durationSeconds: Int = 0

    /// Logged distance for non-strength activity entries.
    var distanceMeters: Double = 0

    /// Rep pattern as comma-separated values (e.g., "12,10,8")
    var repPattern: String?

    /// Weight pattern as comma-separated values (e.g., "60,70,80")
    var weightPattern: String?

    init() {}

    init(from entry: LiveWorkoutEntry, performedAt: Date = Date()) {
        update(from: entry, performedAt: performedAt)
    }

    func update(from entry: LiveWorkoutEntry, performedAt: Date = Date()) {
        self.exerciseId = entry.exerciseId
        self.exerciseName = entry.exerciseName
        self.performedAt = performedAt
        self.sourceWorkoutEntryId = entry.id
        self.activityTypeName = entry.activityTypeName
        self.activityKind = entry.activityKind ?? WorkoutPlan.TrainingBlock.BlockKind.liveWorkoutFallbackKind(for: entry.exerciseType)
        self.activityTags = entry.targetTags
        self.trackingFields = entry.trackingFields
        self.durationSeconds = entry.trackedDurationSeconds
        self.distanceMeters = entry.trackedDistanceMeters

        if entry.isStrength {
            updateStrengthMetrics(from: entry)
        } else {
            updateActivityMetrics(from: entry)
        }
    }

    private func updateStrengthMetrics(from entry: LiveWorkoutEntry) {
        if let best = entry.bestSet {
            // Use pre-computed clean values from SetData
            self.bestSetWeightKg = WeightUtility.round(best.weightKg, unit: .kg)
            self.bestSetWeightLbs = WeightUtility.round(best.weightLbs, unit: .lbs)
            self.bestSetReps = best.reps
        } else {
            self.bestSetWeightKg = 0
            self.bestSetWeightLbs = 0
            self.bestSetReps = 0
        }

        self.totalVolume = entry.totalVolume
        self.totalSets = entry.completedSets?.count ?? 0
        self.totalReps = entry.totalReps
        self.estimatedOneRepMax = entry.estimatedOneRepMax

        // Store rep and weight patterns from completed sets
        if let completedSets = entry.completedSets, !completedSets.isEmpty {
            self.repPattern = completedSets.map { "\($0.reps)" }.joined(separator: ",")
            self.weightPattern = completedSets.map { set -> String in
                let rounded = WeightUtility.round(set.weightKg, unit: .kg)
                return String(format: "%.1f", rounded)
            }.joined(separator: ",")
        } else {
            self.repPattern = nil
            self.weightPattern = nil
        }
    }

    private func updateActivityMetrics(from entry: LiveWorkoutEntry) {
        let loggedSegments = entry.activitySegments.filter(\.hasLoggedData)
        let segmentWeights = loggedSegments
            .compactMap(\.weightKg)
            .filter { $0 > 0 }
        let segmentReps = loggedSegments
            .compactMap(\.reps)
            .filter { $0 > 0 }

        self.bestSetWeightKg = segmentWeights.max() ?? 0
        self.bestSetWeightLbs = bestSetWeightKg > 0
            ? WeightUtility.round(bestSetWeightKg * WeightUtility.kgToLbs, unit: .lbs)
            : 0
        self.bestSetReps = segmentReps.max() ?? 0
        self.totalVolume = 0
        self.totalSets = loggedSegments.count
        self.totalReps = segmentReps.reduce(0, +)
        self.estimatedOneRepMax = nil
        self.repPattern = segmentReps.isEmpty ? nil : segmentReps.map(String.init).joined(separator: ",")
        self.weightPattern = segmentWeights.isEmpty ? nil : segmentWeights.map { weightKg in
            let rounded = WeightUtility.round(weightKg, unit: .kg)
            return String(format: "%.1f", rounded)
        }.joined(separator: ",")
    }

    /// Get rep pattern as array of integers
    var repPatternArray: [Int] {
        guard let pattern = repPattern else { return [] }
        return pattern.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
    }

    /// Get weight pattern as array of doubles
    var weightPatternArray: [Double] {
        guard let pattern = weightPattern else { return [] }
        return pattern.split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
    }
}

// MARK: - Computed Properties

extension ExerciseHistory {
    var activityTypeName: String {
        get { activityTypeNameRaw.trimmingCharacters(in: .whitespacesAndNewlines) }
        set { activityTypeNameRaw = newValue.trimmingCharacters(in: .whitespacesAndNewlines) }
    }

    var activityKind: WorkoutPlan.TrainingBlock.BlockKind? {
        get {
            let rawValue = activityKindRaw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !rawValue.isEmpty else { return nil }
            return WorkoutPlan.TrainingBlock.BlockKind(rawValue: rawValue)
        }
        set {
            activityKindRaw = newValue?.rawValue ?? ""
        }
    }

    var activityTags: [String] {
        get {
            activityTagsRaw
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }
        set {
            activityTagsRaw = newValue
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: ",")
        }
    }

    var trackingFields: [Exercise.TrackingField] {
        get {
            trackingFieldsRaw
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .compactMap(Exercise.TrackingField.init(rawValue:))
        }
        set {
            trackingFieldsRaw = newValue
                .map(\.rawValue)
                .joined(separator: ",")
        }
    }

    var semanticActivityTokens: Set<String> {
        Set(
            ([exerciseName, activityTypeName, activityKind?.displayName ?? ""] + activityTags)
                .map(\.goalNormalizedKey)
                .filter { !$0.isEmpty }
        )
    }

    var hasStrengthMetrics: Bool {
        let isStrengthRecord = activityKind == .strength || (
            activityKind == nil &&
            durationSeconds == 0 &&
            distanceMeters == 0
        )
        guard isStrengthRecord else { return false }
        return bestSetWeightKg > 0 || bestSetReps > 0 || totalVolume > 0 || totalSets > 0 || totalReps > 0
    }

    var hasActivityMetrics: Bool {
        !hasStrengthMetrics && (
            durationSeconds > 0 ||
            distanceMeters > 0 ||
            totalSets > 0 ||
            totalReps > 0
        )
    }

    func suggestionSummary(usesMetricWeight: Bool) -> String? {
        if hasActivityMetrics {
            var parts: [String] = []
            if durationSeconds > 0 {
                parts.append(Self.formatDuration(seconds: durationSeconds))
            }
            if distanceMeters > 0 {
                parts.append(Self.formatDistance(meters: distanceMeters))
            }
            if totalReps > 0 {
                parts.append("\(totalReps) \(activityCountLabel(for: totalReps))")
            } else if totalSets > 0 {
                parts.append("\(totalSets) \(activitySegmentLabel(for: totalSets))")
            }
            return parts.isEmpty ? nil : parts.prefix(2).joined(separator: " • ")
        }

        guard bestSetWeightKg > 0, bestSetReps > 0 else { return nil }
        let unit = WeightUnit(usesMetric: usesMetricWeight)
        let displayWeight = WeightUtility.displayInt(bestSetWeightKg, displayUnit: unit)
        return "\(displayWeight) \(unit.symbol) \u{00D7} \(bestSetReps)"
    }

    private func activityCountLabel(for value: Int) -> String {
        let label: String
        switch activityKind {
        case .sportPractice, .skill:
            label = "attempt"
        case .conditioning:
            label = "round"
        default:
            label = "rep"
        }
        return value == 1 ? label : "\(label)s"
    }

    private func activitySegmentLabel(for value: Int) -> String {
        let label = activityKind == .conditioning ? "round" : "segment"
        return value == 1 ? label : "\(label)s"
    }

    private static func formatDuration(seconds: Int) -> String {
        let minutes = seconds / 60
        if minutes >= 60 {
            let hours = minutes / 60
            let remainder = minutes % 60
            return remainder > 0 ? "\(hours)h \(remainder)m" : "\(hours)h"
        }
        return "\(minutes)m"
    }

    private static func formatDistance(meters: Double) -> String {
        if meters >= 1000 {
            return String(format: "%.1f km", meters / 1000)
        }
        return "\(Int(meters.rounded())) m"
    }

    static func records(
        from workout: LiveWorkout,
        performedAt: Date? = nil
    ) -> [ExerciseHistory] {
        guard let entries = workout.entries else { return [] }
        let date = performedAt ?? workout.completedAt ?? workout.startedAt
        return entries.compactMap { entry in
            guard entry.hasExercisePreferenceSignal else { return nil }
            return ExerciseHistory(from: entry, performedAt: date)
        }
    }

    static func recordsToInsert(
        from workout: LiveWorkout,
        existingHistories: [ExerciseHistory],
        performedAt: Date? = nil
    ) -> [ExerciseHistory] {
        let candidateRecords = records(from: workout, performedAt: performedAt)
        guard !candidateRecords.isEmpty else { return [] }

        let existingSourceEntryIDs = Set(existingHistories.compactMap(\.sourceWorkoutEntryId))
        let legacyHistoriesByExercise = Dictionary(
            grouping: existingHistories.filter { $0.sourceWorkoutEntryId == nil },
            by: \.exerciseName
        )

        return candidateRecords.filter { record in
            if let sourceWorkoutEntryId = record.sourceWorkoutEntryId,
               existingSourceEntryIDs.contains(sourceWorkoutEntryId) {
                return false
            }

            let legacyMatches = legacyHistoriesByExercise[record.exerciseName] ?? []
            return !legacyMatches.contains { existing in
                abs(existing.performedAt.timeIntervalSince(record.performedAt)) <= 60
            }
        }
    }

    /// Best set volume (weight × reps)
    var bestSetVolume: Double {
        bestSetWeightKg * Double(bestSetReps)
    }

    /// Normalized session volume to make records comparable across different set counts.
    /// Using per-set volume prevents one-off high-set sessions from permanently dominating PRs.
    var volumePerSet: Double {
        let setCount = max(totalSets, 1)
        return totalVolume / Double(setCount)
    }

    /// Returns the volume metric value using the selected PR mode.
    func volumeValue(for mode: UserProfile.VolumePRMode) -> Double {
        switch mode {
        case .perSet:
            return volumePerSet
        case .totalVolume:
            return totalVolume
        }
    }

    /// Formatted date
    var formattedDate: String {
        performedAt.formatted(date: .abbreviated, time: .omitted)
    }

    /// Get clean weight in user's preferred unit
    func displayWeight(usesMetric: Bool) -> Double {
        if usesMetric {
            return bestSetWeightKg
        } else {
            // Use stored lbs if available, otherwise compute
            return bestSetWeightLbs > 0 ? bestSetWeightLbs : WeightUtility.round(bestSetWeightKg * WeightUtility.kgToLbs, unit: .lbs)
        }
    }

    /// Get formatted weight string in user's preferred unit
    func formattedWeight(usesMetric: Bool, showUnit: Bool = true) -> String {
        let value = displayWeight(usesMetric: usesMetric)
        let unit = usesMetric ? "kg" : "lbs"
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return showUnit ? "\(Int(value)) \(unit)" : "\(Int(value))"
        }
        return showUnit ? String(format: "%.1f %@", value, unit) : String(format: "%.1f", value)
    }
}

// MARK: - Analytics Helpers

extension ExerciseHistory {
    /// Calculate progress between two history entries
    static func progress(from previous: ExerciseHistory, to current: ExerciseHistory) -> ProgressDelta {
        ProgressDelta(
            weightChange: current.bestSetWeightKg - previous.bestSetWeightKg,
            repsChange: current.bestSetReps - previous.bestSetReps,
            volumeChange: current.totalVolume - previous.totalVolume,
            oneRepMaxChange: (current.estimatedOneRepMax ?? 0) - (previous.estimatedOneRepMax ?? 0)
        )
    }

    struct ProgressDelta {
        let weightChange: Double
        let repsChange: Int
        let volumeChange: Double
        let oneRepMaxChange: Double

        var isImprovement: Bool {
            weightChange > 0 || repsChange > 0 || volumeChange > 0
        }

        var formattedWeightChange: String {
            if weightChange > 0 {
                return String(format: "+%.1f kg", weightChange)
            } else if weightChange < 0 {
                return String(format: "%.1f kg", weightChange)
            }
            return "No change"
        }
    }
}

// MARK: - Personal Records

extension ExerciseHistory {
    /// Record types for PR tracking
    enum RecordType: String, CaseIterable {
        case weight = "weight"
        case reps = "reps"
        case volume = "volume"
        case oneRepMax = "oneRepMax"

        var displayName: String {
            switch self {
            case .weight: "Heaviest Weight"
            case .reps: "Most Reps"
            case .volume: "Best Volume/Set"
            case .oneRepMax: "Best Estimated 1RM"
            }
        }

        var iconName: String {
            switch self {
            case .weight: "scalemass.fill"
            case .reps: "number.circle.fill"
            case .volume: "chart.bar.fill"
            case .oneRepMax: "trophy.fill"
            }
        }
    }

    /// Check if this entry sets a new record compared to previous best
    func isNewRecord(
        _ type: RecordType,
        comparedTo previous: ExerciseHistory?,
        volumePRMode: UserProfile.VolumePRMode = .perSet
    ) -> Bool {
        guard let previous else { return true }

        switch type {
        case .weight:
            return bestSetWeightKg > previous.bestSetWeightKg
        case .reps:
            return bestSetReps > previous.bestSetReps
        case .volume:
            return volumeValue(for: volumePRMode) > previous.volumeValue(for: volumePRMode)
        case .oneRepMax:
            guard let current1RM = estimatedOneRepMax,
                  let previous1RM = previous.estimatedOneRepMax else { return false }
            return current1RM > previous1RM
        }
    }
}

// MARK: - Performance Snapshot

struct ExercisePerformanceSnapshot {
    let exerciseName: String
    let lastSession: ExerciseHistory?
    let weightPR: ExerciseHistory?
    let repsPR: ExerciseHistory?
    let volumePR: ExerciseHistory?
    let estimatedOneRepMax: Double?
    let activityDurationPR: ExerciseHistory?
    let activityDistancePR: ExerciseHistory?
    let activityCountPR: ExerciseHistory?
    let totalSessions: Int

    var hasStrengthRecords: Bool {
        weightPR != nil || repsPR != nil || volumePR != nil || estimatedOneRepMax != nil
    }

    var hasActivityRecords: Bool {
        activityDurationPR != nil || activityDistancePR != nil || activityCountPR != nil
    }
}

enum ExercisePerformanceService {
    /// Fetch exercise history sorted by most-recent session first.
    static func history(
        for exerciseName: String,
        limit: Int? = nil,
        modelContext: ModelContext
    ) -> [ExerciseHistory] {
        var descriptor = FetchDescriptor<ExerciseHistory>(
            predicate: #Predicate { $0.exerciseName == exerciseName },
            sortBy: [SortDescriptor(\.performedAt, order: .reverse)]
        )
        if let limit {
            descriptor.fetchLimit = limit
        }
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    static func snapshot(
        for exerciseName: String,
        modelContext: ModelContext,
        volumePRMode: UserProfile.VolumePRMode = .perSet
    ) -> ExercisePerformanceSnapshot? {
        let history = history(for: exerciseName, modelContext: modelContext)
        return Self.snapshot(
            exerciseName: exerciseName,
            history: history,
            volumePRMode: volumePRMode
        )
    }

    static func snapshots(
        from history: [ExerciseHistory],
        volumePRMode: UserProfile.VolumePRMode = .perSet
    ) -> [String: ExercisePerformanceSnapshot] {
        let grouped = Dictionary(grouping: history, by: { $0.exerciseName })
        return grouped.reduce(into: [:]) { result, item in
            let (exerciseName, exerciseHistory) = item
            if let snapshot = snapshot(
                exerciseName: exerciseName,
                history: exerciseHistory,
                volumePRMode: volumePRMode
            ) {
                result[exerciseName] = snapshot
            }
        }
    }

    static func snapshot(
        exerciseName: String,
        history: [ExerciseHistory],
        volumePRMode: UserProfile.VolumePRMode = .perSet
    ) -> ExercisePerformanceSnapshot? {
        let strengthHistory = history.filter(\.hasStrengthMetrics)
        let activityHistory = history.filter(\.hasActivityMetrics)
        let trackableHistory = strengthHistory + activityHistory
        guard !trackableHistory.isEmpty else { return nil }

        return ExercisePerformanceSnapshot(
            exerciseName: exerciseName,
            lastSession: mostRecentRecord(in: trackableHistory),
            weightPR: bestWeightRecord(in: strengthHistory),
            repsPR: bestRepsRecord(in: strengthHistory),
            volumePR: bestVolumeRecord(in: strengthHistory, mode: volumePRMode),
            estimatedOneRepMax: strengthHistory
                .compactMap { entry in
                    entry.estimatedOneRepMax ??
                        LiveWorkoutEntry.estimatedOneRepMax(
                            weightKg: entry.bestSetWeightKg,
                            reps: entry.bestSetReps
                        )
                }
                .filter { $0 > 0 }
                .max(),
            activityDurationPR: bestActivityDurationRecord(in: activityHistory),
            activityDistancePR: bestActivityDistanceRecord(in: activityHistory),
            activityCountPR: bestActivityCountRecord(in: activityHistory),
            totalSessions: trackableHistory.count
        )
    }

    static func bestWeightRecord(in history: [ExerciseHistory]) -> ExerciseHistory? {
        let weightedHistory = history.filter { $0.bestSetWeightKg > 0 }
        if !weightedHistory.isEmpty {
            return weightedHistory.max(by: isWeightRecordWorse(_:_:))
        }

        // Bodyweight exercises have zero external load. Fall back to best reps at bodyweight.
        return history
            .filter { $0.bestSetWeightKg == 0 && $0.bestSetReps > 0 }
            .max(by: isRepsRecordWorse(_:_:))
    }

    static func bestRepsRecord(in history: [ExerciseHistory]) -> ExerciseHistory? {
        history
            .filter { $0.bestSetReps > 0 }
            .max(by: isRepsRecordWorse(_:_:))
    }

    static func bestVolumeRecord(
        in history: [ExerciseHistory],
        mode: UserProfile.VolumePRMode = .perSet
    ) -> ExerciseHistory? {
        history
            .filter { $0.totalVolume > 0 }
            .max { lhs, rhs in
                isVolumeRecordWorse(lhs, rhs, mode: mode)
            }
    }

    static func bestActivityDurationRecord(in history: [ExerciseHistory]) -> ExerciseHistory? {
        history
            .filter { $0.durationSeconds > 0 }
            .max(by: isActivityDurationRecordWorse(_:_:))
    }

    static func bestActivityDistanceRecord(in history: [ExerciseHistory]) -> ExerciseHistory? {
        history
            .filter { $0.distanceMeters > 0 }
            .max(by: isActivityDistanceRecordWorse(_:_:))
    }

    static func bestActivityCountRecord(in history: [ExerciseHistory]) -> ExerciseHistory? {
        history
            .filter { $0.totalReps > 0 || $0.totalSets > 0 }
            .max(by: isActivityCountRecordWorse(_:_:))
    }

    private static func mostRecentRecord(in history: [ExerciseHistory]) -> ExerciseHistory? {
        history.max(by: isRecentRecordWorse(_:_:))
    }

    nonisolated private static func isWeightRecordWorse(_ lhs: ExerciseHistory, _ rhs: ExerciseHistory) -> Bool {
        if lhs.bestSetWeightKg != rhs.bestSetWeightKg {
            return lhs.bestSetWeightKg < rhs.bestSetWeightKg
        }
        if lhs.bestSetReps != rhs.bestSetReps {
            return lhs.bestSetReps < rhs.bestSetReps
        }
        if lhs.totalVolume != rhs.totalVolume {
            return lhs.totalVolume < rhs.totalVolume
        }
        if lhs.performedAt != rhs.performedAt {
            return lhs.performedAt < rhs.performedAt
        }
        return lhs.id.uuidString < rhs.id.uuidString
    }

    nonisolated private static func isRepsRecordWorse(_ lhs: ExerciseHistory, _ rhs: ExerciseHistory) -> Bool {
        if lhs.bestSetReps != rhs.bestSetReps {
            return lhs.bestSetReps < rhs.bestSetReps
        }
        if lhs.bestSetWeightKg != rhs.bestSetWeightKg {
            return lhs.bestSetWeightKg < rhs.bestSetWeightKg
        }
        if lhs.totalVolume != rhs.totalVolume {
            return lhs.totalVolume < rhs.totalVolume
        }
        if lhs.performedAt != rhs.performedAt {
            return lhs.performedAt < rhs.performedAt
        }
        return lhs.id.uuidString < rhs.id.uuidString
    }

    nonisolated private static func isVolumeRecordWorse(
        _ lhs: ExerciseHistory,
        _ rhs: ExerciseHistory,
        mode: UserProfile.VolumePRMode
    ) -> Bool {
        let lhsVolume = lhs.volumeValue(for: mode)
        let rhsVolume = rhs.volumeValue(for: mode)

        if lhsVolume != rhsVolume {
            return lhsVolume < rhsVolume
        }
        if lhs.totalVolume != rhs.totalVolume {
            return lhs.totalVolume < rhs.totalVolume
        }
        if lhs.bestSetWeightKg != rhs.bestSetWeightKg {
            return lhs.bestSetWeightKg < rhs.bestSetWeightKg
        }
        if lhs.bestSetReps != rhs.bestSetReps {
            return lhs.bestSetReps < rhs.bestSetReps
        }
        if lhs.performedAt != rhs.performedAt {
            return lhs.performedAt < rhs.performedAt
        }
        return lhs.id.uuidString < rhs.id.uuidString
    }

    nonisolated private static func isRecentRecordWorse(_ lhs: ExerciseHistory, _ rhs: ExerciseHistory) -> Bool {
        if lhs.performedAt != rhs.performedAt {
            return lhs.performedAt < rhs.performedAt
        }
        return lhs.id.uuidString < rhs.id.uuidString
    }

    nonisolated private static func isActivityDurationRecordWorse(_ lhs: ExerciseHistory, _ rhs: ExerciseHistory) -> Bool {
        if lhs.durationSeconds != rhs.durationSeconds {
            return lhs.durationSeconds < rhs.durationSeconds
        }
        if lhs.distanceMeters != rhs.distanceMeters {
            return lhs.distanceMeters < rhs.distanceMeters
        }
        if lhs.totalReps != rhs.totalReps {
            return lhs.totalReps < rhs.totalReps
        }
        if lhs.performedAt != rhs.performedAt {
            return lhs.performedAt < rhs.performedAt
        }
        return lhs.id.uuidString < rhs.id.uuidString
    }

    nonisolated private static func isActivityDistanceRecordWorse(_ lhs: ExerciseHistory, _ rhs: ExerciseHistory) -> Bool {
        if lhs.distanceMeters != rhs.distanceMeters {
            return lhs.distanceMeters < rhs.distanceMeters
        }
        if lhs.durationSeconds != rhs.durationSeconds {
            return lhs.durationSeconds < rhs.durationSeconds
        }
        if lhs.totalReps != rhs.totalReps {
            return lhs.totalReps < rhs.totalReps
        }
        if lhs.performedAt != rhs.performedAt {
            return lhs.performedAt < rhs.performedAt
        }
        return lhs.id.uuidString < rhs.id.uuidString
    }

    nonisolated private static func isActivityCountRecordWorse(_ lhs: ExerciseHistory, _ rhs: ExerciseHistory) -> Bool {
        let lhsCount = max(lhs.totalReps, lhs.totalSets)
        let rhsCount = max(rhs.totalReps, rhs.totalSets)
        if lhsCount != rhsCount {
            return lhsCount < rhsCount
        }
        if lhs.durationSeconds != rhs.durationSeconds {
            return lhs.durationSeconds < rhs.durationSeconds
        }
        if lhs.distanceMeters != rhs.distanceMeters {
            return lhs.distanceMeters < rhs.distanceMeters
        }
        if lhs.performedAt != rhs.performedAt {
            return lhs.performedAt < rhs.performedAt
        }
        return lhs.id.uuidString < rhs.id.uuidString
    }
}
