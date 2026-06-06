//
//  GeneralWorkoutComponents.swift
//  Trai
//

import SwiftUI

struct GeneralSessionOverviewCard: View {
    let workout: LiveWorkout

    private var primaryTitle: String {
        workout.displayFocusAreas.first ?? workout.type.displayName
    }

    private var subtitle: String {
        primaryTitle == workout.type.displayName ? "Activity session" : "\(workout.type.displayName) session"
    }

    private var supportingFocusAreas: [String] {
        workout.displayFocusAreas.filter { $0.goalNormalizedKey != primaryTitle.goalNormalizedKey }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: workout.type.iconName)
                    .font(.title3)
                    .foregroundStyle(workout.type == .custom ? .secondary : Color.accentColor)
                    .frame(width: 40, height: 40)
                    .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 2) {
                    Text(primaryTitle)
                        .font(.headline)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            if !supportingFocusAreas.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(supportingFocusAreas, id: \.self) { focus in
                        Text(focus)
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color(.tertiarySystemFill), in: Capsule())
                    }
                }
            }

            Text("Log activities and notes with full session context.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(.rect(cornerRadius: 16))
    }
}

struct SessionNotesCard: View {
    @Binding var notes: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Session Notes", systemImage: "note.text")
                .font(.headline)

            Text("Capture cues, observations, route grades, flow notes, or anything you want Trai to understand.")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextEditor(text: $notes)
                .frame(minHeight: 96)
                .padding(8)
                .scrollContentBackground(.hidden)
                .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 12))
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(.rect(cornerRadius: 16))
    }
}

struct GeneralActivityCard: View {
    let entry: LiveWorkoutEntry
    var allowsDeletion: Bool = true
    var showsEditableFields: Bool = true
    var isPlannedGuidance: Bool = false
    let onUpdateNotes: (String) -> Void
    let onUpdateDuration: (Int?) -> Void
    let onDelete: () -> Void

    private var durationMinutesBinding: Binding<String> {
        Binding(
            get: {
                let seconds = entry.trackedDurationSeconds
                guard seconds > 0 else { return "" }
                return String(seconds / 60)
            },
            set: { newValue in
                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else {
                    onUpdateDuration(nil)
                    return
                }
                onUpdateDuration(Int(trimmed).map { $0 * 60 })
            }
        )
    }

    private var notesBinding: Binding<String> {
        Binding(
            get: { entry.notes },
            set: onUpdateNotes
        )
    }

    private var hasLoggedData: Bool {
        entry.completedAt != nil || entry.hasExercisePreferenceSignal
    }

    private var statusText: String {
        if let completedAt = entry.completedAt {
            return "Logged \(completedAt.formatted(date: .omitted, time: .shortened))"
        }
        if hasLoggedData {
            return "Logged in this workout"
        }
        return "Added to this workout"
    }

    private var metadataChips: [ActivityMetadataChip] {
        guard !isPlannedGuidance else { return [] }

        var chips: [ActivityMetadataChip] = []

        func appendUnique(title: String, icon: String) {
            let normalized = title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !normalized.isEmpty,
                  !chips.contains(where: { $0.title.lowercased() == normalized }) else {
                return
            }
            chips.append(ActivityMetadataChip(title: title, icon: icon))
        }

        let activityName = entry.activityTypeName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !activityName.isEmpty, activityName.goalNormalizedKey != entry.exerciseName.goalNormalizedKey {
            appendUnique(title: activityName, icon: entry.activityIconName)
        }
        return chips
    }

    var body: some View {
        VStack(alignment: .leading, spacing: isPlannedGuidance ? 8 : 12) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: entry.activityIconName)
                    .font(.subheadline)
                    .foregroundStyle(hasLoggedData ? .green : .secondary)
                    .frame(width: 34, height: 34)
                    .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.exerciseName)
                        .font(isPlannedGuidance ? .subheadline.weight(.semibold) : .headline)

                    if !isPlannedGuidance {
                        Text(statusText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if allowsDeletion && !isPlannedGuidance {
                    Button(role: .destructive, action: onDelete) {
                        Image(systemName: "trash")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }

            if !metadataChips.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(metadataChips) { chip in
                        Label(chip.title, systemImage: chip.icon)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color(.tertiarySystemFill), in: Capsule())
                    }
                }
            }

            if showsEditableFields {
                HStack(spacing: 10) {
                    Label("Duration", systemImage: "clock")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    TextField("Minutes", text: durationMinutesBinding)
                        .keyboardType(.numberPad)
                        .font(.subheadline)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 10))
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Activity Notes")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    TextField("What did you work on?", text: notesBinding, axis: .vertical)
                        .lineLimit(2...5)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 12))
                }
            } else if !isPlannedGuidance {
                VStack(alignment: .leading, spacing: 8) {
                    if let duration = entry.formattedDuration {
                        Label(duration, systemImage: "clock")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if !entry.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(entry.notes)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
        }
        .padding(isPlannedGuidance ? 14 : 16)
        .background(Color(.secondarySystemBackground).opacity(isPlannedGuidance ? 0.72 : 1))
        .clipShape(.rect(cornerRadius: isPlannedGuidance ? 14 : 16))
    }
}

