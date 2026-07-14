//
//  LiveWorkoutViewModel.swift
//  Trai
//
//  Manages state for live workout tracking
//

import ActivityKit
import Foundation
import SwiftData
import SwiftUI
import UIKit

@MainActor @Observable
final class LiveWorkoutViewModel {
    // MARK: - Properties

    var workout: LiveWorkout
    var isTimerRunning = true
    private(set) var isFinishingWorkout = false

    var isWorkoutFinished: Bool {
        workout.completedAt != nil
    }

    // Live Activity manager (shared singleton to prevent duplicates)
    private var liveActivityManager: LiveActivityManager { LiveActivityManager.shared }
    private var liveActivityUpdateTimer: Timer?
    private var persistenceCoordinator: LiveWorkoutPersistenceCoordinator?
    private var pendingLiveActivityUpdateTask: Task<Void, Never>?
    private var deferredPerformanceHydrationTask: Task<Void, Never>?
    private var deferredSuggestionHydrationTask: Task<Void, Never>?
    private let liveActivityDebounceDelay: Duration = .milliseconds(300)
    private let updatePolicy = LiveWorkoutUpdatePolicy()
    
    // Live Activity intent handling via App Groups
    private var liveActivityIntentTimer: Timer?
    private var lastAddSetTimestamp: TimeInterval = 0
    private var lastTogglePauseTimestamp: TimeInterval = 0
    private var lastAdvanceExerciseTimestamp: TimeInterval = 0
    private var lastLiveActivityIntentInteractionAt: Date?
    private var lastPublishedWatchPayload: LiveWorkoutUpdatePolicy.WatchPayload?
    private var backgroundFlushObserver: NSObjectProtocol?
    private var isSetupActive = false
    private var liveActivityFocusedEntryID: UUID?

    // Timer state - use date calculation for accuracy
    private(set) var pausedDuration: TimeInterval = 0
    private var pauseStartTime: Date?
    private(set) var pausedElapsedTimeSnapshot: TimeInterval?

    /// Total pause duration including any active pause (for UI display)
    var totalPauseDuration: TimeInterval {
        let currentPause = pauseStartTime.map { Date().timeIntervalSince($0) } ?? 0
        return pausedDuration + currentPause
    }

    /// Calculated elapsed time (accurate, doesn't drift)
    var elapsedTime: TimeInterval {
        let totalElapsed = Date().timeIntervalSince(workout.startedAt)
        let currentPauseDuration = pauseStartTime.map { Date().timeIntervalSince($0) } ?? 0
        return totalElapsed - pausedDuration - currentPauseDuration
    }

    // Exercise suggestions generated from target muscles and user history
    var exerciseSuggestions: [ExerciseSuggestion] = []

    // Cache of last performances for exercises
    var lastPerformances: [String: ExerciseHistory] = [:]

    // Cache of personal records (all-time max weight) for exercises
    var personalRecords: [String: ExerciseHistory] = [:]
    var performanceSnapshots: [String: ExercisePerformanceSnapshot] = [:]

    // PRs achieved during this workout (exercise name -> PR details)
    var achievedPRs: [String: PRValue] = [:]

    enum PRType {
        case weight
        case volume
        case reps
    }

    struct PRValue: Equatable {
        let type: PRType
        let exerciseName: String
        let newValue: Double
        let previousValue: Double
        let isFirstTime: Bool
        let volumePRMode: UserProfile.VolumePRMode

        var improvement: Double { newValue - previousValue }

        private var volumeUnitSuffix: String {
            volumePRMode.unitSuffix
        }

        var formattedNewValue: String {
            switch type {
            case .weight: return String(format: "%.1f kg", newValue)
            case .volume: return String(format: "%.0f kg%@", newValue, volumeUnitSuffix)
            case .reps: return "\(Int(newValue)) reps"
            }
        }

        var formattedImprovement: String {
            guard !isFirstTime && improvement > 0 else { return "" }
            switch type {
            case .weight: return String(format: "+%.1f kg", improvement)
            case .volume: return String(format: "+%.0f kg%@", improvement, volumeUnitSuffix)
            case .reps: return "+\(Int(improvement)) reps"
            }
        }
    }

    private struct WorkoutMetrics: Equatable {
        var totalSets: Int
        var completedSets: Int
        var totalVolume: Double

        static let zero = WorkoutMetrics(totalSets: 0, completedSets: 0, totalVolume: 0)
    }

    private struct EntryListSignature: Equatable {
        let id: UUID
        let orderIndex: Int
        let exerciseName: String
    }

    struct LiveActivityProgressSummary: Equatable {
        let completed: Int
        let total: Int
        let label: String
        let supportsSetShortcut: Bool
    }

    private var cachedEntries: [LiveWorkoutEntry] = []
    private var cachedMetrics: WorkoutMetrics = .zero
    private var cachedCurrentExerciseNameSet: Set<String> = []
    private var cachedMuscleGroupByExerciseName: [String: String] = [:]

    // User preferences cache (exercise usage frequency)
    var exerciseUsageFrequency: [String: Int] = [:]
    var availableSuggestions: [ExerciseSuggestion] = []
    var upNextSuggestion: ExerciseSuggestion?
    var suggestionsByMuscle: [String: [ExerciseSuggestion]] = [:]

    // Apple Watch data (via HealthKit)
    var currentHeartRate: Double?
    var lastHeartRateUpdate: Date?
    var workoutCalories: Double = 0
    var lastCalorieUpdate: Date?
    var isHeartRateAvailable: Bool { currentHeartRate != nil }
    var isWatchConnected: Bool {
        if AppLaunchArguments.shouldShowAppStoreScreenshotWatchConnected {
            return true
        }
        return healthKitService?.isWatchConnected ?? false
    }
    var watchSetupErrorMessage: String?
    var isRetryingWatchSync = false

    var watchConnectionHint: String? {
        if let watchSetupErrorMessage {
            return watchSetupErrorMessage
        }
        if isWatchConnected {
            return nil
        }
        if let lastHeartRateUpdate {
            let ageSeconds = Int(Date().timeIntervalSince(lastHeartRateUpdate))
            if ageSeconds >= 0 && ageSeconds <= 180 {
                return "Latest Apple Watch sample was \(ageSeconds)s ago. Keep the Watch workout running."
            }
        }
        return "Start or continue a workout on Apple Watch to stream live heart rate."
    }

    private var modelContext: ModelContext?
    private(set) var healthKitService: HealthKitService?
    private var usesMetricWeightPreference = true
    private var volumePRModePreference: UserProfile.VolumePRMode = .perSet
    private let maxSuggestionPoolSize = 12
    private let exerciseUsageHistoryLookbackDays = 365
    private let exerciseUsageHistoryFetchLimit = 900
    private let suggestionExerciseFetchLimit = 320

    // MARK: - Exercise Suggestion Model

    struct ExerciseSuggestion: Identifiable, Equatable {
        let id = UUID()
        let exerciseName: String
        let muscleGroup: String
        let category: Exercise.Category
        let activityTypeName: String
        let activityMatchingTokens: Set<String>
        let targetTags: [String]
        let trackingFields: [Exercise.TrackingField]
        let defaultSets: Int
        let defaultReps: Int

        static func == (lhs: ExerciseSuggestion, rhs: ExerciseSuggestion) -> Bool {
            lhs.exerciseName == rhs.exerciseName
        }
    }

    enum SuggestionRebuildReason: String {
        case workoutStart
        case targetMusclesChanged
        case userRefresh
    }

    // MARK: - Computed Properties

    var workoutName: String {
        workout.name.isEmpty ? "Workout" : workout.name
    }

    var formattedElapsedTime: String {
        let hours = Int(elapsedTime) / 3600
        let minutes = (Int(elapsedTime) % 3600) / 60
        let seconds = Int(elapsedTime) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var entries: [LiveWorkoutEntry] {
        cachedEntries
    }

    var totalSets: Int {
        cachedMetrics.totalSets
    }

    /// Count of sets with data entered (reps > 0) - shows workout progress during active workout
    var completedSets: Int {
        cachedMetrics.completedSets
    }

    var totalVolume: Double {
        cachedMetrics.totalVolume
    }

    var isWorkoutComplete: Bool {
        !entries.isEmpty && entries.allSatisfy(isEntryComplete)
    }

    var volumePRMode: UserProfile.VolumePRMode {
        volumePRModePreference
    }

    var usesGeneralSessionWorkspace: Bool {
        !workout.type.prefersStructuredEntries && workout.type != .cardio
    }

    var usesFocusedCardioWorkspace: Bool {
        workout.type == .cardio
    }

    var sessionFocusAreas: [String] {
        workout.focusAreas
    }

    /// Target muscle groups for this workout
    var targetMuscleGroups: [String] {
        workout.muscleGroups.map(\.rawValue)
    }

    var targetActivityCategories: [Exercise.Category] {
        Self.displayActivityCategories(from: categoriesFromFocusAreas())
    }

    var targetActivityTypes: [String] {
        let broadKeys = Self.nonActivityTypeFocusKeys
        return workout.focusAreas
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && !broadKeys.contains($0.goalNormalizedKey) }
    }

    /// Get the muscle group for a workout entry (checks suggestions first, then database)
    private func getMuscleGroup(for entry: LiveWorkoutEntry) -> String? {
        if let cachedMuscle = cachedMuscleGroupByExerciseName[entry.exerciseName] {
            return cachedMuscle
        }

        // First check if it's from our suggestions
        if let suggestion = exerciseSuggestions.first(where: { $0.exerciseName == entry.exerciseName }) {
            cachedMuscleGroupByExerciseName[entry.exerciseName] = suggestion.muscleGroup
            return suggestion.muscleGroup
        }

        // Look up the exercise in the database by name
        guard let modelContext else { return nil }
        let exerciseName = entry.exerciseName
        var descriptor = FetchDescriptor<Exercise>(
            predicate: #Predicate { $0.name == exerciseName }
        )
        descriptor.fetchLimit = 1
        if let exercise = try? modelContext.fetch(descriptor).first,
           let muscleGroup = exercise.muscleGroup {
            cachedMuscleGroupByExerciseName[entry.exerciseName] = muscleGroup
            return muscleGroup
        }

        return nil
    }

    private var targetExerciseMuscleGroups: Set<String> {
        Set(workout.muscleGroups.map { $0.toExerciseMuscleGroup.rawValue })
    }

    private func recentMuscleGroupsFromCurrentWorkout(limit: Int) -> Set<String> {
        var recentMuscles = Set<String>()
        let recentEntries = entries.suffix(limit)
        for entry in recentEntries {
            if let muscle = getMuscleGroup(for: entry) {
                recentMuscles.insert(muscle)
            }
        }
        return recentMuscles
    }

