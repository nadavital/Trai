//
//  WorkoutDetailSheet.swift
//  Trai
//
//  Detailed view of a completed workout session
//

import SwiftUI
import SwiftData

struct WorkoutDetailSheet: View {
    let workout: WorkoutSession
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTabSelection) private var appTabSelection
    @Environment(\.modelContext) private var modelContext
    @Environment(MonetizationService.self) private var monetizationService: MonetizationService?
    @Environment(AccountSessionService.self) private var accountSessionService: AccountSessionService?
    @Environment(ProUpsellCoordinator.self) private var proUpsellCoordinator: ProUpsellCoordinator?
    @Query private var allExerciseHistory: [ExerciseHistory]
    @Query private var profiles: [UserProfile]
    @State private var isEditingNotes = false
    @State private var noteDraft = ""
    @State private var presentedAccountSetupContext: AccountSetupContext?
    @State private var persistenceError: WorkoutDetailPersistenceError?

    private struct DetailItem: Identifiable {
        let id = UUID()
        let label: String
        let value: String
    }

    init(workout: WorkoutSession) {
        self.workout = workout

        let exerciseName = workout.displayName
        let loggedAt = workout.loggedAt
        var exerciseHistoryDescriptor = FetchDescriptor<ExerciseHistory>(
            predicate: #Predicate<ExerciseHistory> { history in
                history.exerciseName == exerciseName && history.performedAt < loggedAt
            },
            sortBy: [SortDescriptor(\ExerciseHistory.performedAt, order: .reverse)]
        )
        exerciseHistoryDescriptor.fetchLimit = 80
        _allExerciseHistory = Query(exerciseHistoryDescriptor)

        var profileDescriptor = FetchDescriptor<UserProfile>()
        profileDescriptor.fetchLimit = 1
        _profiles = Query(profileDescriptor)
    }

    private var usesMetricExerciseWeight: Bool {
        profiles.first?.usesMetricExerciseWeight ?? true
    }

    private var weightUnit: String {
        usesMetricExerciseWeight ? "kg" : "lbs"
    }

    private var volumePRMode: UserProfile.VolumePRMode {
        profiles.first?.volumePRModeValue ?? .perSet
    }

    private var canAccessTraiChat: Bool {
        monetizationService?.canAccessAIFeatures ?? true
    }

    private func displayWeight(_ kg: Double) -> Int {
        let unit = WeightUnit(usesMetric: usesMetricExerciseWeight)
        return WeightUtility.displayInt(kg, displayUnit: unit)
    }

    private func displayVolume(_ volumeKg: Double) -> Int {
        let display = usesMetricExerciseWeight ? volumeKg : (volumeKg * WeightUtility.kgToLbs)
        return Int(display.rounded())
    }

    private func formatVolumePRValue(_ volumeKg: Double) -> String {
        let base = "\(displayVolume(volumeKg)) \(weightUnit)"
        let suffix = volumePRMode.unitSuffix
        if suffix.isEmpty {
            return base
        }
        return "\(base)\(suffix)"
    }

    private var workoutCategoryTitle: String {
        workout.activityContextSegments.prefix(2).joined(separator: " • ")
    }

    private var statsItems: [WorkoutDetailHeaderStat] {
        var items: [WorkoutDetailHeaderStat] = []

        if workout.sets > 0 {
            items.append(WorkoutDetailHeaderStat(
                value: "\(workout.sets)",
                label: workout.setMetricLabel,
                icon: "square.stack.3d.up.fill",
                color: .orange
            ))
        }

        if workout.reps > 0 {
            items.append(WorkoutDetailHeaderStat(
                value: "\(workout.reps)",
                label: workout.repMetricLabel,
                icon: "repeat",
                color: .green
            ))
        }

        if let weight = workout.weightKg {
            items.append(WorkoutDetailHeaderStat(
                value: "\(displayWeight(weight))",
                label: weightUnit,
                icon: "scalemass.fill",
                color: .indigo
            ))
        }

        if let duration = workout.durationMinutes {
            items.append(WorkoutDetailHeaderStat(
                value: formatDuration(duration),
                label: "Duration",
                icon: "clock.fill",
                color: .blue
            ))
        }

        if let distance = workout.distanceMeters {
            items.append(WorkoutDetailHeaderStat(
                value: formatDistance(distance),
                label: "Distance",
                icon: "figure.walk",
                color: .teal
            ))
        }

        if let heartRate = workout.averageHeartRate {
            items.append(WorkoutDetailHeaderStat(
                value: "\(heartRate)",
                label: "Avg BPM",
                icon: "heart.fill",
                color: .pink
            ))
        }

        if let calories = workout.caloriesBurned {
            items.append(WorkoutDetailHeaderStat(
                value: "\(calories)",
                label: "kcal",
                icon: "flame.fill",
                color: .red
            ))
        }

        return items
    }

    private var detailItems: [DetailItem] {
        var items: [DetailItem] = [
            DetailItem(label: "Activity", value: workout.activityContextSegments.joined(separator: ", "))
        ]

        if workout.isStrengthTraining, let volume = workout.totalVolume {
            items.append(DetailItem(label: "Strength Volume", value: "\(displayVolume(volume)) \(weightUnit)"))
        }

        if workout.sourceIsHealthKit {
            items.append(DetailItem(label: "Source", value: "Apple Health"))
        }

        items.append(
            DetailItem(
                label: "Logged",
                value: workout.loggedAt.formatted(date: .abbreviated, time: .shortened)
            )
        )

        return items
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    headerSection

                    traiReviewSection

                    // PR highlights (if any)
                    if !prHighlights.isEmpty {
                        prSection
                    }

                    // Workout details
                    detailsSection

                    notesSection

                    // HealthKit info
                    if workout.sourceIsHealthKit {
                        healthKitSection
                    }
                }
                .padding()
            }
            .navigationTitle("Session Details")
            .toolbarTitleDisplayMode(.inlineLarge)
            .onAppear {
                if noteDraft.isEmpty {
                    noteDraft = workout.notes ?? ""
                }
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", systemImage: "checkmark") {
                        dismiss()
                    }
                    .labelStyle(.iconOnly)
                }
            }
        }
        .sheet(item: $presentedAccountSetupContext) { context in
            AccountSetupView(context: context)
        }
        .alert(item: $persistenceError) { error in
            Alert(
                title: Text(error.title),
                message: Text(error.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        WorkoutDetailHeaderCard(
            icon: workout.iconName,
            title: workout.displayName,
            subtitle: workoutCategoryTitle,
            date: workout.loggedAt,
            stats: statsItems
        )
    }

    @ViewBuilder
    private var traiReviewSection: some View {
        if canAccessTraiChat {
            WorkoutTraiReviewCard(
                title: "Review with Trai",
                subtitle: "Ask what this session means for your next workout.",
                action: reviewSessionWithTrai
            )
        } else {
            ProUpsellInlineCard(
                source: .workoutReview,
                actionTitle: "Unlock Trai Pro",
                showsShadow: false,
                action: {
                    proUpsellCoordinator?.present(source: .workoutReview)
                }
            )
        }
    }

    // MARK: - Details Section

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Session Details")
                .font(.headline)

            VStack(spacing: 0) {
                ForEach(Array(detailItems.enumerated()), id: \.element.id) { index, item in
                    DetailRow(label: item.label, value: item.value)

                    if index < detailItems.count - 1 {
                        Divider()
                            .padding(.horizontal)
                    }
                }
            }
            .traiCard()
        }
    }

    // MARK: - PR Section

    private struct PRHighlight: Identifiable {
        let id = UUID()
        let kind: PRMetricKind
        let label: String
        let value: String
    }

    private var prHighlights: [PRHighlight] {
        guard workout.isStrengthTraining else { return [] }

        let previousEntries = allExerciseHistory
        guard !previousEntries.isEmpty else { return [] }

        var highlights: [PRHighlight] = []

        if let weight = workout.weightKg,
           weight > 0,
           weight > (previousEntries.map(\.bestSetWeightKg).max() ?? 0) {
            highlights.append(PRHighlight(
                kind: .weight,
                label: PRMetricKind.weight.label,
                value: "\(displayWeight(weight)) \(weightUnit)",
            ))
        }

        if workout.reps > 0,
           workout.reps > (previousEntries.map(\.bestSetReps).max() ?? 0) {
            highlights.append(PRHighlight(
                kind: .reps,
                label: PRMetricKind.reps.label,
                value: "\(workout.reps) reps",
            ))
        }

        if let volume = workout.volumeValue(for: volumePRMode),
           volume > 0,
           volume > (previousEntries.map { $0.volumeValue(for: volumePRMode) }.max() ?? 0) {
            highlights.append(PRHighlight(
                kind: .volume,
                label: PRMetricKind.volume.label(for: volumePRMode),
                value: formatVolumePRValue(volume),
            ))
        }

        return highlights
    }

    private var prSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "trophy.fill")
                    .foregroundStyle(.yellow)
                Text("Personal Records")
                    .font(.headline)
            }

            VStack(spacing: 8) {
                ForEach(prHighlights) { pr in
                    HStack(spacing: 10) {
                        Image(systemName: pr.kind.iconName)
                            .foregroundStyle(pr.kind.color)
                        Text(pr.label)
                            .fontWeight(.medium)
                        Spacer()
                        Text(pr.value)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color(.tertiarySystemBackground))
                    .clipShape(.rect(cornerRadius: 10))
                }
            }
            .traiCard()
        }
    }

    // MARK: - Notes Section

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Trai Notes")
                    .font(.headline)

                Spacer()

                if isEditingNotes {
                    Button("Save") {
                        saveNotes()
                    }
                    .font(.subheadline.weight(.semibold))
                    .tint(.accentColor)
                } else {
                    Button((workout.notes ?? "").isEmpty ? "Add Note" : "Edit") {
                        noteDraft = workout.notes ?? ""
                        isEditingNotes = true
                    }
                    .font(.subheadline.weight(.semibold))
                }
            }

            if isEditingNotes {
                VStack(alignment: .leading, spacing: 10) {
                    TextEditor(text: $noteDraft)
                        .frame(minHeight: 120)
                        .scrollContentBackground(.hidden)
                        .padding(10)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))

                    HStack {
                        Text("Add context like route grade, intervals, energy, technique notes, or what felt different.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Spacer()

                        Button("Cancel") {
                            noteDraft = workout.notes ?? ""
                            isEditingNotes = false
                        }
                        .font(.caption.weight(.semibold))
                    }
                }
            } else if let notes = workout.notes, !notes.isEmpty {
                Text(notes)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text(workout.sourceIsHealthKit ? "Imported workout, no Trai notes yet." : "No session notes yet.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text("You can add a quick note afterward so Trai can use it as progression context later.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    // MARK: - HealthKit Section

    private var healthKitSection: some View {
        HStack(spacing: 8) {
            Image(systemName: "heart.fill")
                .foregroundStyle(.red)
            Text("Imported from Apple Health")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.red.opacity(0.1))
        .clipShape(.rect(cornerRadius: 12))
    }

    // MARK: - Helpers

    private func formatDuration(_ minutes: Double) -> String {
        let totalMinutes = Int(minutes)
        if totalMinutes >= 60 {
            let hours = totalMinutes / 60
            let mins = totalMinutes % 60
            return "\(hours)h \(mins)m"
        }
        return "\(totalMinutes)m"
    }

    private func formatDistance(_ meters: Double) -> String {
        if meters >= 1000 {
            return String(format: "%.1f km", meters / 1000)
        }
        return "\(Int(meters)) m"
    }

    private func saveNotes() {
        let trimmed = noteDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        workout.notes = trimmed.isEmpty ? nil : trimmed
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            persistenceError = WorkoutDetailPersistenceError(
                title: "Notes Not Saved",
                message: error.localizedDescription
            )
            HapticManager.error()
            return
        }
        isEditingNotes = false
        HapticManager.selectionChanged()
    }

    private func reviewSessionWithTrai() {
        guard canAccessTraiChat else {
            proUpsellCoordinator?.present(source: .workoutReview)
            HapticManager.lightTap()
            return
        }
        guard accountSessionService?.isAuthenticated != false else {
            presentedAccountSetupContext = .aiFeatures
            HapticManager.lightTap()
            return
        }
        guard !PendingTraiChatLaunchRequest.hasValidPendingTraiChatPayload() else {
            dismiss()
            DispatchQueue.main.async {
                appTabSelection.wrappedValue = .trai
            }
            HapticManager.selectionChanged()
            return
        }

        PendingTraiChatLaunchRequest(
            launchLabel: "Reviewing your latest session...",
            contextAttachmentStorageValue: workout.traiChatContextAttachment.storageValue
        ).write()
        BehaviorTracker(modelContext: modelContext).recordDeferred(
            actionKey: "engagement.review_workout_session_with_trai",
            domain: .engagement,
            surface: .workouts,
            outcome: .opened,
            relatedEntityId: workout.id,
            metadata: [
                "source": workout.sourceIsHealthKit ? "imported_session_detail" : "session_detail",
                "workout_name": workout.displayName
            ]
        )
        dismiss()
        DispatchQueue.main.async {
            appTabSelection.wrappedValue = .trai
        }
        HapticManager.selectionChanged()
    }
}

