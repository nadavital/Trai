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
    @State private var persistenceError: CustomExercisesPersistenceError?

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
        Exercise.Category.userFacingCases.flatMap { category in
            smartSections(
                for: category,
                exercises: filteredExercises.filter { $0.exerciseCategory.userFacingEquivalent == category }
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
        .toolbarTitleDisplayMode(.inlineLarge)
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
        .alert(item: $persistenceError) { error in
            Alert(
                title: Text(error.title),
                message: Text(error.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            ContentUnavailableView(
                "No Custom Items",
                systemImage: "dumbbell",
                description: Text("Exercises and activities you create will appear here")
            )

            Button("Add Exercise", systemImage: "plus") {
                showingAddCustomExercise = true
            }
            .buttonStyle(.traiSecondary(color: .accentColor, fullWidth: false))
        }
        .frame(maxWidth: .infinity)
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
        guard saveCustomExerciseChange(title: "Exercise Not Deleted") else { return }
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
            guard saveCustomExerciseChange(title: "Exercise Not Updated") else { return }
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
        guard saveCustomExerciseChange(title: "Exercise Not Created") else { return }
        fetchCustomExercises()
        HapticManager.success()
    }

    private func saveCustomExerciseChange(title: String) -> Bool {
        do {
            try modelContext.save()
            return true
        } catch {
            modelContext.rollback()
            persistenceError = CustomExercisesPersistenceError(
                title: title,
                message: error.localizedDescription
            )
            HapticManager.error()
            return false
        }
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

    private func smartSections(
        for category: Exercise.Category,
        exercises: [Exercise]
    ) -> [ExerciseLibrarySection] {
        guard !exercises.isEmpty else { return [] }

        let sorted = exercises.sorted(by: sortExercises)
        guard exercises.count > 6 else {
            return [
                ExerciseLibrarySection(
                    id: category.rawValue,
                    title: category.displayName,
                    subtitle: nil,
                    icon: category.iconName,
                    category: category,
                    priority: 0,
                    exercises: sorted
                )
            ]
        }

        let activityCounts = Dictionary(grouping: exercises, by: displayActivityName(for:))
            .mapValues(\.count)
        let targetCounts = Dictionary(grouping: exercises, by: { primaryTargetName(for: $0) ?? "" })
            .mapValues(\.count)
        var buckets: [ExerciseLibraryBucket: [Exercise]] = [:]

        for exercise in exercises {
            let activityName = displayActivityName(for: exercise)
            let targetName = primaryTargetName(for: exercise)
            let bucket: ExerciseLibraryBucket

            if category == .strength,
               let targetName,
               (targetCounts[targetName] ?? 0) >= 2 {
                bucket = ExerciseLibraryBucket(
                    title: targetName,
                    subtitle: activityName,
                    icon: exercise.exerciseCategory.iconName,
                    category: category,
                    priority: 0
                )
            } else if (activityCounts[activityName] ?? 0) >= (category == .strength ? 4 : 2) {
                bucket = ExerciseLibraryBucket(
                    title: activityName,
                    subtitle: category.displayName,
                    icon: category.iconName,
                    category: category,
                    priority: 1
                )
            } else if let targetName,
                      (targetCounts[targetName] ?? 0) >= 2 {
                bucket = ExerciseLibraryBucket(
                    title: targetName,
                    subtitle: category.displayName,
                    icon: category.iconName,
                    category: category,
                    priority: 2
                )
            } else {
                bucket = ExerciseLibraryBucket(
                    title: "More \(category.displayName)",
                    subtitle: nil,
                    icon: category.iconName,
                    category: category,
                    priority: 3
                )
            }

            buckets[bucket, default: []].append(exercise)
        }

        return buckets
            .map { bucket, exercises in
                ExerciseLibrarySection(
                    id: "\(category.rawValue)-\(bucket.title.goalNormalizedKey)-\(bucket.subtitle?.goalNormalizedKey ?? "none")",
                    title: bucket.title,
                    subtitle: bucket.subtitle == bucket.title ? nil : bucket.subtitle,
                    icon: bucket.icon,
                    category: bucket.category,
                    priority: bucket.priority,
                    exercises: exercises.sorted(by: sortExercises)
                )
            }
            .sorted { lhs, rhs in
                if lhs.priority != rhs.priority { return lhs.priority < rhs.priority }
                if lhs.exercises.count != rhs.exercises.count { return lhs.exercises.count > rhs.exercises.count }
                return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
            }
    }

    private func sortExercises(_ lhs: Exercise, _ rhs: Exercise) -> Bool {
        let lhsActivity = displayActivityName(for: lhs)
        let rhsActivity = displayActivityName(for: rhs)
        if lhsActivity != rhsActivity {
            return lhsActivity.localizedStandardCompare(rhsActivity) == .orderedAscending
        }
        return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
    }

    private func primaryTargetName(for exercise: Exercise) -> String? {
        if let muscleGroup = exercise.targetMuscleGroup {
            return muscleGroup.displayName
        }
        return exercise.targetTags
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
    }
}

private struct CustomExercisesPersistenceError: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

// MARK: - Exercise Library Cards

private struct ExerciseLibrarySection: Identifiable {
    let id: String
    let title: String
    let subtitle: String?
    let icon: String
    let category: Exercise.Category
    let priority: Int
    let exercises: [Exercise]
}

private struct ExerciseLibraryBucket: Hashable {
    let title: String
    let subtitle: String?
    let icon: String
    let category: Exercise.Category
    let priority: Int
}

private struct ExerciseLibrarySectionCard: View {
    let section: ExerciseLibrarySection
    let onDelete: (Exercise) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TraiSectionHeader(section.title, icon: section.icon) {
                Text("\(section.exercises.count)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .frame(height: 24)
                    .background(Color(.tertiarySystemFill), in: Capsule())
            }

            if let subtitle = section.subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(section.exercises) { exercise in
                        ExerciseManagementCard(
                            exercise: exercise,
                            sectionTitle: section.title,
                            onDelete: { onDelete(exercise) }
                        )
                        .frame(width: 176)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .contentMargins(.horizontal, 1, for: .scrollContent)
        }
        .padding(.vertical, 4)
    }
}

private struct ExerciseManagementCard: View {
    let exercise: Exercise
    let sectionTitle: String
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                Image(systemName: exercise.exerciseCategory.iconName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.accent)
                    .frame(width: 32, height: 32)
                    .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))

                Spacer()

                Menu {
                    Button("Delete", systemImage: "trash", role: .destructive, action: onDelete)
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(exercise.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                if !detailSummary.isEmpty {
                    Text(detailSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            if !trackingSummary.isEmpty {
                Text(trackingSummary)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(12)
        .frame(height: 136, alignment: .topLeading)
        .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 14))
        .contentShape(RoundedRectangle(cornerRadius: 14))
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

    private var detailSummary: String {
        let sectionKey = sectionTitle.goalNormalizedKey
        var values: [String] = []
        if displayActivityName.goalNormalizedKey != sectionKey {
            values.append(displayActivityName)
        }
        if let target = primaryTargetName,
           target.goalNormalizedKey != sectionKey {
            values.append(target)
        }
        if let equipment = exercise.displayEquipment {
            values.append(equipment)
        }
        return values.prefix(2).joined(separator: " • ")
    }

    private var primaryTargetName: String? {
        if let muscleGroup = exercise.targetMuscleGroup {
            return muscleGroup.displayName
        }
        return exercise.targetTags
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
    }
}
