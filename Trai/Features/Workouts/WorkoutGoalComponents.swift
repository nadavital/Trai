//
//  WorkoutGoalComponents.swift
//  Trai
//

import SwiftUI
import SwiftData

struct WorkoutGoalInsight: Identifiable {
    let goal: WorkoutGoal
    let progressText: String
    let supportingText: String?
    let progressFraction: Double?
    let currentValueText: String?
    let targetValueText: String?
    let baselineValueText: String?
    let recurringProgress: WorkoutGoalRecurringProgress?

    var id: UUID { goal.id }

    var cardProgressFraction: Double? {
        if goal.status == .completed {
            return 1
        }
        if let currentPeriod = recurringProgress?.currentPeriod {
            return currentPeriod.targetFraction
        }
        return progressFraction
    }

    init(
        goal: WorkoutGoal,
        progressText: String,
        supportingText: String?,
        progressFraction: Double?,
        currentValueText: String?,
        targetValueText: String?,
        baselineValueText: String? = nil,
        recurringProgress: WorkoutGoalRecurringProgress? = nil
    ) {
        self.goal = goal
        self.progressText = progressText
        self.supportingText = supportingText
        self.progressFraction = progressFraction
        self.currentValueText = currentValueText
        self.targetValueText = targetValueText
        self.baselineValueText = baselineValueText
        self.recurringProgress = recurringProgress
    }
}

extension WorkoutGoalInsight {
    var goalCardSubtitle: String {
        if let recurringProgress {
            return recurringProgress.cardSubtitle
        }
        if goal.status == .completed {
            return "Completed"
        }
        return progressText
    }
}

struct WorkoutGoalRecurringProgress {
    let periodUnit: WorkoutGoal.PeriodUnit
    let periods: [WorkoutGoalPeriodSnapshot]
    let historyPeriods: [WorkoutGoalPeriodSnapshot]
    let isOpenEnded: Bool

    private var trackedPeriods: [WorkoutGoalPeriodSnapshot] {
        periods.filter { !$0.isBeforeGoalStart }
    }

    private var historyTrackedPeriods: [WorkoutGoalPeriodSnapshot] {
        historyPeriods.filter { !$0.isBeforeGoalStart }
    }

    var totalPeriodCount: Int {
        isOpenEnded ? trackedPeriods.count : historyTrackedPeriods.count
    }

    var completedPeriodCount: Int {
        let sourcePeriods = isOpenEnded ? trackedPeriods : historyTrackedPeriods
        return sourcePeriods.filter(\.isTargetMet).count
    }

    var historyPeriodCount: Int { historyTrackedPeriods.count }

    var historyCompletedPeriodCount: Int {
        historyTrackedPeriods.filter(\.isTargetMet).count
    }

    var historyMissedPeriodCount: Int {
        historyTrackedPeriods.filter { !$0.isFuture && !$0.isCurrent && !$0.isTargetMet }.count
    }

    var currentPeriod: WorkoutGoalPeriodSnapshot? {
        historyPeriods.first(where: \.isCurrent) ?? periods.first(where: \.isCurrent)
    }

    var isComplete: Bool {
        !isOpenEnded && !historyTrackedPeriods.isEmpty && historyTrackedPeriods.allSatisfy(\.isTargetMet)
    }

    var streakCount: Int {
        guard isOpenEnded else { return 0 }
        return Self.currentStreakCount(in: historyTrackedPeriods)
    }

    var bestStreakCount: Int {
        Self.bestStreakCount(in: historyTrackedPeriods)
    }

    var bestStreakText: String {
        guard bestStreakCount > 0 else { return "No streak yet" }
        return "\(bestStreakCount) \(periodLabel) best"
    }

    var completionRateText: String {
        guard historyPeriodCount > 0 else { return "0%" }
        let rate = Double(historyCompletedPeriodCount) / Double(historyPeriodCount)
        return "\(Int((rate * 100).rounded()))%"
    }

    var hasExtendedHistory: Bool {
        isOpenEnded && historyTrackedPeriods.count > trackedPeriods.count
    }

    var historySummaryText: String {
        "\(historyCompletedPeriodCount) of \(historyPeriodCount) \(periodLabelPlural) hit"
    }

    var historyRangeText: String? {
        rangeText(for: historyPeriods)
    }

    var startedText: String? {
        guard let firstPeriod = historyTrackedPeriods.first else { return nil }
        return "Started \(firstPeriod.effectiveStartDate.formatted(.dateTime.month(.abbreviated).day().year()))"
    }

    private static func currentStreakCount(in periods: [WorkoutGoalPeriodSnapshot]) -> Int {
        var count = 0
        for period in periods.reversed() {
            guard !period.isFuture else { continue }
            guard !period.isBeforeGoalStart else { break }
            if period.isCurrent, !period.isTargetMet {
                continue
            }
            guard period.isTargetMet else { break }
            count += 1
        }
        return count
    }

    private static func bestStreakCount(in periods: [WorkoutGoalPeriodSnapshot]) -> Int {
        var current = 0
        var best = 0
        for period in periods where !period.isFuture {
            if period.isTargetMet {
                current += 1
                best = max(best, current)
            } else {
                current = 0
            }
        }
        return best
    }

    var streakText: String {
        guard streakCount > 0 else { return "Start a \(periodLabel) streak" }
        return "\(streakCount) \(periodLabel) streak"
    }

    var displayProgressFraction: Double {
        let sourcePeriods = isOpenEnded ? trackedPeriods : historyTrackedPeriods
        guard !sourcePeriods.isEmpty else { return 0 }
        let completedPeriods = sourcePeriods.filter { !$0.isCurrent && $0.isTargetMet }.count
        let currentFraction = currentPeriod?.targetFraction ?? 0
        return min(max((Double(completedPeriods) + currentFraction) / Double(max(sourcePeriods.count, 1)), 0), 1)
    }

    var periodLabel: String {
        switch periodUnit {
        case .day: "day"
        case .week: "week"
        case .month: "month"
        }
    }

    var periodLabelPlural: String {
        switch periodUnit {
        case .day: "days"
        case .week: "weeks"
        case .month: "months"
        }
    }

    var summaryText: String {
        if isOpenEnded {
            return streakText
        }
        return "\(completedPeriodCount) of \(totalPeriodCount) \(periodLabelPlural) hit"
    }

    var currentPeriodText: String {
        guard let currentPeriod else { return summaryText }
        if currentPeriod.isCurrent {
            return "\(currentPeriodTitle): \(currentPeriod.currentCount) of \(currentPeriod.targetCount)"
        }
        return "\(periodLabel.capitalized) \(currentPeriod.index): \(currentPeriod.currentCount) of \(currentPeriod.targetCount)"
    }

    var currentPeriodTitle: String {
        guard let currentPeriod else { return periodLabel.capitalized }
        if currentPeriod.isCurrent {
            if periodUnit == .day {
                return "Today"
            }
            return "This \(periodLabel)"
        }
        return "\(periodLabel.capitalized) \(currentPeriod.index)"
    }

    var detailSummaryText: String {
        if isOpenEnded {
            return streakCount > 0 ? streakText : recentHistoryText
        }
        if isComplete {
            return "All \(totalPeriodCount) \(periodLabelPlural) hit"
        }
        return summaryText
    }

    var patternTitle: String {
        if isOpenEnded {
            return "Habit pattern"
        }
        return "\(totalPeriodCount)-\(periodLabel) goal"
    }

    var cardSubtitle: String {
        if isOpenEnded {
            if let currentPeriod {
                return "\(currentPeriod.currentCount)/\(currentPeriod.targetCount) this \(periodLabel)"
            }
            return "\(completedPeriodCount) of last \(totalPeriodCount) \(periodLabelPlural) hit"
        }
        if isComplete {
            return "All \(totalPeriodCount) \(periodLabelPlural) hit"
        }
        if let currentPeriod {
            return "\(currentPeriod.currentCount)/\(currentPeriod.targetCount) now • \(summaryText)"
        }
        return summaryText
    }

    var recentHistoryText: String {
        "\(completedPeriodCount) of last \(totalPeriodCount) \(periodLabelPlural) hit"
    }

    var timelineRangeText: String? {
        rangeText(for: periods)
    }

    func visiblePeriods(limit: Int) -> [WorkoutGoalPeriodSnapshot] {
        guard periods.count > limit else { return periods }
        return Array(periods.suffix(limit))
    }

    func historyPeriods(limit: Int?) -> [WorkoutGoalPeriodSnapshot] {
        guard let limit, historyPeriods.count > limit else { return historyPeriods }
        return Array(historyPeriods.suffix(limit))
    }

    private func rangeText(for periods: [WorkoutGoalPeriodSnapshot]) -> String? {
        guard let firstPeriod = periods.first,
              let lastPeriod = periods.last else {
            return nil
        }

        let startText = firstPeriod.startDate.formatted(.dateTime.month(.abbreviated).day())
        let endText = lastPeriod.isCurrent
            ? "Today"
            : lastPeriod.endDate.formatted(.dateTime.month(.abbreviated).day())
        return "\(startText) - \(endText)"
    }
}

struct WorkoutGoalPeriodSnapshot: Identifiable {
    let index: Int
    let startDate: Date
    let endDate: Date
    let effectiveStartDate: Date
    let currentCount: Int
    let targetCount: Int
    let isCurrent: Bool
    let isFuture: Bool
    let isBeforeGoalStart: Bool

    init(
        index: Int,
        startDate: Date,
        endDate: Date,
        effectiveStartDate: Date,
        currentCount: Int,
        targetCount: Int,
        isCurrent: Bool,
        isFuture: Bool,
        isBeforeGoalStart: Bool = false
    ) {
        self.index = index
        self.startDate = startDate
        self.endDate = endDate
        self.effectiveStartDate = effectiveStartDate
        self.currentCount = currentCount
        self.targetCount = targetCount
        self.isCurrent = isCurrent
        self.isFuture = isFuture
        self.isBeforeGoalStart = isBeforeGoalStart
    }

    var id: String { "\(index)-\(startDate.timeIntervalSinceReferenceDate)" }

    var isTargetMet: Bool {
        currentCount >= targetCount
    }

    var targetFraction: Double {
        guard targetCount > 0 else { return 0 }
        return min(max(Double(currentCount) / Double(targetCount), 0), 1)
    }

    func accessibilitySummary(periodLabel: String) -> String {
        let state: String
        if isTargetMet {
            state = "hit"
        } else if isCurrent {
            state = "in progress"
        } else if isBeforeGoalStart {
            state = "before goal started"
        } else if isFuture {
            state = "upcoming"
        } else {
            state = "missed"
        }
        return "\(periodLabel) \(index), \(currentCount) of \(targetCount), \(state)"
    }
}

struct RecentWorkoutSignal: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let note: String
    let date: Date
}

enum WorkoutGoalProgressResolver {
    static func relevantGoals(
        for workout: LiveWorkout,
        goals: [WorkoutGoal],
        includeCompleted: Bool = true
    ) -> [WorkoutGoal] {
        goals
            .filter { goal in
                let matchesWorkout: Bool
                if goal.hasGeneratedPlanTemplateScope && !goal.hasGeneratedPlanBlockScope {
                    matchesWorkout = goal.matchesGeneratedPlanTemplate(workout: workout)
                        && (workout.completedAt == nil || hasLoggedGeneratedPlanProgress(in: workout))
                } else {
                    matchesWorkout = goal.matches(workout: workout)
                }
                return matchesWorkout && (includeCompleted || goal.isActive)
            }
            .sorted { lhs, rhs in
                if lhs.status != rhs.status {
                    return lhs.status == .active
                }
                return lhs.createdAt > rhs.createdAt
            }
    }

    static func insights(
        for workout: LiveWorkout,
        goals: [WorkoutGoal],
        workouts: [LiveWorkout],
        sessions: [WorkoutSession] = [],
        exerciseHistory: [ExerciseHistory],
        useLbs: Bool
    ) -> [WorkoutGoalInsight] {
        insights(
            goals: relevantGoals(for: workout, goals: goals),
            workouts: workouts,
            sessions: sessions,
            exerciseHistory: exerciseHistory,
            useLbs: useLbs
        )
    }

    static func insights(
        goals: [WorkoutGoal],
        workouts: [LiveWorkout],
        sessions: [WorkoutSession] = [],
        exerciseHistory: [ExerciseHistory],
        useLbs: Bool
    ) -> [WorkoutGoalInsight] {
        goals.map {
            insight(
                for: $0,
                workouts: workouts,
                sessions: sessions,
                exerciseHistory: exerciseHistory,
                useLbs: useLbs
            )
        }
    }

