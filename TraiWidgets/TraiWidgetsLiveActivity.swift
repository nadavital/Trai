//
//  TraiWidgetsLiveActivity.swift
//  TraiWidgets
//
//  Live Activity for workout tracking on Lock Screen and Dynamic Island
//

import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

private enum LiveActivityTheme {
    static let traiSymbol = "circle.hexagongrid.circle.fill"
    static let brandAccent = Color(red: 0.85, green: 0.25, blue: 0.20)
    static let accent = brandAccent
    static let controlAccent = brandAccent
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.88)
    static let textTertiary = Color.white.opacity(0.7)
    static let muted = textSecondary
    static let background = Color(red: 0.08, green: 0.08, blue: 0.10)
    static let elevatedSurface = Color.white.opacity(0.10)
    static let softSurface = Color.white.opacity(0.07)
    static let actionForeground = Color.white

    static func statusIcon(isPaused: Bool) -> String {
        isPaused ? "pause.fill" : traiSymbol
    }

    static func statusColor(isPaused: Bool) -> Color {
        isPaused ? muted : accent
    }
}

private extension TraiWorkoutAttributes.ContentState {
    var liveActivityStatusSummary: String {
        if isPaused {
            return "Paused"
        }
        if let currentSetProgressDisplay {
            return currentSetProgressDisplay
        }
        if let totalSetsSummaryDisplay {
            return totalSetsSummaryDisplay
        }
        if let exerciseTotalSummaryDisplay {
            return exerciseTotalSummaryDisplay
        }
        return progressCountDisplay
    }

    var liveActivityShortStatus: String {
        if isPaused {
            return "Paused"
        }
        if let currentSetOrdinalDisplay {
            return currentSetOrdinalDisplay
        }
        if let totalSetsSummaryDisplay {
            return totalSetsSummaryDisplay
        }
        if let exerciseTotalSummaryDisplay {
            return exerciseTotalSummaryDisplay
        }
        return progressCountDisplay
    }

    var liveActivityCompactStatus: String {
        if let currentSetOrdinalDisplay {
            return currentSetOrdinalDisplay.replacingOccurrences(of: "Set ", with: "S")
        }
        if progressTotalValue > 0 || progressCompletedValue > 0 {
            return progressCountDisplay
        }
        return isPaused ? "Pause" : "Live"
    }
}

// MARK: - Live Activity Widget

struct TraiWidgetsLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TraiWorkoutAttributes.self) { context in
            // Lock Screen / Banner view
            LockScreenWorkoutView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    ExpandedLeadingView(context: context)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    ExpandedTrailingView(context: context)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ExpandedBottomView(context: context)
                }
                DynamicIslandExpandedRegion(.center) {
                    HStack(spacing: 7) {
                        Image(systemName: LiveActivityTheme.traiSymbol)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(LiveActivityTheme.accent)
                        Text(context.attributes.workoutName)
                            .font(.headline)
                            .foregroundStyle(LiveActivityTheme.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                    .padding(.horizontal, 18)
                }
            } compactLeading: {
                CompactLeadingView(context: context)
            } compactTrailing: {
                CompactTrailingView(context: context)
            } minimal: {
                MinimalView(context: context)
            }
            .widgetURL(AppRoute.workout(templateID: nil, templateName: nil).url)
        }
        .supplementalActivityFamilies([.small])
    }
}

// MARK: - Lock Screen View

private struct LockScreenWorkoutView: View {
    let context: ActivityViewContext<TraiWorkoutAttributes>
    @Environment(\.activityFamily) private var activityFamily

