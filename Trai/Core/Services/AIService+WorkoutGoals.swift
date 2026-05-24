//
//  AIService+WorkoutGoals.swift
//  Trai
//

import Foundation

struct WorkoutGoalSuggestion: Codable, Identifiable, Sendable {
    let title: String
    let rationale: String
    let goalKindRaw: String
    let linkedWorkoutTypeRaw: String?
    let linkedActivityName: String?
    let linkedActivityTags: [String]?
    let linkedActivityKindRaw: String?
    let linkedActivityRoleRaw: String?
    let targetValue: Double?
    let targetUnit: String?
    let periodUnitRaw: String?
    let periodCount: Int?
    let successCriteria: String?
    let notes: String?
    let targetDateISO8601: String?
    let checkInCadenceDays: Int?
    var tracksGeneratedPlanAdherence: Bool? = nil

    var id: String {
        [
            title,
            goalKindRaw,
            linkedWorkoutTypeRaw ?? "",
            linkedActivityName ?? "",
            linkedActivityTags?.joined(separator: ",") ?? "",
            linkedActivityKindRaw ?? "",
            linkedActivityRoleRaw ?? "",
            tracksGeneratedPlanAdherence == true ? "planAdherence" : ""
        ].joined(separator: "|")
    }

    var goalKind: WorkoutGoal.GoalKind {
        WorkoutGoal.GoalKind(rawValue: goalKindRaw) ?? .milestone
    }

    var linkedWorkoutType: WorkoutMode? {
        linkedWorkoutTypeRaw.flatMap(WorkoutMode.init(rawValue:))
    }

    var periodUnit: WorkoutGoal.PeriodUnit? {
        periodUnitRaw.flatMap(WorkoutGoal.PeriodUnit.init(rawValue:))
    }

    var targetDate: Date? {
        guard let targetDateISO8601, !targetDateISO8601.isEmpty else { return nil }
        if let isoDate = ISO8601DateFormatter().date(from: targetDateISO8601) {
            return isoDate
        }

        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: targetDateISO8601)
    }

    func asWorkoutGoal() -> WorkoutGoal {
        WorkoutGoal(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            goalKind: goalKind,
            linkedWorkoutType: linkedWorkoutType,
            linkedActivityName: linkedActivityName?.trimmingCharacters(in: .whitespacesAndNewlines),
            linkedActivityTags: linkedActivityTags ?? [],
            linkedActivityKind: linkedActivityKindRaw.flatMap(WorkoutPlan.TrainingBlock.BlockKind.init(rawValue:)),
            linkedActivityRole: linkedActivityRoleRaw.flatMap(WorkoutPlan.TrainingBlock.Role.init(rawValue:)),
            targetValue: goalKind.supportsNumericTarget ? targetValue : nil,
            targetUnit: goalKind.supportsNumericTarget ? (targetUnit ?? "") : "",
            periodUnit: periodTrackingGoalKinds.contains(goalKind) ? periodUnit : nil,
            periodCount: periodTrackingGoalKinds.contains(goalKind) ? periodCount : nil,
            successCriteria: successCriteria?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            notes: notes?.trimmingCharacters(in: .whitespacesAndNewlines) ?? rationale,
            targetDate: targetDate,
            checkInCadenceDays: checkInCadenceDays,
            tracksGeneratedPlanAdherence: tracksGeneratedPlanAdherence == true
        )
    }
}

private struct WorkoutGoalSuggestionResponse: Codable {
    let suggestions: [WorkoutGoalSuggestion]
}

