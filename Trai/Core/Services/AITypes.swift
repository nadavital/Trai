//
//  AITypes.swift
//  Trai
//
//  Created by Nadav Avital on 12/25/25.
//

import Foundation

/// Response from Trai AI for food analysis
struct FoodAnalysis: Codable, Sendable {
    let name: String
    let calories: Int
    let proteinGrams: Double
    let carbsGrams: Double
    let fatGrams: Double
    let fiberGrams: Double?
    let sugarGrams: Double?
    let servingSize: String?
    let confidence: String?
    let notes: String?
    let emoji: String?
    let components: [FoodAnalysisComponent]?
    let mealKind: String?

    /// Display emoji with fallback
    var displayEmoji: String {
        emoji ?? "🍽️"
    }

    var rejectionReason: String? {
        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalizedName == "unclear food or drink" {
            return "model returned unclear sentinel"
        }

        if calories < 0 || proteinGrams < 0 || carbsGrams < 0 || fatGrams < 0 {
            return "negative calories or macros"
        }

        return nil
    }

    var shouldBeRejectedForLogging: Bool {
        rejectionReason != nil
    }
}

struct FoodAnalysisComponent: Codable, Sendable, Equatable {
    let id: String?
    let displayName: String
    let role: String?
    let quantity: Double?
    let unit: String?
    let calories: Int
    let proteinGrams: Double
    let carbsGrams: Double
    let fatGrams: Double
    let fiberGrams: Double?
    let sugarGrams: Double?
    let confidence: String?

    init(
        id: String? = nil,
        displayName: String,
        role: String? = nil,
        quantity: Double? = nil,
        unit: String? = nil,
        calories: Int,
        proteinGrams: Double,
        carbsGrams: Double,
        fatGrams: Double,
        fiberGrams: Double? = nil,
        sugarGrams: Double? = nil,
        confidence: String? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.role = role
        self.quantity = quantity
        self.unit = unit
        self.calories = calories
        self.proteinGrams = proteinGrams
        self.carbsGrams = carbsGrams
        self.fatGrams = fatGrams
        self.fiberGrams = fiberGrams
        self.sugarGrams = sugarGrams
        self.confidence = confidence
    }
}

/// Result from chat-based food analysis (with optional meal logging)
struct ChatFoodAnalysisResult: Sendable {
    let message: String
    let suggestedFoodEntry: SuggestedFoodEntry?
}

