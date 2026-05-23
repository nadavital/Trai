//
//  WorkoutPlanTemplateDisplay.swift
//  Trai
//

import SwiftUI

extension WorkoutPlan.WorkoutTemplate {
    var displayAccentColor: Color {
        switch sessionType {
        case .strength:
            switch resolvedTargetMuscleGroups.first {
            case "chest", "shoulders", "triceps":
                return .orange
            case "back", "biceps":
                return .blue
            case "quads", "hamstrings", "glutes", "calves", "legs":
                return .green
            case "core":
                return .purple
            default:
                return .accentColor
            }
        case .cardio:
            return .cyan
        case .hiit:
            return .red
        case .climbing:
            return .brown
        case .yoga:
            return .indigo
        case .pilates:
            return .pink
        case .flexibility:
            return .teal
        case .mobility:
            return .purple
        case .mixed:
            return .accentColor
        case .recovery:
            return .mint
        case .custom:
            return .gray
        }
    }

    var displaySubtitle: String {
        if !focusAreasDisplay.isEmpty {
            return focusAreasDisplay
        }
        if !primaryBlockSummary.isEmpty {
            return primaryBlockSummary
        }
        return sessionType.displayName
    }

    var displayWorkloadSummary: String {
        if exerciseCount > 0 {
            let exerciseSummary = "\(exerciseCount) exercise\(exerciseCount == 1 ? "" : "s")"
            guard let supportSummary = activityBlockSummary(includeStrengthBlocks: false, maxItems: 1) else {
                return exerciseSummary
            }
            return "\(exerciseSummary) • \(supportSummary)"
        }

        if let activitySummary = activityBlockSummary(includeStrengthBlocks: true, maxItems: 2) {
            return activitySummary
        }

        if let block = displayBlocks.first {
            return block.displayActivityName
        }

        return sessionType.displayName
    }

    private func activityBlockSummary(includeStrengthBlocks: Bool, maxItems: Int) -> String? {
        var seen = Set<String>()
        let names = displayBlocks.compactMap { block -> String? in
            guard includeStrengthBlocks || block.kind != .strength else { return nil }
            let name = block.displayActivityName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { return nil }
            let key = name.goalNormalizedKey
            guard !key.isEmpty, seen.insert(key).inserted else { return nil }
            return name
        }

        guard !names.isEmpty else { return nil }
        let visibleNames = names.prefix(maxItems)
        let suffixCount = names.count - visibleNames.count
        let base = visibleNames.joined(separator: " • ")
        return suffixCount > 0 ? "\(base) +\(suffixCount)" : base
    }
}