    private var isSmallFamily: Bool {
        if #available(iOS 18.0, *) {
            return activityFamily == .small
        }
        return false
    }

    private var isMediumFamily: Bool {
        if #available(iOS 18.0, *) {
            return activityFamily == .medium
        }
        return false
    }

    private var isSupplementalFamily: Bool { isSmallFamily }

    var body: some View {
        if isSmallFamily {
            smallFamilyBody
        } else {
            regularBody
        }
    }

    private var shortenedWorkoutName: String {
        let firstWord = context.attributes.workoutName
            .split(separator: " ")
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let firstWord, !firstWord.isEmpty, firstWord.count <= 14 {
            return firstWord
        }

        return "Workout"
    }

    private func compactExerciseName(_ exercise: String) -> String {
        let firstWord = exercise
            .split(separator: " ")
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let firstWord, !firstWord.isEmpty, firstWord.count <= 14 {
            return firstWord
        }

        return "Current"
    }

    private var mediumFamilyBody: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: LiveActivityTheme.statusIcon(isPaused: context.state.isPaused))
                    .font(.caption)
                    .foregroundStyle(LiveActivityTheme.statusColor(isPaused: context.state.isPaused))

                VStack(alignment: .leading, spacing: 3) {
                    ViewThatFits(in: .horizontal) {
                        Text(context.attributes.workoutName)
                            .font(.subheadline)
                            .lineLimit(1)
                            .minimumScaleFactor(0.9)
                        Text(shortenedWorkoutName)
                            .font(.subheadline)
                            .lineLimit(1)
                        Text("Workout")
                            .font(.subheadline)
                            .lineLimit(1)
                    }

                    if let exercise = context.state.currentExercise {
                        ViewThatFits(in: .horizontal) {
                            Text(exercise)
                                .font(.caption2)
                                .foregroundStyle(LiveActivityTheme.textSecondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.9)
                            Text(compactExerciseName(exercise))
                                .font(.caption2)
                                .foregroundStyle(LiveActivityTheme.textSecondary)
                                .lineLimit(1)
                            Text("Current")
                                .font(.caption2)
                                .foregroundStyle(LiveActivityTheme.textSecondary)
                                .lineLimit(1)
                        }
                    }
                }
                .layoutPriority(1)

                Spacer(minLength: 8)

                Text(watchTargetSummary)
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(LiveActivityTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }

            if context.state.hasProgressTarget {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(LiveActivityTheme.textPrimary.opacity(0.2))
                        Capsule()
                            .fill(LiveActivityTheme.controlAccent)
                            .frame(width: geometry.size.width * context.state.progress)
                    }
                }
                .frame(height: 5)
            }
        }
        .foregroundStyle(LiveActivityTheme.textPrimary)
        .padding(12)
        .traiLiveActivityContainerBackground()
        .activityBackgroundTint(.clear)
        .activitySystemActionForegroundColor(LiveActivityTheme.actionForeground)
    }

    private var smallFamilyBody: some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: LiveActivityTheme.statusIcon(isPaused: context.state.isPaused))
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(LiveActivityTheme.statusColor(isPaused: context.state.isPaused))
                .frame(width: 28, height: 52)

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(context.state.currentExercise ?? context.attributes.workoutName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(LiveActivityTheme.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .layoutPriority(1)

                    Text(context.state.liveActivityShortStatus)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(LiveActivityTheme.textSecondary)
                        .lineLimit(1)
                }

                HStack(spacing: 5) {
                    if let currentSet = context.state.currentSetOrdinalDisplay {
                        LiveActivityWatchPill(value: currentSet, isPrimary: true)
                    }

                    if let work = context.state.currentWorkDisplay {
                        LiveActivityWatchPill(value: work)
                    } else if let totalSets = context.state.totalSetsSummaryDisplay {
                        LiveActivityWatchPill(value: totalSets)
                    }
                }

                HStack(spacing: 6) {
                    if context.state.canUseSetShortcut {
                        Button(intent: AddSetIntent()) {
                            Label("Add", systemImage: "plus.circle.fill")
                                .font(.caption2.weight(.semibold))
                                .labelStyle(.titleAndIcon)
                                .lineLimit(1)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.capsule)
                        .controlSize(.small)
                        .tint(LiveActivityTheme.controlAccent)
                    }

                    if context.state.nextExercise != nil {
                        Button(intent: AdvanceExerciseIntent()) {
                            Label("Next", systemImage: "forward.fill")
                                .font(.caption2.weight(.semibold))
                                .labelStyle(.titleAndIcon)
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.capsule)
                        .controlSize(.small)
                        .tint(LiveActivityTheme.muted)
                        .accessibilityLabel(context.state.nextExercise.map { "Next exercise, \($0)" } ?? "Next exercise")
                    }
                }
            }
            .layoutPriority(1)
        }
        .foregroundStyle(LiveActivityTheme.textPrimary)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .traiLiveActivityContainerBackground()
        .activityBackgroundTint(.clear)
        .activitySystemActionForegroundColor(LiveActivityTheme.actionForeground)
    }

    private var watchTargetSummary: String {
        let set = context.state.currentSetOrdinalDisplay
        let work = context.state.currentWorkDisplay

        switch (set, work) {
        case let (set?, work?):
            return "\(set) · \(work)"
        case let (set?, nil):
            return set
        case let (nil, work?):
            return work
        case (nil, nil):
            return context.state.liveActivityStatusSummary
        }
    }

    private var regularBody: some View {
        VStack(alignment: .leading, spacing: 9) {
                HStack(alignment: .top, spacing: isMediumFamily ? 12 : 16) {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: LiveActivityTheme.statusIcon(isPaused: context.state.isPaused))
                            .font(.system(size: isMediumFamily ? 31 : 35, weight: .semibold))
                            .foregroundStyle(LiveActivityTheme.statusColor(isPaused: context.state.isPaused))
                            .frame(width: isMediumFamily ? 36 : 40, height: isMediumFamily ? 42 : 46, alignment: .center)

                    VStack(alignment: .leading, spacing: 3) {
                        if let exercise = context.state.currentExercise {
                            Text(exercise)
                                .font(isMediumFamily ? .subheadline.weight(.semibold) : .headline.weight(.semibold))
                                .foregroundStyle(LiveActivityTheme.textPrimary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                                .layoutPriority(1)
                        } else {
                            Text(context.attributes.workoutName)
                                .font(isMediumFamily ? .subheadline.weight(.semibold) : .headline.weight(.semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }

                        if let nextExercise = context.state.nextExercise {
                            LiveActivityUpNextText(exercise: nextExercise)
                        }
                    }
                }
                .layoutPriority(1)

                    Spacer(minLength: 8)

                    VStack(alignment: .trailing, spacing: 6) {
                        LiveActivityStatusBadge(state: context.state, isCompact: isMediumFamily)
                        LiveActivityPauseControl(state: context.state, isCompact: true)
                    }
                }

                LiveActivityCurrentMetricsRow(state: context.state)

                if !isSupplementalFamily {
                    HStack(spacing: 12) {
                    if context.state.canUseSetShortcut {
                        Button(intent: AddSetIntent()) {
                            Label("Add Set", systemImage: "plus.circle.fill")
                                .font(.caption)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(LiveActivityTheme.controlAccent)
                    }

                    if context.state.nextExercise != nil {
                        LiveActivityUpNextButton(state: context.state)
                    } else {
                        Button(intent: TogglePauseIntent()) {
                            Label(
                                context.state.isPaused ? "Resume" : "Pause",
                                systemImage: context.state.isPaused ? "play.fill" : "pause.fill"
                            )
                            .font(.caption)
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(context.state.isPaused ? LiveActivityTheme.controlAccent : LiveActivityTheme.textSecondary)
                    }
                }
            }
        }
        .foregroundStyle(LiveActivityTheme.textPrimary)
        .padding()
        .traiLiveActivityContainerBackground()
        .activityBackgroundTint(.clear)
        .activitySystemActionForegroundColor(LiveActivityTheme.actionForeground)
    }
}

private extension View {
    @ViewBuilder
    func traiLiveActivityContainerBackground() -> some View {
        if #available(iOS 17.0, *) {
            self.containerBackground(for: .widget) {
                LiveActivityTheme.background
            }
        } else {
            self.background(LiveActivityTheme.background)
        }
    }
}

private struct LiveActivityStatusBadge: View {
    let state: TraiWorkoutAttributes.ContentState
    var isCompact = false

    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(state.liveActivityStatusSummary)
                .font(.system(isCompact ? .subheadline : .headline, design: .rounded, weight: .semibold))
                .foregroundStyle(LiveActivityTheme.textPrimary)
                .shadow(color: .black.opacity(0.28), radius: 2, x: 0, y: 1)
                .lineLimit(1)
                .minimumScaleFactor(0.62)

            if state.isPaused {
                Text("Paused")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(LiveActivityTheme.textSecondary)
                    .lineLimit(1)
            }
        }
        .frame(width: isCompact ? 108 : 124, alignment: .trailing)
        .clipped()
        .layoutPriority(2)
    }
}

