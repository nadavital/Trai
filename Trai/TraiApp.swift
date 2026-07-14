//
//  TraiApp.swift
//  Trai
//
//  Created by Nadav Avital on 12/25/25.
//

import SwiftUI
import SwiftData
import WidgetKit
import BackgroundTasks
import UIKit

@main
struct TraiApp: App {
    /// Shared ModelContainer for App Intents and other extension access
    @MainActor static var sharedModelContainer: ModelContainer?
    @UIApplicationDelegateAdaptor(HomeScreenQuickActionApplicationDelegate.self)
    private var quickActionDelegate

    let isUITesting: Bool
    let isRunningTests: Bool
    let modelContainer: ModelContainer
    let modelContainerLaunchError: String?
    @State private var notificationService: NotificationService
    @State private var healthKitService: HealthKitService
    @State private var appAccountService: AppAccountService
    @State private var accountSessionService: AccountSessionService
    @State private var monetizationService: MonetizationService
    @State private var billingService: BillingService
    @State private var proUpsellCoordinator: ProUpsellCoordinator
    @State private var notificationDelegate: NotificationDelegate?
    @State private var showRemindersFromNotification = false
    @State private var deepLinkDestination: AppRoute?
    @State private var lastHealthKitWorkoutSyncDate: Date?
    @AppStorage("healthkitRecentWorkoutSyncTimestamp")
    private var persistedHealthKitWorkoutSyncTimestamp: Double = 0
    @AppStorage("foodMemoryLaunchMaintenanceTimestamp")
    private var persistedFoodMemoryLaunchMaintenanceTimestamp: Double = 0
    @AppStorage("reminderScheduleRefreshToken")
    private var reminderScheduleRefreshToken: String = ""
    @State private var startupCoordinator = AppStartupCoordinator()
    @State private var deferredHealthKitSyncTask: Task<Void, Never>?
    @State private var reminderScheduleRefreshTask: Task<Void, Never>?
    #if DEBUG
    @State private var hasRunLaunchReplayEvaluation = false
    #endif
    @Environment(\.scenePhase) private var scenePhase
    private let startupTaskDeferral: Duration = .seconds(2)
    private let startupMigrationDeferral: Duration = .seconds(90)
    private let foodMemoryMaintenanceDeferral: Duration = .seconds(30)
    private let foregroundHealthKitSyncDelay: Duration = .seconds(35)
    private let reminderBackgroundRefreshInterval: TimeInterval = 12 * 60 * 60
    private let foodMemoryLaunchMaintenanceInterval: TimeInterval = 12 * 60 * 60
    private let minimumHealthKitSyncInterval: TimeInterval = 6 * 60 * 60
    private let initialHealthKitSyncLookbackDays = 30
    private let incrementalHealthKitSyncLookbackDays = 10
    private let brandAccent = Color("AccentColor")
    private static let swiftDataStoreFilename = "default.store"
    private static let reminderBackgroundRefreshTaskIdentifier = "Nadav.Trai.reminder-refresh"
    private static let appSchema = Schema([
        UserProfile.self,
        FoodEntry.self,
        Exercise.self,
        WorkoutSession.self,
        WeightEntry.self,
        ChatMessage.self,
        LiveWorkout.self,
        LiveWorkoutEntry.self,
        ExerciseHistory.self,
        CoachMemory.self,
        CoachSignal.self,
        NutritionPlanVersion.self,
        WorkoutPlanVersion.self,
        WorkoutGoal.self,
        CustomReminder.self,
        ReminderCompletion.self,
        SuggestionUsage.self,
        BehaviorEvent.self,
        FoodMemory.self,
        FoodSuggestionFeedback.self
    ])

