//
//  LiveWorkoutView.swift
//  Trai
//
//  Full-screen live workout tracking interface
//

import ActivityKit
import SwiftUI
import SwiftData

struct LiveWorkoutView: View {
    private enum LiveWorkoutSheet: Identifiable {
        case exerciseList
        case exerciseReplacement(LiveWorkoutEntry)
        case chat

        var id: String {
            switch self {
            case .exerciseList:
                return "exerciseList"
            case .exerciseReplacement(let entry):
                return "exerciseReplacement-\(entry.id.uuidString)"
            case .chat:
                return "chat"
            }
        }
    }

    private enum LiveWorkoutAlert: Identifiable {
        case liveActivityDisabled
        case persistenceFailure(title: String, message: String)

        var id: String {
            switch self {
            case .liveActivityDisabled:
                return "liveActivityDisabled"
            case .persistenceFailure(let title, let message):
                return "persistenceFailure-\(title)-\(message)"
            }
        }
    }

    // MARK: - Properties

    @State private var viewModel: LiveWorkoutViewModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(HealthKitService.self) private var healthKitService: HealthKitService?
    @EnvironmentObject private var activeWorkoutRuntimeState: ActiveWorkoutRuntimeState
    @Query private var profiles: [UserProfile]
    @Query private var workoutGoals: [WorkoutGoal]
    @Query private var activityTypeExercises: [Exercise]
    private static let activeWorkoutGoalFetchLimit = 24
    private static let activityTypeExerciseFetchLimit = 80

    private var usesMetricExerciseWeight: Bool {
        profiles.first?.usesMetricExerciseWeight ?? true
    }
    private var planTargets: [MuscleGroupSelector.PlanTarget] {
        guard let templates = profiles.first?.workoutPlan?.templates else { return [] }

        var seen: Set<String> = []
        return templates
            .sorted { $0.order < $1.order }
            .compactMap { template in
                let title = template.name.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !title.isEmpty else { return nil }
                let key = title.lowercased()
                guard seen.insert(key).inserted else { return nil }

                return MuscleGroupSelector.PlanTarget(
                    id: template.id,
                    title: title,
                    iconName: template.sessionType.iconName,
                    muscles: template.sessionType.supportsMuscleTargets
                        ? LiveWorkout.MuscleGroup.fromTargetStrings(template.resolvedTargetMuscleGroups)
                        : [],
                    categories: activityCategories(for: template),
                    activityTypes: activityTypes(for: template)
                )
            }
    }

    private var activityTypeTargets: [MuscleGroupSelector.ActivityTypeTarget] {
        var seen: Set<String> = []
        return activityTypeExercises.compactMap { exercise in
            guard exercise.exerciseCategory != .strength else { return nil }
            let title = exercise.activityTypeName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty else { return nil }
            let key = title.goalNormalizedKey
            guard seen.insert(key).inserted else { return nil }
            return MuscleGroupSelector.ActivityTypeTarget(
                id: key,
                title: title,
                iconName: exercise.exerciseCategory.iconName,
                categories: [exercise.exerciseCategory]
            )
        }
    }
    private let finishOnPresentation: Bool

    private var relevantSessionGoals: [WorkoutGoal] {
        WorkoutGoalProgressResolver.relevantGoals(
            for: viewModel.workout,
            goals: workoutGoals,
            includeCompleted: false
        )
    }

    // Heart rate update timer
    @State private var heartRateTimer: Timer?

    // Presentation state
    @State private var activeSheet: LiveWorkoutSheet?
    @State private var showingCancelConfirmation = false
    @State private var showingEndConfirmation = false
    @State private var showingSummary = false
    @State private var activeAlert: LiveWorkoutAlert?
    @State private var didApplyPresentationFinishRequest = false
    @State private var shouldDismissAfterCancelConfirmation = false
    @State private var focusedSetID: UUID?
    private let onCancelled: (() -> Void)?