// MARK: - Detail Row

private struct WorkoutDetailPersistenceError: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }
}

// MARK: - Shared Workout Detail Header

struct WorkoutDetailHeaderStat: Identifiable {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var id: String { "\(icon)-\(value)-\(label)" }
}

struct WorkoutDetailHeaderCard: View {
    let icon: String
    let title: String
    let subtitle: String?
    let date: Date
    let stats: [WorkoutDetailHeaderStat]

    private var subtitleText: String? {
        let trimmed = subtitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                titleCluster
                if !stats.isEmpty {
                    Spacer(minLength: 8)
                    statRow(stats)
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                titleCluster
                if !stats.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        statRow(stats)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .traiCard(cornerRadius: 16, contentPadding: 0)
    }

    private var titleCluster: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(.accent)
                .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.traiBold(20))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                if let subtitleText {
                    Text(subtitleText)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }

                Text(date, format: .dateTime.weekday(.wide).month().day().hour().minute())
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
    }

    private func statRow(_ stats: [WorkoutDetailHeaderStat]) -> some View {
        HStack(spacing: 8) {
            ForEach(stats) { stat in
                WorkoutDetailHeaderStatPill(stat: stat)
            }
        }
        .fixedSize(horizontal: true, vertical: false)
    }
}

private struct WorkoutDetailHeaderStatPill: View {
    let stat: WorkoutDetailHeaderStat

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: stat.icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(stat.color)

            Text(stat.value)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Text(stat.label)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(minWidth: 64)
        .frame(height: 32)
        .padding(.horizontal, 8)
        .background(Color(.secondarySystemFill), in: Capsule())
    }
}

// MARK: - Preview

#Preview("WorkoutSession Detail") {
    WorkoutDetailSheet(workout: {
        let workout = WorkoutSession()
        workout.exerciseName = "Evening Climb"
        workout.healthKitWorkoutType = "climbing"
        workout.durationMinutes = 75
        workout.caloriesBurned = 480
        workout.averageHeartRate = 134
        workout.notes = "Focused on technique drills and easier endurance laps."
        return workout
    }())
}
