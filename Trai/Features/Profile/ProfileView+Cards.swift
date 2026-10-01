//
//  ProfileView+Cards.swift
//  Trai
//
//  Profile view card components (plan, memories, chat history, preferences)
//

import SwiftUI

extension ProfileView {
    // MARK: - Plan Card

    @ViewBuilder
    func planCard(_ profile: UserProfile) -> some View {
        VStack(spacing: 16) {
            planActionLayout {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Nutrition Plan", systemImage: "chart.pie.fill")
                        .font(.headline)
                        .foregroundStyle(.primary)

                }

                if !dynamicTypeSize.isAccessibilitySize { Spacer() }

                Button {
                    showPlanSheet = true
                } label: {
                    Text("Adjust")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .buttonStyle(.traiTertiary(size: .compact, width: dynamicTypeSize.isAccessibilitySize ? nil : 76, height: dynamicTypeSize.isAccessibilitySize ? nil : 44))
                .controlSize(.small)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            let effectiveCalories = profile.effectiveCalorieGoal(hasWorkoutToday: hasWorkoutToday)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(effectiveCalories)")
                    .font(.system(.title, design: .rounded, weight: .bold))

                Text("kcal/day")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                if hasWorkoutToday, let trainingCals = profile.trainingDayCalories, trainingCals != profile.dailyCalorieGoal {
                    Text("+\(trainingCals - profile.dailyCalorieGoal)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.15), in: .capsule)
                }
            }

            // Show enabled macros with dynamic grid layout
            let macros = profile.enabledMacrosOrdered
            if !macros.isEmpty {
                DisclosureGroup("Daily macro targets") {
                    VStack(spacing: 8) {
                    ForEach(Array(balancedMacroRows(for: macros).enumerated()), id: \.offset) { _, row in
                        HStack(spacing: 8) {
                            ForEach(row) { macro in
                                MacroPill(
                                    label: macro.displayName,
                                    value: profile.goalFor(macro),
                                    unit: "g",
                                    color: macro.color
                                )
                            }
                        }
                    }
                    }
                    .padding(.top, 8)
                }
                .font(.subheadline)
                .tint(.primary)
            }

            planActionLayout {
                // Review with Trai button
                Button {
                    if canAccessAIFeatures {
                        if accountSessionService?.isAuthenticated == false {
                            presentedAccountSetupContext = .aiFeatures
                        } else {
                            if !PendingTraiChatLaunchRequest.hasValidPendingTraiChatPayload() {
                                PendingTraiChatLaunchRequest(
                                    prompt: "Can you review my nutrition plan and check if any updates are needed based on my progress?",
                                    launchLabel: "Reviewing your nutrition plan...",
                                    actionKind: .nutritionPlanReview
                                ).write()
                            }
                            openTraiTab()
                        }
                    } else {
                        proUpsellCoordinator?.present(source: .nutritionPlan)
                    }
                    HapticManager.lightTap()
                } label: {
                    aiActionButtonLabel(
                        isUnlocked: canAccessAIFeatures,
                        unlockedTitle: "Review with Trai"
                    )
                }
                .buttonStyle(.traiSecondary(color: .accentColor, size: .compact, fullWidth: true, height: dynamicTypeSize.isAccessibilitySize ? nil : 44))

                // Plan History link
                NavigationLink {
                    PlanHistoryView()
                } label: {
                    HStack {
                        Image(systemName: "clock.arrow.circlepath")
                        Text("History")
                            .font(.subheadline.weight(.medium))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .fixedSize(horizontal: !dynamicTypeSize.isAccessibilitySize, vertical: true)
                    .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : nil)
                }
                .buttonStyle(.traiTertiary(size: .compact, height: dynamicTypeSize.isAccessibilitySize ? nil : 44))
                .layoutPriority(1)
            }

            if let currentWeight = latestWeightForPlanPrompt,
               profile.shouldPromptForRecalculation(currentWeight: currentWeight),
               let diff = profile.weightDifferenceSincePlan(currentWeight: currentWeight) {
                HStack(spacing: 12) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.title3)
                        .foregroundStyle(Color.accentColor)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(format: "Weight changed by %.1f kg", diff))
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Text("Consider updating your plan")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button("Update") {
                        showPlanSheet = true
                    }
                    .font(.subheadline)
                    .buttonStyle(.traiPrimary(color: .accentColor, size: .compact, width: dynamicTypeSize.isAccessibilitySize ? nil : 76, height: dynamicTypeSize.isAccessibilitySize ? nil : 44))
                    .controlSize(.small)
                }
                .padding()
                .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(20)
        .traiCard(cornerRadius: 20, contentPadding: 0)
    }

    // MARK: - Workout Plan Card

