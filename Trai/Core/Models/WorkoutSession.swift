import Foundation
import SwiftData

/// Represents a single workout session or exercise set
@Model
final class WorkoutSession {
    var id: UUID = UUID()

    /// The exercise performed (optional for HealthKit-imported workouts)
    var exercise: Exercise?

    /// Name of exercise (used when exercise relationship is nil)
    var exerciseName: String?

    // Strength training metrics
    var sets: Int = 0
    var reps: Int = 0
    var weightKg: Double?

    // Cardio metrics
    var durationMinutes: Double?
    var caloriesBurned: Int?
    var distanceMeters: Double?
    var averageHeartRate: Int?

    /// Whether this was imported from HealthKit
    var sourceIsHealthKit: Bool = false

    /// HealthKit workout UUID for deduplication
    var healthKitWorkoutID: String?

    /// Type of workout from HealthKit (e.g., "running", "cycling")
    var healthKitWorkoutType: String?

    /// Comma-separated activity identity tags imported from Trai HealthKit metadata.
    var activityTagsRaw: String = ""

    var loggedAt: Date = Date()
    var notes: String?

    init() {}

    /// Initialize for strength training
    init(exercise: Exercise, sets: Int, reps: Int, weightKg: Double?) {
        self.exercise = exercise
        self.exerciseName = exercise.name
        self.sets = sets
        self.reps = reps
        self.weightKg = weightKg
    }

    /// Initialize for cardio from HealthKit
    init(
        healthKitWorkoutID: String,
        workoutType: String,
        durationMinutes: Double,
        caloriesBurned: Int?,
        distanceMeters: Double?,
        loggedAt: Date
    ) {
        self.healthKitWorkoutID = healthKitWorkoutID
        self.healthKitWorkoutType = workoutType
        self.exerciseName = workoutType.capitalized
        self.durationMinutes = durationMinutes
        self.caloriesBurned = caloriesBurned
        self.distanceMeters = distanceMeters
        self.loggedAt = loggedAt
        self.sourceIsHealthKit = true
    }
}

// MARK: - Computed Properties

extension WorkoutSession {
    /// Display name for the workout
    var displayName: String {
        exercise?.name ?? exerciseName ?? healthKitWorkoutType?.capitalized ?? "Workout"
    }

    var activityDisplayName: String {
        if let exercise {
            let activityName = exercise.activityTypeName.trimmingCharacters(in: .whitespacesAndNewlines)
            if exercise.exerciseCategory != .strength, !activityName.isEmpty {
                return activityName
            }
        }

        if let workoutType = WorkoutMode.normalized(from: healthKitWorkoutType) {
            return workoutType.displayName
        }

        let cleaned = (healthKitWorkoutType ?? exercise?.category ?? "")
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleaned.isEmpty else {
            return isCardio ? "Cardio" : "Workout"
        }

        return cleaned
            .split(separator: " ")
            .map { $0.capitalized }
            .joined(separator: " ")
    }

    var semanticActivityTags: [String] {
        var seen = Set<String>()
        var values: [String] = []
        let candidates = semanticActivityTagCandidates + importedActivityTags + (exercise?.targetTags ?? [])

        for rawValue in candidates {
            let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
            let key = trimmed.goalNormalizedKey
            guard !trimmed.isEmpty, !key.isEmpty, seen.insert(key).inserted else { continue }
            values.append(trimmed)
        }

        return values
    }