    static func recentSignals(
        for workout: LiveWorkout,
        workouts: [LiveWorkout],
        sessions: [WorkoutSession] = []
    ) -> [RecentWorkoutSignal] {
        let currentFocus = Set(workout.focusAreas.map(\.goalNormalizedKey))
        let currentActivities = workoutActivityTokens(workout)

        let liveSignals: [RecentWorkoutSignal] = workouts
            .filter { candidate in
                candidate.id != workout.id && candidate.completedAt != nil
            }
            .filter { candidate in
                if candidate.type == workout.type {
                    return true
                }

                let candidateActivities = workoutActivityTokens(candidate)
                return !candidateActivities.isDisjoint(with: currentActivities)
            }
            .compactMap { candidate -> RecentWorkoutSignal? in
                guard let note = latestNote(in: candidate), !note.isEmpty else { return nil }
                let subtitle = candidate.workoutContextSummarySegments.joined(separator: " • ")

                return RecentWorkoutSignal(
                    title: candidate.name,
                    subtitle: subtitle,
                    note: note,
                    date: candidate.completedAt ?? candidate.startedAt
                )
            }
            .sorted { $0.date > $1.date }

        let sessionSignals = sessions
            .filter { candidate in
                if candidate.inferredWorkoutMode == workout.type {
                    return true
                }

                let candidateTokens = candidate.goalMatchingTokens
                if !candidateTokens.isDisjoint(with: currentActivities) {
                    return true
                }

                return candidateTokens.contains(where: { currentFocus.contains($0) })
            }
            .compactMap { signal(from: $0) }

        return Array((liveSignals + sessionSignals)
            .sorted { $0.date > $1.date }
            .prefix(3))
    }

    static func globalRecentSignals(
        from workouts: [LiveWorkout],
        sessions: [WorkoutSession] = []
    ) -> [RecentWorkoutSignal] {
        let liveSignals: [RecentWorkoutSignal] = workouts
            .filter { $0.completedAt != nil }
            .compactMap { workout -> RecentWorkoutSignal? in
                guard let note = latestNote(in: workout), !note.isEmpty else { return nil }
                let subtitle = workout.workoutContextSummarySegments.joined(separator: " • ")

                return RecentWorkoutSignal(
                    title: workout.name,
                    subtitle: subtitle,
                    note: note,
                    date: workout.completedAt ?? workout.startedAt
                )
            }

        let sessionSignals = sessions.compactMap { signal(from: $0) }

        return Array((liveSignals + sessionSignals)
            .sorted { $0.date > $1.date }
            .prefix(3))
    }

    static func matchingCompletedWorkouts(
        for goal: WorkoutGoal,
        in workouts: [LiveWorkout]
    ) -> [LiveWorkout] {
        workouts
            .filter { hasCompletedProgress(for: goal, in: $0) }
            .sorted {
                ($0.completedAt ?? $0.startedAt) > ($1.completedAt ?? $1.startedAt)
            }
    }

    static func signals(
        for goal: WorkoutGoal,
        in workouts: [LiveWorkout],
        sessions: [WorkoutSession] = []
    ) -> [RecentWorkoutSignal] {
        let liveSignals = matchingCompletedWorkouts(for: goal, in: workouts)
            .compactMap { signal(from: $0) }

        let sessionSignals = matchingCompletedSessions(for: goal, in: sessions)
            .compactMap { signal(from: $0) }

        return Array((liveSignals + sessionSignals)
            .sorted { $0.date > $1.date }
            .prefix(5))
    }

    static func staleGoalsNeedingCheckIn(
        goals: [WorkoutGoal],
        workouts: [LiveWorkout],
        sessions: [WorkoutSession] = [],
        now: Date = Date()
    ) -> [WorkoutGoal] {
        goals
            .filter(\.isActive)
            .filter { goal in
                let latestWorkoutDate = matchingCompletedWorkouts(for: goal, in: workouts)
                    .compactMap { $0.completedAt ?? $0.startedAt }
                    .max()
                let latestSessionDate = matchingCompletedSessions(for: goal, in: sessions)
                    .map(\.loggedAt)
                    .max()

                let latestProgressDate = [latestWorkoutDate, latestSessionDate, goal.completedAt, goal.updatedAt, goal.lastCheckInPromptAt]
                    .compactMap { $0 }
                    .max() ?? goal.createdAt

                let daysSinceProgress = Calendar.current.dateComponents([.day], from: latestProgressDate, to: now).day ?? 0
                return daysSinceProgress >= goal.effectiveCheckInCadenceDays
            }
            .sorted { lhs, rhs in
                let lhsDate = [lhs.updatedAt, lhs.lastCheckInPromptAt, lhs.createdAt].compactMap { $0 }.max() ?? lhs.createdAt
                let rhsDate = [rhs.updatedAt, rhs.lastCheckInPromptAt, rhs.createdAt].compactMap { $0 }.max() ?? rhs.createdAt
                return lhsDate < rhsDate
            }
    }

    static func matchingCompletedSessions(
        for goal: WorkoutGoal,
        in sessions: [WorkoutSession]
    ) -> [WorkoutSession] {
        sessions
            .filter { isSessionProgressCandidate($0, for: goal) }
            .sorted { $0.loggedAt > $1.loggedAt }
    }

    private static func insight(
        for goal: WorkoutGoal,
        workouts: [LiveWorkout],
        sessions: [WorkoutSession],
        exerciseHistory: [ExerciseHistory],
        useLbs: Bool
    ) -> WorkoutGoalInsight {
        let matchingWorkouts = matchingCompletedWorkouts(for: goal, in: workouts)
        let matchingSessions = matchingCompletedSessions(for: goal, in: sessions)

        let matchingEntries = matchingWorkouts.flatMap { workout in
            (workout.entries ?? []).filter { goal.matches(entry: $0) }
        }

        let latestSupportingNote = latestNote(
            from: matchingEntries,
            fallbackTo: matchingWorkouts,
            or: matchingSessions
        )
        let trimmedGoalNotes = goal.trimmedNotes
        let trimmedSuccessCriteria = goal.trimmedSuccessCriteria

        switch goal.goalKind {
        case .milestone:
            let progressText: String
            if goal.status == .completed {
                progressText = "Completed"
            } else if latestSupportingNote != nil {
                progressText = "Recent progress logged"
            } else {
                progressText = "Use notes and completed sessions to track this"
            }

            let supportingText = latestSupportingNote
                ?? (trimmedSuccessCriteria.isEmpty ? nil : trimmedSuccessCriteria)
                ?? (trimmedGoalNotes.isEmpty ? nil : trimmedGoalNotes)

            return WorkoutGoalInsight(
                goal: goal,
                progressText: progressText,
                supportingText: supportingText,
                progressFraction: goal.status == .completed ? 1.0 : nil,
                currentValueText: nil,
                targetValueText: nil
            )

        case .frequency:
            let now = Date()
            let frequencyProgress = frequencyProgress(
                for: goal,
                workouts: matchingWorkouts,
                sessions: matchingSessions,
                now: now
            )
            let recurringProgress = frequencyRecurringProgress(
                for: goal,
                workouts: matchingWorkouts,
                sessions: matchingSessions,
                now: now
            )

            let targetValueText = goal.targetValue.map {
                formatTarget($0, unit: frequencyUnitText(for: goal))
            }
            let periodText = frequencyPeriodText(for: goal)

            let progressText: String
            if let recurringProgress {
                progressText = recurringProgress.currentPeriodText
            } else if let currentCount = frequencyProgress.currentCount {
                progressText = "\(currentCount) of \(targetValueText ?? "target") this \(periodText)"
            } else {
                progressText = "No \(frequencyUnitText(for: goal)) logged this \(periodText) yet"
            }

            let supportingParts = [
                recurringProgress?.summaryText,
                frequencyProgress.periodRangeText,
                latestSupportingNote,
                trimmedSuccessCriteria.isEmpty ? nil : trimmedSuccessCriteria,
                trimmedGoalNotes.isEmpty ? nil : trimmedGoalNotes
            ].compactMap { $0 }

            return WorkoutGoalInsight(
                goal: goal,
                progressText: progressText,
                supportingText: supportingParts.isEmpty ? nil : supportingParts.joined(separator: "\n"),
                progressFraction: goal.status == .completed ? 1.0 : {
                    if let recurringProgress, !recurringProgress.isOpenEnded {
                        return recurringProgress.displayProgressFraction
                    }
                    return frequencyProgress.progressFraction
                }(),
                currentValueText: frequencyProgress.currentCount.map { "\($0)" },
                targetValueText: targetValueText,
                recurringProgress: recurringProgress
            )

        case .duration:
            let currentSeconds: Double? = {
                let periodStart = periodStartDate(for: goal, now: Date())
                let sessionValues = matchingSessions
                    .filter { session in periodStart.map { session.loggedAt >= $0 } ?? true }
                    .compactMap { session -> Double? in
                    guard let durationMinutes = session.durationMinutes, durationMinutes > 0 else { return nil }
                    return durationMinutes * 60
                }

                if goal.hasActivityScope {
                    let entryValues = matchingEntries
                        .filter { entry in periodStart.map { progressDate(for: entry) >= $0 } ?? true }
                        .compactMap { entry -> Double? in
                        let durationSeconds = entry.trackedDurationSeconds
                        guard durationSeconds > 0 else { return nil }
                        return Double(durationSeconds)
                    }
                    let workoutValues = matchingWorkouts
                        .filter { workout in periodStart.map { (workout.completedAt ?? workout.startedAt) >= $0 } ?? true }
                        .filter { workoutLevelMatchesActivityScope(for: goal, in: $0) }
                        .filter { !hasLoggedMatchingEntries(for: goal, in: $0) }
                        .map(\.duration)
                        .filter { $0 > 0 }
                    return currentNumericValue(entryValues + workoutValues + sessionValues, cumulative: periodStart != nil)
                }

                let workoutValues = matchingWorkouts
                    .filter { workout in periodStart.map { (workout.completedAt ?? workout.startedAt) >= $0 } ?? true }
                    .map(\.duration)
                    .filter { $0 > 0 }
                return currentNumericValue(workoutValues + sessionValues, cumulative: periodStart != nil)
            }()

            return numericInsight(
                for: goal,
                currentBaseValue: currentSeconds,
                formattedCurrentValue: currentSeconds.map { formatDuration(seconds: $0, unit: goal.targetUnit) },
                supportingText: latestSupportingNote
                    ?? (trimmedSuccessCriteria.isEmpty ? nil : trimmedSuccessCriteria)
                    ?? (trimmedGoalNotes.isEmpty ? nil : trimmedGoalNotes)
            )

        case .distance:
            let periodStart = periodStartDate(for: goal, now: Date())
            let entryMeters = matchingEntries
                .filter { entry in periodStart.map { progressDate(for: entry) >= $0 } ?? true }
                .compactMap { entry -> Double? in
                    let distanceMeters = entry.trackedDistanceMeters
                    guard distanceMeters > 0 else { return nil }
                    return distanceMeters
                }
            let sessionMeters = matchingSessions
                .filter { session in periodStart.map { session.loggedAt >= $0 } ?? true }
                .compactMap { session -> Double? in
                    guard let distanceMeters = session.distanceMeters, distanceMeters > 0 else { return nil }
                    return distanceMeters
                }
            let currentMeters = currentNumericValue(entryMeters + sessionMeters, cumulative: periodStart != nil)

            return numericInsight(
                for: goal,
                currentBaseValue: currentMeters,
                formattedCurrentValue: currentMeters.map { formatDistance(meters: $0, unit: goal.targetUnit) },
                supportingText: latestSupportingNote
                    ?? (trimmedSuccessCriteria.isEmpty ? nil : trimmedSuccessCriteria)
                    ?? (trimmedGoalNotes.isEmpty ? nil : trimmedGoalNotes)
            )

        case .count:
            let periodStart = periodStartDate(for: goal, now: Date())
            let entryCounts = matchingEntries
                .filter { entry in periodStart.map { progressDate(for: entry) >= $0 } ?? true }
                .map(countValue)
                .filter { $0 > 0 }
            let sessionCounts = matchingSessions
                .filter { session in periodStart.map { session.loggedAt >= $0 } ?? true }
                .map(countValue)
                .filter { $0 > 0 }
            let currentCount = currentNumericValue(entryCounts + sessionCounts, cumulative: periodStart != nil)

            return numericInsight(
                for: goal,
                currentBaseValue: currentCount,
                formattedCurrentValue: currentCount.map { formatCount($0, unit: goal.targetUnit) },
                supportingText: latestSupportingNote
                    ?? (trimmedSuccessCriteria.isEmpty ? nil : trimmedSuccessCriteria)
                    ?? (trimmedGoalNotes.isEmpty ? nil : trimmedGoalNotes)
            )

        case .weight:
            let currentKg: Double?
            let liveEntryMax = matchingEntries
                .flatMap(\.loggedWorkingSets)
                .compactMap(\.weightKg)
                .filter { $0 > 0 }
                .max()
            if let activityName = goal.trimmedActivityName {
                let exerciseHistoryMax = exerciseHistory
                    .filter { $0.exerciseName.goalNormalizedKey == activityName.goalNormalizedKey }
                    .compactMap(\.bestSetWeightKg)
                    .max()
                let sessionMax = matchingSessions.compactMap(\.weightKg).max()
                let bestKnownWeight = max(exerciseHistoryMax ?? 0, sessionMax ?? 0, liveEntryMax ?? 0)
                currentKg = bestKnownWeight == 0 ? nil : bestKnownWeight
            } else {
                let sessionMax = matchingSessions.compactMap(\.weightKg).max()
                let bestKnownWeight = max(sessionMax ?? 0, liveEntryMax ?? 0)
                currentKg = bestKnownWeight == 0 ? nil : bestKnownWeight
            }

            // Auto-baseline: the weight you were at when you created this goal.
            // Uses the most recent matching workout at or before goal.createdAt, so progress
            // shows improvement since the goal was set, not since you started lifting.
            let autoBaselineKg: Double?
            if goal.baselineValue == nil {
                // matchingWorkouts is sorted newest-first; find closest one at/before creation
                let atCreation = matchingWorkouts.first {
                    ($0.completedAt ?? $0.startedAt) <= goal.createdAt
                }
                let activityNormalizedName = goal.trimmedActivityName?.goalNormalizedKey
                let entryWeights = (atCreation?.entries ?? [])
                    .filter { activityNormalizedName == nil || $0.exerciseName.goalNormalizedKey == activityNormalizedName }
                    .flatMap(\.loggedWorkingSets)
                    .compactMap(\.weightKg)
                    .filter { $0 > 0 }
                autoBaselineKg = entryWeights.max()
            } else {
                autoBaselineKg = nil
            }

            return numericInsight(
                for: goal,
                currentBaseValue: currentKg,
                formattedCurrentValue: currentKg.map {
                    formatWeight(kg: $0, unit: goal.targetUnit, useLbsFallback: useLbs)
                },
                supportingText: latestSupportingNote
                    ?? (trimmedSuccessCriteria.isEmpty ? nil : trimmedSuccessCriteria)
                    ?? (trimmedGoalNotes.isEmpty ? nil : trimmedGoalNotes),
                autoBaselineBaseValue: autoBaselineKg
            )
        }
    }

