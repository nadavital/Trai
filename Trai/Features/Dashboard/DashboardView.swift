//
//  DashboardView.swift
//  Trai
//
//  Created by Nadav Avital on 12/25/25.
//

import SwiftUI
import SwiftData

private struct DashboardNutritionTotals {
    var calories: Int = 0
    var protein: Double = 0
    var carbs: Double = 0
    var fat: Double = 0
    var fiber: Double = 0
    var sugar: Double = 0

    init() {}

    init(entries: [FoodEntry]) {
        calories = entries.reduce(0) { $0 + $1.calories }
        protein = entries.reduce(0) { $0 + $1.proteinGrams }
        carbs = entries.reduce(0) { $0 + $1.carbsGrams }
        fat = entries.reduce(0) { $0 + $1.fatGrams }
        fiber = entries.reduce(0) { $0 + ($1.fiberGrams ?? 0) }
        sugar = entries.reduce(0) { $0 + ($1.sugarGrams ?? 0) }
    }
}

struct DashboardView: View {
    @State private var dashboardSection: DashboardSection = .today
    @State private var nutritionTrendRequest = 0
    @State private var nutritionTrendMetric: NutritionTrendChart.NutritionMetric = .calories
    /// Optional binding to control reminders sheet from parent (for notification taps)
    @Binding var showRemindersBinding: Bool
    let onSelectTab: ((AppTab) -> Void)?
    let onPresentFoodCamera: ((UUID?, Date?) -> Void)?

    @Query private var profiles: [UserProfile]
    @Query private var allFoodEntries: [FoodEntry]
    @Query private var insightFoodEntries: [FoodEntry]
    @Query private var allWorkouts: [WorkoutSession]
    @Query private var liveWorkouts: [LiveWorkout]
    @Query private var weightEntries: [WeightEntry]
    @Query private var coachSignals: [CoachSignal]
    @Query private var suggestionUsage: [SuggestionUsage]
    @Query private var behaviorEvents: [BehaviorEvent]

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(NotificationService.self) private var notificationService: NotificationService?
    @Environment(HealthKitService.self) private var healthKitService: HealthKitService?
    @Environment(MonetizationService.self) private var monetizationService: MonetizationService?
    @EnvironmentObject private var activeWorkoutRuntimeState: ActiveWorkoutRuntimeState
    @Environment(\.presentLiveWorkout) private var presentLiveWorkout
    @State private var recoveryService = MuscleRecoveryService.shared
    @State private var workoutTemplateService = WorkoutTemplateService()

    // Custom reminders (fetched manually to avoid @Query freeze)
    @State private var customReminders: [CustomReminder] = []
    @State private var todaysCompletedReminderIds: Set<UUID> = []
    @State private var remindersLoaded = false
    @State private var pendingScrollToReminders = false
    @State private var reminderCompletionHistory: [ReminderCompletion] = []
    @State private var cachedRecommendedTemplateId: UUID?
    @State private var didPrimeInitialData = false
    @State private var hasSettledActivationChecklistState = false
    @State private var coachContextRefreshTask: Task<Void, Never>?
    @State private var deferredInitialLoadTask: Task<Void, Never>?
    @State private var remindersLoadTask: Task<Void, Never>?
    @State private var hasPerformedDeferredStartupWork = false
    @State private var isDashboardTabVisible = false
    @State private var latencyProbeEntries: [String] = []
    @State private var tabActivationPolicy = TabActivationPolicy(minimumDwellMilliseconds: 0)
    private let reminderCompletionHistoryCapPerWindow = 180

    // Sheet presentation state
    @State private var localFoodCameraPresentation: FoodCameraPresentation?
    @State private var showingLogWeight = false
    @State private var showingActivityGoal = false
    @State private var activityGoalDraft = 3
    @State private var showingNutritionPlan = false
    @State private var showingCalorieDetail = false
    @State private var showingMacroDetail = false
    @State private var entryToEdit: FoodEntry?
    @State private var reminderComposerSeed: ReminderComposerSeed?
    @State private var activationChecklistHealthError: String?
    @State private var persistenceError: DashboardPersistenceError?
    @AppStorage("dashboardActivationChecklistHasLoggedFood")
    private var cachedActivationHasLoggedFood = false
    @AppStorage("dashboardActivationChecklistHasWorkoutPlan")
    private var cachedActivationHasWorkoutPlan = false
    @AppStorage("dashboardActivationChecklistHasHealthAccess")
    private var cachedActivationHasHealthAccess = false
    @AppStorage("dashboardActivationChecklistHasReminders")
    private var cachedActivationHasReminders = false
    @AppStorage("dashboardActivationChecklistDismissed")
    private var hasDismissedActivationChecklist = false

    @AppStorage("pendingWorkoutPlanSetupRequest") private var pendingWorkoutPlanSetupRequest = false
    private static let dashboardHistoryWindowDays = 100
    private static let dashboardFastFoodWindowDays = 2
    private static let behaviorHistoryWindowDays = 90
    private static let dashboardEntryFetchLimit = 48
    private static let dashboardFastFoodFetchLimit = 72
    private static let dashboardInsightFoodWindowDays = 45
    private static let dashboardInsightFoodFetchLimit = 360
    private static let dashboardLazyFoodTrendWindowDays = 7
    private static let dashboardHistoricalFoodFetchLimit = 240
    private static let behaviorEventFetchLimit = 90
    private static let coachSignalFetchLimit = 48
    private static let suggestionUsageFetchLimit = 64
    private static var deferredStartupWorkDelayMilliseconds: Int {
        AppLaunchArguments.shouldAggressivelyDeferHeavyTabWork ? 2400 : 420
    }
    private static var dashboardResumeDeferredWorkDelayMilliseconds: Int {
        AppLaunchArguments.shouldAggressivelyDeferHeavyTabWork ? 1800 : 220
    }
    private static var remindersInitialLoadDelayMilliseconds: Int {
        AppLaunchArguments.shouldAggressivelyDeferHeavyTabWork ? 1400 : 120
    }
    private static var activationChecklistStartupGraceMilliseconds: Int {
        AppLaunchArguments.shouldAggressivelyDeferHeavyTabWork ? 1600 : 650
    }
    private static var coachContextRefreshDelayMilliseconds: Int {
        AppLaunchArguments.shouldAggressivelyDeferHeavyTabWork ? 1200 : 180
    }
    private static var dashboardHeavyRefreshMinimumDwellMilliseconds: Int {
        AppLaunchArguments.shouldAggressivelyDeferHeavyTabWork ? 1600 : 320
    }

    private var canAccessAIFeatures: Bool {
        monetizationService?.canAccessAIFeatures ?? true
    }

    init(
        showRemindersBinding: Binding<Bool> = .constant(false),
        onSelectTab: ((AppTab) -> Void)? = nil,
        onPresentFoodCamera: ((UUID?, Date?) -> Void)? = nil
    ) {
        _showRemindersBinding = showRemindersBinding
        self.onSelectTab = onSelectTab
        self.onPresentFoodCamera = onPresentFoodCamera

        let now = Date()
        let calendar = Calendar.current
        let historyCutoff = calendar.date(
            byAdding: .day,
            value: -Self.dashboardHistoryWindowDays,
            to: now
        ) ?? .distantPast
        let foodFastWindowCutoff = calendar.date(
            byAdding: .day,
            value: -(Self.dashboardFastFoodWindowDays - 1),
            to: calendar.startOfDay(for: now)
        ) ?? historyCutoff
        let insightFoodWindowCutoff = calendar.date(
            byAdding: .day,
            value: -Self.dashboardInsightFoodWindowDays,
            to: now
        ) ?? .distantPast
        let behaviorCutoff = calendar.date(
            byAdding: .day,
            value: -Self.behaviorHistoryWindowDays,
            to: now
        ) ?? .distantPast
        let coachSignalCutoff = calendar.date(
            byAdding: .day,
            value: -30,
            to: now
        ) ?? .distantPast

        var profileDescriptor = FetchDescriptor<UserProfile>()
        profileDescriptor.fetchLimit = 1
        _profiles = Query(profileDescriptor)

        var foodDescriptor = FetchDescriptor<FoodEntry>(
            predicate: #Predicate<FoodEntry> { $0.loggedAt >= foodFastWindowCutoff },
            sortBy: [SortDescriptor(\FoodEntry.loggedAt, order: .reverse)]
        )
        foodDescriptor.fetchLimit = Self.dashboardFastFoodFetchLimit
        _allFoodEntries = Query(foodDescriptor)

        var insightFoodDescriptor = FetchDescriptor<FoodEntry>(
            predicate: #Predicate<FoodEntry> { $0.loggedAt >= insightFoodWindowCutoff },
            sortBy: [SortDescriptor(\FoodEntry.loggedAt, order: .reverse)]
        )
        insightFoodDescriptor.fetchLimit = Self.dashboardInsightFoodFetchLimit
        _insightFoodEntries = Query(insightFoodDescriptor)

        var workoutDescriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate<WorkoutSession> { $0.loggedAt >= historyCutoff },
            sortBy: [SortDescriptor(\WorkoutSession.loggedAt, order: .reverse)]
        )
        workoutDescriptor.fetchLimit = Self.dashboardEntryFetchLimit
        _allWorkouts = Query(workoutDescriptor)

        var liveWorkoutDescriptor = FetchDescriptor<LiveWorkout>(
            predicate: #Predicate<LiveWorkout> { $0.startedAt >= historyCutoff },
            sortBy: [SortDescriptor(\LiveWorkout.startedAt, order: .reverse)]
        )
        liveWorkoutDescriptor.fetchLimit = Self.dashboardEntryFetchLimit
        _liveWorkouts = Query(liveWorkoutDescriptor)

        var weightDescriptor = FetchDescriptor<WeightEntry>(
            predicate: #Predicate<WeightEntry> { $0.loggedAt >= historyCutoff },
            sortBy: [SortDescriptor(\WeightEntry.loggedAt, order: .reverse)]
        )
        weightDescriptor.fetchLimit = Self.dashboardEntryFetchLimit
        _weightEntries = Query(weightDescriptor)

        var behaviorDescriptor = FetchDescriptor<BehaviorEvent>(
            predicate: #Predicate<BehaviorEvent> { $0.occurredAt >= behaviorCutoff },
            sortBy: [SortDescriptor(\BehaviorEvent.occurredAt, order: .reverse)]
        )
        behaviorDescriptor.fetchLimit = Self.behaviorEventFetchLimit
        _behaviorEvents = Query(behaviorDescriptor)

