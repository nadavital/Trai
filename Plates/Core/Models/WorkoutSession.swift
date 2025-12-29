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

    /// Total volume (sets * reps * weight) for strength exercises
    var totalVolume: Double? {
        guard let weightKg, sets > 0, reps > 0 else { return nil }
        return Double(sets * reps) * weightKg
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
        exercise?.category == "strength" || (sets > 0 && reps > 0)
    }

    /// Check if this is a cardio session
    var isCardio: Bool {
        exercise?.category == "cardio" || durationMinutes != nil || healthKitWorkoutType != nil
    }
}