private struct LiveActivityPauseControl: View {
    let state: TraiWorkoutAttributes.ContentState
    var isCompact = false

    var body: some View {
        Button(intent: TogglePauseIntent()) {
            Image(systemName: state.isPaused ? "play.fill" : "pause.fill")
                .font(.caption2.weight(.bold))
                .frame(width: isCompact ? 24 : 30, height: isCompact ? 22 : 26)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .controlSize(.small)
        .foregroundStyle(state.isPaused ? LiveActivityTheme.controlAccent : LiveActivityTheme.textSecondary)
        .accessibilityLabel(state.isPaused ? "Resume workout" : "Pause workout")
    }
}

private struct LiveActivityUpNextText: View {
    let exercise: String

    var body: some View {
        Text("Up next: \(exercise)")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(LiveActivityTheme.textSecondary)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .shadow(color: .black.opacity(0.22), radius: 1.5, x: 0, y: 1)
            .accessibilityLabel("Up next, \(exercise)")
    }
}

private struct LiveActivityUpNextButton: View {
    let state: TraiWorkoutAttributes.ContentState

    var body: some View {
        Button(intent: AdvanceExerciseIntent()) {
            Label("Next Exercise", systemImage: "forward.fill")
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
        .tint(LiveActivityTheme.muted)
        .accessibilityLabel(state.nextExercise.map { "Next exercise, \($0)" } ?? "Next exercise")
    }
}

private struct LiveActivityCurrentMetricsRow: View {
    let state: TraiWorkoutAttributes.ContentState

