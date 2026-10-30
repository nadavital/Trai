import SwiftUI

/// Split illustration concepts; never personal usage rankings or exercise prescriptions.
enum WorkoutSplitIdentity: String, CaseIterable {
    case push, pull, legs, upper, lower, arms, fullBody
    var cell: (column: Int, row: Int) {
        switch self {
        case .push: (0, 0)
        case .pull: (1, 0)
        case .legs: (2, 0)
        case .upper, .fullBody: (0, 1)
        case .lower: (1, 1)
        case .arms: (2, 1)
        }
    }
    static func resolve(name: String, muscleTargets: [String]) -> Self? {
        let words = Set(name.lowercased().split(whereSeparator: { !$0.isLetter }).map(String.init))
        for value in [Self.push, .pull, .legs, .upper, .lower, .arms] where words.contains(value.rawValue) { return value }
        let groups = Set(muscleTargets.flatMap(LiveWorkout.MuscleGroup.fromTargetString))
        let lower: Set<LiveWorkout.MuscleGroup> = [.quads, .hamstrings, .glutes, .calves]
        let arms: Set<LiveWorkout.MuscleGroup> = [.biceps, .triceps, .forearms]
        guard !groups.isEmpty else { return nil }
        if groups.contains(.fullBody) || (!groups.isDisjoint(with: lower) && !groups.subtracting(lower).isEmpty) { return .fullBody }
        if groups.isSubset(of: lower) { return .legs }
        if groups.isSubset(of: arms) { return .arms }
        if groups.isSubset(of: [.chest, .shoulders, .triceps]) { return .push }
        if groups.isSubset(of: [.back, .biceps, .forearms]) { return .pull }
        return .upper
    }
    static func resolve(_ template: WorkoutPlan.WorkoutTemplate) -> Self? {
        guard template.sessionType.supportsMuscleTargets else { return nil }
        return resolve(name: template.name, muscleTargets: template.resolvedTargetMuscleGroups)
    }
}

/// Genuine Blender equipment concepts; native labels carry the session semantics.
struct WorkoutSplitArtwork: View {
    let identity: WorkoutSplitIdentity
    var role: WorkoutArtworkRole = .card
    private var split: String? {
        switch identity {
        case .push: "Push"
        case .pull: "Pull"
        case .legs, .lower: nil
        case .arms: "Arms"
        case .upper: "Upper"
        case .fullBody: nil
        }
    }
    var body: some View {
        if let split {
            let export = role == .hero ? "Hero720" : role == .row ? "Nav120" : "Card228"
            Image("PrototypeBlender" + split + export).resizable().scaledToFit().accessibilityHidden(true)
        } else { WorkoutRenderedActivityAsset(key: "Strength", role: role) }
    }
}

enum WorkoutArtworkRole { case hero, card, row }
struct WorkoutRenderedActivityAsset: View {
    let key: String
    var role: WorkoutArtworkRole = .card
    var body: some View {
        Image("PrototypeResin" + key + (role == .hero ? "Hero" : role == .row ? (["Plan", "Custom", "Mobility"].contains(key) ? "Nav" : "Row") : "Card"))
            .resizable().scaledToFit().accessibilityHidden(true)
    }
}
struct WorkoutTemplateArtwork: View {
    let template: WorkoutPlan.WorkoutTemplate
    var role: WorkoutArtworkRole = .card
    var body: some View {
        if template.sessionType == .strength, let split = WorkoutSplitIdentity.resolve(template) {
            WorkoutSplitArtwork(identity: split, role: role)
        } else if let key = Self.activityKey(for: template) {
            WorkoutRenderedActivityAsset(key: key, role: role)
        } else {
            // No approved illustration exists for this activity: keep its truthful native label.
            Image(systemName: template.sessionType.iconName).font(.largeTitle).foregroundStyle(.secondary).accessibilityHidden(true)
        }
    }
    static func activityKey(for template: WorkoutPlan.WorkoutTemplate) -> String? {
        if template.sessionType == .strength { return "Strength" }
        if template.sessionType == .custom { return "Custom" }
        if template.sessionType == .climbing { return "Climbing" }
        if [.mobility, .yoga].contains(template.sessionType) { return "Mobility" }
        let focus = Set(template.focusAreas.map { $0.lowercased() })
        if template.sessionType == .cardio && !focus.isEmpty {
            if focus.isSubset(of: ["cycling", "biking", "bike"]) { return "Cycling" }
            if focus.isSubset(of: ["walking", "running"]) { return "Footwear" }
            if focus.isSubset(of: ["hiking"]) { return "Hiking" }
        }
        if template.sessionType == .mixed && !template.resolvedTargetMuscleGroups.isEmpty && !focus.isEmpty && focus.isSubset(of: ["walking", "running"]) { return "Mixed" }
        return nil
    }
}