    private static func numericInsight(
        for goal: WorkoutGoal,
        currentBaseValue: Double?,
        formattedCurrentValue: String?,
        supportingText: String?,
        autoBaselineBaseValue: Double? = nil
    ) -> WorkoutGoalInsight {
        guard let targetValue = goal.targetValue, targetValue > 0 else {
            return WorkoutGoalInsight(
                goal: goal,
                progressText: "Add a target to track progress",
                supportingText: supportingText,
                progressFraction: nil,
                currentValueText: formattedCurrentValue,
                targetValueText: nil
            )
        }

        let currentDisplayValue = currentBaseValue.map { convertedValue(for: $0, kind: goal.goalKind, unit: goal.targetUnit) }
        let autoBaselineDisplayValue: Double? = autoBaselineBaseValue.map { raw in
            let converted = convertedValue(for: raw, kind: goal.goalKind, unit: goal.targetUnit)
            // Round weight baselines the same way WeightUtility.format does (2.5 lbs / 0.5 kg increments)
            // so baseline display matches the current value display and avoids "130.1 lbs" artifacts.
            if goal.goalKind == .weight {
                let weightUnit: WeightUnit = (goal.targetUnit.lowercased() == "lbs" || goal.targetUnit.lowercased() == "lb") ? .lbs : .kg
                return WeightUtility.round(converted, unit: weightUnit)
            }
            return converted
        }
        let targetValueText = formatTarget(targetValue, unit: goal.targetUnit)
        let currentValueText = formattedCurrentValue

        // Effective baseline: prefer explicit user-set value, fall back to auto-derived from training history.
        // Without a baseline we can't tell how much progress was made
        // (e.g. 130 lbs on a 140 lb goal when you started at 130 is 0% progress, not 93%).
        let effectiveBaseline: Double? = goal.baselineValue ?? autoBaselineDisplayValue

        let progressFraction: Double?
        if goal.status == .completed {
            progressFraction = 1.0
        } else if let current = currentDisplayValue, goal.goalKind == .weight, current >= targetValue * 0.995 {
            progressFraction = 1.0
        } else if let current = currentDisplayValue, let baseline = effectiveBaseline, targetValue != baseline {
            progressFraction = min(max((current - baseline) / (targetValue - baseline), 0), 1)
        } else if let current = currentDisplayValue,
                  goal.goalKind == .duration || goal.goalKind == .distance || goal.goalKind == .count {
            progressFraction = min(max(current / targetValue, 0), 1)
        } else {
            progressFraction = nil
        }

        let progressText: String
        if let currentValueText {
            progressText = "\(currentValueText) of \(targetValueText)"
        } else {
            progressText = "No logged progress yet"
        }

        let baselineValueText = effectiveBaseline.map { formatTarget($0, unit: goal.targetUnit) }

        return WorkoutGoalInsight(
            goal: goal,
            progressText: progressText,
            supportingText: supportingText,
            progressFraction: progressFraction,
            currentValueText: currentValueText,
            targetValueText: targetValueText,
            baselineValueText: baselineValueText
        )
    }

    private static func signal(from workout: LiveWorkout) -> RecentWorkoutSignal? {
        guard let note = latestNote(in: workout), !note.isEmpty else { return nil }
        let subtitle = workout.workoutContextSummarySegments.joined(separator: " • ")

        return RecentWorkoutSignal(
            title: workout.name,
            subtitle: subtitle,
            note: note,
            date: workout.completedAt ?? workout.startedAt
        )
    }

    private static func signal(from session: WorkoutSession) -> RecentWorkoutSignal? {
        guard session.hasSignalNote else { return nil }
        let subtitle = session.historyDetailSegments.joined(separator: " • ")

        return RecentWorkoutSignal(
            title: session.displayName,
            subtitle: subtitle,
            note: session.trimmedNotes,
            date: session.loggedAt
        )
    }

    private static func workoutActivityTokens(_ workout: LiveWorkout) -> Set<String> {
        let values = [workout.name] + workout.focusAreas + (workout.entries ?? []).flatMap { entry in
            [entry.exerciseName, entry.activityTypeName] + entry.targetTags
        }
        return Set(values.map(\.goalNormalizedKey).filter { !$0.isEmpty })
    }

    private static func latestNote(in workout: LiveWorkout) -> String? {
        let workoutNote = workout.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        if !workoutNote.isEmpty {
            return workoutNote
        }

        return latestNote(
            from: workout.entries ?? [],
            fallbackTo: []
        )
    }

    private static func latestNote(in session: WorkoutSession) -> String? {
        let note = session.trimmedNotes
        return note.isEmpty ? nil : note
    }

    private static func hasCompletedProgress(
        for goal: WorkoutGoal,
        in workout: LiveWorkout
    ) -> Bool {
        guard workout.completedAt != nil else {
            return false
        }
        if goal.hasGeneratedPlanTemplateScope && !goal.hasGeneratedPlanBlockScope {
            return goal.matchesGeneratedPlanTemplate(workout: workout)
                && hasLoggedGeneratedPlanProgress(in: workout)
        }
        guard goal.matches(workout: workout) else {
            return false
        }

        guard goal.hasActivityScope else {
            return true
        }

        if hasLoggedMatchingEntries(for: goal, in: workout) {
            return true
        }
        if hasPlannedMatchingEntries(for: goal, in: workout) {
            return false
        }
        return workoutLevelMatchesActivityScope(for: goal, in: workout)
    }

    private static func hasLoggedMatchingEntries(
        for goal: WorkoutGoal,
        in workout: LiveWorkout
    ) -> Bool {
        (workout.entries ?? []).contains {
            goal.matches(entry: $0) && $0.hasExercisePreferenceSignal
        }
    }

    private static func hasLoggedGeneratedPlanProgress(in workout: LiveWorkout) -> Bool {
        (workout.entries ?? []).contains { $0.hasExercisePreferenceSignal }
    }

    private static func hasPlannedMatchingEntries(
        for goal: WorkoutGoal,
        in workout: LiveWorkout
    ) -> Bool {
        (workout.entries ?? []).contains {
            guard goal.matches(entry: $0), !$0.hasExercisePreferenceSignal else { return false }
            return $0.isPlannedActivityGuidance || !$0.plannedActivitySummarySegments.isEmpty
        }
    }

    private static func isSessionProgressCandidate(
        _ session: WorkoutSession,
        for goal: WorkoutGoal
    ) -> Bool {
        guard !goal.hasGeneratedPlanTemplateScope, !goal.hasGeneratedPlanBlockScope else { return false }
        guard goal.matches(session: session) else { return false }
        guard !goal.hasActivityScope else { return true }

        return session.sourceIsHealthKit
            || session.healthKitWorkoutID != nil
            || session.healthKitWorkoutType != nil
    }

    private static func workoutLevelMatchesActivityScope(
        for goal: WorkoutGoal,
        in workout: LiveWorkout
    ) -> Bool {
        guard goal.hasActivityScope else { return false }

        let workoutTokens = Set(
            ([workout.name] + workout.focusAreas)
                .map(\.goalNormalizedKey)
                .filter { !$0.isEmpty }
        )

        if let activityName = goal.trimmedActivityName?.goalNormalizedKey,
           !activityName.isEmpty,
           workoutTokens.contains(activityName) {
            return true
        }

        let activityTags = Set(goal.linkedActivityTags.map(\.goalNormalizedKey).filter { !$0.isEmpty })
        if !activityTags.isEmpty,
           !activityTags.isDisjoint(with: workoutTokens) {
            return true
        }

        guard goal.trimmedActivityName == nil,
              activityTags.isEmpty,
              goal.linkedActivityRole == nil,
              goal.linkedActivityKind != nil else {
            return false
        }

        return goal.matches(workout: workout)
    }