    init() {
        let isUITesting = AppLaunchArguments.isUITesting
        let isRunningTests = AppLaunchArguments.isRunningTests
        let shouldUseInMemoryStore = AppLaunchArguments.shouldUseInMemoryStore
        let launchPendingRoute = AppLaunchArguments.launchPendingRoute

        let notificationService = NotificationService()
        let healthKitService = HealthKitService()
        let appAccountService = AppAccountService.shared
        let accountSessionService = AccountSessionService.shared
        let monetizationService = MonetizationService.shared
        let billingService = BillingService.shared
        let proUpsellCoordinator = ProUpsellCoordinator.shared
        _notificationService = State(initialValue: notificationService)
        _healthKitService = State(initialValue: healthKitService)
        _appAccountService = State(initialValue: appAccountService)
        _accountSessionService = State(initialValue: accountSessionService)
        _monetizationService = State(initialValue: monetizationService)
        _billingService = State(initialValue: billingService)
        _proUpsellCoordinator = State(initialValue: proUpsellCoordinator)

        self.isUITesting = isUITesting
        self.isRunningTests = isRunningTests
        _deepLinkDestination = State(initialValue: launchPendingRoute)

        #if DEBUG
        if isUITesting {
            if AppLaunchArguments.shouldRunOnboardingFlowUITest {
                UserDefaults.standard.set(false, forKey: AppLaunchArguments.onboardingCompletedCacheKey)
                UserDefaults.standard.removeObject(forKey: "onboardingDraft")
            }
            if AppLaunchArguments.shouldUseLiveAIBackendForUITest {
                appAccountService.setDebugBackendEnvironment(.localDevelopment)
            }
            if AppLaunchArguments.shouldUseFreePlanForUITest {
                monetizationService.setDebugPlan(.free)
                if AppLaunchArguments.shouldUseAuthenticatedFreePlanForUITest {
                    accountSessionService.setDebugAuthenticatedSession()
                } else {
                    accountSessionService.signOut()
                }
            } else {
                monetizationService.setDebugPlan(AppLaunchArguments.shouldUseProPlanForUITest ? .pro : .developer)
                if !AppLaunchArguments.shouldUseLiveAIBackendForUITest {
                    accountSessionService.setDebugAuthenticatedSession()
                }
            }
            monetizationService.resetQuotaForDebug()
        }

        if isUITesting && AppLaunchArguments.shouldUseLiveAIBackendForUITest {
            Task { @MainActor in
                await Self.prepareLiveAIBackendSessionForUITest(
                    appAccountService: appAccountService,
                    accountSessionService: accountSessionService
                )
            }
        }
        #endif

        do {
            Self.primeSharedStoreDirectoryIfNeeded(usesInMemoryStore: shouldUseInMemoryStore)
            Self.migrateLegacyStoreToSharedContainerIfNeeded(usesInMemoryStore: shouldUseInMemoryStore)

            let schema = Self.appSchema

            let modelConfiguration: ModelConfiguration
            if shouldUseInMemoryStore {
                modelConfiguration = ModelConfiguration(
                    schema: schema,
                    isStoredInMemoryOnly: true,
                    cloudKitDatabase: .none
                )
            } else if Self.hasAccessibleSharedGroupContainer {
                modelConfiguration = ModelConfiguration(
                    schema: schema,
                    isStoredInMemoryOnly: false,
                    groupContainer: .identifier(SharedStorageKeys.AppGroup.suiteName),
                    cloudKitDatabase: .automatic
                )
            } else {
                // Keep simulator/test persistence working even when app-group
                // entitlements are unavailable in the current build environment.
                modelConfiguration = ModelConfiguration(
                    schema: schema,
                    isStoredInMemoryOnly: false,
                    cloudKitDatabase: .none
                )
            }

            modelContainer = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
            modelContainerLaunchError = nil

            notificationService.ensureNotificationSetup()
            let delegate = NotificationDelegate(
                modelContainer: modelContainer,
                notificationService: notificationService
            )
            _notificationDelegate = State(initialValue: delegate)

            // Set shared container for App Intents access
            let container = modelContainer
            Task { @MainActor in
                TraiApp.sharedModelContainer = container

                if #available(iOS 27.0, *) {
                    TraiMetricReporter.shared.start()
                }

                if isUITesting && !AppLaunchArguments.shouldRunOnboardingFlowUITest {
                    seedUITestProfileIfNeeded(modelContainer: container)
                    if AppLaunchArguments.shouldUseAppStoreScreenshotSeed {
                        seedAppStoreScreenshotDataIfNeeded(modelContainer: container)
                    }
                    if AppLaunchArguments.shouldSeedGoalPreviewData {
                        seedGoalPreviewDataIfNeeded(modelContainer: container)
                    }
                }

                if isRunningTests {
                    try? await Task.sleep(for: .milliseconds(250))
                    guard !Task.isCancelled else { return }
                }

                ExerciseLibrarySeeder.ensureDefaults(in: container.mainContext)
                if AppLaunchArguments.shouldSeedLiveWorkoutPerfData {
                    seedLiveWorkoutPerformanceDataIfNeeded(modelContainer: container)
                } else if !isRunningTests {
                    purgeLiveWorkoutPerformanceSeedDataIfPresent(modelContainer: container)
                }
            }
        } catch {
            modelContainerLaunchError = error.localizedDescription
            let recoveryConfiguration = ModelConfiguration(
                schema: Self.appSchema,
                isStoredInMemoryOnly: true,
                cloudKitDatabase: .none
            )
            do {
                modelContainer = try ModelContainer(
                    for: Self.appSchema,
                    configurations: [recoveryConfiguration]
                )
            } catch {
                preconditionFailure("Failed to create recovery ModelContainer: \(error)")
            }
        }
    }

    #if DEBUG
    @MainActor
    private static func prepareLiveAIBackendSessionForUITest(
        appAccountService: AppAccountService,
        accountSessionService: AccountSessionService
    ) async {
        appAccountService.setDebugBackendEnvironment(.localDevelopment)

        do {
            let bootstrap = try await TraiBackendClient.shared.exchangeAppleIdentity(
                AppleIdentityExchangeRequest(
                    installationID: appAccountService.installationID,
                    appAccountToken: appAccountService.appAccountToken,
                    identityToken: "ui-test-live-ai-token",
                    authorizationCode: "ui-test-live-ai-code",
                    rawNonce: nil,
                    appleUserID: "ui-test-live-ai-\(appAccountService.installationID)",
                    email: "ui-live-ai@trai.local",
                    displayName: "Live AI Tester"
                ),
                environment: .localDevelopment
            )
            accountSessionService.setDebugAuthenticatedBootstrap(bootstrap)

            try await applyLocalDeveloperSubscriptionOverrideForUITest(userID: bootstrap.session.userID)
            await accountSessionService.refreshAccountFromBackend()
        } catch {
            print("⚠️ Failed to prepare live AI backend UI-test session: \(error.localizedDescription)")
        }
    }

    private static func applyLocalDeveloperSubscriptionOverrideForUITest(userID: String) async throws {
        guard let baseURL = TraiBackendClient.shared.baseURL(for: .localDevelopment) else {
            throw BackendClientError.environmentNotConfigured
        }

        var request = URLRequest(url: baseURL.appending(path: "/v1/admin/subscription-override"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer local-dev-admin", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "userID": userID,
            "plan": "developer",
            "status": "active",
            "source": "developer",
            "reason": "local simulator live AI testing",
            "createdBy": "trai-ios-ui-test"
        ])

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw BackendClientError.invalidResponse
        }
    }
    #endif

    var body: some Scene {
        WindowGroup {
            if let modelContainerLaunchError {
                ModelStoreRecoveryView(errorDescription: modelContainerLaunchError)
                    .tint(brandAccent)
            } else if isRunningTests {
                ContentView(deepLinkDestination: $deepLinkDestination)
                    .tint(brandAccent)
                    .accentColor(brandAccent)
                    .environment(notificationService)
                    .environment(appAccountService)
                    .environment(accountSessionService)
                    .environment(monetizationService)
                    .environment(billingService)
                    .environment(proUpsellCoordinator)
                    .environment(\.showRemindersFromNotification, $showRemindersFromNotification)
                    .proUpsellPresenter()
                    .onOpenURL { url in
                        handleDeepLink(url)
                    }
            } else {
                ContentView(deepLinkDestination: $deepLinkDestination)
                    .tint(brandAccent)
                    .accentColor(brandAccent)
                    .environment(notificationService)
                    .environment(healthKitService)
                    .environment(appAccountService)
                    .environment(accountSessionService)
                    .environment(monetizationService)
                    .environment(billingService)
                    .environment(proUpsellCoordinator)
                    .environment(\.showRemindersFromNotification, $showRemindersFromNotification)
                    .proUpsellPresenter()
                    .onAppear {
                        PerformanceTrace.event("app_window_appear", category: .launch)
                        billingService.refreshLocalState()
                        monetizationService.refreshStateIfNeeded()
                        setupNotificationDelegate()
                        scheduleDeferredStartupTasksIfNeeded()
                        scheduleStartupMigrationIfNeeded()
                        scheduleReminderScheduleRefreshIfNeeded()
                        scheduleReminderBackgroundRefresh()
                        runLaunchReplayEvaluationIfRequested()
                        scheduleFoodMemoryMaintenanceIfNeeded()
                    }
                    .onOpenURL { url in
                        handleDeepLink(url)
                    }
            }
        }
        .modelContainer(modelContainer)
        .onChange(of: scenePhase) { _, newPhase in
            guard !isRunningTests, modelContainerLaunchError == nil else { return }

            if newPhase == .active {
                FoodMemoryBackgroundService.shared.resumeProcessing(modelContainer: modelContainer)
            } else {
                FoodMemoryBackgroundService.shared.suspendProcessing()
                WidgetDataProvider.shared.cancelScheduledRefresh()
            }

            if newPhase == .background {
                deferredHealthKitSyncTask?.cancel()
                reminderScheduleRefreshTask?.cancel()
                NotificationCenter.default.post(name: .liveWorkoutForceFlush, object: nil)
            } else if newPhase == .active {
                billingService.refreshLocalState()
                monetizationService.refreshStateIfNeeded()
                processPendingWidgetFoodLogs()
                scheduleForegroundHealthKitSyncIfEligible()
                scheduleReminderScheduleRefreshIfNeeded()
                scheduleReminderBackgroundRefresh()
                scheduleFoodMemoryMaintenanceIfNeeded()
            }
        }
        .backgroundTask(.appRefresh(Self.reminderBackgroundRefreshTaskIdentifier)) {
            await handleReminderBackgroundRefresh()
        }
    }

    private func handleDeepLink(_ url: URL) {
        guard let route = AppRoute(url: url) else { return }
        deepLinkDestination = route
    }

    private func setupNotificationDelegate() {
        notificationService.ensureNotificationSetup()

        if notificationDelegate == nil {
            notificationDelegate = NotificationDelegate(
                modelContainer: modelContainer,
                notificationService: notificationService
            )
        }

        notificationDelegate?.onShowReminders = {
            showRemindersFromNotification = true
        }
    }

    #if DEBUG
    @MainActor
    private func runLaunchReplayEvaluationIfRequested() {
        guard AppLaunchArguments.shouldRunFoodRecommendationReplayEvaluation else { return }
        guard !hasRunLaunchReplayEvaluation else { return }
        hasRunLaunchReplayEvaluation = true
        NSLog("Food recommendation replay evaluation launch run started")
        writeLaunchReplayEvaluationReport(
            "Food recommendation replay evaluation\nrunning=\(Date().formatted(date: .abbreviated, time: .standard))"
        )
        let maximumCases = AppLaunchArguments.foodRecommendationReplayMaximumCases ?? 20
        Task { @MainActor in
            do {
                try? await Task.sleep(for: .seconds(1))
                let report = try await FoodRecommendationReplayService().run(
                    maximumCases: maximumCases,
                    modelContext: modelContainer.mainContext
                )
                writeLaunchReplayEvaluationReport(report.summaryText)
                NSLog("Food recommendation replay evaluation launch run completed cases=%d", report.metrics.evaluatedCases)
            } catch {
                let message = "Food recommendation replay evaluation launch run failed: \(error)"
                writeLaunchReplayEvaluationReport(message)
                NSLog("%@", message)
            }
        }
    }

    private func writeLaunchReplayEvaluationReport(_ text: String) {
        guard let cachesDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else { return }
        let reportURL = cachesDirectory.appendingPathComponent("FoodRecommendationReplayEvaluation.txt")
        try? text.write(to: reportURL, atomically: true, encoding: .utf8)
    }
    #else
    private func runLaunchReplayEvaluationIfRequested() {}
    #endif

    @MainActor
    private func scheduleReminderScheduleRefreshIfNeeded(force: Bool = false) {
        reminderScheduleRefreshTask?.cancel()
        reminderScheduleRefreshTask = Task(priority: .utility) { @MainActor in
            await refreshReminderSchedulesIfNeeded(force: force)
        }
    }

    private func scheduleReminderBackgroundRefresh() {
        guard !isRunningTests else { return }

        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.reminderBackgroundRefreshTaskIdentifier)
        let request = BGAppRefreshTaskRequest(identifier: Self.reminderBackgroundRefreshTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: reminderBackgroundRefreshInterval)

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Failed to schedule reminder background refresh: \(error)")
        }
    }

    @MainActor
    private func handleReminderBackgroundRefresh() async {
        guard modelContainerLaunchError == nil else { return }
        await refreshReminderSchedulesIfNeeded(force: true)
        scheduleReminderBackgroundRefresh()
    }

    @MainActor
    private func refreshReminderSchedulesIfNeeded(force: Bool) async {
        let todayToken = NotificationService.occurrenceDateToken(for: Date())
        if !force, reminderScheduleRefreshToken == todayToken {
            return
        }

        await notificationService.updateAuthorizationStatus()
        guard notificationService.isAuthorized else { return }

        var profileDescriptor = FetchDescriptor<UserProfile>()
        profileDescriptor.fetchLimit = 1
        guard let profile = try? modelContainer.mainContext.fetch(profileDescriptor).first else { return }

        let customReminderDescriptor = FetchDescriptor<CustomReminder>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        let customReminders = (try? modelContainer.mainContext.fetch(customReminderDescriptor)) ?? []

        let startOfDay = Calendar.current.startOfDay(for: Date())
        let completionDescriptor = FetchDescriptor<ReminderCompletion>(
            predicate: #Predicate { completion in
                completion.completedAt >= startOfDay
            }
        )
        let completions = (try? modelContainer.mainContext.fetch(completionDescriptor)) ?? []
        let completedTodayReminderIDs = Set(completions.map(\.reminderId))

        if profile.mealRemindersEnabled {
            let enabledMeals = Set(profile.enabledMealReminders.split(separator: ",").map(String.init))
            let mealTimes = MealReminderTime.allMeals.filter { enabledMeals.contains($0.id) }
            await notificationService.scheduleMealReminders(
                times: mealTimes,
                skippingTodayReminderIDs: completedTodayReminderIDs
            )
        } else {
            await notificationService.cancelNotifications(category: .mealReminder)
        }

        if profile.workoutRemindersEnabled {
            let workoutDays = Set(profile.workoutReminderDays.split(separator: ",").compactMap { Int($0) })
            await notificationService.scheduleWorkoutReminders(
                days: workoutDays.sorted(),
                hour: profile.workoutReminderHour,
                minute: profile.workoutReminderMinute,
                skippingTodayReminderIDs: completedTodayReminderIDs
            )
        } else {
            await notificationService.cancelNotifications(category: .workoutReminder)
        }

        if profile.weightReminderEnabled {
            await notificationService.scheduleWeightReminder(
                weekday: profile.weightReminderWeekday,
                hour: profile.weightReminderHour,
                minute: 0,
                skippingTodayReminderIDs: completedTodayReminderIDs
            )
        } else {
            await notificationService.cancelNotifications(category: .weightReminder)
        }

        await notificationService.scheduleAllCustomReminders(
            customReminders,
            skippingTodayReminderIDs: completedTodayReminderIDs
        )
        reminderScheduleRefreshToken = todayToken
        scheduleReminderBackgroundRefresh()
    }

    @MainActor
    private func scheduleDeferredStartupTasksIfNeeded() {
        guard startupCoordinator.claimDeferredStartupWork() else { return }

        Task(priority: .utility) {
            try? await Task.sleep(for: startupTaskDeferral)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                let interval = PerformanceTrace.begin("startup_deferral", category: .launch)
                // Keep non-critical cleanup and widget persistence off the first-frame path.
                if !hasActiveLiveWorkoutInProgress() {
                    LiveActivityManager.shared.cancelAllActivities()
                }
                processPendingWidgetFoodLogs()
                startupCoordinator.markDeferredStartupWorkCompleted()
                PerformanceTrace.event("startup_deferral_completed", category: .launch)
                PerformanceTrace.end("startup_deferral", interval, category: .launch)
            }
        }
    }

    @MainActor
    private func scheduleStartupMigrationIfNeeded() {
        guard startupCoordinator.claimStartupMigration() else { return }

        Task(priority: .utility) {
            // Keep migration work well off the critical startup + early interaction window.
            try? await Task.sleep(for: startupMigrationDeferral)
            guard !Task.isCancelled else { return }
            await runStartupMigrationWhenIdle()
        }
    }

    @MainActor
    private func scheduleFoodMemoryMaintenanceIfNeeded() {
        guard !AppLaunchArguments.shouldRunFoodRecommendationReplayEvaluation else { return }
        guard startupCoordinator.claimFoodMemoryMaintenance() else { return }

        let now = Date()
        if persistedFoodMemoryLaunchMaintenanceTimestamp > 0 {
            let lastRun = Date(timeIntervalSince1970: persistedFoodMemoryLaunchMaintenanceTimestamp)
            guard now.timeIntervalSince(lastRun) >= foodMemoryLaunchMaintenanceInterval else { return }
        }

        guard scenePhase == .active else { return }
        guard !hasActiveLiveWorkoutInProgress() else { return }

        persistedFoodMemoryLaunchMaintenanceTimestamp = now.timeIntervalSince1970
        FoodMemoryBackgroundService.shared.scheduleMaintenance(
            modelContainer: modelContainer,
            backfillLimit: 8,
            resolveLimit: 4,
            delay: foodMemoryMaintenanceDeferral
        )
    }

    @MainActor
    private func runStartupMigrationWhenIdle(maxAttempts: Int = 8) async {
        for attempt in 0..<maxAttempts {
            guard !Task.isCancelled else { return }
            if !hasActiveLiveWorkoutInProgress() {
                let interval = PerformanceTrace.begin("startup_migration", category: .dataLoad)
                await migrateExistingWorkoutSets(modelContainer: modelContainer)
                await migrateLegacyCloudImagesAndBackfillFoodEmoji(modelContainer: modelContainer)
                PerformanceTrace.end("startup_migration", interval, category: .dataLoad)
                return
            }

            let retryDelay: Duration = attempt < 3 ? .seconds(45) : .seconds(90)
            try? await Task.sleep(for: retryDelay)
        }
    }

    @MainActor
    private func scheduleForegroundHealthKitSyncIfEligible() {
        guard hasCompletedOnboardingProfile() else { return }
        guard healthKitService.isAuthorized else { return }

        deferredHealthKitSyncTask?.cancel()
        deferredHealthKitSyncTask = Task(priority: .utility) { @MainActor in
            try? await Task.sleep(for: foregroundHealthKitSyncDelay)
            guard !Task.isCancelled else { return }
            guard scenePhase == .active else { return }
            let hasActiveWorkout = hasActiveLiveWorkoutInProgress()
            guard startupCoordinator.shouldScheduleForegroundHealthKitSync(
                hasActiveWorkoutInProgress: hasActiveWorkout
            ) else { return }
            await syncRecentWorkoutsFromHealthKit()
        }
    }

    @MainActor
    private func hasCompletedOnboardingProfile() -> Bool {
        var descriptor = FetchDescriptor<UserProfile>(
            predicate: #Predicate<UserProfile> { $0.hasCompletedOnboarding == true }
        )
        descriptor.fetchLimit = 1
        return ((try? modelContainer.mainContext.fetch(descriptor)) ?? []).isEmpty == false
    }

    @MainActor
    private func hasActiveLiveWorkoutInProgress() -> Bool {
        var descriptor = FetchDescriptor<LiveWorkout>(predicate: #Predicate { $0.completedAt == nil })
        descriptor.fetchLimit = 1
        let active = (try? modelContainer.mainContext.fetch(descriptor)) ?? []
        return !active.isEmpty
    }

    @MainActor
    private func syncRecentWorkoutsFromHealthKit() async {
        let interval = PerformanceTrace.begin("healthkit_recent_sync", category: .dataLoad)
        defer { PerformanceTrace.end("healthkit_recent_sync", interval, category: .dataLoad) }

        let now = Date()
        let persistedLastSync: Date? = {
            guard persistedHealthKitWorkoutSyncTimestamp > 0 else { return nil }
            return Date(timeIntervalSince1970: persistedHealthKitWorkoutSyncTimestamp)
        }()
        let effectiveLastSync = lastHealthKitWorkoutSyncDate ?? persistedLastSync

        // Persisted debounce keeps launch-time sync from re-running every app open.
        if let lastSync = effectiveLastSync, now.timeIntervalSince(lastSync) < minimumHealthKitSyncInterval {
            return
        }

        do {
            let context = ModelContext(modelContainer)
            context.autosaveEnabled = false
            let lookbackDays = effectiveLastSync == nil
                ? initialHealthKitSyncLookbackDays
                : incrementalHealthKitSyncLookbackDays
            let syncStart = Calendar.current.date(byAdding: .day, value: -lookbackDays, to: now) ?? now
            let healthKitWorkouts = try await healthKitService.fetchWorkoutsAuthorized(from: syncStart, to: now)
            guard !hasActiveLiveWorkoutInProgress() else { return }
            guard !healthKitWorkouts.isEmpty else {
                // Avoid long import backoff when the sample window is empty.
                return
            }

            let workoutDescriptor = FetchDescriptor<WorkoutSession>(
                predicate: #Predicate<WorkoutSession> { workout in
                    workout.loggedAt >= syncStart && workout.healthKitWorkoutID != nil
                }
            )
            let existingWorkouts = try context.fetch(workoutDescriptor)
            let existingIDs = Set(existingWorkouts.compactMap { $0.healthKitWorkoutID })
            let newWorkouts = healthKitWorkouts.filter { !existingIDs.contains($0.healthKitWorkoutID ?? "") }

            for workout in newWorkouts {
                context.insert(workout)
            }

            let mergeSearchStart = Calendar.current.date(
                byAdding: .day,
                value: -(lookbackDays + 14),
                to: now
            ) ?? syncStart
            let liveDescriptor = FetchDescriptor<LiveWorkout>(
                predicate: #Predicate<LiveWorkout> { workout in
                    workout.completedAt != nil &&
                    workout.mergedHealthKitWorkoutID == nil &&
                    workout.startedAt >= mergeSearchStart
                }
            )
            let completedLiveWorkouts = try context.fetch(liveDescriptor)

            var didMerge = false
            for workout in completedLiveWorkouts {
                if let match = healthKitService.bestOverlappingWorkout(for: workout, from: healthKitWorkouts, searchBufferMinutes: 15) {
                    workout.mergedHealthKitWorkoutID = match.healthKitWorkoutID
                    if let calories = match.caloriesBurned {
                        workout.healthKitCalories = Double(calories)
                    }
                    if let avgHR = match.averageHeartRate {
                        workout.healthKitAvgHeartRate = Double(avgHR)
                    }
                    didMerge = true
                }
            }

            if !newWorkouts.isEmpty || didMerge {
                do {
                    try context.save()
                } catch {
                    context.rollback()
                    throw error
                }
            }

            lastHealthKitWorkoutSyncDate = now
            persistedHealthKitWorkoutSyncTimestamp = now.timeIntervalSince1970
            PerformanceTrace.event("healthkit_recent_sync_completed", category: .dataLoad)
        } catch {
            // Handle silently to avoid blocking app startup.
        }
    }

    private static var hasAccessibleSharedGroupContainer: Bool {
        FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: SharedStorageKeys.AppGroup.suiteName
        ) != nil
    }

    private static func primeSharedStoreDirectoryIfNeeded(usesInMemoryStore: Bool) {
        guard !usesInMemoryStore else { return }
        guard let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: SharedStorageKeys.AppGroup.suiteName
        ) else {
            return
        }

        let appSupportURL = groupURL.appendingPathComponent("Library/Application Support", isDirectory: true)
        try? FileManager.default.createDirectory(at: appSupportURL, withIntermediateDirectories: true)
    }

    private static func migrateLegacyStoreToSharedContainerIfNeeded(usesInMemoryStore: Bool) {
        guard !usesInMemoryStore else { return }

        let fileManager = FileManager.default
        guard let sharedContainerURL = fileManager.containerURL(
            forSecurityApplicationGroupIdentifier: SharedStorageKeys.AppGroup.suiteName
        ) else {
            return
        }
        guard let appSupportURL = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            return
        }

        let sharedAppSupportURL = sharedContainerURL.appendingPathComponent(
            "Library/Application Support",
            isDirectory: true
        )
        do {
            try fileManager.createDirectory(
                at: sharedAppSupportURL,
                withIntermediateDirectories: true
            )
        } catch {
            return
        }

        guard let legacyFiles = try? fileManager.contentsOfDirectory(
            at: appSupportURL,
            includingPropertiesForKeys: nil
        ) else {
            return
        }

        let legacyStoreFiles = legacyFiles.filter {
            $0.lastPathComponent.hasPrefix(swiftDataStoreFilename)
        }
        guard !legacyStoreFiles.isEmpty else { return }

        let sharedStoreURL = sharedAppSupportURL.appendingPathComponent(swiftDataStoreFilename)
        guard !fileManager.fileExists(atPath: sharedStoreURL.path) else {
            return
        }

        let stagingURL = sharedAppSupportURL.appendingPathComponent(
            ".trai-store-migration-\(UUID().uuidString)",
            isDirectory: true
        )
        var installedURLs: [URL] = []

        do {
            try fileManager.createDirectory(at: stagingURL, withIntermediateDirectories: false)
            defer { try? fileManager.removeItem(at: stagingURL) }

            for sourceURL in legacyStoreFiles {
                let stagedURL = stagingURL.appendingPathComponent(sourceURL.lastPathComponent)
                try fileManager.copyItem(at: sourceURL, to: stagedURL)

                guard let sourceSize = try sourceURL.resourceValues(forKeys: [.fileSizeKey]).fileSize,
                      let stagedSize = try stagedURL.resourceValues(forKeys: [.fileSizeKey]).fileSize,
                      sourceSize == stagedSize else {
                    throw CocoaError(.fileReadCorruptFile)
                }
            }

            // Install SQLite sidecars first and the primary store last. The
            // primary file remains the durable marker that migration completed.
            let orderedFiles = legacyStoreFiles.sorted {
                ($0.lastPathComponent == swiftDataStoreFilename ? 1 : 0)
                    < ($1.lastPathComponent == swiftDataStoreFilename ? 1 : 0)
            }
            for sourceURL in orderedFiles {
                let destinationURL = sharedAppSupportURL.appendingPathComponent(sourceURL.lastPathComponent)
                if fileManager.fileExists(atPath: destinationURL.path) {
                    try fileManager.removeItem(at: destinationURL)
                }
                try fileManager.moveItem(
                    at: stagingURL.appendingPathComponent(sourceURL.lastPathComponent),
                    to: destinationURL
                )
                installedURLs.append(destinationURL)
            }
        } catch {
            // A failed attempt must not leave sidecars that can poison a retry.
            if !fileManager.fileExists(atPath: sharedStoreURL.path) {
                for installedURL in installedURLs {
                    try? fileManager.removeItem(at: installedURL)
                }
            }
        }
    }
}

