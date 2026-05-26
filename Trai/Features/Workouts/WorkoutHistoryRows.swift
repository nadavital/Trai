//
//  WorkoutHistoryRows.swift
//  Trai
//
//  Row and group components for displaying workout history
//

import SwiftUI

extension LiveWorkout {
    var hasHistorySignalNote: Bool {
        let trimmedWorkoutNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedWorkoutNotes.isEmpty {
            return true
        }

        return (entries ?? []).contains {
            !$0.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }
}

struct WorkoutHistoryInsightBadges: View {
    let matchedGoalCount: Int
    let hasSignalNote: Bool

    var body: some View {
        if matchedGoalCount > 0 || hasSignalNote {
            HStack(spacing: 6) {
                if matchedGoalCount > 0 {
                    Label(
                        matchedGoalCount == 1 ? "Goal" : "\(matchedGoalCount) goals",
                        systemImage: "scope"
                    )
                    .foregroundStyle(Color.accentColor)
                }

                if hasSignalNote {
                    Label("Notes", systemImage: "text.quote")
                        .foregroundStyle(TraiColors.flame)
                }
            }
            .font(.caption2.weight(.medium))
        }
    }
}

// MARK: - Combined Workout Date Group

struct CombinedWorkoutDateGroup: View {
    let date: Date
    let sessions: [WorkoutSession]
    let liveWorkouts: [LiveWorkout]
    let activeGoals: [WorkoutGoal]
    let onSessionTap: (WorkoutSession) -> Void
    let onLiveWorkoutTap: (LiveWorkout) -> Void
    let onDeleteSession: (WorkoutSession) -> Void
    let onDeleteLiveWorkout: (LiveWorkout) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(date, format: .dateTime.weekday(.wide).month().day())
                .font(.caption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            VStack(spacing: 8) {
                // Show in-app workouts first (LiveWorkout)
                ForEach(liveWorkouts) { workout in
                    LiveWorkoutHistoryRow(
                        workout: workout,
                        activeGoals: activeGoals,
                        onTap: { onLiveWorkoutTap(workout) },
                        onDelete: { onDeleteLiveWorkout(workout) }
                    )
                }

                // Then show HealthKit/session workouts
                ForEach(sessions) { workout in
                    WorkoutHistoryRow(
                        workout: workout,
                        onTap: { onSessionTap(workout) },
                        onDelete: { onDeleteSession(workout) }
                    )
                }
            }
        }
    }
}

// MARK: - Live Workout History Row

struct LiveWorkoutHistoryRow: View {
    let workout: LiveWorkout
    let activeGoals: [WorkoutGoal]
    let onTap: () -> Void
    let onDelete: () -> Void

    @State private var showDeleteConfirmation = false

    private var matchedGoalCount: Int {
        activeGoals.filter { $0.matches(workout: workout) }.count
    }

    private var focusSummary: String? {
        let summary = workout.displayFocusSummary.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !summary.isEmpty, summary.caseInsensitiveCompare(workout.name) != .orderedSame else { return nil }
        return summary
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Icon with colored background
                Image(systemName: workout.historyIconName)
                    .font(.body)
                    .foregroundStyle(.accent)
                    .frame(width: 32, height: 32)
                    .background(Color.accentColor.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(workout.name)
                            .font(.subheadline)
                            .lineLimit(1)
                            .foregroundStyle(.primary)

                        // Apple Watch indicator for merged workouts
                        if workout.mergedHealthKitWorkoutID != nil {
                            Image(systemName: "applewatch")
                                .font(.caption2)
                                .foregroundStyle(.red)
                        }
                    }

                    if let focusSummary {
                        Text(focusSummary)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    WorkoutHistoryInsightBadges(
                        matchedGoalCount: matchedGoalCount,
                        hasSignalNote: workout.hasHistorySignalNote
                    )

                    HStack(spacing: 6) {
                        ForEach(Array(workout.historySummarySegments.enumerated()), id: \.offset) { index, segment in
                            if index > 0 {
                                Text("•")
                                    .foregroundStyle(.tertiary)
                            }

                            Text(segment)
                                .foregroundStyle(segment.hasSuffix("kcal") ? .red : .secondary)
                        }
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .confirmationDialog(
            "Delete Workout",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive, action: onDelete)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete \"\(workout.name)\"? This cannot be undone.")
        }
    }
}

// MARK: - Workout Date Group

struct WorkoutDateGroup: View {
    let date: Date
    let workouts: [WorkoutSession]
    let onWorkoutTap: (WorkoutSession) -> Void
    let onDelete: (WorkoutSession) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(date, format: .dateTime.weekday(.wide).month().day())
                .font(.caption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            ForEach(workouts) { workout in
                WorkoutHistoryRow(
                    workout: workout,
                    onTap: { onWorkoutTap(workout) },
                    onDelete: { onDelete(workout) }
                )
            }
        }
    }
}

// MARK: - Workout History Row

struct WorkoutHistoryRow: View {
    let workout: WorkoutSession
    let onTap: () -> Void
    let onDelete: () -> Void

    @State private var showDeleteConfirmation = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Icon with colored background
                Image(systemName: workout.iconName)
                    .font(.body)
                    .foregroundStyle(workout.sourceIsHealthKit ? .red : .accent)
                    .frame(width: 32, height: 32)
                    .background((workout.sourceIsHealthKit ? Color.red : Color.accentColor).opacity(0.15), in: RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    Text(workout.displayName)
                        .font(.subheadline)
                        .lineLimit(1)
                        .foregroundStyle(.primary)

                    WorkoutHistoryInsightBadges(
                        matchedGoalCount: 0,
                        hasSignalNote: workout.hasSignalNote
                    )

                    HStack(spacing: 6) {
                        ForEach(Array(workout.historyDetailSegments.enumerated()), id: \.offset) { index, segment in
                            if index > 0 {
                                Text("•")
                                    .foregroundStyle(.tertiary)
                            }

                            Text(segment)
                                .foregroundStyle(segment.hasSuffix("kcal") ? .red : .secondary)
                        }

                        if workout.sourceIsHealthKit {
                            Image(systemName: "heart.fill")
                                .foregroundStyle(.red)
                        }
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .confirmationDialog(
            "Delete Workout",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive, action: onDelete)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete \"\(workout.displayName)\"? This cannot be undone.")
        }
    }
}

// MARK: - Empty Workout History

struct EmptyWorkoutHistory: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "figure.run.circle")
                .font(.largeTitle)
                .foregroundStyle(.tertiary)

            Text("No workouts yet")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("Start your first workout to see it here")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}