    // MARK: - Initialization

    init(
        workout: LiveWorkout,
        template: WorkoutPlan.WorkoutTemplate? = nil,
        finishOnPresentation: Bool = false,
        onCancelled: (() -> Void)? = nil
    ) {
        self._viewModel = State(initialValue: LiveWorkoutViewModel(workout: workout, template: template))
        self.finishOnPresentation = finishOnPresentation
        self.onCancelled = onCancelled

        var profileDescriptor = FetchDescriptor<UserProfile>()
        profileDescriptor.fetchLimit = 1
        _profiles = Query(profileDescriptor)

        var workoutGoalDescriptor = FetchDescriptor<WorkoutGoal>(
            predicate: #Predicate<WorkoutGoal> { $0.statusRaw == "active" },
            sortBy: [SortDescriptor(\WorkoutGoal.updatedAt, order: .reverse)]
        )
        workoutGoalDescriptor.fetchLimit = Self.activeWorkoutGoalFetchLimit
        _workoutGoals = Query(workoutGoalDescriptor)

        var activityTypeExerciseDescriptor = FetchDescriptor<Exercise>(
            predicate: #Predicate<Exercise> { $0.isCustom && $0.category != "strength" },
            sortBy: [SortDescriptor(\Exercise.name)]
        )
        activityTypeExerciseDescriptor.fetchLimit = Self.activityTypeExerciseFetchLimit
        _activityTypeExercises = Query(activityTypeExerciseDescriptor)
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            navigationContent
        }
        .sheet(item: $activeSheet, content: liveWorkoutSheet)
        .tint(Color("AccentColor"))
        .accentColor(Color("AccentColor"))
        .traiBackground()
        .accessibilityIdentifier("liveWorkoutView")
    }

    private var navigationContent: some View {
        Group {
            if showingSummary {
                WorkoutSummaryContent(
                    workout: viewModel.workout,
                    achievedPRs: viewModel.achievedPRs,
                    onDismiss: handleSummaryDone
                )
            } else {
                workoutContent
            }
        }
        .navigationTitle(showingSummary ? "Summary" : viewModel.workoutName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { liveWorkoutToolbar }
        .onAppear(perform: handleAppear)
        .onDisappear(perform: handleDisappear)
        .confirmationDialog("Cancel Workout", isPresented: $showingCancelConfirmation, titleVisibility: .visible) {
            Button("Cancel Workout", role: .destructive, action: cancelWorkout)
            Button("Continue Workout", role: .cancel) {}
        } message: {
            Text("Are you sure you want to cancel this workout? All progress will be lost.")
        }
        .onChange(of: showingCancelConfirmation, handleCancelConfirmationChange)
        .confirmationDialog("End Workout", isPresented: $showingEndConfirmation, titleVisibility: .visible) {
            Button("End Workout", action: finishAndShowSummary)
                .disabled(viewModel.isWorkoutFinished || viewModel.isFinishingWorkout)
            Button("Continue", role: .cancel) {}
        } message: {
            Text("Are you ready to finish this workout?")
        }
        .alert(item: $activeAlert) { alert in
            switch alert {
            case .liveActivityDisabled:
                Alert(
                    title: Text("Live Activity Disabled"),
                    message: Text("Enable Live Activities in Settings to see workout progress on your Lock Screen and Dynamic Island."),
                    primaryButton: .default(Text("Open Settings"), action: openAppSettings),
                    secondaryButton: .cancel(Text("Not Now"))
                )
            case .persistenceFailure(let title, let message):
                Alert(
                    title: Text(title),
                    message: Text(message),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }

    @ToolbarContentBuilder
    private var liveWorkoutToolbar: some ToolbarContent {
        if showingSummary {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done", systemImage: "checkmark", action: handleSummaryDone)
                    .labelStyle(.iconOnly)
            }
        } else {
            if AppLaunchArguments.isUITesting && AppLaunchArguments.shouldUseLiveWorkoutUITestPreset {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Stress +4", systemImage: "bolt.fill", action: applyUITestStressMutationBurst)
                        .accessibilityIdentifier("liveWorkoutStressAddSetBurst")
                }
            }

            ToolbarItem(placement: .cancellationAction) {
                Button {
                    showingCancelConfirmation = true
                } label: {
                    Image(systemName: "xmark")
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("End", systemImage: "checkmark") {
                    showingEndConfirmation = true
                }
                .labelStyle(.iconOnly)
                .accessibilityIdentifier("liveWorkoutEndButton")
                .tint(.accentColor)
                .disabled(viewModel.isWorkoutFinished || viewModel.isFinishingWorkout)
            }
        }
    }

    private func handleAppear() {
        activeWorkoutRuntimeState.beginLiveWorkoutPresentation()
        if let error = viewModel.setup(with: modelContext, healthKitService: healthKitService) {
            activeAlert = .persistenceFailure(
                title: "Workout Not Started",
                message: error.localizedDescription
            )
            return
        }
        startHeartRateUpdates()
        applyPresentationFinishRequestIfNeeded()

        if !AppLaunchArguments.isUITesting && !ActivityAuthorizationInfo().areActivitiesEnabled {
            activeAlert = .liveActivityDisabled
        }
    }

    private func handleDisappear() {
        activeWorkoutRuntimeState.endLiveWorkoutPresentation()
        stopHeartRateUpdates()
    }

    private func cancelWorkout() {
        viewModel.cancelWorkout(using: modelContext)
        onCancelled?()
        shouldDismissAfterCancelConfirmation = true
        showingCancelConfirmation = false
    }

    private func handleCancelConfirmationChange(_ oldValue: Bool, _ isShowing: Bool) {
        guard !isShowing, shouldDismissAfterCancelConfirmation else { return }
        shouldDismissAfterCancelConfirmation = false
        Task { @MainActor in
            await Task.yield()
            dismiss()
        }
    }

    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    @ViewBuilder
    private func liveWorkoutSheet(_ sheet: LiveWorkoutSheet) -> some View {
        switch sheet {
        case .exerciseList:
            ExerciseListView(
                targetMuscleGroups: viewModel.workout.muscleGroups.map { $0.toExerciseMuscleGroup },
                targetActivityCategories: viewModel.targetActivityCategories,
                targetActivityTypes: viewModel.targetActivityTypes,
                title: viewModel.usesFocusedCardioWorkspace ? "Select Activity" : "Select Exercise"
            ) { exercise in
                viewModel.addExercise(exercise)
            }
        case .exerciseReplacement(let entry):
            ExerciseListView(
                targetMuscleGroups: viewModel.workout.muscleGroups.map { $0.toExerciseMuscleGroup },
                targetActivityCategories: viewModel.targetActivityCategories,
                targetActivityTypes: viewModel.targetActivityTypes,
                title: "Replace Exercise"
            ) { exercise in
                viewModel.replaceExercise(entry, with: exercise)
                activeSheet = nil
            }
        case .chat:
            NavigationStack {
                ChatView(
                    workoutContext: buildWorkoutContext(),
                    initialContextAttachment: viewModel.workout.traiChatContextAttachment
                )
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done", systemImage: "checkmark") {
                                activeSheet = nil
                            }
                            .labelStyle(.iconOnly)
                        }
                    }
            }
        }
    }

    // MARK: - Workout Content

    private func applyPresentationFinishRequestIfNeeded() {
        guard finishOnPresentation else { return }
        guard !didApplyPresentationFinishRequest else { return }
        guard viewModel.workout.completedAt == nil else { return }

        didApplyPresentationFinishRequest = true
        finishAndShowSummary()
    }

    private func finishAndShowSummary() {
        guard !viewModel.isFinishingWorkout else { return }

        if !viewModel.isWorkoutFinished {
            if let error = viewModel.finishWorkout() {
                activeAlert = .persistenceFailure(
                    title: "Workout Not Finished",
                    message: error.localizedDescription
                )
                HapticManager.error()
                return
            }
        }

        withAnimation {
            showingSummary = true
        }
    }

    @ViewBuilder
    private var workoutContent: some View {
        if viewModel.usesGeneralSessionWorkspace {
            generalWorkoutContent
        } else {
            structuredWorkoutContent
        }
    }

    private var generalWorkoutContent: some View {
        ZStack(alignment: .bottom) {
            ScrollViewReader { scrollProxy in
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 16) {
                        WorkoutTimerHeader(
                            workoutStartedAt: viewModel.workout.startedAt,
                            isTimerRunning: viewModel.isTimerRunning,
                            totalPauseDuration: viewModel.totalPauseDuration,
                            pausedElapsedTime: viewModel.pausedElapsedTimeSnapshot,
                            totalVolume: viewModel.totalVolume,
                            onTogglePause: {
                                if viewModel.isTimerRunning {
                                    viewModel.pauseTimer()
                                } else {
                                    viewModel.resumeTimer()
                                }
                            },
                            showsWatchSyncButton: !viewModel.isWatchConnected,
                            isWatchSyncing: viewModel.isRetryingWatchSync,
                            onRetryWatchSync: {
                                viewModel.retryWatchSync()
                            },
                            watchConnectionHint: viewModel.watchConnectionHint,
                            heartRate: viewModel.isWatchConnected ? viewModel.currentHeartRate : nil,
                            calories: viewModel.isWatchConnected ? viewModel.workoutCalories : nil
                        )

                        workoutTargetSelector

                        GeneralSessionOverviewCard(workout: viewModel.workout)

                        SessionNotesCard(
                            notes: Binding(
                                get: { viewModel.workout.notes },
                                set: { viewModel.updateWorkoutNotes($0) }
                            )
                        )

                        if viewModel.entries.isEmpty {
                            ContentUnavailableView(
                                "No Activities Yet",
                                systemImage: viewModel.workout.type.iconName,
                                description: Text("Add exercises or activities to track in this session.")
                            )
                            .padding(.top, 8)
                        } else {
                            ForEach(viewModel.entries, id: \.id) { entry in
                                workoutEntryCard(entry)
                            }
                        }

                        Color.clear.frame(height: 100)
                    }
                    .padding()
                }
                .scrollDismissesKeyboard(.interactively)
                .simultaneousGesture(
                    TapGesture().onEnded {
                        dismissKeyboard()
                    }
                )
                .onChange(of: focusedSetID) { _, setID in
                    scrollFocusedSet(setID, with: scrollProxy)
                }
            }

            WorkoutBottomBar(
                onAddExercise: { activeSheet = .exerciseList },
                onAskTrai: { activeSheet = .chat },
                addLabel: "Add Exercise",
                addSystemImage: "plus.circle.fill"
            )
        }
    }

    private var structuredWorkoutContent: some View {
        ZStack(alignment: .bottom) {
            ScrollViewReader { scrollProxy in
                ScrollView(showsIndicators: false) {
                    let entries = viewModel.entries
                    let upNext = viewModel.upNextSuggestion
                    let availableSuggestions = viewModel.availableSuggestions
                    let suggestionsByMuscle = viewModel.suggestionsByMuscle
                    let upNextSuggestionID = upNext?.id

                    LazyVStack(spacing: 16) {
                        // Timer header with optional watch data
                        WorkoutTimerHeader(
                            workoutStartedAt: viewModel.workout.startedAt,
                            isTimerRunning: viewModel.isTimerRunning,
                            totalPauseDuration: viewModel.totalPauseDuration,
                            pausedElapsedTime: viewModel.pausedElapsedTimeSnapshot,
                            totalVolume: viewModel.totalVolume,
                            onTogglePause: {
                                if viewModel.isTimerRunning {
                                    viewModel.pauseTimer()
                                } else {
                                    viewModel.resumeTimer()
                                }
                            },
                            showsWatchSyncButton: !viewModel.isWatchConnected,
                            isWatchSyncing: viewModel.isRetryingWatchSync,
                            onRetryWatchSync: {
                                viewModel.retryWatchSync()
                            },
                            watchConnectionHint: viewModel.watchConnectionHint,
                            heartRate: viewModel.isWatchConnected ? viewModel.currentHeartRate : nil,
                            calories: viewModel.isWatchConnected ? viewModel.workoutCalories : nil
                        )

                        workoutTargetSelector

                        // Planned and ad hoc workout entries share the same logging surface.
                        ForEach(entries, id: \.id) { entry in
                            workoutEntryCard(entry)
                        }

                        // Up Next suggestion (smart rotation)
                        if let upNext {
                            UpNextSuggestionCard(
                                suggestion: upNext,
                                lastPerformance: viewModel.lastPerformances[upNext.exerciseName],
                                usesMetricWeight: usesMetricExerciseWeight
                            ) {
                                viewModel.addUpNextExercise()
                            }
                        }

                        // More suggestions by muscle group
                        if !availableSuggestions.isEmpty {
                            // Filter out the up next suggestion from the grouped view
                            let filteredSuggestions = suggestionsByMuscle.mapValues { suggestions in
                                guard let upNextSuggestionID else { return suggestions }
                                return suggestions.filter { $0.id != upNextSuggestionID }
                            }.filter { !$0.value.isEmpty }

                            if !filteredSuggestions.isEmpty {
                                SuggestionsByMuscleSection(
                                    suggestionsByMuscle: filteredSuggestions,
                                    lastPerformances: viewModel.lastPerformances
                                ) { suggestion in
                                    viewModel.addExerciseFromSuggestion(suggestion)
                                }
                            }
                        }

                        if entries.isEmpty && upNext == nil && availableSuggestions.isEmpty {
                            ContentUnavailableView(
                                "No Exercises Yet",
                                systemImage: "figure.mixed.cardio",
                                description: Text("Add an exercise or activity to track in this session.")
                            )
                            .padding(.top, 4)
                        }

                        // Bottom padding for the bar
                        Color.clear.frame(height: 100)
                    }
                    .padding()
                }
                .scrollDismissesKeyboard(.interactively)
                .simultaneousGesture(
                    TapGesture().onEnded {
                        dismissKeyboard()
                    }
                )
                .onChange(of: focusedSetID) { _, setID in
                    scrollFocusedSet(setID, with: scrollProxy)
                }
            }

            // Bottom bar
            WorkoutBottomBar(
                onAddExercise: { activeSheet = .exerciseList },
                onAskTrai: { activeSheet = .chat },
                addLabel: viewModel.usesFocusedCardioWorkspace ? "Add Interval" : "Add Exercise",
                addSystemImage: "plus.circle.fill"
            )
        }
    }

    @ViewBuilder
    private func workoutEntryCard(_ entry: LiveWorkoutEntry) -> some View {
        if entry.isStrength {
            ExerciseCard(
                entry: entry,
                lastPerformance: viewModel.lastPerformances[entry.exerciseName],
                personalRecord: viewModel.personalRecords[entry.exerciseName],
                usesMetricWeight: usesMetricExerciseWeight,
                onAddSet: { viewModel.addSet(to: entry) },
                onRemoveSet: { setIndex in viewModel.removeSet(at: setIndex, from: entry) },
                onUpdateSet: { setIndex, reps, weightKg, weightLbs, notes, preferredWeightUnit in
                    viewModel.updateSet(
                        at: setIndex,
                        in: entry,
                        reps: reps,
                        weightKg: weightKg,
                        weightLbs: weightLbs,
                        notes: notes,
                        preferredWeightUnit: preferredWeightUnit
                    )
                },
                onToggleWarmup: { setIndex in viewModel.toggleWarmup(at: setIndex, in: entry) },
                onDeleteExercise: { removeEntry(entry) },
                onChangeExercise: {
                    activeSheet = .exerciseReplacement(entry)
                },
                setRowScrollID: setRowScrollID,
                onFocusedSetChange: { focusedSetID = $0 }
            )
        } else {
            CardioExerciseCard(
                entry: entry,
                usesMetricWeight: usesMetricExerciseWeight,
                onUpdateDuration: { seconds in
                    viewModel.updateCardioDuration(for: entry, seconds: seconds)
                },
                onUpdateDistance: { meters in
                    viewModel.updateCardioDistance(for: entry, meters: meters)
                },
                onUpdateSetCount: { count in
                    viewModel.updateEntrySetCount(for: entry, count: count)
                },
                onUpdateReps: { reps in
                    viewModel.updateEntryReps(for: entry, reps: reps)
                },
                onUpdateWeightKg: { weightKg in
                    viewModel.updateEntryWeight(for: entry, weightKg: weightKg)
                },
                onUpdateNotes: { notes in
                    viewModel.updateEntryNotes(for: entry, notes: notes)
                },
                onAddSegment: { viewModel.addActivitySegment(to: entry) },
                onUpdateSegmentDuration: { index, seconds in
                    viewModel.updateActivitySegment(for: entry, at: index, durationSeconds: seconds)
                },
                onUpdateSegmentDistance: { index, meters in
                    viewModel.updateActivitySegment(for: entry, at: index, distanceMeters: meters)
                },
                onUpdateSegmentReps: { index, reps in
                    viewModel.updateActivitySegment(for: entry, at: index, reps: reps)
                },
                onUpdateSegmentWeightKg: { index, weightKg in
                    viewModel.updateActivitySegment(for: entry, at: index, weightKg: weightKg)
                },
                onUpdateSegmentNotes: { index, notes in
                    viewModel.updateActivitySegment(for: entry, at: index, notes: notes)
                },
                onRemoveSegment: { index in
                    viewModel.removeActivitySegment(from: entry, at: index)
                },
                onDeleteExercise: { removeEntry(entry) }
            )
        }
    }

    private var workoutTargetSelector: some View {
        MuscleGroupSelector(
            selectedMuscles: Binding(
                get: { Set(viewModel.workout.muscleGroups) },
                set: { viewModel.updateMuscleGroups(Array($0)) }
            ),
            selectedActivityCategories: Binding(
                get: { Set(viewModel.targetActivityCategories) },
                set: { viewModel.updateActivityTargets(Array($0)) }
            ),
            selectedActivityTypes: Binding(
                get: { Set(viewModel.targetActivityTypes) },
                set: { selectedTypes in viewModel.updateActivityTypeTargets(Array(selectedTypes)) }
            ),
            isCustomWorkout: viewModel.exerciseSuggestions.isEmpty,
            planTargets: planTargets,
            activityTypeTargets: activityTypeTargets,
            showsMuscleTargets: viewModel.workout.type.supportsMuscleTargets
                || viewModel.workout.type == .custom,
            onSelectPlanTarget: { target in
                viewModel.applyPlanTarget(
                    sourcePlanTemplateID: target.id,
                    name: target.title,
                    muscles: target.muscles,
                    categories: target.categories,
                    activityTypes: target.activityTypes
                )
            }
        )
    }

    // MARK: - Helpers

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private func setRowScrollID(for setID: UUID) -> String {
        "liveWorkoutSet-\(setID.uuidString)"
    }

    private func scrollFocusedSet(_ setID: UUID?, with scrollProxy: ScrollViewProxy) {
        guard let setID else { return }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(260))
            withAnimation(.easeInOut(duration: 0.2)) {
                scrollProxy.scrollTo(setRowScrollID(for: setID), anchor: .center)
            }
        }
    }

    private func handleSummaryDone() {
        dismiss()
    }

    private func removeEntry(_ entry: LiveWorkoutEntry) {
        guard let index = viewModel.entries.firstIndex(where: { $0.id == entry.id }) else { return }
        viewModel.removeExercise(at: index)
    }

    private func activityCategories(for template: WorkoutPlan.WorkoutTemplate) -> [Exercise.Category] {
        var categories: [Exercise.Category] = []

        func append(_ category: Exercise.Category) {
            guard !categories.contains(category) else { return }
            categories.append(category)
        }

        switch template.sessionType {
        case .strength:
            break
        case .cardio:
            append(.cardio)
        case .hiit:
            append(.conditioning)
        case .climbing:
            append(.sportPractice)
        case .yoga, .pilates, .mobility, .flexibility:
            append(.mobility)
        case .recovery:
            append(.recovery)
        case .mixed, .custom:
            break
        }

        for block in template.displayBlocks {
            switch block.kind {
            case .cardio:
                append(.cardio)
            case .conditioning:
                append(.conditioning)
            case .mobility:
                append(.mobility)
            case .recovery:
                append(.recovery)
            case .skill, .sportPractice:
                append(.sportPractice)
            case .strength, .custom:
                continue
            }
        }

        return categories
    }

    private func activityTypes(for template: WorkoutPlan.WorkoutTemplate) -> [String] {
        var seen: Set<String> = []
        return template.displayBlocks.compactMap { block in
            guard block.kind != .strength else { return nil }
            let name = block.displayActivityName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { return nil }
            let key = name.goalNormalizedKey
            guard !key.isEmpty, seen.insert(key).inserted else { return nil }
            return name
        }
    }

    private func applyUITestStressMutationBurst() {
        guard AppLaunchArguments.isUITesting,
              AppLaunchArguments.shouldUseLiveWorkoutUITestPreset,
              let entry = viewModel.entries.first(where: { !$0.isCardio }) else {
            return
        }

        for _ in 0..<4 {
            viewModel.addSet(to: entry)
        }
    }

    private func startHeartRateUpdates() {
        heartRateTimer?.invalidate()
        // Poll every 2 seconds for a snappier live-data UI without per-sample view churn.
        heartRateTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            Task { @MainActor in
                viewModel.updateHeartRateFromService()
            }
        }
    }

    private func stopHeartRateUpdates() {
        heartRateTimer?.invalidate()
        heartRateTimer = nil
    }

    private func buildWorkoutContext() -> AIService.WorkoutContext {
        let entries = viewModel.entries

        let completedExercises = entries.filter { entry in
            if entry.isCardio {
                return entry.completedAt != nil || entry.hasExercisePreferenceSignal
            }
            if entry.isGeneralActivity {
                guard !entry.isPlannedActivityGuidance else { return false }
                return entry.completedAt != nil || entry.hasExercisePreferenceSignal
            }
            let workingSets = entry.sets.filter { !$0.isWarmup }
            return !workingSets.isEmpty && workingSets.allSatisfy { $0.completed && $0.reps > 0 }
        }.count

        let currentExercise = entries.first { entry in
            if entry.isGeneralActivity {
                return !entry.isPlannedActivityGuidance
                    && entry.completedAt == nil
                    && !entry.hasExercisePreferenceSignal
            }
            if entry.isCardio {
                return entry.completedAt == nil && !entry.hasExercisePreferenceSignal
            }
            let workingSets = entry.sets.filter { !$0.isWarmup }
            return workingSets.isEmpty || workingSets.contains { !$0.completed || $0.reps == 0 }
        }?.exerciseName ?? entries.last?.exerciseName

        let setsWithData = entries.reduce(0) { total, entry in
            guard entry.isStrength else { return total }
            return total + entry.sets.filter { $0.completed && $0.reps > 0 && !$0.isWarmup }.count
        }

        let volumeWithData = entries.reduce(0.0) { total, entry in
            guard !entry.isCardio, !entry.isGeneralActivity else { return total }
            return total + entry.sets.filter { $0.completed && $0.reps > 0 && !$0.isWarmup }.reduce(0.0) { $0 + $1.volume }
        }

        return AIService.WorkoutContext(
            workoutName: viewModel.workoutName,
            workoutType: viewModel.workout.type.displayName,
            focusAreas: viewModel.sessionFocusAreas,
            elapsedMinutes: Int(viewModel.elapsedTime / 60),
            entriesLogged: completedExercises,
            exercisesTotal: entries.count,
            currentExercise: currentExercise,
            setsLogged: setsWithData,
            totalVolume: volumeWithData,
            targetMuscleGroups: viewModel.targetMuscleGroups,
            sessionNotes: viewModel.workout.notes.isEmpty ? nil : viewModel.workout.notes,
            activeGoals: relevantSessionGoals.map(\.trimmedTitle),
            entryDetails: entries
                .sorted { $0.orderIndex < $1.orderIndex }
                .map(workoutContextEntryDetail)
        )
    }

    private func workoutContextEntryDetail(_ entry: LiveWorkoutEntry) -> String {
        entry.traiWorkoutContextDetail(usesMetricExerciseWeight: usesMetricExerciseWeight)
    }

    private func toggleGoalCompletion(_ goal: WorkoutGoal) {
        if goal.status == .completed {
            goal.markActive()
        } else {
            goal.markCompleted()
        }
        guard saveLiveWorkoutChange(title: "Workout Goal Not Updated") else { return }
        HapticManager.selectionChanged()
    }

    private func saveLiveWorkoutChange(title: String) -> Bool {
        do {
            try modelContext.save()
            return true
        } catch {
            modelContext.rollback()
            activeAlert = .persistenceFailure(
                title: title,
                message: error.localizedDescription
            )
            HapticManager.error()
            return false
        }
    }

}

