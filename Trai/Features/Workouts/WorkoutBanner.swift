//
//  WorkoutBanner.swift
//  Trai
//
//  Compact banner shown above tab bar when a workout is in progress
//

import SwiftUI

/// Compact banner view shown above tab bar when workout is active
struct WorkoutBanner: View {
    let workout: LiveWorkout
    let onTap: () -> Void
    let onEnd: () -> Void

    private struct BannerStats {
        let exerciseCount: Int
        let completedSets: Int
    }

    private var stats: BannerStats {
        let entries = workout.entries ?? []
        let completedSets = entries.reduce(0) { total, entry in
            total + (entry.completedSets?.count ?? 0)
        }
        return BannerStats(
            exerciseCount: entries.count,
            completedSets: completedSets
        )
    }

    private func formattedTime(at date: Date) -> String {
        let elapsedTime = date.timeIntervalSince(workout.startedAt)
        let minutes = Int(elapsedTime) / 60
        let seconds = Int(elapsedTime) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var body: some View {
        let stats = stats

        HStack(spacing: 12) {
            // Pulsing indicator
            Circle()
                .fill(.green)
                .frame(width: 10, height: 10)
                .overlay {
                    Circle()
                        .stroke(.green.opacity(0.4), lineWidth: 2)
                        .scaleEffect(1.5)
                }

            // Workout info
            VStack(alignment: .leading, spacing: 2) {
                Text(workout.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    if stats.exerciseCount > 0 {
                        Text("\(stats.exerciseCount) exercises")
                    }
                    Text("•")
                        .foregroundStyle(.tertiary)
                    TimelineView(.periodic(from: workout.startedAt, by: 1.0)) { context in
                        Text(formattedTime(at: context.date))
                            .monospacedDigit()
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            // Sets completed badge
            if stats.completedSets > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                    Text("\(stats.completedSets) sets")
                        .font(.caption)
                }
                .foregroundStyle(.green)
            }

            // End button
            Button(action: onEnd) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .contentShape(Rectangle())
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("activeWorkoutBanner")
        .onTapGesture(perform: onTap)
    }
}

// MARK: - Preview

#Preview {
    VStack {
        Spacer()

        WorkoutBanner(
            workout: {
                let workout = LiveWorkout(
                    name: "Push Day",
                    workoutType: .strength,
                    targetMuscleGroups: [.chest, .shoulders, .triceps]
                )
                let entry = LiveWorkoutEntry(exerciseName: "Bench Press", orderIndex: 0)
                entry.addSet(LiveWorkoutEntry.SetData(reps: 10, weight: CleanWeight(kg: 60, lbs: 132.5), completed: true, isWarmup: false))
                entry.addSet(LiveWorkoutEntry.SetData(reps: 8, weight: CleanWeight(kg: 70, lbs: 155), completed: true, isWarmup: false))
                workout.entries = [entry]
                return workout
            }(),
            onTap: {},
            onEnd: {}
        )
        .background(Color(.systemBackground))
    }
}
