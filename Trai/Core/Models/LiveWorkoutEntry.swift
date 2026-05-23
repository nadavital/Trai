//
//  LiveWorkoutEntry.swift
//  Trai
//

import Foundation
import SwiftData

/// Represents a single exercise within a live workout, with detailed set tracking
@Model
final class LiveWorkoutEntry {
    var id: UUID = UUID()

    /// Order of this exercise in the workout (0-based)
    var orderIndex: Int = 0

    /// Reference to the exercise by ID (not a relationship for CloudKit compatibility)
    var exerciseId: UUID?

    /// Exercise name (stored for display, in case exercise is deleted)
    var exerciseName: String = ""

    /// Equipment/machine name (e.g., "Life Fitness Lat Pulldown", "Rack 3")
    var equipmentName: String?

    /// Type of exercise: "strength", "cardio", or "flexibility"
    var exerciseType: String = "strength"

    /// Broad activity kind for non-strength planned/ad hoc work, e.g. "cardio", "mobility", "skill".
    var activityKindRaw: String = ""

    /// Role inside the workout, e.g. "main", "warmup", "accessory", "finisher", "cooldown".
    var activityRoleRaw: String = ""

    /// Source workout-plan block ID when this entry came from a generated or manual plan.
    var sourcePlanBlockIDRaw: String?

    /// Planned duration in seconds before the user edits/logs the actual duration.
    var plannedDurationSeconds: Int?

    /// Planned effort or intensity cue copied from the workout plan.
    var plannedIntensity: String?

    /// Planned target copied from the workout plan, such as pace, zone, or movement cue.
    var plannedTarget: String?

    /// Comma-separated targeting tags copied from the exercise library or inferred from the plan.
    var targetTagsRaw: String = ""

    /// Comma-separated tracking fields copied from the exercise library.
    var trackingFieldsRaw: String = ""

    /// User-facing activity type copied from the exercise library or generated plan.
    var activityTypeNameRaw: String = ""

    /// JSON-encoded sets data for strength exercises
    /// Format: [{"reps": 10, "weightKg": 50.0, "completed": true, "isWarmup": false}]
    var setsData: String = "[]"

    /// JSON-encoded repeatable activity segments for cardio, conditioning, sport, and mobility work.
    var activitySegmentsData: String = "[]"

    /// Duration in seconds (for cardio/timed exercises)
    var durationSeconds: Int?

    /// Distance in meters (for cardio exercises)
    var distanceMeters: Double?

    /// Calories burned from imported external workout data. Not exposed as a manual tracking metric.
    var caloriesBurned: Double?

    /// Notes for this specific exercise
    var notes: String = ""

    /// When this exercise was completed (nil if still in progress)
    var completedAt: Date?

    /// Parent workout
    var workout: LiveWorkout?
    
    @Transient
    private var cachedSetsDataSnapshot: String?
    
    @Transient
    private var cachedSets: [SetData] = []

    @Transient
    private var cachedActivitySegmentsDataSnapshot: String?

    @Transient
    private var cachedActivitySegments: [ActivitySegment] = []

    init() {}

    /// Whether this is a cardio exercise
    var isCardio: Bool {
        exerciseType == "cardio"
    }

    /// Whether this is a strength exercise
    var isStrength: Bool {
        exerciseType == "strength"
    }

    /// Whether this is a non-strength, non-cardio activity item.
    var isGeneralActivity: Bool {
        !isStrength && !isCardio
    }

    /// Passive plan guidance shown in live workouts before the user logs any real data.
    var isPlannedActivityGuidance: Bool {
        !isStrength && sourcePlanBlockID != nil && !hasActivityLogData
    }

    var hasExercisePreferenceSignal: Bool {
        if isStrength {
            return completedSets?.isEmpty == false
        }
        return hasActivityLogData
    }

    var isLoggedActivity: Bool {
        guard !isStrength else { return false }
        return hasActivityLogData
    }

