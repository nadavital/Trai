//
//  CustomExercisesView.swift
//  Trai
//
//  Manage reusable exercises and activities - view, edit, and delete
//

import SwiftUI
import SwiftData

struct CustomExercisesView: View {
    @Environment(\.modelContext) private var modelContext

    // Use @State + manual fetch instead of @Query to avoid navigation freeze
    @State private var customExercises: [Exercise] = []
    @State private var searchText = ""
    @State private var showingDeleteConfirmation = false
    @State private var exerciseToDelete: Exercise?
    @State private var showingAddCustomExercise = false

    private var filteredExercises: [Exercise] {
        if searchText.isEmpty {
            return customExercises
        }
        return customExercises.filter { exercise in
            exercise.name.localizedStandardContains(searchText)
                || exercise.activityTypeName.localizedStandardContains(searchText)
                || exercise.activityAliases.contains { $0.localizedStandardContains(searchText) }
                || exercise.targetTags.contains { $0.localizedStandardContains(searchText) }
                || exercise.exerciseCategory.displayName.localizedStandardContains(searchText)
                || exercise.trackingFields.contains { $0.displayName.localizedStandardContains(searchText) }
                || (exercise.displayEquipment?.localizedStandardContains(searchText) ?? false)
        }
    }

    private var exercisesByTarget: [String: [Exercise]] {
        Dictionary(grouping: filteredExercises) { exercise in
            let activityName = exercise.activityTypeName.trimmingCharacters(in: .whitespacesAndNewlines)
            return activityName.isEmpty
                ? Exercise.defaultActivityTypeName(for: exercise.name, category: exercise.exerciseCategory)
                : activityName
        }
    }

    var body: some View {
        List {
            if customExercises.isEmpty {
                VStack(spacing: 16) {
                    ContentUnavailableView(
                        "No Custom Items",
                        systemImage: "dumbbell",
                        description: Text("Exercises and activities you create will appear here")
                    )

                    Button("Add Item", systemImage: "plus") {
                        showingAddCustomExercise = true
                    }
                    .buttonStyle(.traiSecondary(color: .accentColor, fullWidth: false))
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            } else if filteredExercises.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else {
                ForEach(exercisesByTarget.keys.sorted(), id: \.self) { target in
                    Section(target) {
                        ForEach(exercisesByTarget[target] ?? []) { exercise in
                            ExerciseManagementRow(exercise: exercise)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        exerciseToDelete = exercise
                                        showingDeleteConfirmation = true
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    }
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search exercises and activities")
        .navigationTitle("Exercise Library")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Add", systemImage: "plus") {
                    showingAddCustomExercise = true
                }
            }
        }
        .onAppear {
            fetchCustomExercises()
        }
        .sheet(isPresented: $showingAddCustomExercise) {
            AddCustomExerciseSheet(initialName: "") { name, activityTypeName, activityAliases, muscleGroup, category, secondaryMuscles, targetTags, trackingFields in
                addCustomExercise(
                    name: name,
                    activityTypeName: activityTypeName,
                    activityAliases: activityAliases,
                    muscleGroup: muscleGroup,
                    category: category,
                    secondaryMuscles: secondaryMuscles,
                    targetTags: targetTags,
                    trackingFields: trackingFields
                )
            }
            .traiSheetBranding()
        }
        .confirmationDialog(
            "Delete Exercise?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let exercise = exerciseToDelete {
                    deleteExercise(exercise)
                }
            }
            Button("Cancel", role: .cancel) {
                exerciseToDelete = nil
            }
        } message: {
            if let exercise = exerciseToDelete {
                Text("Are you sure you want to delete \"\(exercise.name)\"? This cannot be undone.")
            }
        }
    }

    private func fetchCustomExercises() {
        let descriptor = FetchDescriptor<Exercise>(
            predicate: #Predicate { $0.isCustom == true },
            sortBy: [SortDescriptor(\.name)]
        )
        customExercises = (try? modelContext.fetch(descriptor)) ?? []
    }

    private func deleteExercise(_ exercise: Exercise) {
        modelContext.delete(exercise)
        try? modelContext.save()
        exerciseToDelete = nil
        HapticManager.lightTap()
        // Refresh the list
        fetchCustomExercises()
    }

