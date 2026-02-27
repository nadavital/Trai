//
//  WorkoutPlanProposalCard.swift
//  Trai
//
//  Inline card showing a generated workout plan with accept/customize options
//

import SwiftUI

/// Card displayed inline in chat showing the generated workout plan
struct WorkoutPlanProposalCard: View {
    let plan: WorkoutPlan
    let message: String
    let onAccept: () -> Void
    let onCustomize: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Trai's message (only show if not empty)
            if !message.isEmpty {
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
            }

            // Plan summary card
            VStack(alignment: .leading, spacing: 12) {
                // Header
                planHeader

                Divider()

                // Templates preview
                templatesPreview

                // Action buttons
                actionButtons
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .clipShape(.rect(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
            }
        }
    }

    // MARK: - Plan Header

    private var planHeader: some View {
        HStack {
            Image(systemName: plan.splitType.iconName)
                .font(.title3)
                .foregroundStyle(.accent)

            VStack(alignment: .leading, spacing: 2) {
                Text(plan.splitType.displayName)
                    .font(.subheadline)
                    .bold()

                Text("\(plan.daysPerWeek) days/week")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Total exercises count
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(totalExercises)")
                    .font(.subheadline)
                    .bold()

                Text("exercises")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var totalExercises: Int {
        plan.templates.reduce(0) { $0 + $1.exerciseCount }
    }

    // MARK: - Templates Preview

    private var templatesPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(plan.templates) { template in
                HStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.2))
                        .frame(width: 8, height: 8)

                    Text(template.name)
                        .font(.caption)
                        .fontWeight(.medium)

                    Spacer()

                    Text("\(template.exerciseCount) exercises")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Text("\(template.estimatedDurationMinutes) min")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: 12) {
            // Accept button
            Button(action: onAccept) {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                    Text("Use This Plan")
                        .fontWeight(.semibold)
                }
                .font(.subheadline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .buttonStyle(.traiPrimary(color: .accentColor))

            // Customize button (optional)
            if let customize = onCustomize {
                Button(action: customize) {
                    HStack(spacing: 6) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 12, weight: .medium))
                        Text("Adjust")
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                }
                .buttonStyle(.traiTertiary())
            }
        }
    }
}

// MARK: - Plan Accepted Badge

/// Shows a confirmation badge when plan is accepted
struct WorkoutPlanAcceptedBadge: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.body)
                .foregroundStyle(.green)

            Text("Plan saved!")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.green.opacity(0.1))
        .clipShape(.capsule)
    }
}

// MARK: - Plan Updated Badge

/// Shows when a plan was updated after refinement
struct WorkoutPlanUpdatedBadge: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.body)
                .foregroundStyle(.accent)

            Text("Plan updated")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.accentColor.opacity(0.1))
        .clipShape(.capsule)
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        VStack(spacing: 20) {
            WorkoutPlanProposalCard(
                plan: WorkoutPlan(
                    splitType: .pushPullLegs,
                    daysPerWeek: 4,
                    templates: [
                        WorkoutPlan.WorkoutTemplate(
                            name: "Push Day",
                            targetMuscleGroups: ["chest", "shoulders", "triceps"],
                            exercises: [],
                            estimatedDurationMinutes: 45,
                            order: 0
                        ),
                        WorkoutPlan.WorkoutTemplate(
                            name: "Pull Day",
                            targetMuscleGroups: ["back", "biceps"],
                            exercises: [],
                            estimatedDurationMinutes: 45,
                            order: 1
                        ),
                        WorkoutPlan.WorkoutTemplate(
                            name: "Legs Day",
                            targetMuscleGroups: ["quads", "hamstrings", "calves"],
                            exercises: [],
                            estimatedDurationMinutes: 50,
                            order: 2
                        ),
                        WorkoutPlan.WorkoutTemplate(
                            name: "Cardio",
                            targetMuscleGroups: ["cardio"],
                            exercises: [],
                            estimatedDurationMinutes: 30,
                            order: 3
                        )
                    ],
                    rationale: "A classic Push/Pull/Legs split is perfect for your schedule and goals. This gives each muscle group adequate rest while maintaining workout frequency.",
                    guidelines: ["Rest 2-3 minutes between heavy sets"],
                    progressionStrategy: .defaultStrategy,
                    warnings: nil
                ),
                message: "Here's what I put together for you!",
                onAccept: {},
                onCustomize: {}
            )

            WorkoutPlanAcceptedBadge()

            WorkoutPlanUpdatedBadge()
        }
        .padding()
    }
}