private struct ActivityMetadataChip: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
}

struct AddGeneralActivitySheet: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let onAdd: (String, String, Int?, WorkoutPlan.TrainingBlock.BlockKind, WorkoutPlan.TrainingBlock.Role) -> Void

    @State private var activityName = ""
    @State private var activityNotes = ""
    @State private var durationMinutes = ""
    @State private var selectedCategory: Exercise.Category = .custom
    @State private var selectedRole: WorkoutPlan.TrainingBlock.Role = .main

    private var placementOptions: [(role: WorkoutPlan.TrainingBlock.Role, label: String)] {
        [
            .main,
            .warmup,
            .accessory,
            .finisher,
            .cooldown
        ].map { ($0, $0.displayName) }
    }

    private var categoryOptions: [Exercise.Category] {
        Exercise.Category.userFacingCases.filter { $0 != .strength }
    }

    private var selectedKind: WorkoutPlan.TrainingBlock.BlockKind {
        selectedCategory.liveWorkoutActivityKind ?? .custom
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Activity", systemImage: "square.and.pencil")
                            .font(.headline)

                        TextField("e.g. V4 bouldering, Flow block, Breathing work", text: $activityName)
                            .padding(12)
                            .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 12))

                        FlowLayout(spacing: 8) {
                            ForEach(categoryOptions) { category in
                                Button {
                                    selectedCategory = category
                                    HapticManager.selectionChanged()
                                } label: {
                                    Label(category.displayName, systemImage: category.iconName)
                                        .font(.caption.weight(.semibold))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(
                                            selectedCategory == category ? Color.accentColor : Color(.tertiarySystemFill),
                                            in: Capsule()
                                        )
                                        .foregroundStyle(selectedCategory == category ? .white : .primary)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        FlowLayout(spacing: 8) {
                            ForEach(placementOptions, id: \.role) { option in
                                Button {
                                    selectedRole = option.role
                                } label: {
                                    Text(option.label)
                                        .font(.caption.weight(.semibold))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(
                                            selectedRole == option.role ? Color.accentColor : Color(.tertiarySystemFill),
                                            in: Capsule()
                                        )
                                        .foregroundStyle(selectedRole == option.role ? .white : .primary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(.rect(cornerRadius: 16))

                    VStack(alignment: .leading, spacing: 12) {
                        Label("Duration", systemImage: "clock")
                            .font(.headline)

                        TextField("Minutes (optional)", text: $durationMinutes)
                            .keyboardType(.numberPad)
                            .padding(12)
                            .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 12))
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(.rect(cornerRadius: 16))

                    VStack(alignment: .leading, spacing: 12) {
                        Label("Notes", systemImage: "note.text")
                            .font(.headline)

                        TextEditor(text: $activityNotes)
                            .frame(minHeight: 120)
                            .padding(8)
                            .scrollContentBackground(.hidden)
                            .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 12))
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(.rect(cornerRadius: 16))
                }
                .padding()
            }
            .navigationTitle(title)
            .toolbarTitleDisplayMode(.inlineLarge)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add", systemImage: "checkmark") {
                        onAdd(
                            activityName,
                            activityNotes,
                            Int(durationMinutes.trimmingCharacters(in: .whitespacesAndNewlines)).map { $0 * 60 },
                            selectedKind,
                            selectedRole
                        )
                        dismiss()
                    }
                    .labelStyle(.iconOnly)
                    .disabled(activityName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .tint(.accentColor)
                }
            }
        }
        .traiSheetBranding()
    }
}