    private func addCustomExercise(
        name: String,
        activityTypeName: String,
        activityAliases: [String] = [],
        muscleGroup: Exercise.MuscleGroup?,
        category: Exercise.Category,
        secondaryMuscles: [String]? = nil,
        targetTags: [String] = [],
        trackingFields: [Exercise.TrackingField] = []
    ) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let resolvedCategory = category.userFacingEquivalent
        let resolvedActivityName = activityTypeName
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let displayActivityName = resolvedActivityName.isEmpty
            ? Exercise.defaultActivityTypeName(for: trimmed, category: resolvedCategory)
            : resolvedActivityName

        if let existing = existingExercise(named: trimmed) {
            let canSafelyRefreshCategory = existing.isCustom
                || existing.sessions?.isEmpty != false
                || existing.exerciseCategory == .custom
            if canSafelyRefreshCategory {
                existing.exerciseCategory = resolvedCategory
            }
            existing.isCustom = true
            if existing.exerciseCategory == .strength {
                if existing.targetMuscleGroup == nil,
                   let muscleGroup {
                    existing.targetMuscleGroup = muscleGroup
                }
            } else {
                existing.muscleGroup = nil
            }
            if let secondaryMuscles,
               !secondaryMuscles.isEmpty,
               existing.exerciseCategory == .strength,
               (existing.secondaryMuscles?.isEmpty ?? true) {
                existing.secondaryMuscles = secondaryMuscles.joined(separator: ",")
            } else if existing.exerciseCategory != .strength {
                existing.secondaryMuscles = nil
            }
            if !targetTags.isEmpty {
                existing.targetTags = targetTags
            }
            if !trackingFields.isEmpty {
                existing.trackingFields = trackingFields
            }
            existing.activityTypeName = displayActivityName
            if !activityAliases.isEmpty {
                existing.activityAliases = activityAliases
            }
            try? modelContext.save()
            fetchCustomExercises()
            HapticManager.success()
            return
        }

        let exercise = Exercise(
            name: trimmed,
            category: resolvedCategory,
            muscleGroup: resolvedCategory == .strength ? muscleGroup : nil
        )
        exercise.isCustom = true
        exercise.activityTypeName = displayActivityName
        exercise.activityAliases = activityAliases
        exercise.targetTags = targetTags.isEmpty ? Exercise.defaultTargetTags(for: resolvedCategory) : targetTags
        exercise.trackingFields = trackingFields.isEmpty ? Exercise.defaultTrackingFields(for: resolvedCategory) : trackingFields
        if let secondaryMuscles, !secondaryMuscles.isEmpty {
            exercise.secondaryMuscles = secondaryMuscles.joined(separator: ",")
        }
        modelContext.insert(exercise)
        try? modelContext.save()
        fetchCustomExercises()
        HapticManager.success()
    }

    private func existingExercise(named name: String) -> Exercise? {
        let descriptor = FetchDescriptor<Exercise>(sortBy: [SortDescriptor(\.name)])
        let allExercises = (try? modelContext.fetch(descriptor)) ?? []
        return allExercises.first { $0.name.lowercased() == name.lowercased() }
    }
}

// MARK: - Exercise Row

private struct ExerciseManagementRow: View {
    let exercise: Exercise

    var body: some View {
        HStack(spacing: 12) {
            // Category icon
            Image(systemName: exercise.exerciseCategory.iconName)
                .font(.title3)
                .foregroundStyle(.accent)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.name)
                    .font(.body)

                HStack(spacing: 8) {
                    Text(displayActivityName)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let target = exercise.targetTags.first {
                        Text("•")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        Text(target)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let equipment = exercise.displayEquipment {
                        Text("•")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        Text(equipment)
                            .font(.caption)
                            .foregroundStyle(.accent)
                    }
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    private var displayActivityName: String {
        let activityName = exercise.activityTypeName.trimmingCharacters(in: .whitespacesAndNewlines)
        return activityName.isEmpty
            ? Exercise.defaultActivityTypeName(for: exercise.name, category: exercise.exerciseCategory)
            : activityName
    }
}