struct WorkoutGoalRecommendationContextBuilder {
    static func recentSessionSummaries(
        workouts: [LiveWorkout],
        sessions: [WorkoutSession]
    ) -> [String] {
        let live = workouts
            .filter { $0.completedAt != nil }
            .sorted { ($0.completedAt ?? $0.startedAt) > ($1.completedAt ?? $1.startedAt) }
            .prefix(4)
            .map { workout in
                let activityDetails = recentActivityDetails(for: workout)
                let detailParts = [workout.displayFocusSummary, workout.type.displayName, workout.formattedDuration]
                    + Array(activityDetails.prefix(3))
                let detail = detailParts
                    .filter { !$0.isEmpty }
                    .joined(separator: " • ")
                return "\(workout.name) (\(detail))"
            }

        let imported = sessions
            .sorted { $0.loggedAt > $1.loggedAt }
            .prefix(4)
            .map { session in
                let detail = session.historyDetailSegments.joined(separator: " • ")
                return "\(session.displayName) (\(detail))"
            }

        return Array((live + imported).prefix(6))
    }

    private static func recentActivityDetails(for workout: LiveWorkout) -> [String] {
        (workout.entries ?? [])
            .filter { !$0.isStrength && $0.hasExercisePreferenceSignal }
            .sorted { $0.orderIndex < $1.orderIndex }
            .map { entry in
                let details = goalContextActivitySummarySegments(for: entry)
                    .prefix(4)
                return ([entry.exerciseName] + Array(details)).joined(separator: " ")
            }
    }

    private static func goalContextActivitySummarySegments(for entry: LiveWorkoutEntry) -> [String] {
        var segments: [String] = []
        let activityName = entry.activityTypeName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !activityName.isEmpty, activityName.goalNormalizedKey != entry.exerciseName.goalNormalizedKey {
            segments.append(activityName)
        }
        let durationSeconds = entry.trackedDurationSeconds
        if durationSeconds > 0 {
            segments.append("\(durationSeconds / 60) min")
        }
        if let distance = entry.formattedDistance {
            segments.append(distance)
        }
        let loggedSegments = entry.activitySegments.filter(\.hasLoggedData)
        if loggedSegments.count > 1 {
            segments.append("\(loggedSegments.count) \(pluralized(goalContextSegmentLabel(for: entry), count: loggedSegments.count))")
        }
        let countTotal = loggedSegments
            .compactMap(\.reps)
            .filter { $0 > 0 }
            .reduce(0, +)
        if countTotal > 0 {
            segments.append("\(countTotal) \(pluralized(goalContextCountLabel(for: entry), count: countTotal))")
        }
        return segments
    }

    private static func goalContextSegmentLabel(for entry: LiveWorkoutEntry) -> String {
        switch entry.resolvedActivityCategory {
        case .conditioning:
            return "round"
        default:
            return "segment"
        }
    }

    private static func goalContextCountLabel(for entry: LiveWorkoutEntry) -> String {
        switch entry.resolvedActivityCategory {
        case .sportPractice:
            return "attempt"
        case .conditioning:
            return "round"
        case .mobility, .recovery:
            return "rep"
        default:
            return "rep"
        }
    }

    private static func pluralized(_ label: String, count: Int) -> String {
        guard count != 1 else { return label }
        return label.hasSuffix("s") ? label : "\(label)s"
    }