private struct ModelStoreRecoveryView: View {
    let errorDescription: String

    var body: some View {
        ContentUnavailableView {
            Label("Trai Couldn't Open Your Data", systemImage: "externaldrive.badge.exclamationmark")
        } description: {
            Text("Your data has not been reset or replaced. Close Trai and try again. If this keeps happening, contact support with the diagnostic below.")
        } actions: {
            ShareLink(
                item: "Trai storage launch error: \(errorDescription)",
                subject: Text("Trai storage diagnostic")
            ) {
                Label("Share Diagnostic", systemImage: "square.and.arrow.up")
            }
        }
        .padding()
    }
}

// MARK: - Widget Food Log Processing

extension TraiApp {
    /// Process any pending food logs from widget quick actions
    @MainActor
    func processPendingWidgetFoodLogs() {
        guard modelContainerLaunchError == nil else { return }
        guard let defaults = UserDefaults(suiteName: SharedStorageKeys.AppGroup.suiteName) else {
            return
        }

        let pendingLogs = PendingFoodLogQueue.load(from: defaults)
        guard !pendingLogs.isEmpty else { return }

        let context = ModelContext(modelContainer)
        context.autosaveEnabled = false
        var alreadyPersistedIDs = Set<UUID>()
        var stagedIDs = Set<UUID>()
        var seenIDs = Set<UUID>()

        for log in pendingLogs {
            guard seenIDs.insert(log.id).inserted else { continue }

            do {
                if try hasPersistedWidgetFoodEntry(id: log.id, context: context) {
                    alreadyPersistedIDs.insert(log.id)
                    continue
                }
            } catch {
                continue
            }

            let entry = FoodEntry()
            entry.id = log.id
            entry.name = log.name
            entry.calories = log.calories
            entry.proteinGrams = Double(log.protein)
            entry.loggedAt = log.loggedAt
            entry.mealType = log.mealType
            entry.emoji = FoodEmojiResolver.resolve(preferred: nil, foodName: log.name)
            entry.ensureDisplayMetadata()
            context.insert(entry)
            BehaviorTracker(modelContext: context).record(
                actionKey: BehaviorActionKey.logFood,
                domain: .nutrition,
                surface: .widget,
                outcome: .completed,
                relatedEntityId: entry.id,
                metadata: [
                    "source": "widget_pending",
                    "name": log.name
                ],
                saveImmediately: false
            )
            stagedIDs.insert(log.id)
        }

        var processedIDs = alreadyPersistedIDs

        if !stagedIDs.isEmpty {
            do {
                try context.save()
                processedIDs.formUnion(stagedIDs)
            } catch {
                context.rollback()
            }
        }

        try? PendingFoodLogQueue.remove(ids: processedIDs, from: defaults)

        // Refresh widgets with new data
        if !processedIDs.isEmpty {
            WidgetDataProvider.shared.scheduleRefresh(
                modelContainer: modelContainer,
                delay: .milliseconds(150)
            )
        }
    }