    var body: some View {
        HStack(spacing: 7) {
            if let currentSet = state.currentSetOrdinalDisplay {
                LiveActivityMetricPill(value: currentSet, isPrimary: true)
            }

            if let weight = state.currentWeightDisplay {
                LiveActivityMetricPill(value: weight)
            }

            if let reps = state.currentRepsDisplay {
                LiveActivityMetricPill(value: reps)
            }
        }
        .lineLimit(1)
    }
}

private struct LiveActivityMetricPill: View {
    let value: String
    var isPrimary = true

    var body: some View {
        Text(value)
            .font(.caption.weight(.semibold))
            .foregroundStyle(isPrimary ? LiveActivityTheme.textPrimary : LiveActivityTheme.textSecondary)
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .frame(maxWidth: .infinity)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(LiveActivityTheme.softSurface, in: Capsule())
    }
}

private struct LiveActivityWatchPill: View {
    let value: String
    var isPrimary = false

    var body: some View {
        Text(value)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(isPrimary ? LiveActivityTheme.textPrimary : LiveActivityTheme.textSecondary)
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.68)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(LiveActivityTheme.softSurface, in: Capsule())
    }
}

// MARK: - Dynamic Island Views

private struct ExpandedLeadingView: View {
    let context: ActivityViewContext<TraiWorkoutAttributes>

    var body: some View {
        EmptyView()
    }
}

private struct ExpandedTrailingView: View {
    let context: ActivityViewContext<TraiWorkoutAttributes>