    private static func latestNote(
        from entries: [LiveWorkoutEntry],
        fallbackTo workouts: [LiveWorkout],
        or sessions: [WorkoutSession] = []
    ) -> String? {
        if let entryNote = entries
            .sorted(by: { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) })
            .map(\.notes)
            .map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) })
            .first(where: { !$0.isEmpty }) {
            return entryNote
        }

        return workouts
            .sorted(by: { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) })
            .compactMap { latestNote(in: $0) }
            .first
            ?? sessions
            .sorted(by: { $0.loggedAt > $1.loggedAt })
            .compactMap { latestNote(in: $0) }
            .first
    }

    private static func convertedValue(for baseValue: Double, kind: WorkoutGoal.GoalKind, unit: String) -> Double {
        switch kind {
        case .frequency:
            return baseValue
        case .duration:
            switch unit.lowercased() {
            case "hr", "hrs", "hour", "hours":
                return baseValue / 3600
            default:
                return baseValue / 60
            }
        case .distance:
            switch unit.lowercased() {
            case "mi", "mile", "miles":
                return baseValue / 1609.344
            case "m":
                return baseValue
            default:
                return baseValue / 1000
            }
        case .count:
            return baseValue
        case .weight:
            switch unit.lowercased() {
            case "lbs", "lb":
                return baseValue * WeightUtility.kgToLbs
            default:
                return baseValue
            }
        case .milestone:
            return baseValue
        }
    }

    private static func formatDuration(seconds: Double, unit: String) -> String {
        let converted = convertedValue(for: seconds, kind: .duration, unit: unit)
        return formatTarget(converted, unit: unit.isEmpty ? "min" : unit)
    }

    private static func formatDistance(meters: Double, unit: String) -> String {
        let displayUnit = unit.isEmpty ? "km" : unit
        let converted = convertedValue(for: meters, kind: .distance, unit: displayUnit)
        return formatTarget(converted, unit: displayUnit)
    }

    private static func formatCount(_ value: Double, unit: String) -> String {
        formatTarget(value, unit: unit.isEmpty ? "count" : unit)
    }

    private static func formatWeight(kg: Double, unit: String, useLbsFallback: Bool) -> String {
        let displayUnitStr = unit.isEmpty ? (useLbsFallback ? "lbs" : "kg") : unit
        let weightUnit: WeightUnit = (displayUnitStr.lowercased() == "lbs" || displayUnitStr.lowercased() == "lb") ? .lbs : .kg
        // Use WeightUtility so we get the same rounding (2.5 lbs / 0.5 kg) as everywhere else in the app.
        return WeightUtility.format(kg, displayUnit: weightUnit)
    }

    static func formatTarget(_ value: Double, unit: String) -> String {
        let trimmedUnit = unit.trimmingCharacters(in: .whitespacesAndNewlines)
        let roundedValue = value.rounded()
        let formattedValue: String
        if abs(value - roundedValue) < 0.000_001 {
            formattedValue = "\(Int(roundedValue))"
        } else {
            formattedValue = String(format: "%.1f", value)
        }
        return trimmedUnit.isEmpty ? formattedValue : "\(formattedValue) \(trimmedUnit)"
    }

    private struct FrequencyProgressSnapshot {
        let currentCount: Int?
        let progressFraction: Double?
        let periodRangeText: String?
    }

    private static func frequencyProgress(
        for goal: WorkoutGoal,
        workouts: [LiveWorkout],
        sessions: [WorkoutSession],
        now: Date
    ) -> FrequencyProgressSnapshot {
        guard let targetValue = goal.targetValue, targetValue > 0 else {
            return FrequencyProgressSnapshot(currentCount: nil, progressFraction: nil, periodRangeText: nil)
        }

        let periodStart = periodStartDate(for: goal, now: now) ?? Calendar.current.startOfDay(for: now)
        let progressStart = max(periodStart, goal.createdAt)
        let currentCount = frequencyCount(
            for: goal,
            workouts: workouts,
            sessions: sessions,
            lowerBound: progressStart,
            upperBound: nil
        )

        let progressFraction = min(max(Double(currentCount) / targetValue, 0), 1)
        let periodRangeText: String
        if progressStart > periodStart {
            periodRangeText = "Tracking this \(frequencyPeriodText(for: goal)) since \(progressStart.formatted(date: .abbreviated, time: .omitted))"
        } else {
            periodRangeText = "Current \(goal.periodLabelText) started \(periodStart.formatted(date: .abbreviated, time: .omitted))"
        }

        return FrequencyProgressSnapshot(
            currentCount: currentCount,
            progressFraction: progressFraction,
            periodRangeText: periodRangeText
        )
    }

    private static func frequencyUnitText(for goal: WorkoutGoal) -> String {
        let trimmedUnit = goal.targetUnit.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedUnit.isEmpty ? "sessions" : trimmedUnit
    }

    private static func frequencyPeriodText(for goal: WorkoutGoal) -> String {
        guard let periodUnit = goal.periodUnit else { return "period" }
        let periodCount = max(goal.periodCount ?? 1, 1)
        if periodCount > 1 {
            return goal.periodLabelText
        }
        return periodUnit.rawValue
    }

    private static func frequencyCount(
        for goal: WorkoutGoal,
        workouts: [LiveWorkout],
        sessions: [WorkoutSession],
        lowerBound: Date,
        upperBound: Date?
    ) -> Int {
        let workoutCount: Int
        if goal.hasGeneratedPlanTemplateScope && !goal.hasGeneratedPlanBlockScope {
            workoutCount = Set(workouts.compactMap { workout -> UUID? in
                let progressDate = workout.completedAt ?? workout.startedAt
                guard progressDate >= lowerBound,
                      upperBound.map({ progressDate < $0 }) ?? true,
                      goal.matchesGeneratedPlanTemplate(workout: workout),
                      hasLoggedGeneratedPlanProgress(in: workout) else {
                    return nil
                }
                return workout.sourcePlanTemplateID
            }).count
        } else if goal.hasActivityScope && frequencyGoalCountsActivityEntries(goal) {
            workoutCount = workouts.reduce(0) { count, workout in
                let entryCount = (workout.entries ?? []).filter { entry in
                    guard goal.matches(entry: entry),
                          entry.hasExercisePreferenceSignal else {
                        return false
                    }
                    let progressDate = entry.completedAt ?? workout.completedAt ?? workout.startedAt
                    return progressDate >= lowerBound && (upperBound.map { progressDate < $0 } ?? true)
                }.count

                if entryCount > 0 {
                    return count + entryCount
                }

                let progressDate = workout.completedAt ?? workout.startedAt
                guard progressDate >= lowerBound,
                      upperBound.map({ progressDate < $0 }) ?? true,
                      !hasPlannedMatchingEntries(for: goal, in: workout),
                      workoutLevelMatchesActivityScope(for: goal, in: workout) else {
                    return count
                }
                return count + 1
            }
        } else {
            workoutCount = workouts
                .filter {
                    let progressDate = $0.completedAt ?? $0.startedAt
                    return progressDate >= lowerBound && (upperBound.map { progressDate < $0 } ?? true)
                }
                .count
        }
        let sessionCount = sessions
            .filter { session in
                session.loggedAt >= lowerBound && (upperBound.map { session.loggedAt < $0 } ?? true)
            }
            .count
        return workoutCount + sessionCount
    }

    private static func frequencyRecurringProgress(
        for goal: WorkoutGoal,
        workouts: [LiveWorkout],
        sessions: [WorkoutSession],
        now: Date
    ) -> WorkoutGoalRecurringProgress? {
        guard goal.goalKind == .frequency,
              let targetValue = goal.targetValue,
              targetValue > 0,
              let periodUnit = goal.periodUnit else {
            return nil
        }

        let calendar = Calendar.current
        let targetCount = max(Int(ceil(targetValue)), 1)
        let stepCount = max(goal.periodCount ?? 1, 1)

        if let targetDate = goal.targetDate {
            let horizonEnd = calendar.startOfDay(for: targetDate)
            guard horizonEnd > goal.createdAt else { return nil }

            var periodStart = containingPeriodStart(for: goal.createdAt, unit: periodUnit, calendar: calendar)
            var historyPeriods: [WorkoutGoalPeriodSnapshot] = []

            while periodStart < horizonEnd {
                guard let periodEnd = calendar.date(
                    byAdding: dateComponent(for: periodUnit),
                    value: stepCount,
                    to: periodStart
                ) else { break }

                let effectiveStart = max(periodStart, goal.createdAt)
                let effectiveEnd = min(periodEnd, horizonEnd)
                let count = frequencyCount(
                    for: goal,
                    workouts: workouts,
                    sessions: sessions,
                    lowerBound: effectiveStart,
                    upperBound: effectiveEnd
                )

                historyPeriods.append(
                    WorkoutGoalPeriodSnapshot(
                        index: historyPeriods.count + 1,
                        startDate: periodStart,
                        endDate: periodEnd,
                        effectiveStartDate: effectiveStart,
                        currentCount: count,
                        targetCount: targetCount,
                        isCurrent: now >= periodStart && now < periodEnd,
                        isFuture: periodStart > now
                    )
                )

                periodStart = periodEnd
            }

            guard historyPeriods.count > 1 else { return nil }
            let displayPeriods = finiteDisplayPeriods(
                from: historyPeriods,
                limit: finitePeriodSnapshotLimit(for: periodUnit)
            )
            return WorkoutGoalRecurringProgress(
                periodUnit: periodUnit,
                periods: displayPeriods,
                historyPeriods: historyPeriods,
                isOpenEnded: false
            )
        }

        let currentPeriodStart = containingPeriodStart(for: now, unit: periodUnit, calendar: calendar)
        let rollingPeriodCount = rollingDisplayPeriodCount(for: periodUnit)
        let earliestRollingStart = calendar.date(
            byAdding: dateComponent(for: periodUnit),
            value: -stepCount * (rollingPeriodCount - 1),
            to: currentPeriodStart
        ) ?? currentPeriodStart

        let historyStart = containingPeriodStart(for: goal.createdAt, unit: periodUnit, calendar: calendar)
        let historyPeriods = openEndedFrequencyPeriods(
            for: goal,
            workouts: workouts,
            sessions: sessions,
            periodUnit: periodUnit,
            stepCount: stepCount,
            targetCount: targetCount,
            start: historyStart,
            currentPeriodStart: currentPeriodStart,
            now: now,
            marksBeforeGoalStart: false,
            limit: nil
        )
        let periods = openEndedFrequencyPeriods(
            for: goal,
            workouts: workouts,
            sessions: sessions,
            periodUnit: periodUnit,
            stepCount: stepCount,
            targetCount: targetCount,
            start: earliestRollingStart,
            currentPeriodStart: currentPeriodStart,
            now: now,
            marksBeforeGoalStart: true,
            limit: rollingPeriodCount
        )

        guard !periods.isEmpty else { return nil }
        return WorkoutGoalRecurringProgress(
            periodUnit: periodUnit,
            periods: periods,
            historyPeriods: historyPeriods.isEmpty ? periods : historyPeriods,
            isOpenEnded: true
        )
    }

    private static func openEndedFrequencyPeriods(
        for goal: WorkoutGoal,
        workouts: [LiveWorkout],
        sessions: [WorkoutSession],
        periodUnit: WorkoutGoal.PeriodUnit,
        stepCount: Int,
        targetCount: Int,
        start: Date,
        currentPeriodStart: Date,
        now: Date,
        marksBeforeGoalStart: Bool,
        limit: Int?
    ) -> [WorkoutGoalPeriodSnapshot] {
        let calendar = Calendar.current
        var periodStart = start
        var periods: [WorkoutGoalPeriodSnapshot] = []

        while periodStart <= currentPeriodStart && (limit.map { periods.count < $0 } ?? true) {
            guard let periodEnd = calendar.date(
                byAdding: dateComponent(for: periodUnit),
                value: stepCount,
                to: periodStart
            ) else { break }

            let isBeforeGoalStart = marksBeforeGoalStart && periodEnd <= goal.createdAt
            let effectiveStart = isBeforeGoalStart ? periodStart : max(periodStart, goal.createdAt)
            let count = isBeforeGoalStart ? 0 : frequencyCount(
                for: goal,
                workouts: workouts,
                sessions: sessions,
                lowerBound: effectiveStart,
                upperBound: periodEnd
            )

            periods.append(
                WorkoutGoalPeriodSnapshot(
                    index: periods.count + 1,
                    startDate: periodStart,
                    endDate: periodEnd,
                    effectiveStartDate: effectiveStart,
                    currentCount: count,
                    targetCount: targetCount,
                    isCurrent: now >= periodStart && now < periodEnd,
                    isFuture: false,
                    isBeforeGoalStart: isBeforeGoalStart
                )
            )

            periodStart = periodEnd
        }

        return periods
    }

    private static func rollingDisplayPeriodCount(for periodUnit: WorkoutGoal.PeriodUnit) -> Int {
        switch periodUnit {
        case .day: 91
        case .week: 26
        case .month: 24
        }
    }

    private static func finiteDisplayPeriods(
        from periods: [WorkoutGoalPeriodSnapshot],
        limit: Int
    ) -> [WorkoutGoalPeriodSnapshot] {
        guard periods.count > limit else { return periods }

        let anchorIndex = periods.firstIndex(where: \.isCurrent)
            ?? periods.firstIndex(where: \.isFuture)
            ?? periods.index(before: periods.endIndex)
        let halfWindow = limit / 2
        let maxStartIndex = max(periods.count - limit, 0)
        let startIndex = min(max(anchorIndex - halfWindow, 0), maxStartIndex)
        let endIndex = min(startIndex + limit, periods.count)
        return Array(periods[startIndex..<endIndex])
    }

    private static func finitePeriodSnapshotLimit(for periodUnit: WorkoutGoal.PeriodUnit) -> Int {
        switch periodUnit {
        case .day: 84
        case .week: 52
        case .month: 24
        }
    }

    private static func frequencyGoalCountsActivityEntries(_ goal: WorkoutGoal) -> Bool {
        guard goal.hasActivityScope else { return false }

        let normalizedUnit = goal.targetUnit
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        return !(normalizedUnit.contains("session") || normalizedUnit.contains("workout"))
    }

    private static func periodStartDate(for goal: WorkoutGoal, now: Date) -> Date? {
        guard goal.periodUnit != nil || goal.periodCount != nil else { return nil }
        let calendar = Calendar.current
        let periodCount = max(goal.periodCount ?? 1, 1)
        let periodUnit = goal.periodUnit ?? .week

        switch periodUnit {
        case .day:
            let startOfToday = calendar.startOfDay(for: now)
            return calendar.date(byAdding: .day, value: -(periodCount - 1), to: startOfToday) ?? startOfToday
        case .week:
            let currentWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? calendar.startOfDay(for: now)
            return calendar.date(byAdding: .weekOfYear, value: -(periodCount - 1), to: currentWeek) ?? currentWeek
        case .month:
            let currentMonth = calendar.dateInterval(of: .month, for: now)?.start ?? calendar.startOfDay(for: now)
            return calendar.date(byAdding: .month, value: -(periodCount - 1), to: currentMonth) ?? currentMonth
        }
    }

    private static func currentNumericValue(_ values: [Double], cumulative: Bool) -> Double? {
        let positiveValues = values.filter { $0 > 0 }
        guard !positiveValues.isEmpty else { return nil }
        return cumulative ? positiveValues.reduce(0, +) : positiveValues.max()
    }

    nonisolated private static func countValue(for entry: LiveWorkoutEntry) -> Double {
        if entry.isStrength {
            let completedReps = entry.completedSets?
                .map(\.reps)
                .filter { $0 > 0 }
                .reduce(0, +) ?? 0
            return Double(completedReps)
        }

        let segmentReps = entry.activitySegments
            .compactMap(\.reps)
            .filter { $0 > 0 }
            .reduce(0, +)
        let segmentCount = entry.activitySegments.filter(\.hasLoggedData).count
        return Double(segmentReps > 0 ? segmentReps : segmentCount)
    }

    nonisolated private static func countValue(for session: WorkoutSession) -> Double {
        if session.reps > 0 {
            return Double(session.reps)
        }
        if session.sets > 0 {
            return Double(session.sets)
        }
        return 0
    }

    private static func progressDate(for entry: LiveWorkoutEntry) -> Date {
        entry.completedAt ?? entry.workout?.completedAt ?? entry.workout?.startedAt ?? .distantPast
    }

    private static func containingPeriodStart(
        for date: Date,
        unit: WorkoutGoal.PeriodUnit,
        calendar: Calendar
    ) -> Date {
        switch unit {
        case .day:
            return calendar.startOfDay(for: date)
        case .week:
            return calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? calendar.startOfDay(for: date)
        case .month:
            return calendar.dateInterval(of: .month, for: date)?.start ?? calendar.startOfDay(for: date)
        }
    }

    private static func dateComponent(for unit: WorkoutGoal.PeriodUnit) -> Calendar.Component {
        switch unit {
        case .day: .day
        case .week: .weekOfYear
        case .month: .month
        }
    }
}

struct SessionGoalsCard: View {
    let goals: [WorkoutGoal]
    let onAddGoal: () -> Void
    let onToggleCompletion: (WorkoutGoal) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Working Toward", systemImage: "scope")
                    .font(.headline)

                Spacer()