    @MainActor
    private func hasPersistedWidgetFoodEntry(id: UUID, context: ModelContext) throws -> Bool {
        var descriptor = FetchDescriptor<FoodEntry>(
            predicate: #Predicate<FoodEntry> { entry in
                entry.id == id
            }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).isEmpty == false
    }
}

private enum HomeScreenQuickAction: String, CaseIterable {
    case logFood = "Nadav.Trai.quickaction.logFood"
    case logWeight = "Nadav.Trai.quickaction.logWeight"
    case workout = "Nadav.Trai.quickaction.workout"
    case chat = "Nadav.Trai.quickaction.chat"

    var title: String {
        switch self {
        case .logFood:
            return "Log Food"
        case .logWeight:
            return "Log Weight"
        case .workout:
            return "Start Workout"
        case .chat:
            return "Trai"
        }
    }

    var systemImageName: String {
        switch self {
        case .logFood:
            return "fork.knife"
        case .logWeight:
            return "scalemass.fill"
        case .workout:
            return "figure.run"
        case .chat:
            return "circle.hexagongrid.circle"
        }
    }

    var route: AppRoute {
        switch self {
        case .logFood:
            return .logFood
        case .logWeight:
            return .logWeight
        case .workout:
            return .workout(templateID: nil, templateName: nil)
        case .chat:
            return .chat
        }
    }

