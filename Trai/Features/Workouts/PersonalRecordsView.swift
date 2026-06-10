//
//  PersonalRecordsView.swift
//  Trai
//
//  Personal Records (PR) management screen showing personal bests for exercises and activities
//

import SwiftUI
import SwiftData

struct PersonalRecordsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \ExerciseHistory.performedAt, order: .reverse)
    private var allHistory: [ExerciseHistory]

    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @Query private var profiles: [UserProfile]

    @State private var searchText = ""
    @State private var selectedExercise: ExercisePR?
    @State private var exerciseToDelete: ExercisePR?
    @State private var showingDeleteConfirmation = false
    @State private var selectedSort: PRSortOption = .recentActivity
    @State private var persistenceError: PersonalRecordsPersistenceError?

    init() {
        var profileDescriptor = FetchDescriptor<UserProfile>()
        profileDescriptor.fetchLimit = 1
        _profiles = Query(profileDescriptor)
    }

    /// Whether to use metric (kg) or imperial (lbs) for weight display
    private var useLbs: Bool {
        !(profiles.first?.usesMetricExerciseWeight ?? true)
    }

    private var volumePRMode: UserProfile.VolumePRMode {
        profiles.first?.volumePRModeValue ?? .perSet
    }

    private var historyByExerciseName: [String: [ExerciseHistory]] {
        Dictionary(grouping: allHistory, by: \.exerciseName)
    }

    private var muscleGroupByExerciseName: [String: Exercise.MuscleGroup] {
        var result: [String: Exercise.MuscleGroup] = [:]
        for exercise in exercises {
            guard result[exercise.name] == nil else { continue }
            guard let muscleGroup = exercise.targetMuscleGroup else { continue }
            result[exercise.name] = muscleGroup
        }
        return result
    }

    // MARK: - Computed Properties

    /// Group history by exercise and compute PRs
    private var exercisePRs: [ExercisePR] {
        let snapshotsByExercise = ExercisePerformanceService.snapshots(
            from: allHistory,
            volumePRMode: volumePRMode
        )
        return snapshotsByExercise.values.map { snapshot in
            ExercisePR.from(
                snapshot: snapshot,
                muscleGroup: muscleGroupByExerciseName[snapshot.exerciseName],
                volumePRMode: volumePRMode
            )
        }
    }

    /// Filtered PRs based on search query
    private var filteredPRs: [ExercisePR] {
        var result = exercisePRs

        if !searchText.isEmpty {
            result = result.filter { $0.exerciseName.localizedStandardContains(searchText) }
        }

        return sortPRs(result)
    }

    /// PRs grouped by muscle group
    private var prsByMuscleGroup: [Exercise.MuscleGroup: [ExercisePR]] {
        var grouped: [Exercise.MuscleGroup: [ExercisePR]] = [:]
        for pr in filteredPRs {
            if let muscleGroup = pr.muscleGroup {
                grouped[muscleGroup, default: []].append(pr)
            }
        }
        return grouped
    }

    private var activityPRs: [ExercisePR] {
        filteredPRs.filter { $0.muscleGroup == nil && $0.isActivityRecord }
    }

    private var otherPRs: [ExercisePR] {
        filteredPRs.filter { $0.muscleGroup == nil && !$0.isActivityRecord }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Group {
                if exercisePRs.isEmpty {
                    emptyStateView
                } else {
                    prListView
                }
            }
            .navigationTitle("Personal Records")
            .toolbarTitleDisplayMode(.inlineLarge)
            .searchable(text: $searchText, prompt: "Search records")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done", systemImage: "xmark") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        ForEach(PRSortOption.allCases) { option in
                            Button {
                                selectedSort = option
                            } label: {
                                if selectedSort == option {
                                    Label(option.label(volumePRMode: volumePRMode), systemImage: "checkmark")
                                } else {
                                    Text(option.label(volumePRMode: volumePRMode))
                                }
                            }
                        }
                    } label: {
                        Label("Sort", systemImage: "arrow.up.arrow.down")
                    }
                }
            }
            .sheet(item: $selectedExercise) { pr in
                PRDetailSheet(
                    pr: pr,
                    history: historyByExerciseName[pr.exerciseName] ?? [],
                    useLbs: useLbs,
                    volumePRMode: volumePRMode,
                    onDeleteAll: {
                        exerciseToDelete = pr
                        showingDeleteConfirmation = true
                    }
                )
            }
            .confirmationDialog(
                "Delete All Records",
                isPresented: $showingDeleteConfirmation,
                presenting: exerciseToDelete
            ) { pr in
                Button("Delete All \(pr.exerciseName) Records", role: .destructive) {
                    if deleteAllRecords(for: pr.exerciseName) {
                        selectedExercise = nil
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: { pr in
                Text("This will permanently delete all \(pr.totalSessions) workout records for \(pr.exerciseName). This cannot be undone.")
            }
            .alert(item: $persistenceError) { error in
                Alert(
                    title: Text(error.title),
                    message: Text(error.message),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }

    // MARK: - Views

    private var emptyStateView: some View {
        ContentUnavailableView(
            "No Personal Records Yet",
            systemImage: "trophy",
            description: Text("Complete workouts to start tracking your personal records")
        )
    }

    private var prListView: some View {
        let visiblePRs = filteredPRs
        let visibleMuscleGroups = Array(Set(visiblePRs.compactMap(\.muscleGroup)))
            .sorted { $0.displayName < $1.displayName }

        return VStack(spacing: 0) {
            List {
                // Summary stats
                Section {
                    HStack {
                        StatBox(
                            title: "Records",
                            value: "\(visiblePRs.count)",
                            icon: "trophy.fill"
                        )

                        StatBox(
                            title: "Total Sessions",
                            value: "\(visiblePRs.reduce(0) { $0 + $1.totalSessions })",
                            icon: "calendar"
                        )

                        StatBox(
                            title: "Groups",
                            value: "\(visibleMuscleGroups.count + (activityPRs.isEmpty ? 0 : 1))",
                            icon: "rectangle.3.group.fill"
                        )
                    }
                    .listRowInsets(EdgeInsets(top: 10, leading: 12, bottom: 6, trailing: 12))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
                .listSectionSeparator(.hidden, edges: .all)

                // PRs by muscle group
                if visiblePRs.isEmpty {
                    Section {
                        ContentUnavailableView(
                            "No Matching Records",
                            systemImage: "line.3.horizontal.decrease.circle",
                            description: Text("Try a different search term")
                        )
                        .frame(maxWidth: .infinity, alignment: .center)
                        .listRowBackground(Color.clear)
                    }
                } else {
                    ForEach(visibleMuscleGroups) { muscleGroup in
                        if let prs = prsByMuscleGroup[muscleGroup], !prs.isEmpty {
                            Section {
                                PRCardRow(prs: prs, useLbs: useLbs, volumePRMode: volumePRMode) { pr in
                                    selectedExercise = pr
                                }
                                .listRowInsets(EdgeInsets(top: 2, leading: 0, bottom: 4, trailing: 0))
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                            } header: {
                                PRSectionHeader(title: muscleGroup.displayName, iconName: muscleGroup.iconName)
                            }
                        }
                    }

                    if !activityPRs.isEmpty {
                        Section {
                            PRCardRow(prs: activityPRs, useLbs: useLbs, volumePRMode: volumePRMode) { pr in
                                selectedExercise = pr
                            }
                            .listRowInsets(EdgeInsets(top: 2, leading: 0, bottom: 4, trailing: 0))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        } header: {
                            PRSectionHeader(title: "Activities", iconName: "figure.mixed.cardio")
                        }
                    }

                    if !otherPRs.isEmpty {
                        Section {
                            PRCardRow(prs: otherPRs, useLbs: useLbs, volumePRMode: volumePRMode) { pr in
                                selectedExercise = pr
                            }
                            .listRowInsets(EdgeInsets(top: 2, leading: 0, bottom: 4, trailing: 0))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        } header: {
                            PRSectionHeader(title: "Other", iconName: "figure.run")
                        }
                    }
                }
            }
            .listStyle(.plain)
            .listSectionSpacing(.compact)
            .scrollContentBackground(.hidden)
            .contentMargins(.horizontal, 0, for: .scrollContent)
        }
        .background(Color(.systemBackground))
    }

    // MARK: - Actions

    private func deleteAllRecords(for exerciseName: String) -> Bool {
        let historyToDelete = historyByExerciseName[exerciseName] ?? []
        for history in historyToDelete {
            modelContext.delete(history)
        }
        guard savePersonalRecordsChange(title: "Records Not Deleted") else { return false }
        HapticManager.success()
        return true
    }

    private func savePersonalRecordsChange(title: String) -> Bool {
        do {
            try modelContext.save()
            return true
        } catch {
            modelContext.rollback()
            persistenceError = PersonalRecordsPersistenceError(
                title: title,
                message: error.localizedDescription
            )
            HapticManager.error()
            return false
        }
    }

    private func sortPRs(_ prs: [ExercisePR]) -> [ExercisePR] {
        switch selectedSort {
        case .recentActivity:
            return prs.sorted { lhs, rhs in
                if lhs.lastPerformed != rhs.lastPerformed {
                    return lhs.lastPerformed > rhs.lastPerformed
                }
                return lhs.exerciseName.localizedStandardCompare(rhs.exerciseName) == .orderedAscending
            }
        case .weightPR:
            return prs.sorted { lhs, rhs in
                if lhs.maxWeightKg != rhs.maxWeightKg {
                    return lhs.maxWeightKg > rhs.maxWeightKg
                }
                return lhs.exerciseName.localizedStandardCompare(rhs.exerciseName) == .orderedAscending
            }
        case .volumePR:
            return prs.sorted { lhs, rhs in
                if lhs.maxVolume != rhs.maxVolume {
                    return lhs.maxVolume > rhs.maxVolume
                }
                return lhs.exerciseName.localizedStandardCompare(rhs.exerciseName) == .orderedAscending
            }
        case .alphabetical:
            return prs.sorted { lhs, rhs in
                lhs.exerciseName.localizedStandardCompare(rhs.exerciseName) == .orderedAscending
            }
        }
    }
}

private enum PRSortOption: String, CaseIterable, Identifiable {
    case recentActivity
    case weightPR
    case volumePR
    case alphabetical

    var id: String { rawValue }

    func label(volumePRMode: UserProfile.VolumePRMode) -> String {
        switch self {
        case .recentActivity:
            return "Recent Activity"
        case .weightPR:
            return "Top Record"
        case .volumePR:
            return volumePRMode.sortLabel
        case .alphabetical:
            return "A-Z"
        }
    }
}

// MARK: - Data Models

struct ExercisePR: Identifiable {
    var id: String { exerciseName }

    let exerciseName: String
    let muscleGroup: Exercise.MuscleGroup?

    // Weight PR
    let maxWeightKg: Double
    let maxWeightDate: Date?
    let maxWeightReps: Int

    // Reps PR
    let maxReps: Int
    let maxRepsDate: Date?
    let maxRepsWeight: Double

    // Volume PR based on user-selected mode (per-set or total volume)
    let maxVolume: Double
    let maxVolumeDate: Date?

    // Estimated 1RM
    let estimated1RM: Double?

    // Activity PRs
    let maxDurationSeconds: Int
    let maxDurationDate: Date?
    let maxDistanceMeters: Double
    let maxDistanceDate: Date?
    let maxActivityCount: Int
    let maxActivityCountDate: Date?
    let maxActivityCountLabel: String

    let totalSessions: Int
    let lastPerformed: Date

    var isActivityRecord: Bool {
        maxDurationSeconds > 0 || maxDistanceMeters > 0 || maxActivityCount > 0
    }

    /// Create an ExercisePR from exercise history entries
    static func from(
        exerciseName: String,
        history: [ExerciseHistory],
        muscleGroup: Exercise.MuscleGroup? = nil,
        volumePRMode: UserProfile.VolumePRMode = .perSet
    ) -> ExercisePR? {
        guard let snapshot = ExercisePerformanceService.snapshot(
            exerciseName: exerciseName,
            history: history,
            volumePRMode: volumePRMode
        ) else {
            return nil
        }
        return from(snapshot: snapshot, muscleGroup: muscleGroup, volumePRMode: volumePRMode)
    }

    static func from(
        snapshot: ExercisePerformanceSnapshot,
        muscleGroup: Exercise.MuscleGroup? = nil,
        volumePRMode: UserProfile.VolumePRMode = .perSet
    ) -> ExercisePR {
        ExercisePR(
            exerciseName: snapshot.exerciseName,
            muscleGroup: muscleGroup,
            maxWeightKg: snapshot.weightPR?.bestSetWeightKg ?? 0,
            maxWeightDate: snapshot.weightPR?.performedAt,
            maxWeightReps: snapshot.weightPR?.bestSetReps ?? 0,
            maxReps: snapshot.repsPR?.bestSetReps ?? 0,
            maxRepsDate: snapshot.repsPR?.performedAt,
            maxRepsWeight: snapshot.repsPR?.bestSetWeightKg ?? 0,
            maxVolume: snapshot.volumePR?.volumeValue(for: volumePRMode) ?? 0,
            maxVolumeDate: snapshot.volumePR?.performedAt,
            estimated1RM: snapshot.estimatedOneRepMax,
            maxDurationSeconds: snapshot.activityDurationPR?.durationSeconds ?? 0,
            maxDurationDate: snapshot.activityDurationPR?.performedAt,
            maxDistanceMeters: snapshot.activityDistancePR?.distanceMeters ?? 0,
            maxDistanceDate: snapshot.activityDistancePR?.performedAt,
            maxActivityCount: snapshot.activityCountPR.map { max($0.totalReps, $0.totalSets) } ?? 0,
            maxActivityCountDate: snapshot.activityCountPR?.performedAt,
            maxActivityCountLabel: activityCountLabel(for: snapshot.activityCountPR),
            totalSessions: snapshot.totalSessions,
            lastPerformed: snapshot.lastSession?.performedAt ?? Date()
        )
    }

    private static func activityCountLabel(for record: ExerciseHistory?) -> String {
        guard let record else { return "reps" }
        if record.totalReps > 0 {
            switch record.activityKind {
            case .sportPractice, .skill:
                return record.totalReps == 1 ? "attempt" : "attempts"
            case .conditioning:
                return record.totalReps == 1 ? "round" : "rounds"
            case .mobility, .recovery:
                return record.totalReps == 1 ? "rep" : "reps"
            case .cardio, .custom, .strength, .none:
                return record.totalReps == 1 ? "rep" : "reps"
            }
        }

        switch record.activityKind {
        case .conditioning:
            return record.totalSets == 1 ? "round" : "rounds"
        default:
            return record.totalSets == 1 ? "segment" : "segments"
        }
    }
}

// MARK: - Supporting Views

private struct StatBox: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(Color.accentColor)
                .frame(width: 30, height: 30)
                .background(Color.accentColor.opacity(0.16))
                .clipShape(.circle)

            Text(value)
                .font(.title3)
                .bold()

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 0, maxWidth: .infinity)
        .frame(minHeight: 96)
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(.rect(cornerRadius: 14))
    }
}

private struct PRSectionHeader: View {
    let title: String
    let iconName: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: iconName)
                .foregroundStyle(.accent)
            Text(title)
                .foregroundStyle(.primary)
        }
    }
}

