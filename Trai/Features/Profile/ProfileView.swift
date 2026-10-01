//
//  ProfileView.swift
//  Trai
//

import SwiftUI
import SwiftData

struct ProfileView: View {
    enum Mode: Equatable {
        case account, nutritionPlan, workoutPlan

        var title: String {
            switch self {
            case .account: "Account"
            case .nutritionPlan: "Nutrition plan"
            case .workoutPlan: "Workout plan"
            }
        }
    }

    let mode: Mode
    let onSelectTab: ((AppTab) -> Void)?
    @Query var profiles: [UserProfile]
    @Query private var activeWorkouts: [LiveWorkout]
    @Query private var historicalWorkouts: [WorkoutSession]
    @Query private var loggedFoodEntries: [FoodEntry]
    @Query private var loggedChatMessages: [ChatMessage]
    @Query private var todaysWorkouts: [WorkoutSession]
    @Query private var todaysLiveWorkouts: [LiveWorkout]

    @Environment(\.dismiss) private var dismiss
    @Environment(BillingService.self) private var billingService: BillingService?
    @Environment(\.appTabSelection) private var appTabSelection
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    @Environment(\.modelContext) var modelContext
    @Environment(AccountSessionService.self) var accountSessionService: AccountSessionService?
    @Environment(MonetizationService.self) private var monetizationService: MonetizationService?
    @Environment(ProUpsellCoordinator.self) var proUpsellCoordinator: ProUpsellCoordinator?
    @State var showPlanSheet = false
    @State var showSettingsSheet = false
    @State var customRemindersCount = 0
    @State var standardWorkoutPlanDraft = OnboardingWorkoutPlanDraft()
    @State var standardGeneratedWorkoutPlan: WorkoutPlan?
    @State var standardGeneratedWorkoutGoals: [WorkoutGoal] = []
    @State private var standardWorkoutPlanSetupBase: WorkoutPlan?
    @State var standardWorkoutPlanAIService = AIService()

    // Workout plan management sheets
    @State var showPlanSetupSheet = false
    @State var showPlanEditSheet = false
    @State private var lastOpenTrackedAt: Date?
    @State private var latestWeightKg: Double?
    @State private var activeMemoriesCount = 0
    @State private var chatConversationCount = 0
    @State private var profileMetricsRefreshTask: Task<Void, Never>?
    @State private var remindersCountTask: Task<Void, Never>?
    @State private var hasPendingProfileMetricsRefresh = false
    @State private var hasPendingRemindersCountRefresh = false
    @State private var hasExecutedInitialHeavyRefresh = false
    @State private var isProfileTabVisible = false
    @State private var latencyProbeEntries: [String] = []
    @State private var tabActivationPolicy = TabActivationPolicy(minimumDwellMilliseconds: 0)
    @State var presentedAccountSetupContext: AccountSetupContext?
    @State private var workoutPlanSaveError: WorkoutPlanSaveError?

    @AppStorage(SharedStorageKeys.Chat.currentSessionId) var currentChatSessionIdString = ""
    @AppStorage(SharedStorageKeys.Chat.pendingOpenSessionId) var pendingOpenChatSessionIdString = ""
    @AppStorage("profile_cached_latest_weight_kg") private var cachedLatestWeightKg: Double = -1
    @AppStorage("profile_cached_active_memories_count") private var cachedActiveMemoriesCount = 0
    @AppStorage("profile_cached_chat_conversation_count") private var cachedChatConversationCount = 0
    @AppStorage("profile_cached_custom_reminders_count") private var cachedCustomRemindersCount = 0
    @AppStorage("profile_cached_owner_id") private var cachedOwnerProfileID = ""
    @AppStorage("profile_metrics_last_refresh_at") private var profileMetricsLastRefreshAt: Double = 0
    @AppStorage("profile_reminders_last_refresh_at") private var remindersCountLastRefreshAt: Double = 0
    private static let profileChatWindowDays = 90
    private static let profileMetricsStaleAfterSeconds: Double = 24 * 60 * 60
    private static let profileRemindersStaleAfterSeconds: Double = 24 * 60 * 60
    private static var profileHeavyMetricsDelayMilliseconds: Int {
        AppLaunchArguments.shouldAggressivelyDeferHeavyTabWork ? 4200 : 420
    }
    private static var profileReactivationHeavyDelayMilliseconds: Int {
        AppLaunchArguments.shouldAggressivelyDeferHeavyTabWork ? 5200 : 540
    }
    private static var profileHeavyRefreshMinimumDwellMilliseconds: Int {
        AppLaunchArguments.shouldAggressivelyDeferHeavyTabWork ? 2200 : 320
    }