    private var hasActivityLogData: Bool {
        completedAt != nil
            || trackedDurationSeconds > 0
            || trackedDistanceMeters > 0
            || activitySegments.contains { $0.hasLoggedData }
            || !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var trackingFields: [Exercise.TrackingField] {
        get {
            let fields = trackingFieldsRaw
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .compactMap(Exercise.TrackingField.init(rawValue:))
            let category = resolvedActivityCategory
            if !fields.isEmpty {
                return Exercise.normalizedTrackingFields(fields, for: category)
            }
            return Exercise.defaultTrackingFields(for: category)
        }
        set {
            let category = resolvedActivityCategory
            trackingFieldsRaw = Exercise.normalizedTrackingFields(newValue, for: category).map(\.rawValue).joined(separator: ",")
        }
    }

    var targetTags: [String] {
        get {
            targetTagsRaw
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }
        set {
            targetTagsRaw = newValue
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: ",")
        }
    }

    var activityTypeName: String {
        get {
            let explicit = activityTypeNameRaw.trimmingCharacters(in: .whitespacesAndNewlines)
            if !explicit.isEmpty { return explicit }
            return Exercise.defaultActivityTypeName(
                for: exerciseName,
                category: Exercise.Category.normalized(from: exerciseType) ?? .custom
            )
        }
        set {
            activityTypeNameRaw = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    var activityKind: WorkoutPlan.TrainingBlock.BlockKind? {
        get {
            let trimmed = activityKindRaw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            return WorkoutPlan.TrainingBlock.BlockKind(rawValue: trimmed)
        }
        set {
            activityKindRaw = newValue?.rawValue ?? ""
        }
    }

    var activityRole: WorkoutPlan.TrainingBlock.Role? {
        get {
            let trimmed = activityRoleRaw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            return WorkoutPlan.TrainingBlock.Role(rawValue: trimmed)
        }
        set {
            activityRoleRaw = newValue?.rawValue ?? ""
        }
    }

    var sourcePlanBlockID: UUID? {
        get {
            guard let raw = sourcePlanBlockIDRaw else { return nil }
            return UUID(uuidString: raw)
        }
        set {
            sourcePlanBlockIDRaw = newValue?.uuidString
        }
    }

    var activityIconName: String {
        if let kind = activityKind {
            return kind.iconName
        }

        switch exerciseType {
        case "strength":
            return "dumbbell.fill"
        case "cardio":
            return "figure.run"
        case "conditioning":
            return "bolt.heart.fill"
        case "mobility":
            return "figure.mind.and.body"
        case "skill":
            return "figure.climbing"
        case "sportPractice":
            return "sportscourt.fill"
        case "recovery":
            return "heart.text.square.fill"
        case "flexibility":
            return "figure.cooldown"
        default:
            return "list.bullet.rectangle"
        }
    }

    init(exercise: Exercise, orderIndex: Int) {
        self.exerciseId = exercise.id
        self.exerciseName = exercise.name
        self.exerciseType = exercise.category
        self.equipmentName = exercise.displayEquipment  // Use inferred equipment if not stored
        self.orderIndex = orderIndex
        self.trackingFields = exercise.trackingFields
        self.targetTags = exercise.targetTags
        self.activityTypeName = exercise.activityTypeName
        if exercise.exerciseCategory != .strength {
            self.activityKind = exercise.exerciseCategory.liveWorkoutActivityKind
        }
    }

    init(exerciseName: String, orderIndex: Int, exerciseId: UUID? = nil, exerciseType: String = "strength", equipmentName: String? = nil) {
        self.exerciseName = exerciseName
        self.orderIndex = orderIndex
        self.exerciseId = exerciseId
        self.exerciseType = exerciseType
        self.equipmentName = equipmentName
        self.activityTypeName = Exercise.defaultActivityTypeName(
            for: exerciseName,
            category: Exercise.Category.normalized(from: exerciseType) ?? .custom
        )
    }
}

extension LiveWorkoutEntry {
    var resolvedActivityCategory: Exercise.Category {
        if let category = activityKind?.exerciseCategoryFallback.userFacingEquivalent {
            return category
        }
        return (Exercise.Category.normalized(from: exerciseType) ?? .custom).userFacingEquivalent
    }
}

extension WorkoutPlan.TrainingBlock.BlockKind {
    var exerciseCategoryFallback: Exercise.Category {
        switch self {
        case .strength:
            return .strength
        case .cardio:
            return .cardio
        case .conditioning:
            return .conditioning
        case .skill:
            return .skill
        case .sportPractice:
            return .sportPractice
        case .mobility:
            return .mobility
        case .recovery:
            return .recovery
        case .custom:
            return .custom
        }
    }

    static func liveWorkoutFallbackKind(for exerciseType: String) -> WorkoutPlan.TrainingBlock.BlockKind? {
        switch exerciseType {
        case "strength":
            return .strength
        case "cardio":
            return .cardio
        case "conditioning":
            return .conditioning
        case "mobility", "flexibility":
            return .mobility
        case "skill":
            return .skill
        case "sportPractice":
            return .sportPractice
        case "recovery":
            return .recovery
        case "custom":
            return .custom
        default:
            return nil
        }
    }

    var liveWorkoutExerciseType: String {
        switch self {
        case .cardio, .conditioning:
            return "cardio"
        case .mobility, .recovery:
            return "flexibility"
        case .skill, .sportPractice, .custom, .strength:
            return "activity"
        }
    }
}

// MARK: - Set Data Model

extension LiveWorkoutEntry {
    struct ActivitySegment: Codable, Identifiable, Equatable {
        var id: UUID = UUID()
        var durationSeconds: Int?
        var distanceMeters: Double?
        var reps: Int?
        var weightKg: Double?
        var notes: String

        init(
            id: UUID = UUID(),
            durationSeconds: Int? = nil,
            distanceMeters: Double? = nil,
            reps: Int? = nil,
            weightKg: Double? = nil,
            notes: String = ""
        ) {
            self.id = id
            self.durationSeconds = durationSeconds
            self.distanceMeters = distanceMeters
            self.reps = reps
            self.weightKg = weightKg
            self.notes = notes
        }

        nonisolated var hasLoggedData: Bool {
            (durationSeconds ?? 0) > 0
                || (distanceMeters ?? 0) > 0
                || (reps ?? 0) > 0
                || (weightKg ?? 0) > 0
                || !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    struct SetData: Codable, Identifiable, Equatable {
        var id: UUID = UUID()
        var reps: Int
        var weightKg: Double
        var weightLbs: Double
        var preferredWeightUnit: WeightUnit?
        var completed: Bool
        var isWarmup: Bool
        var notes: String

        init(
            reps: Int = 0,
            weightKg: Double = 0,
            weightLbs: Double = 0,
            preferredWeightUnit: WeightUnit? = nil,
            completed: Bool = false,
            isWarmup: Bool = false,
            notes: String = ""
        ) {
            self.reps = reps
            self.weightKg = weightKg
            self.weightLbs = weightLbs
            self.preferredWeightUnit = preferredWeightUnit
            self.completed = completed
            self.isWarmup = isWarmup
            self.notes = notes
        }

        /// Initialize with clean weight (both units pre-computed)
        init(
            reps: Int = 0,
            weight: CleanWeight,
            preferredWeightUnit: WeightUnit? = nil,
            completed: Bool = false,
            isWarmup: Bool = false,
            notes: String = ""
        ) {
            self.reps = reps
            self.weightKg = weight.kg
            self.weightLbs = weight.lbs
            self.preferredWeightUnit = preferredWeightUnit
            self.completed = completed
            self.isWarmup = isWarmup
            self.notes = notes
        }

        // Custom decoder to handle missing fields in existing data
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
            reps = try container.decode(Int.self, forKey: .reps)
            weightKg = try container.decode(Double.self, forKey: .weightKg)
            // Migration: compute lbs from kg if not present
            if let lbs = try container.decodeIfPresent(Double.self, forKey: .weightLbs) {
                weightLbs = lbs
            } else {
                // Legacy data: convert kg to lbs with clean rounding
                weightLbs = WeightUtility.round(weightKg * WeightUtility.kgToLbs, unit: .lbs)
            }
            preferredWeightUnit = try container.decodeIfPresent(WeightUnit.self, forKey: .preferredWeightUnit)
            completed = try container.decode(Bool.self, forKey: .completed)
            isWarmup = try container.decode(Bool.self, forKey: .isWarmup)
            notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
        }

        /// Volume for this set (weight × reps) - uses kg for calculations
        var volume: Double {
            Double(reps) * weightKg
        }

        /// Get clean weight in user's preferred unit
        func effectiveWeightUnit(defaultUsesMetric: Bool) -> WeightUnit {
            preferredWeightUnit ?? WeightUnit(usesMetric: defaultUsesMetric)
        }

        func displayWeight(usesMetric: Bool) -> Double {
            let unit = effectiveWeightUnit(defaultUsesMetric: usesMetric)
            return unit == .kg ? weightKg : weightLbs
        }

        /// Get formatted weight string in user's preferred unit
        func formattedWeight(usesMetric: Bool, showUnit: Bool = true) -> String {
            let value = displayWeight(usesMetric: usesMetric)
            let unit = effectiveWeightUnit(defaultUsesMetric: usesMetric).symbol
            if value.truncatingRemainder(dividingBy: 1) == 0 {
                return showUnit ? "\(Int(value)) \(unit)" : "\(Int(value))"
            }
            return showUnit ? String(format: "%.1f %@", value, unit) : String(format: "%.1f", value)
        }
    }
}

// MARK: - Sets Management

extension LiveWorkoutEntry {
    var activitySegments: [ActivitySegment] {
        get {
            if cachedActivitySegmentsDataSnapshot == activitySegmentsData {
                return cachedActivitySegments
            }
            guard let data = activitySegmentsData.data(using: .utf8),
                  let decodedSegments = try? JSONDecoder().decode([ActivitySegment].self, from: data) else {
                cachedActivitySegments = []
                cachedActivitySegmentsDataSnapshot = activitySegmentsData
                return []
            }
            cachedActivitySegments = decodedSegments
            cachedActivitySegmentsDataSnapshot = activitySegmentsData
            return decodedSegments
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue),
                  let json = String(data: data, encoding: .utf8) else { return }
            if activitySegmentsData != json {
                activitySegmentsData = json
            }
            cachedActivitySegments = newValue
            cachedActivitySegmentsDataSnapshot = json
        }
    }

    func addActivitySegment(_ segment: ActivitySegment = ActivitySegment()) {
        var segments = activitySegments
        segments.append(segment)
        activitySegments = segments
    }

    func updateActivitySegment(at index: Int, with segment: ActivitySegment) {
        var segments = activitySegments
        guard index < segments.count else { return }
        segments[index] = segment
        activitySegments = segments
    }

    func removeActivitySegment(at index: Int) {
        var segments = activitySegments
        guard index < segments.count else { return }
        segments.remove(at: index)
        activitySegments = segments
    }

    var trackedDurationSeconds: Int {
        let segmentTotal = activitySegments
            .compactMap(\.durationSeconds)
            .filter { $0 > 0 }
            .reduce(0, +)
        return max(durationSeconds ?? 0, segmentTotal)
    }

    var trackedDistanceMeters: Double {
        let segmentTotal = activitySegments
            .compactMap(\.distanceMeters)
            .filter { $0 > 0 }
            .reduce(0, +)
        return max(distanceMeters ?? 0, segmentTotal)
    }

    /// Parsed sets from JSON
    var sets: [SetData] {
        get {
            if cachedSetsDataSnapshot == setsData {
                return cachedSets
            }
            guard let data = setsData.data(using: .utf8),
                  let decodedSets = try? JSONDecoder().decode([SetData].self, from: data) else {
                cachedSets = []
                cachedSetsDataSnapshot = setsData
                return []
            }
            cachedSets = decodedSets
            cachedSetsDataSnapshot = setsData
            return decodedSets
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue),
                  let json = String(data: data, encoding: .utf8) else { return }
            if setsData != json {
                setsData = json
            }
            cachedSets = newValue
            cachedSetsDataSnapshot = json
        }
    }

    /// Add a new set
    func addSet(_ set: SetData = SetData()) {
        var currentSets = sets
        currentSets.append(set)
        sets = currentSets
    }

    /// Update a set at index
    func updateSet(at index: Int, with set: SetData) {
        var currentSets = sets
        guard index < currentSets.count else { return }
        currentSets[index] = set
        sets = currentSets
    }

    /// Remove a set at index
    func removeSet(at index: Int) {
        var currentSets = sets
        guard index < currentSets.count else { return }
        currentSets.remove(at: index)
        sets = currentSets
    }

    /// Toggle set completion
    func toggleSetCompletion(at index: Int) {
        var currentSets = sets
        guard index < currentSets.count else { return }
        currentSets[index].completed.toggle()
        sets = currentSets
    }
}

// MARK: - Computed Properties

extension LiveWorkoutEntry {
    static let estimatedOneRepMaxRepRange = 1...25