    var shortcutItem: UIApplicationShortcutItem {
        UIApplicationShortcutItem(
            type: rawValue,
            localizedTitle: title,
            localizedSubtitle: nil,
            icon: UIApplicationShortcutIcon(systemImageName: systemImageName),
            userInfo: nil
        )
    }

    @MainActor
    static func registerAll() {
        UIApplication.shared.shortcutItems = allCases.map(\.shortcutItem)
    }

    static func handle(_ shortcutItem: UIApplicationShortcutItem) -> Bool {
        guard let action = Self(rawValue: shortcutItem.type) else { return false }
        PendingAppRouteStore.setPendingRoute(action.route)
        return true
    }
}

private final class HomeScreenQuickActionApplicationDelegate: NSObject, UIApplicationDelegate {
    @MainActor
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        HomeScreenQuickAction.registerAll()
        return true
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(
            name: nil,
            sessionRole: connectingSceneSession.role
        )
        configuration.delegateClass = HomeScreenQuickActionSceneDelegate.self
        return configuration
    }
}

private final class HomeScreenQuickActionSceneDelegate: NSObject, UIWindowSceneDelegate {
    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        if let shortcutItem = connectionOptions.shortcutItem {
            _ = HomeScreenQuickAction.handle(shortcutItem)
        }
    }

    @MainActor
    func sceneWillResignActive(_ scene: UIScene) {
        HomeScreenQuickAction.registerAll()
    }

    func windowScene(
        _ windowScene: UIWindowScene,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        completionHandler(HomeScreenQuickAction.handle(shortcutItem))
    }
}

// MARK: - Data Migrations

@MainActor
private func seedUITestProfileIfNeeded(modelContainer: ModelContainer) {
    let context = modelContainer.mainContext
    var completedProfileDescriptor = FetchDescriptor<UserProfile>(
        predicate: #Predicate<UserProfile> { $0.hasCompletedOnboarding == true }
    )
    completedProfileDescriptor.fetchLimit = 1
    let hasCompletedProfile = ((try? context.fetch(completedProfileDescriptor)) ?? []).isEmpty == false
    guard !hasCompletedProfile else { return }

    var anyProfileDescriptor = FetchDescriptor<UserProfile>()
    anyProfileDescriptor.fetchLimit = 1
    if let existingProfile = ((try? context.fetch(anyProfileDescriptor)) ?? []).first {
        existingProfile.hasCompletedOnboarding = true
        if existingProfile.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            existingProfile.name = "UI Test User"
        }
        try? context.save()
        return
    }

    let profile = UserProfile()
    profile.name = "UI Test User"
    profile.hasCompletedOnboarding = true
    context.insert(profile)
    try? context.save()
}

@MainActor
private func seedAppStoreScreenshotDataIfNeeded(modelContainer: ModelContainer) {
    let context = modelContainer.mainContext
    UserDefaults.standard.set(true, forKey: "dashboardActivationChecklistDismissed")

    var markerDescriptor = FetchDescriptor<CoachMemory>(
        predicate: #Predicate<CoachMemory> { $0.content == "App Store Screenshot Seed" }
    )
    markerDescriptor.fetchLimit = 1
    guard ((try? context.fetch(markerDescriptor)) ?? []).isEmpty else { return }

    let calendar = Calendar.current
    let now = Date()
    let today = calendar.startOfDay(for: now)

    let profile = fetchOrCreateScreenshotProfile(context: context)
    profile.name = "Nadav"
    profile.hasCompletedOnboarding = true
    profile.goal = .recomposition
    profile.currentWeightKg = 78.4
    profile.targetWeightKg = 75.0
    profile.dailyCalorieGoal = 2450
    profile.dailyProteinGoal = 175
    profile.dailyCarbsGoal = 260
    profile.dailyFatGoal = 72
    profile.dailyFiberGoal = 34
    profile.dailySugarGoal = 55
    profile.enabledMacros = MacroType.defaultEnabled
    profile.usesMetricWeight = false
    profile.usesMetricExerciseWeight = false
    profile.preferredWorkoutDays = 4
    profile.workoutExperienceLevel = "intermediate"
    profile.workoutTimePerSession = 55
    profile.defaultWorkoutAction = "recommendedWorkout"
    profile.workoutPlan = screenshotWorkoutPlan()

    let chatSessionId = UUID(uuidString: "48D643F0-4B92-4C90-9754-8546F511C6EF") ?? UUID()
    UserDefaults.standard.set(chatSessionId.uuidString, forKey: SharedStorageKeys.Chat.currentSessionId)
    UserDefaults.standard.set(now.timeIntervalSince1970, forKey: "lastChatActivityDate")

    seedScreenshotFoodEntries(context: context, calendar: calendar, today: today)
    seedScreenshotWeightEntries(context: context, calendar: calendar, today: today)
    seedScreenshotWorkouts(context: context, calendar: calendar, today: today)
    seedScreenshotExerciseHistory(context: context, calendar: calendar, today: today)
    seedScreenshotChat(context: context, sessionId: chatSessionId, now: now)
    seedScreenshotGoalsAndMemory(context: context, now: now)

    try? context.save()
}

@MainActor
private func seedGoalPreviewDataIfNeeded(modelContainer: ModelContainer) {
    let context = modelContainer.mainContext
    UserDefaults.standard.set(true, forKey: "dashboardActivationChecklistDismissed")

    var markerDescriptor = FetchDescriptor<CoachMemory>(
        predicate: #Predicate<CoachMemory> { $0.content == "Goal Preview Seed" }
    )
    markerDescriptor.fetchLimit = 1
    guard ((try? context.fetch(markerDescriptor)) ?? []).isEmpty else { return }

    let calendar = Calendar.current
    let now = Date()
    let today = calendar.startOfDay(for: now)
    let currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? today
    let currentMonthStart = calendar.dateInterval(of: .month, for: now)?.start ?? today

    let profile = fetchOrCreateScreenshotProfile(context: context)
    profile.name = "Nadav"
    profile.hasCompletedOnboarding = true
    profile.goal = .recomposition
    profile.preferredWorkoutDays = 4
    profile.usesMetricExerciseWeight = false
    profile.workoutPlan = screenshotWorkoutPlan()

    let weeklyGoal = WorkoutGoal(
        title: "Strength 3x weekly",
        goalKind: .frequency,
        linkedWorkoutType: .strength,
        targetValue: 3,
        targetUnit: "sessions",
        periodUnit: .week,
        periodCount: 1,
        successCriteria: "Complete three strength sessions each week.",
        notes: "Open-ended habit preview: four complete weeks, current week in progress."
    )
    weeklyGoal.createdAt = calendar.date(byAdding: .weekOfYear, value: -4, to: currentWeekStart)?
        .addingTimeInterval(3_600) ?? now

    let dailyGoal = WorkoutGoal(
        title: "Move every day",
        goalKind: .frequency,
        linkedWorkoutType: .cardio,
        targetValue: 1,
        targetUnit: "session",
        periodUnit: .day,
        periodCount: 1,
        successCriteria: "Log one easy cardio session each day.",
        notes: "Open-ended daily habit preview with a live streak."
    )
    dailyGoal.createdAt = calendar.date(byAdding: .day, value: -120, to: today) ?? now

    let monthlyGoal = WorkoutGoal(
        title: "Mobility 8x monthly",
        goalKind: .frequency,
        linkedWorkoutType: .mobility,
        targetValue: 8,
        targetUnit: "sessions",
        periodUnit: .month,
        periodCount: 1,
        successCriteria: "Log eight mobility sessions each month.",
        notes: "Open-ended monthly habit preview with a partial current month."
    )
    monthlyGoal.createdAt = calendar.date(byAdding: .month, value: -5, to: currentMonthStart) ?? now

    let challengeGoal = WorkoutGoal(
        title: "Yoga 2x weekly for 4 weeks",
        goalKind: .frequency,
        linkedWorkoutType: .yoga,
        targetValue: 2,
        targetUnit: "sessions",
        periodUnit: .week,
        periodCount: 1,
        successCriteria: "Complete two yoga sessions each week for four weeks.",
        notes: "Finite challenge preview.",
        targetDate: calendar.date(byAdding: .weekOfYear, value: 1, to: currentWeekStart)
    )
    challengeGoal.createdAt = calendar.date(byAdding: .weekOfYear, value: -3, to: currentWeekStart)?
        .addingTimeInterval(3_600) ?? now

    let completedGoal = WorkoutGoal(
        title: "Finish first plan block",
        goalKind: .milestone,
        status: .completed,
        linkedWorkoutType: .strength,
        successCriteria: "Complete the first structured training block.",
        notes: "Completed goal preview."
    )
    completedGoal.createdAt = calendar.date(byAdding: .weekOfYear, value: -6, to: currentWeekStart) ?? now
    completedGoal.completedAt = calendar.date(byAdding: .day, value: -2, to: today)?.addingTimeInterval(18 * 60 * 60)
    completedGoal.updatedAt = completedGoal.completedAt ?? now

    for goal in [weeklyGoal, dailyGoal, monthlyGoal, challengeGoal, completedGoal] {
        context.insert(goal)
    }

    if let firstWeekStart = calendar.dateInterval(of: .weekOfYear, for: weeklyGoal.createdAt)?.start {
        seedGoalPreviewWeeklyWorkouts(
            context: context,
            calendar: calendar,
            firstWeekStart: firstWeekStart,
            weeklyCounts: [3, 3, 3, 3, 2],
            mode: .strength,
            name: "Strength Session"
        )
    }

    if let firstChallengeWeekStart = calendar.dateInterval(of: .weekOfYear, for: challengeGoal.createdAt)?.start {
        seedGoalPreviewWeeklyWorkouts(
            context: context,
            calendar: calendar,
            firstWeekStart: firstChallengeWeekStart,
            weeklyCounts: [2, 2, 1, 1],
            mode: .yoga,
            name: "Yoga Flow"
        )
    }

    seedGoalPreviewDailyWorkouts(
        context: context,
        calendar: calendar,
        today: today,
        startOffset: -120,
        mode: .cardio,
        name: "Morning Walk"
    )

    for monthOffset in [-3, -2, -1] {
        guard let monthStart = calendar.date(byAdding: .month, value: monthOffset, to: currentMonthStart) else {
            continue
        }
        seedGoalPreviewMonthlyWorkouts(
            context: context,
            calendar: calendar,
            monthStart: monthStart,
            count: 8,
            mode: .mobility,
            name: "Mobility Flow"
        )
    }
    seedGoalPreviewMonthlyWorkouts(
        context: context,
        calendar: calendar,
        monthStart: currentMonthStart,
        count: 5,
        mode: .mobility,
        name: "Mobility Flow"
    )

    context.insert(CoachMemory(
        content: "Goal Preview Seed",
        category: .context,
        topic: .general,
        source: "goal_preview_seed",
        importance: 1
    ))

    try? context.save()
}