private struct PRCardRow: View {
    let prs: [ExercisePR]
    let useLbs: Bool
    let volumePRMode: UserProfile.VolumePRMode
    let onSelect: (ExercisePR) -> Void

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 12) {
                ForEach(prs) { pr in
                    ExercisePRCard(pr: pr, useLbs: useLbs, volumePRMode: volumePRMode) {
                        onSelect(pr)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 2)
        }
        .scrollIndicators(.hidden)
    }
}

private struct ExercisePRCard: View {
    let pr: ExercisePR
    let useLbs: Bool
    let volumePRMode: UserProfile.VolumePRMode
    let onTap: () -> Void

    private var weightUnit: String { useLbs ? "lbs" : "kg" }

    private func displayWeight(_ kg: Double) -> Int {
        let unit = WeightUnit(usesMetric: !useLbs)
        return WeightUtility.displayInt(kg, displayUnit: unit)
    }

    private func formatVolume(_ volumeKg: Double) -> String {
        let displayVolume = useLbs ? volumeKg * WeightUtility.kgToLbs : volumeKg
        if displayVolume >= 1000 {
            return String(format: "%.1fk", displayVolume / 1000)
        }
        return "\(Int(displayVolume.rounded()))"
    }

    private var isBodyweightWeightPR: Bool {
        pr.maxWeightKg <= 0 && pr.maxWeightReps > 0
    }

