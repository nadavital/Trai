//
//  WorkoutMode.swift
//  Trai
//

import Foundation

nonisolated enum WorkoutMode: String, Codable, CaseIterable, Identifiable {
    case strength = "strength"
    case cardio = "cardio"
    case hiit = "hiit"
    case climbing = "climbing"
    case yoga = "yoga"
    case pilates = "pilates"
    case flexibility = "flexibility"
    case mobility = "mobility"
    case mixed = "mixed"
    case recovery = "recovery"
    case custom = "custom"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .strength: "Strength"
        case .cardio: "Cardio"
        case .hiit: "HIIT"
        case .climbing: "Climbing"
        case .yoga: "Yoga"
        case .pilates: "Pilates"
        case .flexibility: "Flexibility"
        case .mobility: "Mobility"
        case .mixed: "Mixed"
        case .recovery: "Recovery"
        case .custom: "Custom"
        }
    }

    nonisolated var iconName: String {
        switch self {
        case .strength: "dumbbell.fill"
        case .cardio: "figure.run"
        case .hiit: "bolt.heart.fill"
        case .climbing: "figure.climbing"
        case .yoga: "figure.yoga"
        case .pilates: "figure.flexibility"
        case .flexibility: "figure.cooldown"
        case .mobility: "figure.mind.and.body"
        case .mixed: "figure.mixed.cardio"
        case .recovery: "heart.text.square.fill"
        case .custom: "slider.horizontal.3"
        }
    }

    var supportsMuscleTargets: Bool {
        switch self {
        case .strength, .mixed:
            return true
        case .cardio, .hiit, .climbing, .yoga, .pilates, .flexibility, .mobility, .recovery, .custom:
            return false
        }
    }

    var prefersStructuredEntries: Bool {
        switch self {
        case .strength, .mixed, .hiit:
            return true
        case .cardio, .climbing, .yoga, .pilates, .flexibility, .mobility, .recovery, .custom:
            return false
        }
    }

    var suggestedFocusPresets: [String] {
        switch self {
        case .strength:
            return ["Push", "Pull", "Legs", "Upper", "Full Body"]
        case .cardio:
            return ["Running", "Cycling", "Swimming", "Rowing", "Steady Cardio"]
        case .hiit:
            return ["Intervals", "Conditioning", "Sprints", "Circuit"]
        case .climbing:
            return ["Bouldering", "Top Rope", "Technique", "Endurance"]
        case .yoga:
            return ["Flow", "Recovery", "Balance", "Breathwork"]
        case .pilates:
            return ["Core", "Reformer", "Mat", "Control"]
        case .flexibility:
            return ["Stretching", "Range of Motion", "Cooldown", "Recovery"]
        case .mobility:
            return ["Hips", "Shoulders", "Thoracic", "Ankles"]
        case .mixed:
            return ["Strength", "Cardio", "Conditioning", "Full Body"]
        case .recovery:
            return ["Easy Cardio", "Mobility", "Breathing", "Walk"]
        case .custom:
            return ["Skills", "Technique", "Conditioning", "Recovery"]
        }
    }

    static func normalized(from rawValue: String?) -> WorkoutMode? {
        guard let rawValue else { return nil }
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let lowercased = trimmed.lowercased()
        if let mode = WorkoutMode(rawValue: lowercased) {
            return mode
        }

        let compact = lowercased
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: " ", with: "")

        switch compact {
        case "strength", "strengthtraining", "weighttraining", "weightlifting", "weights", "lifting", "resistancetraining", "gym":
            return .strength
        case "cardio", "run", "running", "jog", "jogging", "cycle", "cycling", "bike", "biking", "swim", "swimming", "row", "rowing", "walk", "walking", "hike", "hiking", "zone2", "zone2cardio", "elliptical", "stairs", "stairmaster":
            return .cardio
        case "hiit", "interval", "intervals", "sprints", "circuit", "metcon", "conditioning":
            return .hiit
        case "climb", "climbing", "boulder", "bouldering", "rockclimbing":
            return .climbing
        case "yoga":
            return .yoga
        case "pilates", "reformerpilates", "matpilates":
            return .pilates
        case "flexibility", "stretch", "stretching", "rangeofmotion":
            return .flexibility
        case "mobility", "mobilitywork":
            return .mobility
        case "recovery", "restorative", "cooldown", "easycardio", "activerecovery":
            return .recovery
        case "mixed", "hybrid", "crossfit", "crossfitstyle", "sport", "sports":
            return .mixed
        case "custom", "other":
            return .custom
        default:
            let inferred = infer(from: trimmed, focusAreas: [], targetMuscleGroups: [])
            return inferred == .custom ? nil : inferred
        }
    }

    static func infer(from sessionName: String, focusAreas: [String], targetMuscleGroups: [String]) -> WorkoutMode {
        let words = activityWords(from: ([sessionName] + focusAreas + targetMuscleGroups).joined(separator: " "))

        if words.contains("yoga") { return .yoga }
        if words.contains("pilates") { return .pilates }
        if ["climb", "climbing", "boulder", "bouldering"].contains(where: words.contains) { return .climbing }
        if ["hiit", "interval", "intervals", "conditioning"].contains(where: words.contains) { return .hiit }
        if words.contains("mobility") { return .mobility }
        if ["flexibility", "stretch", "stretching"].contains(where: words.contains) { return .flexibility }
        if ["recovery", "cooldown"].contains(where: words.contains) { return .recovery }
        if ["run", "running", "cycle", "cycling", "swim", "swimming", "rowing", "rower", "cardio", "walk", "walking", "hike", "hiking", "stair", "elliptical", "jumprope"].contains(where: words.contains) {
            return .cardio
        }
        if !targetMuscleGroups.isEmpty { return .strength }
        return .custom
    }

    private static func activityWords(from rawValue: String) -> Set<String> {
        let words = rawValue
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let compact = rawValue
            .lowercased()
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: " ", with: "")
        return Set(words + [compact])
    }

    static func personalizedOrder(
        recentModes: [WorkoutMode] = [],
        plannedModes: [WorkoutMode] = [],
        goalModes: [WorkoutMode] = []
    ) -> [WorkoutMode] {
        var scores: [WorkoutMode: Int] = [:]

        for (index, mode) in recentModes.enumerated() {
            scores[mode, default: 0] += max(0, 90 - (index * 8))
        }

        for (index, mode) in plannedModes.enumerated() {
            scores[mode, default: 0] += max(0, 60 - (index * 6))
        }

        for mode in goalModes {
            scores[mode, default: 0] += 24
        }

        return allCases.sorted { lhs, rhs in
            let lhsScore = scores[lhs, default: 0]
            let rhsScore = scores[rhs, default: 0]
            if lhsScore != rhsScore {
                return lhsScore > rhsScore
            }
            return lhs.defaultSortIndex < rhs.defaultSortIndex
        }
    }

    private var defaultSortIndex: Int {
        switch self {
        case .strength: 0
        case .cardio: 1
        case .climbing: 2
        case .yoga: 3
        case .pilates: 4
        case .mobility: 5
        case .flexibility: 6
        case .hiit: 7
        case .mixed: 8
        case .recovery: 9
        case .custom: 10
        }
    }
}