        var coachSignalDescriptor = FetchDescriptor<CoachSignal>(
            predicate: #Predicate<CoachSignal> {
                !$0.isResolved && $0.createdAt >= coachSignalCutoff
            },
            sortBy: [SortDescriptor(\CoachSignal.createdAt, order: .reverse)]
        )
        coachSignalDescriptor.fetchLimit = Self.coachSignalFetchLimit
        _coachSignals = Query(coachSignalDescriptor)

        var suggestionDescriptor = FetchDescriptor<SuggestionUsage>(
            sortBy: [SortDescriptor(\SuggestionUsage.tapCount, order: .reverse)]
        )
        suggestionDescriptor.fetchLimit = Self.suggestionUsageFetchLimit
        _suggestionUsage = Query(suggestionDescriptor)
    }

    // Date navigation
    @State private var selectedDate = Date()

    // Activity data from HealthKit
    @State private var hasLoadedActivitySummary = false
    @State private var todaySteps = 0
    @State private var todayActiveCalories = 0
    @State private var todayExerciseMinutes = 0
    @State private var isLoadingActivity = false
    @State private var cachedSelectedDayFoodEntries: [FoodEntry] = []
    @State private var cachedLast7DaysFoodEntries: [FoodEntry] = []
    @State private var cachedOnDemandFoodTrendEntries: [FoodEntry] = []
    @State private var cachedOnDemandFoodTrendAnchor: Date?
    @State private var cachedSelectedDayWorkouts: [WorkoutSession] = []
    @State private var cachedSelectedDayLiveWorkouts: [LiveWorkout] = []
    @State private var selectedDayNutritionTotals = DashboardNutritionTotals()

    private let reminderHabitWindowDays = 30

    private var profile: UserProfile? { profiles.first }

    private var hasLoggedFood: Bool {
        cachedActivationHasLoggedFood || !allFoodEntries.isEmpty
    }

    private var hasWorkoutPlan: Bool {
        cachedActivationHasWorkoutPlan || profile?.workoutPlan != nil
    }

    private var hasHealthAccessForActivationChecklist: Bool {
        cachedActivationHasHealthAccess || healthKitService?.isAuthorized == true
    }

    private var hasReminderSetup: Bool {
        cachedActivationHasReminders || hasActiveReminderSetup
    }

    private var hasActiveReminderSetup: Bool {
        guard let profile else { return !customReminders.filter(\.isEnabled).isEmpty }
        return profile.mealRemindersEnabled
            || profile.workoutRemindersEnabled
            || profile.weightReminderEnabled
            || customReminders.contains { $0.isEnabled }
    }

    private var shouldShowActivationChecklist: Bool {
        guard !hasDismissedActivationChecklist, hasSettledActivationChecklistState, isViewingToday, profile != nil else { return false }
        return !hasLoggedFood || !hasWorkoutPlan || !hasHealthAccessForActivationChecklist || !hasReminderSetup
    }

    private var isDashboardTabActive: Bool {
        isDashboardTabVisible
    }

    private var shouldDeferCoachContextRefreshDuringStartup: Bool {
        false
    }

    private var isViewingToday: Bool {
        Calendar.current.isDateInToday(selectedDate)
    }

    private var foodEntriesRefreshFingerprint: String {
        guard !allFoodEntries.isEmpty else { return "0" }
        var parts: [String] = []
        parts.reserveCapacity(1 + (allFoodEntries.count * 8))
        parts.append(String(allFoodEntries.count))
        for entry in allFoodEntries {
            parts.append(entry.id.uuidString)
            parts.append(String(entry.loggedAt.timeIntervalSinceReferenceDate))
            parts.append(String(entry.calories))
            parts.append(String(entry.proteinGrams))
            parts.append(String(entry.carbsGrams))
            parts.append(String(entry.fatGrams))
            parts.append(String(entry.fiberGrams ?? -1))
            parts.append(String(entry.sugarGrams ?? -1))
        }
        return parts.joined(separator: "|")
    }

    private var weightEntriesRefreshFingerprint: String {
        guard !weightEntries.isEmpty else { return "0" }
        var parts: [String] = []
        parts.reserveCapacity(1 + (weightEntries.count * 4))
        parts.append(String(weightEntries.count))
        for entry in weightEntries {
            parts.append(entry.id.uuidString)
            parts.append(String(entry.loggedAt.timeIntervalSinceReferenceDate))
            parts.append(String(entry.weightKg))
            parts.append(String(entry.bodyFatPercentage ?? -1))
        }
        return parts.joined(separator: "|")
    }

    private var coachSignalsRefreshFingerprint: String {
        guard !coachSignals.isEmpty else { return "0" }
        var parts: [String] = []
        parts.reserveCapacity(1 + (coachSignals.count * 8))
        parts.append(String(coachSignals.count))
        for signal in coachSignals {
            parts.append(signal.id.uuidString)
            parts.append(String(signal.createdAt.timeIntervalSinceReferenceDate))
            parts.append(String(signal.expiresAt.timeIntervalSinceReferenceDate))
            parts.append(signal.title)
            parts.append(signal.detail)
            parts.append(String(signal.severity))
            parts.append(String(signal.confidence))
            parts.append(signal.isResolved ? "1" : "0")
        }
        return parts.joined(separator: "|")
    }

    private var behaviorEventsRefreshFingerprint: String {
        guard !behaviorEvents.isEmpty else { return "0" }
        var parts: [String] = []
        parts.reserveCapacity(1 + (behaviorEvents.count * 5))
        parts.append(String(behaviorEvents.count))
        for event in behaviorEvents {
            parts.append(event.id.uuidString)
            parts.append(String(event.occurredAt.timeIntervalSinceReferenceDate))
            parts.append(event.actionKey)
            parts.append(event.domainRaw)
            parts.append(event.outcomeRaw)
        }
        return parts.joined(separator: "|")
    }

    private var suggestionUsageRefreshFingerprint: String {
        guard !suggestionUsage.isEmpty else { return "0" }
        var parts: [String] = []
        parts.reserveCapacity(1 + (suggestionUsage.count * 5))
        parts.append(String(suggestionUsage.count))
        for usage in suggestionUsage {
            parts.append(usage.id.uuidString)
            parts.append(usage.suggestionType)
            parts.append(String(usage.tapCount))
            parts.append(String(usage.lastTapped?.timeIntervalSinceReferenceDate ?? 0))
            parts.append(String(usage.hourlyTapsData?.count ?? 0))
        }
        return parts.joined(separator: "|")
    }

    private var selectedDayFoodEntries: [FoodEntry] {
        let fastQueryEntries = selectedDayFastQueryFoodEntries()
        return fastQueryEntries.isEmpty ? cachedSelectedDayFoodEntries : fastQueryEntries
    }

    private var visibleSelectedDayNutritionTotals: DashboardNutritionTotals {
        DashboardNutritionTotals(entries: selectedDayFoodEntries)
    }

    /// Last 7 days of food entries for trend charts
    private var last7DaysFoodEntries: [FoodEntry] { cachedLast7DaysFoodEntries }

    /// Detail sheets read a lazy-loaded 7-day history keyed to the selected date.
    private var detailSheetHistoricalFoodEntries: [FoodEntry] {
        let selectedStart = Calendar.current.startOfDay(for: selectedDate)
        if cachedOnDemandFoodTrendAnchor == selectedStart {
            return cachedOnDemandFoodTrendEntries
        }
        return last7DaysFoodEntries
    }

    private var selectedDayWorkouts: [WorkoutSession] { cachedSelectedDayWorkouts }

    private var selectedDayLiveWorkouts: [LiveWorkout] { cachedSelectedDayLiveWorkouts }

    /// HealthKit workout IDs that have been merged into LiveWorkouts (to avoid double-counting)
    private var mergedHealthKitIDs: Set<String> {
        Set(liveWorkouts.compactMap { $0.mergedHealthKitWorkoutID })
    }

    /// HealthKit workouts for the selected day that have not already been merged into in-app workouts.
    private var selectedDayUniqueHealthKitWorkouts: [WorkoutSession] {
        selectedDayWorkouts.filter { workout in
            guard let hkID = workout.healthKitWorkoutID else { return true }
            return !mergedHealthKitIDs.contains(hkID)
        }
    }

    private var selectedDayWorkoutCount: Int {
        selectedDayUniqueHealthKitWorkouts.count + selectedDayLiveWorkouts.count
    }

    private var selectedDayHasWorkoutForTargets: Bool {
        let interval = WorkoutDayTargetContext.dayInterval(containing: selectedDate)
        return WorkoutDayTargetContext.hasWorkout(
            in: interval,
            workoutSessions: selectedDayUniqueHealthKitWorkouts,
            liveWorkouts: selectedDayLiveWorkouts
        )
    }

    private var hasActiveLiveWorkout: Bool {
        liveWorkouts.contains { $0.completedAt == nil }
    }

    private func computeRecommendedTemplateId() -> UUID? {
        guard isViewingToday, let plan = profile?.workoutPlan else { return nil }

        let startedAt = LatencyProbe.timerStart()
        defer {
            recordDashboardLatencyProbe(
                "computeRecommendedTemplateId",
                startedAt: startedAt,
                counts: [
                    "templates": plan.templates.count,
                    "workouts": allWorkouts.count,
                    "liveWorkouts": liveWorkouts.count
                ]
            )
        }

        return recoveryService.getRecommendedTemplateId(
            plan: plan,
            modelContext: modelContext
        ) ?? plan.templates.first?.id
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                DashboardTopGradient()
                ScrollViewReader { scrollProxy in
                    VStack(spacing: 0) {
                        DashboardSectionHeader(
                            selection: $dashboardSection,
                            calories: totalCalories,
                            macroProgress: dashboardMacroProgress,
                            trainingDays: trainingRhythm,
                            weeklyTrainingTarget: weeklyTrainingTarget,
                            weightLabel: dashboardWeightLabel,
                            onAccount: { onSelectTab?(.profile) }
                        )
                        TabView(selection: $dashboardSection) {
                            ForEach(DashboardSection.allCases) { section in
                                ScrollView(.vertical) {
                                    LazyVStack(alignment: .leading, spacing: 24) {
                                        if section == .today { dashboardHeading(section) }
                                        if section == .today { connectedNutritionCard; dashboardContextCards; dashboardReminders }
                                        if section == .nutrition { connectedNutritionSection }
                                        if section == .activity { connectedWorkoutAction }
                                        if section == .nutrition { dashboardNutritionSections }
                                        if section == .activity { dashboardActivitySections; dashboardWorkoutHistory }
                                        if section == .weight { connectedWeightSection }
                                        if section == .today { dashboardTopSections }
                                    }
                                    .padding(.horizontal, 16).padding(.vertical, 20)
                                    .frame(maxWidth: 600).frame(maxWidth: .infinity)
                                }
                                .task(id: "\(pendingScrollToReminders)-\(remindersLoaded)-\(dashboardSection)") {
                                    guard section == .today, dashboardSection == .today,
                                          pendingScrollToReminders, remindersLoaded else { return }
                                    await Task.yield()
                                    guard !Task.isCancelled else { return }
                                    withAnimation(.smooth) { scrollProxy.scrollTo("reminders-section", anchor: .top) }
                                    pendingScrollToReminders = false
                                    showRemindersBinding = false
                                }
                                .accessibilityIdentifier("dashboardPage\(section.title)")
                                .tag(section)
                            }
                        }.tabViewStyle(.page(indexDisplayMode: .never))
                        .ignoresSafeArea(.container, edges: .bottom)
                    }
                .onChange(of: nutritionTrendRequest) { _, _ in
                    withAnimation(.smooth) { scrollProxy.scrollTo("nutrition-trends", anchor: .top) }
                }
                .onChange(of: showRemindersBinding) { _, isShowing in
                    if isShowing {
                        pendingScrollToReminders = true
                        dashboardSection = .today
                    }
                }
            }
            .task {
                guard !didPrimeInitialData else { return }
                didPrimeInitialData = true
                if showRemindersBinding {
                    pendingScrollToReminders = true
                }
                refreshDateScopedCaches()
                updateActivationChecklistCompletionCache()
                await Task.yield()
                scheduleRemindersLoad(
                    delayMilliseconds: Self.remindersInitialLoadDelayMilliseconds
                )
                scheduleDeferredStartupWork(
                    delayMilliseconds: Self.deferredStartupWorkDelayMilliseconds
                )
            }
            .sheet(isPresented: $showingNutritionPlan) {
                ProfileView(mode: .nutritionPlan, onSelectTab: onSelectTab)
                    .traiSheetBranding()
            }
            .task(id: didPrimeInitialData) {
                guard didPrimeInitialData, !hasSettledActivationChecklistState else { return }
                try? await Task.sleep(for: .milliseconds(Self.activationChecklistStartupGraceMilliseconds))
                guard !Task.isCancelled else { return }
                hasSettledActivationChecklistState = true
            }
            .onAppear {
                if tabActivationPolicy.activeSince == nil {
                    tabActivationPolicy = TabActivationPolicy(
                        minimumDwellMilliseconds: Self.dashboardHeavyRefreshMinimumDwellMilliseconds
                    )
                }
                tabActivationPolicy.activate()
                isDashboardTabVisible = true
                prewarmFoodCameraSuggestions(targetDate: selectedDate, modelContext: modelContext)
                updateActivationChecklistCompletionCache()
                guard didPrimeInitialData else { return }

                if showRemindersBinding {
                    pendingScrollToReminders = true
                }
                if !remindersLoaded {
                    scheduleRemindersLoad(delayMilliseconds: 0)
                }

                refreshDateScopedCaches()
                if isViewingToday {
                    Task {
                        await loadActivityData()
                    }
                }

                if !hasPerformedDeferredStartupWork {
                    scheduleDeferredStartupWork(
                        delayMilliseconds: Self.dashboardResumeDeferredWorkDelayMilliseconds
                    )
                }
            }
            .onChange(of: selectedDate) { _, newDate in
                refreshDateScopedCaches()
                prewarmFoodCameraSuggestions(targetDate: newDate, modelContext: modelContext)
                updateActivationChecklistCompletionCache()
                if Calendar.current.isDateInToday(newDate) {
                    Task {
                        await loadActivityData()
                    }
                }
            }
            .onChange(of: foodEntriesRefreshFingerprint) { _, _ in
                guard isDashboardTabActive else { return }
                invalidateFoodCameraSuggestions()
                prewarmFoodCameraSuggestions(targetDate: selectedDate, modelContext: modelContext)
                refreshFoodDateCaches()
                updateActivationChecklistCompletionCache()
            }
            .onChange(of: allWorkouts.count) {
                guard isDashboardTabActive else { return }
                refreshWorkoutDateCache()
                updateActivationChecklistCompletionCache()
                if isViewingToday {
                    scheduleCoachContextRefresh(forceRefresh: true)
                }
            }
            .onChange(of: liveWorkouts.count) {
                guard isDashboardTabActive else { return }
                refreshLiveWorkoutDateCache()
                updateActivationChecklistCompletionCache()
                if isViewingToday {
                    scheduleCoachContextRefresh(forceRefresh: true)
                }
            }
            .onChange(of: profile?.workoutPlan) {
                updateActivationChecklistCompletionCache()
            }
            .onChange(of: healthKitService?.isAuthorized) {
                updateActivationChecklistCompletionCache()
            }
            .onReceive(NotificationCenter.default.publisher(for: .workoutCompleted)) { _ in
                guard isDashboardTabActive else { return }
                // Refresh after workout completed to update muscle recovery
                Task {
                    await loadActivityData()
                }
            }
            .onChange(of: activeWorkoutRuntimeState.isLiveWorkoutPresented) { _, isPresented in
                guard isDashboardTabActive else { return }
                if !isPresented {
                    guard !hasActiveLiveWorkout else { return }
                }
            }
            .onDisappear {
                isDashboardTabVisible = false
                tabActivationPolicy.deactivate()
                deferredInitialLoadTask?.cancel()
                remindersLoadTask?.cancel()
            }
            .refreshable {
                await refreshHealthData()
            }
            .sheet(item: $localFoodCameraPresentation) { presentation in
                FoodCameraView(sessionId: presentation.sessionId, targetDate: presentation.targetDate)
                    .traiSheetBranding()
            }
            .sheet(isPresented: $showingActivityGoal) {
                NavigationStack {
                    Form {
                        TextField("Workouts per week", value: $activityGoalDraft, format: .number)
                            .keyboardType(.numberPad)
                        Text("Every completed workout counts, including multiple sessions on the same day.")
                            .font(.footnote).foregroundStyle(.secondary)
                        if weeklyTrainingTarget != nil {
                            Button("Remove goal", role: .destructive) {
                                profile?.weeklyWorkoutSessionGoal = nil
                                showingActivityGoal = false
                            }
                        }
                    }
                    .navigationTitle("Weekly workout goal").navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) { Button("Cancel") { showingActivityGoal = false } }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Save") {
                                profile?.weeklyWorkoutSessionGoal = activityGoalDraft
                                showingActivityGoal = false
                            }.disabled(activityGoalDraft < 1).tint(.accentColor)
                        }
                    }
                }.presentationDetents([.medium])
            }
            .sheet(isPresented: $showingLogWeight) {
                LogWeightSheet()
                    .traiSheetBranding()
            }
            .sheet(isPresented: $showingCalorieDetail) {
                CalorieDetailSheet(
                    entries: selectedDayFoodEntries,
                    goal: profile?.effectiveCalorieGoal(hasWorkoutToday: selectedDayHasWorkoutForTargets) ?? 0,
                    isToday: isViewingToday,
                    historicalEntries: detailSheetHistoricalFoodEntries,
                    onAddFood: {
                        showingCalorieDetail = false
                        Task {
                            try? await Task.sleep(for: .milliseconds(300))
                            presentFoodCamera(targetDate: selectedDate)
                        }
                    },
                    onEditEntry: { entry in
                        showingCalorieDetail = false
                        Task {
                            try? await Task.sleep(for: .milliseconds(300))
                            entryToEdit = entry
                        }
                    },
                    onDeleteEntry: deleteFoodEntry
                )
                .traiSheetBranding()
            }
            .sheet(isPresented: $showingMacroDetail) {
                MacroDetailSheet(
                    entries: selectedDayFoodEntries,
                    proteinGoal: profile?.dailyProteinGoal ?? 0,
                    carbsGoal: profile?.dailyCarbsGoal ?? 0,
                    fatGoal: profile?.dailyFatGoal ?? 0,
                    isToday: isViewingToday,
                    fiberGoal: profile?.dailyFiberGoal ?? 0,
                    sugarGoal: profile?.dailySugarGoal ?? 0,
                    enabledMacros: profile?.enabledMacros ?? MacroType.defaultEnabled,
                    historicalEntries: detailSheetHistoricalFoodEntries,
                    onAddFood: {
                        showingMacroDetail = false
                        Task {
                            try? await Task.sleep(for: .milliseconds(300))
                            presentFoodCamera(targetDate: selectedDate)
                        }
                    },
                    onEditEntry: { entry in
                        showingMacroDetail = false
                        Task {
                            try? await Task.sleep(for: .milliseconds(300))
                            entryToEdit = entry
                        }
                    }
                )
                .traiSheetBranding()
            }
            .sheet(item: $reminderComposerSeed) { seed in
                if let profile {
                    ReminderQuickSetupSheet(
                        profile: profile,
                        notificationService: notificationService,
                        seed: seed,
                        onSaved: {
                            fetchCustomReminders()
                            updateActivationChecklistCompletionCache()
                        }
                    )
                }
            }
            .sheet(item: $entryToEdit) { entry in
                EditFoodEntrySheet(entry: entry)
                    .traiSheetBranding()
            }
            .alert(item: $persistenceError) { error in
                Alert(
                    title: Text(error.title),
                    message: Text(error.message),
                    dismissButton: .default(Text("OK"))
                )
            }
            .overlay(alignment: .topLeading) {
                Text("ready")
                    .font(.system(size: 1))
                    .frame(width: 1, height: 1)
                    .opacity(0.01)
                    .accessibilityElement(children: .ignore)
                    .accessibilityIdentifier("dashboardRootReady")
            }
            .overlay(alignment: .topLeading) { latencyProbeOverlay }
            }
        }
        .traiBackground()
    }

    private var latencyProbeOverlay: some View {
        Text(dashboardLatencyProbeLabel)
            .font(.system(size: 1))
            .frame(width: 1, height: 1)
            .opacity(0.01)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(dashboardLatencyProbeLabel)
            .accessibilityIdentifier("dashboardLatencyProbe")
    }

    private var dashboardLatencyProbeLabel: String {
        guard AppLaunchArguments.shouldEnableLatencyProbe else { return "disabled" }
        return latencyProbeEntries.isEmpty ? "pending" : latencyProbeEntries.joined(separator: " | ")
    }

    private func updateActivationChecklistCompletionCache() {
        if !allFoodEntries.isEmpty {
            cachedActivationHasLoggedFood = true
        }
        if profile?.workoutPlan != nil {
            cachedActivationHasWorkoutPlan = true
        }
        if healthKitService?.isAuthorized == true {
            cachedActivationHasHealthAccess = true
        }
        if hasActiveReminderSetup {
            cachedActivationHasReminders = true
        }
    }

    private func connectHealthFromActivationChecklist() {
        activationChecklistHealthError = nil
        Task { @MainActor in
            do {
                try await healthKitService?.requestAuthorization()
                updateActivationChecklistCompletionCache()
                guard let profile else { return }
                profile.syncFoodToHealthKit = true
                profile.syncWeightToHealthKit = true
                try modelContext.save()
            } catch {
                activationChecklistHealthError = healthKitService?.authorizationError ?? error.localizedDescription
            }
        }
    }

    private func openWorkoutPlanSetupFromActivationChecklist() {
        pendingWorkoutPlanSetupRequest = true
        onSelectTab?(.workouts)
    }

    private var dashboardMacroProgress: [Double] {
        let current = [totalProtein, totalCarbs, totalFat]
        let targets = [profile?.dailyProteinGoal, profile?.dailyCarbsGoal, profile?.dailyFatGoal]
        return zip(current, targets).map { value, goal in
            guard let goal, goal > 0 else { return 0 }
            return value / Double(goal)
        }
    }

    private var dashboardWeightLabel: String {
        guard let weight = weightEntries.first else { return "Not logged" }
        let metric = profile?.usesMetricWeight ?? true
        let value = metric ? weight.weightKg : weight.weightKg * 2.20462
        return "\(value.formatted(.number.precision(.fractionLength(1)))) \(metric ? "kg" : "lb")"
    }

    private var dashboardGreeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let greeting = hour < 12 ? "Good morning" : hour < 17 ? "Good afternoon" : "Good evening"
        guard let name = profile?.name.split(separator: " ").first else { return greeting }
        return "\(greeting), \(name)"
    }

    private func dashboardHeading(_ section: DashboardSection) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(dashboardGreeting).font(.system(.title2, design: .rounded, weight: .bold))
            dashboardFoodAction
        }.padding(.horizontal, 4)
    }

    private var connectedNutritionCard: some View {
        DashboardNutritionGlassCard(
            entries: selectedDayFoodEntries,
            profile: profile,
            hasWorkoutToday: selectedDayHasWorkoutForTargets,
            animates: isDashboardTabVisible && dashboardSection == .today,
            onLogFood: { openFoodCameraFromDashboard(source: "nutrition_glass_card", targetDate: selectedDate) },
            onDetails: { withAnimation(.smooth(duration: 0.3)) { dashboardSection = .nutrition } }
        )
    }

    private var dashboardFoodAction: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout(spacing: 8))
        return layout {
            Button {
                openFoodCameraFromDashboard(source: "dashboard_top_action", targetDate: selectedDate)
            } label: {
                HStack(spacing: 9) {
                    Image(systemName: "camera.fill")
                        .font(.body.weight(.semibold))
                    Text("Log food").font(.system(.headline, design: .rounded))
                }
            }
            .buttonStyle(.traiPrimary(size: .regular, fullWidth: true, height: dynamicTypeSize.isAccessibilitySize ? nil : 50))
            .layoutPriority(1)
            .accessibilityIdentifier("dashboardNutritionLogFood")

            if hasActiveLiveWorkout {
                Button("Resume", systemImage: "play.fill", action: openOrStartWorkout)
                    .buttonStyle(.traiSecondary(size: .regular, height: 50))
                    .accessibilityLabel("Resume workout")
            }
            Menu {
                Button(hasActiveLiveWorkout ? "Resume workout" : nextWorkoutName == nil ? "Quick start workout" : "Start workout", systemImage: "play.fill", action: openOrStartWorkout)
                Button("Log weight", systemImage: "scalemass") {
                    openLogWeightFromDashboard(source: "dashboard_add_menu")
                }
                Button("Add reminder", systemImage: "bell.badge") { reminderComposerSeed = .blank }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                    Text("Add")
                }
                .fixedSize(horizontal: true, vertical: false)
            }
            .buttonStyle(.traiTertiary(color: .primary, size: .regular, height: 50))
            .accessibilityLabel("Add more")
        }
        .padding(.top, 6)
    }

    private var weeklyTrainingTarget: Int? {
        guard let goal = profile?.weeklyWorkoutSessionGoal, goal > 0 else { return nil }
        return goal
    }

    private var trainingRhythm: [TrainingRhythmDay] {
        let calendar = Calendar.current
        let start = calendar.dateInterval(of: .weekOfYear, for: selectedDate)?.start ?? calendar.startOfDay(for: selectedDate)
        let mergedIDs = mergedHealthKitIDs
        let sessions = allWorkouts.filter { workout in
            guard let id = workout.healthKitWorkoutID else { return true }
            return !mergedIDs.contains(id)
        }
        let completed = liveWorkouts.filter { $0.completedAt != nil }
        return (0..<7).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: start),
                  let next = calendar.date(byAdding: .day, value: 1, to: day) else { return nil }
            let logged = sessions.filter { $0.loggedAt >= day && $0.loggedAt < next }
            let live = completed.filter { ($0.completedAt ?? $0.startedAt) >= day && ($0.completedAt ?? $0.startedAt) < next }
            let strength = logged.filter { $0.sets > 0 || WorkoutMode.normalized(from: $0.healthKitWorkoutType) == .strength }.count
                + live.filter { $0.type == .strength || $0.type == .mixed }.count
            return TrainingRhythmDay(date: day, strength: strength, movement: logged.count + live.count - strength,
                                     names: logged.map(\.displayName) + live.map(\.name),
                                     isPartial: (allWorkouts.count >= Self.dashboardEntryFetchLimit && (allWorkouts.last?.loggedAt ?? .distantPast) > day)
                                        || (liveWorkouts.count >= Self.dashboardEntryFetchLimit && (liveWorkouts.last?.startedAt ?? .distantPast) > day))
        }
    }

    private var weightJourneySamples: [WeightJourneySample] {
        let metric = profile?.usesMetricWeight ?? true
        return weightEntries.prefix(30).reversed().map {
            WeightJourneySample(id: $0.id, date: $0.loggedAt, value: metric ? $0.weightKg : $0.weightLbs)
        }
    }

    private var nextWorkoutName: String? {
        let templates = profile?.workoutPlan?.templates ?? []
        guard !templates.isEmpty, profile?.defaultWorkoutActionValue != .customWorkout else { return nil }
        return templates.first(where: { $0.id == cachedRecommendedTemplateId })?.name ?? templates.first?.name
    }

    private var dashboardContextCards: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                dashboardSectionLink("Activity", icon: "figure.run", tint: .orange, section: .activity)
                activityDial(compact: true)
                workoutContextAction
            }.traiCard(contentPadding: 18)

            VStack(alignment: .leading, spacing: 12) {
                dashboardSectionLink("Weight", icon: "scalemass", tint: .accentColor, section: .weight)
                WeightJourneyVisual(samples: weightJourneySamples,
                                    unit: (profile?.usesMetricWeight ?? true) ? "kg" : "lb", compact: true)
                weightContextAction
            }.traiCard(contentPadding: 18)
        }
    }

    private var workoutContextAction: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let active = liveWorkouts.first(where: { $0.completedAt == nil }) {
                Text("In progress").font(.caption).foregroundStyle(.secondary)
                Text(active.name).font(.headline)
            } else if let nextWorkoutName {
                Text("Up next").font(.caption).foregroundStyle(.secondary)
                Text(nextWorkoutName).font(.headline)
            } else {
                Text(profile?.workoutPlan == nil ? "Train your way" : "Choose your workout")
                    .font(.headline)
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) { workoutContextButtons }
                VStack(alignment: .leading, spacing: 12) { workoutContextButtons }
            }
        }
    }

    @ViewBuilder private var workoutContextButtons: some View {
        if hasActiveLiveWorkout || nextWorkoutName != nil {
            Button(hasActiveLiveWorkout ? "Resume" : "Start", systemImage: "play.fill", action: openOrStartWorkout)
                .buttonStyle(.traiPrimary())
                .accessibilityLabel(hasActiveLiveWorkout ? "Resume active workout" : "Start recommended workout")
        } else {
            Button(profile?.workoutPlan == nil ? "Make a plan" : "Choose session", systemImage: "list.bullet") {
                if profile?.workoutPlan == nil {
                    openWorkoutPlanSetupFromActivationChecklist()
                } else {
                    onSelectTab?(.workouts)
                }
            }.buttonStyle(.traiPrimary())
            Button("Quick start", systemImage: "play.fill", action: startCustomWorkout)
                .buttonStyle(.traiSecondary())
                .accessibilityIdentifier("dashboardQuickStartWorkout")
        }
    }

    private var weightContextAction: some View {
            Button { openLogWeightFromDashboard(source: "weight_visual") } label: {
                Label {
                    Text("Log weight")
                } icon: {
                    Image(systemName: "plus")
                }
            }
                .font(.subheadline.weight(.semibold))
                .buttonStyle(.traiSecondary())
                .fixedSize(horizontal: true, vertical: false)
    }

    private func dashboardSectionLink(_ title: String, icon: String, tint: Color, section: DashboardSection) -> some View {
        Button {
            withAnimation(.smooth) { dashboardSection = section }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon).foregroundStyle(tint)
                Text(title).foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
            }
            .font(.subheadline.weight(.semibold))
            .frame(minHeight: 44)
            .contentShape(.rect)
        }.buttonStyle(.plain)
        .accessibilityLabel("Show \(title.lowercased()) details")
    }

    private var connectedNutritionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            DashboardNutritionGlassCard(
                entries: selectedDayFoodEntries,
                profile: profile,
                hasWorkoutToday: selectedDayHasWorkoutForTargets,
                isSection: true,
                animates: isDashboardTabVisible && dashboardSection == .nutrition,
                onLogFood: { openFoodCameraFromDashboard(source: "nutrition_section", targetDate: selectedDate) },
                onDetails: { nutritionTrendRequest += 1 }
            )
            heroActions {
                Button("Log food", systemImage: "camera.fill") {
                    openFoodCameraFromDashboard(source: "nutrition_section", targetDate: selectedDate)
                }.buttonStyle(.traiPrimary())
                    .accessibilityIdentifier("dashboardNutritionLogFood")
                Menu {
                    Button("Trends", systemImage: "chart.xyaxis.line") { nutritionTrendRequest += 1 }
                    Button("Nutrition plan", systemImage: "slider.horizontal.3") { showingNutritionPlan = true }
                } label: { Label("More", systemImage: "ellipsis") }
                    .buttonStyle(.traiTertiary(color: .primary))
                    .accessibilityLabel("Nutrition options")
            }
        }
    }

    private func activityDial(compact: Bool) -> some View {
        let days = trainingRhythm
        let count = days.reduce(0) { $0 + $1.count }
        let partial = days.contains(where: \.isPartial)
        let horizontal = compact && !dynamicTypeSize.isAccessibilitySize
        let layout = horizontal ? AnyLayout(HStackLayout(spacing: 18)) : AnyLayout(VStackLayout(spacing: 12))
        let amount = "\(partial ? "≥" : "")\(count)\(weeklyTrainingTarget.map { " / \($0)" } ?? "")"
        let centeredCount = !compact && !dynamicTypeSize.isAccessibilitySize
        return layout {
            WorkoutGauge(target: weeklyTrainingTarget, completed: count, miniature: compact, glass: !compact, showsCount: false)
                .frame(width: compact ? 100 : 240, height: compact ? 100 : 240)
                .overlay {
                    if centeredCount {
                        VStack(spacing: 6) {
                            Text(amount).font(.largeTitle.bold()).fontDesign(.rounded).monospacedDigit()
                            Text("workouts\nthis week").font(.caption).foregroundStyle(.secondary)
                                .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: 110)
                        }.offset(y: 10)
                    }
                }
                // The open arc leaves an unused lower part of its square canvas.
                .frame(height: compact ? 100 : 210, alignment: .top)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(centeredCount ? "\(amount) workouts this week" : "")
                .accessibilityHidden(!centeredCount)
            if !centeredCount || compact || partial {
            VStack(alignment: horizontal ? .leading : .center, spacing: 6) {
                if !centeredCount {
                    Text(amount).font(.largeTitle.bold()).fontDesign(.rounded).monospacedDigit()
                    Text("workouts this week").font(.subheadline).foregroundStyle(.secondary)
                }
                if compact {
                Button(weeklyTrainingTarget == nil ? "Set weekly goal" : "Edit weekly goal") {
                    activityGoalDraft = weeklyTrainingTarget ?? 3
                    showingActivityGoal = true
                }.font(.caption.weight(.semibold)).tint(.accentColor)
                    .disabled(profile == nil)
                }
                if partial { Text("Some older workouts may be missing").font(.caption2).foregroundStyle(.secondary) }
            }.frame(maxWidth: .infinity, alignment: horizontal ? .leading : .center)
            }
        }.accessibilityIdentifier("activityDial")
    }

    private func heroActions<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12, content: content)
            VStack(spacing: 12, content: content)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }

    private var connectedWorkoutAction: some View {
        VStack(spacing: 16) {
            activityDial(compact: false)
            if let name = liveWorkouts.first(where: { $0.completedAt == nil })?.name ?? nextWorkoutName {
                Text(name).font(.headline).multilineTextAlignment(.center)
            }
            heroActions {
                Button(hasActiveLiveWorkout ? "Resume" : nextWorkoutName != nil ? "Start" : "Quick start", systemImage: "play.fill", action: openOrStartWorkout)
                    .buttonStyle(.traiPrimary())
                    .accessibilityLabel(hasActiveLiveWorkout ? "Resume active workout" : nextWorkoutName != nil ? "Start recommended workout" : "Quick start workout")
                activityOptions
            }
        }
        .padding(.horizontal, 4)
    }

    private var activityOptions: some View {
        Menu {
            Button(weeklyTrainingTarget == nil ? "Set weekly goal" : "Edit weekly goal", systemImage: "target") {
                activityGoalDraft = weeklyTrainingTarget ?? 3
                showingActivityGoal = true
            }.disabled(profile == nil)
            Button(profile?.workoutPlan == nil ? "Make a plan" : "Workout plan", systemImage: "list.bullet") {
                if profile?.workoutPlan == nil { openWorkoutPlanSetupFromActivationChecklist() }
                else { onSelectTab?(.workouts) }
            }
        } label: { Label("More", systemImage: "ellipsis") }
            .buttonStyle(.traiTertiary(color: .primary))
            .accessibilityLabel("Activity options")
    }

    private var connectedWeightSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            WeightJourneyVisual(samples: weightJourneySamples,
                                unit: (profile?.usesMetricWeight ?? true) ? "kg" : "lb")
            heroActions {
                Button("Log weight", systemImage: "plus") {
                    openLogWeightFromDashboard(source: "weight_visual")
                }.buttonStyle(.traiPrimary())
            }
            WeightTrackingView(embedded: true)
        }
    }

    @ViewBuilder
    private var dashboardTopSections: some View {
        if isViewingToday, profile != nil {
            if shouldShowActivationChecklist {
                OnboardingActivationChecklistCard(
                    hasLoggedFood: hasLoggedFood,
                    hasWorkoutPlan: hasWorkoutPlan,
                    hasHealthAccess: healthKitService?.isAuthorized == true,
                    hasReminders: hasReminderSetup,
                    healthError: activationChecklistHealthError,
                    onLogFood: { openFoodCameraFromDashboard(source: "onboarding_checklist_log_food") },
                    onCreateWorkoutPlan: openWorkoutPlanSetupFromActivationChecklist,
                    onConnectHealth: connectHealthFromActivationChecklist,
                    onSetReminders: { reminderComposerSeed = .blank },
                    onDismiss: { hasDismissedActivationChecklist = true }
                )
                .traiEntrance(index: 2)
            }

        }
    }

    @ViewBuilder private var dashboardReminders: some View {
        if isViewingToday, remindersLoaded, profile != nil {
            TodaysRemindersCard(
                reminders: todaysReminderItems,
                hasActiveReminderSetup: hasActiveReminderSetup,
                onReminderTap: openReminderComposer,
                onComplete: completeReminder,
                onAdd: { reminderComposerSeed = .blank }
            )
            .id("reminders-section")
        }
    }

    @ViewBuilder
    private var dashboardNutritionSections: some View {
        DailyFoodTimeline(
            entries: selectedDayFoodEntries,
            enabledMacros: profile?.enabledMacros ?? MacroType.defaultEnabled,
            isToday: isViewingToday,
            onAddToSession: { sessionId in
                openFoodCameraFromDashboard(
                    source: "food_timeline_add_to_session",
                    sessionId: sessionId,
                    targetDate: selectedDate
                )
            },
            onEditEntry: { entryToEdit = $0 },
            onDeleteEntry: deleteFoodEntry
        )
        .traiEntrance(index: 5)
        dashboardNutritionTrends
    }

    private var dashboardWorkoutHistory: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("This week’s sessions").font(.headline)
            let loggedDays = trainingRhythm.filter { $0.count > 0 }
            if loggedDays.isEmpty {
                Text("No sessions logged this week.")
                    .font(.subheadline).foregroundStyle(.secondary)
            } else {
                ForEach(loggedDays.reversed()) { day in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(day.date, format: .dateTime.weekday(.wide).month(.abbreviated).day())
                            .font(.subheadline.weight(.semibold))
                        Text(day.names.joined(separator: " · "))
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            Button("Workout history & plan", systemImage: "figure.strengthtraining.traditional") {
                onSelectTab?(.workouts)
            }.buttonStyle(.traiTertiary(color: .primary))
        }
        .traiCard(contentPadding: 18)
        .accessibilityIdentifier("dashboardWorkoutHistory")
    }

    private var enabledTrendMacros: [MacroType] {
        let enabled = profile?.enabledMacros ?? MacroType.defaultEnabled
        return MacroType.allCases.filter { enabled.contains($0) }
    }

    private var dashboardNutritionTrends: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Past 7 days").font(.headline)
                Spacer()
                Picker("Nutrient", selection: $nutritionTrendMetric) {
                    Text("Calories").tag(NutritionTrendChart.NutritionMetric.calories)
                    ForEach(enabledTrendMacros) { macro in
                        Text(macro.displayName).tag(nutritionMetric(for: macro))
                    }
                }.pickerStyle(.menu).tint(.primary)
            }
            NutritionTrendChart(
                data: TrendsService.aggregateNutritionByDay(entries: isViewingToday ? last7DaysFoodEntries : detailSheetHistoricalFoodEntries, days: 7, endDate: selectedDate),
                goal: nil, metric: nutritionTrendMetric
            )
        }
        .id("nutrition-trends")
        .accessibilityIdentifier("dashboardNutritionTrends")
        .task(id: selectedDate) { loadFoodTrendHistoryForSelectedDateIfNeeded() }
    }

    private func nutritionMetric(for macro: MacroType) -> NutritionTrendChart.NutritionMetric {
        switch macro {
        case .protein: .protein
        case .carbs: .carbs
        case .fat: .fat
        case .fiber: .fiber
        case .sugar: .sugar
        }
    }

    @ViewBuilder private var dashboardActivitySections: some View {
        if hasLoadedActivitySummary {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Label("Daily movement", systemImage: "heart.fill").font(.headline)
                        .accessibilityIdentifier("dashboardActivityTitle")
                    Spacer()
                    Text("Health").font(.caption).foregroundStyle(.secondary)
                }
                let columns = dynamicTypeSize.isAccessibilitySize ? 1 : 3
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), alignment: .leading), count: columns), alignment: .leading, spacing: 16) {
                    movementValue(todaySteps.formatted(), label: "Steps", color: .green, identifier: "dashboardActivityStepsValue")
                    movementValue(todayActiveCalories.formatted(), label: "Active kcal", color: .orange, identifier: "dashboardActivityCaloriesValue")
                    movementValue(todayExerciseMinutes.formatted(), label: "Exercise min", color: .cyan, identifier: "dashboardActivityExerciseValue")
                }
            }
            .traiCard(contentPadding: 18)
            .accessibilityIdentifier("dashboardActivityCard")
        } else {
            HStack(spacing: 8) {
                if isLoadingActivity { ProgressView().controlSize(.small) }
                else { Image(systemName: "heart") }
                Text(isLoadingActivity ? "Loading movement from Health…" : "Movement from Health isn’t available.")
                    .fixedSize(horizontal: false, vertical: true)
            }
            .font(.footnote).foregroundStyle(.secondary)
            .padding(.horizontal, 4)
            .accessibilityIdentifier("dashboardActivityStatus")
        }
    }

    private func movementValue(_ value: String, label: String, color: Color, identifier: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value).font(.title2.bold()).foregroundStyle(color.gradient).monospacedDigit()
                .accessibilityIdentifier(identifier)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }.accessibilityElement(children: .combine)
    }

    private func recordDashboardLatencyProbe(
        _ operation: String,
        startedAt: UInt64,
        counts: [String: Int] = [:]
    ) {
        guard AppLaunchArguments.shouldEnableLatencyProbe else { return }
        let entry = LatencyProbe.makeEntry(
            operation: operation,
            durationMilliseconds: LatencyProbe.elapsedMilliseconds(since: startedAt),
            counts: counts
        )
        LatencyProbe.append(entry: entry, to: &latencyProbeEntries)
    }

    private func refreshDateScopedCaches() {
        let interval = PerformanceTrace.begin("dashboard_date_cache_refresh", category: .dataLoad)
        let startedAt = LatencyProbe.timerStart()
        defer {
            PerformanceTrace.end("dashboard_date_cache_refresh", interval, category: .dataLoad)
            recordDashboardLatencyProbe(
                "refreshDateScopedCaches",
                startedAt: startedAt,
                counts: [
                    "food": allFoodEntries.count,
                    "workouts": allWorkouts.count,
                    "liveWorkouts": liveWorkouts.count
                ]
            )
        }
        refreshFoodDateCaches()
        refreshWorkoutDateCache()
        refreshLiveWorkoutDateCache()
    }

    private func scheduleDeferredStartupWork(delayMilliseconds: Int) {
        deferredInitialLoadTask?.cancel()
        let activationToken = tabActivationPolicy.activationToken
        let effectiveDelayMilliseconds = tabActivationPolicy.effectiveDelayMilliseconds(
            requested: delayMilliseconds
        )
        deferredInitialLoadTask = Task(priority: .utility) {
            if effectiveDelayMilliseconds > 0 {
                try? await Task.sleep(for: .milliseconds(effectiveDelayMilliseconds))
            }
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard tabActivationPolicy.shouldRunHeavyRefresh(for: activationToken) else { return }
                runDeferredStartupWorkIfNeeded()
            }
        }
    }

    @MainActor
    private func runDeferredStartupWorkIfNeeded() {
        guard !hasPerformedDeferredStartupWork else { return }
        guard isDashboardTabActive else { return }

        hasPerformedDeferredStartupWork = true
        Task(priority: .utility) { @MainActor in
            guard isDashboardTabActive else { return }
            _ = CoachSignalService(modelContext: modelContext).pruneExpiredSignals()
        }
        Task { @MainActor in
            guard isDashboardTabActive else { return }
            await loadActivityData()
        }
        scheduleCoachContextRefresh(forceRefresh: true, immediate: true)
    }

    private func refreshFoodDateCaches() {
        let startedAt = LatencyProbe.timerStart()
        let calendar = Calendar.current
        let selectedStart = calendar.startOfDay(for: selectedDate)
        guard let selectedEnd = calendar.date(byAdding: .day, value: 1, to: selectedStart) else { return }
        let fastWindowCutoff = calendar.date(
            byAdding: .day,
            value: -(Self.dashboardFastFoodWindowDays - 1),
            to: calendar.startOfDay(for: .now)
        ) ?? .distantPast
        let selectedDateInFastWindow = selectedStart >= fastWindowCutoff

        if selectedDateInFastWindow {
            cachedSelectedDayFoodEntries = allFoodEntries.filter {
                $0.loggedAt >= selectedStart && $0.loggedAt < selectedEnd
            }
        } else {
            cachedSelectedDayFoodEntries = fetchFoodEntries(start: selectedStart, end: selectedEnd)
        }
        selectedDayNutritionTotals = DashboardNutritionTotals(entries: cachedSelectedDayFoodEntries)

        let todayStart = calendar.startOfDay(for: Date())
        if let sevenDayStart = calendar.date(byAdding: .day, value: -6, to: todayStart),
           let tomorrowStart = calendar.date(byAdding: .day, value: 1, to: todayStart) {
            cachedLast7DaysFoodEntries = fetchFoodEntries(start: sevenDayStart, end: tomorrowStart)
        } else {
            cachedLast7DaysFoodEntries = []
        }
        if cachedOnDemandFoodTrendAnchor != selectedStart {
            cachedOnDemandFoodTrendEntries = []
            cachedOnDemandFoodTrendAnchor = nil
        }
        recordDashboardLatencyProbe(
            "refreshFoodDateCaches",
            startedAt: startedAt,
            counts: [
                "allFood": allFoodEntries.count,
                "fastWindow": selectedDateInFastWindow ? 1 : 0,
                "selectedFood": cachedSelectedDayFoodEntries.count,
                "last7Food": cachedLast7DaysFoodEntries.count
            ]
        )
    }

    private func selectedDayFastQueryFoodEntries() -> [FoodEntry] {
        let calendar = Calendar.current
        let selectedStart = calendar.startOfDay(for: selectedDate)
        guard let selectedEnd = calendar.date(byAdding: .day, value: 1, to: selectedStart) else { return [] }
        let fastWindowCutoff = calendar.date(
            byAdding: .day,
            value: -(Self.dashboardFastFoodWindowDays - 1),
            to: calendar.startOfDay(for: .now)
        ) ?? .distantPast
        guard selectedStart >= fastWindowCutoff else { return [] }

        return allFoodEntries.filter {
            $0.loggedAt >= selectedStart && $0.loggedAt < selectedEnd
        }
    }

    private func fetchFoodEntries(start: Date, end: Date) -> [FoodEntry] {
        let from = start
        let to = end
        var descriptor = FetchDescriptor<FoodEntry>(
            predicate: #Predicate<FoodEntry> {
                $0.loggedAt >= from && $0.loggedAt < to
            },
            sortBy: [SortDescriptor(\FoodEntry.loggedAt, order: .reverse)]
        )
        descriptor.fetchLimit = Self.dashboardHistoricalFoodFetchLimit
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private func loadFoodTrendHistoryForSelectedDateIfNeeded() {
        let calendar = Calendar.current
        let selectedStart = calendar.startOfDay(for: selectedDate)
        guard cachedOnDemandFoodTrendAnchor != selectedStart else { return }
        guard
            let selectedEnd = calendar.date(byAdding: .day, value: 1, to: selectedStart),
            let trendStart = calendar.date(
                byAdding: .day,
                value: -(Self.dashboardLazyFoodTrendWindowDays - 1),
                to: selectedStart
            )
        else { return }

        let startedAt = LatencyProbe.timerStart()
        cachedOnDemandFoodTrendEntries = fetchFoodEntries(start: trendStart, end: selectedEnd)
        cachedOnDemandFoodTrendAnchor = selectedStart
        recordDashboardLatencyProbe(
            "loadFoodTrendHistoryForSelectedDate",
            startedAt: startedAt,
            counts: [
                "trendFood": cachedOnDemandFoodTrendEntries.count,
                "days": Self.dashboardLazyFoodTrendWindowDays
            ]
        )
    }

    private func refreshWorkoutDateCache() {
        let startedAt = LatencyProbe.timerStart()
        let calendar = Calendar.current
        let selectedStart = calendar.startOfDay(for: selectedDate)
        guard let selectedEnd = calendar.date(byAdding: .day, value: 1, to: selectedStart) else { return }

        cachedSelectedDayWorkouts = allWorkouts.filter {
            $0.loggedAt >= selectedStart && $0.loggedAt < selectedEnd
        }
        recordDashboardLatencyProbe(
            "refreshWorkoutDateCache",
            startedAt: startedAt,
            counts: [
                "allWorkouts": allWorkouts.count,
                "selectedWorkouts": cachedSelectedDayWorkouts.count
            ]
        )
    }

    private func refreshLiveWorkoutDateCache() {
        let startedAt = LatencyProbe.timerStart()
        let calendar = Calendar.current
        let selectedStart = calendar.startOfDay(for: selectedDate)
        guard let selectedEnd = calendar.date(byAdding: .day, value: 1, to: selectedStart) else { return }

        cachedSelectedDayLiveWorkouts = liveWorkouts.filter { workout in
            (workout.startedAt >= selectedStart && workout.startedAt < selectedEnd)
                || workout.completedAt.map { $0 >= selectedStart && $0 < selectedEnd } == true
        }
        recordDashboardLatencyProbe(
            "refreshLiveWorkoutDateCache",
            startedAt: startedAt,
            counts: [
                "allLive": liveWorkouts.count,
                "selectedLive": cachedSelectedDayLiveWorkouts.count
            ]
        )
    }

    private var totalCalories: Int {
        visibleSelectedDayNutritionTotals.calories
    }

    private var totalProtein: Double {
        visibleSelectedDayNutritionTotals.protein
    }

    private var totalCarbs: Double {
        visibleSelectedDayNutritionTotals.carbs
    }

    private var totalFat: Double {
        visibleSelectedDayNutritionTotals.fat
    }

    private var totalFiber: Double {
        visibleSelectedDayNutritionTotals.fiber
    }

    private var totalSugar: Double {
        visibleSelectedDayNutritionTotals.sugar
    }

    private var todaysReminderItems: [TodaysRemindersCard.ReminderItem] {
        guard remindersLoaded, let profile else { return [] }

        let enabledMeals = Set(profile.enabledMealReminders.split(separator: ",").map(String.init))
        let workoutDays = Set(profile.workoutReminderDays.split(separator: ",").compactMap { Int($0) })

        let allItems = TodaysRemindersCard.buildReminderItems(
            from: customReminders,
            mealRemindersEnabled: profile.mealRemindersEnabled,
            enabledMeals: enabledMeals,
            workoutRemindersEnabled: profile.workoutRemindersEnabled,
            workoutDays: workoutDays,
            workoutHour: profile.workoutReminderHour,
            workoutMinute: profile.workoutReminderMinute
        )

        // Filter out completed reminders
        return allItems.filter { !todaysCompletedReminderIds.contains($0.id) }
    }

    private var todaysReminderItemsAll: [TodaysRemindersCard.ReminderItem] {
        guard remindersLoaded, let profile else { return [] }

        return TodaysRemindersCard.buildReminderItems(
            from: customReminders,
            mealRemindersEnabled: profile.mealRemindersEnabled,
            enabledMeals: Set(profile.enabledMealReminders.split(separator: ",").map(String.init)),
            workoutRemindersEnabled: profile.workoutRemindersEnabled,
            workoutDays: Set(profile.workoutReminderDays.split(separator: ",").compactMap { Int($0) }),
            workoutHour: profile.workoutReminderHour,
            workoutMinute: profile.workoutReminderMinute
        )
    }

    private func clamp(_ value: Double) -> Double {
        max(0.0, min(1.0, value))
    }

    private var todaysReminderCompletionRate: Double? {
        guard !todaysReminderItemsAll.isEmpty else { return nil }
        let completed = todaysReminderItemsAll.filter { todaysCompletedReminderIds.contains($0.id) }.count
        return Double(completed) / Double(todaysReminderItemsAll.count)
    }

    private var todaysMissedReminderCount: Int? {
        guard !todaysReminderItemsAll.isEmpty else { return nil }
        return max(0, todaysReminderItemsAll.count - todaysReminderItems.count)
    }

    private var daysSinceLastWeightLog: Int? {
        guard let latest = weightEntries.first else { return nil }

        let calendar = Calendar.current
        let latestDay = calendar.startOfDay(for: latest.loggedAt)
        let today = calendar.startOfDay(for: Date())
        let delta = calendar.dateComponents([.day], from: latestDay, to: today).day ?? 0
        return max(delta, 0)
    }

    private var loggedWeightThisWeek: Bool? {
        let calendar = Calendar.current
        guard let weekStart = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: Date())) else {
            return nil
        }
        return weightEntries.contains { $0.loggedAt >= weekStart }
    }

    private var inferredWeightLogWeekdays: [String] {
        let recentWeightEntries = Array(weightEntries.prefix(12))
        guard recentWeightEntries.count >= 3 else { return [] }

        let weekdayCounts = recentWeightEntries.reduce(into: [Int: Int]()) { counts, entry in
            let weekday = Calendar.current.component(.weekday, from: entry.loggedAt)
            counts[weekday, default: 0] += 1
        }

        let sortedDays = weekdayCounts.sorted { lhs, rhs in
            if lhs.value != rhs.value { return lhs.value > rhs.value }
            return lhs.key < rhs.key
        }

        guard let topCount = sortedDays.first?.value, topCount >= 2 else { return [] }
        let threshold = max(2, Int(Double(topCount) * 0.5.rounded(.up)))

        return sortedDays
            .filter { $0.value >= threshold }
            .compactMap { weekday in
                switch weekday.key {
                case 1: return "Sunday"
                case 2: return "Monday"
                case 3: return "Tuesday"
                case 4: return "Wednesday"
                case 5: return "Thursday"
                case 6: return "Friday"
                case 7: return "Saturday"
                default: return nil
                }
            }
    }

    private var inferredWeightLogTimes: [String] {
        let recentWeightEntries = Array(weightEntries.prefix(10))
        guard recentWeightEntries.count >= 3 else { return [] }

        let timeCounts = recentWeightEntries.reduce(into: [String: Int]()) { counts, entry in
            let hour = Calendar.current.component(.hour, from: entry.loggedAt)
            let bucket: String
            switch hour {
            case 4..<9:
                bucket = "Morning (4-9 AM)"
            case 9..<12:
                bucket = "Late Morning (9-12 PM)"
            case 12..<15:
                bucket = "Early Afternoon (12-3 PM)"
            case 15..<18:
                bucket = "Mid-Afternoon (3-6 PM)"
            case 18..<22:
                bucket = "Evening (6-10 PM)"
            default:
                bucket = "Night (10 PM-4 AM)"
            }
            counts[bucket, default: 0] += 1
        }

        guard !timeCounts.isEmpty else { return [] }
        let topCount = timeCounts.values.max() ?? 0
        guard topCount >= 2 else { return [] }
        let threshold = max(2, Int(Double(topCount) * 0.5.rounded(.up)))

        return timeCounts
            .filter { $0.value >= threshold }
            .keys
            .sorted()
    }

    private var inferredWeightLogRoutineScore: Double {
        guard weightEntries.count >= 4 else { return 0 }
        guard let daysSince = daysSinceLastWeightLog else { return 0 }

        let calendar = Calendar.current
        let currentWeekday = weekdayLabel(for: calendar.component(.weekday, from: Date()))
        let currentHour = calendar.component(.hour, from: Date())
        let isUsualWeekday = inferredWeightLogWeekdays.contains(currentWeekday)
        let isUsualTime = matchingWeightLogWindow(hour: currentHour, windows: inferredWeightLogTimes) != nil

        let daysSinceScore = min(Double(daysSince), 10.0) / 20.0
        let recurrenceScore = isUsualWeekday ? 0.22 : 0.0
        let timeScore = isUsualTime ? 0.2 : 0.0
        let volumeScore = min(Double(min(weightEntries.count, 20)), 20.0) / 100.0
        let routinePenalty = isUsualWeekday && isUsualTime ? 0.0 : -0.12

        return clamp(daysSinceScore + recurrenceScore + timeScore + volumeScore + routinePenalty)
    }

    private func weekdayLabel(for weekday: Int) -> String {
        switch weekday {
        case 1: return "Sunday"
        case 2: return "Monday"
        case 3: return "Tuesday"
        case 4: return "Wednesday"
        case 5: return "Thursday"
        case 6: return "Friday"
        case 7: return "Saturday"
        default: return ""
        }
    }

    private func matchingWeightLogWindow(hour: Int, windows: [String]) -> String? {
        guard (0...23).contains(hour) else { return nil }

        for window in windows {
            switch window {
            case "Morning (4-9 AM)":
                if (4...8).contains(hour) { return "morning window" }
            case "Late Morning (9-12 PM)":
                if (9...11).contains(hour) { return "late morning window" }
            case "Early Afternoon (12-3 PM)":
                if (12...14).contains(hour) { return "early afternoon window" }
            case "Mid-Afternoon (3-6 PM)":
                if (15...17).contains(hour) { return "mid afternoon window" }
            case "Evening (6-10 PM)":
                if (18...21).contains(hour) { return "evening window" }
            case "Night (10 PM-4 AM)":
                if hour >= 22 || hour <= 3 { return "night window" }
            default:
                continue
            }
        }

        return nil
    }

    private var recentWeightRangeKg: Double? {
        let recentWeightEntries = Array(weightEntries.prefix(20))
        guard recentWeightEntries.count >= 5 else { return nil }

        let weights = recentWeightEntries.map(\.weightKg)
        guard let minWeight = weights.min(), let maxWeight = weights.max() else { return nil }

        return maxWeight - minWeight
    }

    private var pendingPlanReviewRecommendation: PlanRecommendation? {
        guard let profile else { return nil }
        return PlanAssessmentService().checkForRecommendation(
            profile: profile,
            weightEntries: Array(weightEntries),
            foodEntries: Array(insightFoodEntries)
        )
    }

    private var pendingPlanReviewMessage: String? {
        guard
            let profile,
            let recommendation = pendingPlanReviewRecommendation
        else { return nil }
        return PlanAssessmentService().getRecommendationMessage(
            recommendation,
            useLbs: !(profile.usesMetricWeight)
        )
    }

    private var lastRecentWorkoutAt: Date? {
        let referenceDate = Date()
        let recentWorkoutDate = (allWorkouts.map(\.loggedAt) + liveWorkouts.map { $0.completedAt ?? $0.startedAt })
            .filter { $0 <= referenceDate }
        guard let latest = recentWorkoutDate.max() else { return nil }
        return latest
    }

    private var lastRecentCompletedWorkoutName: String? {
        let referenceDate = Date()

        let latestLoggedWorkout = allWorkouts
            .filter { $0.loggedAt <= referenceDate }
            .max { $0.loggedAt < $1.loggedAt }
            .map { workout -> (date: Date, name: String) in
                let name = workout.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
                return (workout.loggedAt, name.isEmpty ? "Workout" : name)
            }

        let latestCompletedLiveWorkout = liveWorkouts
            .compactMap { workout -> (date: Date, name: String)? in
                guard let completedAt = workout.completedAt, completedAt <= referenceDate else {
                    return nil
                }
                let rawName = workout.name.trimmingCharacters(in: .whitespacesAndNewlines)
                let resolvedName = rawName.isEmpty ? "\(workout.type.displayName) Workout" : rawName
                return (completedAt, resolvedName)
            }
            .max { $0.date < $1.date }

        switch (latestLoggedWorkout, latestCompletedLiveWorkout) {
        case let (logged?, live?):
            return logged.date >= live.date ? logged.name : live.name
        case let (logged?, nil):
            return logged.name
        case let (nil, live?):
            return live.name
        case (nil, nil):
            return nil
        }
    }

    private var lastRecentWorkoutHour: Int? {
        guard let latest = lastRecentWorkoutAt else { return nil }
        return Calendar.current.component(.hour, from: latest)
    }

    private func fetchCustomReminders() {
        let startedAt = LatencyProbe.timerStart()
        let descriptor = FetchDescriptor<CustomReminder>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        customReminders = (try? modelContext.fetch(descriptor)) ?? []

        let now = Date()
        let lookbackStart = Calendar.current.date(byAdding: .day, value: -reminderHabitWindowDays, to: now) ?? now
        let startOfDay = Calendar.current.startOfDay(for: Date())
        let completionDescriptor = FetchDescriptor<ReminderCompletion>(
            predicate: #Predicate { $0.completedAt >= lookbackStart },
            sortBy: [SortDescriptor(\.completedAt, order: .reverse)]
        )
        var limitedCompletionDescriptor = completionDescriptor
        limitedCompletionDescriptor.fetchLimit = reminderCompletionHistoryCapPerWindow
        let completions = (try? modelContext.fetch(limitedCompletionDescriptor)) ?? []
        reminderCompletionHistory = completions
        trimReminderCompletionHistory(to: now)
        todaysCompletedReminderIds = Set(
            completions
                .filter { $0.completedAt >= startOfDay }
                .map { $0.reminderId }
        )
        updateActivationChecklistCompletionCache()
        recordDashboardLatencyProbe(
            "fetchCustomReminders",
            startedAt: startedAt,
            counts: [
                "customReminders": customReminders.count,
                "completionHistory": reminderCompletionHistory.count,
                "completedToday": todaysCompletedReminderIds.count
            ]
        )
    }

    private func scheduleRemindersLoad(delayMilliseconds: Int = 0) {
        remindersLoadTask?.cancel()
        let activationToken = tabActivationPolicy.activationToken
        let effectiveDelayMilliseconds = tabActivationPolicy.effectiveDelayMilliseconds(
            requested: delayMilliseconds
        )
        remindersLoadTask = Task(priority: .utility) {
            if effectiveDelayMilliseconds > 0 {
                try? await Task.sleep(for: .milliseconds(effectiveDelayMilliseconds))
            }
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard tabActivationPolicy.shouldRunHeavyRefresh(for: activationToken) else { return }
                fetchCustomReminders()
                remindersLoaded = true
            }
        }
    }

    private func trimReminderCompletionHistory(to referenceDate: Date) {
        let start = Calendar.current.date(
            byAdding: .day,
            value: -reminderHabitWindowDays,
            to: referenceDate
        ) ?? referenceDate

        reminderCompletionHistory.removeAll { $0.completedAt < start }
        while reminderCompletionHistory.count > reminderCompletionHistoryCapPerWindow {
            reminderCompletionHistory.removeLast()
        }
    }

    private func openReminderComposer(_ reminder: TodaysRemindersCard.ReminderItem) {
        if reminder.isCustom, let customReminder = customReminders.first(where: { $0.id == reminder.id }) {
            reminderComposerSeed = .custom(customReminder)
            return
        }

        if reminder.id == StableUUID.forMeal(MealReminderTime.breakfast.id) {
            reminderComposerSeed = .preset(.breakfast)
        } else if reminder.id == StableUUID.forMeal(MealReminderTime.lunch.id) {
            reminderComposerSeed = .preset(.lunch)
        } else if reminder.id == StableUUID.forMeal(MealReminderTime.dinner.id) {
            reminderComposerSeed = .preset(.dinner)
        } else if reminder.id == StableUUID.forWeightReminder() {
            reminderComposerSeed = .preset(.weighIn)
        } else {
            reminderComposerSeed = .preset(.workout)
        }
    }

    private func completeReminder(_ reminder: TodaysRemindersCard.ReminderItem) {
        if todaysCompletedReminderIds.contains(reminder.id) {
            notificationService?.cancelPendingRequest(identifier: reminder.pendingNotificationIdentifier)
            return
        }

        // Calculate if completed on time (within 30 min of scheduled time)
        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        let reminderID = reminder.id
        let existingDescriptor = FetchDescriptor<ReminderCompletion>(
            predicate: #Predicate { completion in
                completion.reminderId == reminderID && completion.completedAt >= startOfDay
            }
        )
        if let existing = try? modelContext.fetch(existingDescriptor), !existing.isEmpty {
            _ = withAnimation(.easeInOut(duration: 0.3)) {
                todaysCompletedReminderIds.insert(reminder.id)
            }
            notificationService?.cancelPendingRequest(identifier: reminder.pendingNotificationIdentifier)
            return
        }

        let currentHour = calendar.component(.hour, from: now)
        let currentMinute = calendar.component(.minute, from: now)
        let currentMinutes = currentHour * 60 + currentMinute
        let reminderMinutes = reminder.hour * 60 + reminder.minute
        let wasOnTime = currentMinutes <= reminderMinutes + 30

        // Create and save completion record
        let completion = ReminderCompletion(
            reminderId: reminder.id,
            completedAt: now,
            wasOnTime: wasOnTime
        )
        modelContext.insert(completion)
        do {
            try modelContext.save()
        } catch {
            print("Failed to save reminder completion: \(error)")
        }
        reminderCompletionHistory.insert(completion, at: 0)
        trimReminderCompletionHistory(to: now)

        // Update local state with animation for smooth removal
        _ = withAnimation(.easeInOut(duration: 0.3)) {
            todaysCompletedReminderIds.insert(reminder.id)
        }
        notificationService?.cancelPendingRequest(identifier: reminder.pendingNotificationIdentifier)

        BehaviorTracker(modelContext: modelContext).record(
            actionKey: BehaviorActionKey.completeReminder,
            domain: .reminder,
            surface: .dashboard,
            outcome: .completed,
            relatedEntityId: reminder.id,
            metadata: [
                "title": reminder.title,
                "time": reminder.time
            ]
        )

        scheduleCoachContextRefresh(forceRefresh: true, immediate: true)
        HapticManager.success()
    }

    private func loadActivityData() async {
        let interval = PerformanceTrace.begin("dashboard_activity_summary_load", category: .dataLoad)
        defer { PerformanceTrace.end("dashboard_activity_summary_load", interval, category: .dataLoad) }

        guard isViewingToday else { return }
        isLoadingActivity = true
        hasLoadedActivitySummary = false
        defer { isLoadingActivity = false }
        guard let healthKitService, healthKitService.isHealthKitAvailable else { return }

        do {
            let summary = try await healthKitService.fetchTodayActivitySummaryAuthorized()
            todaySteps = summary.steps
            todayActiveCalories = summary.activeCalories
            todayExerciseMinutes = summary.exerciseMinutes
            hasLoadedActivitySummary = true
        } catch {
            // Silently fail - user may not have granted HealthKit permissions
            print("Failed to load activity data: \(error)")
        }
    }

    private func refreshHealthData() async {
        await loadActivityData()
        scheduleCoachContextRefresh(forceRefresh: true, immediate: true)
    }

    private func scheduleCoachContextRefresh(forceRefresh: Bool = false, immediate: Bool = false) {
        coachContextRefreshTask?.cancel()
        let requestedDelayMilliseconds = immediate ? 0 : Self.coachContextRefreshDelayMilliseconds
        let activationToken = tabActivationPolicy.activationToken
        let delayMilliseconds = tabActivationPolicy.effectiveDelayMilliseconds(
            requested: requestedDelayMilliseconds
        )
        coachContextRefreshTask = Task(priority: .utility) {
            if delayMilliseconds > 0 {
                try? await Task.sleep(for: .milliseconds(delayMilliseconds))
            }
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard tabActivationPolicy.shouldRunHeavyRefresh(for: activationToken) else { return }
                guard isDashboardTabActive else { return }
                refreshRecommendedTemplateCacheIfNeeded(forceRefresh: forceRefresh)
            }
        }
    }

    private func refreshRecommendedTemplateCacheIfNeeded(forceRefresh: Bool = false) {
        let shouldRefresh = forceRefresh || DashboardRefreshPolicy.shouldRefreshRecovery(
            isWorkoutRuntimeActive: activeWorkoutRuntimeState.isLiveWorkoutPresented || hasActiveLiveWorkout
        )
        guard shouldRefresh || cachedRecommendedTemplateId == nil else {
            return
        }

        let interval = PerformanceTrace.begin("dashboard_recommended_template_refresh", category: .dataLoad)
        let startedAt = LatencyProbe.timerStart()
        cachedRecommendedTemplateId = computeRecommendedTemplateId()
        PerformanceTrace.end("dashboard_recommended_template_refresh", interval, category: .dataLoad)
        recordDashboardLatencyProbe(
            "refreshRecommendedTemplateCache",
            startedAt: startedAt,
            counts: [
                "hasTemplate": cachedRecommendedTemplateId == nil ? 0 : 1,
                "force": forceRefresh ? 1 : 0
            ]
        )
    }

    private func deleteFoodEntry(_ entry: FoodEntry) {
        entry.imageData = nil
        modelContext.delete(entry)
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            persistenceError = DashboardPersistenceError(
                title: "Food Not Deleted",
                message: error.localizedDescription
            )
            HapticManager.error()
            return
        }
        HapticManager.success()
    }

    private func behaviorActionStateForToday() -> (openedActionKeys: Set<String>, completedActionKeys: Set<String>) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: .now)
        var opened: Set<String> = []
        var completed: Set<String> = []

        for event in behaviorEvents {
            if event.occurredAt < startOfDay {
                break
            }

            switch event.outcome {
            case .opened:
                opened.insert(event.actionKey)
            case .performed:
                opened.insert(event.actionKey)
                completed.insert(event.actionKey)
            case .completed:
                opened.insert(event.actionKey)
                completed.insert(event.actionKey)
            case .presented, .suggestedTap, .dismissed:
                continue
            }
        }

        return (opened, completed)
    }

    private func openFoodCameraFromDashboard(source: String, sessionId: UUID? = nil, targetDate: Date? = nil) {
        presentFoodCamera(sessionId: sessionId, targetDate: targetDate)
        BehaviorTracker(modelContext: modelContext).recordDeferred(
            actionKey: BehaviorActionKey.logFood,
            domain: .nutrition,
            surface: .dashboard,
            outcome: .opened,
            metadata: ["source": source]
        )
    }

    private func presentFoodCamera(sessionId: UUID? = nil, targetDate: Date? = nil) {
        prewarmFoodCameraSuggestions(
            sessionId: sessionId,
            targetDate: targetDate,
            modelContext: modelContext
        )

        if let onPresentFoodCamera {
            onPresentFoodCamera(sessionId, targetDate)
            return
        }

        guard localFoodCameraPresentation == nil else { return }
        localFoodCameraPresentation = FoodCameraPresentation(sessionId: sessionId, targetDate: targetDate)
    }

    private func openLogWeightFromDashboard(source: String) {
        showingLogWeight = true
        BehaviorTracker(modelContext: modelContext).recordDeferred(
            actionKey: BehaviorActionKey.logWeight,
            domain: .body,
            surface: .dashboard,
            outcome: .opened,
            metadata: ["source": source]
        )
    }

    private func openCalorieDetailFromDashboard(source: String) {
        loadFoodTrendHistoryForSelectedDateIfNeeded()
        showingCalorieDetail = true
        BehaviorTracker(modelContext: modelContext).recordDeferred(
            actionKey: BehaviorActionKey.openCalorieDetail,
            domain: .nutrition,
            surface: .dashboard,
            outcome: .opened,
            metadata: ["source": source]
        )
    }

    private func openMacroDetailFromDashboard(source: String) {
        loadFoodTrendHistoryForSelectedDateIfNeeded()
        showingMacroDetail = true
        BehaviorTracker(modelContext: modelContext).recordDeferred(
            actionKey: BehaviorActionKey.openMacroDetail,
            domain: .nutrition,
            surface: .dashboard,
            outcome: .opened,
            metadata: ["source": source]
        )
    }

    private func trackOpenWeightFromDashboard(source: String) {
        BehaviorTracker(modelContext: modelContext).recordDeferred(
            actionKey: BehaviorActionKey.openWeight,
            domain: .body,
            surface: .dashboard,
            outcome: .opened,
            metadata: ["source": source]
        )
    }

    // MARK: - Workout Actions

    private func openOrStartWorkout() {
        if let workout = liveWorkouts.first(where: { $0.completedAt == nil }) {
            presentLiveWorkout(workout: workout)
        } else {
            startWorkout()
        }
    }

    private func startWorkout() {
        guard let profile else {
            startCustomWorkout()
            return
        }

        switch profile.defaultWorkoutActionValue {
        case .customWorkout:
            startCustomWorkout()
        case .recommendedWorkout:
            startRecommendedWorkout()
        }
    }

    private func startWorkoutFromTemplate(_ template: WorkoutPlan.WorkoutTemplate) {
        let workout = workoutTemplateService.createStartWorkout(from: template)
        _ = workoutTemplateService.persistWorkout(workout, modelContext: modelContext)
        BehaviorTracker(modelContext: modelContext).record(
            actionKey: BehaviorActionKey.startWorkout,
            domain: .workout,
            surface: .dashboard,
            outcome: .performed,
            relatedEntityId: workout.id,
            metadata: [
                "type": "template",
                "template_name": template.name
            ]
        )

        presentLiveWorkout(workout: workout, template: template)
        HapticManager.selectionChanged()
    }

    private func startCustomWorkout() {
        let workout = workoutTemplateService.createCustomWorkout()
        _ = workoutTemplateService.persistWorkout(workout, modelContext: modelContext)
        BehaviorTracker(modelContext: modelContext).record(
            actionKey: BehaviorActionKey.startWorkout,
            domain: .workout,
            surface: .dashboard,
            outcome: .performed,
            relatedEntityId: workout.id,
            metadata: ["type": "custom"]
        )

        presentLiveWorkout(workout: workout)
        HapticManager.selectionChanged()
    }

    private func startRecommendedWorkout() {
        guard let plan = profile?.workoutPlan else {
            // Fall back to custom workout if no plan exists
            startCustomWorkout()
            return
        }

        let template: WorkoutPlan.WorkoutTemplate?
        if let cachedTemplateId = cachedRecommendedTemplateId {
            template = plan.templates.first(where: { $0.id == cachedTemplateId }) ?? plan.templates.first
        } else {
            if let recommendedTemplateId = recoveryService.getRecommendedTemplateId(
                plan: plan,
                modelContext: modelContext
            ) {
                template = plan.templates.first(where: { $0.id == recommendedTemplateId }) ?? plan.templates.first
            } else {
                template = plan.templates.first
            }
        }

        guard let template else {
            startCustomWorkout()
            return
        }

        let workout = workoutTemplateService.createStartWorkout(from: template)
        _ = workoutTemplateService.persistWorkout(workout, modelContext: modelContext)
        BehaviorTracker(modelContext: modelContext).record(
            actionKey: BehaviorActionKey.startWorkout,
            domain: .workout,
            surface: .dashboard,
            outcome: .performed,
            relatedEntityId: workout.id,
            metadata: [
                "type": "recommended",
                "template_name": template.name
            ]
        )

        presentLiveWorkout(workout: workout, template: template)
        HapticManager.selectionChanged()
    }

    private func mergeUniqueStrings(_ base: [String], _ extra: [String]) -> [String] {
        var ordered: [String] = []
        var seen = Set<String>()
        for value in base + extra {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            if seen.insert(trimmed).inserted {
                ordered.append(trimmed)
            }
        }
        return ordered
    }

}