@MainActor
private func seedGoalPreviewWeeklyWorkouts(
    context: ModelContext,
    calendar: Calendar,
    firstWeekStart: Date,
    weeklyCounts: [Int],
    mode: WorkoutMode,
    name: String
) {
    for (weekOffset, count) in weeklyCounts.enumerated() {
        guard let weekStart = calendar.date(byAdding: .weekOfYear, value: weekOffset, to: firstWeekStart) else {
            continue
        }
        for sessionOffset in 0..<count {
            guard let candidateDate = calendar.date(byAdding: .day, value: min(sessionOffset * 2, 5), to: weekStart)?
                .addingTimeInterval(12 * 60 * 60) else { continue }
            let completedAt = min(candidateDate, Date().addingTimeInterval(-Double(count - sessionOffset) * 60 * 60))
            context.insert(goalPreviewWorkout(name: name, mode: mode, completedAt: completedAt))
        }
    }
}

@MainActor
private func seedGoalPreviewDailyWorkouts(
    context: ModelContext,
    calendar: Calendar,
    today: Date,
    startOffset: Int,
    mode: WorkoutMode,
    name: String
) {
    let sparseHitOffsets = Set(
        Array(-4...0) +
        Array(-28 ... -21) +
        [-100, -91, -82, -73, -64, -55, -46, -37]
    )

    for dayOffset in startOffset...0 {
        guard sparseHitOffsets.contains(dayOffset) else {
            continue
        }

        guard let date = calendar.date(byAdding: .day, value: dayOffset, to: today)?
            .addingTimeInterval(8 * 60 * 60) else { continue }
        context.insert(goalPreviewWorkout(name: name, mode: mode, completedAt: date))
    }
}

@MainActor
private func seedGoalPreviewMonthlyWorkouts(
    context: ModelContext,
    calendar: Calendar,
    monthStart: Date,
    count: Int,
    mode: WorkoutMode,
    name: String
) {
    for sessionOffset in 0..<count {
        guard let candidateDate = calendar.date(byAdding: .day, value: min(sessionOffset * 3, 24), to: monthStart)?
            .addingTimeInterval(9 * 60 * 60) else { continue }
        let completedAt = min(candidateDate, Date().addingTimeInterval(-Double(count - sessionOffset) * 60 * 60))
        context.insert(goalPreviewWorkout(name: name, mode: mode, completedAt: completedAt))
    }
}

private func goalPreviewWorkout(name: String, mode: WorkoutMode, completedAt: Date) -> LiveWorkout {
    let workout = LiveWorkout(name: name, workoutType: mode, focusAreas: [mode.displayName])
    workout.startedAt = completedAt.addingTimeInterval(-45 * 60)
    workout.completedAt = completedAt
    return workout
}

@MainActor
private func fetchOrCreateScreenshotProfile(context: ModelContext) -> UserProfile {
    var descriptor = FetchDescriptor<UserProfile>()
    descriptor.fetchLimit = 1
    if let profile = (try? context.fetch(descriptor))?.first {
        return profile
    }

    let profile = UserProfile()
    context.insert(profile)
    return profile
}

private func seedScreenshotFoodEntries(context: ModelContext, calendar: Calendar, today: Date) {
    let mealSession = UUID()
    let items: [(String, Int, Double, Double, Double, Double, Double, String, String, Int, Int)] = [
        ("Greek Yogurt Berry Bowl", 420, 38, 46, 12, 8, 16, "breakfast", "yogurt bowl with berries and granola", 8, 10),
        ("Turkey Avocado Wrap", 610, 47, 58, 22, 10, 7, "lunch", "turkey avocado wrap", 12, 35),
        ("Iced Protein Latte", 190, 25, 14, 4, 0, 6, "snack", "protein latte", 15, 5),
        ("Salmon Rice Bowl", 735, 52, 76, 24, 9, 8, "dinner", "salmon rice bowl with vegetables", 19, 15)
    ]

    for (index, item) in items.enumerated() {
        let entry = FoodEntry()
        entry.name = item.0
        entry.calories = item.1
        entry.proteinGrams = item.2
        entry.carbsGrams = item.3
        entry.fatGrams = item.4
        entry.fiberGrams = item.5
        entry.sugarGrams = item.6
        entry.mealType = item.7
        entry.input = index == 3 ? .camera : .manual
        entry.sessionId = index == 3 ? mealSession : nil
        entry.sessionOrder = index == 3 ? 0 : index
        entry.servingSize = "1 serving"
        entry.userDescription = item.8
        entry.loggedAt = calendar.date(byAdding: .minute, value: item.10, to: calendar.date(byAdding: .hour, value: item.9, to: today) ?? today) ?? Date()
        entry.ensureDisplayMetadata()
        context.insert(entry)
    }
}

private func seedScreenshotWeightEntries(context: ModelContext, calendar: Calendar, today: Date) {
    for dayOffset in stride(from: -42, through: 0, by: 7) {
        let entry = WeightEntry(weightKg: 80.1 + Double(dayOffset) * 0.04, loggedAt: calendar.date(byAdding: .day, value: dayOffset, to: today) ?? today)
        entry.bodyFatPercentage = 17.8 + Double(dayOffset) * 0.01
        context.insert(entry)
    }
}

private func seedScreenshotWorkouts(context: ModelContext, calendar: Calendar, today: Date) {
    let workouts: [(String, LiveWorkout.WorkoutType, [String], Int, Int)] = [
        ("Upper Strength", .strength, ["Chest", "Back", "Shoulders"], -1, 58),
        ("Zone 2 Run", .cardio, ["Conditioning"], -3, 36),
        ("Lower Power", .strength, ["Quads", "Glutes", "Hamstrings"], -5, 62),
        ("Push Hypertrophy", .strength, ["Chest", "Shoulders", "Triceps"], -8, 54)
    ]

    for workoutData in workouts {
        let startedAt = calendar.date(byAdding: .day, value: workoutData.3, to: today) ?? today
        let workout = LiveWorkout(
            name: workoutData.0,
            workoutType: workoutData.1,
            targetMuscleGroups: LiveWorkout.MuscleGroup.fromTargetStrings(workoutData.2),
            focusAreas: workoutData.2
        )
        workout.startedAt = calendar.date(byAdding: .hour, value: 17, to: startedAt) ?? startedAt
        workout.completedAt = calendar.date(byAdding: .minute, value: workoutData.4, to: workout.startedAt)
        workout.healthKitCalories = workoutData.1 == .cardio ? 390 : 260
        workout.healthKitAvgHeartRate = workoutData.1 == .cardio ? 148 : 116

        if workoutData.1 == .cardio {
            let run = LiveWorkoutEntry(exerciseName: "Outdoor Run", orderIndex: 0, exerciseType: "cardio")
            run.durationSeconds = workoutData.4 * 60
            run.distanceMeters = 6200
            run.caloriesBurned = 390
            run.completedAt = workout.completedAt
            workout.entries = [run]
        } else {
            let first = LiveWorkoutEntry(exerciseName: workoutData.0.contains("Lower") ? "Back Squat" : "Incline Dumbbell Press", orderIndex: 0)
            first.addSet(.init(reps: 8, weight: .init(kg: 42.5, lbs: 94), preferredWeightUnit: .lbs, completed: true))
            first.addSet(.init(reps: 8, weight: .init(kg: 45, lbs: 99), preferredWeightUnit: .lbs, completed: true))
            first.addSet(.init(reps: 7, weight: .init(kg: 45, lbs: 99), preferredWeightUnit: .lbs, completed: true))
            first.completedAt = workout.completedAt

            let second = LiveWorkoutEntry(exerciseName: workoutData.0.contains("Lower") ? "Romanian Deadlift" : "Chest-Supported Row", orderIndex: 1)
            second.addSet(.init(reps: 10, weight: .init(kg: 50, lbs: 110), preferredWeightUnit: .lbs, completed: true))
            second.addSet(.init(reps: 10, weight: .init(kg: 52.5, lbs: 116), preferredWeightUnit: .lbs, completed: true))
            second.completedAt = workout.completedAt
            workout.entries = [first, second]
        }
        context.insert(workout)
    }

    context.insert(WorkoutGoal(
        title: "Train 4x this week",
        goalKind: .frequency,
        linkedWorkoutType: .strength,
        targetValue: 4,
        targetUnit: "workouts",
        periodUnit: .week,
        periodCount: 1,
        notes: "Build consistent strength training weeks."
    ))
    context.insert(WorkoutGoal(
        title: "Bench 185 lb for 5",
        goalKind: .weight,
        linkedWorkoutType: .strength,
        linkedActivityName: "Bench Press",
        targetValue: 185,
        targetUnit: "lb",
        notes: "Progress upper-body strength without rushing recovery."
    ))
}

