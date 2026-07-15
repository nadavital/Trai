//
//  WorkoutSummarySheet.swift
//  Trai
//
//  Workout completion summary sheet
//

import SwiftUI
import SwiftData

// MARK: - Workout Summary Sheet

// MARK: - Identifiable Exercise Wrapper

private struct IdentifiableExerciseName: Identifiable {
    let id: String
    var name: String { id }
}

private enum WorkoutSummaryPresentation: Identifiable {
    case exercisePR(IdentifiableExerciseName)
    case goalDetail(WorkoutGoal)

    var id: String {
        switch self {
        case .exercisePR(let exercise):
            return "exercisePR-\(exercise.id)"
        case .goalDetail(let goal):
            return "goalDetail-\(goal.id.uuidString)"
        }
    }
}

struct WorkoutSummarySheet: View {
    @Bindable var workout: LiveWorkout
    var achievedPRs: [String: LiveWorkoutViewModel.PRValue] = [:]
    let onDismiss: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(HealthKitService.self) private var healthKitService: HealthKitService?
    @Query private var profiles: [UserProfile]
    @Query(sort: \ExerciseHistory.performedAt, order: .reverse)
    private var allExerciseHistory: [ExerciseHistory]
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @Query(sort: \LiveWorkout.startedAt, order: .reverse) private var allLiveWorkouts: [LiveWorkout]
    @Query(sort: \WorkoutSession.loggedAt, order: .reverse) private var allWorkoutSessions: [WorkoutSession]
    @Query(
        filter: #Predicate<WorkoutGoal> { $0.statusRaw == "active" },
        sort: \WorkoutGoal.updatedAt,
        order: .reverse
    )
    private var workoutGoals: [WorkoutGoal]
    @State private var showConfetti = false
    @State private var showCelebration = false
    @State private var activePresentation: WorkoutSummaryPresentation?
    @State private var persistenceError: WorkoutSummaryPersistenceError?

    init(
        workout: LiveWorkout,
        achievedPRs: [String: LiveWorkoutViewModel.PRValue] = [:],
        onDismiss: @escaping () -> Void
    ) {
        self.workout = workout
        self.achievedPRs = achievedPRs
        self.onDismiss = onDismiss

        var profileDescriptor = FetchDescriptor<UserProfile>()
        profileDescriptor.fetchLimit = 1
        _profiles = Query(profileDescriptor)
    }

    /// Whether to use metric (kg) based on user profile
    private var usesMetric: Bool {
        profiles.first?.usesMetricExerciseWeight ?? true
    }

    private var volumePRMode: UserProfile.VolumePRMode {
        profiles.first?.volumePRModeValue ?? .perSet
    }

    private var sortedEntries: [LiveWorkoutEntry] {
        (workout.entries ?? []).sorted { $0.orderIndex < $1.orderIndex }
    }

    private var loggedEntries: [LiveWorkoutEntry] {
        sortedEntries.filter(\.hasExercisePreferenceSignal)
    }

    private var entryStats: LiveWorkout.EntrySummaryStats {
        workout.entrySummaryStats
    }

    private var usesFlexibleSessionPresentation: Bool {
        !workout.type.prefersStructuredEntries && workout.totalSets == 0
    }

    private var summaryTitle: String {
        usesFlexibleSessionPresentation ? "Session Complete!" : "Workout Complete!"
    }

    private var entriesTitle: String {
        if usesFlexibleSessionPresentation {
            return "Activities"
        }
        return loggedEntries.contains(where: { !$0.isStrength }) ? "Workout Log" : "Exercises"
    }

    private var goalInsights: [WorkoutGoalInsight] {
        WorkoutGoalProgressResolver.insights(
            for: workout,
            goals: workoutGoals.filter(\.isActive),
            workouts: allLiveWorkouts,
            sessions: goalProgressSessions,
            exerciseHistory: allExerciseHistory,
            useLbs: !usesMetric
        )
    }

