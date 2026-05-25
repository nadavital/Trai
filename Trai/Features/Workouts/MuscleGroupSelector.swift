//
//  MuscleGroupSelector.swift
//  Trai
//
//  Inline muscle group selection component for workouts
//

import SwiftUI

// MARK: - Muscle Group Selector

struct MuscleGroupSelector: View {
    struct PlanTarget: Identifiable, Equatable {
        let id: UUID
        let title: String
        let iconName: String
        let muscles: [LiveWorkout.MuscleGroup]
        let categories: [Exercise.Category]
        let activityTypes: [String]
    }

    struct ActivityTypeTarget: Identifiable, Equatable {
        let id: String
        let title: String
        let iconName: String
        let categories: [Exercise.Category]
    }

    @Binding var selectedMuscles: Set<LiveWorkout.MuscleGroup>
    @Binding var selectedActivityCategories: Set<Exercise.Category>
    @Binding var selectedActivityTypes: Set<String>
    let isCustomWorkout: Bool
    var planTargets: [PlanTarget] = []
    var activityTypeTargets: [ActivityTypeTarget] = []
    var showsMuscleTargets: Bool = true
    var onSelectPlanTarget: ((PlanTarget) -> Void)?

    @State private var isExpanded: Bool = false

    private let activityTargets: [Exercise.Category] = [.cardio, .conditioning, .mobility, .sportPractice, .recovery]

    private var displayedActivityTargets: [Exercise.Category] {
        activityTargets
    }

    private var displayedActivityCategories: [Exercise.Category] {
        let impliedCategories = Set(
            activityTypeTargets
                .filter { selectedActivityTypes.contains($0.title) }
                .flatMap { $0.categories.flatMap { Array($0.suggestionCategories) } }
        )
        return selectedActivityCategories
            .filter { category in
                impliedCategories.isDisjoint(with: category.suggestionCategories)
            }
            .sorted { $0.displayName < $1.displayName }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header - tap to expand/collapse target muscles.
            Button {
                withAnimation(.snappy) { isExpanded.toggle() }
                HapticManager.lightTap()
            } label: {
                HStack {
                    if selectedMuscles.isEmpty && selectedActivityCategories.isEmpty && selectedActivityTypes.isEmpty {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(.accent)
                        Text("Choose workout targets")
                            .foregroundStyle(.secondary)
                    } else {
                        Image(systemName: "scope")
                            .foregroundStyle(.accent)
                        Text("Targeting")
                            .foregroundStyle(.secondary)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(Array(selectedMuscles).sorted { $0.displayName < $1.displayName }) { muscle in
                                    SelectedTargetChip(title: muscle.displayName)
                                }
                                ForEach(displayedActivityCategories) { category in
                                    SelectedTargetChip(title: category.displayName)
                                }
                                ForEach(Array(selectedActivityTypes).sorted(), id: \.self) { activityType in
                                    SelectedTargetChip(title: activityType)
                                }
                            }
                        }
                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .font(.subheadline)
            }
            .buttonStyle(.plain)

            // Expanded selection
            if isExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    if !planTargets.isEmpty {
                        horizontalTargetRow {
                            ForEach(planTargets) { target in
                                PlanTargetChip(
                                    target: target,
                                    isSelected: isPlanTargetSelected(target)
                                ) {
                                    selectPlanTarget(target)
                                }
                            }
                        }
                    }

                    if !activityTypeTargets.isEmpty {
                        horizontalTargetRow {
                            ForEach(activityTypeTargets) { target in
                                ActivityTypeTargetChip(
                                    target: target,
                                    isSelected: isActivityTypeTargetSelected(target)
                                ) {
                                    toggleActivityTypeTarget(target)
                                }
                            }
                        }
                    }

                    horizontalTargetRow {
                        ForEach(displayedActivityTargets) { category in
                            ActivityTargetChip(
                                category: category,
                                isSelected: isActivityCategorySelected(category)
                            ) {
                                toggleActivityCategory(category)
                            }
                        }
                    }

                    if showsMuscleTargets {
                        horizontalTargetRow {
                            ForEach(LiveWorkout.MuscleGroup.allCases.filter { $0 != .fullBody }) { muscle in
                                MuscleSelectChip(
                                    muscle: muscle,
                                    isSelected: selectedMuscles.contains(muscle)
                                ) {
                                    toggleMuscle(muscle)
                                }
                            }
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(.rect(cornerRadius: 12))
        .onAppear {
            // Auto-expand for custom workouts with no muscles selected
            if isCustomWorkout && selectedMuscles.isEmpty && selectedActivityCategories.isEmpty && selectedActivityTypes.isEmpty {
                isExpanded = true
            }
        }
    }

    private func toggleMuscle(_ muscle: LiveWorkout.MuscleGroup) {
        if selectedMuscles.contains(muscle) {
            selectedMuscles.remove(muscle)
        } else {
            selectedMuscles.insert(muscle)
        }
        HapticManager.selectionChanged()
    }

    private func toggleActivityCategory(_ category: Exercise.Category) {
        if isActivityCategorySelected(category) {
            selectedActivityCategories.subtract(category.suggestionCategories)
        } else {
            selectedActivityCategories.formUnion(category.suggestionCategories)
        }
        HapticManager.selectionChanged()
    }

    private func isActivityCategorySelected(_ category: Exercise.Category) -> Bool {
        !selectedActivityCategories.isDisjoint(with: category.suggestionCategories)
    }

    private func selectPlanTarget(_ target: PlanTarget) {
        selectedMuscles = Set(target.muscles)
        selectedActivityCategories = Set(target.categories.flatMap { Array($0.suggestionCategories) })
        selectedActivityTypes = Set(target.activityTypes)
        onSelectPlanTarget?(target)
        HapticManager.selectionChanged()
    }

    private func isPlanTargetSelected(_ target: PlanTarget) -> Bool {
        guard !target.muscles.isEmpty || !target.categories.isEmpty || !target.activityTypes.isEmpty else { return false }
        let targetMuscles = Set(target.muscles)
        let targetCategories = Set(target.categories.flatMap { Array($0.suggestionCategories) })
        return selectedMuscles == targetMuscles
            && selectedActivityCategories == targetCategories
            && selectedActivityTypes == Set(target.activityTypes)
    }

    private func toggleActivityTypeTarget(_ target: ActivityTypeTarget) {
        if isActivityTypeTargetSelected(target) {
            selectedActivityTypes.remove(target.title)
        } else {
            selectedActivityTypes.insert(target.title)
            selectedActivityCategories.formUnion(target.categories.flatMap { Array($0.suggestionCategories) })
        }
        HapticManager.selectionChanged()
    }

    private func isActivityTypeTargetSelected(_ target: ActivityTypeTarget) -> Bool {
        selectedActivityTypes.contains(target.title)
    }

    private func horizontalTargetRow<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                content()
            }
            .padding(.horizontal, 1)
        }
        .scrollClipDisabled()
    }

}