                Button("Add Goal", systemImage: "plus") {
                    onAddGoal()
                }
                .font(.caption.weight(.semibold))
            }

            if goals.isEmpty {
                Text("Add a goal Trai can follow during this session.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(goals.prefix(3)) { goal in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: goal.goalKind.iconName)
                            .font(.subheadline)
                            .foregroundStyle(goal.status == .completed ? .green : .accentColor)
                            .frame(width: 34, height: 34)
                            .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 10))

                        VStack(alignment: .leading, spacing: 4) {
                            Text(goal.trimmedTitle)
                                .font(.subheadline.weight(.semibold))

                            Text(goal.scopeSummary)
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            if let supportingSummary = goal.supportingSummary {
                                Text(supportingSummary)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }

                        Spacer()

                        Button {
                            onToggleCompletion(goal)
                        } label: {
                            Image(systemName: goal.status == .completed ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                                .foregroundStyle(goal.status == .completed ? .green : .secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .traiCard()
    }
}

struct WorkoutGoalProgressCard: View {
    let insights: [WorkoutGoalInsight]
    var showsAddGoal: Bool = true
    let onAddGoal: () -> Void
    let onToggleCompletion: (WorkoutGoal) -> Void
    var onGoalTap: ((WorkoutGoal) -> Void)? = nil

    private var activeInsights: [WorkoutGoalInsight] {
        insights.filter { $0.goal.isActive }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if showsAddGoal {
                TraiSectionHeader("Working Toward", icon: "scope") {
                    Button("Add Goal", systemImage: "plus", action: onAddGoal)
                        .buttonStyle(.traiTertiary(size: .compact, height: 32))
                }
            } else {
                TraiSectionHeader("Working Toward", icon: "scope")
            }

            if activeInsights.isEmpty {
                Text("Add a goal for this workout type or a specific activity to see progress here.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(activeInsights.prefix(5)) { insight in
                            compactGoalCard(insight)
                                .frame(width: 154)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.viewAligned)
                .contentMargins(.horizontal, 1, for: .scrollContent)
            }
        }
        .padding(16)
        .traiCard(cornerRadius: 16, contentPadding: 0)
    }

    private func compactGoalCard(_ insight: WorkoutGoalInsight) -> some View {
        Button {
            onGoalTap?(insight.goal)
        } label: {
            VStack(spacing: 10) {
                GoalProgressRing(
                    progress: insight.cardProgressFraction,
                    iconName: insight.goal.goalKind.iconName,
                    color: insight.goal.status == .completed ? .green : TraiColors.flame
                )
                .frame(width: 52, height: 52)

                Text(insight.goal.trimmedTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(height: 34, alignment: .top)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .padding(.horizontal, 10)
            .frame(height: 126)
            .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 14))
            .contentShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(TraiPressStyle())
    }
}

struct RecentWorkoutSignalsCard: View {
    let signals: [RecentWorkoutSignal]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TraiSectionHeader("Recent Notes", icon: "text.quote")

            if signals.isEmpty {
                Text("No recent notes yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(signals) { signal in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(signal.title)
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Text(signal.date, format: .dateTime.month().day())
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        if !signal.subtitle.isEmpty {
                            Text(signal.subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Text(signal.note)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(4)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
        }
        .traiCard()
    }
}

struct WorkoutTraiReviewCard: View {
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: TraiSpacing.sm) {
                TraiLensSymbolIcon(size: 30, variant: .enclosedFilled, color: Color.accentColor)
                    .frame(width: 30, height: 30)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.traiHeadline(14))
                        .foregroundStyle(Color.accentColor)

                    Text(subtitle)
                        .font(.traiLabel(12))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.accentColor.opacity(0.58))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .glassEffect(
                .regular.tint(Color.accentColor.opacity(0.20)).interactive(),
                in: .capsule
            )
            .overlay {
                Capsule()
                    .strokeBorder(.white.opacity(0.18), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.03), radius: 5, y: 3)
        }
        .buttonStyle(TraiPressStyle(scale: 0.96))
    }
}

struct WorkoutGoalsOverviewSection: View {
    let insights: [WorkoutGoalInsight]
    let celebratedGoal: WorkoutGoal?
    let canCreateGoalsWithTrai: Bool
    let completedGoalCount: Int
    let onCreateGoalWithTrai: () -> Void
    let onCompletedGoalsTap: () -> Void
    let onUnlockPro: () -> Void
    let staleCheckInGoal: WorkoutGoal?
    let onGoalTap: (WorkoutGoal) -> Void

    @ViewBuilder
    var body: some View {
        overviewContent
            .traiCard(glow: .activity)
    }

    private var overviewContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            TraiSectionHeader("Goals", icon: "scope") {
                if canCreateGoalsWithTrai {
                    Button("Set Goals", action: onCreateGoalWithTrai)
                        .buttonStyle(.traiTertiary(size: .compact, height: 32))
                }
            }

            if !canCreateGoalsWithTrai {
                lockedGoalsState
            } else if insights.isEmpty && completedGoalCount == 0 {
                emptyStateCard
            } else {
                if !insights.isEmpty || completedGoalCount > 0 {
                    goalsCarousel
                }

                if let staleCheckInGoal {
                    staleCheckInCard(staleCheckInGoal)
                }
            }

        }
    }

    private var emptyStateCard: some View {
        Button {
            if canCreateGoalsWithTrai {
                onCreateGoalWithTrai()
            } else {
                onUnlockPro()
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "scope")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 34, height: 34)
                    .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 2) {
                    Text(canCreateGoalsWithTrai ? "Set goals with Trai" : "Goal coaching is locked")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)

                    Text(canCreateGoalsWithTrai ? "Turn a route, lift, or routine into something trackable." : "Unlock Pro from the banner above to track goals and workout signals.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer()
            }
            .padding(14)
            .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 14))
            .contentShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(TraiPressStyle())
    }

    private var lockedGoalsState: some View {
        VStack(alignment: .leading, spacing: 12) {
            emptyStateCard

            Button(action: onUnlockPro) {
                HStack(spacing: 12) {
                    TraiLensSymbolIcon(size: 20, variant: .enclosedFilled, color: TraiColors.brandAccent)
                        .frame(width: 34, height: 34)
                        .background(TraiColors.brandAccent.opacity(0.10), in: RoundedRectangle(cornerRadius: 10))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Get Trai Pro")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)

                        Text("Unlock workout signals, goal tracking, and adaptive coaching.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }

                    Spacer(minLength: 8)

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(12)
                .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 14))
                .contentShape(RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(TraiPressStyle())
        }
    }

    private var goalsCarousel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                if completedGoalCount > 0, celebratedGoal != nil {
                    completedGoalsCard(isHighlighted: true)
                        .frame(width: 134)
                }

                ForEach(insights.prefix(5)) { insight in
                    featuredGoalCard(insight)
                        .frame(width: 134)
                }

                if completedGoalCount > 0, celebratedGoal == nil {
                    completedGoalsCard(isHighlighted: false)
                        .frame(width: 134)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned)
        .contentMargins(.horizontal, 1, for: .scrollContent)
    }

    private func featuredGoalCard(_ insight: WorkoutGoalInsight) -> some View {
        Button {
            onGoalTap(insight.goal)
        } label: {
            goalTileContent(
                progress: insight.cardProgressFraction,
                iconName: insight.goal.goalKind.iconName,
                color: TraiColors.flame,
                title: insight.goal.trimmedTitle
            )
            .padding(.horizontal, 10)
            .frame(height: 112)
            .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 14))
            .contentShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(TraiPressStyle())
    }

    private func goalTileContent(
        progress: Double?,
        iconName: String,
        color: Color,
        title: String
    ) -> some View {
        VStack(spacing: 9) {
            GoalProgressRing(
                progress: progress,
                iconName: iconName,
                color: color,
                size: 46,
                lineWidth: 4.5
            )
            .frame(maxWidth: .infinity, alignment: .center)

            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .lineLimit(2, reservesSpace: true)
                .frame(maxWidth: .infinity, alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private func completedGoalsCard(isHighlighted: Bool) -> some View {
        Button(action: onCompletedGoalsTap) {
            goalTileContent(
                progress: 1,
                iconName: "checkmark.seal.fill",
                color: .green,
                title: "Completed Goals"
            )
            .padding(.horizontal, 10)
            .frame(height: 112)
            .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 14))
            .overlay {
                if isHighlighted {
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(Color.green.opacity(0.32), lineWidth: 1)
                }
            }
            .overlay(alignment: .topTrailing) {
                if isHighlighted {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 10, height: 10)
                        .overlay {
                            Circle()
                                .strokeBorder(Color.white.opacity(0.9), lineWidth: 2)
                        }
                        .shadow(color: Color.green.opacity(0.22), radius: 4, y: 2)
                        .padding(10)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(TraiPressStyle())
    }

    private func staleCheckInCard(_ goal: WorkoutGoal) -> some View {
        Button {
            onGoalTap(goal)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "message.badge.waveform.fill")
                    .font(.headline)
                    .foregroundStyle(TraiColors.brandAccent)
                    .frame(width: 38, height: 38)
                    .background(TraiColors.brandAccent.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 4) {
                    Text("Time to check in")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)

                    Text(goal.trimmedTitle)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text("Trai can review or refresh it.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 14))
            .contentShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(TraiPressStyle())
    }

}

struct CompletedWorkoutGoalsSheet: View {
    let insights: [WorkoutGoalInsight]
    let workouts: [LiveWorkout]
    let sessions: [WorkoutSession]
    let exerciseHistory: [ExerciseHistory]
    let useLbs: Bool
    let onToggleCompletion: (WorkoutGoal) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var selectedGoal: WorkoutGoal?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if insights.isEmpty {
                        ContentUnavailableView(
                            "No Completed Goals",
                            systemImage: "checkmark.seal",
                            description: Text("Completed workout goals will stay available here.")
                        )
                        .padding(.top, 40)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(Array(insights.enumerated()), id: \.element.id) { index, insight in
                                Button {
                                    selectedGoal = insight.goal
                                } label: {
                                    CompletedWorkoutGoalRow(insight: insight)
                                }
                                .buttonStyle(TraiPressStyle())

                                if index < insights.count - 1 {
                                    Divider()
                                        .padding(.leading, 72)
                                }
                            }
                        }
                        .traiCard(cornerRadius: 16, contentPadding: 0)
                    }
                }
                .padding()
            }
            .navigationTitle("Completed Goals")
            .toolbarTitleDisplayMode(.inlineLarge)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", systemImage: "checkmark") {
                        dismiss()
                    }
                    .labelStyle(.iconOnly)
                }
            }
            .sheet(item: $selectedGoal) { goal in
                WorkoutGoalDetailSheet(
                    goal: goal,
                    workouts: workouts,
                    sessions: sessions,
                    exerciseHistory: exerciseHistory,
                    useLbs: useLbs,
                    onToggleCompletion: onToggleCompletion
                )
                .traiSheetBranding()
            }
        }
    }
}

private struct CompletedWorkoutGoalRow: View {
    let insight: WorkoutGoalInsight