    private var goalProgressSessions: [WorkoutSession] {
        let mergedHealthKitIDs = Set(
            allLiveWorkouts
                .filter { $0.completedAt != nil }
                .compactMap(\.mergedHealthKitWorkoutID)
        )
        return allWorkoutSessions.filter { session in
            guard let healthKitWorkoutID = session.healthKitWorkoutID else { return true }
            return !mergedHealthKitIDs.contains(healthKitWorkoutID)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    WorkoutSummaryHeader(
                        title: summaryTitle,
                        subtitle: usesFlexibleSessionPresentation ? workout.displayFocusSummary : nil,
                        formattedDuration: workout.formattedDuration,
                        entryStats: entryStats,
                        showCelebration: showCelebration,
                        showConfetti: showConfetti
                    )

                    if let averageHeartRate = workout.healthKitAvgHeartRate,
                       let zone = healthKitService?.preferredHeartRateZone(for: averageHeartRate) {
                        WorkoutHeartRateZoneSummaryCard(
                            averageHeartRate: averageHeartRate,
                            zone: zone
                        )
                    }

                    if !goalInsights.isEmpty {
                        WorkoutGoalProgressCard(
                            insights: goalInsights,
                            showsAddGoal: false,
                            onAddGoal: {},
                            onToggleCompletion: toggleGoalCompletion,
                            onGoalTap: { activePresentation = .goalDetail($0) }
                        )
                    }

                    // PRs achieved (if any)
                    if !achievedPRs.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "trophy.fill")
                                    .foregroundStyle(.yellow)
                                Text("Personal Records!")
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                            }

                            ForEach(Array(achievedPRs.keys.sorted()), id: \.self) { exerciseName in
                                if let prValue = achievedPRs[exerciseName] {
                                    PRRow(prValue: prValue, usesMetric: usesMetric)
                                }
                            }
                        }
                        .padding()
                        .background(Color.yellow.opacity(0.15))
                        .clipShape(.rect(cornerRadius: 16))
                    }

                    // Exercises completed with full detail
                    if !loggedEntries.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(entriesTitle)
                                .font(.headline)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            ForEach(loggedEntries) { entry in
                                if entry.isStrength {
                                    ExerciseSummaryRow(entry: entry, usesMetric: usesMetric) {
                                        activePresentation = .exercisePR(IdentifiableExerciseName(id: entry.exerciseName))
                                    }
                                } else {
                                    ActivitySummaryRow(entry: entry, usesMetric: usesMetric)
                                }
                            }
                        }
                        .traiCard()
                    }
                }
                .padding()
            }
            .navigationTitle("Summary")
            .toolbarTitleDisplayMode(.inlineLarge)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", systemImage: "checkmark", action: onDismiss)
                    .labelStyle(.iconOnly)
                }
            }
            .task {
                if #available(iOS 27.0, *),
                   workout.healthKitAvgHeartRate != nil {
                    try? await healthKitService?.refreshPreferredHeartRateZones()
                }
                withAnimation {
                    showConfetti = true
                }
                try? await Task.sleep(for: .milliseconds(300))
                showCelebration = true
            }
            .sheet(item: $activePresentation) { presentation in
                presentationContent(presentation)
            }
            .alert(item: $persistenceError) { error in
                Alert(
                    title: Text(error.title),
                    message: Text(error.message),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
        .overlay {
            // Confetti overlay - covers entire sheet
            if showConfetti {
                ConfettiView()
                    .allowsHitTesting(false)
                    .ignoresSafeArea()
            }
        }
        .traiSheetBranding()
        .traiBackground()
    }

    @ViewBuilder
    private func presentationContent(_ presentation: WorkoutSummaryPresentation) -> some View {
        switch presentation {
        case .exercisePR(let exercise):
            exercisePRSheet(for: exercise.name)
                .traiSheetBranding()
        case .goalDetail(let goal):
            WorkoutGoalDetailSheet(
                goal: goal,
                workouts: allLiveWorkouts,
                sessions: goalProgressSessions,
                exerciseHistory: allExerciseHistory,
                useLbs: !usesMetric,
                onToggleCompletion: toggleGoalCompletion
            )
            .traiSheetBranding()
        }
    }

    /// Build the PR detail sheet for a given exercise name
    @ViewBuilder
    private func exercisePRSheet(for exerciseName: String) -> some View {
        let history = allExerciseHistory.filter { $0.exerciseName == exerciseName }
        let exercise = exercises.first { $0.name == exerciseName }

        if let pr = ExercisePR.from(
            exerciseName: exerciseName,
            history: history,
            muscleGroup: exercise?.targetMuscleGroup,
            volumePRMode: volumePRMode
        ) {
            PRDetailSheet(
                pr: pr,
                history: history,
                useLbs: !usesMetric,
                volumePRMode: volumePRMode,
                onDeleteAll: {}
            )
        } else {
            NavigationStack {
                ContentUnavailableView(
                    "No History Yet",
                    systemImage: "chart.line.uptrend.xyaxis",
                    description: Text("Complete more workouts with \(exerciseName) to see your progress")
                )
                .navigationTitle(exerciseName)
                .toolbarTitleDisplayMode(.inlineLarge)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") {
                            activePresentation = nil
                        }
                    }
                }
            }
        }
    }

    private func toggleGoalCompletion(_ goal: WorkoutGoal) {
        if goal.status == .completed {
            goal.markActive()
        } else {
            goal.markCompleted()
        }
        guard saveSummaryChange(title: "Workout Goal Not Updated") else { return }
        HapticManager.selectionChanged()
    }

    private func saveSummaryChange(title: String) -> Bool {
        do {
            try modelContext.save()
            return true
        } catch {
            modelContext.rollback()
            persistenceError = WorkoutSummaryPersistenceError(
                title: title,
                message: error.localizedDescription
            )
            HapticManager.error()
            return false
        }
    }
}