private func seedScreenshotExerciseHistory(context: ModelContext, calendar: Calendar, today: Date) {
    let benchProgress: [(Int, Double, Int)] = [
        (-42, 70, 5),
        (-28, 75, 5),
        (-14, 79, 5),
        (-1, 84, 5)
    ]

    for (dayOffset, weightKg, reps) in benchProgress {
        let entry = LiveWorkoutEntry(exerciseName: "Bench Press", orderIndex: 0)
        entry.addSet(.init(reps: reps, weight: .init(kg: weightKg, lbs: weightKg * 2.20462), preferredWeightUnit: .lbs, completed: true))
        entry.addSet(.init(reps: reps, weight: .init(kg: weightKg - 2.5, lbs: (weightKg - 2.5) * 2.20462), preferredWeightUnit: .lbs, completed: true))
        entry.addSet(.init(reps: reps - 1, weight: .init(kg: weightKg - 2.5, lbs: (weightKg - 2.5) * 2.20462), preferredWeightUnit: .lbs, completed: true))
        let performedAt = calendar.date(
            byAdding: .hour,
            value: 18,
            to: calendar.date(byAdding: .day, value: dayOffset, to: today) ?? today
        ) ?? today
        context.insert(ExerciseHistory(from: entry, performedAt: performedAt))
    }
}

private func seedScreenshotChat(context: ModelContext, sessionId: UUID, now: Date) {
    if AppLaunchArguments.appStoreScreenshotChatScenarioRawValue == "plan" {
        seedScreenshotPlanChat(context: context, sessionId: sessionId, now: now)
        return
    }
    if AppLaunchArguments.appStoreScreenshotChatScenarioRawValue == "reminder" {
        seedScreenshotReminderChat(context: context, sessionId: sessionId, now: now)
        return
    }

    let user = ChatMessage(
        content: "Can you use this instead of barbell rows in today's Upper Strength workout?",
        isFromUser: true,
        sessionId: sessionId,
        imageData: screenshotGymMachineImageData()
    )
    user.timestamp = now.addingTimeInterval(-240)
    let coach = ChatMessage(
        content: "Yes. I identified it as a chest-supported row and rebuilt your session around it, keeping the same back volume while taking stress off your lower back.",
        isFromUser: false,
        sessionId: sessionId
    )
    coach.timestamp = now.addingTimeInterval(-210)
    coach.setSuggestedWorkout(SuggestedWorkoutEntry(
        name: "Updated Upper Strength",
        workoutType: "strength",
        targetMuscleGroups: ["chest", "back", "shoulders"],
        exercises: [
            .init(name: "Chest-Supported Row", category: "strength", targetTags: ["back"], trackingFields: ["weight", "reps"], sets: 3, reps: 10, weightKg: 48, notes: "Swapped in from your photo."),
            .init(name: "Bench Press", category: "strength", targetTags: ["chest"], trackingFields: ["weight", "reps"], sets: 4, reps: 5, weightKg: 84),
            .init(name: "Incline Press", category: "strength", targetTags: ["chest", "shoulders"], trackingFields: ["weight", "reps"], sets: 3, reps: 8, weightKg: 29)
        ],
        durationMinutes: 42,
        rationale: "Photo-matched swap. Volume preserved."
    ))
    context.insert(user)
    context.insert(coach)
    context.insert(CoachMemory(
        content: "Prefers machine swaps that keep planned workout volume intact.",
        category: .preference,
        topic: .workout,
        source: "app_store_screenshot_seed",
        importance: 5
    ))
}

private func screenshotGymMachineImageData() -> Data? {
    UIImage(named: "AppStoreGymMachineSample")?.jpegData(compressionQuality: 0.88)
}

private func seedScreenshotReminderChat(context: ModelContext, sessionId: UUID, now: Date) {
    let user = ChatMessage(
        content: "Remind me to weigh in every weekday before breakfast.",
        isFromUser: true,
        sessionId: sessionId
    )
    user.timestamp = now.addingTimeInterval(-240)

    let coach = ChatMessage(
        content: "I drafted that reminder with your weekday schedule.",
        isFromUser: false,
        sessionId: sessionId
    )
    coach.timestamp = now.addingTimeInterval(-210)
    coach.setSuggestedReminder(SuggestedReminder(
        title: "Weigh in",
        body: "Track your morning weight before breakfast.",
        hour: 7,
        minute: 30,
        repeatDays: "2,3,4,5,6"
    ))

    context.insert(user)
    context.insert(coach)
}

private func seedScreenshotPlanChat(context: ModelContext, sessionId: UUID, now: Date) {
    let user = ChatMessage(
        content: "Build me a 4-day plan for strength, lean muscle, and Friday's Zone 2 run.",
        isFromUser: true,
        sessionId: sessionId
    )
    user.timestamp = now.addingTimeInterval(-240)

    let coach = ChatMessage(
        content: "Here's a week that balances heavy upper/lower days, recovery, and your recomp targets.",
        isFromUser: false,
        sessionId: sessionId
    )
    coach.timestamp = now.addingTimeInterval(-210)
    coach.setSuggestedWorkoutPlan(WorkoutPlanSuggestionEntry(
        plan: screenshotWorkoutPlan(),
        message: "4-day upper/lower split plus protected conditioning."
    ))

    context.insert(user)
    context.insert(coach)
}

private func seedScreenshotGoalsAndMemory(context: ModelContext, now: Date) {
    context.insert(CoachMemory(
        content: "Prefers fast high-protein lunches like bowls, wraps, and protein coffee on training days.",
        category: .preference,
        topic: .food,
        source: "app_store_screenshot_seed",
        importance: 4
    ))
    context.insert(CoachMemory(
        content: "App Store Screenshot Seed",
        category: .context,
        topic: .general,
        source: "app_store_screenshot_seed",
        importance: 1
    ))
}

