//
//  ProUpsellContent.swift
//  Trai
//
//  Shared Trai Pro offer content and visual components.
//

import SwiftUI

struct ProUpsellModule: Identifiable, Equatable {
    let id: String
    let iconName: String
    let title: String
    let subtitle: String
}

struct ProUpsellContent: Equatable {
    let headline: String
    let tagline: String
    let modules: [ProUpsellModule]
    let inlineTitle: String
    let inlineMessage: String
    let inlineIconName: String
}

extension ProUpsellSource {
    var offerContent: ProUpsellContent {
        let fitnessPlan = ProUpsellModule(
            id: "fitness-plan",
            iconName: "figure.strengthtraining.traditional",
            title: "Adaptive workout coaching",
            subtitle: "reviews, tweaks, progression"
        )
        let nutritionPlan = ProUpsellModule(
            id: "nutrition-plan",
            iconName: "target",
            title: "Targets that adapt",
            subtitle: "calories + macros"
        )
        let coachSuggestions = ProUpsellModule(
            id: "coach-suggestions",
            iconName: "sparkles",
            title: "Next-step coaching",
            subtitle: "nudges from your logs"
        )
        let photoLogging = ProUpsellModule(
            id: "photo-logging",
            iconName: "camera.viewfinder",
            title: "Snap meals to log",
            subtitle: "calories + macros estimated"
        )

        switch self {
        case .chat:
            return ProUpsellContent(
                headline: "Unlock full coach mode",
                tagline: "Ask Trai to plan, log, and adjust with you.",
                modules: [coachSuggestions, nutritionPlan, fitnessPlan, photoLogging],
                inlineTitle: "Unlock coach chat",
                inlineMessage: "Talk with Trai about food, workouts, momentum, and next steps in one ongoing conversation.",
                inlineIconName: "message.badge.waveform.fill"
            )
        case .foodAnalysis:
            return ProUpsellContent(
                headline: "Log meals faster",
                tagline: "Snap a meal, get calories and macros fast.",
                modules: [photoLogging, nutritionPlan, coachSuggestions, fitnessPlan],
                inlineTitle: "Unlock Trai food logging",
                inlineMessage: "Snap meals and get fast calorie and macro estimates when you want the quickest path to logging.",
                inlineIconName: "fork.knife"
            )
        case .nutritionPlan:
            return ProUpsellContent(
                headline: "Make nutrition adaptive",
                tagline: "Plans that adjust as you log, train, and make progress.",
                modules: [nutritionPlan, photoLogging, coachSuggestions, fitnessPlan],
                inlineTitle: "Unlock Trai plan coaching",
                inlineMessage: "Have Trai build and refine your nutrition plan around your goals, routine, and progress.",
                inlineIconName: "slider.horizontal.3"
            )
        case .workoutPlan:
            return ProUpsellContent(
                headline: "Keep your training moving",
                tagline: "Trai reviews your workouts, adjusts the plan, and keeps the next step clear.",
                modules: [fitnessPlan, coachSuggestions, nutritionPlan, photoLogging],
                inlineTitle: "Unlock workout coaching",
                inlineMessage: "Your workout plan is included. Upgrade when you want Trai to review progress, adjust your week, and keep coaching over time.",
                inlineIconName: "figure.strengthtraining.traditional"
            )
        case .workoutReview:
            return ProUpsellContent(
                headline: "Review workouts with Trai",
                tagline: "Turn a completed session into clear feedback and a smarter next workout.",
                modules: [coachSuggestions, fitnessPlan, nutritionPlan, photoLogging],
                inlineTitle: "Unlock workout reviews",
                inlineMessage: "Have Trai review completed workouts, spot useful patterns, and suggest the next adjustment.",
                inlineIconName: "bubble.left.and.text.bubble.right.fill"
            )
        case .exerciseAnalysis:
            return ProUpsellContent(
                headline: "Get smarter exercise help",
                tagline: "Get smarter exercise guidance inside your plan.",
                modules: [coachSuggestions, fitnessPlan, nutritionPlan, photoLogging],
                inlineTitle: "Unlock exercise analysis",
                inlineMessage: "Get instant exercise guidance, smarter setup help, and faster analysis when adding new movements.",
                inlineIconName: "dumbbell.fill"
            )
        case .reminders:
            return ProUpsellContent(
                headline: "Let Trai remember with you",
                tagline: "Ask for the nudge you want and Trai drafts the reminder.",
                modules: [coachSuggestions, nutritionPlan, fitnessPlan, photoLogging],
                inlineTitle: "Unlock AI reminder setup",
                inlineMessage: "Tell Trai what you want to remember and it will draft the title, timing, and repeat days for you.",
                inlineIconName: "bell.badge.fill"
            )
        case .settings:
            return ProUpsellContent(
                headline: "Upgrade to Trai Pro",
                tagline: "AI planning, logging, and coaching.",
                modules: [fitnessPlan, nutritionPlan, coachSuggestions, photoLogging],
                inlineTitle: "Upgrade to Trai Pro",
                inlineMessage: "Unlock adaptive coaching, faster food logging, and personalized plans across the app.",
                inlineIconName: "circle.hexagongrid.circle"
            )
        }
    }
}

struct TraiProGradientBackground: View {
    var body: some View {
        ZStack {
            TraiColors.brandGradient

            LinearGradient(
                colors: [
                    .white.opacity(0.26),
                    .white.opacity(0.08),
                    .black.opacity(0.18)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }
}

struct TraiProWordmark: View {
    var body: some View {
        HStack(spacing: 10) {
            TraiLensSymbolIcon(size: 28, variant: .enclosedFilled, color: .white)

            Text("Trai Pro")
                .font(.traiBold(36))
        }
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(0.14), radius: 14, y: 8)
    }
}

struct TraiProValueList: View {
    let modules: [ProUpsellModule]

    var body: some View {
        VStack(spacing: 8) {
            ForEach(modules) { module in
                TraiProModuleTile(module: module)
            }
        }
    }
}

struct TraiProModuleTile: View {
    let module: ProUpsellModule

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: module.iconName)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 36, height: 36)
                .background(Color.accentColor.opacity(0.10), in: .rect(cornerRadius: 10))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(module.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(module.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 18))
    }
}
