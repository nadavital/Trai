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

    private var exerciseSections: [ExerciseLibrarySection] {
        let grouped = Dictionary(grouping: filteredExercises) { exercise in
            exercise.exerciseCategory.userFacingEquivalent
        }
        let orderedCategories = Exercise.Category.userFacingCases
        return orderedCategories.compactMap { category in
            guard let exercises = grouped[category], !exercises.isEmpty else { return nil }
            return ExerciseLibrarySection(
                category: category,
                exercises: exercises.sorted { lhs, rhs in
                    let lhsActivity = displayActivityName(for: lhs)
                    let rhsActivity = displayActivityName(for: rhs)
                    if lhsActivity != rhsActivity {
                        return lhsActivity.localizedStandardCompare(rhsActivity) == .orderedAscending
                    }
                    return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
                }
            )
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                if customExercises.isEmpty {
                    emptyState
                        .padding(.top, 48)
                } else if filteredExercises.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                        .padding(.top, 48)
                } else {
                    librarySummaryCard

                    ForEach(exerciseSections) { section in
                        ExerciseLibrarySectionCard(
                            section: section,
                            onDelete: { exercise in
                                exerciseToDelete = exercise
                                showingDeleteConfirmation = true
                            }
                        )
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
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

    private var emptyState: some View {
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
    }

    private var librarySummaryCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "square.grid.2x2.fill")
                .font(.headline)
                .foregroundStyle(.accent)
                .frame(width: 38, height: 38)
                .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 2) {
                Text("\(filteredExercises.count) custom item\(filteredExercises.count == 1 ? "" : "s")")
                    .font(.traiHeadline())

                Text("Organized by category, activity group, targets, and tracking.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .traiCard(cornerRadius: 16, contentPadding: 0)
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

    private func displayActivityName(for exercise: Exercise) -> String {
        let activityName = exercise.activityTypeName.trimmingCharacters(in: .whitespacesAndNewlines)
        return activityName.isEmpty
            ? Exercise.defaultActivityTypeName(for: exercise.name, category: exercise.exerciseCategory)
            : activityName
    }
}

// MARK: - Exercise Library Cards

private struct ExerciseLibrarySection: Identifiable {
    let category: Exercise.Category
    let exercises: [Exercise]

    var id: String { category.rawValue }
}

private struct ExerciseLibrarySectionCard: View {
    let section: ExerciseLibrarySection
    let onDelete: (Exercise) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TraiSectionHeader(section.category.displayName, icon: section.category.iconName) {
                Text("\(section.exercises.count)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .frame(height: 24)
                    .background(Color(.tertiarySystemFill), in: Capsule())
            }

            VStack(spacing: 0) {
                ForEach(Array(section.exercises.enumerated()), id: \.element.id) { index, exercise in
                    ExerciseManagementRow(exercise: exercise, onDelete: { onDelete(exercise) })

                    if index < section.exercises.count - 1 {
                        Divider()
                            .padding(.leading, 46)
                    }
                }
            }
        }
        .padding(14)
        .traiCard(cornerRadius: 16, contentPadding: 0)
    }
}

private struct ExerciseManagementRow: View {
    let exercise: Exercise
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: exercise.exerciseCategory.iconName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.accent)
                .frame(width: 34, height: 34)
                .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 8) {
                Text(exercise.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                VStack(alignment: .leading, spacing: 6) {
                    ExerciseLibraryMetadataLine(
                        icon: "rectangle.stack.fill",
                        title: displayActivityName
                    )

                    ExerciseLibraryMetadataLine(
                        icon: "slider.horizontal.3",
                        title: trackingSummary
                    )

                    if !targetSummary.isEmpty {
                        ExerciseLibraryMetadataLine(
                            icon: exercise.exerciseCategory.iconName,
                            title: targetSummary
                        )
                    }
                }
            }

            Spacer()

            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 32)
                    .background(Color(.tertiarySystemFill), in: Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 12)
    }

    private var displayActivityName: String {
        let activityName = exercise.activityTypeName.trimmingCharacters(in: .whitespacesAndNewlines)
        return activityName.isEmpty
            ? Exercise.defaultActivityTypeName(for: exercise.name, category: exercise.exerciseCategory)
            : activityName
    }

    private var trackingSummary: String {
        exercise.trackingFields
            .prefix(3)
            .map(\.displayName)
            .joined(separator: ", ")
    }

    private var targetSummary: String {
        var values = Array(exercise.targetTags.prefix(3))
        if let equipment = exercise.displayEquipment {
            values.append(equipment)
        }
        return values.joined(separator: ", ")
    }
}

private struct ExerciseLibraryMetadataLine: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 14)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}
