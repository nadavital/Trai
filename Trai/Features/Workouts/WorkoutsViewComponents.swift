//
//  WorkoutsViewComponents.swift
//  Trai
//
//  Supporting card components for WorkoutsView
//

import SwiftUI

// MARK: - Start Workout Section

struct StartWorkoutSection: View {
    let templates: [WorkoutPlan.WorkoutTemplate]
    let recoveryScores: [UUID: (score: Double, reason: String)]
    let recommendedTemplateId: UUID?
    let onStartTemplate: (WorkoutPlan.WorkoutTemplate) -> Void
    let onStartCustomWorkout: () -> Void
    var onCreatePlan: (() -> Void)?

    private var featuredTemplateId: UUID? {
        recommendedTemplateId ?? templates.first?.id
    }

    private var featuredTemplate: WorkoutPlan.WorkoutTemplate? {
        guard let featuredTemplateId else { return nil }
        return templates.first(where: { $0.id == featuredTemplateId })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let featuredTemplate {
                FeaturedStartWorkoutCard(
                    template: featuredTemplate,
                    recoveryInsight: recoveryScores[featuredTemplate.id],
                    isRecommended: recommendedTemplateId == featuredTemplate.id,
                    onStart: { onStartTemplate(featuredTemplate) }
                )
            } else if let onCreatePlan {
                StartWorkoutCreatePlanCard(
                    onCreatePlan: onCreatePlan,
                    onStartCustomWorkout: onStartCustomWorkout
                )
            } else {
                StartWorkoutEmptyState()
            }
        }
    }
}

private struct FeaturedStartWorkoutCard: View {
    let template: WorkoutPlan.WorkoutTemplate
    let recoveryInsight: (score: Double, reason: String)?
    let isRecommended: Bool
    let onStart: () -> Void
    @Environment(\.dynamicTypeSize) private var typeSize
    private var sessionSummary: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(isRecommended ? "Suggested session" : "Up next")
                .font(.subheadline).foregroundStyle(.secondary)
            Text(template.name).font(.system(.title2, design: .rounded, weight: .bold))
                .fixedSize(horizontal: false, vertical: true)
            Text(template.muscleGroupsDisplay).font(.subheadline).foregroundStyle(.secondary)
            if template.estimatedDurationMinutes > 0 {
                Text("About \(template.estimatedDurationMinutes) min")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }

    private var startAction: some View {
        Button("Start workout", systemImage: "play.fill", action: onStart)
            .buttonStyle(.traiPrimary()).fixedSize()
            .accessibilityIdentifier("workoutHeroStart")
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            if !typeSize.isAccessibilitySize {
                HStack(spacing: 24) {
                    WorkoutTemplateArtwork(template: template, role: .hero)
                        .frame(width: 144, height: 156)
                    sessionSummary.frame(minWidth: 260, maxWidth: .infinity, alignment: .leading)
                    startAction
                }
            }
            let compactLayout = typeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
                : AnyLayout(HStackLayout(alignment: .center, spacing: 16))
            compactLayout {
                WorkoutTemplateArtwork(template: template, role: .hero)
                    .frame(width: 120, height: 142)
                VStack(alignment: .leading, spacing: 12) {
                    sessionSummary
                    startAction
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
        }.padding(.vertical, 12)
    }
}

struct WorkoutAlternativeSessions: View {
    let templates: [WorkoutPlan.WorkoutTemplate]
    let featuredID: UUID?
    let onSelect: (WorkoutPlan.WorkoutTemplate) -> Void
    let onCustom: () -> Void
    let onChooseAnother: () -> Void
    private var alternatives: [WorkoutPlan.WorkoutTemplate] {
        Array(templates.filter { $0.id != (featuredID ?? templates.first?.id) }.prefix(2))
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Text("Other sessions").font(.headline)
                Spacer(minLength: 8)
                Button("Choose another", action: onChooseAnother)
                    .buttonStyle(.traiSecondary(size: .compact))
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("workoutChooseAnother")
            }
            TraiHorizontalScrollView(identifier: "workoutAlternativesScroll") {
                HStack(spacing: 12) {
                    Button(action: onCustom) {
                        alternativeLabel(title: "Custom workout", subtitle: "Choose as you go", color: .pink) {
                            WorkoutRenderedActivityAsset(key: "Custom")
                        }
                    }.buttonStyle(.plain)
                    ForEach(alternatives) { template in
                        Button { onSelect(template) } label: {
                            alternativeLabel(title: template.name, subtitle: template.muscleGroupsDisplay, color: .teal) {
                                WorkoutTemplateArtwork(template: template)
                            }
                        }.buttonStyle(.plain)
                    }
                }
            }.scrollIndicators(.hidden).scrollBounceBehavior(.basedOnSize)
        }
    }
    private func alternativeLabel<Artwork: View>(title: String, subtitle: String, color: Color,
                                                 @ViewBuilder artwork: () -> Artwork) -> some View {
        HStack(spacing: 10) {
            artwork().frame(width: 56, height: 64)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.subheadline.weight(.semibold)).lineLimit(2)
                Text(subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            }.frame(maxWidth: .infinity, alignment: .leading)
        }.frame(width: 230, height: 80).padding(12)
            .background(color.opacity(0.09), in: .rect(cornerRadius: TraiRadius.large))
            .foregroundStyle(.primary)
    }
}