    var body: some View {
        HStack(spacing: 12) {
            GoalProgressRing(
                progress: 1,
                iconName: insight.goal.goalKind.iconName,
                color: .green
            )
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text(insight.goal.trimmedTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                Text(insight.progressText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if let completedAt = insight.goal.completedAt {
                    Text(completedAt.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .contentShape(Rectangle())
    }
}

private struct RecurringGoalTimeline: View {
    let progress: WorkoutGoalRecurringProgress
    let color: Color
    var onShowHistory: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(progress.patternTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer(minLength: 8)

                Text(progress.detailSummaryText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(progress.isComplete ? .green : color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }

            RecurringGoalContributionGrid(progress: progress, color: color)
                .frame(maxWidth: .infinity, alignment: .center)

            if let timelineRangeText = progress.timelineRangeText {
                Text(timelineRangeText)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }

            if progress.hasExtendedHistory, let onShowHistory {
                Button(action: onShowHistory) {
                    HStack(spacing: 10) {
                        Image(systemName: "calendar.day.timeline.leading")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(color)
                            .frame(width: 28, height: 28)
                            .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))

                        VStack(alignment: .leading, spacing: 2) {
                            Text("View full history")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.primary)
                            Text(progress.historySummaryText)
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.secondary)
                        }

                        Spacer(minLength: 8)

                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(10)
                    .background(Color(.tertiarySystemFill).opacity(0.7), in: RoundedRectangle(cornerRadius: 12))
                    .contentShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(TraiPressStyle())
            }
        }
    }
}

private struct RecurringGoalContributionGrid: View {
    let progress: WorkoutGoalRecurringProgress
    let color: Color
    var periodsOverride: [WorkoutGoalPeriodSnapshot]?
    var fillsAvailableWidth = true
    var availableWidth: CGFloat?

    private var periods: [WorkoutGoalPeriodSnapshot] {
        periodsOverride ?? progress.periods
    }

    private var rowCount: Int {
        let count = max(periods.count, 1)
        switch progress.periodUnit {
        case .day:
            if progress.isOpenEnded, count < 21 {
                return min(max(Int(ceil(Double(count) / 7.0)), 1), 3)
            }
            return min(count, 7)
        case .week:
            return min(max(Int(ceil(Double(count) / 12.0)), 1), 6)
        case .month:
            return min(max(Int(ceil(Double(count) / 12.0)), 1), 4)
        }
    }

    private var columnCount: Int {
        guard rowCount > 0 else { return 0 }
        return Int(ceil(Double(periods.count) / Double(rowCount)))
    }

    private var cellSize: CGFloat {
        guard !progress.isOpenEnded else {
            if let availableWidth {
                let columns = max(columnCount, 1)
                let spacingWidth = CGFloat(max(columns - 1, 0)) * cellSpacing
                let widthBoundSize = floor((availableWidth - spacingWidth) / CGFloat(columns))
                return max(min(openEndedMaxCellSize, widthBoundSize), openEndedMinCellSize)
            }

            switch progress.periodUnit {
            case .day: return 13
            case .week, .month: return 16
            }
        }

        let maxCellSize = finiteMaxCellSize
        let columns = max(columnCount, 1)
        let availableWidth: CGFloat = 260
        let spacingWidth = CGFloat(max(columns - 1, 0)) * cellSpacing
        let widthBoundSize = floor((availableWidth - spacingWidth) / CGFloat(columns))
        return max(min(maxCellSize, widthBoundSize), finiteMinCellSize)
    }

    private var cellSpacing: CGFloat {
        guard !progress.isOpenEnded else {
            return progress.periodUnit == .day ? 5 : 6
        }

        switch progress.periodUnit {
        case .day:
            return periods.count <= 14 ? 6 : 5
        case .week, .month:
            return periods.count <= 6 ? 8 : 6
        }
    }

    private var openEndedMaxCellSize: CGFloat {
        switch progress.periodUnit {
        case .day:
            return 13
        case .week, .month:
            return 16
        }
    }

    private var openEndedMinCellSize: CGFloat {
        switch progress.periodUnit {
        case .day:
            return 8
        case .week, .month:
            return 10
        }
    }

    var contentHeight: CGFloat {
        let rows = max(rowCount, 1)
        return CGFloat(rows) * cellSize + CGFloat(max(rows - 1, 0)) * cellSpacing + 4
    }

    private var finiteMaxCellSize: CGFloat {
        switch progress.periodUnit {
        case .day:
            return periods.count <= 14 ? 16 : 13
        case .week, .month:
            if periods.count <= 6 {
                return 24
            }
            if periods.count <= 12 {
                return 18
            }
            return 16
        }
    }

    private var finiteMinCellSize: CGFloat {
        switch progress.periodUnit {
        case .day:
            return 10
        case .week, .month:
            return 12
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: cellSpacing) {
                ForEach(0..<columnCount, id: \.self) { column in
                    VStack(spacing: cellSpacing) {
                        ForEach(0..<rowCount, id: \.self) { row in
                            let index = column * rowCount + row
                            if periods.indices.contains(index) {
                                RecurringGoalContributionCell(
                                    period: periods[index],
                                    periodLabel: progress.periodLabel,
                                    color: color,
                                    size: cellSize
                                )
                            } else {
                                Color.clear
                                    .frame(width: cellSize, height: cellSize)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: fillsAvailableWidth ? .infinity : nil, alignment: .center)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(progress.isOpenEnded ? "Habit pattern" : "Goal pattern")
        .accessibilityValue(progress.detailSummaryText)
    }
}

private enum RecurringGoalHistoryRange: String, CaseIterable, Identifiable {
    case recent
    case longer
    case allTime

    var id: String { rawValue }

    func title(for progress: WorkoutGoalRecurringProgress) -> String {
        switch self {
        case .recent:
            switch progress.periodUnit {
            case .day: "13 weeks"
            case .week: "26 weeks"
            case .month: "24 months"
            }
        case .longer:
            switch progress.periodUnit {
            case .day: "1 year"
            case .week: "1 year"
            case .month: "3 years"
            }
        case .allTime:
            "All time"
        }
    }

    func periodLimit(for progress: WorkoutGoalRecurringProgress) -> Int? {
        switch self {
        case .recent:
            progress.periods.count
        case .longer:
            switch progress.periodUnit {
            case .day: 365
            case .week: 52
            case .month: 36
            }
        case .allTime:
            nil
        }
    }
}

private struct RecurringGoalHistorySheet: View {
    let goal: WorkoutGoal
    let progress: WorkoutGoalRecurringProgress
    let color: Color

    @Environment(\.dismiss) private var dismiss
    @State private var selectedRange: RecurringGoalHistoryRange = .recent

    private var selectedPeriods: [WorkoutGoalPeriodSnapshot] {
        progress.historyPeriods(limit: selectedRange.periodLimit(for: progress))
    }

    private var availableRanges: [RecurringGoalHistoryRange] {
        RecurringGoalHistoryRange.allCases.filter { range in
            guard range == .longer,
                  let limit = range.periodLimit(for: progress) else {
                return true
            }
            return progress.historyPeriodCount > limit
        }
    }

    private var selectedTrackedPeriods: [WorkoutGoalPeriodSnapshot] {
        selectedPeriods.filter { !$0.isBeforeGoalStart }
    }

    private var selectedCompletedCount: Int {
        selectedTrackedPeriods.filter(\.isTargetMet).count
    }

    private var selectedCompletionRateText: String {
        guard !selectedTrackedPeriods.isEmpty else { return "0%" }
        let rate = Double(selectedCompletedCount) / Double(selectedTrackedPeriods.count)
        return "\(Int((rate * 100).rounded()))%"
    }

    private var selectedRangeText: String {
        guard let first = selectedPeriods.first,
              let last = selectedPeriods.last else {
            return "No history yet"
        }

        let start = first.startDate.formatted(.dateTime.month(.abbreviated).day())
        let end = last.isCurrent ? "Today" : last.endDate.formatted(.dateTime.month(.abbreviated).day())
        return "\(start) - \(end)"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    historyHeader
                    historyStats
                    historyGridCard
                }
                .padding()
            }
            .traiBackground()
            .navigationTitle("Goal History")
            .toolbarTitleDisplayMode(.inlineLarge)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .traiSheetBranding()
    }

    private var historyHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                GoalProgressRing(
                    progress: progress.currentPeriod?.targetFraction,
                    iconName: goal.goalKind.iconName,
                    color: color,
                    size: 48,
                    lineWidth: 5
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text(goal.trimmedTitle)
                        .font(.traiHeadline(17))
                        .foregroundStyle(.primary)
                        .lineLimit(2)

                    if let startedText = progress.startedText {
                        Text(startedText)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 0)
            }
        }
        .padding(16)
        .traiCard(glow: .workout, cornerRadius: 20, contentPadding: 0)
    }

    private var historyStats: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            historyStat(title: "Current streak", value: progress.streakText, icon: "flame")
            historyStat(title: "Best run", value: progress.bestStreakText, icon: "sparkles")
            historyStat(title: "Hit rate", value: progress.completionRateText, icon: "percent")
            historyStat(title: "Goal periods", value: "\(progress.historyPeriodCount)", icon: "calendar")
        }
    }

    private func historyStat(title: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(color)
                .frame(width: 28, height: 28)
                .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))

            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(title)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.tertiarySystemFill).opacity(0.65), in: RoundedRectangle(cornerRadius: 14))
    }

    private var historyGridCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("Timeline")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Spacer(minLength: 8)

                Text(selectedCompletionRateText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(color)
            }

            Picker("Range", selection: $selectedRange) {
                ForEach(availableRanges) { range in
                    Text(range.title(for: progress)).tag(range)
                }
            }
            .pickerStyle(.segmented)

            GeometryReader { geometry in
                let availableWidth = max(geometry.size.width, 1)
                let grid = RecurringGoalContributionGrid(
                    progress: progress,
                    color: color,
                    periodsOverride: selectedPeriods,
                    fillsAvailableWidth: false,
                    availableWidth: availableWidth
                )

                ScrollView(.horizontal, showsIndicators: false) {
                    grid
                        .frame(minWidth: availableWidth, alignment: .center)
                        .padding(.vertical, 2)
                }
                .contentMargins(.horizontal, 1, for: .scrollContent)
            }
            .frame(height: historyGridHeight)

            HStack {
                Text(selectedRangeText)
                Spacer(minLength: 8)
                Text("\(selectedCompletedCount) of \(selectedTrackedPeriods.count) hit")
            }
            .font(.caption2.weight(.medium))
            .foregroundStyle(.secondary)
        }
        .traiCard()
    }

    private var historyGridHeight: CGFloat {
        switch progress.periodUnit {
        case .day:
            return 112
        case .week:
            return 122
        case .month:
            return 82
        }
    }
}

private struct RecurringGoalContributionCell: View {
    let period: WorkoutGoalPeriodSnapshot
    let periodLabel: String
    let color: Color
    let size: CGFloat

    private var fillColor: Color {
        guard !period.isBeforeGoalStart else { return Color(.quaternarySystemFill).opacity(0.55) }
        guard !period.isFuture else { return Color(.quaternarySystemFill) }
        guard period.currentCount > 0 else { return Color(.quaternarySystemFill) }

        if period.isTargetMet {
            return Color.green.opacity(0.42 + min(period.targetFraction, 1) * 0.28)
        }
        return color.opacity(0.16 + min(period.targetFraction, 1) * 0.32)
    }

    private var strokeColor: Color {
        period.isCurrent ? color.opacity(0.78) : Color.clear
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 3.5)
            .fill(fillColor)
            .overlay(
                RoundedRectangle(cornerRadius: 3.5)
                    .stroke(strokeColor, lineWidth: period.isCurrent ? 1.5 : 0)
            )
            .frame(width: size, height: size)
            .accessibilityLabel(period.accessibilitySummary(periodLabel: periodLabel))
    }
}

private struct GoalProgressRing: View {
    let progress: Double?
    let iconName: String
    let color: Color
    var size: CGFloat = 52
    var lineWidth: CGFloat = 5

    private var clampedProgress: Double {
        min(max(progress ?? 0, 0), 1)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color(.quaternarySystemFill), lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: clampedProgress)
                .stroke(
                    color,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            Image(systemName: iconName)
                .font(.system(size: max(size * 0.33, 15), weight: .semibold))
                .foregroundStyle(color)
        }
        .frame(width: size, height: size)
        .accessibilityLabel("Goal progress")
        .accessibilityValue(progress.map { "\((Int(($0 * 100).rounded()))) percent" } ?? "Not started")
    }
}

private struct ActivityItem: Identifiable {
    let id = UUID()
    let date: Date
    let workout: LiveWorkout?
    let session: WorkoutSession?
}

private struct WorkoutGoalDetailPersistenceError: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

struct WorkoutGoalDetailSheet: View {
    private enum Presentation: Identifiable {
        case workout(LiveWorkout)
        case session(WorkoutSession)
        case checkIn
        case editGoal
        case goalHistory

        var id: String {
            switch self {
            case .workout(let workout):
                return "workout-\(workout.id.uuidString)"
            case .session(let session):
                return "session-\(session.id.uuidString)"
            case .checkIn:
                return "checkIn"
            case .editGoal:
                return "editGoal"
            case .goalHistory:
                return "goalHistory"
            }
        }
    }

    @Bindable var goal: WorkoutGoal
    let workouts: [LiveWorkout]
    let sessions: [WorkoutSession]
    let exerciseHistory: [ExerciseHistory]
    let useLbs: Bool
    let onToggleCompletion: (WorkoutGoal) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(MonetizationService.self) private var monetizationService: MonetizationService?
    @Environment(ProUpsellCoordinator.self) private var proUpsellCoordinator: ProUpsellCoordinator?
    @State private var activePresentation: Presentation?
    @State private var showDeleteConfirmation = false
    @State private var persistenceError: WorkoutGoalDetailPersistenceError?

    private var insight: WorkoutGoalInsight {
        WorkoutGoalProgressResolver.insights(
            goals: [goal],
            workouts: workouts,
            sessions: sessions,
            exerciseHistory: exerciseHistory,
            useLbs: useLbs
        ).first ?? WorkoutGoalInsight(
            goal: goal,
            progressText: "No progress yet",
            supportingText: nil,
            progressFraction: nil,
            currentValueText: nil,
            targetValueText: nil
        )
    }

    private var relatedWorkouts: [LiveWorkout] {
        WorkoutGoalProgressResolver.matchingCompletedWorkouts(for: goal, in: workouts)
    }

    private var relatedSessions: [WorkoutSession] {
        WorkoutGoalProgressResolver.matchingCompletedSessions(for: goal, in: sessions)
    }

    private var relatedSignals: [RecentWorkoutSignal] {
        WorkoutGoalProgressResolver.signals(for: goal, in: workouts, sessions: sessions)
    }

    private var recentActivityItems: [ActivityItem] {
        // Only sessions after the goal was created
        let workoutItems = relatedWorkouts
            .filter { ($0.completedAt ?? $0.startedAt) >= goal.createdAt }
            .map { w in
                ActivityItem(
                    date: w.completedAt ?? w.startedAt,
                    workout: w,
                    session: nil
                )
            }
        let sessionItems = relatedSessions
            .filter { $0.loggedAt >= goal.createdAt }
            .map { s in
                ActivityItem(
                    date: s.loggedAt,
                    workout: nil,
                    session: s
                )
            }
        return (workoutItems + sessionItems).sorted { $0.date > $1.date }
    }

    private var goalAccentColor: Color {
        goal.status == .completed ? .green : TraiColors.flame
    }

    private var currentRecurringProgressFraction: Double? {
        guard let recurringProgress = insight.recurringProgress else { return nil }
        return recurringProgress.currentPeriod?.targetFraction ?? insight.progressFraction
    }

