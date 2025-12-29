//
//  HapticManager.swift
//  Plates
//

import SwiftUI

/// Centralized haptic feedback manager for consistent tactile responses
@MainActor
enum HapticManager {

    // MARK: - Impact Haptics

    /// Light tap - for subtle selections
    static func lightTap() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }

    /// Medium tap - for button presses and confirmations
    static func mediumTap() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }

    /// Heavy tap - for important actions
    static func heavyTap() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
    }

    /// Soft tap - for gentle feedback
    static func softTap() {
        let generator = UIImpactFeedbackGenerator(style: .soft)
        generator.impactOccurred()
    }

    /// Rigid tap - for precise feedback
    static func rigidTap() {
        let generator = UIImpactFeedbackGenerator(style: .rigid)
        generator.impactOccurred()
    }

    // MARK: - Notification Haptics

    /// Success - task completed successfully
    static func success() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    /// Warning - attention needed
    static func warning() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
    }

    /// Error - something went wrong
    static func error() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
    }

    // MARK: - Selection Haptics

    /// Selection changed - for pickers, toggles, selections
    static func selectionChanged() {
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }

    // MARK: - Onboarding-Specific Patterns

    /// Step completed - celebratory feedback for onboarding progress
    static func stepCompleted() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    /// Card selected - feedback when selecting an option card
    static func cardSelected() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred(intensity: 0.7)
    }

    /// Toggle switched - for unit toggles, dietary restrictions
    static func toggleSwitched() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred(intensity: 0.5)
    }

    /// Plan ready - celebratory pattern when AI plan is generated
    static func planReady() {
        Task {
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)

            try? await Task.sleep(for: .milliseconds(150))

            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred(intensity: 0.6)
        }
    }

    /// Error shake - feedback for validation errors
    static func errorShake() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
    }
}