    var body: some View {
        VStack(alignment: .trailing, spacing: 5) {
            Text(context.state.liveActivityShortStatus)
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(LiveActivityTheme.textPrimary)
                .shadow(color: .black.opacity(0.28), radius: 2, x: 0, y: 1)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(width: 64, alignment: .trailing)

            LiveActivityPauseControl(state: context.state, isCompact: true)
        }
        .padding(.trailing, 8)
    }
}

private struct ExpandedBottomView: View {
    let context: ActivityViewContext<TraiWorkoutAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if context.state.hasProgressTarget {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(LiveActivityTheme.textPrimary.opacity(0.2))

                        Capsule()
                            .fill(LiveActivityTheme.controlAccent)
                            .frame(width: geometry.size.width * context.state.progress)
                    }
                }
                .frame(height: 6)
            }

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .top, spacing: 16) {
                    ExpandedCurrentExerciseView(context: context)
                        .frame(width: 158, alignment: .leading)
                        .layoutPriority(2)

                    ExpandedNextExerciseView(state: context.state)
                        .frame(width: 118, alignment: .trailing)
                        .layoutPriority(1)
                }

                ExpandedActionButtons(context: context)
            }
            .padding(.top, 2)
            .padding(.horizontal, 18)
            .padding(.bottom, 1)
        }
    }
}

private struct ExpandedCurrentExerciseView: View {
    let context: ActivityViewContext<TraiWorkoutAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(context.state.currentExercise ?? context.attributes.workoutName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(LiveActivityTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.78)

            Text(targetDisplay)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(LiveActivityTheme.textSecondary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
    }

    private var targetDisplay: String {
        let set = context.state.currentSetOrdinalDisplay
        let work = context.state.currentWorkDisplay

        switch (set, work) {
        case let (set?, work?):
            return "\(set) · \(work)"
        case let (set?, nil):
            return set
        case let (nil, work?):
            return work
        case (nil, nil):
            return context.state.liveActivityStatusSummary
        }
    }
}

private struct ExpandedNextExerciseView: View {
    let state: TraiWorkoutAttributes.ContentState

    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text("Next")
                .font(.caption2.weight(.medium))
                .foregroundStyle(LiveActivityTheme.textTertiary)
                .lineLimit(1)

            Text(state.nextExercise ?? "Finish")
                .font(.caption.weight(.semibold))
                .foregroundStyle(LiveActivityTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .multilineTextAlignment(.trailing)
    }
}

private struct ExpandedMetric: View {
    let value: String
    var isPrimary = false

    var body: some View {
        Text(value)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(isPrimary ? LiveActivityTheme.accent : LiveActivityTheme.textSecondary)
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(LiveActivityTheme.softSurface, in: Capsule())
    }
}

private struct ExpandedActionButtons: View {
    let context: ActivityViewContext<TraiWorkoutAttributes>