    private func currentTargetMuscleCounts() -> [String: Int] {
        var counts: [String: Int] = [:]
        for entry in entries {
            guard entry.isStrength else { continue }
            guard let muscle = getMuscleGroup(for: entry) else { continue }
            guard targetExerciseMuscleGroups.contains(muscle) else { continue }
            counts[muscle, default: 0] += 1
        }
        return counts
    }

    private func suggestionScore(
        _ suggestion: ExerciseSuggestion,
        targetMuscleCounts: [String: Int],
        recentMuscleGroups: Set<String>
    ) -> Double {
        let usageFrequency = Double(exerciseUsageFrequency[suggestion.exerciseName, default: 0])
        let preferenceScore = log1p(usageFrequency) * 1.5
        guard suggestion.category == .strength else {
            let contextualScore: Double = suggestedActivityCategories().contains(suggestion.category) ? 2.0 : 0.5
            let semanticMatchScore: Double = targetActivityFocusKeys.isDisjoint(with: suggestion.activityMatchingTokens) ? 0 : 3.0
            return preferenceScore + contextualScore + semanticMatchScore
        }

        let currentTargetCount = targetMuscleCounts[suggestion.muscleGroup, default: 0]
        let coverageScore: Double
        if targetExerciseMuscleGroups.contains(suggestion.muscleGroup) {
            switch currentTargetCount {
            case 0:
                coverageScore = 3.0
            case 1:
                coverageScore = 1.5
            default:
                coverageScore = 0.5
            }
        } else {
            coverageScore = 0.0
        }

        let diversityPenalty = recentMuscleGroups.contains(suggestion.muscleGroup) ? 1.25 : 0.0
        return preferenceScore + coverageScore - diversityPenalty
    }

    private func applyRankedSuggestions(_ rankedSuggestions: [ExerciseSuggestion]) {
        availableSuggestions = rankedSuggestions
        upNextSuggestion = rankedSuggestions.first
        suggestionsByMuscle = Dictionary(grouping: rankedSuggestions) { $0.muscleGroup }
    }

    private func suggestedActivityCategories() -> Set<Exercise.Category> {
        var categories = Set<Exercise.Category>()

        switch workout.type {
        case .cardio:
            categories.insert(.cardio)
        case .hiit:
            categories.formUnion([.conditioning, .cardio])
        case .climbing:
            categories.formUnion(Exercise.Category.sportPractice.suggestionCategories)
            categories.formUnion([.conditioning, .mobility])
        case .yoga, .pilates, .flexibility:
            categories.formUnion([.flexibility, .mobility])
        case .mobility:
            categories.insert(.mobility)
        case .recovery:
            categories.formUnion([.recovery, .mobility, .cardio])
        case .mixed:
            categories.formUnion(categoriesFromFocusAreas())
        case .custom:
            categories.formUnion(categoriesFromFocusAreas())
        case .strength:
            categories.formUnion(categoriesFromFocusAreas())
        }

        return categories
    }

    private var targetActivityFocusKeys: Set<String> {
        Set(targetActivityTypes.map(Exercise.normalizedActivityKey).filter { !$0.isEmpty })
    }

    private func categoriesFromFocusAreas() -> Set<Exercise.Category> {
        workout.focusAreas.reduce(into: Set<Exercise.Category>()) { result, focus in
            let normalized = focus
                .lowercased()
                .replacingOccurrences(of: "-", with: "")
                .replacingOccurrences(of: "_", with: "")
                .replacingOccurrences(of: " ", with: "")

            for category in Exercise.Category.allCases {
                let normalizedRawValue = category.rawValue
                    .lowercased()
                    .replacingOccurrences(of: "-", with: "")
                    .replacingOccurrences(of: "_", with: "")
                    .replacingOccurrences(of: " ", with: "")
                let normalizedDisplayName = category.displayName
                    .lowercased()
                    .replacingOccurrences(of: "-", with: "")
                    .replacingOccurrences(of: "_", with: "")
                    .replacingOccurrences(of: " ", with: "")
                if normalized == normalizedRawValue || normalized == normalizedDisplayName {
                    result.formUnion(category.suggestionCategories)
                }
            }
        }
    }

    private static func displayActivityCategories(from categories: Set<Exercise.Category>) -> [Exercise.Category] {
        Exercise.Category.userFacingCases
            .filter { category in
                guard category != .strength else { return false }
                return !categories.isDisjoint(with: category.suggestionCategories)
            }
    }

    private static var nonActivityTypeFocusKeys: Set<String> {
        let categoryKeys = Exercise.Category.allCases.flatMap { category in
            [category.rawValue, category.displayName]
        }
        let liveMuscleKeys = LiveWorkout.MuscleGroup.allCases.flatMap { muscle in
            [muscle.rawValue, muscle.displayName]
        }
        let exerciseMuscleKeys = Exercise.MuscleGroup.allCases.flatMap { muscle in
            [muscle.rawValue, muscle.displayName]
        }
        let blockKindKeys = WorkoutPlan.TrainingBlock.BlockKind.allCases.flatMap { kind in
            [kind.rawValue, kind.displayName]
        }
        let roleKeys = WorkoutPlan.TrainingBlock.Role.allCases.flatMap { role in
            [role.rawValue, role.displayName]
        }
        let splitKeys = [
            "push", "pull", "legs", "ppl", "push pull legs",
            "upper", "lower", "upper body", "lower body",
            "full body", "fullbody", "total body",
            "main lift", "accessory", "accessories",
            "hypertrophy", "power", "speed", "technique",
            "easy effort", "general", "mixed", "hybrid"
        ]
        return Set((categoryKeys + liveMuscleKeys + exerciseMuscleKeys + blockKindKeys + roleKeys + splitKeys)
            .map(\.goalNormalizedKey)
            .filter { !$0.isEmpty })
    }

    /// Recomputes ranked suggestions only when source data changes (entries/suggestions/frequencies).
    private func recomputeSuggestionRankings() {
        let filtered = exerciseSuggestions.filter { !cachedCurrentExerciseNameSet.contains($0.exerciseName.lowercased()) }
        guard !filtered.isEmpty else {
            applyRankedSuggestions([])
            return
        }

        let recentMuscleGroups = recentMuscleGroupsFromCurrentWorkout(limit: 2)
        let targetMuscleCounts = currentTargetMuscleCounts()

        let ranked = filtered.sorted { lhs, rhs in
            let lhsScore = suggestionScore(
                lhs,
                targetMuscleCounts: targetMuscleCounts,
                recentMuscleGroups: recentMuscleGroups
            )
            let rhsScore = suggestionScore(
                rhs,
                targetMuscleCounts: targetMuscleCounts,
                recentMuscleGroups: recentMuscleGroups
            )
            if lhsScore != rhsScore {
                return lhsScore > rhsScore
            }

            let lhsUsage = exerciseUsageFrequency[lhs.exerciseName, default: 0]
            let rhsUsage = exerciseUsageFrequency[rhs.exerciseName, default: 0]
            if lhsUsage != rhsUsage {
                return lhsUsage > rhsUsage
            }

            return lhs.exerciseName.localizedStandardCompare(rhs.exerciseName) == .orderedAscending
        }

        applyRankedSuggestions(ranked)
    }

    // MARK: - Initialization

    init(workout: LiveWorkout, suggestions: [ExerciseSuggestion] = []) {
        self.workout = workout
        // elapsedTime is now computed from workout.startedAt
        self.exerciseSuggestions = suggestions
        refreshEntriesAndMetrics(forceSuggestionRefresh: true)
    }

    deinit {
        MainActor.assumeIsolated {
            liveActivityUpdateTimer?.invalidate()
            liveActivityIntentTimer?.invalidate()
            pendingLiveActivityUpdateTask?.cancel()
            deferredPerformanceHydrationTask?.cancel()
            deferredSuggestionHydrationTask?.cancel()
            if let backgroundFlushObserver {
                NotificationCenter.default.removeObserver(backgroundFlushObserver)
            }
        }
    }

    /// Initialize with an existing workout and optional template for suggestions
    convenience init(workout: LiveWorkout, template: WorkoutPlan.WorkoutTemplate?) {
        // Template exercises are intentionally ignored so suggestions can adapt
        // to the user's own exercise history, but the planned day still needs
        // its targets so recommendations start from the right context.
        if let template {
            if workout.muscleGroups.isEmpty, template.sessionType.supportsMuscleTargets {
                workout.muscleGroups = LiveWorkout.MuscleGroup.fromTargetStrings(template.resolvedTargetMuscleGroups)
            }
            if workout.focusAreas.isEmpty {
                workout.focusAreas = template.focusAreas
            }
        }
        self.init(workout: workout, suggestions: [])
    }

    // MARK: - Setup

    func setup(with modelContext: ModelContext, healthKitService: HealthKitService? = nil) -> Error? {
        self.modelContext = modelContext
        self.healthKitService = healthKitService
        usesMetricWeightPreference = getUserUsesMetricWeight()
        volumePRModePreference = getUserVolumePRMode()
        seedScreenshotWatchDataIfNeeded()
        guard !isSetupActive else {
            refreshEntriesAndMetrics()
            return nil
        }
        isSetupActive = true
        configurePersistenceCoordinatorIfNeeded()
        registerBackgroundFlushObserverIfNeeded()

        // Insert workout if not already persisted
        if workout.modelContext == nil {
            modelContext.insert(workout)
            do {
                try modelContext.save()
            } catch {
                modelContext.rollback()
                isSetupActive = false
                return error
            }
            BehaviorTracker(modelContext: modelContext).record(
                actionKey: BehaviorActionKey.startWorkout,
                domain: .workout,
                surface: .workouts,
                outcome: .performed,
                relatedEntityId: workout.id,
                metadata: [
                    "source": "live_workout_setup",
                    "workout_name": workout.name
                ]
            )
        }

        refreshEntriesAndMetrics()
        startTimer()
        scheduleDeferredStartupHydration()

        // Start heart rate streaming from Apple Watch
        startHeartRateMonitoring()

        // Start Live Activity
        startLiveActivity()
        
        // Set up Live Activity intent observers
        setupLiveActivityObservers()
        return nil
    }
    
    private func setupLiveActivityObservers() {
        seedStaleLiveActivityIntentTimestampsIfNeeded()
        // Poll App Group intents with adaptive intervals:
        // slower while app is foregrounded, faster during intent interactions/background.
        scheduleNextLiveActivityIntentPoll()
    }

    private func seedStaleLiveActivityIntentTimestampsIfNeeded() {
        let workoutStartTimestamp = workout.startedAt.timeIntervalSince1970
        lastAddSetTimestamp = max(lastAddSetTimestamp, workoutStartTimestamp)
        lastTogglePauseTimestamp = max(lastTogglePauseTimestamp, workoutStartTimestamp)
        lastAdvanceExerciseTimestamp = max(lastAdvanceExerciseTimestamp, workoutStartTimestamp)
    }

