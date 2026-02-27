//
//  PlanReviewRecommendationCard.swift
//  Trai
//
//  UI card for displaying plan reassessment recommendations
//

import SwiftUI

struct PlanReviewRecommendationCard: View {
    let recommendation: PlanRecommendation
    let message: String
    let onReviewPlan: () -> Void
    let onDismiss: () -> Void

    private var iconName: String {
        switch recommendation.trigger {
        case .weightChange:
            "scalemass.fill"
        case .weightPlateau:
            "chart.line.flattrend.xyaxis"
        case .planAge:
            "calendar.badge.clock"
        }
    }

    private var accentColor: Color {
        switch recommendation.trigger {
        case .weightChange:
            .accentColor
        case .weightPlateau:
            .orange
        case .planAge:
            .accentColor
        }
    }

    private var triggerTitle: String {
        switch recommendation.trigger {
        case .weightChange:
            "Weight Change Detected"
        case .weightPlateau:
            "Weight Plateau Detected"
        case .planAge:
            "Time for a Plan Review"
        }
    }

    var body: some View {
        VStack(spacing: 14) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: iconName)
                        .font(.subheadline)
                        .foregroundStyle(accentColor)

                    Text(triggerTitle)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }

                Spacer()

                Button {
                    HapticManager.lightTap()
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                        .frame(width: 24, height: 24)
                        .background(Color(.quaternarySystemFill))
                        .clipShape(.circle)
                }
            }

            // Message
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Action buttons
            HStack(spacing: 12) {
                Button {
                    HapticManager.lightTap()
                    onDismiss()
                } label: {
                    Text("Later")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.traiTertiary(color: .secondary))

                Button {
                    HapticManager.selectionChanged()
                    onReviewPlan()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.subheadline)
                        Text("Review Plan")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.traiPrimary(color: accentColor))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
        )
    }
}

#Preview("Weight Change") {
    VStack {
        PlanReviewRecommendationCard(
            recommendation: PlanRecommendation(
                trigger: .weightChange,
                details: PlanRecommendation.TriggerDetails(
                    weightChangeKg: -3.2,
                    baselineWeightKg: 85.0,
                    currentWeightKg: 81.8
                )
            ),
            message: "Great progress! You've lost 3.2 kg. Let's update your plan to keep the momentum going.",
            onReviewPlan: {},
            onDismiss: {}
        )
    }
    .padding()
}

#Preview("Plateau") {
    VStack {
        PlanReviewRecommendationCard(
            recommendation: PlanRecommendation(
                trigger: .weightPlateau,
                details: PlanRecommendation.TriggerDetails(
                    plateauDays: 16,
                    plateauWeightKg: 78.5
                )
            ),
            message: "Your weight has stayed consistent for 16 days. Let's review your plan to help you break through.",
            onReviewPlan: {},
            onDismiss: {}
        )
    }
    .padding()
}

#Preview("Plan Age") {
    VStack {
        PlanReviewRecommendationCard(
            recommendation: PlanRecommendation(
                trigger: .planAge,
                details: PlanRecommendation.TriggerDetails(
                    daysSinceReview: 35,
                    lastReviewDate: Calendar.current.date(byAdding: .day, value: -35, to: Date())
                )
            ),
            message: "It's been 35 days since your plan was last reviewed. Time for a check-in!",
            onReviewPlan: {},
            onDismiss: {}
        )
    }
    .padding()
}