    private var currentRecurringProgressText: String? {
        guard let recurringProgress = insight.recurringProgress else { return nil }
        return recurringCurrentValueText(recurringProgress, includesTitle: true)
    }

    private var recurringPeriodStatusText: String? {
        guard let recurringProgress = insight.recurringProgress else { return nil }
        if recurringProgress.currentPeriod?.isTargetMet == true {
            return "\(recurringProgress.currentPeriodTitle) complete"
        }
        return recurringProgress.currentPeriodTitle
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    detailHeader
                    progressSection
                    sessionsSection
                    if !relatedSignals.isEmpty || goal.supportingSummary != nil {
                        notesSection
                    }
                    goalActionsSection
                }
                .padding()
            }
            .traiBackground()
            .navigationTitle("Goal Details")
            .toolbarTitleDisplayMode(.inlineLarge)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Dismiss", systemImage: "xmark") {
                        dismiss()
                    }
                    .labelStyle(.iconOnly)
                }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("Edit Goal", systemImage: "pencil") {
                            activePresentation = .editGoal
                        }
                        Button("Delete Goal", systemImage: "trash", role: .destructive) {
                            showDeleteConfirmation = true
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(item: $activePresentation) { presentation in
                presentationContent(presentation)
            }
            .confirmationDialog("Delete Goal", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    modelContext.delete(goal)
                    do {
                        try modelContext.save()
                        dismiss()
                    } catch {
                        modelContext.rollback()
                        persistenceError = WorkoutGoalDetailPersistenceError(
                            title: "Goal Not Deleted",
                            message: error.localizedDescription
                        )
                        HapticManager.error()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete \"\(goal.trimmedTitle)\" and all its progress.")
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
        .proUpsellPresenter()
    }

    @ViewBuilder
    private func presentationContent(_ presentation: Presentation) -> some View {
        switch presentation {
        case .workout(let workout):
            LiveWorkoutDetailSheet(workout: workout, useLbs: useLbs)
                .traiSheetBranding()
        case .session(let session):
            WorkoutDetailSheet(workout: session)
                .traiSheetBranding()
        case .checkIn:
            WorkoutGoalCheckInView(
                goal: goal,
                insight: insight,
                workouts: workouts,
                sessions: sessions
            )
            .traiSheetBranding()
        case .editGoal:
            AddWorkoutGoalSheet(
                editGoal: goal,
                activitySuggestions: [],
                prefersMetricWeight: !useLbs
            )
            .traiSheetBranding()
        case .goalHistory:
            if let recurringProgress = insight.recurringProgress {
                RecurringGoalHistorySheet(
                    goal: goal,
                    progress: recurringProgress,
                    color: goalAccentColor
                )
            }
        }
    }

    private var detailHeader: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                detailHeaderMark

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        if goal.status == .completed {
                            goalStatusPill(goal)
                        } else if let recurringPeriodStatusText {
                            goalPeriodStatusPill(
                                recurringPeriodStatusText,
                                isComplete: insight.recurringProgress?.currentPeriod?.isTargetMet == true
                            )
                        }
                        Text(goal.scopeSummary)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Text(goal.trimmedTitle)
                        .font(.traiHeadline(17))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)

                    if let currentRecurringProgressText {
                        Text(currentRecurringProgressText)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(goalAccentColor)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                }

                Spacer(minLength: 0)
            }
        }
        .padding(16)
        .traiCard(glow: .workout, cornerRadius: 20, contentPadding: 0)
    }

    @ViewBuilder
    private var detailHeaderMark: some View {
        if let currentRecurringProgressFraction {
            GoalProgressRing(
                progress: currentRecurringProgressFraction,
                iconName: goal.goalKind.iconName,
                color: goalAccentColor,
                size: 56,
                lineWidth: 6
            )
        } else {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [goalAccentColor, goalAccentColor.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                Image(systemName: goal.goalKind.iconName)
                    .font(.title3)
                    .foregroundStyle(.white)
            }
            .frame(width: 52, height: 52)
        }
    }

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            TraiSectionHeader("Progress", icon: "chart.line.uptrend.xyaxis")

            if let recurringProgress = insight.recurringProgress {
                RecurringGoalTimeline(
                    progress: recurringProgress,
                    color: goalAccentColor,
                    onShowHistory: recurringProgress.hasExtendedHistory ? {
                        activePresentation = .goalHistory
                    } : nil
                )
            } else if let progressFraction = insight.progressFraction {
                VStack(alignment: .leading, spacing: 6) {
                    ProgressView(value: progressFraction)
                        .tint(goalAccentColor)

                    HStack {
                        Text(insight.progressText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        if let target = insight.targetValueText {
                            Text(target)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(goalAccentColor)
                        }
                    }
                }
            } else {
                Text(insight.progressText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .traiCard()
    }

    private func recurringCurrentValueText(
        _ recurringProgress: WorkoutGoalRecurringProgress,
        includesTitle: Bool = false
    ) -> String {
        guard let currentPeriod = recurringProgress.currentPeriod else {
            return insight.progressText
        }

        let unit = recurringTargetUnit(for: currentPeriod.targetCount)
        if currentPeriod.isTargetMet {
            let completedText = currentPeriod.currentCount > currentPeriod.targetCount
                ? "Completed +\(currentPeriod.currentCount - currentPeriod.targetCount) \(unit)"
                : "Completed"
            if includesTitle {
                return "\(recurringProgress.currentPeriodTitle): \(completedText)"
            }
            return completedText
        }

        let valueText = "\(currentPeriod.currentCount) of \(currentPeriod.targetCount) \(unit)"
        if includesTitle {
            return "\(recurringProgress.currentPeriodTitle): \(valueText)"
        }
        return valueText
    }

    private func recurringTargetUnit(for count: Int) -> String {
        let trimmedUnit = goal.targetUnit.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedUnit.isEmpty {
            return count == 1 ? "session" : "sessions"
        }
        return trimmedUnit
    }

    private var goalActionsSection: some View {
        VStack(spacing: 10) {
            if goal.goalKind == .milestone, goal.status != .completed {
                Button {
                    onToggleCompletion(goal)
                } label: {
                    Label("Mark Done", systemImage: "circle")
                }
                .buttonStyle(.traiSecondary(color: goalAccentColor, fullWidth: true))
            }

            Button {
                if monetizationService?.canAccessAIFeatures ?? true {
                    activePresentation = .checkIn
                } else {
                    proUpsellCoordinator?.present(source: .workoutPlan)
                }
            } label: {
                HStack {
                    TraiLensSymbolIcon(size: 16, variant: .nodes, color: TraiColors.brandAccent)
                    Text("Check in with Trai")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.traiSecondary(color: TraiColors.brandAccent, fullWidth: true))
        }
    }

    private func goalStatusPill(_ goal: WorkoutGoal) -> some View {
        Text(goal.status == .completed ? "Completed" : "Active")
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                (goal.status == .completed ? Color.green.opacity(0.16) : Color.accentColor.opacity(0.14)),
                in: Capsule()
            )
            .foregroundStyle(goal.status == .completed ? .green : Color.accentColor)
    }

    private func goalPeriodStatusPill(_ text: String, isComplete: Bool) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                (isComplete ? Color.green.opacity(0.16) : TraiColors.flame.opacity(0.14)),
                in: Capsule()
            )
            .foregroundStyle(isComplete ? .green : TraiColors.flame)
    }

    private var sessionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            TraiSectionHeader("Sessions", icon: "clock.arrow.circlepath") {
                if !recentActivityItems.isEmpty {
                    Text("\(recentActivityItems.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if recentActivityItems.isEmpty {
                Text("No completed sessions match this goal yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(Array(recentActivityItems.prefix(8))) { item in
                            if let workout = item.workout {
                                CompactLiveWorkoutRow(
                                    workout: workout,
                                    onTap: { activePresentation = .workout(workout) }
                                )
                                .frame(width: 150)
                            } else if let session = item.session {
                                CompactWorkoutSessionRow(
                                    workout: session,
                                    onTap: { activePresentation = .session(session) }
                                )
                                .frame(width: 150)
                            }
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.viewAligned)
                .contentMargins(.horizontal, 1, for: .scrollContent)
            }
        }
        .traiCard()
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            TraiSectionHeader(relatedSignals.isEmpty ? "Notes" : "Recent Context", icon: "text.quote")
                .padding(.bottom, 12)

            let successCriteria = goal.trimmedSuccessCriteria
            let goalNotes = goal.trimmedNotes

            if !successCriteria.isEmpty {
                goalContextRow(
                    title: "Success criteria",
                    text: successCriteria,
                    icon: "checklist.checked"
                )

                if !goalNotes.isEmpty || !relatedSignals.isEmpty {
                    Divider().padding(.vertical, 12)
                }
            }

            if !goalNotes.isEmpty {
                goalContextRow(
                    title: "Goal notes",
                    text: goalNotes,
                    icon: "circle.hexagongrid.circle",
                    showsCheckInDate: true
                )

                if !relatedSignals.isEmpty {
                    Divider().padding(.vertical, 12)
                }
            }

            ForEach(Array(relatedSignals.prefix(4).enumerated()), id: \.element.id) { index, signal in
                if index > 0 {
                    Divider().padding(.vertical, 10)
                }
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(signal.title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Spacer()
                        Text(signal.date, format: .dateTime.month(.abbreviated).day())
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    Text(signal.note)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(4)
                }
            }
        }
        .traiCard()
    }

    private func goalContextRow(
        title: String,
        text: String,
        icon: String,
        showsCheckInDate: Bool = false
    ) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(TraiColors.brandAccent)
                .frame(width: 32, height: 32)
                .background(TraiColors.brandAccent.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    if showsCheckInDate, let promptDate = goal.lastCheckInPromptAt {
                        Text(promptDate, format: .dateTime.month(.abbreviated).day())
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(6)
            }
        }
    }
}

private extension WorkoutGoal {
    var hasUserEditableActivityScope: Bool {
        trimmedActivityName != nil
            || !linkedActivityTags.isEmpty
            || linkedActivityKind != nil
            || linkedActivityRole != nil
    }
}

