//
//  ProfileView.swift
//  Trai
//

import SwiftUI
import SwiftData

struct ProfileView: View {
    let onSelectTab: ((AppTab) -> Void)?
    @Query var profiles: [UserProfile]
    @Query private var activeWorkouts: [LiveWorkout]
    @Query private var todaysWorkouts: [WorkoutSession]

    @Environment(\.appTabSelection) private var appTabSelection
    @Environment(\.modelContext) var modelContext
    @State var showPlanSheet = false
    @State var showSettingsSheet = false
    @State var customRemindersCount = 0

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

    // For navigating to Trai tab with plan review
    @AppStorage("pendingPlanReviewRequest") var pendingPlanReviewRequest = false
    @AppStorage("pendingWorkoutPlanReviewRequest") var pendingWorkoutPlanReviewRequest = false
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

    init(onSelectTab: ((AppTab) -> Void)? = nil) {
        self.onSelectTab = onSelectTab
        let now = Date()
        let startOfToday = Calendar.current.startOfDay(for: now)

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

        var todaysWorkoutDescriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate<WorkoutSession> { workout in
                workout.loggedAt >= startOfToday
            },
            sortBy: [SortDescriptor(\WorkoutSession.loggedAt, order: .reverse)]
        )
        todaysWorkoutDescriptor.fetchLimit = 1
        _todaysWorkouts = Query(todaysWorkoutDescriptor)
    }

    var profile: UserProfile? { profiles.first }

    var hasWorkoutToday: Bool {
        !todaysWorkouts.isEmpty
    }

    private var isProfileTabActive: Bool {
        isProfileTabVisible && appTabSelection.wrappedValue == .profile
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

    var body: some View {
        let currentProfile = profile

        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if let currentProfile {
                        headerCard(currentProfile)
                        planCard(currentProfile)
                        workoutPlanCard(currentProfile)
                        memoriesCard()
                        chatHistoryCard()
                        exercisesCard()
                        remindersCard(currentProfile, customRemindersCount: customRemindersCount)
                    }
                }
                .id(currentProfile?.id)
                .padding()
            }
            .refreshable {
                refreshProfileMetrics()
                fetchCustomRemindersCount()
            }
            .navigationTitle("Profile")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showSettingsSheet = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .sheet(isPresented: $showPlanSheet) {
                if let currentProfile {
                    PlanAdjustmentSheet(profile: currentProfile)
                }
            }
            .sheet(isPresented: $showSettingsSheet) {
                if let currentProfile {
                    NavigationStack {
                        SettingsView(profile: currentProfile)
                    }
                }
            }
            .sheet(isPresented: $showPlanSetupSheet) {
                WorkoutPlanChatFlow()
            }
            .sheet(isPresented: $showPlanEditSheet) {
                if let plan = currentProfile?.workoutPlan {
                    WorkoutPlanEditSheet(currentPlan: plan)
                }
            }
            .onAppear {
                handleProfileTabSelectionChange(to: appTabSelection.wrappedValue, trackOpen: true)
            }
            .onChange(of: appTabSelection.wrappedValue) { _, selectedTab in
                handleProfileTabSelectionChange(to: selectedTab, trackOpen: true)
            }
            .onChange(of: activeWorkouts.count) {
                markProfileMetricsRefreshNeeded(delayMilliseconds: 180)
            }
            .onChange(of: showPlanSheet) { _, isShowing in
                if !isShowing {
                    markProfileMetricsRefreshNeeded(delayMilliseconds: 180)
                }
            }
            .onChange(of: showPlanSetupSheet) { _, isShowing in
                if !isShowing {
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

    private func handleProfileTabSelectionChange(to selectedTab: AppTab, trackOpen: Bool) {
        let shouldBeActive = selectedTab == .profile

        guard shouldBeActive else {
            guard isProfileTabVisible else { return }
            isProfileTabVisible = false
            tabActivationPolicy.deactivate()
            profileMetricsRefreshTask?.cancel()
            remindersCountTask?.cancel()
            return
        }

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

    // MARK: - Header Card

    @ViewBuilder
    private func headerCard(_ profile: UserProfile) -> some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [.accentColor, .accentColor.opacity(0.5)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 3
                    )
                    .frame(width: 90, height: 90)

                Circle()
                    .fill(Color.accentColor.opacity(0.15))
                    .frame(width: 80, height: 80)
                    .overlay {
                        Text(profile.name.prefix(1).uppercased())
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.accentColor)
                    }
            }

            VStack(spacing: 4) {
                Text(profile.name.isEmpty ? "Welcome" : profile.name)
                    .font(.title2)
                    .fontWeight(.bold)

                HStack(spacing: 6) {
                    Image(systemName: profile.goal.iconName)
                        .font(.caption)
                    Text(profile.goal.displayName)
                        .font(.subheadline)
                }
                .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                Circle()
                    .fill(hasWorkoutToday ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)

                Text(hasWorkoutToday ? "Training Day" : "Rest Day")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill((hasWorkoutToday ? Color.green : Color.orange).opacity(0.15))
            )
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .traiCard(cornerRadius: 24, contentPadding: 0)
    }

}

#Preview {
    ProfileView()
        .modelContainer(for: [
            UserProfile.self,
            WorkoutSession.self,
            WeightEntry.self
        ], inMemory: true)
}
