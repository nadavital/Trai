//
//  WorkoutPlanSetupChoiceFlow.swift
//  Trai
//
//  Forked workout plan setup entry for Pro-generated and manual plans.
//

import SwiftUI

struct WorkoutPlanSetupChoiceFlow: View {
    @Binding var draft: OnboardingWorkoutPlanDraft
    @Binding var generatedPlanForReview: WorkoutPlan?
    @Binding var generatedPlanGoalsForReview: [WorkoutGoal]

    let context: OnboardingWorkoutPlanUserContext
    let existingWorkoutGoals: [WorkoutGoal]
    let aiService: AIService
    let canAccessAIFeatures: Bool
    let onComplete: (WorkoutPlan, [WorkoutGoal], WorkoutPlanSetupMode, OnboardingWorkoutPlanDraft) -> Void
    let onBack: () -> Void
    let onSkip: () -> Void

    @Environment(AccountSessionService.self) private var accountSessionService: AccountSessionService?
    @Environment(MonetizationService.self) private var monetizationService: MonetizationService?
    @State private var activeMode: WorkoutPlanSetupMode = .proAI
    @State private var hasResolvedProFork = false
    @State private var showingProFork = false
    @State private var shouldAdvanceAfterManualFork = false
    @State private var presentedAccountSetupContext: AccountSetupContext?

    var body: some View {
        OnboardingWorkoutPlanSetupView(
            draft: $draft,
            generatedPlanForReview: $generatedPlanForReview,
            generatedPlanGoalsForReview: $generatedPlanGoalsForReview,
            context: context,
            existingWorkoutGoals: existingWorkoutGoals,
            aiService: aiService,
            mode: activeMode,
            showsProForkBeforeReview: !hasResolvedProFork,
            canAccessAIFeatures: canUseAIGeneration,
            advancePastSetupAfterManualFork: shouldAdvanceAfterManualFork,
            onProForkRequired: presentProFork,
            onComplete: { plan, goals in
                onComplete(plan, goals, activeMode, draft)
            },
            onBack: onBack,
            onSkip: onSkip
        )
        .fullScreenCover(isPresented: $showingProFork, onDismiss: resolveProFork) {
            ProUpsellView(
                source: .workoutPlan,
                showsDismissButton: false,
                showsHeroCopy: false,
                modulesOverride: workoutPlanForkModules,
                secondaryActionTitle: "Continue manually",
                secondaryAction: continueManually
            )
                .traiSheetBranding()
        }
        .sheet(item: $presentedAccountSetupContext) { context in
            AccountSetupView(context: context)
                .traiSheetBranding()
        }
        .traiSheetBranding()
    }

    private var currentAIAccess: Bool {
        monetizationService?.canAccessAIFeatures ?? canAccessAIFeatures
    }

    private var canUseAIGeneration: Bool {
        if AppLaunchArguments.shouldRunOnboardingFlowUITest {
            return true
        }
        return currentAIAccess && accountSessionService?.isAuthenticated == true
    }

    private var workoutPlanForkModules: [ProUpsellModule] {
        [
            ProUpsellModule(
                id: "generated-plan",
                iconName: "sparkles",
                title: "Builds the plan",
                subtitle: "uses your answers"
            ),
            ProUpsellModule(
                id: "tracking-updates",
                iconName: "chart.line.uptrend.xyaxis",
                title: "Adapts as you train",
                subtitle: "updates from tracking"
            ),
            ProUpsellModule(
                id: "mid-workout-coach",
                iconName: "figure.strengthtraining.traditional",
                title: "Coaches mid-workout",
                subtitle: "advice in the moment"
            ),
            ProUpsellModule(
                id: "exercise-machine-ai",
                iconName: "camera.viewfinder",
                title: "Identifies exercises",
                subtitle: "machines and movements"
            )
        ]
    }

    private func presentProFork() {
        if currentAIAccess, accountSessionService?.isAuthenticated != true {
            presentedAccountSetupContext = .aiFeatures
            return
        }
        guard !currentAIAccess else {
            hasResolvedProFork = true
            activeMode = .proAI
            return
        }
        showingProFork = true
    }

    private func resolveProFork() {
        hasResolvedProFork = true
        if currentAIAccess {
            activeMode = .proAI
        } else {
            continueManually()
        }
    }

    private func continueManually() {
        hasResolvedProFork = true
        activeMode = .manual
        shouldAdvanceAfterManualFork = true
        if draft.schedule == .flexible {
            draft.schedule = .threeDays
        }
        if draft.preferredSplit == .letTraiDecide {
            draft.preferredSplit = .fullBody
        }
        showingProFork = false
    }
}

#Preview {
    WorkoutPlanSetupChoiceFlow(
        draft: .constant(OnboardingWorkoutPlanDraft()),
        generatedPlanForReview: .constant(nil),
        generatedPlanGoalsForReview: .constant([]),
        context: OnboardingWorkoutPlanUserContext(
            name: "Nadav",
            age: 30,
            gender: .notSpecified,
            goal: .recomposition,
            activityLevel: .moderate
        ),
        existingWorkoutGoals: [],
        aiService: AIService(),
        canAccessAIFeatures: false,
        onComplete: { _, _, _, _ in },
        onBack: {},
        onSkip: {}
    )
}