// MARK: - Workout Summary Content (for inline display)

/// Summary content without NavigationStack - for embedding in parent view
struct WorkoutSummaryContent: View {
    @Bindable var workout: LiveWorkout
    var achievedPRs: [String: LiveWorkoutViewModel.PRValue] = [:]
    let onDismiss: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(HealthKitService.self) private var healthKitService: HealthKitService?
    @Query private var profiles: [UserProfile]
    @Query(sort: \ExerciseHistory.performedAt, order: .reverse)
    private var allExerciseHistory: [ExerciseHistory]
    @Query(sort: \LiveWorkout.startedAt, order: .reverse) private var allLiveWorkouts: [LiveWorkout]
    @Query(sort: \WorkoutSession.loggedAt, order: .reverse) private var allWorkoutSessions: [WorkoutSession]
    @Query(
        filter: #Predicate<WorkoutGoal> { $0.statusRaw == "active" },
        sort: \WorkoutGoal.updatedAt,
        order: .reverse
    )
    private var workoutGoals: [WorkoutGoal]
    @State private var showConfetti = false
    @State private var showCelebration = false
    @State private var selectedGoal: WorkoutGoal?
    @State private var persistenceError: WorkoutSummaryPersistenceError?

    init(
        workout: LiveWorkout,
        achievedPRs: [String: LiveWorkoutViewModel.PRValue] = [:],
        onDismiss: @escaping () -> Void
    ) {
        self.workout = workout
        self.achievedPRs = achievedPRs
        self.onDismiss = onDismiss

        var profileDescriptor = FetchDescriptor<UserProfile>()
        profileDescriptor.fetchLimit = 1
        _profiles = Query(profileDescriptor)
    }

    /// Whether to use metric (kg) based on user profile
    private var usesMetric: Bool {
        profiles.first?.usesMetricExerciseWeight ?? true
    }

    private var sortedEntries: [LiveWorkoutEntry] {
        (workout.entries ?? []).sorted { $0.orderIndex < $1.orderIndex }
    }

    private var loggedEntries: [LiveWorkoutEntry] {
        sortedEntries.filter(\.hasExercisePreferenceSignal)
    }

    private var entryStats: LiveWorkout.EntrySummaryStats {
        workout.entrySummaryStats
    }

    private var usesFlexibleSessionPresentation: Bool {
        !workout.type.prefersStructuredEntries && workout.totalSets == 0
    }

    private var summaryTitle: String {
        usesFlexibleSessionPresentation ? "Session Complete!" : "Workout Complete!"
    }

    private var entriesTitle: String {
        if usesFlexibleSessionPresentation {
            return "Activities"
        }
        return loggedEntries.contains(where: { !$0.isStrength }) ? "Workout Log" : "Exercises"
    }

    private var goalInsights: [WorkoutGoalInsight] {
        WorkoutGoalProgressResolver.insights(
            for: workout,
            goals: workoutGoals.filter(\.isActive),
            workouts: allLiveWorkouts,
            sessions: goalProgressSessions,
            exerciseHistory: allExerciseHistory,
            useLbs: !usesMetric
        )
    }

