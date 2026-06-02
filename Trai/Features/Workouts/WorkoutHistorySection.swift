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
            TraiSectionHeader("Recent Workouts", icon: "clock.arrow.trianglehead.counterclockwise.rotate.90") {
                if totalWorkoutCount > 5 {
                    Button {
                        showAllWorkouts = true
                    } label: {
                        Text("See All")
                    }
                    .buttonStyle(.traiTertiary(size: .compact, height: 32))
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
                                .frame(width: 150)
                            case .session(let workout):
                                CompactWorkoutSessionRow(
                                    workout: workout,
                                    onTap: { onWorkoutTap(workout) },
                                    onDelete: { onDelete(workout) }
                                )
                                .frame(width: 150)
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

struct CompactLiveWorkoutRow: View {
    let workout: LiveWorkout
    let onTap: () -> Void
    let onDelete: (() -> Void)?

    @State private var showDeleteConfirmation = false

    init(
        workout: LiveWorkout,
        onTap: @escaping () -> Void,
        onDelete: (() -> Void)? = nil
    ) {
        self.workout = workout
        self.onTap = onTap
        self.onDelete = onDelete
    }

    private var workoutDate: Date {
        workout.completedAt ?? workout.startedAt
    }

    private var subtitle: String {
        workout.historySummarySegments.first ?? workoutDate.formatted(.dateTime.month(.abbreviated).day())
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button(action: onTap) {
                VStack(spacing: 8) {
                    Image(systemName: workout.historyIconName)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(TraiColors.flame)
                        .frame(width: 48, height: 48)
                        .background(TraiColors.flame.opacity(0.14), in: RoundedRectangle(cornerRadius: 14))

                    Text(workout.name)
                        .font(.traiLabel(13))
                        .lineLimit(2)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(subtitle)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .padding(.horizontal, 10)
                .frame(height: 126)
                .contentShape(RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)

            if onDelete != nil {
                Menu {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete Workout", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Workout options")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 14))
        .confirmationDialog(
            "Delete Workout?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            if let onDelete {
                Button("Delete Workout", role: .destructive, action: onDelete)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes \"\(workout.name)\" from your history.")
        }
    }
}

// MARK: - Compact Workout Session Row

struct CompactWorkoutSessionRow: View {
    let workout: WorkoutSession
    let onTap: () -> Void
    let onDelete: (() -> Void)?

    @State private var showDeleteConfirmation = false

    init(
        workout: WorkoutSession,
        onTap: @escaping () -> Void,
        onDelete: (() -> Void)? = nil
    ) {
        self.workout = workout
        self.onTap = onTap
        self.onDelete = onDelete
    }

    private var subtitle: String {
        workout.historyDetailSegments.first ?? workout.loggedAt.formatted(.dateTime.month(.abbreviated).day())
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button(action: onTap) {
                VStack(spacing: 8) {
                    Image(systemName: workout.iconName)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(workout.sourceIsHealthKit ? .red : TraiColors.flame)
                        .frame(width: 48, height: 48)
                        .background((workout.sourceIsHealthKit ? Color.red : TraiColors.flame).opacity(0.14), in: RoundedRectangle(cornerRadius: 14))

                    Text(workout.displayName)
                        .font(.traiLabel(13))
                        .lineLimit(2)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(subtitle)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(workout.sourceIsHealthKit ? .red : .secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .padding(.horizontal, 10)
                .frame(height: 126)
                .contentShape(RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)

            if onDelete != nil {
                Menu {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete Workout", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Workout options")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 14))
        .confirmationDialog(
            "Delete Workout?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            if let onDelete {
                Button("Delete Workout", role: .destructive, action: onDelete)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes \"\(workout.displayName)\" from your history.")
        }
    }
}