    init(mode: Mode = .account, onSelectTab: ((AppTab) -> Void)? = nil) {
        self.mode = mode
        self.onSelectTab = onSelectTab
        let now = Date()
        let startOfToday = Calendar.current.startOfDay(for: now)
        let endOfToday = Calendar.current.date(byAdding: .day, value: 1, to: startOfToday) ?? startOfToday

        var profileDescriptor = FetchDescriptor<UserProfile>()
        profileDescriptor.fetchLimit = 1
        _profiles = Query(profileDescriptor)

        var activeWorkoutDescriptor = FetchDescriptor<LiveWorkout>(
            predicate: #Predicate<LiveWorkout> { workout in
                workout.completedAt == nil
            }
        )
        activeWorkoutDescriptor.fetchLimit = 1
        _activeWorkouts = Query(activeWorkoutDescriptor)

        var historicalWorkoutDescriptor = FetchDescriptor<WorkoutSession>(
            sortBy: [SortDescriptor(\WorkoutSession.loggedAt, order: .reverse)]
        )
        historicalWorkoutDescriptor.fetchLimit = 1
        _historicalWorkouts = Query(historicalWorkoutDescriptor)

        var foodEntriesDescriptor = FetchDescriptor<FoodEntry>(
            sortBy: [SortDescriptor(\FoodEntry.loggedAt, order: .reverse)]
        )
        foodEntriesDescriptor.fetchLimit = 1
        _loggedFoodEntries = Query(foodEntriesDescriptor)

        var chatMessagesDescriptor = FetchDescriptor<ChatMessage>(
            sortBy: [SortDescriptor(\ChatMessage.timestamp, order: .reverse)]
        )
        chatMessagesDescriptor.fetchLimit = 1
        _loggedChatMessages = Query(chatMessagesDescriptor)