    static func recentTrainingSummary(
        workouts: [LiveWorkout],
        sessions: [WorkoutSession],
        now: Date = Date()
    ) -> [String] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: now) ?? .distantPast

        let liveModes = workouts
            .filter { ($0.completedAt ?? $0.startedAt) >= cutoff }
            .map(\.type)

        let sessionModes = sessions
            .filter { $0.loggedAt >= cutoff }
            .map(\.inferredWorkoutMode)

        let modeCounts = Dictionary((liveModes + sessionModes).map { ($0, 1) }, uniquingKeysWith: +)
        let modeLines = modeCounts
            .sorted { lhs, rhs in
                if lhs.value != rhs.value {
                    return lhs.value > rhs.value
                }
                return lhs.key.displayName < rhs.key.displayName
            }
            .prefix(4)
            .map { mode, count in
                "\(mode.displayName): \(count) session\(count == 1 ? "" : "s") in the last 30 days"
            }

        let liveActivityTokens = workouts
            .filter { ($0.completedAt ?? $0.startedAt) >= cutoff }
            .flatMap { workout in
                let focus = workout.focusAreas.map(\.goalNormalizedKey)
                return focus.isEmpty ? [workout.name.goalNormalizedKey] : focus
            }

        let sessionActivityTokens = sessions
            .filter { $0.loggedAt >= cutoff }
            .flatMap { session in
                let tokens = Array(session.goalMatchingTokens)
                return tokens.isEmpty ? [session.displayName.goalNormalizedKey] : tokens
            }

        let activityCounts = Dictionary((liveActivityTokens + sessionActivityTokens).map { ($0, 1) }, uniquingKeysWith: +)
        let activityLines = activityCounts
            .filter { !$0.key.isEmpty }
            .sorted { lhs, rhs in
                if lhs.value != rhs.value {
                    return lhs.value > rhs.value
                }
                return lhs.key < rhs.key
            }
            .prefix(3)
            .map { activity, count in
                "Recurring focus: \(activity.capitalized) (\(count)x)"
            }

        return modeLines + activityLines
    }

    static func exerciseSummaries(
        history: [ExerciseHistory],
        prefersMetricWeight: Bool
    ) -> [String] {
        let snapshots = ExercisePerformanceService.snapshots(from: history.filter(\.hasStrengthMetrics))
        let strengthExerciseNames = Set(snapshots.keys.map(\.goalNormalizedKey))

        let strengthSummaries = snapshots.values
            .sorted { lhs, rhs in
                if lhs.totalSessions != rhs.totalSessions {
                    return lhs.totalSessions > rhs.totalSessions
                }
                return lhs.exerciseName < rhs.exerciseName
            }
            .prefix(10)
            .map { snapshot in
                var parts: [String] = ["\(snapshot.exerciseName): \(snapshot.totalSessions) sessions"]

                if let lastSession = snapshot.lastSession {
                    parts.append("last \(lastSession.formattedDate)")
                }

                if let weightPR = snapshot.weightPR {
                    parts.append("best \(weightPR.formattedWeight(usesMetric: prefersMetricWeight)) x \(weightPR.bestSetReps)")
                } else if let repsPR = snapshot.repsPR {
                    parts.append("best \(repsPR.bestSetReps) reps")
                }

                if let estimatedOneRepMax = snapshot.estimatedOneRepMax, estimatedOneRepMax > 0 {
                    let oneRMText = prefersMetricWeight
                        ? "\(Int(estimatedOneRepMax.rounded())) kg est 1RM"
                        : "\(Int((estimatedOneRepMax * WeightUtility.kgToLbs).rounded())) lbs est 1RM"
                    parts.append(oneRMText)
                }

                return parts.joined(separator: " • ")
            }

        let activitySummaries = activityExerciseSummaries(
            from: history.filter { record in
                !record.hasStrengthMetrics &&
                !strengthExerciseNames.contains(record.exerciseName.goalNormalizedKey)
            }
        )

        return Array((strengthSummaries + activitySummaries).prefix(10))
    }

    private static func activityExerciseSummaries(from history: [ExerciseHistory]) -> [String] {
        let grouped = Dictionary(grouping: history) { $0.exerciseName }

        return grouped.compactMap { exerciseName, records -> (String, Int, Date)? in
            let trackable = records.filter { record in
                record.durationSeconds > 0 ||
                record.distanceMeters > 0 ||
                record.totalSets > 0 ||
                record.totalReps > 0
            }
            guard !trackable.isEmpty else { return nil }

            let latest = trackable.max { $0.performedAt < $1.performedAt }
            let totalDuration = trackable.map(\.durationSeconds).reduce(0, +)
            let totalDistance = trackable.map(\.distanceMeters).reduce(0, +)
            let totalSegments = trackable.map(\.totalSets).reduce(0, +)
            let totalCount = trackable.map(\.totalReps).reduce(0, +)
            let countLabel = activityHistoryCountLabel(for: latest)

            var parts: [String] = ["\(exerciseName): \(trackable.count) sessions"]
            if let latest {
                let activityName = latest.activityTypeName.trimmingCharacters(in: .whitespacesAndNewlines)
                if !activityName.isEmpty, activityName.goalNormalizedKey != exerciseName.goalNormalizedKey {
                    parts.append(activityName)
                }
                parts.append("last \(latest.formattedDate)")
            }
            if totalDuration > 0 {
                parts.append("\(totalDuration / 60) min total")
            }
            if totalDistance > 0 {
                parts.append(formatActivityDistance(totalDistance))
            }
            if totalCount > 0 {
                parts.append("\(totalCount) \(pluralized(countLabel, count: totalCount)) total")
            } else if totalSegments > 0 {
                parts.append("\(totalSegments) \(pluralized("segment", count: totalSegments)) total")
            }

            return (parts.joined(separator: " • "), trackable.count, latest?.performedAt ?? .distantPast)
        }
        .sorted { lhs, rhs in
            if lhs.1 != rhs.1 {
                return lhs.1 > rhs.1
            }
            return lhs.2 > rhs.2
        }
        .map(\.0)
    }

    private static func activityHistoryCountLabel(for record: ExerciseHistory?) -> String {
        switch record?.activityKind {
        case .sportPractice, .skill:
            return "attempt"
        case .conditioning:
            return "round"
        case .mobility, .recovery:
            return "rep"
        default:
            return "rep"
        }
    }

    private static func formatActivityDistance(_ meters: Double) -> String {
        if meters >= 1000 {
            return String(format: "%.1f km total", meters / 1000)
        }
        return "\(Int(meters.rounded())) m total"
    }
}