private struct PlanTargetChip: View {
    let target: MuscleGroupSelector.PlanTarget
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: target.iconName)
                    .font(.caption2)
                Text(target.title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background(isSelected ? Color.accentColor : Color.accentColor.opacity(0.12))
            .foregroundStyle(isSelected ? .white : Color.accentColor)
            .clipShape(.capsule)
        }
        .buttonStyle(.plain)
    }
}

private struct ActivityTypeTargetChip: View {
    let target: MuscleGroupSelector.ActivityTypeTarget
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: target.iconName)
                    .font(.caption2)
                Text(target.title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background(isSelected ? Color.accentColor : Color(.tertiarySystemFill))
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(.capsule)
        }
        .buttonStyle(.plain)
    }
}

private struct SelectedTargetChip: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.accentColor.opacity(0.15))
            .clipShape(.capsule)
    }
}

// MARK: - Muscle Select Chip

private struct MuscleSelectChip: View {
    let muscle: LiveWorkout.MuscleGroup
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: muscle.iconName)
                    .font(.caption2)
                Text(muscle.displayName)
                    .font(.caption)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isSelected ? Color.accentColor : Color(.tertiarySystemFill))
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(.capsule)
        }
        .buttonStyle(.plain)
    }
}

private struct ActivityTargetChip: View {
    let category: Exercise.Category
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: category.iconName)
                    .font(.caption2)
                Text(category.displayName)
                    .font(.caption)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isSelected ? Color.accentColor : Color(.tertiarySystemFill))
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(.capsule)
        }
        .buttonStyle(.plain)
    }
}