        var todaysWorkoutDescriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate<WorkoutSession> { workout in
                workout.loggedAt >= startOfToday
            },
            sortBy: [SortDescriptor(\WorkoutSession.loggedAt, order: .reverse)]
        )
        todaysWorkoutDescriptor.fetchLimit = 1
        _todaysWorkouts = Query(todaysWorkoutDescriptor)

        var todaysLiveWorkoutDescriptor = FetchDescriptor<LiveWorkout>(
            predicate: #Predicate<LiveWorkout> { workout in
                (workout.startedAt >= startOfToday && workout.startedAt < endOfToday)
                    || ((workout.completedAt ?? workout.startedAt) >= startOfToday && (workout.completedAt ?? workout.startedAt) < endOfToday)
            },
            sortBy: [SortDescriptor(\LiveWorkout.startedAt, order: .reverse)]
        )
        todaysLiveWorkoutDescriptor.fetchLimit = 1
        _todaysLiveWorkouts = Query(todaysLiveWorkoutDescriptor)
    }

    var profile: UserProfile? { profiles.first }

    var hasWorkoutToday: Bool {
        let interval = WorkoutDayTargetContext.dayInterval()
        return WorkoutDayTargetContext.hasWorkout(
            in: interval,
            workoutSessions: todaysWorkouts,
            liveWorkouts: todaysLiveWorkouts
        ) || isActiveWorkoutInProgress
    }

    private var isProfileTabActive: Bool {
        isProfileTabVisible
    }

    private var isActiveWorkoutInProgress: Bool {
        !activeWorkouts.isEmpty
    }

    private var currentProfileID: String {
        profile?.id.uuidString ?? ""
    }

    var latestWeightForPlanPrompt: Double? { latestWeightKg }
    var memoryCount: Int { activeMemoriesCount }
    var conversationCount: Int { chatConversationCount }
    var canAccessAIFeatures: Bool { monetizationService?.canAccessAIFeatures ?? true }
    var standardWorkoutPlanSetupContext: OnboardingWorkoutPlanUserContext {
        let profile = self.profile
        return OnboardingWorkoutPlanUserContext(
            name: profile?.name ?? "User",
            age: profile?.age ?? 30,
            gender: profile?.genderValue ?? .notSpecified,
            goal: profile?.goal ?? .maintenance,
            activityLevel: profile?.activityLevelValue ?? .moderate,
            nutritionContext: OnboardingWorkoutPlanUserContext.nutritionContext(from: profile),
            memoryContext: workoutPlanMemoryContext(),
            activeWorkoutGoalContext: OnboardingWorkoutPlanUserContext.activeGoalContext(from: activeWorkoutGoalsForPlanSetup())
        )
    }
    private var shouldShowAccountSignInCard: Bool {
        guard accountSessionService != nil else { return false }
        return accountSessionService?.isAuthenticated != true
    }

    private var shouldShowProUpsellCard: Bool {
        monetizationService?.canAccessAIFeatures == false
    }

    var body: some View {
        let currentProfile = profile

        NavigationStack {
            destinationContent
            .refreshable {
                refreshProfileMetrics()
                fetchCustomRemindersCount()
            }
            .navigationTitle(mode.title)
            .toolbarTitleDisplayMode(.inlineLarge)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", systemImage: "checkmark") { dismiss() }
                        .accessibilityIdentifier(mode == .account ? "accountDone" : "profileDestinationDone")
                }
            }
            .sheet(isPresented: $showPlanSheet) {
                if let currentProfile {
                    PlanAdjustmentSheet(profile: currentProfile)
                        .traiSheetBranding()
                }
            }
            .sheet(isPresented: $showSettingsSheet) {
                if let currentProfile {
                    NavigationStack {
                        SettingsView(profile: currentProfile)
                    }
                    .traiSheetBranding()
                }
            }
            .sheet(isPresented: $showPlanSetupSheet, onDismiss: resetStandardWorkoutPlanSetupState) {
                WorkoutPlanSetupChoiceFlow(
                    draft: $standardWorkoutPlanDraft,
                    generatedPlanForReview: $standardGeneratedWorkoutPlan,
                    generatedPlanGoalsForReview: $standardGeneratedWorkoutGoals,
                    context: standardWorkoutPlanSetupContext,
                    existingWorkoutGoals: activeWorkoutGoalsForPlanSetup(),
                    aiService: standardWorkoutPlanAIService,
                    canAccessAIFeatures: canAccessAIFeatures,
                    onComplete: saveStandardWorkoutPlan,
                    onBack: { showPlanSetupSheet = false },
                    onSkip: { showPlanSetupSheet = false }
                )
                    .traiSheetBranding()
            }
            .sheet(isPresented: $showPlanEditSheet) {
                if let plan = currentProfile?.workoutPlan {
                    WorkoutPlanEditSheet(currentPlan: plan)
                        .traiSheetBranding()
                }
            }
            .sheet(item: $presentedAccountSetupContext) { context in
                AccountSetupView(context: context, showsDismissButton: context != .secureExistingData)
                    .traiSheetBranding()
            }
            .alert(item: $workoutPlanSaveError) { error in
                Alert(
                    title: Text("Workout Plan Not Saved"),
                    message: Text(error.message),
                    dismissButton: .default(Text("OK"))
                )
            }
            .onAppear {
                activateDestination(trackOpen: true)
            }
            .onChange(of: activeWorkouts.count) {
                markProfileMetricsRefreshNeeded(delayMilliseconds: 180)
            }
            .proUpsellPresenter()
            .onChange(of: showPlanSheet) { _, isShowing in
                if !isShowing {
                    markProfileMetricsRefreshNeeded(delayMilliseconds: 180)
                }
            }
            .onChange(of: showPlanSetupSheet) { _, isShowing in
                if isShowing {
                    standardWorkoutPlanSetupBase = profile?.workoutPlan
                } else {
                    markProfileMetricsRefreshNeeded(delayMilliseconds: 180)
                }
            }
            .onChange(of: showPlanEditSheet) { _, isShowing in
                if !isShowing {
                    markProfileMetricsRefreshNeeded(delayMilliseconds: 180)
                }
            }
            .onChange(of: showSettingsSheet) { _, isShowing in
                if !isShowing {
                    markRemindersCountRefreshNeeded(delayMilliseconds: 160)
                    markProfileMetricsRefreshNeeded(delayMilliseconds: 220)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .workoutCompleted)) { _ in
                markProfileMetricsRefreshNeeded(delayMilliseconds: 220)
            }
            .onReceive(NotificationCenter.default.publisher(for: .weightLogged)) { _ in
                markProfileMetricsRefreshNeeded(delayMilliseconds: 140)
            }
            .onReceive(NotificationCenter.default.publisher(for: .coachMemoriesChanged)) { _ in
                markProfileMetricsRefreshNeeded(delayMilliseconds: 60)
            }
            .onDisappear {
                isProfileTabVisible = false
                tabActivationPolicy.deactivate()
                profileMetricsRefreshTask?.cancel()
                remindersCountTask?.cancel()
            }
        }
        .traiBackground()
        .overlay(alignment: .topLeading) {
            Text("ready")
                .font(.system(size: 1))
                .frame(width: 1, height: 1)
                .opacity(0.01)
                .accessibilityElement(children: .ignore)
                .accessibilityIdentifier("profileRootReady")
        }
        .overlay(alignment: .topLeading) {
            Text(profileLatencyProbeLabel)
                .font(.system(size: 1))
                .frame(width: 1, height: 1)
                .opacity(0.01)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(profileLatencyProbeLabel)
                .accessibilityIdentifier("profileLatencyProbe")
        }
    }

    @ViewBuilder
    private var destinationContent: some View {
        if let profile {
            switch mode {
            case .account:
                accountList(profile)
            case .nutritionPlan:
                ScrollView {
                    planCard(profile).padding(16)
                }
            case .workoutPlan:
                ScrollView {
                    workoutPlanCard(profile).padding(16)
                }
            }
        } else {
            ContentUnavailableView("Account unavailable", systemImage: "person.crop.circle", description: Text("Your profile will appear when setup is complete."))
        }
    }

    private func accountList(_ profile: UserProfile) -> some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text(profile.name.isEmpty ? "Your account" : profile.name)
                        .font(.headline)
                    Text(profile.goal.displayName)
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
                Button { showSettingsSheet = true } label: {
                    HStack {
                        Label("Personal details & settings", systemImage: "person.crop.circle")
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    }
                }
                .accessibilityIdentifier("accountSettings")
                NavigationLink {
                    ReminderSettingsView(profile: profile)
                } label: {
                    Label("Reminders", systemImage: "bell")
                }
            }
            Section("Your Trai") {
                NavigationLink {
                    AllMemoriesView()
                } label: {
                    Label("Memories", systemImage: "circle.hexagongrid")
                }
                NavigationLink {
                    AllChatSessionsView { sessionId in
                        currentChatSessionIdString = sessionId.uuidString
                        pendingOpenChatSessionIdString = sessionId.uuidString
                        openTraiTab()
                    }
                } label: {
                    Label("Saved conversations", systemImage: "bubble.left.and.bubble.right")
                }
            }
            Section("Account & subscription") {
                if shouldShowAccountSignInCard {
                    Button {
                        presentedAccountSetupContext = .secureExistingData
                    } label: {
                        Label("Sign in with Apple", systemImage: "person.crop.circle.badge.plus")
                    }
                } else if let accountSessionService {
                    LabeledContent("Signed in", value: accountSessionService.currentUserDisplayName)
                }
                LabeledContent("Plan", value: canAccessAIFeatures ? "Trai Pro" : "Free")
                if shouldShowProUpsellCard {
                    Button("Explore Trai Pro", systemImage: "sparkles") {
                        proUpsellCoordinator?.present(source: .settings)
                    }
                }
                if let url = billingService?.manageSubscriptionsURL {
                    Link(destination: url) {
                        Label("Manage subscription", systemImage: "creditcard")
                    }
                }
            }
        }
        .tint(.primary)
        .accessibilityIdentifier("accountRootReady")
    }

    func openTraiTab() {
        dismiss()
        if let onSelectTab {
            onSelectTab(.trai)
        } else {
            appTabSelection.wrappedValue = .trai
        }
    }

    private var profileLatencyProbeLabel: String {
        guard AppLaunchArguments.shouldEnableLatencyProbe else { return "disabled" }
        return latencyProbeEntries.isEmpty ? "pending" : latencyProbeEntries.joined(separator: " | ")
    }

    private func recordProfileLatencyProbe(
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

    private func fetchCustomRemindersCount() {
        let startedAt = LatencyProbe.timerStart()
        let descriptor = FetchDescriptor<CustomReminder>(
            predicate: #Predicate { $0.isEnabled }
        )
        customRemindersCount = (try? modelContext.fetchCount(descriptor)) ?? 0
        cachedOwnerProfileID = currentProfileID
        cachedCustomRemindersCount = customRemindersCount
        remindersCountLastRefreshAt = Date().timeIntervalSince1970
        hasPendingRemindersCountRefresh = false
        recordProfileLatencyProbe(
            "fetchCustomRemindersCount",
            startedAt: startedAt,
            counts: [
                "enabledCustomReminders": customRemindersCount
            ]
        )
    }

    private func activateDestination(trackOpen: Bool) {
        let wasVisible = isProfileTabVisible
        if tabActivationPolicy.activeSince == nil || !wasVisible {
            tabActivationPolicy = TabActivationPolicy(
                minimumDwellMilliseconds: Self.profileHeavyRefreshMinimumDwellMilliseconds
            )
            tabActivationPolicy.activate()
        }
        isProfileTabVisible = true
        let hydratedFromCache = hydrateCachedProfileMetricsIfNeeded()
        if hydratedFromCache {
            // Always reconcile hydrated cache with source-of-truth shortly after first paint.
            markProfileMetricsRefreshNeeded(delayMilliseconds: 320)
            markRemindersCountRefreshNeeded(delayMilliseconds: 280)
        }
        schedulePendingRefreshesIfNeeded()
        if trackOpen && !wasVisible {
            trackOpenProfileIfNeeded()
        }
    }

    private func scheduleRemindersCountRefresh(delayMilliseconds: Int = 300) {
        remindersCountTask?.cancel()
        let activationToken = tabActivationPolicy.activationToken
        let effectiveDelayMilliseconds = tabActivationPolicy.effectiveDelayMilliseconds(
            requested: delayMilliseconds
        )
        remindersCountTask = Task(priority: .utility) {
            if effectiveDelayMilliseconds > 0 {
                try? await Task.sleep(for: .milliseconds(effectiveDelayMilliseconds))
            }
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard tabActivationPolicy.shouldRunHeavyRefresh(for: activationToken) else { return }
                guard isProfileTabActive, hasPendingRemindersCountRefresh else { return }
                fetchCustomRemindersCount()
            }
        }
    }

    private func trackOpenProfileIfNeeded() {
        let now = Date()
        if let lastOpenTrackedAt, now.timeIntervalSince(lastOpenTrackedAt) < 8 * 60 {
            return
        }
        lastOpenTrackedAt = now
        BehaviorTracker(modelContext: modelContext).record(
            actionKey: BehaviorActionKey.openProfile,
            domain: .profile,
            surface: .profile,
            outcome: .opened,
            metadata: ["source": "profile_tab"],
            saveImmediately: false
        )
    }

    private func scheduleProfileMetricsRefresh(delayMilliseconds: Int = 300) {
        profileMetricsRefreshTask?.cancel()
        let activationToken = tabActivationPolicy.activationToken
        let effectiveDelayMilliseconds = tabActivationPolicy.effectiveDelayMilliseconds(
            requested: delayMilliseconds
        )
        profileMetricsRefreshTask = Task(priority: .utility) {
            if effectiveDelayMilliseconds > 0 {
                try? await Task.sleep(for: .milliseconds(effectiveDelayMilliseconds))
            }
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard tabActivationPolicy.shouldRunHeavyRefresh(for: activationToken) else { return }
                guard isProfileTabActive, hasPendingProfileMetricsRefresh else { return }
                guard !isActiveWorkoutInProgress else { return }
                refreshProfileMetrics()
            }
        }
    }

    private func refreshProfileMetrics() {
        let startedAt = LatencyProbe.timerStart()
        guard let profile else {
            latestWeightKg = nil
            activeMemoriesCount = 0
            chatConversationCount = 0
            cachedOwnerProfileID = ""
            cachedLatestWeightKg = -1
            cachedActiveMemoriesCount = 0
            cachedChatConversationCount = 0
            profileMetricsLastRefreshAt = Date().timeIntervalSince1970
            hasPendingProfileMetricsRefresh = false
            return
        }

        var weightDescriptor = FetchDescriptor<WeightEntry>(
            sortBy: [SortDescriptor(\WeightEntry.loggedAt, order: .reverse)]
        )
        weightDescriptor.fetchLimit = 1
        latestWeightKg = ((try? modelContext.fetch(weightDescriptor))?.first)?.weightKg

        let activeMemoriesDescriptor = FetchDescriptor<CoachMemory>(
            predicate: #Predicate<CoachMemory> { $0.isActive }
        )
        activeMemoriesCount = (try? modelContext.fetchCount(activeMemoriesDescriptor)) ?? 0

        let now = Date()
        let chatCutoff = Calendar.current.date(
            byAdding: .day,
            value: -Self.profileChatWindowDays,
            to: now
        ) ?? .distantPast
        let chatDescriptor = FetchDescriptor<ChatMessage>(
            predicate: #Predicate<ChatMessage> { message in
                message.timestamp >= chatCutoff && message.sessionId != nil
            }
        )
        let messages = (try? modelContext.fetch(chatDescriptor)) ?? []
        chatConversationCount = Set(messages.compactMap(\.sessionId)).count
        cachedOwnerProfileID = profile.id.uuidString
        cachedLatestWeightKg = latestWeightKg ?? -1
        cachedActiveMemoriesCount = activeMemoriesCount
        cachedChatConversationCount = chatConversationCount
        profileMetricsLastRefreshAt = now.timeIntervalSince1970
        hasPendingProfileMetricsRefresh = false
        recordProfileLatencyProbe(
            "refreshProfileMetrics",
            startedAt: startedAt,
            counts: [
                "activeMemories": activeMemoriesCount,
                "chatMessages": messages.count,
                "chatSessions": chatConversationCount,
                "hasWeight": latestWeightKg == nil ? 0 : 1
            ]
        )
    }

    private func markProfileMetricsRefreshNeeded(delayMilliseconds: Int = 220) {
        hasPendingProfileMetricsRefresh = true
        guard isProfileTabActive else { return }
        scheduleProfileMetricsRefresh(delayMilliseconds: delayMilliseconds)
    }

    private func markRemindersCountRefreshNeeded(delayMilliseconds: Int = 220) {
        hasPendingRemindersCountRefresh = true
        guard isProfileTabActive else { return }
        scheduleRemindersCountRefresh(delayMilliseconds: delayMilliseconds)
    }

    private func schedulePendingRefreshesIfNeeded() {
        guard isProfileTabActive else { return }
        var scheduledHeavyRefresh = false

        let shouldRefreshProfileMetrics = hasPendingProfileMetricsRefresh || isProfileMetricsRefreshStale
        if shouldRefreshProfileMetrics {
            hasPendingProfileMetricsRefresh = true
            scheduleProfileMetricsRefresh(
                delayMilliseconds: hasExecutedInitialHeavyRefresh
                    ? Self.profileReactivationHeavyDelayMilliseconds
                    : Self.profileHeavyMetricsDelayMilliseconds
            )
            scheduledHeavyRefresh = true
        }

        let shouldRefreshRemindersCount = hasPendingRemindersCountRefresh || isRemindersCountRefreshStale
        if shouldRefreshRemindersCount {
            hasPendingRemindersCountRefresh = true
            scheduleRemindersCountRefresh(
                delayMilliseconds: hasExecutedInitialHeavyRefresh
                    ? Self.profileReactivationHeavyDelayMilliseconds
                    : Self.profileHeavyMetricsDelayMilliseconds
            )
            scheduledHeavyRefresh = true
        }

        if scheduledHeavyRefresh {
            hasExecutedInitialHeavyRefresh = true
        }
    }

    private var isProfileMetricsRefreshStale: Bool {
        guard profileMetricsLastRefreshAt > 0 else { return true }
        return Date().timeIntervalSince1970 - profileMetricsLastRefreshAt > Self.profileMetricsStaleAfterSeconds
    }

    private var isRemindersCountRefreshStale: Bool {
        guard remindersCountLastRefreshAt > 0 else { return true }
        return Date().timeIntervalSince1970 - remindersCountLastRefreshAt > Self.profileRemindersStaleAfterSeconds
    }

    @discardableResult
    private func hydrateCachedProfileMetricsIfNeeded() -> Bool {
        guard !currentProfileID.isEmpty else { return false }
        guard cachedOwnerProfileID == currentProfileID else { return false }

        var hydrated = false
        if latestWeightKg == nil, cachedLatestWeightKg >= 0 {
            latestWeightKg = cachedLatestWeightKg
            hydrated = true
        }
        if activeMemoriesCount == 0, cachedActiveMemoriesCount > 0 {
            activeMemoriesCount = cachedActiveMemoriesCount
            hydrated = true
        }
        if chatConversationCount == 0, cachedChatConversationCount > 0 {
            chatConversationCount = cachedChatConversationCount
            hydrated = true
        }
        if customRemindersCount == 0, cachedCustomRemindersCount > 0 {
            customRemindersCount = cachedCustomRemindersCount
            hydrated = true
        }
        return hydrated
    }

    func saveStandardWorkoutPlan(
        _ plan: WorkoutPlan,
        generatedGoals: [WorkoutGoal],
        mode: WorkoutPlanSetupMode,
        draftSnapshot: OnboardingWorkoutPlanDraft
    ) {
        guard let profile else { return }
        guard WorkoutPlanEditSheet.canSaveSetupPlan(
            savedPlan: profile.workoutPlan,
            setupBase: standardWorkoutPlanSetupBase
        ) else {
            workoutPlanSaveError = WorkoutPlanSaveError(
                message: "Your workout plan changed while setup was open. Reopen the latest plan before saving changes."
            )
            HapticManager.error()
            return
        }
        let hadExistingPlan = profile.workoutPlan != nil
        let durablePlan = plan.normalizedForDurableBlocks()

        WorkoutPlanHistoryService.archiveCurrentPlanIfExists(
            profile: profile,
            reason: .chatAdjustment,
            modelContext: modelContext,
            replacingWith: durablePlan
        )

        profile.workoutPlan = durablePlan
        draftSnapshot.applyPreferences(to: profile, generatedPlan: durablePlan)
        refreshExistingGeneratedPlanAdherenceGoals(for: durablePlan)

        if mode == .proAI {
            insertGeneratedWorkoutGoals(generatedGoals, for: durablePlan)
        }

        if !hadExistingPlan {
            WorkoutPlanHistoryService.archivePlan(
                durablePlan,
                profile: profile,
                reason: .chatCreate,
                modelContext: modelContext
            )
        }

        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            workoutPlanSaveError = WorkoutPlanSaveError(message: error.localizedDescription)
            HapticManager.error()
            return
        }
        resetStandardWorkoutPlanSetupState()
        showPlanSetupSheet = false
        WidgetDataProvider.shared.scheduleRefresh()
        HapticManager.success()
    }

    private func workoutPlanMemoryContext() -> [String] {
        let descriptor = FetchDescriptor<CoachMemory>(
            predicate: #Predicate<CoachMemory> { memory in
                memory.isActive
            },
            sortBy: [
                SortDescriptor(\CoachMemory.importance, order: .reverse),
                SortDescriptor(\CoachMemory.createdAt, order: .reverse)
            ]
        )
        let memories = (try? modelContext.fetch(descriptor)) ?? []
        return memories
            .filter {
                $0.topic == .workout || $0.topic == .general || $0.category == .goal || $0.category == .context || $0.category == .restriction
            }
            .prefix(8)
            .map(\.promptFormat)
    }

    private func activeWorkoutGoalsForPlanSetup() -> [WorkoutGoal] {
        let descriptor = FetchDescriptor<WorkoutGoal>(
            predicate: #Predicate<WorkoutGoal> { goal in
                goal.statusRaw == "active"
            },
            sortBy: [SortDescriptor(\WorkoutGoal.updatedAt, order: .reverse)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private func insertGeneratedWorkoutGoals(_ goals: [WorkoutGoal], for plan: WorkoutPlan) {
        for goal in WorkoutGoal.generatedGoalsToInsert(
            goals,
            existingGoals: activeWorkoutGoalsForPlanSetup(),
            for: plan
        ) {
            modelContext.insert(goal)
        }
    }

    private func refreshExistingGeneratedPlanAdherenceGoals(for plan: WorkoutPlan) {
        WorkoutGoal.refreshGeneratedPlanAdherenceGoals(activeWorkoutGoalsForPlanSetup(), for: plan)
    }

    private func resetStandardWorkoutPlanSetupState() {
        standardWorkoutPlanDraft = OnboardingWorkoutPlanDraft()
        standardGeneratedWorkoutPlan = nil
        standardGeneratedWorkoutGoals = []
        standardWorkoutPlanSetupBase = nil
    }
}

private struct WorkoutPlanSaveError: Identifiable {
    let id = UUID()
    let message: String
}

#Preview {
    ProfileView()
        .modelContainer(for: [
            UserProfile.self,
            WorkoutSession.self,
            WeightEntry.self
        ], inMemory: true)
}