extension AIService {
    func checkInOnGoal(
        goalTitle: String,
        goalKind: String,
        goalScope: String,
        successCriteria: String?,
        currentProgress: String?,
        targetSummary: String?,
        recentSessionSummaries: [String],
        userMessage: String,
        conversationHistory: [(role: String, text: String)]
    ) async throws -> String {
        try await performAIRequest(for: .coachChat) {
            let systemPrompt = """
            You are Trai, a focused fitness coach. The user is checking in on a specific workout goal.

            Goal: \(goalTitle)
            Kind: \(goalKind)
            Scope: \(goalScope)
            Success criteria: \(successCriteria?.isEmpty == false ? successCriteria! : "Not specified")
            Current progress: \(currentProgress ?? "Not yet measured")
            Target: \(targetSummary ?? "No specific target set")
            Recent related sessions: \(recentSessionSummaries.isEmpty ? "None yet" : recentSessionSummaries.joined(separator: " | "))

            Your role:
            - Acknowledge what the user tells you about their progress
            - Give honest, concise feedback — encourage when warranted, be realistic when not
            - Help them think about next steps or adjustments
            - Keep responses focused on this goal, not general advice
            - Use 2-4 short sentences per reply. No bullet lists.
            """

            var messages: [TraiAIMessage] = [
                AIBackendPayloadBuilder.canonicalTextMessage(role: .user, text: systemPrompt),
                AIBackendPayloadBuilder.canonicalTextMessage(role: .assistant, text: "Got it. I'm looking at your goal and recent training. What's on your mind?")
            ]

            for entry in conversationHistory.suffix(10) {
                let role: TraiAIMessageRole = entry.role == "user" ? .user : .assistant
                messages.append(AIBackendPayloadBuilder.canonicalTextMessage(role: role, text: entry.text))
            }

            messages.append(AIBackendPayloadBuilder.canonicalTextMessage(role: .user, text: userMessage))

            let request = AIBackendPayloadBuilder.canonicalRequest(
                messages: messages,
                generation: AIBackendPayloadBuilder.canonicalGeneration(reasoningLevel: .low, maxTokens: 512)
            )

            logPrompt(userMessage)
            let response = try await makeRequest(request: request)
            logResponse(response)
            return response
        }
    }