    private var goalProgressSessions: [WorkoutSession] {
        let mergedHealthKitIDs = Set(
            allLiveWorkouts
                .filter { $0.completedAt != nil }
                .compactMap(\.mergedHealthKitWorkoutID)
        )
        return allWorkoutSessions.filter { session in
            guard let healthKitWorkoutID = session.healthKitWorkoutID else { return true }
            return !mergedHealthKitIDs.contains(healthKitWorkoutID)
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                WorkoutSummaryHeader(
                    title: summaryTitle,
                    subtitle: usesFlexibleSessionPresentation ? workout.displayFocusSummary : nil,
                    formattedDuration: workout.formattedDuration,
                    entryStats: entryStats,
                    showCelebration: showCelebration,
                    showConfetti: showConfetti
                )

                if let averageHeartRate = workout.healthKitAvgHeartRate,
                   let zone = healthKitService?.preferredHeartRateZone(for: averageHeartRate) {
                    WorkoutHeartRateZoneSummaryCard(
                        averageHeartRate: averageHeartRate,
                        zone: zone
                    )
                }

                if !goalInsights.isEmpty {
                    WorkoutGoalProgressCard(
                        insights: goalInsights,
                        showsAddGoal: false,
                        onAddGoal: {},
                        onToggleCompletion: toggleGoalCompletion,
                        onGoalTap: { selectedGoal = $0 }
                    )
                }

                // PRs achieved (if any)
                if !achievedPRs.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "trophy.fill")
                                .foregroundStyle(.yellow)
                            Text("Personal Records!")
                                .font(.headline)
                                .foregroundStyle(.primary)
                        }