    var body: some View {
        HStack(spacing: 12) {
            if context.state.canUseSetShortcut {
                Button(intent: AddSetIntent()) {
                    Label("Add Set", systemImage: "plus.circle.fill")
                        .font(.caption2.weight(.semibold))
                        .labelStyle(.titleAndIcon)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .controlSize(.small)
                .tint(LiveActivityTheme.controlAccent)
            }

            if context.state.nextExercise != nil {
                Button(intent: AdvanceExerciseIntent()) {
                    Label("Next Exercise", systemImage: "forward.fill")
                        .font(.caption2.weight(.semibold))
                        .labelStyle(.titleAndIcon)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
                .controlSize(.small)
                .tint(LiveActivityTheme.muted)
            } else {
                Button(intent: TogglePauseIntent()) {
                    Label(
                        context.state.isPaused ? "Resume" : "Pause",
                        systemImage: context.state.isPaused ? "play.fill" : "pause.fill"
                    )
                    .font(.caption2.weight(.semibold))
                    .labelStyle(.titleAndIcon)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .controlSize(.small)
                .foregroundStyle(context.state.isPaused ? LiveActivityTheme.controlAccent : LiveActivityTheme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct CompactLeadingView: View {
    let context: ActivityViewContext<TraiWorkoutAttributes>

    var body: some View {
        Image(systemName: LiveActivityTheme.statusIcon(isPaused: context.state.isPaused))
            .font(.caption2.weight(.semibold))
            .foregroundStyle(LiveActivityTheme.statusColor(isPaused: context.state.isPaused))
            .frame(width: 16, height: 16)
            .accessibilityLabel(context.state.isPaused ? "Paused" : "Trai workout")
    }
}

private struct CompactTrailingView: View {
    let context: ActivityViewContext<TraiWorkoutAttributes>

    private var statusText: String? {
        if let currentSet = context.state.currentSetOrdinalDisplay {
            return currentSet.replacingOccurrences(of: "Set ", with: "S")
        }
        if let totalSets = context.state.totalSetsSummaryDisplay?.split(separator: " ").first {
            return "\(totalSets)"
        }
        return nil
    }

    var body: some View {
        if let statusText {
            Text(statusText)
                .font(.system(.caption2, design: .rounded, weight: .bold))
                .foregroundStyle(LiveActivityTheme.textPrimary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(width: 18, alignment: .center)
                .accessibilityLabel(statusText)
        } else {
            Text(context.state.liveActivityCompactStatus)
                .font(.system(.caption2, design: .rounded, weight: .bold))
                .foregroundStyle(LiveActivityTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(width: 24, alignment: .center)
        }
    }
}

private struct MinimalView: View {
    let context: ActivityViewContext<TraiWorkoutAttributes>

    var body: some View {
        Image(systemName: context.state.isPaused ? "pause.fill" : LiveActivityTheme.traiSymbol)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(LiveActivityTheme.statusColor(isPaused: context.state.isPaused))
            .accessibilityLabel(context.state.isPaused ? "Paused workout" : "Trai workout")
    }
}

// MARK: - Previews

extension TraiWorkoutAttributes {
    static var preview: TraiWorkoutAttributes {
        TraiWorkoutAttributes(
            workoutName: "Push Day",
            targetMuscles: ["Chest", "Shoulders", "Triceps"],
            startedAt: Date()
        )
    }
}

extension TraiWorkoutAttributes.ContentState {
    static var active: TraiWorkoutAttributes.ContentState {
        TraiWorkoutAttributes.ContentState(
            elapsedSeconds: 1847,
            currentExercise: "Bench Press",
            currentEquipment: "Smith Machine",
            completedSets: 8,
            totalSets: 15,
            heartRate: 142,
            isPaused: false,
            currentWeightKg: 80,
            currentWeightLbs: 176,
            currentReps: 8,
            totalVolumeKg: 2450,
            totalVolumeLbs: 5401,
            nextExercise: "Incline Dumbbell Press"
        )
    }

    static var paused: TraiWorkoutAttributes.ContentState {
        TraiWorkoutAttributes.ContentState(
            elapsedSeconds: 2100,
            currentExercise: "Overhead Press",
            currentEquipment: nil,
            completedSets: 10,
            totalSets: 15,
            heartRate: 98,
            isPaused: true,
            currentWeightKg: 50,
            currentWeightLbs: 110,
            currentReps: 10,
            totalVolumeKg: 3200,
            totalVolumeLbs: 7055,
            nextExercise: "Lateral Raises"
        )
    }

    static var mixedActivity: TraiWorkoutAttributes.ContentState {
        TraiWorkoutAttributes.ContentState(
            elapsedSeconds: 1240,
            currentExercise: "Climbing Technique Practice",
            currentEquipment: nil,
            currentDetail: "18:00 • 6 attempts",
            completedSets: 0,
            totalSets: 0,
            heartRate: 118,
            isPaused: false,
            totalVolumeKg: nil,
            totalVolumeLbs: nil,
            nextExercise: "Mobility Flow",
            progressCompleted: 1,
            progressTotal: 3,
            progressLabel: "exercises",
            supportsSetShortcut: false
        )
    }
}

#if DEBUG
struct TraiWidgetsLiveActivity_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            if #available(iOSApplicationExtension 16.2, *) {
                TraiWorkoutAttributes.preview
                    .previewContext(TraiWorkoutAttributes.ContentState.active, viewKind: .content)
                    .previewDisplayName("Notification")

                TraiWorkoutAttributes.preview
                    .previewContext(TraiWorkoutAttributes.ContentState.paused, viewKind: .content)
                    .previewDisplayName("Paused")

                TraiWorkoutAttributes.preview
                    .previewContext(TraiWorkoutAttributes.ContentState.mixedActivity, viewKind: .content)
                    .previewDisplayName("Mixed Activity")
            }
        }
    }
}
#endif