/// Food entry suggested by AI for logging
nonisolated struct SuggestedFoodEntry: Codable, Sendable, Identifiable, Equatable {
    var id: String = UUID().uuidString
    let name: String
    let calories: Int
    let proteinGrams: Double
    let carbsGrams: Double
    let fatGrams: Double
    let fiberGrams: Double?
    let sugarGrams: Double?
    let servingSize: String?
    let emoji: String?  // Relevant emoji for the food (☕, 🥗, 🍳, etc.)
    let loggedAtDateString: String?  // YYYY-MM-DD format if user specified a date
    let loggedAtTime: String?  // HH:mm format if user specified a time
    let components: [SuggestedFoodComponent]
    let mealKind: String?
    let notes: String?
    let confidence: String?
    let schemaVersion: Int

    nonisolated private enum CodingKeys: String, CodingKey {
        case id
        case name
        case calories
        case proteinGrams
        case carbsGrams
        case fatGrams
        case fiberGrams
        case sugarGrams
        case servingSize
        case emoji
        case loggedAtDateString
        case loggedAtTime
        case components
        case mealKind
        case notes
        case confidence
        case schemaVersion
    }

    /// Parse the logged date/time into a concrete Date in the current calendar.
    var loggedAtDate: Date? {
        let calendar = Calendar.current
        let baseDay: Date

        if let loggedAtDateString {
            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale(identifier: "en_US_POSIX")
            dateFormatter.dateFormat = "yyyy-MM-dd"
            guard let parsedDate = dateFormatter.date(from: loggedAtDateString) else { return nil }
            baseDay = parsedDate
        } else if loggedAtTime != nil {
            baseDay = Date()
        } else {
            return nil
        }

        var components = calendar.dateComponents([.year, .month, .day], from: baseDay)

        if let loggedAtTime {
            let timeFormatter = DateFormatter()
            timeFormatter.locale = Locale(identifier: "en_US_POSIX")
            timeFormatter.dateFormat = "HH:mm"
            guard let parsedTime = timeFormatter.date(from: loggedAtTime) else { return nil }
            let timeComponents = calendar.dateComponents([.hour, .minute], from: parsedTime)
            components.hour = timeComponents.hour
            components.minute = timeComponents.minute
        } else {
            let nowComponents = calendar.dateComponents([.hour, .minute, .second], from: Date())
            components.hour = nowComponents.hour
            components.minute = nowComponents.minute
            components.second = nowComponents.second
        }

        return calendar.date(from: components)
    }

    /// Display emoji or default fork and knife
    var displayEmoji: String {
        emoji ?? "🍽️"
    }

    init(
        id: String = UUID().uuidString,
        name: String,
        calories: Int,
        proteinGrams: Double,
        carbsGrams: Double,
        fatGrams: Double,
        fiberGrams: Double? = nil,
        sugarGrams: Double? = nil,
        servingSize: String?,
        emoji: String? = nil,
        loggedAtDateString: String? = nil,
        loggedAtTime: String? = nil,
        components: [SuggestedFoodComponent] = [],
        mealKind: String? = nil,
        notes: String? = nil,
        confidence: String? = nil,
        schemaVersion: Int = 1
    ) {
        self.id = id
        self.name = name
        self.calories = calories
        self.proteinGrams = proteinGrams
        self.carbsGrams = carbsGrams
        self.fatGrams = fatGrams
        self.fiberGrams = fiberGrams
        self.sugarGrams = sugarGrams
        self.servingSize = servingSize
        self.emoji = emoji
        self.loggedAtDateString = loggedAtDateString
        self.loggedAtTime = loggedAtTime
        self.components = components
        self.mealKind = mealKind
        self.notes = notes
        self.confidence = confidence
        self.schemaVersion = schemaVersion
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        name = try container.decode(String.self, forKey: .name)
        calories = try container.decode(Int.self, forKey: .calories)
        proteinGrams = try container.decode(Double.self, forKey: .proteinGrams)
        carbsGrams = try container.decode(Double.self, forKey: .carbsGrams)
        fatGrams = try container.decode(Double.self, forKey: .fatGrams)
        fiberGrams = try container.decodeIfPresent(Double.self, forKey: .fiberGrams)
        sugarGrams = try container.decodeIfPresent(Double.self, forKey: .sugarGrams)
        servingSize = try container.decodeIfPresent(String.self, forKey: .servingSize)
        emoji = try container.decodeIfPresent(String.self, forKey: .emoji)
        loggedAtDateString = try container.decodeIfPresent(String.self, forKey: .loggedAtDateString)
        loggedAtTime = try container.decodeIfPresent(String.self, forKey: .loggedAtTime)
        components = try container.decodeIfPresent([SuggestedFoodComponent].self, forKey: .components) ?? []
        mealKind = try container.decodeIfPresent(String.self, forKey: .mealKind)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        confidence = try container.decodeIfPresent(String.self, forKey: .confidence)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
    }
}

nonisolated struct SuggestedFoodComponent: Codable, Sendable, Equatable, Hashable {
    let id: String
    let displayName: String
    let role: String?
    let quantity: Double?
    let unit: String?
    let calories: Int
    let proteinGrams: Double
    let carbsGrams: Double
    let fatGrams: Double
    let fiberGrams: Double?
    let sugarGrams: Double?
    let confidence: String?

    nonisolated init(
        id: String = UUID().uuidString,
        displayName: String,
        role: String? = nil,
        quantity: Double? = nil,
        unit: String? = nil,
        calories: Int,
        proteinGrams: Double,
        carbsGrams: Double,
        fatGrams: Double,
        fiberGrams: Double? = nil,
        sugarGrams: Double? = nil,
        confidence: String? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.role = role
        self.quantity = quantity
        self.unit = unit
        self.calories = calories
        self.proteinGrams = proteinGrams
        self.carbsGrams = carbsGrams
        self.fatGrams = fatGrams
        self.fiberGrams = fiberGrams
        self.sugarGrams = sugarGrams
        self.confidence = confidence
    }
}

extension SuggestedFoodComponent {
    nonisolated init(component: FoodAnalysisComponent) {
        self.init(
            id: component.id ?? UUID().uuidString,
            displayName: component.displayName,
            role: component.role,
            quantity: component.quantity,
            unit: component.unit,
            calories: component.calories,
            proteinGrams: component.proteinGrams,
            carbsGrams: component.carbsGrams,
            fatGrams: component.fatGrams,
            fiberGrams: component.fiberGrams,
            sugarGrams: component.sugarGrams,
            confidence: component.confidence
        )
    }
}