                        ForEach(Array(achievedPRs.keys.sorted()), id: \.self) { exerciseName in
                            if let prValue = achievedPRs[exerciseName] {
                                PRRow(prValue: prValue, usesMetric: usesMetric)
                            }
                        }
                    }
                    .padding()
                    .background(Color.yellow.opacity(0.15))
                    .clipShape(.rect(cornerRadius: 16))
                }

                // Exercises completed with full detail
                if !loggedEntries.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(entriesTitle)
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        ForEach(loggedEntries) { entry in
                            if entry.isStrength {
                                ExerciseSummaryRow(entry: entry, usesMetric: usesMetric)
                            } else {
                                ActivitySummaryRow(entry: entry, usesMetric: usesMetric)
                            }
                        }
                    }
                    .traiCard()
                }
            }
            .padding()
        }
        .overlay {
            if showConfetti {
                ConfettiView()
                    .allowsHitTesting(false)
                    .ignoresSafeArea()
            }
        }
        .task {
            if #available(iOS 27.0, *),
               workout.healthKitAvgHeartRate != nil {
                try? await healthKitService?.refreshPreferredHeartRateZones()
            }
            withAnimation {
                showConfetti = true
            }
            try? await Task.sleep(for: .milliseconds(300))
            showCelebration = true
        }
        .sheet(item: $selectedGoal) { goal in
            WorkoutGoalDetailSheet(
                goal: goal,
                workouts: allLiveWorkouts,
                sessions: goalProgressSessions,
                exerciseHistory: allExerciseHistory,
                useLbs: !usesMetric,
                onToggleCompletion: toggleGoalCompletion
            )
            .traiSheetBranding()
        }
        .alert(item: $persistenceError) { error in
            Alert(
                title: Text(error.title),
                message: Text(error.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    private func toggleGoalCompletion(_ goal: WorkoutGoal) {
        if goal.status == .completed {
            goal.markActive()
        } else {
            goal.markCompleted()
        }
        guard saveSummaryChange(title: "Workout Goal Not Updated") else { return }
        HapticManager.selectionChanged()
    }

    private func saveSummaryChange(title: String) -> Bool {
        do {
            try modelContext.save()
            return true
        } catch {
            modelContext.rollback()
            persistenceError = WorkoutSummaryPersistenceError(
                title: title,
                message: error.localizedDescription
            )
            HapticManager.error()
            return false
        }
    }
}

// MARK: - PR Row

private struct WorkoutSummaryPersistenceError: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

struct PRRow: View {
    let prValue: LiveWorkoutViewModel.PRValue
    let usesMetric: Bool

    private var weightUnit: String { usesMetric ? "kg" : "lbs" }

    /// Format a weight value (stored in kg) for display
    private func formatWeight(_ kg: Double) -> String {
        let value = usesMetric ? kg : kg * WeightUtility.kgToLbs
        let rounded = WeightUtility.round(value, unit: usesMetric ? .kg : .lbs)
        if rounded.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(rounded)) \(weightUnit)"
        }
        return String(format: "%.1f %@", rounded, weightUnit)
    }

    /// Format improvement value
    private func formatImprovement(_ kg: Double) -> String {
        let value = usesMetric ? kg : kg * WeightUtility.kgToLbs
        let rounded = WeightUtility.round(value, unit: usesMetric ? .kg : .lbs)
        if rounded.truncatingRemainder(dividingBy: 1) == 0 {
            return "+\(Int(rounded)) \(weightUnit)"
        }
        return String(format: "+%.1f %@", rounded, weightUnit)
    }

    /// Formatted new value respecting user's unit preference
    private var formattedNewValue: String {
        switch prValue.type {
        case .weight:
            return formatWeight(prValue.newValue)
        case .volume:
            return formatWeight(prValue.newValue) + prValue.volumePRMode.unitSuffix
        case .reps:
            return "\(Int(prValue.newValue)) reps"
        }
    }

    /// Formatted improvement respecting user's unit preference
    private var formattedImprovement: String {
        guard !prValue.isFirstTime && prValue.improvement > 0 else { return "" }
        switch prValue.type {
        case .weight:
            return formatImprovement(prValue.improvement)
        case .volume:
            return formatImprovement(prValue.improvement) + prValue.volumePRMode.unitSuffix
        case .reps:
            return "+\(Int(prValue.improvement)) reps"
        }
    }

    var body: some View {
        let metric = prValue.type.metricKind

        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(prValue.exerciseName)
                    .font(.subheadline)

                HStack(spacing: 6) {
                    Text(formattedNewValue)
                        .font(.caption)
                        .bold()
                        .foregroundStyle(.primary)

                    if prValue.isFirstTime {
                        Text("First time!")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    } else if !formattedImprovement.isEmpty {
                        Text(formattedImprovement)
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
            }

            Spacer()

            HStack(spacing: 4) {
                Image(systemName: metric.iconName)
                    .font(.caption2)
                Text(metric.label(for: prValue.volumePRMode))
                    .font(.caption)
            }
            .foregroundStyle(metric.color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(metric.color.opacity(0.15))
            .clipShape(.capsule)
        }
    }
}

// MARK: - Summary Header

private struct WorkoutHeartRateZoneSummaryCard: View {
    let averageHeartRate: Double
    let zone: HealthKitService.HeartRateZoneSummary

    private var rangeDescription: String? {
        switch (zone.minimumBPM, zone.maximumBPM) {
        case let (minimum?, maximum?):
            return "\(Int(minimum.rounded()))–\(Int(maximum.rounded())) BPM"
        case let (minimum?, nil):
            return "\(Int(minimum.rounded()))+ BPM"
        case let (nil, maximum?):
            return "Below \(Int(maximum.rounded())) BPM"
        case (nil, nil):
            return nil
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "heart.fill")
                .font(.title2)
                .foregroundStyle(.red)
                .frame(width: 44, height: 44)
                .background(.red.opacity(0.12), in: .circle)

            VStack(alignment: .leading, spacing: 3) {
                Text("Average Heart Rate")
                    .font(.subheadline.weight(.semibold))

                Text("\(Int(averageHeartRate.rounded())) BPM")
                    .font(.title3.weight(.bold))
                    .monospacedDigit()
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 4) {
                Text("Zone \(zone.index)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.accentColor.opacity(0.12), in: .capsule)

                if let rangeDescription {
                    Text(rangeDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
        }
        .traiCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Average heart rate, \(Int(averageHeartRate.rounded())) beats per minute, zone \(zone.index)"
        )
    }
}

private struct WorkoutSummaryHeader: View {
    let title: String
    let subtitle: String?
    let formattedDuration: String
    let entryStats: LiveWorkout.EntrySummaryStats
    let showCelebration: Bool
    let showConfetti: Bool

    private var subtitleText: String? {
        let trimmed = subtitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                ZStack {
                    TraiCelebrationRipple(isActive: showCelebration, color: .green)
                        .frame(width: 58, height: 58)

                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 46))
                        .foregroundStyle(.green)
                        .symbolEffect(.bounce, value: showConfetti)
                }
                .frame(width: 58, height: 58)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.traiHero(26))
                        .traiGradientText()
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)

                    if let subtitleText {
                        Text(subtitleText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            WorkoutSummaryMetricRibbon(
                formattedDuration: formattedDuration,
                entryStats: entryStats
            )
        }
        .traiCard()
    }
}

