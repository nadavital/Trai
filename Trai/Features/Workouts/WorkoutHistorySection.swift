//
//  WorkoutHistorySection.swift
//  Trai
//
//  Section component showing recent workouts with "See All" functionality
//

import SwiftUI

// MARK: - Workout History Section

struct WorkoutHistorySection: View {
    private enum PreviewItem: Identifiable {
        case live(LiveWorkout)
        case session(WorkoutSession)

        var id: String {
            switch self {
            case .live(let workout):
                return "live-\(workout.id.uuidString)"
            case .session(let workout):
                return "session-\(workout.id.uuidString)"
            }
        }

        var date: Date {
            switch self {
            case .live(let workout):
                return workout.completedAt ?? workout.startedAt
            case .session(let workout):
                return workout.loggedAt
            }
        }
    }

    let workoutsByDate: [(date: Date, workouts: [WorkoutSession])]
    let liveWorkoutsByDate: [(date: Date, workouts: [LiveWorkout])]
    let activeGoals: [WorkoutGoal]
    let onWorkoutTap: (WorkoutSession) -> Void
    let onLiveWorkoutTap: (LiveWorkout) -> Void
    let onDelete: (WorkoutSession) -> Void
    let onDeleteLiveWorkout: (LiveWorkout) -> Void

    @State private var showAllWorkouts = false

    private var previewItems: [PreviewItem] {
        let liveItems = liveWorkoutsByDate
            .flatMap(\.workouts)
            .map(PreviewItem.live)
        let sessionItems = workoutsByDate
            .flatMap(\.workouts)
            .map(PreviewItem.session)

        return (liveItems + sessionItems)
            .sorted { $0.date > $1.date }
            .prefix(5)
            .map { $0 }
    }

    /// Total workout count for "See All" button
    private var totalWorkoutCount: Int {
        let sessionCount = workoutsByDate.reduce(0) { $0 + $1.workouts.count }
        let liveCount = liveWorkoutsByDate.reduce(0) { $0 + $1.workouts.count }
        return sessionCount + liveCount
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with See All button
            HStack {
                Label("Recent Workouts", systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                    .font(.headline)
                Spacer()
                if totalWorkoutCount > 5 {
                    Button {
                        showAllWorkouts = true
                    } label: {
                        Text("See All")
                            .font(.subheadline)
                            .foregroundStyle(.accent)
                    }
                }
            }

            if previewItems.isEmpty {
                EmptyWorkoutHistory()
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(previewItems) { item in
                            switch item {
                            case .live(let workout):
                                CompactLiveWorkoutRow(
                                    workout: workout,
                                    onTap: { onLiveWorkoutTap(workout) },
                                    onDelete: { onDeleteLiveWorkout(workout) }
                                )
                                .frame(width: 265)
                            case .session(let workout):
                                CompactWorkoutSessionRow(
                                    workout: workout,
                                    onTap: { onWorkoutTap(workout) },
                                    onDelete: { onDelete(workout) }
                                )
                                .frame(width: 265)
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
        .sheet(isPresented: $showAllWorkouts) {
            AllWorkoutsSheet(
                workoutsByDate: workoutsByDate,
                liveWorkoutsByDate: liveWorkoutsByDate,
                activeGoals: activeGoals,
                onWorkoutTap: onWorkoutTap,
                onLiveWorkoutTap: onLiveWorkoutTap,
                onDelete: onDelete,
                onDeleteLiveWorkout: onDeleteLiveWorkout
            )
        }
    }
}

// MARK: - Compact Live Workout Row

private struct CompactLiveWorkoutRow: View {
    let workout: LiveWorkout
    let onTap: () -> Void
    let onDelete: () -> Void

    @State private var showDeleteConfirmation = false

    private var workoutDate: Date {
        workout.completedAt ?? workout.startedAt
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                Button(action: onTap) {
                    Image(systemName: workout.historyIconName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.accent)
                        .frame(width: 34, height: 34)
                        .background(Color.accentColor.opacity(0.14), in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(workoutDate, format: .dateTime.month(.abbreviated).day())
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Menu {
                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            Label("Delete Workout", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 30, height: 28)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("Workout options")
                }
            }

            Button(action: onTap) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(workout.name)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(2)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)

                    HStack(spacing: 6) {
                        ForEach(Array(workout.historySummarySegments.prefix(2).enumerated()), id: \.offset) { _, segment in
                            Text(segment)
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(Color(.quaternarySystemFill), in: Capsule())
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(height: 142)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
        .confirmationDialog(
            "Delete Workout?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Workout", role: .destructive, action: onDelete)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes \"\(workout.name)\" from your history.")
        }
    }
}

// MARK: - Compact Workout Session Row

private struct CompactWorkoutSessionRow: View {
    let workout: WorkoutSession
    let onTap: () -> Void
    let onDelete: () -> Void

    @State private var showDeleteConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                Button(action: onTap) {
                    Image(systemName: workout.iconName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(workout.sourceIsHealthKit ? .red : .accent)
                        .frame(width: 34, height: 34)
                        .background((workout.sourceIsHealthKit ? Color.red : Color.accentColor).opacity(0.14), in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(workout.loggedAt, format: .dateTime.month(.abbreviated).day())
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Menu {
                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            Label("Delete Workout", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 30, height: 28)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("Workout options")
                }
            }

            Button(action: onTap) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Text(workout.displayName)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(2)
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)

                        if workout.sourceIsHealthKit {
                            Image(systemName: "heart.fill")
                                .font(.caption2)
                                .foregroundStyle(.red)
                        }
                    }

                    HStack(spacing: 6) {
                        ForEach(Array(workout.historyDetailSegments.prefix(2).enumerated()), id: \.offset) { _, segment in
                            Text(segment)
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(segment.hasSuffix("kcal") ? .red : .secondary)
                                .lineLimit(1)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(Color(.quaternarySystemFill), in: Capsule())
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(height: 142)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
        .confirmationDialog(
            "Delete Workout?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Workout", role: .destructive, action: onDelete)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes \"\(workout.displayName)\" from your history.")
        }
    }
}