struct TrainingRecoveryOverview: View {
    let recoveryInfo: [MuscleRecoveryService.MuscleRecoveryInfo]
    let onDetails: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Your muscle history")
                .font(.system(.title3, design: .rounded, weight: .bold))
            RecordedMuscleMap(recoveryInfo: recoveryInfo)
            Button("Recovery details", action: onDetails)
                .buttonStyle(.traiSecondary(size: .compact))
                .frame(minHeight: 44)
        }
    }
}

struct WorkoutPlanSessionsSection: View {
    let plan: WorkoutPlan
    let onStartTemplate: (WorkoutPlan.WorkoutTemplate) -> Void
    let onStartCustomWorkout: () -> Void
    let onEditPlan: () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var expandedTemplates: Set<UUID> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
                : AnyLayout(HStackLayout(alignment: .center, spacing: 12))
            layout {
                VStack(alignment: .leading, spacing: 4) {
                    Text(plan.splitType.displayName).font(.title3.weight(.semibold))
                    Text("\(plan.daysPerWeek) days a week")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Button("Edit plan", systemImage: "pencil", action: onEditPlan)
                    .font(.subheadline.weight(.semibold))
                    .buttonStyle(.traiTertiary(color: .primary))
            }

            ForEach(plan.templates.sorted { $0.order < $1.order }) { template in
                sessionCard(template)
            }
            Button("Start custom workout", systemImage: "plus", action: onStartCustomWorkout)
                .buttonStyle(.traiSecondary(fullWidth: true))
        }
    }

    private func sessionCard(_ template: WorkoutPlan.WorkoutTemplate) -> some View {
        let isExpanded = expandedTemplates.contains(template.id)
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 12))
        return VStack(alignment: .leading, spacing: 14) {
            layout {
                Button {
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                        if isExpanded {
                            expandedTemplates.remove(template.id)
                        } else {
                            expandedTemplates.insert(template.id)
                        }
                    }
                } label: {
                    HStack(spacing: 10) {
                        WorkoutTemplateArtwork(template: template, role: .row)
                            .frame(width: 48, height: 48)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(template.name)
                                .font(.system(.headline, design: .rounded))
                                .foregroundStyle(.primary)
                            Text(template.displaySubtitle)
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    }
                    .frame(minHeight: 44)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(template.name), session details")
                .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")
                .accessibilityHint("Inspect exercises and training blocks")

                Button("Start", systemImage: "play.fill") { onStartTemplate(template) }
                    .buttonStyle(.traiSecondary(color: .red))
                    .accessibilityLabel("Start \(template.name)")
            }

            if isExpanded {
                Divider()
                VStack(alignment: .leading, spacing: 12) {
                    if template.estimatedDurationMinutes > 0 {
                        Label("About \(template.estimatedDurationMinutes) min", systemImage: "clock")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    ForEach(template.displayBlocks) { block in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(block.shortSummary)
                                .font(.subheadline.weight(.semibold))
                            let targets = [block.intensity, block.target]
                                .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
                                .filter { !$0.isEmpty }
                                .joined(separator: " · ")
                            if !targets.isEmpty {
                                Text(targets).font(.caption).foregroundStyle(.secondary)
                            }
                            if !block.detail.isEmpty {
                                Text(block.detail)
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            ForEach(block.exercises.sorted { $0.order < $1.order }) { exercise in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(exercise.exerciseName).font(.subheadline)
                                    Text("\(exercise.defaultSets) sets · \(exercise.repRange ?? String(exercise.defaultReps)) reps")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            if let notes = block.notes, !notes.isEmpty, notes != block.detail {
                                Text(notes).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .traiCard(contentPadding: 14)
    }

}

private struct StartWorkoutCreatePlanCard: View {
    let onCreatePlan: () -> Void
    let onStartCustomWorkout: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.title3)
                    .foregroundStyle(Color.accentColor)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Build your workout plan")
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(.primary)

                    Text("Choose your days. Make the plan yours.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 8)
            }

            HStack(spacing: 10) {
                Button("Create Plan", action: onCreatePlan)
                    .buttonStyle(.traiPrimary(fullWidth: true))

                Button("Quick Start") {
                    onStartCustomWorkout()
                }
                .buttonStyle(.traiTertiary(color: .primary, fullWidth: true))
            }
        }
        .padding(16)
        .traiCard(cornerRadius: 20, contentPadding: 0)
    }
}

private struct StartWorkoutEmptyState: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "figure.mixed.cardio")
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Start any workout")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)

                    Text("Use Quick Start to log a flexible session without a plan.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
        }
        .padding(16)
        .traiCard(cornerRadius: 20, contentPadding: 0)
    }
}

