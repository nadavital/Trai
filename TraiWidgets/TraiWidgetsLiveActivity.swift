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
    static let textTertiary = Color.white.opacity(0.70)
    static let muted = textSecondary
    static let background = Color(red: 0.09, green: 0.09, blue: 0.12)
    static let supplementalBackground = Color(red: 0.09, green: 0.09, blue: 0.12).opacity(0.72)
    static let actionForeground = Color.white

    static func statusIcon(isPaused: Bool) -> String {
        isPaused ? "pause.fill" : traiSymbol
    }

    static func statusColor(isPaused: Bool) -> Color {
        isPaused ? muted : accent
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
                    Text(context.attributes.workoutName)
                        .font(.headline)
                        .lineLimit(1)
                }
            } compactLeading: {
                CompactLeadingView(context: context)
            } compactTrailing: {
                CompactTrailingView(context: context)
            } minimal: {
                Image(systemName: LiveActivityTheme.statusIcon(isPaused: context.state.isPaused))
                    .font(.caption)
                    .foregroundStyle(LiveActivityTheme.statusColor(isPaused: context.state.isPaused))
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

                Text(context.state.progressDisplay)
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(LiveActivityTheme.accent)
                    .lineLimit(1)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(LiveActivityTheme.textPrimary.opacity(0.2))
                    Capsule()
                        .fill(LiveActivityTheme.accent)
                        .frame(width: geometry.size.width * context.state.progress)
                }
            }
            .frame(height: 5)
        }
        .foregroundStyle(LiveActivityTheme.textPrimary)
        .padding(12)
        .traiLiveActivityContainerBackground()
        .activityBackgroundTint(.clear)
        .activitySystemActionForegroundColor(LiveActivityTheme.actionForeground)
    }

    private var smallFamilyBody: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: LiveActivityTheme.statusIcon(isPaused: context.state.isPaused))
                    .font(.caption)
                    .foregroundStyle(LiveActivityTheme.statusColor(isPaused: context.state.isPaused))

                ViewThatFits(in: .horizontal) {
                    Text(context.attributes.workoutName)
                        .font(.caption)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .truncationMode(.tail)
                    Text(shortenedWorkoutName)
                        .font(.caption)
                        .lineLimit(1)
                    Image(systemName: LiveActivityTheme.traiSymbol)
                        .font(.caption)
                }
            }

            if let exercise = context.state.currentExercise {
                ViewThatFits(in: .horizontal) {
                    Text(exercise)
                        .font(.caption2)
                        .foregroundStyle(LiveActivityTheme.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
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

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(LiveActivityTheme.textPrimary.opacity(0.2))
                    Capsule()
                        .fill(LiveActivityTheme.accent)
                        .frame(width: geometry.size.width * context.state.progress)
                }
            }
            .frame(height: 5)

            Text(context.state.progressDisplay)
                .font(.caption2)
                .monospacedDigit()
                .foregroundStyle(LiveActivityTheme.textSecondary)
                .lineLimit(1)
        }
        .foregroundStyle(LiveActivityTheme.textPrimary)
        .padding(12)
        .traiLiveActivityContainerBackground(isSupplemental: true)
        .activityBackgroundTint(LiveActivityTheme.supplementalBackground)
        .activitySystemActionForegroundColor(LiveActivityTheme.actionForeground)
    }

    private var regularBody: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: isMediumFamily ? 12 : 16) {
                Image(systemName: LiveActivityTheme.statusIcon(isPaused: context.state.isPaused))
                    .font(.system(size: isMediumFamily ? 30 : 34, weight: .semibold))
                    .foregroundStyle(LiveActivityTheme.statusColor(isPaused: context.state.isPaused))
                    .frame(width: isMediumFamily ? 34 : 40, height: isMediumFamily ? 40 : 46)

                VStack(alignment: .leading, spacing: 4) {
                    Text(context.state.currentExercise ?? context.attributes.workoutName)
                        .font(isMediumFamily ? .subheadline.weight(.semibold) : .headline.weight(.semibold))
                        .foregroundStyle(LiveActivityTheme.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    if let nextExercise = context.state.nextExercise {
                        LiveActivityUpNextText(exercise: nextExercise)
                    } else {
                        Text(context.attributes.workoutName)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(LiveActivityTheme.textSecondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
                .layoutPriority(1)

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 6) {
                    LiveActivityTargetSummary(state: context.state)
                    LiveActivityPauseControl(state: context.state, isCompact: true)
                }
            }

            if !isSupplementalFamily {
                HStack(spacing: 10) {
                    if context.state.canUseSetShortcut {
                        Button(intent: AddSetIntent()) {
                            Label("Add Set", systemImage: "plus.circle.fill")
                                .font(.caption)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.capsule)
                        .tint(LiveActivityTheme.controlAccent)
                    }

                    if context.state.canUseAdvanceShortcut {
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
                    }

                    Button(intent: ClearLiveActivityIntent()) {
                        Label("Clear", systemImage: "xmark")
                            .font(.caption)
                            .labelStyle(.iconOnly)
                            .frame(width: 34)
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                    .tint(LiveActivityTheme.muted)
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
    func traiLiveActivityContainerBackground(isSupplemental: Bool = false) -> some View {
        if #available(iOS 17.0, *) {
            self.containerBackground(for: .widget) {
                isSupplemental ? LiveActivityTheme.supplementalBackground : Color.clear
            }
        } else {
            self.background(isSupplemental ? LiveActivityTheme.supplementalBackground : Color.clear)
        }
    }
}

private struct LiveActivityTargetSummary: View {
    let state: TraiWorkoutAttributes.ContentState

    var body: some View {
        Text(summary)
            .font(.system(.caption, design: .rounded, weight: .semibold))
            .foregroundStyle(LiveActivityTheme.textPrimary)
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(.black.opacity(0.18), in: Capsule())
    }

    private var summary: String {
        let work = state.currentWorkDisplay

        if let work {
            return work
        }
        return state.progressCountDisplay
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
            .accessibilityLabel("Up next, \(exercise)")
    }
}

// MARK: - Dynamic Island Views

private struct ExpandedLeadingView: View {
    let context: ActivityViewContext<TraiWorkoutAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Image(systemName: LiveActivityTheme.statusIcon(isPaused: context.state.isPaused))
                .font(.title2)
                .foregroundStyle(LiveActivityTheme.statusColor(isPaused: context.state.isPaused))

            Text(context.attributes.workoutName)
                .font(.caption2)
                .foregroundStyle(LiveActivityTheme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }
}

private struct ExpandedTrailingView: View {
    let context: ActivityViewContext<TraiWorkoutAttributes>

    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            if let nextExercise = context.state.nextExercise {
                Text("Next")
                    .font(.caption2)
                    .foregroundStyle(LiveActivityTheme.textTertiary)
                Text(nextExercise)
                    .font(.caption)
                    .foregroundStyle(LiveActivityTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            } else {
                Text(context.state.isPaused ? "Paused" : "Live")
                    .font(.caption)
                    .foregroundStyle(LiveActivityTheme.textSecondary)
            }
        }
    }
}

private struct ExpandedBottomView: View {
    let context: ActivityViewContext<TraiWorkoutAttributes>

    var body: some View {
        VStack(spacing: 8) {
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(LiveActivityTheme.textPrimary.opacity(0.2))

                    Capsule()
                        .fill(LiveActivityTheme.accent)
                        .frame(width: geometry.size.width * context.state.progress)
                }
            }
            .frame(height: 6)

            HStack(alignment: .top, spacing: 10) {
                // Current exercise with set info
                if let exercise = context.state.currentExercise {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Text("Now:")
                                .font(.caption2)
                                .foregroundStyle(LiveActivityTheme.textSecondary)
                            Text(exercise)
                                .font(.caption)
                                .lineLimit(1)
                        }

                        if let workDisplay = context.state.currentWorkDisplay {
                            Text(workDisplay)
                                .font(.caption2)
                                .foregroundStyle(LiveActivityTheme.accent)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    if context.state.canUseSetShortcut, let volume = context.state.volumeDisplay {
                        Text("Volume")
                            .font(.caption2)
                            .foregroundStyle(LiveActivityTheme.textSecondary)
                        Text(volume)
                            .font(.caption)
                            .foregroundStyle(LiveActivityTheme.accent)
                    } else {
                        Text(context.state.progressDisplay)
                            .font(.caption)
                            .foregroundStyle(LiveActivityTheme.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }

            HStack(spacing: 8) {
                if context.state.canUseSetShortcut {
                    Button(intent: AddSetIntent()) {
                        Label("Add", systemImage: "plus.circle.fill")
                            .font(.caption2)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(LiveActivityTheme.accent)
                }

                if context.state.canUseAdvanceShortcut {
                    Button(intent: AdvanceExerciseIntent()) {
                        Label("Next", systemImage: "forward.fill")
                            .font(.caption2)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(LiveActivityTheme.accent)
                }

                Button(intent: TogglePauseIntent()) {
                    Label(
                        context.state.isPaused ? "Resume" : "Pause",
                        systemImage: context.state.isPaused ? "play.fill" : "pause.fill"
                    )
                    .font(.caption2)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(context.state.isPaused ? LiveActivityTheme.accent : LiveActivityTheme.muted)
            }
        }
    }
}

private struct CompactLeadingView: View {
    let context: ActivityViewContext<TraiWorkoutAttributes>

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: LiveActivityTheme.statusIcon(isPaused: context.state.isPaused))
                .font(.caption)
                .foregroundStyle(LiveActivityTheme.statusColor(isPaused: context.state.isPaused))

            // Show current workout item instead of timer
            if let exercise = context.state.currentExercise {
                Text(exercise)
                    .font(.caption)
                    .lineLimit(1)
            }
        }
    }
}

private struct CompactTrailingView: View {
    let context: ActivityViewContext<TraiWorkoutAttributes>

    var body: some View {
        Text(context.state.progressDisplay)
            .font(.system(.caption, design: .rounded, weight: .semibold))
            .foregroundStyle(LiveActivityTheme.accent)
            .lineLimit(1)
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
            progressLabel: "items",
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