    @ViewBuilder
    func workoutPlanCard(_ profile: UserProfile) -> some View {
        if let plan = profile.workoutPlan {
            // Has plan - show detailed card like nutrition plan
            VStack(spacing: 16) {
                // Header with title and adjust button
                planActionLayout {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Workout Plan", systemImage: "figure.strengthtraining.traditional")
                            .font(.headline)
                            .foregroundStyle(.primary)

                        HStack(spacing: 4) {
                            Image(systemName: plan.splitType.iconName)
                                .font(.caption2)
                            Text(plan.splitType.displayName)
                                .font(.caption)
                        }
                        .foregroundStyle(.secondary)
                    }

                    if !dynamicTypeSize.isAccessibilitySize { Spacer() }

                    Button {
                        showPlanEditSheet = true
                    } label: {
                        Text("Adjust")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .buttonStyle(.traiTertiary(size: .compact, width: dynamicTypeSize.isAccessibilitySize ? nil : 76, height: dynamicTypeSize.isAccessibilitySize ? nil : 44))
                    .controlSize(.small)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Big stats display
                planActionLayout {
                    VStack(spacing: 2) {
                        Text("\(plan.daysPerWeek)")
                            .font(.system(.title2, design: .rounded, weight: .bold))
                            .foregroundStyle(.green)
                        Text("days/week")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    VStack(spacing: 2) {
                        Text("\(plan.templates.count)")
                            .font(.system(.title2, design: .rounded, weight: .bold))
                            .foregroundStyle(Color.accentColor)
                        Text("workouts")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let avgDuration = plan.templates.isEmpty ? nil : plan.templates.map(\.estimatedDurationMinutes).reduce(0, +) / plan.templates.count {
                        VStack(spacing: 2) {
                            Text("~\(avgDuration)")
                                .font(.system(.title2, design: .rounded, weight: .bold))
                                .foregroundStyle(.orange)
                            Text("min avg")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .frame(maxWidth: .infinity)

                // Template chips
                DisclosureGroup("Your workouts") {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(plan.templates.sorted { $0.order < $1.order }) { template in
                            WorkoutPlanChip(template: template)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 8)
                }
                .font(.subheadline)
                .tint(.primary)

                planActionLayout {
                    Button {
                        if canAccessAIFeatures {
                            if accountSessionService?.isAuthenticated == false {
                                presentedAccountSetupContext = .aiFeatures
                            } else {
                                if !PendingTraiChatLaunchRequest.hasValidPendingTraiChatPayload() {
                                    PendingTraiChatLaunchRequest(
                                        prompt: "Can you review my workout split and suggest any updates based on my recovery and recent workouts?",
                                        launchLabel: "Reviewing your workout plan..."
                                    ).write()
                                }
                                openTraiTab()
                            }
                        } else {
                            proUpsellCoordinator?.present(source: .workoutPlan)
                        }
                        HapticManager.lightTap()
                    } label: {
                        aiActionButtonLabel(
                            isUnlocked: canAccessAIFeatures,
                            unlockedTitle: "Review with Trai"
                        )
                    }
                    .buttonStyle(.traiSecondary(color: .accentColor, size: .compact, fullWidth: true, height: dynamicTypeSize.isAccessibilitySize ? nil : 44))

                    NavigationLink {
                        WorkoutPlanHistoryView()
                    } label: {
                        HStack {
                            Image(systemName: "clock.arrow.circlepath")
                            Text("History")
                                .font(.subheadline.weight(.medium))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .fixedSize(horizontal: !dynamicTypeSize.isAccessibilitySize, vertical: true)
                        .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : nil)
                    }
                    .buttonStyle(.traiTertiary(size: .compact, height: dynamicTypeSize.isAccessibilitySize ? nil : 44))
                    .layoutPriority(1)
                }
            }
            .padding(20)
            .traiCard(cornerRadius: 20, contentPadding: 0)
        } else {
            // No plan - show create CTA
            VStack(spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Workout Plan", systemImage: "figure.strengthtraining.traditional")
                            .font(.headline)
                            .foregroundStyle(.primary)

                        Text("No plan created yet")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }

                // Create plan prompt
                Button {
                    showPlanSetupSheet = true
                } label: {
                    HStack(spacing: 12) {
                        TraiLensIcon(size: 26)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Create Personalized Plan")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(.primary)

                            Text("Let Trai design a training program for your goals")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding()
                    .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
            .padding(20)
            .traiCard(cornerRadius: 20, contentPadding: 0)
        }
    }

    // MARK: - Workout Plan Chip

    private func WorkoutPlanChip(template: WorkoutPlan.WorkoutTemplate) -> some View {
        let primaryColor = template.displayAccentColor

        return HStack(spacing: 6) {
            Image(systemName: template.sessionType.iconName)
                .font(.caption2)
                .foregroundStyle(primaryColor)

            Text(template.name)
                .font(.caption)
                .bold()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(primaryColor.opacity(0.15))
        .clipShape(.capsule)
    }

    func balancedMacroRows(for macros: [MacroType]) -> [[MacroType]] {
        if dynamicTypeSize.isAccessibilitySize { return macros.map { [$0] } }
        return switch macros.count {
        case 0...3:
            [macros]
        case 4:
            [Array(macros.prefix(2)), Array(macros.suffix(2))]
        case 5:
            [Array(macros.prefix(3)), Array(macros.suffix(2))]
        default:
            stride(from: 0, to: macros.count, by: 3).map { start in
                Array(macros[start..<min(start + 3, macros.count)])
            }
        }
    }

    // MARK: - Helpers

    private var planActionLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout(spacing: 12))
    }

    private func aiActionButtonLabel(isUnlocked: Bool, unlockedTitle: String) -> some View {
        HStack(spacing: 6) {
            TraiLensSymbolIcon(size: 14, variant: .enclosedFilled, color: Color.accentColor)
                .accessibilityHidden(true)
            Text(unlockedTitle)
                .font(.subheadline.weight(.medium))
                .fixedSize(horizontal: false, vertical: true)
            if !isUnlocked {
                Text("PRO")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 44)
    }

}