struct AddWorkoutGoalSheet: View {
    private enum GoalScope: String, CaseIterable, Identifiable {
        case session
        case activity

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .session: "Session"
            case .activity: "Activity"
            }
        }
    }

    private func goalStatusPill(_ goal: WorkoutGoal) -> some View {
        Text(goal.status == .completed ? "Completed" : "Active")
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                (goal.status == .completed ? Color.green.opacity(0.16) : Color.accentColor.opacity(0.14)),
                in: Capsule()
            )
            .foregroundStyle(goal.status == .completed ? .green : Color.accentColor)
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let workoutType: WorkoutMode?
    let activitySuggestions: [String]
    let prefersMetricWeight: Bool
    let onSave: (WorkoutGoal) -> Bool
    private let editingGoal: WorkoutGoal?
    private let editingOriginalGeneratedPlanTemplateIDs: [UUID]
    private let editingOriginalGeneratedPlanBlockIDs: [UUID]
    private let editingOriginalTracksGeneratedPlanAdherence: Bool
    private let editingOriginalRequiresGeneratedPlanBlockScope: Bool

    @State private var title = ""
    @State private var goalKind: WorkoutGoal.GoalKind = .milestone
    @State private var scope: GoalScope = .session
    @State private var selectedWorkoutType: WorkoutMode
    @State private var activityName = ""
    @State private var activityTagsText = ""
    @State private var selectedActivityRole: WorkoutPlan.TrainingBlock.Role?
    @State private var targetValueText = ""
    @State private var baselineValueText = ""
    @State private var targetUnit: String
    @State private var periodUnit: WorkoutGoal.PeriodUnit = .week
    @State private var periodCountText = "1"
    @State private var successCriteria = ""
    @State private var targetDateEnabled = false
    @State private var targetDate = Calendar.current.date(byAdding: .day, value: 42, to: Date()) ?? Date()
    @State private var checkInCadenceDaysText = ""
    @State private var notes = ""

    /// Create a new goal.
    init(
        workoutType: WorkoutMode?,
        activitySuggestions: [String],
        prefersMetricWeight: Bool,
        onSave: @escaping (WorkoutGoal) -> Bool
    ) {
        self.workoutType = workoutType
        self.activitySuggestions = activitySuggestions
        self.prefersMetricWeight = prefersMetricWeight
        self.onSave = onSave
        self.editingGoal = nil
        self.editingOriginalGeneratedPlanTemplateIDs = []
        self.editingOriginalGeneratedPlanBlockIDs = []
        self.editingOriginalTracksGeneratedPlanAdherence = false
        self.editingOriginalRequiresGeneratedPlanBlockScope = false
        _selectedWorkoutType = State(initialValue: workoutType ?? .custom)
        _targetUnit = State(initialValue: Self.defaultUnit(for: .milestone, prefersMetricWeight: prefersMetricWeight))
    }

    /// Edit an existing goal. Changes are written directly to the `@Model` object on save.
    init(
        editGoal existing: WorkoutGoal,
        activitySuggestions: [String],
        prefersMetricWeight: Bool,
        onSave: @escaping (WorkoutGoal) -> Bool = { _ in true }
    ) {
        self.workoutType = existing.linkedWorkoutType
        self.activitySuggestions = activitySuggestions
        self.prefersMetricWeight = prefersMetricWeight
        self.onSave = onSave
        self.editingGoal = existing
        self.editingOriginalGeneratedPlanTemplateIDs = existing.generatedPlanTemplateIDs
        self.editingOriginalGeneratedPlanBlockIDs = existing.generatedPlanBlockIDs
        self.editingOriginalTracksGeneratedPlanAdherence = existing.tracksGeneratedPlanAdherence
        self.editingOriginalRequiresGeneratedPlanBlockScope = existing.requiresGeneratedPlanBlockScope
        _title = State(initialValue: existing.title)
        _goalKind = State(initialValue: existing.goalKind)
        _scope = State(initialValue: existing.hasUserEditableActivityScope ? .activity : .session)
        _selectedWorkoutType = State(initialValue: existing.linkedWorkoutType ?? .custom)
        _activityName = State(initialValue: existing.linkedActivityName ?? "")
        _activityTagsText = State(initialValue: existing.linkedActivityTags.joined(separator: ", "))
        _selectedActivityRole = State(initialValue: existing.linkedActivityRole)
        _targetValueText = State(initialValue: Self.formatDoubleForField(existing.targetValue))
        _baselineValueText = State(initialValue: Self.formatDoubleForField(existing.baselineValue))
        _targetUnit = State(
            initialValue: existing.targetUnit.isEmpty
                ? Self.defaultUnit(for: existing.goalKind, prefersMetricWeight: prefersMetricWeight)
                : existing.targetUnit
        )
        _periodUnit = State(initialValue: existing.periodUnit ?? .week)
        _periodCountText = State(initialValue: existing.periodCount.map { "\($0)" } ?? "1")
        _successCriteria = State(initialValue: existing.successCriteria)
        _targetDateEnabled = State(initialValue: existing.targetDate != nil)
        _targetDate = State(initialValue: existing.targetDate ?? Calendar.current.date(byAdding: .day, value: 42, to: Date()) ?? Date())
        _checkInCadenceDaysText = State(initialValue: existing.checkInCadenceDays.map { "\($0)" } ?? "")
        _notes = State(initialValue: existing.notes)
    }

    private static func formatDoubleForField(_ value: Double?) -> String {
        guard let value else { return "" }
        return value.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(value.rounded()))"
            : String(format: "%.1f", value)
    }

    private var unitOptions: [String] {
        switch goalKind {
        case .milestone:
            return []
        case .frequency:
            return ["sessions"]
        case .duration:
            return ["min", "hr"]
        case .distance:
            return prefersMetricWeight ? ["km", "m"] : ["mi", "km"]
        case .count:
            return ["reps", "attempts", "rounds"]
        case .weight:
            return prefersMetricWeight ? ["kg", "lbs"] : ["lbs", "kg"]
        }
    }

    private var isSaveDisabled: Bool {
        let hasActivityScope = !activityName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            !activityTagsText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            selectedActivityRole != nil
        return title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        (scope == .activity && !hasActivityScope) ||
        (goalKind.supportsNumericTarget && Double(targetValueText.trimmingCharacters(in: .whitespacesAndNewlines)) == nil)
    }

    private var parsedActivityTags: [String] {
        activityTagsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Goal", systemImage: "scope")
                            .font(.headline)

                        TextField("e.g. Send the blue V5 clean, Hold a 60 minute flow, Hit 225 on bench", text: $title)
                            .padding(12)
                            .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 12))

                        TextField("Success criteria", text: $successCriteria, axis: .vertical)
                            .lineLimit(1...3)
                            .padding(12)
                            .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 12))

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(WorkoutGoal.GoalKind.allCases) { kind in
                                    Button {
                                        goalKind = kind
                                        targetUnit = Self.defaultUnit(for: kind, prefersMetricWeight: prefersMetricWeight)
                                    } label: {
                                        Label(kind.displayName, systemImage: kind.iconName)
                                            .font(.caption.weight(.semibold))
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                            .background(
                                                (goalKind == kind ? Color.accentColor : Color(.tertiarySystemFill)),
                                                in: Capsule()
                                            )
                                            .foregroundStyle(goalKind == kind ? .white : .primary)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .traiCard()

                    VStack(alignment: .leading, spacing: 12) {
                        Label("Track", systemImage: "figure.walk.motion")
                            .font(.headline)

                        Picker("Scope", selection: $scope) {
                            ForEach(GoalScope.allCases) { goalScope in
                                Text(goalScope.displayName).tag(goalScope)
                            }
                        }
                        .pickerStyle(.segmented)

                        if workoutType == nil {
                            Picker("Session Type", selection: $selectedWorkoutType) {
                                ForEach(WorkoutMode.allCases) { mode in
                                    Text(mode.displayName).tag(mode)
                                }
                            }
                            .pickerStyle(.menu)
                        } else {
                            Label(selectedWorkoutType.displayName, systemImage: selectedWorkoutType.iconName)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }

                        Text(scope == .session ? "This goal will follow your \(selectedWorkoutType.displayName.lowercased()) sessions." : "Tie it to a movement, activity, or part of a workout.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if scope == .activity {
                            TextField("Movement or activity (optional)", text: $activityName)
                                .padding(12)
                                .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 12))

                            TextField("Related focus (optional, comma separated)", text: $activityTagsText)
                                .padding(12)
                                .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 12))

                            activityRoleMenu

                            if !activitySuggestions.isEmpty {
                                FlowLayout(spacing: 8) {
                                    ForEach(activitySuggestions, id: \.self) { suggestion in
                                        Button(suggestion) {
                                            activityName = suggestion
                                        }
                                        .font(.caption)
                                        .buttonStyle(.traiSecondary(size: .compact, fullWidth: false))
                                    }
                                }
                            }
                        }
                    }
                    .traiCard()

                    if goalKind.supportsNumericTarget {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Target", systemImage: "target")
                                .font(.headline)

                            HStack(spacing: 10) {
                                TextField("Target value", text: $targetValueText)
                                    .keyboardType(.decimalPad)
                                    .padding(12)
                                    .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 12))

                                Picker("Unit", selection: $targetUnit) {
                                    ForEach(unitOptions, id: \.self) { option in
                                        Text(option).tag(option)
                                    }
                                }
                                .pickerStyle(.segmented)
                            }

                            if goalKind == .weight {
                                TextField(
                                    "Starting point (optional, e.g. \(targetUnit.isEmpty ? "130" : "130 \(targetUnit)"))",
                                    text: $baselineValueText
                                )
                                .keyboardType(.decimalPad)
                                .padding(12)
                                .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 12))

                                Text("Used to calculate real progress — how far you've come, not just where you are.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            if goalKind.usesPeriodTarget {
                                HStack(spacing: 10) {
                                    TextField("Period count", text: $periodCountText)
                                        .keyboardType(.numberPad)
                                        .padding(12)
                                        .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 12))

                                    Picker("Period", selection: $periodUnit) {
                                        ForEach(WorkoutGoal.PeriodUnit.allCases) { option in
                                            Text(option.displayName).tag(option)
                                        }
                                    }
                                    .pickerStyle(.segmented)
                                }
                            }
                        }
                        .traiCard()
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Label("Timing", systemImage: "calendar")
                            .font(.headline)

                        Toggle("Add a soft target date", isOn: $targetDateEnabled)

                        if targetDateEnabled {
                            DatePicker("Target date", selection: $targetDate, displayedComponents: .date)
                                .datePickerStyle(.compact)
                        }

                        TextField("Check in every X days (optional)", text: $checkInCadenceDaysText)
                            .keyboardType(.numberPad)
                            .padding(12)
                            .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 12))
                    }
                    .traiCard()

                    VStack(alignment: .leading, spacing: 12) {
                        Label("Notes", systemImage: "note.text")
                            .font(.headline)

                        TextEditor(text: $notes)
                            .frame(minHeight: 110)
                            .padding(8)
                            .scrollContentBackground(.hidden)
                            .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 12))
                    }
                    .traiCard()
                }
                .padding()
            }
            .navigationTitle(editingGoal == nil ? "New Goal" : "Edit Goal")
            .toolbarTitleDisplayMode(.inlineLarge)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", systemImage: "checkmark") {
                        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
                        let baseline = goalKind == .weight
                            ? Double(baselineValueText.trimmingCharacters(in: .whitespacesAndNewlines))
                            : nil
                        let preservesGeneratedPlanScope = editingOriginalTracksGeneratedPlanAdherence
                            || !editingOriginalGeneratedPlanTemplateIDs.isEmpty
                            || !editingOriginalGeneratedPlanBlockIDs.isEmpty

                        if let existing = editingGoal {
                            existing.title = trimmedTitle
                            existing.goalKindRaw = goalKind.rawValue
                            if preservesGeneratedPlanScope {
                                existing.linkedWorkoutTypeRaw = nil
                                existing.linkedActivityName = nil
                                existing.linkedActivityTags = []
                                existing.linkedActivityKind = nil
                                existing.linkedActivityRole = nil
                            } else {
                                existing.linkedWorkoutTypeRaw = selectedWorkoutType.rawValue
                                existing.linkedActivityName = scope == .activity
                                    ? activityName.trimmingCharacters(in: .whitespacesAndNewlines)
                                    : nil
                                existing.linkedActivityTags = scope == .activity ? parsedActivityTags : []
                                existing.linkedActivityKind = nil
                                existing.linkedActivityRole = scope == .activity ? selectedActivityRole : nil
                            }
                            existing.targetValue = goalKind.supportsNumericTarget
                                ? Double(targetValueText.trimmingCharacters(in: .whitespacesAndNewlines))
                                : nil
                            existing.targetUnit = goalKind.supportsNumericTarget ? targetUnit : ""
                            existing.periodUnitRaw = goalKind.usesPeriodTarget ? periodUnit.rawValue : nil
                            existing.periodCount = goalKind.usesPeriodTarget
                                ? Int(periodCountText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 1
                                : nil
                            existing.successCriteria = successCriteria.trimmingCharacters(in: .whitespacesAndNewlines)
                            existing.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
                            existing.targetDate = targetDateEnabled ? targetDate : nil
                            existing.checkInCadenceDays = Int(checkInCadenceDaysText.trimmingCharacters(in: .whitespacesAndNewlines))
                            existing.baselineValue = baseline
                            existing.tracksGeneratedPlanAdherence = editingOriginalTracksGeneratedPlanAdherence
                            existing.generatedPlanBlockIDs = editingOriginalGeneratedPlanBlockIDs
                            existing.generatedPlanTemplateIDs = editingOriginalGeneratedPlanTemplateIDs
                            existing.requiresGeneratedPlanBlockScope = editingOriginalRequiresGeneratedPlanBlockScope
                            existing.updatedAt = Date()
                            do {
                                try modelContext.save()
                                dismiss()
                            } catch {
                                modelContext.rollback()
                                HapticManager.error()
                            }
                        } else {
                            let newGoal = WorkoutGoal(
                                title: trimmedTitle,
                                goalKind: goalKind,
                                linkedWorkoutType: selectedWorkoutType,
                                linkedActivityName: scope == .activity ? activityName : nil,
                                linkedActivityTags: scope == .activity ? parsedActivityTags : [],
                                linkedActivityKind: nil,
                                linkedActivityRole: scope == .activity ? selectedActivityRole : nil,
                                targetValue: goalKind.supportsNumericTarget ? Double(targetValueText.trimmingCharacters(in: .whitespacesAndNewlines)) : nil,
                                targetUnit: goalKind.supportsNumericTarget ? targetUnit : "",
                                periodUnit: goalKind.usesPeriodTarget ? periodUnit : nil,
                                periodCount: goalKind.usesPeriodTarget ? Int(periodCountText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 1 : nil,
                                successCriteria: successCriteria.trimmingCharacters(in: .whitespacesAndNewlines),
                                notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
                                targetDate: targetDateEnabled ? targetDate : nil,
                                checkInCadenceDays: Int(checkInCadenceDaysText.trimmingCharacters(in: .whitespacesAndNewlines)),
                                baselineValue: baseline
                            )
                            if onSave(newGoal) {
                                dismiss()
                            } else {
                                HapticManager.error()
                            }
                        }
                    }
                    .labelStyle(.iconOnly)
                    .disabled(isSaveDisabled)
                    .tint(.accentColor)
                }
            }
        }
        .traiSheetBranding()
    }

    private var activityRoleMenu: some View {
        Menu {
            Button("Anywhere in workout") {
                selectedActivityRole = nil
            }
            ForEach(WorkoutPlan.TrainingBlock.Role.allCases) { role in
                Button {
                    selectedActivityRole = role
                } label: {
                    Label(role.placementDisplayName, systemImage: role.iconName)
                }
            }
        } label: {
            Label(selectedActivityRole?.placementDisplayName ?? "Anywhere in workout", systemImage: selectedActivityRole?.iconName ?? "slider.horizontal.3")
                .font(.caption.weight(.semibold))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.traiSecondary(size: .compact, fullWidth: true))
    }

    private static func defaultUnit(for kind: WorkoutGoal.GoalKind, prefersMetricWeight: Bool) -> String {
        switch kind {
        case .milestone:
            return ""
        case .frequency:
            return "sessions"
        case .duration:
            return "min"
        case .distance:
            return prefersMetricWeight ? "km" : "mi"
        case .count:
            return "reps"
        case .weight:
            return prefersMetricWeight ? "kg" : "lbs"
        }
    }
}
