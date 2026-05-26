//
//  WorkoutGeneratedGoalComponents.swift
//  Trai
//

import SwiftUI

struct GeneratedWorkoutGoalsCard: View {
    let goals: [WorkoutGoal]
    var title: String = "Goals Trai will track"
    var isCompact: Bool = false
    var maxVisibleGoals: Int? = nil
    let onSelect: (WorkoutGoal) -> Void

    private var visibleGoals: [WorkoutGoal] {
        guard let maxVisibleGoals else { return goals }
        return Array(goals.prefix(maxVisibleGoals))
    }

    var body: some View {
        GeneratedWorkoutGoalsCardContainer(title: title, isCompact: isCompact) {
            VStack(spacing: 8) {
                ForEach(visibleGoals, id: \.id) { goal in
                    GeneratedWorkoutGoalRow(
                        goal: goal,
                        isCompact: isCompact,
                        onSelect: { onSelect(goal) }
                    )
                }
            }
        }
    }
}

struct GeneratedWorkoutGoalsCardContainer<Content: View>: View {
    var title: String = "Goals Trai will track"
    var isCompact: Bool = false
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: isCompact ? 8 : 12) {
            HStack(spacing: 8) {
                Image(systemName: "flag.checkered")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.accent)

                Text(title)
                    .font(.subheadline.weight(.bold))

                Spacer(minLength: 0)
            }

            content
        }
        .padding(isCompact ? 12 : 14)
        .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.accentColor.opacity(0.22), lineWidth: 1)
        }
    }
}

struct GeneratedWorkoutGoalRow: View {
    let goal: WorkoutGoal
    var isCompact: Bool = false
    let onSelect: () -> Void

    var body: some View {
        Button {
            HapticManager.lightTap()
            onSelect()
        } label: {
            GeneratedWorkoutGoalRowContent(
                goal: goal,
                isCompact: isCompact,
                showsChevron: true
            )
            .padding(isCompact ? 8 : 10)
            .background(Color(.tertiarySystemFill).opacity(0.55), in: .rect(cornerRadius: 13, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct SelectableGeneratedWorkoutGoalRow: View {
    let goal: WorkoutGoal
    let isSelected: Bool
    var isCompact: Bool = false
    let onSelect: () -> Void
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button {
                HapticManager.lightTap()
                onSelect()
            } label: {
                GeneratedWorkoutGoalRowContent(
                    goal: goal,
                    isCompact: isCompact,
                    showsChevron: false
                )
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            Button {
                onToggle()
            } label: {
                Label(isSelected ? "Added" : "Add", systemImage: isSelected ? "checkmark" : "plus")
                    .font(.caption.weight(.semibold))
                    .labelStyle(.titleAndIcon)
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                    .padding(.horizontal, 10)
                    .frame(height: 30)
                    .background(
                        isSelected ? Color.accentColor.opacity(0.12) : Color(.quaternarySystemFill),
                        in: Capsule()
                    )
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isSelected ? "Remove goal" : "Select goal")
        }
        .padding(isCompact ? 8 : 10)
        .background(
            Color(.tertiarySystemFill).opacity(0.55),
            in: .rect(cornerRadius: 13, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(isSelected ? Color.accentColor.opacity(0.22) : Color.clear, lineWidth: 1)
        }
    }
}

struct GeneratedWorkoutGoalDetailSheet: View {
    @Environment(\.dismiss) private var dismiss

    let goal: WorkoutGoal
    var rationale: String? = nil
    var selection: Selection? = nil

    struct Selection {
        let isSelected: Bool
        let onToggle: () -> Void
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    headerCard
                    detailCard
                    if let selection {
                        selectionButton(selection)
                    }
                }
                .padding()
            }
            .navigationTitle("Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", systemImage: "checkmark") {
                        dismiss()
                    }
                    .labelStyle(.iconOnly)
                    .tint(.accentColor)
                }
            }
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: goal.goalKind.iconName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.accent)
                    .frame(width: 34, height: 34)
                    .background(Color.accentColor.opacity(0.12), in: Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(goal.title)
                        .font(.headline.weight(.bold))
                        .fixedSize(horizontal: false, vertical: true)

                    if let trackingSummary = goal.trackingSummary {
                        Text(trackingSummary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if let rationale = rationale?.trimmingCharacters(in: .whitespacesAndNewlines), !rationale.isEmpty {
                Text(rationale)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 16, style: .continuous))
    }

    private var detailCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !goal.trimmedSuccessCriteria.isEmpty {
                goalDetailRow(
                    title: "How Trai verifies it",
                    value: goal.trimmedSuccessCriteria,
                    icon: "checkmark.seal.fill"
                )
            }

            if let supportingSummary = goal.supportingSummary, supportingSummary != goal.trimmedSuccessCriteria {
                goalDetailRow(
                    title: "Notes",
                    value: supportingSummary,
                    icon: "text.bubble.fill"
                )
            }

            goalDetailRow(
                title: "Scope",
                value: goal.scopeSummary,
                icon: "scope"
            )

            if let horizonSummary = goal.horizonSummary, !horizonSummary.isEmpty {
                goalDetailRow(
                    title: "Timeline",
                    value: horizonSummary,
                    icon: "calendar"
                )
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 16, style: .continuous))
    }

    @ViewBuilder
    private func selectionButton(_ selection: Selection) -> some View {
        if selection.isSelected {
            Button {
                selection.onToggle()
            } label: {
                Label("Selected", systemImage: "checkmark.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.traiSecondary(color: Color.accentColor, fullWidth: true))
        } else {
            Button {
                selection.onToggle()
            } label: {
                Label("Add Goal", systemImage: "plus.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.traiPrimary(fullWidth: true))
        }
    }

    private func goalDetailRow(title: String, value: String, icon: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.accent)
                .frame(width: 20)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text(value)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct GeneratedWorkoutGoalRowContent: View {
    let goal: WorkoutGoal
    let isCompact: Bool
    let showsChevron: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            goalIcon

            VStack(alignment: .leading, spacing: isCompact ? 1 : 3) {
                Text(goal.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(isCompact ? 1 : 2)

                Text(goal.generatedGoalDetailText)
                    .font(isCompact ? .caption2 : .caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .padding(.top, isCompact ? 3 : 7)
            }
        }
    }

    @ViewBuilder
    private var goalIcon: some View {
        if isCompact {
            Image(systemName: goal.goalKind.iconName)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.accent)
                .frame(width: 18, height: 18)
                .padding(.top, 2)
        } else {
            Image(systemName: goal.goalKind.iconName)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.accent)
                .frame(width: 28, height: 28)
                .background(Color.accentColor.opacity(0.12), in: Circle())
        }
    }
}

extension WorkoutGoal {
    var generatedGoalDetailText: String {
        let trackingSummary = trackingSummary
        let supportingSummary = supportingSummary
        return [
            trackingSummary,
            scopeSummary,
            supportingSummary == trackingSummary ? nil : supportingSummary,
            horizonSummary
        ]
        .compactMap { $0 }
        .filter { !$0.isEmpty }
        .joined(separator: " • ")
    }
}