func screenshotWorkoutPlan() -> WorkoutPlan {
    WorkoutPlan(
        splitType: .upperLower,
        daysPerWeek: 4,
        templates: [
            WorkoutPlan.WorkoutTemplate(
                name: "Upper Strength",
                targetMuscleGroups: ["chest", "back", "shoulders"],
                exercises: [
                    .init(exerciseName: "Bench Press", muscleGroup: "chest", defaultSets: 4, defaultReps: 5, repRange: "4-6", restSeconds: 150, order: 0),
                    .init(exerciseName: "Chest-Supported Row", muscleGroup: "back", defaultSets: 4, defaultReps: 8, repRange: "8-10", restSeconds: 120, order: 1),
                    .init(exerciseName: "Incline Dumbbell Press", muscleGroup: "chest", defaultSets: 3, defaultReps: 10, repRange: "8-12", restSeconds: 90, order: 2)
                ],
                estimatedDurationMinutes: 55,
                order: 0,
                notes: "Heavy upper-body day with controlled progression."
            ),
            WorkoutPlan.WorkoutTemplate(
                name: "Lower Power",
                targetMuscleGroups: ["quads", "glutes", "hamstrings"],
                exercises: [
                    .init(exerciseName: "Back Squat", muscleGroup: "quads", defaultSets: 4, defaultReps: 5, repRange: "4-6", restSeconds: 180, order: 0),
                    .init(exerciseName: "Romanian Deadlift", muscleGroup: "hamstrings", defaultSets: 3, defaultReps: 8, repRange: "8-10", restSeconds: 120, order: 1),
                    .init(exerciseName: "Walking Lunge", muscleGroup: "glutes", defaultSets: 3, defaultReps: 12, repRange: "10-12", restSeconds: 90, order: 2)
                ],
                estimatedDurationMinutes: 60,
                order: 1,
                notes: "Lower-body strength and posterior-chain focus."
            ),
            WorkoutPlan.WorkoutTemplate(
                name: "Zone 2 Run",
                sessionType: .cardio,
                focusAreas: ["Conditioning", "Recovery"],
                targetMuscleGroups: [],
                exercises: [
                    .init(exerciseName: "Zone 2 Run", muscleGroup: "cardio", defaultSets: 1, defaultReps: 1, repRange: "30-40 min", restSeconds: 0, order: 0)
                ],
                estimatedDurationMinutes: 36,
                order: 2,
                notes: "Protected conditioning day that supports recovery."
            ),
            WorkoutPlan.WorkoutTemplate(
                name: "Upper Hypertrophy",
                targetMuscleGroups: ["chest", "back", "shoulders", "arms"],
                exercises: [
                    .init(exerciseName: "Incline Dumbbell Press", muscleGroup: "chest", defaultSets: 3, defaultReps: 10, repRange: "8-12", restSeconds: 90, order: 0),
                    .init(exerciseName: "Lat Pulldown", muscleGroup: "back", defaultSets: 3, defaultReps: 12, repRange: "10-12", restSeconds: 75, order: 1),
                    .init(exerciseName: "Lateral Raise", muscleGroup: "shoulders", defaultSets: 3, defaultReps: 15, repRange: "12-15", restSeconds: 60, order: 2)
                ],
                estimatedDurationMinutes: 50,
                order: 3,
                notes: "Higher-rep upper day to build muscle without beating up recovery."
            )
        ],
        planIntent: WorkoutPlan.PlanIntent(
            primaryFocus: "Strength and lean muscle",
            supportingFocuses: ["Protected Zone 2 run", "Recovery-aware upper/lower split"],
            sessionAllocation: "Three strength sessions plus one conditioning day.",
            honoredInputs: ["Friday Zone 2 run", "55 minute sessions", "Recomposition goal"],
            summary: "A four-day week that keeps strength moving while leaving room for conditioning."
        ),
        rationale: "Four focused sessions balance strength progress, recovery, and recomposition.",
        guidelines: [
            "Add weight when all top sets reach the target reps.",
            "Keep two reps in reserve on accessory work.",
            "Pair harder training days with the higher-carb nutrition target."
        ],
        progressionStrategy: .defaultStrategy,
        warnings: nil
    )
}

@MainActor
private func seedLiveWorkoutPerformanceDataIfNeeded(modelContainer: ModelContainer) {
    let seeder = LiveWorkoutPerformanceDataSeeder()
    let context = modelContainer.mainContext
    do {
        let summary = try seeder.seed(
            modelContext: context,
            configuration: .defaultHeavyDeviceProfile
        )
        print(
            "Perf seed complete (\(summary.runIdentifier)): " +
            "\(summary.totalWorkoutsInserted) workouts, " +
            "\(summary.totalEntriesInserted) entries, " +
            "\(summary.totalSetsInserted) sets"
        )
    } catch {
        print("Perf seed failed: \(error.localizedDescription)")
    }
}

@MainActor
private func purgeLiveWorkoutPerformanceSeedDataIfPresent(modelContainer: ModelContainer) {
    let seedMarkerPrefix = "[PerfSeed:"
    let context = modelContainer.mainContext

    do {
        let workoutDescriptor = FetchDescriptor<LiveWorkout>()
        let allWorkouts = try context.fetch(workoutDescriptor)
        let seededWorkouts = allWorkouts.filter { $0.notes.contains(seedMarkerPrefix) }
        guard !seededWorkouts.isEmpty else { return }

        var seededEntryIDs: Set<UUID> = []
        seededEntryIDs.reserveCapacity(seededWorkouts.count * 6)

        for workout in seededWorkouts {
            for entry in workout.entries ?? [] {
                seededEntryIDs.insert(entry.id)
            }
            context.delete(workout)
        }

        var deletedHistoryCount = 0
        if !seededEntryIDs.isEmpty {
            let historyDescriptor = FetchDescriptor<ExerciseHistory>()
            let allHistory = try context.fetch(historyDescriptor)
            for history in allHistory {
                guard let sourceWorkoutEntryId = history.sourceWorkoutEntryId else { continue }
                if seededEntryIDs.contains(sourceWorkoutEntryId) {
                    context.delete(history)
                    deletedHistoryCount += 1
                }
            }
        }

        try context.save()
        print(
            "Purged perf seed data: \(seededWorkouts.count) workouts, " +
            "\(deletedHistoryCount) history entries"
        )
    } catch {
        print("Perf seed cleanup failed: \(error.localizedDescription)")
    }
}

/// Fix existing completed workouts that have sets with data but not marked as completed
@MainActor
private func migrateExistingWorkoutSets(modelContainer: ModelContainer) async {
    let context = ModelContext(modelContainer)
    context.autosaveEnabled = false
    let migrationKey = "workout_sets_completion_migration_v1"

    // Check if migration already ran
    if UserDefaults.standard.bool(forKey: migrationKey) {
        return
    }

    // Fetch all completed workouts
    let descriptor = FetchDescriptor<LiveWorkout>(
        predicate: #Predicate { $0.completedAt != nil }
    )

    let workouts: [LiveWorkout]
    var existingHistories: [ExerciseHistory]
    do {
        workouts = try context.fetch(descriptor)
        existingHistories = try context.fetch(FetchDescriptor<ExerciseHistory>())
    } catch {
        return
    }

    var fixedCount = 0
    var insertedHistoryCount = 0

    for (index, workout) in workouts.enumerated() {
        guard let entries = workout.entries else { continue }
        let completedAt = workout.completedAt

        for entry in entries {
            var needsUpdate = false
            var updatedSets: [LiveWorkoutEntry.SetData] = []

            for set in entry.sets {
                if set.reps > 0 && !set.completed {
                    var fixedSet = set
                    fixedSet.completed = true
                    updatedSets.append(fixedSet)
                    needsUpdate = true
                } else {
                    updatedSets.append(set)
                }
            }

            if needsUpdate {
                entry.sets = updatedSets
                fixedCount += 1
            }
        }

        guard let completedAt else { continue }

        let missingHistory = ExerciseHistory.recordsToInsert(
            from: workout,
            existingHistories: existingHistories,
            performedAt: completedAt
        )
        for history in missingHistory {
            context.insert(history)
        }
        insertedHistoryCount += missingHistory.count
        existingHistories.append(contentsOf: missingHistory)

        if index.isMultiple(of: 20) {
            await Task.yield()
        }
    }

    do {
        if fixedCount > 0 || insertedHistoryCount > 0 {
            try context.save()
        }
    } catch {
        context.rollback()
        return
    }

    if fixedCount > 0 {
        print("Migration: Fixed \(fixedCount) exercise entries with unmarked sets")
    }
    if insertedHistoryCount > 0 {
        print("Migration: Inserted \(insertedHistoryCount) missing exercise history entries")
    }

    // Mark migration as complete
    UserDefaults.standard.set(true, forKey: migrationKey)
}

/// Move legacy CloudKit-backed image blobs to local-only file storage and backfill food emojis.
@MainActor
private func migrateLegacyCloudImagesAndBackfillFoodEmoji(modelContainer: ModelContainer) async {
    let context = ModelContext(modelContainer)
    context.autosaveEnabled = false
    let migrationKey = "local_image_storage_migration_v1"

    if UserDefaults.standard.bool(forKey: migrationKey) {
        return
    }

    var migratedFoodImages = 0
    var backfilledFoodEmoji = 0
    var migratedChatImages = 0

    let foodDescriptor = FetchDescriptor<FoodEntry>()
    guard let foodEntries = try? context.fetch(foodDescriptor) else { return }
    for (index, entry) in foodEntries.enumerated() {
        if entry.migrateLegacyImageToLocalStoreIfNeeded() {
            migratedFoodImages += 1
        }

        let previousEmoji = entry.emoji
        entry.ensureDisplayMetadata()
        if previousEmoji != entry.emoji {
            backfilledFoodEmoji += 1
        }

        if index.isMultiple(of: 40) {
            await Task.yield()
        }
    }

    let chatDescriptor = FetchDescriptor<ChatMessage>()
    guard let chatMessages = try? context.fetch(chatDescriptor) else { return }
    for (index, message) in chatMessages.enumerated() {
        if message.migrateLegacyImageToLocalStoreIfNeeded() {
            migratedChatImages += 1
        }
        if index.isMultiple(of: 80) {
            await Task.yield()
        }
    }

    if migratedFoodImages > 0 || backfilledFoodEmoji > 0 || migratedChatImages > 0 {
        do {
            try context.save()
        } catch {
            context.rollback()
            return
        }
    }

    if migratedFoodImages > 0 {
        print("Migration: Moved \(migratedFoodImages) food images to local-only storage")
    }
    if backfilledFoodEmoji > 0 {
        print("Migration: Backfilled emoji for \(backfilledFoodEmoji) food entries")
    }
    if migratedChatImages > 0 {
        print("Migration: Moved \(migratedChatImages) chat images to local-only storage")
    }

    UserDefaults.standard.set(true, forKey: migrationKey)
}