    var importedActivityTags: [String] {
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

    private var semanticActivityTagCandidates: [String] {
        guard let exercise else {
            return [healthKitWorkoutType, displayTypeName].compactMap { $0 }
        }

        let specificActivityName = exercise.exerciseCategory == .strength
            ? nil
            : exercise.activityTypeName
        let categoryDisplayName = exercise.exerciseCategory.userFacingEquivalent.displayName
        return [
            specificActivityName,
            healthKitWorkoutType,
            displayTypeName,
            specificActivityName == nil ? categoryDisplayName : nil
        ].compactMap { $0 }
    }

    /// Total volume (sets * reps * weight) for strength exercises
    var totalVolume: Double? {
        guard isStrengthTraining, let weightKg, sets > 0, reps > 0 else { return nil }
        return Double(sets * reps) * weightKg
    }

    /// Normalized session volume to compare across different set counts.
    var volumePerSet: Double? {
        guard let totalVolume, sets > 0 else { return nil }
        return totalVolume / Double(sets)
    }

    /// Returns the volume metric value using the selected PR mode.
    func volumeValue(for mode: UserProfile.VolumePRMode) -> Double? {
        switch mode {
        case .perSet:
            return volumePerSet
        case .totalVolume:
            return totalVolume
        }
    }

    /// Formatted duration string
    var formattedDuration: String? {
        guard let durationMinutes else { return nil }
        let hours = Int(durationMinutes) / 60
        let minutes = Int(durationMinutes) % 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    /// Formatted distance string
    var formattedDistance: String? {
        guard let distanceMeters else { return nil }
        let kilometers = distanceMeters / 1000

        if kilometers >= 1 {
            return String(format: "%.2f km", kilometers)
        } else {
            return "\(Int(distanceMeters)) m"
        }
    }

    /// Check if this is a strength training session
    var isStrengthTraining: Bool {
        if let exercise {
            return exercise.exerciseCategory == .strength
        }
        return healthKitWorkoutType == nil && sets > 0 && reps > 0
    }

    /// Check if this is a cardio session
    var isCardio: Bool {
        exercise?.category == "cardio" || durationMinutes != nil || healthKitWorkoutType != nil
    }

    var displayTypeName: String {
        if isStrengthTraining {
            return "Strength Training"
        }

        return activityDisplayName
    }

    var setMetricLabel: String {
        guard !isStrengthTraining else { return "Sets" }

        switch exercise?.exerciseCategory.userFacingEquivalent {
        case .conditioning:
            return "Rounds"
        case .cardio, .mobility, .recovery, .sportPractice, .custom, .none:
            return "Segments"
        case .strength:
            return "Sets"
        case .skill, .flexibility:
            return "Segments"
        }
    }

    var repMetricLabel: String {
        guard !isStrengthTraining else { return "Reps" }

        switch exercise?.exerciseCategory.userFacingEquivalent {
        case .sportPractice:
            return "Attempts"
        case .conditioning:
            return "Rounds"
        case .mobility, .recovery:
            return "Reps"
        case .cardio, .custom, .none:
            return "Reps"
        case .strength:
            return "Reps"
        case .skill:
            return "Attempts"
        case .flexibility:
            return "Reps"
        }
    }

    var setMetricPhrase: String? {
        metricPhrase(value: sets, pluralLabel: setMetricLabel)
    }

    var repMetricPhrase: String? {
        metricPhrase(value: reps, pluralLabel: repMetricLabel)
    }

    var historyDetailSegments: [String] {
        var segments: [String] = []

        if isStrengthTraining {
            if sets > 0 && reps > 0 {
                segments.append("\(sets)×\(reps)")
            } else {
                if sets > 0 {
                    segments.append("\(sets) \(sets == 1 ? "set" : "sets")")
                }
                if reps > 0 {
                    segments.append("\(reps) reps")
                }
            }
        } else {
            let displayKey = displayName.goalNormalizedKey
            let typeKey = displayTypeName.goalNormalizedKey
            let importedTags = importedActivityTags.filter { tag in
                let key = tag.goalNormalizedKey
                return !key.isEmpty && key != displayKey && key != typeKey
            }
            let primaryContext = importedTags.first ?? {
                let activity = activityDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
                let key = activity.goalNormalizedKey
                return !activity.isEmpty && key != displayKey ? activity : nil
            }()

            if let primaryContext {
                segments.append(primaryContext)
            }

            if let extraTag = importedTags.dropFirst().first,
               extraTag.goalNormalizedKey != primaryContext?.goalNormalizedKey {
                segments.append(extraTag)
            }

            if let duration = formattedDuration {
                segments.append(duration)
            }
            if let distance = formattedDistance {
                segments.append(distance)
            }
            if let setMetricPhrase {
                segments.append(setMetricPhrase)
            }
            if let repMetricPhrase {
                segments.append(repMetricPhrase)
            }
        }

        if let caloriesBurned {
            segments.append("\(caloriesBurned) kcal")
        }

        return segments
    }

    private func metricPhrase(value: Int, pluralLabel: String) -> String? {
        guard value > 0 else { return nil }
        return "\(value) \(metricName(for: value, pluralLabel: pluralLabel))"
    }

    private func metricName(for value: Int, pluralLabel: String) -> String {
        let lowercased = pluralLabel.lowercased()
        guard value == 1 else { return lowercased }

        switch lowercased {
        case "sets": return "set"
        case "reps": return "rep"
        case "rounds": return "round"
        case "segments": return "segment"
        case "attempts": return "attempt"
        default:
            if lowercased.hasSuffix("s") {
                return String(lowercased.dropLast())
            }
            return lowercased
        }
    }

    var inferredWorkoutMode: WorkoutMode {
        if isStrengthTraining {
            return .strength
        }

        return WorkoutMode.infer(
            from: displayName,
            focusAreas: semanticActivityTags,
            targetMuscleGroups: []
        )
    }

    var trimmedNotes: String {
        (notes ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var hasSignalNote: Bool {
        !trimmedNotes.isEmpty
    }

    var traiReviewPrompt: String {
        var prompt = "Can you review my \(displayName) session from \(loggedAt.formatted(date: .abbreviated, time: .shortened))?"

        var details: [String] = []
        details.append(displayTypeName.lowercased())
        let tags = semanticActivityTags.filter { $0.goalNormalizedKey != displayTypeName.goalNormalizedKey }
        if !tags.isEmpty {
            details.append("activity context \(tags.prefix(3).joined(separator: ", "))")
        }

        if let formattedDuration {
            details.append("duration \(formattedDuration)")
        }
        if let formattedDistance {
            details.append("distance \(formattedDistance)")
        }
        if let setMetricPhrase {
            details.append(setMetricPhrase)
        }
        if let repMetricPhrase {
            details.append(repMetricPhrase)
        }
        if let caloriesBurned {
            details.append("\(caloriesBurned) kcal")
        }

        if !details.isEmpty {
            prompt += " It was a \(details.joined(separator: ", "))."
        }

        if hasSignalNote {
            prompt += " I added these notes: \(trimmedNotes)."
        } else if sourceIsHealthKit {
            prompt += " This one was tracked on my Apple Watch, so please use the workout data that was imported."
        }

        prompt += " Tell me what this says about my progress and what I should focus on next."
        return prompt
    }

    var goalMatchingTokens: Set<String> {
        var tokens: Set<String> = []
        [displayName, exerciseName, healthKitWorkoutType, exercise?.category, exercise?.activityTypeName, displayTypeName]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .forEach { tokens.insert($0.goalNormalizedKey) }
        exercise?.targetTags.forEach { tag in
            let key = tag.goalNormalizedKey
            if !key.isEmpty {
                tokens.insert(key)
            }
        }
        importedActivityTags.forEach { tag in
            let key = tag.goalNormalizedKey
            if !key.isEmpty {
                tokens.insert(key)
            }
        }
        return tokens
    }

    var iconName: String {
        let token = ([displayName, displayTypeName, healthKitWorkoutType, exercise?.category] + semanticActivityTags)
            .compactMap { $0 }
            .joined(separator: " ")
            .lowercased()

        if isStrengthTraining || token.contains("strength") || token.contains("weight") {
            return "dumbbell.fill"
        }
        if token.contains("run") {
            return "figure.run"
        }
        if token.contains("cycle") || token.contains("bike") {
            return "figure.outdoor.cycle"
        }
        if token.contains("swim") {
            return "figure.pool.swim"
        }
        if token.contains("walk") || token.contains("hike") {
            return "figure.walk"
        }
        if token.contains("row") {
            return "figure.rower"
        }
        if token.contains("yoga") {
            return "figure.yoga"
        }
        if token.contains("pilates") || token.contains("stretch") || token.contains("flexibility") {
            return "figure.flexibility"
        }
        if token.contains("mobility") {
            return "figure.mind.and.body"
        }
        if token.contains("climb") || token.contains("boulder") {
            return "figure.climbing"
        }
        if token.contains("skill") || token.contains("practice") {
            return "sportscourt.fill"
        }
        if token.contains("hiit") || token.contains("interval") || token.contains("conditioning") {
            return "bolt.heart.fill"
        }
        if token.contains("recovery") || token.contains("cooldown") {
            return "heart.text.square.fill"
        }
        return isCardio ? "figure.mixed.cardio" : "figure.run"
    }
}