private struct WorkoutSummaryMetricRibbon: View {
    let formattedDuration: String
    let entryStats: LiveWorkout.EntrySummaryStats

    private var activityMetricStats: [WorkoutActivityMetricDisplayStat] {
        entryStats.activityMetricSegments.prefix(2).compactMap(WorkoutActivityMetricDisplayStat.init(segment:))
    }

    private var metrics: [WorkoutSummaryMetricItem] {
        var items = [
            WorkoutSummaryMetricItem(
                label: "Duration",
                value: formattedDuration,
                icon: "clock.fill"
            )
        ]

        if entryStats.strengthEntryCount > 0 {
            items.append(
                WorkoutSummaryMetricItem(
                    label: "Exercises",
                    value: "\(entryStats.strengthEntryCount)",
                    icon: "dumbbell.fill"
                )
            )
        }

        if entryStats.activityEntryCount > 0 {
            items.append(
                WorkoutSummaryMetricItem(
                    label: "Activities",
                    value: "\(entryStats.activityEntryCount)",
                    icon: "list.bullet.rectangle"
                )
            )
        }

        if entryStats.totalSets > 0 {
            items.append(
                WorkoutSummaryMetricItem(
                    label: "Sets",
                    value: "\(entryStats.totalSets)",
                    icon: "square.stack.3d.up.fill"
                )
            )
        }

        items.append(contentsOf: activityMetricStats.map {
            WorkoutSummaryMetricItem(label: $0.label, value: $0.value, icon: $0.icon)
        })

        return Array(items.prefix(4))
    }

    var body: some View {
        HStack(spacing: 8) {
            ForEach(metrics) { metric in
                WorkoutSummaryMetricPill(metric: metric)
            }
        }
    }
}

private struct WorkoutSummaryMetricItem: Identifiable {
    let label: String
    let value: String
    let icon: String

    var id: String { "\(label)-\(value)-\(icon)" }
}

struct WorkoutActivityMetricDisplayStat: Identifiable {
    let value: String
    let label: String
    let icon: String

    var id: String { "\(value)-\(label)" }

    nonisolated init?(segment: String) {
        let parts = segment.split(separator: " ", maxSplits: 1)
        guard let value = parts.first, !value.isEmpty else { return nil }

        self.value = String(value)
        self.label = parts.dropFirst().first.map { String($0).capitalized } ?? "Activity"
        self.icon = Self.icon(for: self.label)
    }

    nonisolated private static func icon(for label: String) -> String {
        switch label.lowercased() {
        case "attempt", "attempts":
            return "scope"
        case "round", "rounds":
            return "repeat"
        case "rep", "reps", "count", "counts":
            return "number"
        case "segment", "segments":
            return "square.stack.3d.up"
        default:
            return "chart.bar.fill"
        }
    }
}

private struct WorkoutSummaryMetricPill: View {
    let metric: WorkoutSummaryMetricItem

    private var iconColor: Color {
        switch metric.icon {
        case "dumbbell.fill":
            .green
        case "square.stack.3d.up.fill":
            .blue
        default:
            Color.accentColor
        }
    }

