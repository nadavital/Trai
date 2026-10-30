//
//  WorkoutHistorySection.swift
//  Trai
//
//  Inline workout history grouped by day
//

import SwiftUI

enum WorkoutHistoryRecencyFormatter {
    static func compactLabel(for date: Date, now: Date = .now) -> String {
        let elapsed = max(0, now.timeIntervalSince(date))
        let hour: TimeInterval = 60 * 60
        let day: TimeInterval = 24 * hour
        let week: TimeInterval = 7 * day
        let month: TimeInterval = 30 * day
        let year: TimeInterval = 365 * day

        switch elapsed {
        case ..<hour:
            return "now"
        case ..<day:
            return "\(max(1, Int(elapsed / hour)))h"
        case ..<week:
            return "\(max(1, Int(elapsed / day)))d"
        case ..<month:
            return "\(max(1, Int(elapsed / week)))w"
        case ..<year:
            return "\(max(1, Int(elapsed / month)))m"
        default:
            return "\(max(1, Int(elapsed / year)))y"
        }
    }
}

// MARK: - Workout History Section

struct WorkoutHistorySection: View {
    private enum HistoryItem: Identifiable {
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

    @State private var pendingDelete: HistoryItem?

    private struct HistoryDay: Identifiable {
        let date: Date
        let items: [HistoryItem]
        var id: Date { date }
    }

    private var historyDays: [HistoryDay] {
        let liveItems = liveWorkoutsByDate.flatMap(\.workouts).map(HistoryItem.live)
        let sessionItems = workoutsByDate.flatMap(\.workouts).map(HistoryItem.session)
        let grouped = Dictionary(grouping: liveItems + sessionItems) {
            Calendar.current.startOfDay(for: $0.date)
        }
        return grouped.keys.sorted(by: >).map { date in
            HistoryDay(date: date, items: (grouped[date] ?? []).sorted { $0.date > $1.date })
        }
    }

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 20) {
            if historyDays.isEmpty {
                EmptyWorkoutHistory()
                    .traiCard()
            } else {
                ForEach(historyDays) { day in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(day.date, format: .dateTime.weekday(.wide).month(.abbreviated).day())
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .accessibilityAddTraits(.isHeader)

                        VStack(spacing: 12) {
                            ForEach(day.items) { item in
                                VStack(alignment: .leading, spacing: 0) {
                                    HStack {
                                        Text(item.date, format: .dateTime.hour().minute())
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Spacer()
                                        Menu {
                                            Button("Delete workout", systemImage: "trash", role: .destructive) {
                                                pendingDelete = item
                                            }
                                        } label: {
                                            Image(systemName: "ellipsis")
                                                .frame(width: 44, height: 44)
                                                .contentShape(.rect)
                                        }
                                        .accessibilityLabel("Workout options")
                                    }
                                    switch item {
                                    case .live(let workout):
                                        LiveWorkoutHistoryRow(
                                            workout: workout,
                                            activeGoals: activeGoals,
                                            onTap: { onLiveWorkoutTap(workout) },
                                            onDelete: { onDeleteLiveWorkout(workout) }
                                        )
                                    case .session(let workout):
                                        WorkoutHistoryRow(
                                            workout: workout,
                                            onTap: { onWorkoutTap(workout) },
                                            onDelete: { onDelete(workout) }
                                        )
                                    }
                                }
                                if item.id != day.items.last?.id {
                                    Divider()
                                }
                            }
                        }
                        .traiCard()
                    }
                }
            }
        }
        .confirmationDialog(
            "Delete workout?",
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ),
            titleVisibility: .visible,
            presenting: pendingDelete
        ) { item in
            Button("Delete workout", role: .destructive) {
                switch item {
                case .live(let workout): onDeleteLiveWorkout(workout)
                case .session(let workout): onDelete(workout)
                }
                pendingDelete = nil
            }
            Button("Cancel", role: .cancel) { pendingDelete = nil }
        } message: { _ in
            Text("This cannot be undone.")
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

    private var recencyLabel: String {
        WorkoutHistoryRecencyFormatter.compactLabel(for: workoutDate)
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

            Text(recencyLabel)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(Color(.secondarySystemFill), in: Capsule())
                .frame(minWidth: 34, minHeight: 24)
                .padding(6)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .allowsHitTesting(false)
                .accessibilityHidden(true)

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

    private var recencyLabel: String {
        WorkoutHistoryRecencyFormatter.compactLabel(for: workout.loggedAt)
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

            Text(recencyLabel)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(Color(.secondarySystemFill), in: Capsule())
                .frame(minWidth: 34, minHeight: 24)
                .padding(6)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .allowsHitTesting(false)
                .accessibilityHidden(true)

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