private struct DashboardTopGradient: View {
    private var lensColors: [Color] {
        TraiLensPalette.energy.colors
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    lensColors[0].opacity(0.34),
                    lensColors[1].opacity(0.26),
                    lensColors[2].opacity(0.20),
                    lensColors[3].opacity(0.14),
                    .clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(lensColors[2].opacity(0.22))
                .frame(width: 320, height: 320)
                .blur(radius: 50)
                .offset(x: 130, y: -120)

            Circle()
                .fill(lensColors[0].opacity(0.20))
                .frame(width: 260, height: 260)
                .blur(radius: 44)
                .offset(x: -130, y: -80)
        }
        .mask(
            LinearGradient(
                stops: [
                    .init(color: .black, location: 0),
                    .init(color: .black, location: 0.45),
                    .init(color: .clear, location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .frame(height: 420)
        .offset(y: -140)
        .ignoresSafeArea(edges: .top)
        .allowsHitTesting(false)
    }
}

private struct OnboardingActivationChecklistCard: View {
    let hasLoggedFood: Bool
    let hasWorkoutPlan: Bool
    let hasHealthAccess: Bool
    let hasReminders: Bool
    let healthError: String?
    let onLogFood: () -> Void
    let onCreateWorkoutPlan: () -> Void
    let onConnectHealth: () -> Void
    let onSetReminders: () -> Void
    let onDismiss: () -> Void

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Button {
                    withAnimation(.smooth) { isExpanded.toggle() }
                } label: {
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Finish setting up Trai").font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                            Text("\(4 - completedCount) optional steps").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    }.frame(minHeight: 44).contentShape(.rect)
                }.buttonStyle(.plain).accessibilityIdentifier("dashboardSetupToggle")
                    .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")
                Button("Dismiss setup checklist", systemImage: "xmark", action: onDismiss)
                    .labelStyle(.iconOnly).buttonStyle(.plain).foregroundStyle(.secondary)
                    .frame(width: 44, height: 44)
            }
            if isExpanded {
                VStack(spacing: 10) {
                    if !hasLoggedFood {
                        checklistRow(
                            title: "Log your first meal",
                            icon: "camera.fill",
                            action: onLogFood
                        )
                    }

                    if !hasWorkoutPlan {
                        checklistRow(
                            title: "Create a workout plan",
                            icon: "figure.strengthtraining.traditional",
                            action: onCreateWorkoutPlan
                        )
                    }

                    if !hasHealthAccess {
                        checklistRow(
                            title: "Connect Apple Health",
                            icon: "heart.fill",
                            action: onConnectHealth
                        )
                    }

                    if !hasReminders {
                        checklistRow(
                            title: "Set reminders",
                            icon: "bell.badge.fill",
                            action: onSetReminders
                        )
                    }
                }

            }

            if let healthError, !healthError.isEmpty {
                Text(healthError)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .traiCard(contentPadding: 14)
    }

    private var completedCount: Int {
        [hasLoggedFood, hasWorkoutPlan, hasHealthAccess, hasReminders].filter { $0 }.count
    }

    private func checklistRow(
        title: String,
        icon: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.accent)
                    .frame(width: 32, height: 32)
                    .background(
                        Color.accentColor.opacity(0.12),
                        in: Circle()
                    )

                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct DashboardPersistenceError: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

#Preview {
    DashboardView()
        .modelContainer(for: [
            UserProfile.self,
            FoodEntry.self,
            WorkoutSession.self,
            WeightEntry.self,
            CoachSignal.self,
            BehaviorEvent.self
        ], inMemory: true)
}
