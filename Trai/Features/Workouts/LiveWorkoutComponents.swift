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
    let totalVolume: Double
    let onTogglePause: () -> Void
    var showsWatchSyncButton: Bool = false
    var isWatchSyncing: Bool = false
    var onRetryWatchSync: (() -> Void)?
    var watchConnectionHint: String?

    // Optional Apple Watch data - only shown when available
    var heartRate: Double?
    var heartRateZone: HealthKitService.HeartRateZoneSummary?
    var calories: Double?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 16) {
            // Timer (centered)
            TimelineView(.periodic(from: .now, by: 1.0)) { context in
                let elapsed = calculateElapsed(at: context.date)
                Text(formatTime(elapsed))
                    .font(.traiHero(48).weight(.light).monospaced())
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .contentTransition(reduceMotion ? .identity : .numericText())
            }

            ViewThatFits(in: .horizontal) {
                timerActions(axis: .horizontal)
                timerActions(axis: .vertical)
            }

            if showsWatchSyncButton,
               let watchConnectionHint,
               !watchConnectionHint.isEmpty {
                Label(watchConnectionHint, systemImage: "applewatch")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Stats row - volume and optional watch data
            let hasWatchData = heartRate != nil || (calories ?? 0) > 0
            if totalVolume > 0 || hasWatchData {
                ViewThatFits(in: .horizontal) {
                    timerStats(axis: .horizontal)
                    timerStats(axis: .vertical)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(.rect(cornerRadius: 16))
    }

    @ViewBuilder
    private func timerActions(axis: Axis) -> some View {
        let layout = axis == .horizontal
            ? AnyLayout(HStackLayout(spacing: 10))
            : AnyLayout(VStackLayout(spacing: 10))

        layout {
                // Pill-shaped pause/resume button
                Button(action: onTogglePause) {
                    HStack(spacing: 6) {
                        Image(systemName: isTimerRunning ? "pause.fill" : "play.fill")
                        Text(isTimerRunning ? "Pause" : "Resume")
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .frame(minWidth: 112, maxWidth: axis == .vertical ? .infinity : nil, minHeight: 44)
                    .background(Color.accentColor.opacity(0.15))
                    .foregroundStyle(Color.accentColor)
                    .clipShape(.capsule)
                }
                .buttonStyle(.plain)

                if showsWatchSyncButton, let onRetryWatchSync {
                    Button(action: onRetryWatchSync) {
                        HStack(spacing: 6) {
                            if isWatchSyncing {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "applewatch.side.right")
                            }
                            Text(isWatchSyncing ? "Syncing" : "Sync")
                        }
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .frame(minWidth: 112, maxWidth: axis == .vertical ? .infinity : nil, minHeight: 44)
                        .background(Color.accentColor.opacity(0.15))
                        .foregroundStyle(Color.accentColor)
                        .clipShape(.capsule)
                    }
                    .buttonStyle(.plain)
                    .disabled(isWatchSyncing)
                }
            }
    }

    @ViewBuilder
    private func timerStats(axis: Axis) -> some View {
        let layout = axis == .horizontal
            ? AnyLayout(HStackLayout(spacing: 24))
            : AnyLayout(VStackLayout(spacing: 12))

        layout {
                    if totalVolume > 0 {
                        TimerStat(
                            value: formatVolume(totalVolume),
                            label: "Volume"
                        )
                    }

                    if let hr = heartRate {
                        TimerStat(
                            value: "\(Int(hr))",
                            label: heartRateZone.map { "BPM • Zone \($0.index)" } ?? "BPM",
                            icon: "heart.fill",
                            iconColor: .red
                        )
                    }

                    if let cal = calories, cal > 0 {
                        TimerStat(
                            value: "\(Int(cal))",
                            label: "kcal",
                            icon: "flame.fill",
                            iconColor: .orange
                        )
                    }
                }
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

    private func formatVolume(_ volume: Double) -> String {
        if volume >= 1000 {
            return String(format: "%.1fk", volume / 1000)
        }
        return "\(Int(volume))"
    }
}

// MARK: - Timer Stat

struct TimerStat: View {
    let value: String
    let label: String
    var icon: String?
    var iconColor: Color?

    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 4) {
                if let icon {
                    Image(systemName: icon)
                        .font(.caption)
                        .foregroundStyle(iconColor ?? .primary)
                }
                Text(value)
                    .font(.title3)
                    .bold()
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Add Exercise Button

struct AddExerciseButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                Text("Add Exercise")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.traiSecondary())
    }
}

// MARK: - Workout Bottom Bar

struct WorkoutBottomBar: View {
    let onAddExercise: () -> Void
    let onAskTrai: () -> Void
    var addLabel: String = "Add Exercise"
    var addSystemImage: String = "plus.circle.fill"

    @ViewBuilder
    var body: some View {
        if #available(iOS 26.0, *) {
            glassBody
        } else {
            fallbackBody
        }
    }

    @available(iOS 26.0, *)
    private var glassBody: some View {
        GlassEffectContainer(spacing: 14) {
            HStack(spacing: 12) {
                tintedGlassButton(
                    title: "Ask Trai",
                    systemImage: "circle.hexagongrid.circle",
                    tint: TraiColors.brandAccent,
                    foreground: TraiColors.brandAccent,
                    tintOpacity: 0.24,
                    strokeOpacity: 0.32,
                    action: onAskTrai
                )

                tintedGlassButton(
                    title: addLabel,
                    systemImage: addSystemImage,
                    tint: .primary,
                    foreground: .primary,
                    tintOpacity: 0.10,
                    strokeOpacity: 0.14,
                    action: onAddExercise
                )
                .accessibilityIdentifier("liveWorkoutAddExerciseButton")
            }
        }
        .accessibilityIdentifier("liveWorkoutBottomBar")
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private var fallbackBody: some View {
        HStack(spacing: 16) {
            Button(action: onAskTrai) {
                HStack {
                    TraiLensSymbolIcon(size: 16, variant: .nodes, color: TraiColors.brandAccent)
                    Text("Ask Trai")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.traiSecondary(color: TraiColors.brandAccent))

            Button(action: onAddExercise) {
                HStack {
                    Image(systemName: addSystemImage)
                    Text(addLabel)
                }
                .frame(maxWidth: .infinity)
            }
            .accessibilityIdentifier("liveWorkoutAddExerciseButton")
            .buttonStyle(.traiTertiary(color: .accentColor))
        }
        .accessibilityIdentifier("liveWorkoutBottomBar")
        .padding()
        .background(.ultraThinMaterial)
    }

    @available(iOS 26.0, *)
    private func tintedGlassButton(
        title: String,
        systemImage: String,
        tint: Color,
        foreground: Color,
        tintOpacity: Double,
        strokeOpacity: Double,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .labelStyle(.titleAndIcon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(foreground)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .glassEffect(
                    .regular.tint(tint.opacity(tintOpacity)).interactive(),
                    in: .capsule
                )
                .overlay {
                    Capsule()
                        .strokeBorder(tint.opacity(strokeOpacity), lineWidth: 1)
                }
        }
        .controlSize(.regular)
        .buttonStyle(.plain)
    }
}