    func suggestWorkoutGoals(
        userGoal: String?,
        plannedSessions: [String],
        recentSessions: [String],
        recentTrainingSummary: [String],
        exerciseSummaries: [String],
        memoryContext: [String],
        existingGoals: [String],
        userIntent: String?,
        prefersMetricWeight: Bool
    ) async throws -> [WorkoutGoalSuggestion] {
        try await performAIRequest(for: .workoutPlanRefinement) {
            let workoutModes = WorkoutMode.allCases.map(\.rawValue).joined(separator: ", ")
            let contextGoal = userGoal?.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedIntent = userIntent?.trimmingCharacters(in: .whitespacesAndNewlines)

            let prompt = """
            You are helping set workout goals inside Trai.

            Create 0-2 workout goals that feel lightweight, motivating, and directly tied to what the user is already doing. One strong goal is better than two weak goals. Returning no goals is acceptable when the context does not support a specific, useful, trackable goal.

            Rules:
            - Suggest at most 2 goals.
            - Prefer one concrete plan-specific goal. Add a second only when it captures a different, meaningful intent from the plan or user request.
            - Goals should feel meaningful over roughly the next 4-8 weeks unless the user asked for a different timeline.
            - Goals should usually represent something the user works toward over multiple sessions or multiple weeks, not a single routine completion.
            - Do NOT suggest goals that merely restate a single normal workout task; goals should reflect a habit, milestone, progression target, or follow-up loop over time.
            - Do NOT suggest maintenance goals like "hold steady" unless the user is explicitly deloading, returning from injury, or asked for maintenance.
            - If the user already does a session type consistently, suggest progression, volume, duration, quality, or milestone goals instead of simple attendance.
            - Use frequency goals when the user's pattern or request is about consistency, e.g. 3 sessions per week.
            - Add a numeric goal only if the recent training data clearly supports it, unless the user explicitly asked for a frequency such as weekly cardio.
            - Do not create exercise-specific weight-increase goals for new users or thin context unless recent sessions, exercise summaries, memory, or the user request includes a current baseline for that exercise.
            - Do not infer a strength baseline just because an exercise appears in the plan.
            - Weight/load goals require a known current baseline and should progress from that baseline.
            - Do not create vague progression goals unless the structured target and successCriteria make the exact achievement verifiable from app data.
            - Broad goals are allowed, but the intent must be accurate: title, target fields, linkedWorkoutType/linkedActivityName/linkedActivityTags/linkedActivityKindRaw/linkedActivityRoleRaw, and successCriteria should all describe the same behavior Trai can track.
            - Set tracksGeneratedPlanAdherence true only when the goal tracks completion of the whole generated weekly plan structure, not a specific activity family, support block, exercise, or modality.
            - If the current plan includes a personalized constraint, habit, or recurring support block, prefer a goal for that specific plan behavior over generic progression.
            - For a brand-new workout plan with little history, use goals that establish the plan: weekly structure adherence, named-day/session-type completion across several weeks, requested recurring habits, check-in cadence, or logging enough sessions for Trai to personalize the next revision.
            - Every frequency, duration, distance, count, or weight goal must have a targetValue greater than 0 and a clear targetUnit.
            - Use count goals for trackable reps, attempts, rounds, completed routes, laps, or segments when the app can count them from logged sets or activity segments.
            - Every frequency, duration, distance, and count goal must also include periodUnitRaw and periodCount.
            - For frequency and count goals, periodCount means the denominator period, not the goal horizon. Use periodCount 1 for "per week", "per day", or "per month"; use targetDateISO8601/checkInCadenceDays to express a 4-8 week horizon.
            - For duration and distance goals, use periodUnitRaw/periodCount to describe the accumulation window, such as 45 min per week or 10 km per month.
            - Every goal must include successCriteria: one concise sentence that says how Trai and the person using the app will know the goal is achieved. This is especially important for creative, skill, sport, form, consistency quality, or milestone goals that do not fit a simple numeric target.
            - Write rationale, successCriteria, and notes directly to the person using the app with "you" and "your"; do not say "the user".
            - Do not return vague frequency goals unless the structured fields make the tracked behavior clear.
            - If you cannot make a goal trackable from the plan and context, choose a milestone goal or omit that suggestion.
            - Do not invent an unrealistic modality or activity.
            - Do not name a modality, activity, exercise, or event that does not actually appear in the plan or context.
            - Avoid duplicating any existing goal.
            - If the user gave a specific ask, prioritize that.
            - If the context is thin, prefer a broader but still meaningful goal over a vague or tiny one, and return only one goal when a second would be filler.
            - If an exercise clearly appears as a recurring anchor movement in the history, it is okay to recommend an exercise-specific goal tied to linkedActivityName.
            - Use linkedWorkoutType when the goal is broad to a session type.
            - Use linkedActivityName when the goal is tied to a specific exercise or activity like a route, lift, or interval format.
            - Use linkedActivityTags for semantic activity families, custom activity types, or personalized targets such as Climbing, grip, intervals, mobility, or technique.
            - Use linkedActivityKindRaw and linkedActivityRoleRaw only as behavioral fallback metadata, such as support work, mobility warmups, skill accessories, or recovery cooldowns. For support work inside another workout, prefer linkedActivityTags plus linkedActivityRoleRaw when the activity has a meaningful semantic identity.
            - linkedWorkoutType must be one of: \(workoutModes)
            - linkedActivityKindRaw can be \(AIPromptBuilder.workoutGoalActivityKindPromptList). Warmup and cooldown are placement roles, not activity kinds.
            - linkedActivityRoleRaw can be \(AIPromptBuilder.workoutGoalActivityRolePromptList).
            - goalKind must be one of: milestone, frequency, duration, distance, count, weight
            - For milestone goals, leave targetValue and targetUnit empty.
            - For frequency goals, targetValue must be the session/activity count, targetUnit should usually be "sessions" or another unit matching the tracked activity, periodUnitRaw must be day, week, or month, and periodCount must be 1.
            - For duration and distance goals, periodUnitRaw must be day, week, or month and periodCount must be greater than 0.
            - For count goals, targetUnit should be the thing being counted, such as reps, attempts, rounds, laps, routes, or segments.
            - When it helps, include a soft targetDateISO8601 roughly 4-8 weeks out.
            - checkInCadenceDays can be provided for more open-ended goals that should be revisited.
            - For weight goals, use \(prefersMetricWeight ? "kg by default" : "lbs by default") unless the user context clearly suggests the other unit.
            - Keep titles short and natural, like something a coach would suggest in the app.
            - rationale should explain why the goal fits.
            - notes should be optional and concise.

            User context:
            - Primary fitness goal: \(contextGoal?.isEmpty == false ? contextGoal! : "Not specified")
            - Current plan sessions: \(plannedSessions.isEmpty ? "None" : plannedSessions.joined(separator: " | "))
            - Recent sessions: \(recentSessions.isEmpty ? "None" : recentSessions.joined(separator: " | "))
            - Recent training summary: \(recentTrainingSummary.isEmpty ? "None" : recentTrainingSummary.joined(separator: " | "))
            - Exercise/activity summaries: \(exerciseSummaries.isEmpty ? "None" : exerciseSummaries.joined(separator: " | "))
            - Relevant memory/context: \(memoryContext.isEmpty ? "None" : memoryContext.joined(separator: " | "))
            - Existing workout goals: \(existingGoals.isEmpty ? "None" : existingGoals.joined(separator: " | "))
            - User request: \(trimmedIntent?.isEmpty == false ? trimmedIntent! : "No extra request. Suggest the best fit from context.")
            """

            let schema: [String: Any] = [
                "type": "object",
                "properties": [
                    "suggestions": [
                        "type": "array",
                        "maxItems": 2,
                        "items": AIPromptBuilder.workoutGoalSuggestionSchema
                    ]
                ],
                "required": ["suggestions"]
            ]

            let request = AIBackendPayloadBuilder.canonicalRequest(
                messages: [
                    AIBackendPayloadBuilder.canonicalTextMessage(role: .user, text: prompt)
                ],
                output: AIBackendPayloadBuilder.canonicalOutput(
                    kind: .jsonSchema,
                    schema: schema
                ),
                generation: AIBackendPayloadBuilder.canonicalGeneration(
                    reasoningLevel: .minimal
                )
            )

            logPrompt(prompt)

            let response = try await makeRequest(request: request)
            logResponse(response)

            guard let data = response.data(using: .utf8) else {
                throw AIServiceError.invalidResponse
            }

            let decoded = try JSONDecoder().decode(WorkoutGoalSuggestionResponse.self, from: data)
            return WorkoutGoalSuggestion.validatedUnique(decoded.suggestions)
        }
    }
}

