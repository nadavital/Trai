//
//  LiveWorkoutComponents.swift
//  Trai
//
//  Core UI components for live workout tracking
//

import SwiftUI

// MARK: - Workout Timer Header

struct WorkoutTimerHeader: View {
    let workoutStartedAt: Date
    let isTimerRunning: Bool
    let totalPauseDuration: TimeInterval
    let pausedElapsedTime: TimeInterval?
    let onTogglePause: () -> Void
    var showsWatchSyncButton: Bool = false
    var isWatchSyncing: Bool = false
    var onRetryWatchSync: (() -> Void)?
    var watchConnectionHint: String?

    // Optional Apple Watch data - only shown when available
    var heartRate: Double?
    var calories: Double?
    @State private var showsWatchDetails = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        sessionState
                        elapsedTime
                    }
                    Spacer(minLength: 0)
                    sessionControls
                }
                VStack(alignment: .leading, spacing: 12) {
                    sessionState
                    elapsedTime
                    sessionControls
                }
            }
            if showsWatchDetails {
                VStack(alignment: .leading, spacing: 10) {
                    Text(watchConnectionHint ?? "Connect your Apple Watch to see live heart rate and energy.")
                        .font(.subheadline).foregroundStyle(.secondary)
                    if let onRetryWatchSync {
                        Button(isWatchSyncing ? "Connecting…" : "Connect Apple Watch", action: onRetryWatchSync)
                            .buttonStyle(.traiTertiary(size: .compact))
                            .disabled(isWatchSyncing)
                    }
                }.padding(.vertical, 4)
            }
            if heartRate != nil || (calories ?? 0) > 0 {
                HStack(spacing: 20) {
                    if let heartRate {
                        Label("\(Int(heartRate)) BPM", systemImage: "heart.fill")
                            .foregroundStyle(.pink)
                    }
                    if let calories, calories > 0 {
                        Label("\(Int(calories)) kcal", systemImage: "flame.fill")
                            .foregroundStyle(.orange)
                    }
                }.font(.subheadline.weight(.medium)).monospacedDigit()
            }
        }
        .padding(.horizontal, 8).padding(.bottom, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var sessionState: some View {
        Label(isTimerRunning ? "In session" : "Paused", systemImage: isTimerRunning ? "waveform.path" : "pause.circle.fill")
            .font(.subheadline.weight(.medium)).foregroundStyle(.indigo)
    }

    private var sessionControls: some View {
        HStack(spacing: 8) {
            timerControls
            if showsWatchSyncButton {
                Button { showsWatchDetails.toggle() } label: {
                    Image(systemName: "applewatch").frame(width: 24, height: 28)
                }
                .buttonStyle(.glass).buttonBorderShape(.circle).tint(.primary)
                .accessibilityLabel("Apple Watch connection")
            }
        }
    }

    private var elapsedTime: some View {
        TimelineView(.animation(minimumInterval: 1, paused: !isTimerRunning || scenePhase != .active)) { context in
            Text(formatTime(calculateElapsed(at: context.date)))
                .font(.system(.largeTitle, design: .rounded, weight: .medium))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .contentTransition(.numericText())
                .accessibilityLabel("Elapsed time")
                .accessibilityValue(formatTime(calculateElapsed(at: context.date)))
        }
    }

    private var timerControls: some View {
        Button(action: onTogglePause) {
            Label(isTimerRunning ? "Pause" : "Resume", systemImage: isTimerRunning ? "pause.fill" : "play.fill")
        }
        .buttonStyle(.traiTertiary(color: .primary, height: 44))
    }

    private func calculateElapsed(at date: Date) -> TimeInterval {
        guard isTimerRunning else {
            return max(0, pausedElapsedTime ?? (date.timeIntervalSince(workoutStartedAt) - totalPauseDuration))
        }
        return max(0, date.timeIntervalSince(workoutStartedAt) - totalPauseDuration)
    }

    private func formatTime(_ elapsed: TimeInterval) -> String {
        let totalSeconds = max(0, Int(elapsed))
        let days = totalSeconds / 86_400
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if days > 0 {
            let remainingHours = (totalSeconds % 86_400) / 3600
            return String(format: "%dd %02d:%02d", days, remainingHours, minutes)
        }
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }

}

// MARK: - Workout Bottom Bar

struct WorkoutBottomBar: View {
    let onAddExercise: () -> Void
    let onAskTrai: () -> Void
    var addLabel: String = "Add exercise"
    var addSystemImage: String = "plus"

    var body: some View {
        GlassEffectContainer(spacing: 12) {
            HStack(spacing: 12) {
                Button(action: onAskTrai) {
                    TraiLensSymbolIcon(size: 24, variant: .nodes, color: TraiColors.brandAccent)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.glass).buttonBorderShape(.circle)
                .accessibilityLabel("Ask Trai")

                Button(action: onAddExercise) {
                    Label(addLabel, systemImage: addSystemImage)
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.glass).buttonBorderShape(.capsule)
                .tint(.primary)
                .accessibilityIdentifier("liveWorkoutAddExerciseButton")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("liveWorkoutBottomBar")
        .padding(.horizontal, 20).padding(.vertical, 12)
    }
}