    var body: some View {
        VStack(spacing: 5) {
            Image(systemName: metric.icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(iconColor)

            Text(metric.value)
                .font(.traiBold(16))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .contentTransition(.numericText())

            Text(metric.label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 62)
        .padding(.horizontal, 6)
        .background(Color(.secondarySystemFill), in: RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Exercise Summary Row

struct ExerciseSummaryRow: View {
    let entry: LiveWorkoutEntry
    let usesMetric: Bool
    var onTap: (() -> Void)?

    private var weightUnit: String { usesMetric ? "kg" : "lbs" }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Exercise name and equipment
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.exerciseName)
                        .font(.subheadline)
                        .bold()

                    if let equipment = entry.equipmentName, !equipment.isEmpty {
                        Text("@ \(equipment)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if onTap != nil {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            // Sets breakdown
            let completedSets = entry.sets.filter { $0.reps > 0 && !$0.isWarmup }
            if !completedSets.isEmpty {
                // Check if all sets have the same weight - use condensed format
                let weights = Set(completedSets.map { $0.displayWeight(usesMetric: usesMetric) })
                if weights.count == 1, let weight = weights.first, weight > 0 {
                    // Condensed format: "3 sets: 12, 10, 8 @ 80 kg"
                    let reps = completedSets.map { "\($0.reps)" }.joined(separator: ", ")
                    let weightStr = weight.truncatingRemainder(dividingBy: 1) == 0
                        ? "\(Int(weight))"
                        : String(format: "%.1f", weight)
                    Text("\(completedSets.count) sets: \(reps) @ \(weightStr) \(weightUnit)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    // Original format with individual badges
                    HStack(spacing: 4) {
                        ForEach(completedSets.indices, id: \.self) { index in
                            let set = completedSets[index]
                            SetBadge(set: set, isBest: set == entry.bestSet, usesMetric: usesMetric)

                            if index < completedSets.count - 1 {
                                Text("•")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap?()
        }
    }
}

struct ActivitySummaryRow: View {
    let entry: LiveWorkoutEntry
    let usesMetric: Bool

    private var subtitleSegments: [String] {
        var segments: [String] = []

        if let role = visibleActivityRole {
            segments.append(role.placementDisplayName)
        }

        let activityName = entry.activityTypeName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !activityName.isEmpty, activityName.goalNormalizedKey != entry.exerciseName.goalNormalizedKey {
            segments.append(activityName)
        }

        if let duration = entry.formattedDuration {
            segments.append(duration)
        }

        if let distance = entry.formattedDistance {
            segments.append(distance)
        }

        let summarySegments = entry.traiActivitySummarySegments(usesMetric: usesMetric)
        let existingKeys = Set(segments.map(\.goalNormalizedKey))
        segments.append(contentsOf: summarySegments.filter { !existingKeys.contains($0.goalNormalizedKey) })

        return segments
    }

    private var visibleActivityRole: WorkoutPlan.TrainingBlock.Role? {
        guard let role = entry.activityRole else { return nil }
        switch role {
        case .main, .accessory, .custom:
            return nil
        case .warmup, .finisher, .cooldown:
            return role
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: entry.activityIconName)
                    .font(.subheadline)
                    .foregroundStyle(entry.isLoggedActivity ? .green : .secondary)
                    .frame(width: 28, height: 28)
                    .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.exerciseName)
                        .font(.subheadline)
                        .bold()

                    if !subtitleSegments.isEmpty {
                        Text(subtitleSegments.joined(separator: " • "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if !entry.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(entry.notes)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                    }
                }

                Spacer()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 6)
    }
}

// MARK: - Set Badge

struct SetBadge: View {
    let set: LiveWorkoutEntry.SetData
    let isBest: Bool
    let usesMetric: Bool

    var body: some View {
        let weight = set.displayWeight(usesMetric: usesMetric)
        let weightStr = weight.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(weight))"
            : String(format: "%.1f", weight)

        HStack(spacing: 2) {
            if isBest {
                Image(systemName: "star.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(.yellow)
            }
            Text("\(weightStr)×\(set.reps)")
                .font(.caption)
                .foregroundStyle(isBest ? .primary : .secondary)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(isBest ? Color.accentColor.opacity(0.2) : Color(.tertiarySystemFill))
        .clipShape(.rect(cornerRadius: 4))
    }
}

// MARK: - Preview

#Preview("LiveWorkout Summary") {
    WorkoutSummarySheet(workout: {
        let workout = LiveWorkout(
            name: "Push Day",
            workoutType: .strength,
            targetMuscleGroups: [.chest, .shoulders, .triceps]
        )
        workout.completedAt = Date()
        return workout
    }(), onDismiss: {})
}