    private var weightPRSummary: String {
        if isBodyweightWeightPR {
            return "BW × \(pr.maxWeightReps)"
        }
        return "\(displayWeight(pr.maxWeightKg)) \(weightUnit) × \(pr.maxWeightReps)"
    }

    private var formattedVolumeWithUnit: String {
        let suffix = volumePRMode.unitSuffix
        if suffix.isEmpty {
            return "\(formatVolume(pr.maxVolume)) \(weightUnit)"
        }
        return "\(formatVolume(pr.maxVolume)) \(weightUnit)\(suffix)"
    }

    private var activityPrimarySummary: String {
        if pr.maxDistanceMeters > 0 {
            return formatDistance(pr.maxDistanceMeters)
        }
        if pr.maxDurationSeconds > 0 {
            return formatDuration(pr.maxDurationSeconds)
        }
        if pr.maxActivityCount > 0 {
            return "\(pr.maxActivityCount) \(pr.maxActivityCountLabel)"
        }
        return "\(pr.totalSessions) sessions"
    }

    private var activitySecondaryMetrics: [(String, String, Color)] {
        var metrics: [(String, String, Color)] = []
        if pr.maxDurationSeconds > 0 {
            metrics.append(("clock.fill", formatDuration(pr.maxDurationSeconds), .blue))
        }
        if pr.maxDistanceMeters > 0 {
            metrics.append(("map.fill", formatDistance(pr.maxDistanceMeters), .green))
        }
        if pr.maxActivityCount > 0 {
            metrics.append(("repeat", "\(pr.maxActivityCount) \(pr.maxActivityCountLabel)", .orange))
        }
        return Array(metrics.prefix(2))
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(pr.exerciseName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .frame(minHeight: 36, maxHeight: 36, alignment: .topLeading)
                        .layoutPriority(1)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                Text(pr.isActivityRecord ? activityPrimarySummary : weightPRSummary)
                    .font(.title3)
                    .bold()
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                if pr.isActivityRecord {
                    HStack {
                        ForEach(Array(activitySecondaryMetrics.enumerated()), id: \.offset) { _, metric in
                            HStack(spacing: 4) {
                                Image(systemName: metric.0)
                                    .foregroundStyle(metric.2)
                                Text(metric.1)
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            Spacer()
                        }
                    }
                } else {
                    HStack {
                        HStack(spacing: 4) {
                            Image(systemName: PRMetricKind.reps.iconName)
                                .foregroundStyle(PRMetricKind.reps.color)
                            Text("\(pr.maxReps) reps")
                        }
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Spacer()

                        HStack(spacing: 4) {
                            Image(systemName: PRMetricKind.volume.iconName)
                                .foregroundStyle(PRMetricKind.volume.color)
                            Text(formattedVolumeWithUnit)
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .traiCard(cornerRadius: 14, contentPadding: 0)
        }
        .frame(height: 126)
        .frame(width: 214, alignment: .leading)
        .foregroundStyle(.primary)
    }

    private func formatDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        if minutes >= 60 {
            let hours = minutes / 60
            let remainder = minutes % 60
            return remainder > 0 ? "\(hours)h \(remainder)m" : "\(hours)h"
        }
        return "\(minutes)m"
    }

    private func formatDistance(_ meters: Double) -> String {
        if meters >= 1000 {
            return String(format: "%.1f km", meters / 1000)
        }
        return "\(Int(meters.rounded())) m"
    }
}

// MARK: - PR Detail Sheet

struct PRDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let pr: ExercisePR
    let history: [ExerciseHistory]
    let useLbs: Bool
    let volumePRMode: UserProfile.VolumePRMode
    let onDeleteAll: () -> Void

    @State private var historyToEdit: ExerciseHistory?
    @State private var showingDeleteConfirmation = false
    @State private var historyToDelete: ExerciseHistory?
    @State private var showingFullHistory = false
    @State private var persistenceError: PersonalRecordsPersistenceError?

    private var displayedHistory: [ExerciseHistory] {
        if showingFullHistory {
            return history
        }
        return Array(history.prefix(20))
    }

    var body: some View {
        NavigationStack {
            List {
                // Progress chart (only show strength charts when enough data exists)
                if history.count >= 2, !pr.isActivityRecord {
                    Section {
                        ExerciseTrendsChart(
                            history: history,
                            useLbs: useLbs,
                            volumePRMode: volumePRMode
                        )
                    } header: {
                        Text("Progress")
                    }
                }

                Section {
                    if pr.isActivityRecord {
                        ActivityRecordStatsGrid(pr: pr)
                    } else {
                        PRStatsGrid(pr: pr, useLbs: useLbs, volumePRMode: volumePRMode)
                    }
                } header: {
                    Text(pr.isActivityRecord ? "Activity Records" : "Personal Records")
                }

                // History with swipe-to-delete
                Section {
                    ForEach(displayedHistory) { entry in
                        HistoryRow(entry: entry, useLbs: useLbs)
                            .contentShape(Rectangle())
                            .contextMenu {
                                if entry.hasStrengthMetrics {
                                    Button("Edit", systemImage: "pencil") {
                                        historyToEdit = entry
                                    }
                                }
                                Button("Delete", systemImage: "trash", role: .destructive) {
                                    historyToDelete = entry
                                    showingDeleteConfirmation = true
                                }
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button("Delete", systemImage: "trash", role: .destructive) {
                                    historyToDelete = entry
                                    showingDeleteConfirmation = true
                                }
                            }
                    }

                    if history.count > 20 {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showingFullHistory.toggle()
                            }
                        } label: {
                            HStack {
                                Text(showingFullHistory ? "Show Less" : "Show All \(history.count) Sessions")
                                Spacer()
                                Image(systemName: showingFullHistory ? "chevron.up" : "chevron.down")
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("Recent History")
                }

            }
            .navigationTitle(pr.exerciseName)
            .toolbarTitleDisplayMode(.inlineLarge)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("Delete All Records", systemImage: "trash", role: .destructive) {
                            dismiss()
                            onDeleteAll()
                        }
                    } label: {
                        Label("Manage", systemImage: "ellipsis.circle")
                    }
                }
            }
            .sheet(item: $historyToEdit) { entry in
                EditHistorySheet(history: entry, useLbs: useLbs)
                    .traiSheetBranding()
            }
            .confirmationDialog(
                "Delete Record",
                isPresented: $showingDeleteConfirmation,
                presenting: historyToDelete
            ) { entry in
                Button("Delete", role: .destructive) {
                    deleteHistory(entry)
                }
                Button("Cancel", role: .cancel) {}
            } message: { entry in
                Text("Delete record from \(entry.performedAt.formatted(date: .abbreviated, time: .omitted))?")
            }
            .alert(item: $persistenceError) { error in
                Alert(
                    title: Text(error.title),
                    message: Text(error.message),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
        .traiSheetBranding()
    }

    private func deleteHistory(_ history: ExerciseHistory) {
        modelContext.delete(history)
        guard savePersonalRecordDetailChange(title: "Record Not Deleted") else { return }
        HapticManager.success()
    }

    private func savePersonalRecordDetailChange(title: String) -> Bool {
        do {
            try modelContext.save()
            return true
        } catch {
            modelContext.rollback()
            persistenceError = PersonalRecordsPersistenceError(
                title: title,
                message: error.localizedDescription
            )
            HapticManager.error()
            return false
        }
    }
}

struct PRStatsGrid: View {
    let pr: ExercisePR
    let useLbs: Bool
    let volumePRMode: UserProfile.VolumePRMode

    private var weightUnit: String { useLbs ? "lbs" : "kg" }

    private func displayWeight(_ kg: Double) -> Int {
        let unit = WeightUnit(usesMetric: !useLbs)
        return WeightUtility.displayInt(kg, displayUnit: unit)
    }

    private func formatVolume(_ volume: Double) -> String {
        let displayVolume = useLbs ? volume * WeightUtility.kgToLbs : volume
        if displayVolume >= 1000 {
            return String(format: "%.1fk", displayVolume / 1000)
        }
        return "\(Int(displayVolume.rounded()))"
    }

    private var isBodyweightWeightPR: Bool {
        pr.maxWeightKg <= 0 && pr.maxWeightReps > 0
    }

    private var isBodyweightRepsPR: Bool {
        pr.maxReps > 0 && pr.maxRepsWeight <= 0
    }

    private var volumeDetail: String {
        let suffix = volumePRMode.unitSuffix
        if suffix.isEmpty {
            return weightUnit
        }
        return "\(weightUnit)\(suffix)"
    }

    var body: some View {
        Grid(horizontalSpacing: 16, verticalSpacing: 12) {
            GridRow {
                PRStatCell(
                    icon: PRMetricKind.weight.iconName,
                    iconColor: PRMetricKind.weight.color,
                    label: PRMetricKind.weight.label,
                    value: isBodyweightWeightPR ? "BW" : "\(displayWeight(pr.maxWeightKg)) \(weightUnit)",
                    detail: "× \(pr.maxWeightReps)"
                )
                PRStatCell(
                    icon: PRMetricKind.reps.iconName,
                    iconColor: PRMetricKind.reps.color,
                    label: PRMetricKind.reps.label,
                    value: "\(pr.maxReps)",
                    detail: isBodyweightRepsPR ? "@ BW" : "@ \(displayWeight(pr.maxRepsWeight)) \(weightUnit)"
                )
            }
            GridRow {
                PRStatCell(
                    icon: PRMetricKind.volume.iconName,
                    iconColor: PRMetricKind.volume.color,
                    label: PRMetricKind.volume.label(for: volumePRMode),
                    value: formatVolume(pr.maxVolume),
                    detail: volumeDetail
                )
                if let oneRM = pr.estimated1RM {
                    PRStatCell(
                        icon: PRMetricKind.estimatedOneRepMax.iconName,
                        iconColor: PRMetricKind.estimatedOneRepMax.color,
                        label: PRMetricKind.estimatedOneRepMax.label,
                        value: "\(displayWeight(oneRM))",
                        detail: weightUnit
                    )
                } else {
                    PRStatCell(
                        icon: PRMetricKind.estimatedOneRepMax.iconName,
                        iconColor: .secondary,
                        label: PRMetricKind.estimatedOneRepMax.label,
                        value: "--",
                        detail: ""
                    )
                }
            }
        }
    }
}

struct ActivityRecordStatsGrid: View {
    let pr: ExercisePR

    var body: some View {
        Grid(horizontalSpacing: 16, verticalSpacing: 12) {
            GridRow {
                PRStatCell(
                    icon: "clock.fill",
                    iconColor: .blue,
                    label: "Duration",
                    value: pr.maxDurationSeconds > 0 ? formatDuration(pr.maxDurationSeconds) : "--",
                    detail: pr.maxDurationDate?.formatted(date: .abbreviated, time: .omitted) ?? ""
                )
                PRStatCell(
                    icon: "map.fill",
                    iconColor: .green,
                    label: "Distance",
                    value: pr.maxDistanceMeters > 0 ? formatDistance(pr.maxDistanceMeters) : "--",
                    detail: pr.maxDistanceDate?.formatted(date: .abbreviated, time: .omitted) ?? ""
                )
            }
            GridRow {
                PRStatCell(
                    icon: "repeat",
                    iconColor: .orange,
                    label: pr.maxActivityCountLabel.capitalized,
                    value: pr.maxActivityCount > 0 ? "\(pr.maxActivityCount)" : "--",
                    detail: pr.maxActivityCountDate?.formatted(date: .abbreviated, time: .omitted) ?? ""
                )
                PRStatCell(
                    icon: "calendar",
                    iconColor: .accentColor,
                    label: "Sessions",
                    value: "\(pr.totalSessions)",
                    detail: "logged"
                )
            }
        }
    }

    private func formatDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        if minutes >= 60 {
            let hours = minutes / 60
            let remainder = minutes % 60
            return remainder > 0 ? "\(hours)h \(remainder)m" : "\(hours)h"
        }
        return "\(minutes)m"
    }

    private func formatDistance(_ meters: Double) -> String {
        if meters >= 1000 {
            return String(format: "%.1f km", meters / 1000)
        }
        return "\(Int(meters.rounded())) m"
    }
}

struct PRStatCell: View {
    let icon: String
    let iconColor: Color
    let label: String
    let value: String
    let detail: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(iconColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(value)
                        .font(.subheadline)
                        .bold()
                    if !detail.isEmpty {
                        Text(detail)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct HistoryRow: View {
    let entry: ExerciseHistory
    let useLbs: Bool

    private var weightUnit: String { useLbs ? "lbs" : "kg" }

    private func displayWeight(_ kg: Double) -> Int {
        let unit = WeightUnit(usesMetric: !useLbs)
        return WeightUtility.displayInt(kg, displayUnit: unit)
    }

    private var isBodyweightEntry: Bool {
        entry.bestSetWeightKg <= 0 && entry.bestSetReps > 0
    }

    var body: some View {
        HStack {
            Text(entry.performedAt, format: .dateTime.month(.abbreviated).day())
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 50, alignment: .leading)

            Text(primarySummary)
                .font(.subheadline)
                .bold()

            Spacer()

            Text(secondarySummary)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var primarySummary: String {
        guard !entry.hasActivityMetrics else { return activityPrimarySummary }
        return isBodyweightEntry
            ? "BW × \(entry.bestSetReps)"
            : "\(displayWeight(entry.bestSetWeightKg)) \(weightUnit) × \(entry.bestSetReps)"
    }

    private var secondarySummary: String {
        guard !entry.hasActivityMetrics else { return activitySecondarySummary }
        return "\(entry.totalSets)s • \(entry.totalReps)r"
    }

    private var activityPrimarySummary: String {
        if entry.distanceMeters > 0 {
            return formatDistance(entry.distanceMeters)
        }
        if entry.durationSeconds > 0 {
            return formatDuration(entry.durationSeconds)
        }
        if entry.totalReps > 0 {
            return "\(entry.totalReps) \(countLabel(for: entry.totalReps))"
        }
        return "\(entry.totalSets) segments"
    }

    private var activitySecondarySummary: String {
        var parts: [String] = []
        let primaryKind = activityPrimaryKind
        let activityName = entry.activityTypeName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !activityName.isEmpty, activityName.goalNormalizedKey != entry.exerciseName.goalNormalizedKey {
            parts.append(activityName)
        }
        if entry.durationSeconds > 0, primaryKind != .duration {
            parts.append(formatDuration(entry.durationSeconds))
        }
        if entry.distanceMeters > 0, primaryKind != .distance {
            parts.append(formatDistance(entry.distanceMeters))
        }
        if entry.totalReps > 0, primaryKind != .count {
            parts.append("\(entry.totalReps) \(countLabel(for: entry.totalReps))")
        } else if entry.totalSets > 0 {
            parts.append("\(entry.totalSets) segments")
        }
        return parts.isEmpty ? "Activity" : parts.joined(separator: " • ")
    }

    private var activityPrimaryKind: ActivityPrimaryKind {
        if entry.distanceMeters > 0 { return .distance }
        if entry.durationSeconds > 0 { return .duration }
        if entry.totalReps > 0 { return .count }
        return .segments
    }

    private enum ActivityPrimaryKind {
        case duration
        case distance
        case count
        case segments
    }

    private func countLabel(for value: Int) -> String {
        let label: String
        switch entry.activityKind {
        case .sportPractice, .skill:
            label = "attempt"
        case .conditioning:
            label = "round"
        default:
            label = "rep"
        }
        return value == 1 ? label : "\(label)s"
    }

    private func formatDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        if minutes >= 60 {
            let hours = minutes / 60
            let remainder = minutes % 60
            return remainder > 0 ? "\(hours)h \(remainder)m" : "\(hours)h"
        }
        return "\(minutes)m"
    }

    private func formatDistance(_ meters: Double) -> String {
        if meters >= 1000 {
            return String(format: "%.1f km", meters / 1000)
        }
        return "\(Int(meters.rounded())) m"
    }
}

// MARK: - Edit History Sheet

private struct EditHistorySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Bindable var history: ExerciseHistory
    let useLbs: Bool

    @State private var weightDisplay: Double  // Weight in display units (kg or lbs)
    @State private var reps: Int
    @State private var date: Date
    @State private var persistenceError: PersonalRecordsPersistenceError?

    private var weightUnit: String { useLbs ? "lbs" : "kg" }

    /// Convert display weight to kg for storage
    private var weightKg: Double {
        useLbs ? weightDisplay / WeightUtility.kgToLbs : weightDisplay
    }

    init(history: ExerciseHistory, useLbs: Bool) {
        self.history = history
        self.useLbs = useLbs
        // Convert stored kg to display units
        let displayValue = useLbs ? history.bestSetWeightKg * WeightUtility.kgToLbs : history.bestSetWeightKg
        _weightDisplay = State(initialValue: displayValue)
        _reps = State(initialValue: history.bestSetReps)
        _date = State(initialValue: history.performedAt)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("Weight")
                        Spacer()
                        TextField(weightUnit, value: $weightDisplay, format: .number.precision(.fractionLength(1)))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text(weightUnit)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Reps")
                        Spacer()
                        TextField("reps", value: $reps, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }

                    DatePicker("Date", selection: $date, displayedComponents: .date)
                } header: {
                    Text("Best Set")
                }

                Section {
                    HStack {
                        Text("Est. 1RM")
                        Spacer()
                        if let oneRM = LiveWorkoutEntry.estimatedOneRepMax(weightKg: weightKg, reps: reps) {
                            let displayOneRM = useLbs ? oneRM * WeightUtility.kgToLbs : oneRM
                            Text(displayOneRM, format: .number.precision(.fractionLength(1)))
                            Text(weightUnit)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("--")
                                .foregroundStyle(.tertiary)
                        }
                    }

                    HStack {
                        Text("Volume")
                        Spacer()
                        let volumeKg = weightKg * Double(reps)
                        let displayVolume = useLbs ? volumeKg * WeightUtility.kgToLbs : volumeKg
                        Text(displayVolume, format: .number.precision(.fractionLength(0)))
                        Text(weightUnit)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Calculated Values")
                } footer: {
                    Text("Estimated 1RM uses the Brzycki formula and is only calculated for 1-25 reps.")
                }
            }
            .navigationTitle("Edit Record")
            .toolbarTitleDisplayMode(.inlineLarge)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", systemImage: "checkmark") {
                        if saveChanges() {
                            dismiss()
                        }
                    }
                    .labelStyle(.iconOnly)
                    .disabled(weightDisplay <= 0 || reps <= 0)
                }
            }
        }
        .alert(item: $persistenceError) { error in
            Alert(
                title: Text(error.title),
                message: Text(error.message),
                dismissButton: .default(Text("OK"))
            )
        }
        .traiSheetBranding()
    }

    private func saveChanges() -> Bool {
        // Round weight to nearest 0.5 kg
        history.bestSetWeightKg = (weightKg * 2).rounded() / 2
        history.bestSetWeightLbs = WeightUtility.round(
            history.bestSetWeightKg * WeightUtility.kgToLbs,
            unit: .lbs
        )
        history.bestSetReps = reps
        history.performedAt = date

        // Recalculate derived values
        // Volume = weight × reps × sets (use totalSets if available, otherwise estimate)
        let sets = max(history.totalSets, 1)
        history.totalVolume = history.bestSetWeightKg * Double(reps) * Double(sets)
        history.totalReps = reps * sets
        history.repPattern = Array(repeating: "\(reps)", count: sets).joined(separator: ",")
        let roundedWeightKg = WeightUtility.round(history.bestSetWeightKg, unit: .kg)
        history.weightPattern = Array(
            repeating: String(format: "%.1f", roundedWeightKg),
            count: sets
        ).joined(separator: ",")

        // Recalculate estimated 1RM
        history.estimatedOneRepMax = LiveWorkoutEntry.estimatedOneRepMax(
            weightKg: history.bestSetWeightKg,
            reps: reps
        )

        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            persistenceError = PersonalRecordsPersistenceError(
                title: "Record Not Saved",
                message: error.localizedDescription
            )
            HapticManager.error()
            return false
        }
        HapticManager.success()
        return true
    }
}

private struct PersonalRecordsPersistenceError: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

// MARK: - Preview

#Preview {
    PersonalRecordsView()
        .modelContainer(for: [ExerciseHistory.self, Exercise.self], inMemory: true)
}