    private func scheduleNextLiveActivityIntentPoll() {
        liveActivityIntentTimer?.invalidate()
        let interval = updatePolicy.intentPollingInterval(
            appState: currentAppState(),
            lastInteractionAt: lastLiveActivityIntentInteractionAt
        )
        liveActivityIntentTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkLiveActivityIntents()
                self?.scheduleNextLiveActivityIntentPoll()
            }
        }
    }
    
    private func checkLiveActivityIntents() {
        guard let defaults = UserDefaults(suiteName: LiveActivityIntentKeys.suiteName) else { return }
        
        let addSetTimestamps = pendingLiveActivityIntentTimestamps(
            defaults: defaults,
            queueKey: LiveActivityIntentKeys.addSetTimestamps,
            legacyTimestampKey: LiveActivityIntentKeys.addSetTimestamp,
            handledAfter: lastAddSetTimestamp
        )
        if !addSetTimestamps.isEmpty {
            for timestamp in addSetTimestamps {
                lastAddSetTimestamp = timestamp
                handleAddSetFromLiveActivity()
            }
            lastLiveActivityIntentInteractionAt = Date()
            pruneLiveActivityIntentTimestamps(
                defaults: defaults,
                queueKey: LiveActivityIntentKeys.addSetTimestamps,
                legacyTimestampKey: LiveActivityIntentKeys.addSetTimestamp,
                through: lastAddSetTimestamp
            )
        }
        
        let togglePauseTimestamps = pendingLiveActivityIntentTimestamps(
            defaults: defaults,
            queueKey: LiveActivityIntentKeys.togglePauseTimestamps,
            legacyTimestampKey: LiveActivityIntentKeys.togglePauseTimestamp,
            handledAfter: lastTogglePauseTimestamp
        )
        if !togglePauseTimestamps.isEmpty {
            for timestamp in togglePauseTimestamps {
                lastTogglePauseTimestamp = timestamp
                handleTogglePauseFromLiveActivity()
            }
            lastLiveActivityIntentInteractionAt = Date()
            pruneLiveActivityIntentTimestamps(
                defaults: defaults,
                queueKey: LiveActivityIntentKeys.togglePauseTimestamps,
                legacyTimestampKey: LiveActivityIntentKeys.togglePauseTimestamp,
                through: lastTogglePauseTimestamp
            )
        }

        let advanceExerciseTimestamps = pendingLiveActivityIntentTimestamps(
            defaults: defaults,
            queueKey: LiveActivityIntentKeys.advanceExerciseTimestamps,
            legacyTimestampKey: LiveActivityIntentKeys.advanceExerciseTimestamp,
            handledAfter: lastAdvanceExerciseTimestamp
        )
        if !advanceExerciseTimestamps.isEmpty {
            for timestamp in advanceExerciseTimestamps {
                lastAdvanceExerciseTimestamp = timestamp
                handleAdvanceExerciseFromLiveActivity()
            }
            lastLiveActivityIntentInteractionAt = Date()
            pruneLiveActivityIntentTimestamps(
                defaults: defaults,
                queueKey: LiveActivityIntentKeys.advanceExerciseTimestamps,
                legacyTimestampKey: LiveActivityIntentKeys.advanceExerciseTimestamp,
                through: lastAdvanceExerciseTimestamp
            )
        }
    }

    private func pendingLiveActivityIntentTimestamps(
        defaults: UserDefaults,
        queueKey: String,
        legacyTimestampKey: String,
        handledAfter lastHandledTimestamp: TimeInterval
    ) -> [TimeInterval] {
        let queuedTimestamps = defaults.array(forKey: queueKey) as? [Double] ?? []
        let legacyTimestamp = defaults.double(forKey: legacyTimestampKey)
        let allTimestamps = queuedTimestamps + (legacyTimestamp > 0 ? [legacyTimestamp] : [])
        return Array(Set(allTimestamps))
            .filter { $0 > lastHandledTimestamp }
            .sorted()
    }

    private func pruneLiveActivityIntentTimestamps(
        defaults: UserDefaults,
        queueKey: String,
        legacyTimestampKey: String,
        through handledTimestamp: TimeInterval
    ) {
        let remainingTimestamps = (defaults.array(forKey: queueKey) as? [Double] ?? [])
            .filter { $0 > handledTimestamp }
        if remainingTimestamps.isEmpty {
            defaults.removeObject(forKey: queueKey)
        } else {
            defaults.set(remainingTimestamps, forKey: queueKey)
        }

        if defaults.double(forKey: legacyTimestampKey) <= handledTimestamp {
            defaults.removeObject(forKey: legacyTimestampKey)
        }
    }

    private func currentAppState() -> LiveWorkoutAppState {
        switch UIApplication.shared.applicationState {
        case .active:
            return .active
        case .inactive:
            return .inactive
        case .background:
            return .background
        @unknown default:
            return .inactive
        }
    }
    
    private func removeLiveActivityObservers() {
        liveActivityIntentTimer?.invalidate()
        liveActivityIntentTimer = nil
        lastLiveActivityIntentInteractionAt = nil
    }

    private func scheduleDeferredStartupHydration() {
        deferredPerformanceHydrationTask?.cancel()
        deferredSuggestionHydrationTask?.cancel()

        deferredPerformanceHydrationTask = Task(priority: .utility) { @MainActor [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: .milliseconds(140))
            guard !Task.isCancelled else { return }
            self.loadLastPerformances()
        }

        deferredSuggestionHydrationTask = Task(priority: .utility) { @MainActor [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: .milliseconds(460))
            guard !Task.isCancelled else { return }
            self.loadExerciseUsageFrequency()
            self.rebuildSuggestionPool(reason: .workoutStart)
        }
    }

    private func configurePersistenceCoordinatorIfNeeded() {
        guard persistenceCoordinator == nil else { return }
        persistenceCoordinator = LiveWorkoutPersistenceCoordinator { [weak self] in
            guard let self, let modelContext = self.modelContext else { return }
            try modelContext.save()
        }
    }

    private func registerBackgroundFlushObserverIfNeeded() {
        guard backgroundFlushObserver == nil else { return }
        backgroundFlushObserver = NotificationCenter.default.addObserver(
            forName: .liveWorkoutForceFlush,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.saveImmediately(updateLiveActivity: false, trigger: .appBackground)
            }
        }
    }

    private func unregisterBackgroundFlushObserver() {
        guard let backgroundFlushObserver else { return }
        NotificationCenter.default.removeObserver(backgroundFlushObserver)
        self.backgroundFlushObserver = nil
    }
    
    /// Handle "Add Set" button tap from Live Activity
    private func handleAddSetFromLiveActivity() {
        let targetEntry = liveActivityEntryForAddSet()
        guard let targetEntry else { return }

        addSet(to: targetEntry)
        updateLiveActivity()
        HapticManager.mediumTap()
    }
    
    /// Handle "Pause/Resume" button tap from Live Activity
    private func handleTogglePauseFromLiveActivity() {
        if isTimerRunning {
            pauseTimer()
        } else {
            resumeTimer()
        }
        HapticManager.lightTap()
    }

    /// Handle "Up Next" button tap from Live Activity
    private func handleAdvanceExerciseFromLiveActivity() {
        guard let currentEntry = liveActivityCurrentEntry(),
              let currentIndex = entries.firstIndex(where: { $0.id == currentEntry.id }) else {
            if addUpNextExercise() {
                updateLiveActivity()
                HapticManager.lightTap()
            }
            return
        }

        if currentEntry.isStrength {
            var sets = currentEntry.sets
            for index in sets.indices where !sets[index].isWarmup && hasLoggedSetData(sets[index]) {
                sets[index].completed = true
            }
            currentEntry.sets = sets
        } else if !currentEntry.isPlannedActivityGuidance {
            currentEntry.completedAt = currentEntry.completedAt ?? Date()
        }

        if entries.indices.contains(currentIndex + 1) {
            liveActivityFocusedEntryID = entries[currentIndex + 1].id
        } else {
            addUpNextExercise()
        }
        refreshEntriesAndMetrics()
        saveDebounced(updateLiveActivity: true)
        updateLiveActivity()
        HapticManager.lightTap()
    }

    // MARK: - Apple Watch Monitoring

    func startHeartRateMonitoring() {
        if seedScreenshotWatchDataIfNeeded() {
            return
        }

        guard let service = healthKitService else {
            watchSetupErrorMessage = "HealthKit is unavailable on this device."
            return
        }

        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await syncWatchData(using: service)
            } catch {
                watchSetupErrorMessage = "Health access is disabled. In Health app, allow Trai to read Heart Rate, Active Energy, and Workouts."
            }
        }
    }

    func retryWatchSync() {
        guard !isRetryingWatchSync else { return }
        guard let service = healthKitService else {
            watchSetupErrorMessage = "HealthKit is unavailable on this device."
            return
        }

        isRetryingWatchSync = true
        watchSetupErrorMessage = nil

        Task { @MainActor [weak self] in
            guard let self else { return }
            defer { isRetryingWatchSync = false }

            do {
                try await syncWatchData(using: service)
            } catch {
                watchSetupErrorMessage = "Health access is disabled. In Health app, allow Trai to read Heart Rate, Active Energy, and Workouts."
            }
        }
    }

    func stopHeartRateMonitoring() {
        healthKitService?.stopHeartRateStreaming()
        healthKitService?.stopCalorieStreaming()
        if AppLaunchArguments.shouldShowAppStoreScreenshotWatchConnected {
            return
        }
        currentHeartRate = nil
        lastHeartRateUpdate = nil
        lastPublishedWatchPayload = nil
        watchSetupErrorMessage = nil
    }

    /// Updates heart rate and calories from the HealthKit service - called by the view
    func updateWatchDataFromService() {
        if seedScreenshotWatchDataIfNeeded() {
            return
        }

        guard let service = healthKitService else { return }
        let nextPayload = LiveWorkoutUpdatePolicy.WatchPayload(
            roundedHeartRate: service.currentHeartRate.map { Int($0.rounded()) },
            heartRateUpdatedAt: service.lastHeartRateUpdate,
            roundedCalories: Int(service.workoutCalories.rounded()),
            caloriesUpdatedAt: service.lastCalorieUpdate
        )

        guard updatePolicy.shouldPublishWatchPayload(
            previous: lastPublishedWatchPayload,
            next: nextPayload
        ) else {
            return
        }

        lastPublishedWatchPayload = nextPayload
        currentHeartRate = service.currentHeartRate
        lastHeartRateUpdate = service.lastHeartRateUpdate
        workoutCalories = service.workoutCalories
        lastCalorieUpdate = service.lastCalorieUpdate
    }

    /// Legacy method for backwards compatibility
    func updateHeartRateFromService() {
        updateWatchDataFromService()
    }

    @discardableResult
    private func seedScreenshotWatchDataIfNeeded() -> Bool {
        guard AppLaunchArguments.shouldShowAppStoreScreenshotWatchConnected else {
            return false
        }
        currentHeartRate = 132
        lastHeartRateUpdate = Date()
        workoutCalories = 286
        lastCalorieUpdate = Date()
        watchSetupErrorMessage = nil
        return true
    }

    private func syncWatchData(using service: HealthKitService) async throws {
        try await service.ensureAuthorization()

        watchSetupErrorMessage = nil
        service.startHeartRateStreaming(from: workout.startedAt)
        service.startCalorieStreaming(from: workout.startedAt)

        // Seed UI immediately with a recent sample while anchored queries warm up.
        if let recentHeartRate = await service.fetchRecentHeartRate(),
           Date().timeIntervalSince(recentHeartRate.date) <= 120 {
            currentHeartRate = recentHeartRate.bpm
            lastHeartRateUpdate = recentHeartRate.date
        }

        updateWatchDataFromService()
    }

    /// Rebuild the session suggestion pool from target muscles.
    /// This is intentionally event-driven (not tied to set/rep/weight edits).
    private func rebuildSuggestionPool(reason _: SuggestionRebuildReason) {
        guard let modelContext else { return }
        let activityCategories = suggestedActivityCategories()
        let activityFocusKeys = targetActivityFocusKeys
        guard !workout.targetMuscleGroups.isEmpty || !activityCategories.isEmpty || !activityFocusKeys.isEmpty else {
            exerciseSuggestions = []
            applyRankedSuggestions([])
            return
        }

        let targetMuscleTokens = workout.targetMuscleGroups
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        let targetMuscles = targetMuscleTokens.isEmpty
            ? []
            : LiveWorkout.MuscleGroup.fromTargetStrings(targetMuscleTokens)
        let exerciseMuscleGroups: Set<String>
        if targetMuscles.contains(.fullBody) {
            // Full-body sessions should suggest across the complete strength catalog,
            // not only exercises explicitly tagged as "fullBody".
            exerciseMuscleGroups = Set(Exercise.MuscleGroup.allCases.map(\.rawValue))
        } else {
            exerciseMuscleGroups = Set(targetMuscles.map { $0.toExerciseMuscleGroup.rawValue })
        }
        var descriptor = FetchDescriptor<Exercise>()
        descriptor.fetchLimit = suggestionExerciseFetchLimit
        guard let exercises = try? modelContext.fetch(descriptor) else { return }
        let targetActivityKeys = Set(
            workout.focusAreas.map(Exercise.normalizedActivityKey).filter { !$0.isEmpty }
        )

        // Exclude custom exercises created in this workout session:
        // those are usually being performed immediately, not "next suggestion" candidates.
        let filtered = exercises.filter { exercise in
            if exercise.isCustom && exercise.createdAt >= workout.startedAt {
                return false
            }

            if exercise.exerciseCategory == .strength {
                guard let muscleGroup = exercise.muscleGroup else { return false }
                return exerciseMuscleGroups.contains(muscleGroup)
            }

            return activityCategories.contains(exercise.exerciseCategory)
                || !activityFocusKeys.isDisjoint(with: exercise.activityMatchingTokens)
                || !targetActivityKeys.isDisjoint(with: exercise.activityMatchingTokens)
        }

        let sortedByPreference = filtered.sorted { lhs, rhs in
            let lhsUsage = exerciseUsageFrequency[lhs.name, default: 0]
            let rhsUsage = exerciseUsageFrequency[rhs.name, default: 0]
            if lhsUsage != rhsUsage {
                return lhsUsage > rhsUsage
            }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }

        var seenNames = Set<String>()
        let uniqueExercises = sortedByPreference.filter { exercise in
            seenNames.insert(exercise.name.lowercased()).inserted
        }

        let userDefaultReps = getUserDefaultRepCount()
        exerciseSuggestions = Array(uniqueExercises.prefix(maxSuggestionPoolSize)).map { exercise in
            ExerciseSuggestion(
                exerciseName: exercise.name,
                muscleGroup: exercise.muscleGroup ?? exercise.activityTypeName,
                category: exercise.exerciseCategory,
                activityTypeName: exercise.activityTypeName,
                activityMatchingTokens: exercise.activityMatchingTokens,
                targetTags: exercise.targetTags,
                trackingFields: exercise.trackingFields,
                defaultSets: 3,
                defaultReps: userDefaultReps
            )
        }
        cachedMuscleGroupByExerciseName.removeAll(keepingCapacity: true)
        loadSuggestionPerformances()
        recomputeSuggestionRankings()
    }

    func refreshSuggestions() {
        rebuildSuggestionPool(reason: .userRefresh)
    }

    #if DEBUG
    func debugRebuildSuggestionPoolForTests(modelContext: ModelContext) {
        self.modelContext = modelContext
        rebuildSuggestionPool(reason: .workoutStart)
    }
    #endif

    /// Load exercise usage frequency from history
    private func loadExerciseUsageFrequency() {
        guard let modelContext else { return }

        let historyCutoff = Calendar.current.date(
            byAdding: .day,
            value: -exerciseUsageHistoryLookbackDays,
            to: Date()
        ) ?? .distantPast
        var descriptor = FetchDescriptor<ExerciseHistory>(
            predicate: #Predicate<ExerciseHistory> { history in
                history.performedAt >= historyCutoff
            },
            sortBy: [SortDescriptor(\ExerciseHistory.performedAt, order: .reverse)]
        )
        descriptor.fetchLimit = exerciseUsageHistoryFetchLimit
        guard let history = try? modelContext.fetch(descriptor) else { return }

        // Count occurrences of each exercise
        var frequency: [String: Int] = [:]
        for record in history {
            frequency[record.exerciseName, default: 0] += 1
        }
        exerciseUsageFrequency = frequency
        recomputeSuggestionRankings()
    }

    /// Load last performances for suggested exercises
    private func loadSuggestionPerformances() {
        for suggestion in exerciseSuggestions {
            if let lastPerformance = getLastPerformance(for: suggestion.exerciseName) {
                lastPerformances[suggestion.exerciseName] = lastPerformance
            }
        }
    }

    // MARK: - Last Performance & Personal Records

    /// Load last performances for all exercises in the workout
    func loadLastPerformances() {
        for entry in entries {
            _ = getPerformanceSnapshot(for: entry.exerciseName)
        }
    }

    /// Get last performance for a specific exercise
    func getLastPerformance(for exerciseName: String) -> ExerciseHistory? {
        getPerformanceSnapshot(for: exerciseName)?.lastSession
    }

    /// Get personal record (all-time max weight) for a specific exercise
    func getPersonalRecord(for exerciseName: String) -> ExerciseHistory? {
        getPerformanceSnapshot(for: exerciseName)?.weightPR
    }

    private func cachePerformanceSnapshot(_ snapshot: ExercisePerformanceSnapshot, for exerciseName: String) {
        performanceSnapshots[exerciseName] = snapshot
        if let lastSession = snapshot.lastSession {
            lastPerformances[exerciseName] = lastSession
        } else {
            lastPerformances.removeValue(forKey: exerciseName)
        }
        if let weightPR = snapshot.weightPR {
            personalRecords[exerciseName] = weightPR
        } else {
            personalRecords.removeValue(forKey: exerciseName)
        }
    }

    private func clearPerformanceCache(for exerciseName: String) {
        performanceSnapshots.removeValue(forKey: exerciseName)
        lastPerformances.removeValue(forKey: exerciseName)
        personalRecords.removeValue(forKey: exerciseName)
    }

    private func getPerformanceSnapshot(for exerciseName: String) -> ExercisePerformanceSnapshot? {
        if let cached = performanceSnapshots[exerciseName] {
            return cached
        }
        guard let modelContext else { return nil }
        guard let snapshot = ExercisePerformanceService.snapshot(
            for: exerciseName,
            modelContext: modelContext,
            volumePRMode: volumePRModePreference
        ) else {
            clearPerformanceCache(for: exerciseName)
            return nil
        }
        cachePerformanceSnapshot(snapshot, for: exerciseName)
        return snapshot
    }

    /// Check if current workout entry exceeds the cached PR (live checking while editing)
    func isNewPR(for entry: LiveWorkoutEntry) -> PRType? {
        // Get best set from current entry
        let completedSets = entry.sets.filter { !$0.isWarmup && $0.reps > 0 }
        guard !completedSets.isEmpty else { return nil }

        let currentBestWeight = completedSets.map(\.weightKg).max() ?? 0
        let currentTotalVolume = completedSets.reduce(0) { $0 + $1.volume }
        let currentVolumeMetric = volumeValue(
            totalVolume: currentTotalVolume,
            setCount: completedSets.count
        )
        let currentBestReps = completedSets.map(\.reps).max() ?? 0
        let snapshot = getPerformanceSnapshot(for: entry.exerciseName)
        let previousWeightPR = snapshot?.weightPR?.bestSetWeightKg ?? 0
        let previousVolumePR = snapshot?.volumePR?.volumeValue(for: volumePRModePreference) ?? 0
        let previousRepsPR = snapshot?.repsPR?.bestSetReps ?? 0

        // First time doing this exercise - consider it a PR if there's weight.
        if snapshot == nil, currentBestWeight > 0 {
            return .weight
        }

        // Check for weight PR
        if currentBestWeight > previousWeightPR {
            return .weight
        }
        // Check for volume PR
        if currentVolumeMetric > previousVolumePR {
            return .volume
        }
        // Check for rep PR (at same or higher weight)
        if currentBestReps > previousRepsPR && currentBestWeight >= previousWeightPR {
            return .reps
        }

        return nil
    }

    // MARK: - Timer
    // Note: Timer display is handled by TimelineView in the UI for better scroll performance.
    // This view model just tracks pause state and provides elapsedTime calculation.

    func startTimer() {
        // No-op - TimelineView handles UI refresh
        // Keeping method for API compatibility
        isTimerRunning = true
    }

    func pauseTimer() {
        pausedElapsedTimeSnapshot = elapsedTime
        isTimerRunning = false
        pauseStartTime = Date()  // Record when pause started
        updateLiveActivity()
    }

    func resumeTimer() {
        // Add pause duration and clear pause start
        if let pauseStart = pauseStartTime {
            pausedDuration += Date().timeIntervalSince(pauseStart)
            pauseStartTime = nil
        }
        pausedElapsedTimeSnapshot = nil
        isTimerRunning = true
        updateLiveActivity()
    }

    func stopTimer() {
        guard isSetupActive else { return }
        isSetupActive = false

        // Finalize any active pause
        if let pauseStart = pauseStartTime {
            pausedDuration += Date().timeIntervalSince(pauseStart)
            pauseStartTime = nil
        }
        pausedElapsedTimeSnapshot = nil
        isTimerRunning = false
        persistenceCoordinator?.flushNow(trigger: .stopWorkout)
        persistenceCoordinator?.cancelPending()
        pendingLiveActivityUpdateTask?.cancel()
        deferredPerformanceHydrationTask?.cancel()
        deferredSuggestionHydrationTask?.cancel()
        stopHeartRateMonitoring()
        stopLiveActivityUpdates()
        removeLiveActivityObservers()
        unregisterBackgroundFlushObserver()
    }

    // MARK: - Suggestion Management

    /// Add an exercise from a suggestion
    func addExerciseFromSuggestion(_ suggestion: ExerciseSuggestion) {
        let entry = LiveWorkoutEntry(
            exerciseName: suggestion.exerciseName,
            orderIndex: entries.count,
            exerciseType: suggestion.category.rawValue
        )
        entry.targetTags = suggestion.targetTags
        entry.trackingFields = suggestion.trackingFields
        entry.activityTypeName = suggestion.activityTypeName

        if suggestion.category != .strength {
            entry.activityKind = suggestion.category.liveWorkoutActivityKind
            ensureInitialActivitySegment(for: entry)
            appendEntry(entry)
            return
        }

        // Get last performance to pre-fill first set
        let lastPerformance = getLastPerformance(for: suggestion.exerciseName)
        _ = getPersonalRecord(for: suggestion.exerciseName)

        // Use first value from user's rep/weight pattern, or fall back to user's default
        let patternReps = lastPerformance?.repPatternArray.first
        let patternWeight = lastPerformance?.weightPatternArray.first

        let suggestedReps = patternReps ?? lastPerformance?.bestSetReps ?? getUserDefaultRepCount()
        let suggestedWeightKg = patternWeight ?? lastPerformance?.bestSetWeightKg ?? 0
        let cleanWeight = WeightUtility.cleanWeightFromKg(suggestedWeightKg)

        // Start with 1 set - user adds more as needed
        entry.addSet(LiveWorkoutEntry.SetData(
            reps: suggestedReps,
            weight: cleanWeight,
            completed: false,
            isWarmup: false
        ))

        appendEntry(entry)
    }

    /// Add the "Up Next" suggested exercise
    @discardableResult
    func addUpNextExercise() -> Bool {
        guard let suggestion = upNextSuggestion else { return false }
        addExerciseFromSuggestion(suggestion)
        return true
    }

    // MARK: - Exercise Management

    func addExercise(_ exercise: Exercise) {
        let entry = LiveWorkoutEntry(exercise: exercise, orderIndex: entries.count)
        guard exercise.exerciseCategory == .strength else {
            ensureInitialActivitySegment(for: entry)
            appendEntry(entry)
            return
        }

        // Get last performance to pre-fill first set
        let lastPerformance = getLastPerformance(for: exercise.name)
        _ = getPersonalRecord(for: exercise.name)

        // Use first value from user's rep/weight pattern
        let patternReps = lastPerformance?.repPatternArray.first
        let patternWeight = lastPerformance?.weightPatternArray.first

        let suggestedReps = patternReps ?? lastPerformance?.bestSetReps ?? getUserDefaultRepCount()
        let suggestedWeightKg = patternWeight ?? lastPerformance?.bestSetWeightKg ?? 0
        let cleanWeight = WeightUtility.cleanWeightFromKg(suggestedWeightKg)

        // Start with 1 set - user adds more as needed
        entry.addSet(LiveWorkoutEntry.SetData(
            reps: suggestedReps,
            weight: cleanWeight,
            completed: false,
            isWarmup: false
        ))

        appendEntry(entry)
    }

    func addExerciseByName(_ name: String, exerciseType: String = "strength") {
        let category = Exercise.Category.normalized(from: exerciseType) ?? .custom
        let entry = LiveWorkoutEntry(exerciseName: name, orderIndex: entries.count, exerciseType: category.rawValue)
        entry.activityTypeName = Exercise.defaultActivityTypeName(for: name, category: category)
        entry.trackingFields = Exercise.defaultTrackingFields(for: category)
        guard category == .strength else {
            entry.activityKind = category.liveWorkoutActivityKind
            ensureInitialActivitySegment(for: entry)
            appendEntry(entry)
            return
        }

        // Get last performance to pre-fill first set
        let lastPerformance = getLastPerformance(for: name)
        _ = getPersonalRecord(for: name)

        // Use first value from user's rep/weight pattern
        let patternReps = lastPerformance?.repPatternArray.first
        let patternWeight = lastPerformance?.weightPatternArray.first

        let suggestedReps = patternReps ?? lastPerformance?.bestSetReps ?? getUserDefaultRepCount()
        let suggestedWeightKg = patternWeight ?? lastPerformance?.bestSetWeightKg ?? 0
        let cleanWeight = WeightUtility.cleanWeightFromKg(suggestedWeightKg)

        // Start with 1 set - user adds more as needed
        entry.addSet(LiveWorkoutEntry.SetData(
            reps: suggestedReps,
            weight: cleanWeight,
            completed: false,
            isWarmup: false
        ))

        appendEntry(entry)
    }

    private func appendEntry(_ entry: LiveWorkoutEntry) {
        if workout.entries == nil {
            workout.entries = []
        }
        workout.entries?.append(entry)
        markLiveActivityFocusedEntry(entry)
        refreshEntriesAndMetrics()
        saveImmediately()
    }

    private func ensureInitialActivitySegment(for entry: LiveWorkoutEntry) {
        guard !entry.isStrength, entry.activitySegments.isEmpty else { return }
        let segment = LiveWorkoutEntry.ActivitySegment(
            durationSeconds: entry.durationSeconds,
            distanceMeters: entry.distanceMeters,
            reps: entry.sets.first?.reps,
            weightKg: entry.sets.first?.weightKg,
            notes: entry.notes
        )
        entry.activitySegments = [segment]
    }

    func removeExercise(at index: Int) {
        guard index < entries.count else { return }
        let entry = entries[index]
        workout.entries?.removeAll { $0.id == entry.id }

        // Reorder remaining entries
        for (newIndex, entry) in (workout.entries ?? []).enumerated() {
            entry.orderIndex = newIndex
        }

        refreshEntriesAndMetrics()
        saveImmediately()
    }

    /// Replace an existing exercise with a new one, keeping the same position
    func replaceExercise(_ existingEntry: LiveWorkoutEntry, with newExercise: Exercise) {
        let orderIndex = existingEntry.orderIndex

        // Create new entry with the same order index
        let newEntry = LiveWorkoutEntry(exercise: newExercise, orderIndex: orderIndex)
        if newExercise.exerciseCategory != .strength {
            ensureInitialActivitySegment(for: newEntry)
            workout.entries?.removeAll { $0.id == existingEntry.id }
            newEntry.workout = workout
            modelContext?.insert(newEntry)
            workout.entries?.append(newEntry)
            workout.entries?.sort { $0.orderIndex < $1.orderIndex }
            refreshEntriesAndMetrics()
            saveImmediately()
            return
        }

        // Get last performance to pre-fill first set
        let lastPerformance = getLastPerformance(for: newExercise.name)
        _ = getPersonalRecord(for: newExercise.name)
        let patternReps = lastPerformance?.repPatternArray.first
        let patternWeight = lastPerformance?.weightPatternArray.first

        let suggestedReps = patternReps ?? lastPerformance?.bestSetReps ?? getUserDefaultRepCount()
        let suggestedWeightKg = patternWeight ?? lastPerformance?.bestSetWeightKg ?? 0
        let cleanWeight = WeightUtility.cleanWeightFromKg(suggestedWeightKg)

        // Start with 1 set
        newEntry.addSet(LiveWorkoutEntry.SetData(
            reps: suggestedReps,
            weight: cleanWeight,
            completed: false,
            isWarmup: false
        ))

        // Remove old entry and add new one
        workout.entries?.removeAll { $0.id == existingEntry.id }
        newEntry.workout = workout
        modelContext?.insert(newEntry)
        workout.entries?.append(newEntry)

        // Re-sort entries by order index
        workout.entries?.sort { $0.orderIndex < $1.orderIndex }

        refreshEntriesAndMetrics()
        saveImmediately()
    }

    func moveExercise(from source: IndexSet, to destination: Int) {
        var mutableEntries = entries
        mutableEntries.move(fromOffsets: source, toOffset: destination)

        for (index, entry) in mutableEntries.enumerated() {
            entry.orderIndex = index
        }

        refreshEntriesAndMetrics()
        saveImmediately()
    }

    // MARK: - Set Management

    func addSet(to entry: LiveWorkoutEntry) {
        let currentSetIndex = entry.sets.count
        let lastSet = entry.sets.last

        // Check if we have a pattern from last performance
        let lastPerformance = getLastPerformance(for: entry.exerciseName)
        let repPattern = lastPerformance?.repPatternArray ?? []
        let weightPattern = lastPerformance?.weightPatternArray ?? []

        // Suggest next reps/weight based on pattern, or copy last set
        let suggestedReps: Int
        let cleanWeight: CleanWeight

        // For weight: prioritize current workout's last set if user modified it
        // This ensures that if user changes weight mid-workout, subsequent sets follow that weight
        if let lastSet, currentSetIndex > 0 {
            // Check if user changed weight from what the pattern suggested
            let patternWeight = currentSetIndex <= weightPattern.count ? weightPattern[currentSetIndex - 1] : 0
            let userModifiedWeight = abs(lastSet.weightKg - patternWeight) > 0.1

            if userModifiedWeight {
                // User overrode the pattern, follow their lead (use their stored clean values)
                cleanWeight = CleanWeight(kg: lastSet.weightKg, lbs: lastSet.weightLbs)
            } else if currentSetIndex < weightPattern.count {
                // Use pattern weight for this set (pattern is in kg)
                cleanWeight = WeightUtility.cleanWeightFromKg(weightPattern[currentSetIndex])
            } else {
                // Past pattern length, copy last set
                cleanWeight = CleanWeight(kg: lastSet.weightKg, lbs: lastSet.weightLbs)
            }
        } else if currentSetIndex < weightPattern.count {
            cleanWeight = WeightUtility.cleanWeightFromKg(weightPattern[currentSetIndex])
        } else {
            if let lastSet {
                cleanWeight = CleanWeight(kg: lastSet.weightKg, lbs: lastSet.weightLbs)
            } else {
                cleanWeight = .zero
            }
        }

        // For reps: use pattern or copy last set
        if currentSetIndex < repPattern.count {
            suggestedReps = repPattern[currentSetIndex]
        } else {
            suggestedReps = lastSet?.reps ?? getUserDefaultRepCount()
        }

        entry.addSet(LiveWorkoutEntry.SetData(
            reps: suggestedReps,
            weight: cleanWeight,
            completed: false,
            isWarmup: false
        ))
        markLiveActivityFocusedEntry(entry)
        refreshCachedMetrics()
        saveDebounced(updateLiveActivity: true)
    }

    func updateSet(
        at index: Int,
        in entry: LiveWorkoutEntry,
        reps: Int? = nil,
        weightKg: Double? = nil,
        weightLbs: Double? = nil,
        notes: String? = nil,
        preferredWeightUnit: WeightUnit? = nil
    ) {
        let sets = entry.sets
        guard index < sets.count else { return }

        let originalSet = sets[index]
        var set = originalSet
        var didChange = false
        if let reps, reps != set.reps {
            set.reps = reps
            didChange = true
        }
        if let weightKg, weightKg != set.weightKg {
            set.weightKg = weightKg
            didChange = true
        }
        if let weightLbs, weightLbs != set.weightLbs {
            set.weightLbs = weightLbs
            didChange = true
        }
        if let notes, notes != set.notes {
            set.notes = notes
            didChange = true
        }
        if preferredWeightUnit != set.preferredWeightUnit {
            set.preferredWeightUnit = preferredWeightUnit
            didChange = true
        }
        if didChange, !set.isWarmup, !set.completed, set.hasLoggedData {
            set.completed = true
        }
        guard didChange else { return }
        entry.updateSet(at: index, with: set)
        markLiveActivityFocusedEntry(entry)
        if metricsImpactChanged(from: originalSet, to: set) {
            refreshCachedMetrics()
        }
        saveDebounced(updateLiveActivity: true)
    }

    func removeSet(at index: Int, from entry: LiveWorkoutEntry) {
        entry.removeSet(at: index)
        markLiveActivityFocusedEntry(entry)
        refreshCachedMetrics()
        saveImmediately()
    }

    func toggleWarmup(at index: Int, in entry: LiveWorkoutEntry) {
        let sets = entry.sets
        guard index < sets.count else { return }

        var set = sets[index]
        set.isWarmup.toggle()
        entry.updateSet(at: index, with: set)
        markLiveActivityFocusedEntry(entry)
        refreshCachedMetrics()
        saveImmediately()
    }

    // MARK: - Cardio Management

    func updateCardioDuration(for entry: LiveWorkoutEntry, seconds: Int) {
        entry.durationSeconds = seconds
        markLiveActivityFocusedEntry(entry)
        saveDebounced(updateLiveActivity: true)
    }

    func updateCardioDistance(for entry: LiveWorkoutEntry, meters: Double) {
        entry.distanceMeters = meters
        markLiveActivityFocusedEntry(entry)
        saveDebounced(updateLiveActivity: true)
    }

    func updateWorkoutNotes(_ notes: String) {
        guard workout.notes != notes else { return }
        workout.notes = notes
        saveDebounced(updateLiveActivity: false)
    }

    func updateEntryNotes(for entry: LiveWorkoutEntry, notes: String) {
        guard entry.notes != notes else { return }
        entry.notes = notes
        saveDebounced(updateLiveActivity: false)
    }

    func updateEntryDuration(for entry: LiveWorkoutEntry, seconds: Int?) {
        guard entry.durationSeconds != seconds else { return }
        entry.durationSeconds = seconds
        markLiveActivityFocusedEntry(entry)
        saveDebounced(updateLiveActivity: true)
    }

    func updateEntryReps(for entry: LiveWorkoutEntry, reps: Int?) {
        let normalizedReps = max(reps ?? 0, 0)
        var sets = entry.sets
        if sets.isEmpty {
            sets = [
                LiveWorkoutEntry.SetData(
                    reps: normalizedReps,
                    weight: .zero,
                    completed: normalizedReps > 0,
                    isWarmup: false
                )
            ]
        } else {
            var firstSet = sets[0]
            firstSet.reps = normalizedReps
            firstSet.completed = normalizedReps > 0
            sets[0] = firstSet
        }
        entry.sets = sets
        markLiveActivityFocusedEntry(entry)
        refreshEntriesAndMetrics()
        saveDebounced(updateLiveActivity: true)
    }

    func updateEntrySetCount(for entry: LiveWorkoutEntry, count: Int?) {
        let normalizedCount = max(count ?? 0, 0)
        var sets = entry.sets
        if sets.count < normalizedCount {
            let template = sets.last ?? LiveWorkoutEntry.SetData(reps: 0, weight: .zero, completed: false, isWarmup: false)
            for _ in sets.count..<normalizedCount {
                sets.append(
                    LiveWorkoutEntry.SetData(
                        reps: template.reps,
                        weight: CleanWeight(kg: template.weightKg, lbs: template.weightLbs),
                        preferredWeightUnit: template.preferredWeightUnit,
                        completed: template.completed,
                        isWarmup: template.isWarmup,
                        notes: template.notes
                    )
                )
            }
        } else if sets.count > normalizedCount {
            sets = Array(sets.prefix(normalizedCount))
        }
        entry.sets = sets
        markLiveActivityFocusedEntry(entry)
        refreshEntriesAndMetrics()
        saveDebounced(updateLiveActivity: true)
    }

    func updateEntryWeight(for entry: LiveWorkoutEntry, weightKg: Double?) {
        let normalizedWeight = max(weightKg ?? 0, 0)
        var sets = entry.sets
        if sets.isEmpty {
            sets = [
                LiveWorkoutEntry.SetData(
                    reps: 0,
                    weight: WeightUtility.cleanWeightFromKg(normalizedWeight),
                    completed: false,
                    isWarmup: false
                )
            ]
        } else {
            var firstSet = sets[0]
            firstSet.weightKg = normalizedWeight
            firstSet.weightLbs = WeightUtility.round(normalizedWeight * WeightUtility.kgToLbs, unit: .lbs)
            sets[0] = firstSet
        }
        entry.sets = sets
        markLiveActivityFocusedEntry(entry)
        refreshEntriesAndMetrics()
        saveDebounced(updateLiveActivity: true)
    }

    func addActivitySegment(to entry: LiveWorkoutEntry) {
        entry.addActivitySegment()
        markLiveActivityFocusedEntry(entry)
        refreshEntriesAndMetrics()
        saveDebounced(updateLiveActivity: true)
        HapticManager.lightTap()
    }

    func updateActivitySegment(
        for entry: LiveWorkoutEntry,
        at index: Int,
        durationSeconds: Int? = nil,
        distanceMeters: Double? = nil,
        reps: Int? = nil,
        weightKg: Double? = nil,
        notes: String? = nil
    ) {
        var segments = entry.activitySegments
        guard index < segments.count else { return }
        var segment = segments[index]
        if let durationSeconds {
            segment.durationSeconds = max(durationSeconds, 0)
        }
        if let distanceMeters {
            segment.distanceMeters = max(distanceMeters, 0)
        }
        if let reps {
            segment.reps = max(reps, 0)
        }
        if let weightKg {
            segment.weightKg = max(weightKg, 0)
        }
        if let notes {
            segment.notes = notes
        }
        segments[index] = segment
        entry.activitySegments = segments
        syncActivityTotals(from: segments, into: entry)
        markLiveActivityFocusedEntry(entry)
        refreshEntriesAndMetrics()
        saveDebounced(updateLiveActivity: true)
    }

    func removeActivitySegment(from entry: LiveWorkoutEntry, at index: Int) {
        entry.removeActivitySegment(at: index)
        syncActivityTotals(from: entry.activitySegments, into: entry)
        markLiveActivityFocusedEntry(entry)
        refreshEntriesAndMetrics()
        saveDebounced(updateLiveActivity: true)
    }

    private func syncActivityTotals(from segments: [LiveWorkoutEntry.ActivitySegment], into entry: LiveWorkoutEntry) {
        let durations = segments.compactMap(\.durationSeconds).filter { $0 > 0 }
        let distances = segments.compactMap(\.distanceMeters).filter { $0 > 0 }
        entry.durationSeconds = durations.isEmpty ? nil : durations.reduce(0, +)
        entry.distanceMeters = distances.isEmpty ? nil : distances.reduce(0, +)
    }

    func addGeneralActivity(
        name: String,
        notes: String = "",
        durationSeconds: Int? = nil,
        kind: WorkoutPlan.TrainingBlock.BlockKind = .custom,
        role: WorkoutPlan.TrainingBlock.Role = .accessory
    ) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        let entry = LiveWorkoutEntry(
            exerciseName: trimmedName,
            orderIndex: entries.count,
            exerciseType: kind.liveWorkoutExerciseType
        )
        entry.notes = notes
        entry.durationSeconds = durationSeconds
        entry.activityKind = kind
        entry.activityRole = role
        entry.activityTypeName = trimmedName
        entry.targetTags = [trimmedName]
        entry.plannedDurationSeconds = durationSeconds
        entry.trackingFields = Exercise.defaultTrackingFields(for: kind.exerciseCategoryFallback)
        ensureInitialActivitySegment(for: entry)

        if workout.entries == nil {
            workout.entries = []
        }
        workout.entries?.append(entry)
        refreshEntriesAndMetrics()
        saveImmediately()
    }

    // MARK: - Muscle Groups

    func updateMuscleGroups(_ muscles: [LiveWorkout.MuscleGroup]) {
        workout.sourcePlanTemplateID = nil
        workout.muscleGroups = muscles
        if muscles.isEmpty {
            refreshWorkoutTypeFromTargets()
        } else {
            workout.type = .strength
        }
        // Update workout name based on muscles if it's still the default
        if workout.name == "Custom Workout" && !muscles.isEmpty {
            let muscleNames = muscles.sorted { $0.displayName < $1.displayName }
                .prefix(3)
                .map { $0.displayName }
                .joined(separator: " + ")
            workout.name = muscleNames
        }
        rebuildSuggestionPool(reason: .targetMusclesChanged)
        saveImmediately()
    }

    func updateActivityTargets(_ categories: [Exercise.Category]) {
        workout.sourcePlanTemplateID = nil
        let existingFreeformFocus = workout.focusAreas.filter { focus in
            Exercise.Category.allCases.allSatisfy { category in
                !category.suggestionCategories.contains(where: { matched in
                    matched.rawValue.caseInsensitiveCompare(focus) == .orderedSame
                        || matched.displayName.caseInsensitiveCompare(focus) == .orderedSame
                })
            }
        }
        let categoryFocus = Self.visibleActivityFocusLabels(for: categories)
        workout.focusAreas = Self.dedupedFocusAreas(existingFreeformFocus + categoryFocus)
        refreshWorkoutTypeFromTargets()
        if workout.name == "Custom Workout", !categories.isEmpty, workout.muscleGroups.isEmpty {
            workout.name = categories.prefix(2).map(\.displayName).joined(separator: " + ")
        }
        rebuildSuggestionPool(reason: .targetMusclesChanged)
        saveImmediately()
    }

    func updateActivityTypeTargets(_ activityTypes: [String]) {
        workout.sourcePlanTemplateID = nil
        let cleanedActivityTypes = activityTypes
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let broadFocusAreas = workout.focusAreas
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && Self.nonActivityTypeFocusKeys.contains($0.goalNormalizedKey) }
        workout.focusAreas = Self.dedupedFocusAreas(broadFocusAreas + cleanedActivityTypes)
        refreshWorkoutTypeFromTargets()
        if workout.name == "Custom Workout", let first = cleanedActivityTypes.first {
            workout.name = first
        }
        rebuildSuggestionPool(reason: .targetMusclesChanged)
        saveImmediately()
    }

    func applyPlanTarget(
        sourcePlanTemplateID: UUID? = nil,
        name: String,
        muscles: [LiveWorkout.MuscleGroup],
        categories: [Exercise.Category],
        activityTypes: [String] = []
    ) {
        workout.sourcePlanTemplateID = sourcePlanTemplateID
        workout.name = name
        workout.muscleGroups = muscles
        let categoryFocus = Self.visibleActivityFocusLabels(for: categories)
        workout.focusAreas = Self.dedupedFocusAreas(categoryFocus + activityTypes)
        rebuildSuggestionPool(reason: .targetMusclesChanged)
        saveImmediately()
    }

    private func refreshWorkoutTypeFromTargets() {
        if !workout.muscleGroups.isEmpty {
            workout.type = .strength
            return
        }

        workout.type = Self.workoutMode(for: categoriesFromFocusAreas())
    }

    private static func workoutMode(for categories: Set<Exercise.Category>) -> WorkoutMode {
        guard !categories.isEmpty else { return .custom }
        let expandedCategories = categories.reduce(into: Set<Exercise.Category>()) { result, category in
            result.formUnion(category.suggestionCategories)
        }

        if expandedCategories.contains(.cardio) { return .cardio }
        if expandedCategories.contains(.conditioning) { return .hiit }
        if expandedCategories.contains(.mobility) || expandedCategories.contains(.flexibility) { return .mobility }
        if expandedCategories.contains(.recovery) { return .recovery }
        if expandedCategories.contains(.strength) { return .strength }
        return .custom
    }

    private static func visibleActivityFocusLabels(for categories: [Exercise.Category]) -> [String] {
        var seen = Set<String>()
        return categories.compactMap { category in
            let label = category.userFacingEquivalent.displayName
            guard seen.insert(label.goalNormalizedKey).inserted else { return nil }
            return label
        }
    }

    private static func dedupedFocusAreas(_ focusAreas: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for focusArea in focusAreas {
            let trimmed = focusArea.trimmingCharacters(in: .whitespacesAndNewlines)
            let key = trimmed.goalNormalizedKey
            guard !trimmed.isEmpty, !key.isEmpty, seen.insert(key).inserted else { continue }
            result.append(trimmed)
        }
        return result
    }

    // MARK: - Workout Completion

    @discardableResult
    func finishWorkout() -> Error? {
        guard !isFinishingWorkout else { return nil }
        guard workout.completedAt == nil else { return nil }

        isFinishingWorkout = true
        defer { isFinishingWorkout = false }

        workout.completedAt = Date()

        for entry in entries {
            if (entry.isCardio || entry.isGeneralActivity)
                && !entry.isPlannedActivityGuidance
                && entry.hasExercisePreferenceSignal {
                entry.completedAt = entry.completedAt ?? Date()
            }
        }
        refreshEntriesAndMetrics()

        // Create ExerciseHistory entries for each exercise
        achievedPRs = [:]
        createExerciseHistoryEntries()

        if let modelContext {
            BehaviorTracker(modelContext: modelContext).record(
                actionKey: BehaviorActionKey.completeWorkout,
                domain: .workout,
                surface: .workouts,
                outcome: .completed,
                relatedEntityId: workout.id,
                metadata: [
                    "workout_name": workout.name,
                    "workout_type": workout.workoutType
                ],
                saveImmediately: false
            )
        }

        if let error = saveImmediately(updateLiveActivity: false, trigger: .finishWorkout) {
            modelContext?.rollback()
            achievedPRs = [:]
            refreshEntriesAndMetrics()
            return error
        }

        stopTimer()

        // Try to merge with overlapping Apple Watch workout
        Task {
            await mergeWithAppleWatchWorkout()
        }

        // Note: Workout saving to HealthKit removed - Apple Watch automatically saves workouts

        // End Live Activity when the workout completes.
        liveActivityManager.endActivity(showSummary: false)

        // Notify dashboard to refresh muscle recovery
        NotificationCenter.default.post(
            name: .workoutCompleted,
            object: nil,
            userInfo: ["workoutId": workout.id]
        )
        WidgetDataProvider.shared.scheduleRefresh()
        return nil
    }

    /// Get user's preferred default rep count from their profile
    private func getUserDefaultRepCount() -> Int {
        guard let modelContext else { return 10 }
        var descriptor = FetchDescriptor<UserProfile>()
        descriptor.fetchLimit = 1
        if let profile = try? modelContext.fetch(descriptor).first {
            return profile.defaultRepCount
        }
        return 10 // Fallback default
    }

    /// Get user's weight unit preference from their profile
    private func getUserUsesMetricWeight() -> Bool {
        guard let modelContext else { return true }
        var descriptor = FetchDescriptor<UserProfile>()
        descriptor.fetchLimit = 1
        if let profile = try? modelContext.fetch(descriptor).first {
            return profile.usesMetricExerciseWeight
        }
        return true // Fallback default (metric)
    }

    /// Get user's volume PR mode preference from their profile
    private func getUserVolumePRMode() -> UserProfile.VolumePRMode {
        guard let modelContext else { return .perSet }
        var descriptor = FetchDescriptor<UserProfile>()
        descriptor.fetchLimit = 1
        if let profile = try? modelContext.fetch(descriptor).first {
            return profile.volumePRModeValue
        }
        return .perSet
    }

    private func volumeValue(totalVolume: Double, setCount: Int) -> Double {
        switch volumePRModePreference {
        case .perSet:
            return totalVolume / Double(max(setCount, 1))
        case .totalVolume:
            return totalVolume
        }
    }

    @discardableResult
    func cancelWorkout(using modelContext: ModelContext) -> Bool {
        self.modelContext = modelContext
        guard LiveWorkoutCancellation.cancelActiveWorkouts(in: modelContext, including: workout) else {
            return false
        }

        stopTimer()
        liveActivityManager.endActivity(showSummary: false)
        return true
    }

    // MARK: - Private Methods

    private func refreshEntriesAndMetrics(forceSuggestionRefresh: Bool = false) {
        let sortedEntries = (workout.entries ?? []).sorted { $0.orderIndex < $1.orderIndex }
        if entryListSignature(for: sortedEntries) != entryListSignature(for: cachedEntries) {
            cachedEntries = sortedEntries
        }
        updateCachedMetrics(calculateMetrics(for: sortedEntries))
        let updatedExerciseNameSet = Set(sortedEntries.map { $0.exerciseName.lowercased() })
        let exerciseListChanged = updatedExerciseNameSet != cachedCurrentExerciseNameSet
        cachedCurrentExerciseNameSet = updatedExerciseNameSet

        if forceSuggestionRefresh || exerciseListChanged {
            recomputeSuggestionRankings()
        }
    }

    private func refreshCachedMetrics() {
        updateCachedMetrics(calculateMetrics(for: cachedEntries))
    }

    private func updateCachedMetrics(_ metrics: WorkoutMetrics) {
        guard metrics != cachedMetrics else { return }
        cachedMetrics = metrics
    }

    private func entryListSignature(for entries: [LiveWorkoutEntry]) -> [EntryListSignature] {
        entries.map {
            EntryListSignature(
                id: $0.id,
                orderIndex: $0.orderIndex,
                exerciseName: $0.exerciseName
            )
        }
    }

    private func metricsImpactChanged(
        from originalSet: LiveWorkoutEntry.SetData,
        to updatedSet: LiveWorkoutEntry.SetData
    ) -> Bool {
        let originalHasData = originalSet.completed && originalSet.reps > 0 && !originalSet.isWarmup
        let updatedHasData = updatedSet.completed && updatedSet.reps > 0 && !updatedSet.isWarmup
        guard originalHasData == updatedHasData else { return true }

        let originalVolume = originalSet.completed && !originalSet.isWarmup ? originalSet.volume : 0
        let updatedVolume = updatedSet.completed && !updatedSet.isWarmup ? updatedSet.volume : 0
        return originalVolume != updatedVolume
    }

    private func calculateMetrics(for entries: [LiveWorkoutEntry]) -> WorkoutMetrics {
        var totalSets = 0
        var completedSetsWithData = 0
        var totalVolume = 0.0

        for entry in entries {
            let sets = entry.sets
            totalSets += sets.count
            for set in sets where !set.isWarmup {
                if set.completed && set.reps > 0 {
                    completedSetsWithData += 1
                }
                if set.completed && set.reps > 0 {
                    totalVolume += set.volume
                }
            }
        }

        return WorkoutMetrics(
            totalSets: totalSets,
            completedSets: completedSetsWithData,
            totalVolume: totalVolume
        )
    }

    private func createExerciseHistoryEntries() {
        guard let modelContext else { return }
        let performedAt = workout.completedAt ?? Date()
        let historyWindowStart = workout.startedAt.addingTimeInterval(-60)
        let historyWindowEnd = performedAt.addingTimeInterval(60)
        let historyDescriptor = FetchDescriptor<ExerciseHistory>(
            predicate: #Predicate<ExerciseHistory> { history in
                history.performedAt >= historyWindowStart && history.performedAt <= historyWindowEnd
            }
        )
        let existingHistories = (try? modelContext.fetch(historyDescriptor)) ?? []
        let historiesToInsert = ExerciseHistory.recordsToInsert(
            from: workout,
            existingHistories: existingHistories,
            performedAt: performedAt
        )

        for history in historiesToInsert {
            guard history.hasStrengthMetrics else { continue }

            // Check for PRs against canonical per-metric records.
            let previousSnapshot = getPerformanceSnapshot(for: history.exerciseName)
            let previousWeight = previousSnapshot?.weightPR?.bestSetWeightKg ?? 0
            let previousVolume = previousSnapshot?.volumePR?.volumeValue(for: volumePRModePreference) ?? 0
            let previousReps = Double(previousSnapshot?.repsPR?.bestSetReps ?? 0)
            let hasHistory = (previousSnapshot?.totalSessions ?? 0) > 0
            let currentVolume = history.volumeValue(for: volumePRModePreference)

            if history.bestSetWeightKg > previousWeight {
                achievedPRs[history.exerciseName] = PRValue(
                    type: .weight,
                    exerciseName: history.exerciseName,
                    newValue: history.bestSetWeightKg,
                    previousValue: previousWeight,
                    isFirstTime: !hasHistory || previousWeight <= 0,
                    volumePRMode: volumePRModePreference
                )
            }
            // Volume PR (only if no weight PR already detected)
            else if currentVolume > previousVolume,
                    achievedPRs[history.exerciseName] == nil {
                achievedPRs[history.exerciseName] = PRValue(
                    type: .volume,
                    exerciseName: history.exerciseName,
                    newValue: currentVolume,
                    previousValue: previousVolume,
                    isFirstTime: false,
                    volumePRMode: volumePRModePreference
                )
            }
            // Rep PR (only if nothing else detected)
            else if Double(history.bestSetReps) > previousReps,
                    achievedPRs[history.exerciseName] == nil {
                achievedPRs[history.exerciseName] = PRValue(
                    type: .reps,
                    exerciseName: history.exerciseName,
                    newValue: Double(history.bestSetReps),
                    previousValue: previousReps,
                    isFirstTime: false,
                    volumePRMode: volumePRModePreference
                )
            }

            modelContext.insert(history)
            clearPerformanceCache(for: history.exerciseName)
        }

        for history in historiesToInsert where !history.hasStrengthMetrics {
            modelContext.insert(history)
            clearPerformanceCache(for: history.exerciseName)
        }
    }

    func save() {
        _ = saveImmediately()
    }

    @discardableResult
    private func saveImmediately(
        updateLiveActivity: Bool = true,
        trigger: LiveWorkoutPersistenceCoordinator.FlushTrigger = .manual
    ) -> Error? {
        let saveError: Error?
        if let persistenceCoordinator {
            saveError = persistenceCoordinator.flushNow(trigger: trigger)
        } else {
            do {
                try modelContext?.save()
                saveError = nil
            } catch {
                saveError = error
            }
        }
        if updateLiveActivity {
            scheduleLiveActivityUpdate()
        }
        return saveError
    }

    private func saveDebounced(updateLiveActivity: Bool = true) {
        if let persistenceCoordinator {
            persistenceCoordinator.requestSave()
        } else {
            try? modelContext?.save()
        }
        if updateLiveActivity {
            scheduleLiveActivityUpdate()
        }
    }

    private func scheduleLiveActivityUpdate() {
        pendingLiveActivityUpdateTask?.cancel()
        pendingLiveActivityUpdateTask = Task { @MainActor [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: self.liveActivityDebounceDelay)
            self.updateLiveActivity()
        }
    }

    // MARK: - Live Activity

    private func startLiveActivity() {
        liveActivityManager.startActivity(
            workoutName: workoutName,
            targetMuscles: targetMuscleGroups,
            startedAt: workout.startedAt
        )
        updateLiveActivity()
    }

    private func stopLiveActivityUpdates() {
        liveActivityUpdateTimer?.invalidate()
        liveActivityUpdateTimer = nil
    }

    private func hasLoggedSetData(_ set: LiveWorkoutEntry.SetData) -> Bool {
        set.reps > 0
    }

    private func isEntryComplete(_ entry: LiveWorkoutEntry) -> Bool {
        if entry.isCardio || entry.isGeneralActivity {
            return entry.completedAt != nil || entry.hasExercisePreferenceSignal
        }

        let workingSets = entry.sets.filter { !$0.isWarmup }
        guard !workingSets.isEmpty else { return false }
        return workingSets.allSatisfy(\.completed)
    }

    private func isEntryStartedForLiveActivity(_ entry: LiveWorkoutEntry) -> Bool {
        if entry.isCardio || entry.isGeneralActivity {
            return entry.completedAt != nil
                || entry.trackedDurationSeconds > 0
                || entry.trackedDistanceMeters > 0
                || entry.activitySegments.contains { $0.hasLoggedData }
                || !entry.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return entry.sets.contains { !$0.isWarmup && $0.completed && hasLoggedSetData($0) }
    }

    private func isEntryCompleteForLiveActivity(_ entry: LiveWorkoutEntry) -> Bool {
        isEntryComplete(entry)
    }

    private func markLiveActivityFocusedEntry(_ entry: LiveWorkoutEntry) {
        liveActivityFocusedEntryID = entry.id
    }

    private func liveActivityCurrentEntry() -> LiveWorkoutEntry? {
        if let liveActivityFocusedEntryID,
           let focusedEntry = entries.first(where: { $0.id == liveActivityFocusedEntryID }) {
            if !isEntryCompleteForLiveActivity(focusedEntry) {
                return focusedEntry
            }
            self.liveActivityFocusedEntryID = nil
        }

        return entries.last(where: isEntryStartedForLiveActivity)
            ?? entries.last
    }

    private func liveActivityEntryForAddSet() -> LiveWorkoutEntry? {
        if let currentEntry = liveActivityCurrentEntry(), currentEntry.isStrength {
            return currentEntry
        }

        // If the current exercise is timed/general work, route "Add Set" to a real strength entry.
        return entries.first { $0.isStrength && !isEntryCompleteForLiveActivity($0) }
            ?? entries.last(where: \.isStrength)
    }

    var liveActivityProgressSummary: LiveActivityProgressSummary {
        liveActivityProgress()
    }

    private func shouldCountEntryForLiveActivityProgress(_ entry: LiveWorkoutEntry) -> Bool {
        entry.isStrength || !entry.isPlannedActivityGuidance
    }

    private func liveActivityProgress() -> LiveActivityProgressSummary {
        let currentEntry = liveActivityCurrentEntry()
        let supportsSetShortcut = currentEntry?.isStrength == true
        let usesItemProgress = entries.contains { $0.isCardio || $0.isGeneralActivity }

        if usesItemProgress {
            let countableEntries = entries.filter(shouldCountEntryForLiveActivityProgress)
            let progressEntries = countableEntries.isEmpty
                ? entries.filter { $0.isCardio || $0.isGeneralActivity }
                : countableEntries
            let loggedExercises = progressEntries.filter { entry in
                entry.isStrength
                    ? isEntryCompleteForLiveActivity(entry)
                    : isEntryStartedForLiveActivity(entry)
            }.count
            let label = loggedExercises == 1 ? "exercise" : "exercises"
            return LiveActivityProgressSummary(
                completed: loggedExercises,
                total: 0,
                label: label,
                supportsSetShortcut: supportsSetShortcut
            )
        }

        let label = completedSets == 1 ? "set" : "sets"
        return LiveActivityProgressSummary(
            completed: completedSets,
            total: 0,
            label: label,
            supportsSetShortcut: supportsSetShortcut
        )
    }

    private func liveActivityCurrentDetail(for entry: LiveWorkoutEntry?) -> String? {
        guard let entry, !entry.isStrength else { return nil }
        let loggedSegments = entry.traiActivitySummarySegments(usesMetric: usesMetricWeightPreference)
        let baseSegments = loggedSegments.isEmpty
            ? entry.plannedActivitySummarySegments
            : loggedSegments
        let segments = baseSegments
            .filter { $0.goalNormalizedKey != entry.activityTypeName.goalNormalizedKey }
        guard !segments.isEmpty else { return nil }
        return segments.prefix(3).joined(separator: " • ")
    }

    private func updateLiveActivity() {
        // Track progression from logged data (or cardio completion), not the legacy set.completed flag.
        let currentEntry = liveActivityCurrentEntry()
        let progress = liveActivityProgress()

        let currentExercise = currentEntry?.exerciseName
        let currentEquipment = currentEntry?.equipmentName
        let currentDetail = liveActivityCurrentDetail(for: currentEntry)

        // Prefer the next planned working set so the activity reflects what the user is doing now.
        // Use both kg and lbs values to avoid rounding errors (200 lbs → 199 bug)
        let currentSet = currentEntry?.sets.first { !$0.isWarmup && !$0.completed && hasLoggedSetData($0) }
            ?? currentEntry?.sets.last { !$0.isWarmup && $0.completed && hasLoggedSetData($0) }
            ?? currentEntry?.sets.first { !$0.isWarmup && hasLoggedSetData($0) }
            ?? currentEntry?.sets.last { $0.completed && hasLoggedSetData($0) }
            ?? currentEntry?.sets.first { hasLoggedSetData($0) }
        let currentWeightKg = currentSet?.weightKg
        let currentWeightLbs = currentSet?.weightLbs
        let currentReps = currentSet?.reps
        let currentWorkingSets = currentEntry?.sets.filter { !$0.isWarmup } ?? []
        let loggedCurrentSets = currentWorkingSets.filter { $0.completed && hasLoggedSetData($0) }.count
        let currentExerciseCompletedSets = currentEntry?.isStrength == true ? loggedCurrentSets : nil
        let currentExerciseTotalSets = currentEntry?.isStrength == true
            ? max(currentWorkingSets.count, loggedCurrentSets + 1, 1)
            : nil

        let liveActivityEntries = entries.filter(shouldCountEntryForLiveActivityProgress)
        let currentExerciseIndex = liveActivityEntries.firstIndex { $0.id == currentEntry?.id }.map { $0 + 1 }
        let exerciseTotal = liveActivityEntries.count

        // Calculate total volume in both units
        let totalVolumeKg = totalVolume
        let totalVolumeLbs = totalVolume * 2.20462

        // Find the next exercise from an existing planned entry, or fall back to
        // the same Up Next recommendation shown in the workout view.
        let currentIndex = entries.firstIndex { $0.id == currentEntry?.id } ?? -1
        let nextExercise = entries.dropFirst(currentIndex + 1)
            .first { !isEntryStartedForLiveActivity($0) }?
            .exerciseName
            ?? upNextSuggestion?.exerciseName

        liveActivityManager.updateActivity(
            elapsedSeconds: Int(elapsedTime),
            currentExercise: currentExercise,
            currentEquipment: currentEquipment,
            currentDetail: currentDetail,
            completedSets: completedSets,
            totalSets: totalSets,
            heartRate: currentHeartRate.map { Int($0) },
            isPaused: !isTimerRunning,
            currentWeightKg: currentWeightKg,
            currentWeightLbs: currentWeightLbs,
            currentReps: currentReps,
            totalVolumeKg: totalVolumeKg,
            totalVolumeLbs: totalVolumeLbs,
            nextExercise: nextExercise,
            usesMetricWeight: usesMetricWeightPreference,
            progressCompleted: progress.completed,
            progressTotal: progress.total,
            progressLabel: progress.label,
            supportsSetShortcut: progress.supportsSetShortcut,
            currentExerciseCompletedSets: currentExerciseCompletedSets,
            currentExerciseTotalSets: currentExerciseTotalSets,
            currentExerciseIndex: currentExerciseIndex,
            exerciseTotal: exerciseTotal
        )
    }
}

@MainActor
enum LiveWorkoutCancellation {
    @discardableResult
    static func cancelActiveWorkouts(
        in modelContext: ModelContext,
        including workout: LiveWorkout? = nil
    ) -> Bool {
        let activeWorkoutDescriptor = FetchDescriptor<LiveWorkout>(
            predicate: #Predicate<LiveWorkout> { candidate in
                candidate.completedAt == nil
            }
        )
        var workoutsToDelete = (try? modelContext.fetch(activeWorkoutDescriptor)) ?? []
        if let workout, !workoutsToDelete.contains(where: { $0.id == workout.id }) {
            workoutsToDelete.append(workout)
        }

        for workoutToDelete in workoutsToDelete {
            workoutToDelete.completedAt = workoutToDelete.completedAt ?? Date()
            modelContext.delete(workoutToDelete)
        }

        do {
            try modelContext.save()
            return true
        } catch {
            modelContext.rollback()
            return false
        }
    }
}
