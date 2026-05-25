//
//  ChatWorkoutCards.swift
//  Trai
//
//  Workout suggestion and logging cards for chat
//

import SwiftUI

// MARK: - Suggested Workout Card

struct SuggestedWorkoutCard: View {
    let workout: SuggestedWorkoutEntry
    let onAccept: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: workout.iconName)
                    .foregroundStyle(.accent)
                Text("Start Workout?")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
            }

            // Workout details
            VStack(alignment: .leading, spacing: 8) {
                Text(workout.name)
                    .font(.headline)

                HStack(spacing: 12) {
                    Label(workout.exercisesSummary, systemImage: "list.bullet")
                    Label("\(workout.durationMinutes) min", systemImage: "clock")
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                if let activityFocuses = workout.activityFocuses, !activityFocuses.isEmpty {
                    Text(activityFocuses.prefix(3).joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if !workout.targetMuscleGroups.isEmpty {
                    Text(workout.muscleGroupsSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let firstExerciseSummary {
                    Text(firstExerciseSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if !workout.rationale.isEmpty {
                    Text(workout.rationale)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 2)
                }
            }
            .padding()
            .background(Color(.tertiarySystemBackground))
            .clipShape(.rect(cornerRadius: 12))

            // Action buttons
            HStack(spacing: 12) {
                Button("Dismiss", systemImage: "xmark") {
                    onDismiss()
                }
                .buttonStyle(.traiTertiary())
                .controlSize(.small)

                Spacer()

                Button("Start Workout", systemImage: "play.fill") {
                    onAccept()
                }
                .buttonStyle(.traiPrimary())
                .controlSize(.small)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(.rect(cornerRadius: 16))
    }

    private var firstExerciseSummary: String? {
        guard let exercise = workout.exercises.first else { return nil }
        let details = exercise.startSummarySegments
        guard !details.isEmpty else { return exercise.name }
        return ([exercise.name] + Array(details.prefix(3))).joined(separator: " • ")
    }
}

// MARK: - Workout Started Badge

struct WorkoutStartedBadge: View {
    let workoutName: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text("Started: \(workoutName)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.green.opacity(0.1))
        .clipShape(.capsule)
    }
}

// MARK: - Suggested Workout Log Card

struct SuggestedWorkoutLogCard: View {
    let workoutLog: SuggestedWorkoutLog
    var useLbs: Bool = false
    let onAccept: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            // Header row
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: workoutLog.iconName)
                    Text("Log this?")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                .foregroundStyle(.green)

                Spacer()

                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                        .frame(width: 24, height: 24)
                        .background(Color(.tertiarySystemBackground))
                        .clipShape(.circle)
                }
            }

            // Workout name and summary
            VStack(alignment: .leading, spacing: 4) {
                Text(workoutLog.displayName)
                    .font(.headline)

                Text(workoutLog.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Exercise list with set rows
            if !workoutLog.exercises.isEmpty {
                VStack(spacing: 0) {
                    ForEach(workoutLog.exercises) { exercise in
                        WorkoutLogExerciseRow(exercise: exercise, useLbs: useLbs)
                        if exercise.id != workoutLog.exercises.last?.id {
                            Divider()
                                .padding(.leading, 12)
                        }
                    }
                }
                .background(Color(.tertiarySystemBackground))
                .clipShape(.rect(cornerRadius: 10))
            }

            // Notes if any
            if let notes = workoutLog.notes, !notes.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "note.text")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Text(notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Action button
            Button {
                onAccept()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.subheadline)
                    Text("Log Workout")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
            .buttonStyle(.traiPrimary(color: .green))
        }
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .clipShape(.rect(cornerRadius: 16))
    }
}

// MARK: - Workout Log Exercise Row

private struct WorkoutLogExerciseRow: View {
    let exercise: SuggestedWorkoutLog.LoggedExercise
    let useLbs: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Exercise name
            Text(exercise.name)
                .font(.subheadline)
                .fontWeight(.medium)

            if exercise.isStrengthLog {
                VStack(spacing: 4) {
                    ForEach(exercise.sets.indices, id: \.self) { index in
                        let set = exercise.sets[index]
                        HStack {
                            Text("Set \(index + 1)")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .frame(width: 44, alignment: .leading)

                            Text("\(set.reps) reps")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Spacer()

                            if let weight = set.weightKg, weight > 0 {
                                let displayWeight = useLbs ? Int(weight * 2.20462) : Int(weight)
                                let unit = useLbs ? "lbs" : "kg"
                                Text("\(displayWeight) \(unit)")
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                        }
                    }
                }
            } else {
                activityDetails
            }
        }
        .padding(12)
    }

    @ViewBuilder
    private var activityDetails: some View {
        let details = exercise.activitySummarySegments
        if details.isEmpty {
            Text(exercise.fallbackActivityLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    ForEach(Array(details.prefix(3).enumerated()), id: \.offset) { index, detail in
                        if index > 0 {
                            Text("•")
                                .foregroundStyle(.tertiary)
                        }
                        Text(detail)
                            .lineLimit(1)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                if let segments = exercise.segments, !segments.isEmpty {
                    ForEach(Array(segments.prefix(3).enumerated()), id: \.element.id) { index, segment in
                        Text(segmentSummary(segment, index: index, exercise: exercise))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }
            }
        }
    }

    private func segmentSummary(
        _ segment: SuggestedWorkoutLog.LoggedExercise.ActivitySegment,
        index: Int,
        exercise: SuggestedWorkoutLog.LoggedExercise
    ) -> String {
        var parts: [String] = ["Segment \(index + 1)"]
        if let duration = segment.durationMinutes, duration > 0 {
            parts.append("\(duration) min")
        }
        if let distance = segment.distanceMeters, distance > 0 {
            if distance >= 1000 {
                parts.append(String(format: "%.1f km", distance / 1000))
            } else {
                parts.append("\(Int(distance.rounded())) m")
            }
        }
        if let reps = segment.reps, reps > 0 {
            parts.append("\(reps) \(exercise.metricName(for: reps, pluralLabel: exercise.countMetricLabel))")
        }
        let notes = segment.notes?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !notes.isEmpty {
            parts.append(notes)
        }
        return parts.joined(separator: " • ")
    }
}

private extension SuggestedWorkoutLog.LoggedExercise {
    var fallbackActivityLabel: String {
        if let activityTypeName = activityTypeName?.trimmingCharacters(in: .whitespacesAndNewlines),
           !activityTypeName.isEmpty {
            return activityTypeName
        }
        if let rawCategory = category,
           let category = Exercise.Category(rawValue: rawCategory.trimmingCharacters(in: .whitespacesAndNewlines))?.userFacingEquivalent {
            return category.displayName
        }
        return "Activity"
    }
}

// MARK: - Workout Log Saved Badge

struct WorkoutLogSavedBadge: View {
    let workoutType: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text("Logged: \(workoutType)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.green.opacity(0.1))
        .clipShape(.capsule)
    }
}