extension WorkoutGoalSuggestion {
    static func validatedUnique(_ suggestions: [WorkoutGoalSuggestion]) -> [WorkoutGoalSuggestion] {
        var seenKeys: Set<String> = []
        return suggestions.compactMap { suggestion in
            guard suggestion.isTrackableAndSpecific else { return nil }
            let key = suggestion.normalizedDeduplicationKey
            guard seenKeys.insert(key).inserted else { return nil }
            return suggestion
        }
    }

    var normalizedDeduplicationKey: String {
        [
            title.goalNormalizedKey,
            goalKind.rawValue,
            linkedWorkoutTypeRaw?.goalNormalizedKey ?? "",
            linkedActivityName?.goalNormalizedKey ?? "",
            linkedActivityTags?.map(\.goalNormalizedKey).sorted().joined(separator: ",") ?? "",
            linkedActivityKindRaw ?? "",
            linkedActivityRoleRaw ?? "",
            tracksGeneratedPlanAdherence == true ? "planAdherence" : ""
        ].joined(separator: "|")
    }

    var isTrackableAndSpecific: Bool {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return false }
        guard successCriteria?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else { return false }
        guard hasTrackableScope else { return false }

        switch goalKind {
        case .milestone:
            return true
        case .frequency:
            guard let targetValue,
                  targetValue > 0,
                  let targetUnit,
                  !targetUnit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  periodUnit != nil,
                  let periodCount,
                  periodCount == 1 else {
                return false
            }
            return true
        case .duration, .distance, .count, .weight:
            guard let targetValue,
                  targetValue > 0,
                  let targetUnit,
                  !targetUnit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return false
            }
            if goalKind == .duration || goalKind == .distance {
                guard periodUnit != nil,
                      let periodCount,
                      periodCount > 0 else {
                    return false
                }
            } else if goalKind == .count {
                guard periodUnit != nil,
                      let periodCount,
                      periodCount == 1 else {
                    return false
                }
            }
            return true
        }
    }

    private var hasTrackableScope: Bool {
        if tracksGeneratedPlanAdherence == true {
            return true
        }

        if linkedWorkoutType != nil {
            return true
        }

        if linkedActivityKindRaw.flatMap(WorkoutPlan.TrainingBlock.BlockKind.init(rawValue:)) != nil {
            return true
        }

        let activityName = linkedActivityName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !activityName.isEmpty {
            return true
        }

        let activityTags = linkedActivityTags?
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty } ?? []
        if !activityTags.isEmpty {
            return true
        }
        return false
    }

    private var periodTrackingGoalKinds: Set<WorkoutGoal.GoalKind> {
        [.frequency, .duration, .distance, .count]
    }
}