// MARK: - Preview

#Preview {
    LiveWorkoutView(workout: {
        let workout = LiveWorkout(
            name: "Push Day",
            workoutType: .strength,
            targetMuscleGroups: [.chest, .shoulders, .triceps]
        )

        let entry1 = LiveWorkoutEntry(exerciseName: "Bench Press", orderIndex: 0)
        entry1.addSet(LiveWorkoutEntry.SetData(reps: 10, weight: CleanWeight(kg: 60, lbs: 132.5), completed: true, isWarmup: true))
        entry1.addSet(LiveWorkoutEntry.SetData(reps: 8, weight: CleanWeight(kg: 80, lbs: 177.5), completed: true, isWarmup: false))
        entry1.addSet(LiveWorkoutEntry.SetData(reps: 6, weight: CleanWeight(kg: 90, lbs: 200), completed: false, isWarmup: false))

        let entry2 = LiveWorkoutEntry(exerciseName: "Overhead Press", orderIndex: 1)
        entry2.addSet(LiveWorkoutEntry.SetData(reps: 10, weight: CleanWeight(kg: 40, lbs: 90), completed: false, isWarmup: false))
        entry2.addSet(LiveWorkoutEntry.SetData(reps: 10, weight: CleanWeight(kg: 40, lbs: 90), completed: false, isWarmup: false))
        entry2.addSet(LiveWorkoutEntry.SetData(reps: 10, weight: CleanWeight(kg: 40, lbs: 90), completed: false, isWarmup: false))

        workout.entries = [entry1, entry2]
        return workout
    }())
    .modelContainer(for: [LiveWorkout.self, LiveWorkoutEntry.self, Exercise.self], inMemory: true)
    .environmentObject(ActiveWorkoutRuntimeState())
}