    static func estimatedOneRepMax(weightKg: Double, reps: Int) -> Double? {
        guard weightKg > 0, estimatedOneRepMaxRepRange.contains(reps) else { return nil }
        // Brzycki formula: 1RM = weight × (36 / (37 - reps))
        return weightKg * (36.0 / (37.0 - Double(reps)))
    }

    /// Only completed (non-warmup) sets
    var completedSets: [SetData]? {
        sets.filter { $0.completed && !$0.isWarmup }
    }

    /// Total volume for this exercise
    var totalVolume: Double {
        completedSets?.reduce(0) { $0 + $1.volume } ?? 0
    }

    /// Best set (highest volume)
    var bestSet: SetData? {
        completedSets?.max(by: { $0.volume < $1.volume })
    }

    /// Total reps completed
    var totalReps: Int {
        completedSets?.reduce(0) { $0 + $1.reps } ?? 0
    }

    /// Average weight used
    var averageWeight: Double {
        guard let completed = completedSets, !completed.isEmpty else { return 0 }
        return completed.reduce(0) { $0 + $1.weightKg } / Double(completed.count)
    }

    /// Whether this entry is complete
    var isComplete: Bool {
        completedAt != nil
    }

    /// Estimated one rep max using Brzycki formula
    var estimatedOneRepMax: Double? {
        guard let best = bestSet else { return nil }
        return Self.estimatedOneRepMax(weightKg: best.weightKg, reps: best.reps)
    }
}

// MARK: - Cardio Helpers

extension LiveWorkoutEntry {
    /// Formatted duration
    var formattedDuration: String? {
        let seconds = trackedDurationSeconds
        guard seconds > 0 else { return nil }
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        if minutes >= 60 {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            return "\(hours)h \(remainingMinutes)m"
        }
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }

    /// Formatted distance
    var formattedDistance: String? {
        let meters = trackedDistanceMeters
        guard meters > 0 else { return nil }
        if meters >= 1000 {
            return String(format: "%.2f km", meters / 1000)
        }
        return "\(Int(meters)) m"
    }

    /// Pace (min/km) for cardio
    var pacePerKm: Double? {
        let meters = trackedDistanceMeters
        let seconds = trackedDurationSeconds
        guard meters > 0, seconds > 0 else { return nil }
        let km = meters / 1000
        let minutes = Double(seconds) / 60
        return minutes / km
    }

    /// Formatted pace string
    var formattedPace: String? {
        guard let pace = pacePerKm else { return nil }
        let minutes = Int(pace)
        let seconds = Int((pace - Double(minutes)) * 60)
        return String(format: "%d:%02d /km", minutes, seconds)
    }

    func traiActivitySummarySegments(usesMetric: Bool = true) -> [String] {
        guard !isStrength else { return [] }

        var segments: [String] = []
        let activityName = activityTypeName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !activityName.isEmpty, activityName.goalNormalizedKey != exerciseName.goalNormalizedKey {
            segments.append(activityName)
        }
        if let duration = formattedDuration {
            segments.append(duration)
        }
        if let distance = formattedDistance {
            segments.append(distance)
        }

        let loggedSegments = activitySegments.filter(\.hasLoggedData)
        if loggedSegments.count > 1 {
            segments.append("\(loggedSegments.count) \(metricName(for: loggedSegments.count, pluralLabel: segmentMetricLabel))")
        }

        let countTotal = loggedSegments
            .compactMap(\.reps)
            .filter { $0 > 0 }
            .reduce(0, +)
        if countTotal > 0 {
            segments.append("\(countTotal) \(metricName(for: countTotal, pluralLabel: countMetricLabel))")
        }

        let maxWeightKg = loggedSegments
            .compactMap(\.weightKg)
            .filter { $0 > 0 }
            .max()
        if let maxWeightKg {
            let unit = WeightUnit(usesMetric: usesMetric)
            segments.append("\(WeightUtility.format(maxWeightKg, displayUnit: unit)) max")
        }

        return segments
    }

    private var segmentMetricLabel: String {
        let category = resolvedActivityCategory
        switch category {
        case .conditioning:
            return "rounds"
        default:
            return "segments"
        }
    }

    private var countMetricLabel: String {
        let category = resolvedActivityCategory
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

    private func metricName(for value: Int, pluralLabel: String) -> String {
        guard value == 1 else { return pluralLabel }
        if pluralLabel.hasSuffix("s") {
            return String(pluralLabel.dropLast())
        }
        return pluralLabel
    }
}
