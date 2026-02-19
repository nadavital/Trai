//
//  WorkoutHistorySection.swift
//  Trai
//
//  Section component showing recent workouts with "See All" functionality
//

import SwiftUI

// MARK: - Workout History Section

struct WorkoutHistorySection: View {
    let workoutsByDate: [(date: Date, workouts: [WorkoutSession])]
    let liveWorkoutsByDate: [(date: Date, workouts: [LiveWorkout])]
    let onWorkoutTap: (WorkoutSession) -> Void
    let onLiveWorkoutTap: (LiveWorkout) -> Void
    let onDelete: (WorkoutSession) -> Void
    let onDeleteLiveWorkout: (LiveWorkout) -> Void

    @State private var showAllWorkouts = false

    /// Recent merged dates used for compact rendering.
    private var previewDates: [Date] {
        mergedDates(limit: 2)
    }

    /// Total workout count for "See All" button
    private var totalWorkoutCount: Int {
        let sessionCount = workoutsByDate.reduce(0) { $0 + $1.workouts.count }
        let liveCount = liveWorkoutsByDate.reduce(0) { $0 + $1.workouts.count }
        return sessionCount + liveCount
    }

    private func sessions(for date: Date) -> [WorkoutSession] {
        workoutsByDate.first { $0.date == date }?.workouts ?? []
    }

    private func liveWorkouts(for date: Date) -> [LiveWorkout] {
        liveWorkoutsByDate.first { $0.date == date }?.workouts ?? []
    }

    private func mergedDates(limit: Int) -> [Date] {
        guard limit > 0 else { return [] }

        var dates: [Date] = []
        var workoutIndex = 0
        var liveIndex = 0

        while dates.count < limit
                && (workoutIndex < workoutsByDate.count || liveIndex < liveWorkoutsByDate.count) {
            let nextWorkoutDate = workoutIndex < workoutsByDate.count
                ? workoutsByDate[workoutIndex].date
                : .distantPast
            let nextLiveDate = liveIndex < liveWorkoutsByDate.count
                ? liveWorkoutsByDate[liveIndex].date
                : .distantPast

            let candidate: Date
            if nextWorkoutDate >= nextLiveDate {
                candidate = nextWorkoutDate
                workoutIndex += 1
                if nextLiveDate == candidate {
                    liveIndex += 1
                }
            } else {
                candidate = nextLiveDate
                liveIndex += 1
            }

            if dates.last != candidate {
                dates.append(candidate)
            }
        }

        return dates
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with See All button
            HStack {
                Label("Recent Workouts", systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                    .font(.headline)
                Spacer()
                if totalWorkoutCount > 3 {
                    Button {
                        showAllWorkouts = true
                    } label: {
                        Text("See All")
                            .font(.subheadline)
                            .foregroundStyle(.accent)
                    }
                }
            }

            if previewDates.isEmpty {
                EmptyWorkoutHistory()
            } else {
                // Show only most recent 2 dates (compact view)
                VStack(spacing: 8) {
                    ForEach(previewDates, id: \.self) { date in
                        CompactWorkoutDateGroup(
                            date: date,
                            sessions: sessions(for: date),
                            liveWorkouts: liveWorkouts(for: date),
                            onSessionTap: onWorkoutTap,
                            onLiveWorkoutTap: onLiveWorkoutTap
                        )
                    }
                }
            }
        }
        .traiCard()
        .sheet(isPresented: $showAllWorkouts) {
            AllWorkoutsSheet(
                workoutsByDate: workoutsByDate,
                liveWorkoutsByDate: liveWorkoutsByDate,
                onWorkoutTap: onWorkoutTap,
                onLiveWorkoutTap: onLiveWorkoutTap,
                onDelete: onDelete,
                onDeleteLiveWorkout: onDeleteLiveWorkout
            )
        }
    }
}

// MARK: - Compact Workout Date Group (for preview)

private struct CompactWorkoutDateGroup: View {
    let date: Date
    let sessions: [WorkoutSession]
    let liveWorkouts: [LiveWorkout]
    let onSessionTap: (WorkoutSession) -> Void
    let onLiveWorkoutTap: (LiveWorkout) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(date, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day())
                .font(.caption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            VStack(spacing: 8) {
                // Show first 2 workouts from this date
                ForEach(liveWorkouts.prefix(2)) { workout in
                    CompactLiveWorkoutRow(workout: workout, onTap: { onLiveWorkoutTap(workout) })
                }

                ForEach(sessions.prefix(max(0, 2 - liveWorkouts.count))) { workout in
                    CompactWorkoutSessionRow(workout: workout, onTap: { onSessionTap(workout) })
                }
            }
        }
    }
}

// MARK: - Compact Live Workout Row

private struct CompactLiveWorkoutRow: View {
    let workout: LiveWorkout
    let onTap: () -> Void

    private var exerciseCount: Int { workout.entries?.count ?? 0 }
    private var totalSets: Int { workout.entries?.reduce(0) { $0 + $1.sets.count } ?? 0 }
    private var durationMinutes: Int { Int(workout.duration / 60) }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Icon with colored background
                Image(systemName: workout.type == .cardio ? "figure.run" : "dumbbell.fill")
                    .font(.body)
                    .foregroundStyle(.accent)
                    .frame(width: 32, height: 32)
                    .background(Color.accentColor.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    Text(workout.name)
                        .font(.subheadline)
                        .lineLimit(1)
                        .foregroundStyle(.primary)

                    HStack(spacing: 6) {
                        if exerciseCount > 0 {
                            Text("\(exerciseCount) exercises")
                        }
                        if totalSets > 0 {
                            Text("•")
                                .foregroundStyle(.tertiary)
                            Text("\(totalSets) sets")
                        }
                        if durationMinutes > 0 {
                            Text("•")
                                .foregroundStyle(.tertiary)
                            Text("\(durationMinutes) min")
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
            .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Compact Workout Session Row

private struct CompactWorkoutSessionRow: View {
    let workout: WorkoutSession
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Icon with colored background
                Image(systemName: workout.isStrengthTraining ? "dumbbell.fill" : "figure.run")
                    .font(.body)
                    .foregroundStyle(workout.sourceIsHealthKit ? .red : .accent)
                    .frame(width: 32, height: 32)
                    .background((workout.sourceIsHealthKit ? Color.red : Color.accentColor).opacity(0.15), in: RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    Text(workout.displayName)
                        .font(.subheadline)
                        .lineLimit(1)
                        .foregroundStyle(.primary)

                    HStack(spacing: 6) {
                        if workout.isStrengthTraining {
                            Text("\(workout.sets)×\(workout.reps)")
                        } else if let duration = workout.formattedDuration {
                            Text(duration)
                        }

                        if let calories = workout.caloriesBurned {
                            Text("•")
                                .foregroundStyle(.tertiary)
                            Text("\(calories) kcal")
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
            .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}