/// Context provided to AI for fitness-aware responses
struct FitnessContext: Sendable {
    let userGoal: String
    let dailyCalorieGoal: Int?
    let dailyProteinGoal: Int?
    let todaysCalories: Int
    let todaysProtein: Double
    let recentWorkouts: [String]
    let currentWeight: Double?
    let targetWeight: Double?

    init(
        userGoal: String,
        dailyCalorieGoal: Int?,
        dailyProteinGoal: Int?,
        todaysCalories: Int,
        todaysProtein: Double,
        recentWorkouts: [String] = [],
        currentWeight: Double? = nil,
        targetWeight: Double? = nil
    ) {
        self.userGoal = userGoal
        self.dailyCalorieGoal = dailyCalorieGoal
        self.dailyProteinGoal = dailyProteinGoal
        self.todaysCalories = todaysCalories
        self.todaysProtein = todaysProtein
        self.recentWorkouts = recentWorkouts
        self.currentWeight = currentWeight
        self.targetWeight = targetWeight
    }

    var calorieTargetPromptLine: String {
        "- Daily calorie target: \(dailyCalorieGoal ?? 2_000) kcal"
    }

    var proteinTargetPromptLine: String {
        "- Daily protein target: \(dailyProteinGoal ?? 150)g"
    }

    var calorieContextSummary: String {
        "\(todaysCalories)/\(dailyCalorieGoal ?? 2_000)"
    }
}

// MARK: - Suggested Food Edit

/// Represents a proposed edit to an existing food entry (needs user confirmation)
nonisolated struct SuggestedFoodEdit: Codable, Sendable, Identifiable {
    let entryId: UUID
    let name: String
    let emoji: String?
    let changes: [FieldChange]

    var id: UUID { entryId }

    nonisolated struct FieldChange: Codable, Sendable, Identifiable {
        var id: String { field }
        let field: String
        let fieldKey: String  // Internal key for applying (e.g., "calories", "proteinGrams")
        let oldValue: String
        let newValue: String
        let newNumericValue: Double?  // For applying the change
        let newStringValue: String?  // For string changes
    }

    /// Display emoji or default
    var displayEmoji: String {
        emoji ?? "🍽️"
    }

    /// Summary of changes for display
    var changesSummary: String {
        changes.map { "\($0.field): \($0.oldValue) → \($0.newValue)" }.joined(separator: ", ")
    }
}

nonisolated struct SuggestedFoodComponentEdit: Codable, Sendable, Identifiable {
    let entryId: UUID
    let name: String
    let emoji: String?
    let operations: [Operation]
    let beforeTotals: NutritionSnapshot
    let afterTotals: NutritionSnapshot

    var id: UUID { entryId }

    nonisolated struct NutritionSnapshot: Codable, Sendable {
        let calories: Int
        let proteinGrams: Double
        let carbsGrams: Double
        let fatGrams: Double
        let fiberGrams: Double?
        let sugarGrams: Double?

        var summary: String {
            let protein = Int(proteinGrams.rounded())
            let carbs = Int(carbsGrams.rounded())
            let fat = Int(fatGrams.rounded())
            return "\(calories) kcal, \(protein)g protein, \(carbs)g carbs, \(fat)g fat"
        }
    }

    nonisolated struct Operation: Codable, Sendable, Identifiable {
        nonisolated enum OperationType: String, Codable, Sendable {
            case remove
            case restore
            case setFraction = "set_fraction"
            case add
            case update
        }

        let id: String
        let type: OperationType
        let componentId: String?
        let componentName: String
        let fractionOfOriginal: Double?
        let componentPayload: LoggedFoodComponent?
        let summary: String

        var summaryLine: String {
            summary
        }
    }

    var displayEmoji: String {
        emoji ?? "🍽️"
    }

    var operationsSummary: String {
        operations.map(\.summaryLine).joined(separator: ", ")
    }
}

// MARK: - Plan Update Suggestion

