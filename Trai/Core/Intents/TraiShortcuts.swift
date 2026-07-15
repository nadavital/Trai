//
//  TraiShortcuts.swift
//  Trai
//
//  AppShortcutsProvider for Siri and Shortcuts integration
//

import AppIntents

/// Provides App Shortcuts for Trai - these appear in Shortcuts app and Siri
struct TraiShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogFoodTextIntent(),
            phrases: [
                "Log food with \(.applicationName)",
                "Track food in \(.applicationName)",
                "Add food to \(.applicationName)"
            ],
            shortTitle: "Log Food",
            systemImageName: "fork.knife"
        )

        AppShortcut(
            intent: LogFoodCameraIntent(),
            phrases: [
                "Scan food with \(.applicationName)",
                "Take food photo with \(.applicationName)",
                "Log food photo with \(.applicationName)"
            ],
            shortTitle: "Scan Food",
            systemImageName: "camera.fill"
        )

        AppShortcut(
            intent: LogWeightIntent(),
            phrases: [
                "Log my weight with \(.applicationName)",
                "Record weight in \(.applicationName)",
                "Track my weight with \(.applicationName)"
            ],
            shortTitle: "Log Weight",
            systemImageName: "scalemass.fill"
        )

        AppShortcut(
            intent: AskTraiIntent(),
            phrases: [
                "Ask \(.applicationName)",
                "Talk to \(.applicationName)",
                "Hey \(.applicationName)"
            ],
            shortTitle: "Ask Trai",
            systemImageName: "circle.hexagongrid.circle"
        )

        AppShortcut(
            intent: StartWorkoutIntent(),
            phrases: [
                "Start a workout with \(.applicationName)",
                "Begin workout in \(.applicationName)",
                "Start exercise with \(.applicationName)"
            ],
            shortTitle: "Start Workout",
            systemImageName: "figure.run"
        )

        AppShortcut(
            intent: GetDailySummaryIntent(),
            phrases: [
                "Get my daily summary from \(.applicationName)",
                "How am I doing in \(.applicationName)",
                "Show my progress in \(.applicationName)"
            ],
            shortTitle: "Daily Summary",
            systemImageName: "chart.bar.fill"
        )

        AppShortcut(
            intent: GetNutritionProgressIntent(),
            phrases: [
                "Check my nutrition in \(.applicationName)",
                "Get my calorie progress from \(.applicationName)",
                "Get my protein progress from \(.applicationName)"
            ],
            shortTitle: "Nutrition Progress",
            systemImageName: "chart.pie.fill"
        )

        AppShortcut(
            intent: GetLatestWorkoutSummaryIntent(),
            phrases: [
                "Get my latest workout from \(.applicationName)",
                "Summarize my last workout with \(.applicationName)",
                "Show my last workout in \(.applicationName)"
            ],
            shortTitle: "Latest Workout",
            systemImageName: "figure.strengthtraining.traditional"
        )
    }
}