// MARK: - Quick Actions Row

struct WorkoutsQuickActionsRow: View {
    let onPersonalRecords: () -> Void
    let onCustomExercises: () -> Void
    let onRecovery: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 10))
            : AnyLayout(HStackLayout(spacing: 10))
        layout {
                WorkoutsQuickActionChip("Records", systemImage: "trophy.fill", color: TraiColors.blaze, action: onPersonalRecords)
                WorkoutsQuickActionChip("Exercises", systemImage: "figure.strengthtraining.traditional", color: .blue, action: onCustomExercises)
                WorkoutsQuickActionChip("Recovery", systemImage: "waveform.path.ecg", color: .green, action: onRecovery)
        }
    }
}

private struct WorkoutsQuickActionChip: View {
    let label: String
    let systemImage: String
    let color: Color
    let action: () -> Void

    init(_ label: String, systemImage: String, color: Color, action: @escaping () -> Void) {
        self.label = label
        self.systemImage = systemImage
        self.color = color
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(color)

                Text(label)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
                .frame(maxWidth: .infinity, minHeight: 44)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(color.opacity(0.10), in: .capsule)
        }
        .buttonStyle(TraiPressStyle())
    }
}

// MARK: - Active Workout Banner

struct ActiveWorkoutBanner: View {
    let workout: LiveWorkout
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Pulsing indicator
                Circle()
                    .fill(.green)
                    .frame(width: 12, height: 12)
                    .overlay {
                        Circle()
                            .stroke(.green.opacity(0.5), lineWidth: 2)
                            .scaleEffect(1.5)
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Workout in Progress")
                        .font(.subheadline)
                        .bold()
                    Text(workout.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(workout.formattedDuration)
                    .font(.headline)
                    .monospacedDigit()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .traiCard(tint: .green, cornerRadius: 16)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Todays Workout Summary

struct TodaysWorkoutSummary: View {
    let workouts: [WorkoutSession]
    var liveWorkouts: [LiveWorkout] = []

    private var totalWorkoutCount: Int {
        workouts.count + liveWorkouts.count
    }

    private var totalDuration: Int {
        let sessionDuration = workouts.compactMap { $0.durationMinutes }.reduce(0) { $0 + Int($1) }
        let liveDuration = liveWorkouts.reduce(0) { $0 + Int($1.duration / 60) }
        return sessionDuration + liveDuration
    }

    private var totalCalories: Int {
        let sessionCalories = workouts.compactMap(\.caloriesBurned).reduce(0, +)
        let liveCalories = liveWorkouts.compactMap { $0.healthKitCalories.map { Int($0) } }.reduce(0, +)
        return sessionCalories + liveCalories
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Today's Activity", systemImage: "flame.fill")
                    .font(.headline)
                Spacer()
            }

            if totalWorkoutCount == 0 {
                HStack {
                    Image(systemName: "figure.run")
                        .foregroundStyle(.secondary)
                    Text("No workouts yet today")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else {
                HStack(spacing: 24) {
                    WorkoutStatItem(
                        value: "\(totalWorkoutCount)",
                        label: totalWorkoutCount == 1 ? "workout" : "workouts",
                        icon: "figure.run",
                        color: .orange
                    )

                    if totalDuration > 0 {
                        WorkoutStatItem(
                            value: "\(totalDuration)",
                            label: "minutes",
                            icon: "clock.fill",
                            color: .blue
                        )
                    }

                    if totalCalories > 0 {
                        WorkoutStatItem(
                            value: "\(totalCalories)",
                            label: "kcal",
                            icon: "flame.fill",
                            color: .red
                        )
                    }
                }
            }
        }
        .traiCard(cornerRadius: 16)
    }
}

// MARK: - Workout Stat Item

struct WorkoutStatItem: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)

            Text(value)
                .font(.title2)
                .bold()

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        VStack(spacing: 16) {
            ActiveWorkoutBanner(
                workout: {
                    let w = LiveWorkout(name: "Push Day", workoutType: .strength, targetMuscleGroups: [.chest, .shoulders, .triceps])
                    return w
                }(),
                onTap: {}
            )

            TodaysWorkoutSummary(workouts: [])
        }
        .padding()
    }
}