/// Plan update suggested by AI for user confirmation
nonisolated struct PlanUpdateSuggestionEntry: Codable, Sendable, Identifiable {
    var id: String {
        "\(calories ?? 0)-\(proteinGrams ?? 0)-\(carbsGrams ?? 0)-\(fatGrams ?? 0)-\(fiberGrams ?? 0)-\(sugarGrams ?? 0)-\(goal ?? "")"
    }
    let calories: Int?
    let proteinGrams: Int?
    let carbsGrams: Int?
    let fatGrams: Int?
    let fiberGrams: Int?
    let sugarGrams: Int?
    let goal: String?
    let rationale: String?

    /// Whether this suggestion contains any changes
    var hasChanges: Bool {
        calories != nil || proteinGrams != nil || carbsGrams != nil ||
        fatGrams != nil || fiberGrams != nil || sugarGrams != nil || goal != nil
    }

    /// Formatted goal display name
    var goalDisplayName: String? {
        guard let goal else { return nil }
        // Convert raw goal string to display name
        switch goal.lowercased().replacing("_", with: "") {
        case "loseweight": return "Lose Weight"
        case "losefat": return "Lose Fat, Keep Muscle"
        case "buildmuscle": return "Build Muscle"
        case "recomposition", "bodyrecomposition": return "Body Recomposition"
        case "maintenance", "maintainweight": return "Maintain Weight"
        case "performance", "athleticperformance": return "Athletic Performance"
        case "health", "generalhealth": return "General Health"
        default: return goal.replacing("_", with: " ").capitalized
        }
    }

    /// Create from function executor result
    init(
        calories: Int? = nil,
        proteinGrams: Int? = nil,
        carbsGrams: Int? = nil,
        fatGrams: Int? = nil,
        fiberGrams: Int? = nil,
        sugarGrams: Int? = nil,
        goal: String? = nil,
        rationale: String? = nil
    ) {
        self.calories = calories
        self.proteinGrams = proteinGrams
        self.carbsGrams = carbsGrams
        self.fatGrams = fatGrams
        self.fiberGrams = fiberGrams
        self.sugarGrams = sugarGrams
        self.goal = goal
        self.rationale = rationale
    }
}

// MARK: - Workout Plan Suggestion

/// Workout plan update suggested by AI for user confirmation
nonisolated struct WorkoutPlanSuggestionEntry: Codable, Sendable, Identifiable {
    var id: UUID = UUID()
    let plan: WorkoutPlan
    let message: String
}

// MARK: - Suggested Workout Entry

nonisolated private enum AIWorkoutCategoryNormalizer {
    static func key(from rawValue: String?) -> String? {
        Exercise.Category.normalized(from: rawValue)?.userFacingEquivalent.rawValue
    }
}

/// Workout suggested by AI for user confirmation before starting
nonisolated struct SuggestedWorkoutEntry: Codable, Sendable, Identifiable {
    var id: UUID = UUID()
    let name: String
    let workoutType: String
    let targetMuscleGroups: [String]
    let activityFocuses: [String]?
    let exercises: [SuggestedExercise]
    let durationMinutes: Int
    let rationale: String

    init(
        id: UUID = UUID(),
        name: String,
        workoutType: String,
        targetMuscleGroups: [String],
        activityFocuses: [String]? = nil,
        exercises: [SuggestedExercise],
        durationMinutes: Int,
        rationale: String
    ) {
        self.id = id
        self.name = name
        self.workoutType = workoutType
        self.targetMuscleGroups = targetMuscleGroups
        self.activityFocuses = activityFocuses
        self.exercises = exercises
        self.durationMinutes = durationMinutes
        self.rationale = rationale
    }

    nonisolated struct SuggestedExercise: Codable, Sendable, Identifiable {
        var id: UUID = UUID()
        let name: String
        let category: String?
        let activityTypeName: String?
        let targetTags: [String]?
        let trackingFields: [String]?
        let sets: Int
        let reps: Int
        let weightKg: Double?
        let durationMinutes: Int?
        let distanceMeters: Double?
        let notes: String?
        let segments: [ActivitySegment]?

        init(
            id: UUID = UUID(),
            name: String,
            category: String? = nil,
            activityTypeName: String? = nil,
            targetTags: [String]? = nil,
            trackingFields: [String]? = nil,
            sets: Int,
            reps: Int,
            weightKg: Double? = nil,
            durationMinutes: Int? = nil,
            distanceMeters: Double? = nil,
            notes: String? = nil,
            segments: [ActivitySegment]? = nil
        ) {
            self.id = id
            self.name = name
            self.category = category
            self.activityTypeName = activityTypeName
            self.targetTags = targetTags
            self.trackingFields = trackingFields
            self.sets = sets
            self.reps = reps
            self.weightKg = weightKg
            self.durationMinutes = durationMinutes
            self.distanceMeters = distanceMeters
            self.notes = notes
            self.segments = segments
        }

        nonisolated struct ActivitySegment: Codable, Sendable, Identifiable {
            var id: UUID = UUID()
            let durationMinutes: Int?
            let distanceMeters: Double?
            let reps: Int?
            let weightKg: Double?
            let notes: String?

            init(
                id: UUID = UUID(),
                durationMinutes: Int? = nil,
                distanceMeters: Double? = nil,
                reps: Int? = nil,
                weightKg: Double? = nil,
                notes: String? = nil
            ) {
                self.id = id
                self.durationMinutes = durationMinutes
                self.distanceMeters = distanceMeters
                self.reps = reps
                self.weightKg = weightKg
                self.notes = notes
            }
        }

        private var normalizedCategoryKey: String? {
            Self.normalizedCategoryKey(category) ?? Self.normalizedCategoryKey(activityTypeName)
        }

        var displayCategory: Exercise.Category? {
            if let category = Exercise.Category.normalized(from: category)?.userFacingEquivalent {
                return category
            }
            if let activityTypeName,
               let category = Exercise.Category.normalized(from: activityTypeName)?.userFacingEquivalent {
                return category
            }
            return nil
        }

        var hasActivityMetrics: Bool {
            let hasNotes = !(notes?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
            return durationMinutes != nil
                || distanceMeters != nil
                || hasNotes
                || segments?.isEmpty == false
                || trackingFields?.contains(where: { $0 != "sets" && $0 != "weight" }) == true
        }

        var isStrengthStartItem: Bool {
            if let normalizedCategoryKey {
                return normalizedCategoryKey == "strength"
            }
            return sets > 0 && !hasActivityMetrics
        }

        var isActivityStartItem: Bool {
            !isStrengthStartItem
        }

        var startSummarySegments: [String] {
            if isStrengthStartItem {
                var segments: [String] = []
                if sets > 0, reps > 0 {
                    segments.append("\(sets)x\(reps)")
                } else if sets > 0 {
                    segments.append("\(sets) \(sets == 1 ? "set" : "sets")")
                } else if reps > 0 {
                    segments.append("\(reps) reps")
                }
                if let weightKg, weightKg > 0 {
                    segments.append("\(Int(weightKg.rounded())) kg")
                }
                return segments
            }

            var details: [String] = []
            let activityName = activityTypeName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !activityName.isEmpty, Self.normalizedTextKey(activityName) != Self.normalizedTextKey(name) {
                details.append(activityName)
            }
            if let durationMinutes, durationMinutes > 0 {
                details.append("\(durationMinutes) min")
            }
            if let distanceMeters, distanceMeters > 0 {
                if distanceMeters >= 1000 {
                    details.append(String(format: "%.1f km", distanceMeters / 1000))
                } else {
                    details.append("\(Int(distanceMeters.rounded())) m")
                }
            }
            let segmentCount = segments?.count ?? 0
            if segmentCount > 1 {
                details.append("\(segmentCount) \(metricName(for: segmentCount, pluralLabel: segmentMetricLabel))")
            }
            let segmentCountTotal = segments?
                .compactMap(\.reps)
                .filter { $0 > 0 }
                .reduce(0, +) ?? 0
            let countTotal = segmentCountTotal > 0 ? segmentCountTotal : max(reps, 0)
            if countTotal > 0 {
                details.append("\(countTotal) \(metricName(for: countTotal, pluralLabel: countMetricLabel))")
            }
            let trimmedNotes = notes?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !trimmedNotes.isEmpty {
                details.append(trimmedNotes)
            }
            return details
        }

        private var segmentMetricLabel: String {
            switch normalizedCategoryKey {
            case "conditioning":
                return "rounds"
            default:
                return "segments"
            }
        }

        private var countMetricLabel: String {
            switch normalizedCategoryKey {
            case "sportPractice":
                return "attempts"
            case "conditioning":
                return "rounds"
            case "mobility", "recovery":
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

        private static func normalizedTextKey(_ value: String) -> String {
            value
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
                .replacingOccurrences(of: "-", with: "")
                .replacingOccurrences(of: "_", with: "")
                .replacingOccurrences(of: " ", with: "")
        }

        private static func normalizedCategoryKey(_ rawValue: String?) -> String? {
            AIWorkoutCategoryNormalizer.key(from: rawValue)
        }
    }

    /// Summary for display
    var exercisesSummary: String {
        var parts: [String] = []
        let strengthCount = exercises.filter(\.isStrengthStartItem).count
        let activityCount = exercises.filter(\.isActivityStartItem).count
        if strengthCount > 0 {
            parts.append("\(strengthCount) exercise\(strengthCount == 1 ? "" : "s")")
        }
        if activityCount > 0 {
            parts.append("\(activityCount) activit\(activityCount == 1 ? "y" : "ies")")
        }
        return parts.isEmpty ? "Workout" : parts.joined(separator: " • ")
    }

    /// Muscle groups summary
    var muscleGroupsSummary: String {
        targetMuscleGroups.map { $0.capitalized }.joined(separator: ", ")
    }

    var iconName: String {
        if let mode = WorkoutMode.normalized(from: workoutType),
           mode != .mixed,
           mode != .custom {
            return mode.iconName
        }

        let categories = exercises.compactMap(\.displayCategory)
        let hasStrength = categories.contains(.strength)
        let nonStrength = categories.first { $0 != .strength }
        if hasStrength, nonStrength != nil {
            return WorkoutMode.mixed.iconName
        }
        return nonStrength?.iconName
            ?? categories.first?.iconName
            ?? WorkoutMode.normalized(from: workoutType)?.iconName
            ?? "figure.mixed.cardio"
    }
}

// MARK: - Suggested Workout Log

/// Completed workout log suggested by AI for user confirmation before saving
nonisolated struct SuggestedWorkoutLog: Codable, Sendable, Identifiable {
    var id: UUID = UUID()
    let name: String?  // Trai-generated workout name
    let workoutType: String
    let activityName: String?
    let activityTags: [String]?
    let durationMinutes: Int?
    let exercises: [LoggedExercise]
    let notes: String?

    init(
        id: UUID = UUID(),
        name: String?,
        workoutType: String,
        activityName: String? = nil,
        activityTags: [String]? = nil,
        durationMinutes: Int?,
        exercises: [LoggedExercise],
        notes: String?
    ) {
        self.id = id
        self.name = name
        self.workoutType = workoutType
        self.activityName = activityName
        self.activityTags = activityTags
        self.durationMinutes = durationMinutes
        self.exercises = exercises
        self.notes = notes
    }

    nonisolated struct LoggedExercise: Codable, Sendable, Identifiable {
        var id: UUID = UUID()
        let name: String
        let category: String?
        let activityTypeName: String?
        let targetTags: [String]?
        let trackingFields: [String]?
        let durationMinutes: Int?
        let distanceMeters: Double?
        let notes: String?
        let segments: [ActivitySegment]?
        let sets: [SetData]

        init(
            id: UUID = UUID(),
            name: String,
            category: String? = nil,
            activityTypeName: String? = nil,
            targetTags: [String]? = nil,
            trackingFields: [String]? = nil,
            durationMinutes: Int? = nil,
            distanceMeters: Double? = nil,
            notes: String? = nil,
            segments: [ActivitySegment]? = nil,
            sets: [SetData]
        ) {
            self.id = id
            self.name = name
            self.category = category
            self.activityTypeName = activityTypeName
            self.targetTags = targetTags
            self.trackingFields = trackingFields
            self.durationMinutes = durationMinutes
            self.distanceMeters = distanceMeters
            self.notes = notes
            self.segments = segments
            self.sets = sets
        }

        nonisolated struct ActivitySegment: Codable, Sendable, Identifiable {
            var id: UUID = UUID()
            let durationMinutes: Int?
            let distanceMeters: Double?
            let reps: Int?
            let weightKg: Double?
            let notes: String?

            init(
                id: UUID = UUID(),
                durationMinutes: Int? = nil,
                distanceMeters: Double? = nil,
                reps: Int? = nil,
                weightKg: Double? = nil,
                notes: String? = nil
            ) {
                self.id = id
                self.durationMinutes = durationMinutes
                self.distanceMeters = distanceMeters
                self.reps = reps
                self.weightKg = weightKg
                self.notes = notes
            }
        }

        nonisolated struct SetData: Codable, Sendable, Identifiable {
            var id: UUID = UUID()
            let reps: Int
            let weightKg: Double?

            /// Formatted weight in user's preferred unit
            func formattedWeight(useLbs: Bool) -> String? {
                guard let weight = weightKg, weight > 0 else { return nil }
                if useLbs {
                    let lbs = weight * 2.20462
                    return "\(Int(lbs)) lbs"
                } else {
                    return "\(Int(weight)) kg"
                }
            }
        }

        private var normalizedCategoryKey: String? {
            Self.normalizedCategoryKey(category) ?? Self.normalizedCategoryKey(activityTypeName)
        }

        var displayCategory: Exercise.Category? {
            if let category = Exercise.Category.normalized(from: category)?.userFacingEquivalent {
                return category
            }
            if let activityTypeName,
               let category = Exercise.Category.normalized(from: activityTypeName)?.userFacingEquivalent {
                return category
            }
            return nil
        }

        var hasActivityMetrics: Bool {
            let hasNotes = !(notes?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
            return durationMinutes != nil
                || distanceMeters != nil
                || hasNotes
                || segments?.isEmpty == false
                || trackingFields?.contains(where: { $0 != "sets" && $0 != "weight" }) == true
        }

        /// Total strength set count.
        var setCount: Int { isStrengthLog ? sets.count : 0 }

        var isStrengthLog: Bool {
            if let normalizedCategoryKey {
                return normalizedCategoryKey == "strength"
            }
            return !sets.isEmpty && !hasActivityMetrics
        }

        var isActivityLog: Bool {
            !isStrengthLog
        }

        private static func normalizedCategoryKey(_ rawValue: String?) -> String? {
            AIWorkoutCategoryNormalizer.key(from: rawValue)
        }

        /// Summary string for display (e.g., "3×10" or "12, 10, 8")
        var setsSummary: String {
            guard !sets.isEmpty else { return "" }
            let allSameReps = sets.dropFirst().allSatisfy { $0.reps == sets.first?.reps }
            if allSameReps, let firstReps = sets.first?.reps {
                return "\(sets.count)×\(firstReps)"
            } else {
                return sets.map { "\($0.reps)" }.joined(separator: ", ")
            }
        }

        /// Weight summary (uses max weight)
        var maxWeightKg: Double? {
            sets.compactMap { $0.weightKg }.max()
        }

        /// Formatted weight in user's preferred unit
        func formattedWeight(useLbs: Bool) -> String? {
            guard let weight = maxWeightKg, weight > 0 else { return nil }
            if useLbs {
                let lbs = weight * 2.20462
                return "\(Int(lbs)) lbs"
            } else {
                return "\(Int(weight)) kg"
            }
        }

        var activitySummarySegments: [String] {
            var parts: [String] = []
            let activityName = activityTypeName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !activityName.isEmpty, Self.normalizedTextKey(activityName) != Self.normalizedTextKey(name) {
                parts.append(activityName)
            }

            if let durationMinutes, durationMinutes > 0 {
                parts.append("\(durationMinutes) min")
            }

            if let distanceMeters, distanceMeters > 0 {
                if distanceMeters >= 1000 {
                    parts.append(String(format: "%.1f km", distanceMeters / 1000))
                } else {
                    parts.append("\(Int(distanceMeters.rounded())) m")
                }
            }

            if let segments, segments.count > 1 {
                parts.append("\(segments.count) \(metricName(for: segments.count, pluralLabel: segmentMetricLabel))")
            }

            let countTotal = segments?
                .compactMap(\.reps)
                .filter { $0 > 0 }
                .reduce(0, +) ?? 0
            if countTotal > 0 {
                parts.append("\(countTotal) \(metricName(for: countTotal, pluralLabel: countMetricLabel))")
            }

            let trimmedNotes = notes?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !trimmedNotes.isEmpty {
                parts.append(trimmedNotes)
            }

            return parts
        }

        var segmentMetricLabel: String {
            switch normalizedCategoryKey {
            case "conditioning":
                return "rounds"
            default:
                return "segments"
            }
        }

        var countMetricLabel: String {
            switch normalizedCategoryKey {
            case "sportPractice":
                return "attempts"
            case "conditioning":
                return "rounds"
            case "mobility", "recovery":
                return "reps"
            default:
                return "reps"
            }
        }

        func metricName(for value: Int, pluralLabel: String) -> String {
            guard value == 1 else { return pluralLabel }
            if pluralLabel.hasSuffix("s") {
                return String(pluralLabel.dropLast())
            }
            return pluralLabel
        }

        private static func normalizedTextKey(_ value: String) -> String {
            value
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
                .replacingOccurrences(of: "-", with: "")
                .replacingOccurrences(of: "_", with: "")
                .replacingOccurrences(of: " ", with: "")
        }
    }

    /// Display name for the workout (uses Trai-generated name or falls back to type)
    var displayName: String {
        if let name, !name.isEmpty {
            return name
        }
        return workoutType.capitalized
    }

    /// Total sets across all exercises
    var totalSets: Int {
        exercises.reduce(0) { $0 + $1.setCount }
    }

    var strengthExerciseCount: Int {
        exercises.filter(\.isStrengthLog).count
    }

    var activityCount: Int {
        exercises.filter(\.isActivityLog).count
    }

    var resolvedDurationMinutes: Int? {
        if let durationMinutes, durationMinutes > 0 {
            return durationMinutes
        }

        let exerciseDurations = exercises.compactMap { exercise -> Int? in
            if let duration = exercise.durationMinutes, duration > 0 {
                return duration
            }

            let segmentTotal = (exercise.segments ?? [])
                .compactMap(\.durationMinutes)
                .filter { $0 > 0 }
                .reduce(0, +)
            return segmentTotal > 0 ? segmentTotal : nil
        }

        guard !exerciseDurations.isEmpty else { return nil }
        return exerciseDurations.reduce(0, +)
    }

    /// Summary for display
    var summary: String {
        var parts: [String] = []
        if strengthExerciseCount > 0 {
            parts.append("\(strengthExerciseCount) exercise\(strengthExerciseCount == 1 ? "" : "s")")
        }
        if activityCount > 0 {
            parts.append("\(activityCount) activit\(activityCount == 1 ? "y" : "ies")")
        }
        if totalSets > 0 {
            parts.append("\(totalSets) sets")
        }
        if let duration = resolvedDurationMinutes, duration > 0 {
            parts.append("\(duration) min")
        }
        return parts.isEmpty ? workoutType.capitalized : parts.joined(separator: " • ")
    }

    var iconName: String {
        if let mode = WorkoutMode.normalized(from: workoutType),
           mode != .mixed,
           mode != .custom {
            return mode.iconName
        }

        let categories = exercises.compactMap(\.displayCategory)
        let hasStrength = categories.contains(.strength)
        let nonStrength = categories.first { $0 != .strength }
        if hasStrength, nonStrength != nil {
            return WorkoutMode.mixed.iconName
        }
        return nonStrength?.iconName
            ?? categories.first?.iconName
            ?? WorkoutMode.normalized(from: workoutType)?.iconName
            ?? "figure.mixed.cardio"
    }

    /// Whether this is a strength workout
    var isStrength: Bool {
        if let mode = WorkoutMode.normalized(from: workoutType) {
            return mode.supportsMuscleTargets
        }
        return ["strength", "weights", "lifting"].contains(workoutType.lowercased())
    }
}

// MARK: - Errors

enum AIServiceError: LocalizedError {
    case invalidInput(String)
    case invalidResponse
    case apiError(statusCode: Int, message: String)
    case parsingError
    case accessDenied(String)
    case quotaExceeded(String)

    var errorDescription: String? {
        switch self {
        case .invalidInput(let message):
            return message
        case .invalidResponse:
            return "Invalid response from AI service"
        case .apiError(let statusCode, let message):
            return "API Error (\(statusCode)): \(message)"
        case .parsingError:
            return "Failed to parse AI response"
        case .accessDenied(let message):
            return message
        case .quotaExceeded(let message):
            return message
        }
    }
}

extension Error {
    var isUserCancelledRequest: Bool {
        if self is CancellationError {
            return true
        }

        if let urlError = self as? URLError, urlError.code == .cancelled {
            return true
        }

        let nsError = self as NSError
        return nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled
    }

    var aiUserFacingMessage: String? {
        switch self {
        case let aiServiceError as AIServiceError:
            switch aiServiceError {
            case .invalidInput(let message), .accessDenied(let message), .quotaExceeded(let message):
                return message
            default:
                return nil
            }
        case let backendError as BackendClientError:
            return backendError.localizedDescription
        default:
            return nil
        }
    }

    func aiUserFacingMessage(fallback: String) -> String {
        aiUserFacingMessage ?? fallback
    }
}
