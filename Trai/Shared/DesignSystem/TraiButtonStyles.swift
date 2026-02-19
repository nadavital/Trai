//
//  TraiButtonStyles.swift
//  Trai
//
//  Three-tier button hierarchy: Primary, Secondary, Tertiary.
//

import SwiftUI

// MARK: - Primary Button Style

/// Solid accent fill, white text, press-scale + shadow lift + haptic.
/// For: "Start Workout", "Save", "Log Food", "Confirm"
struct TraiPrimaryButtonStyle: ButtonStyle {
    var cornerRadius: CGFloat = TraiRadius.medium

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.traiHeadline())
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.accentColor)
            .clipShape(.rect(cornerRadius: cornerRadius))
            .shadow(
                color: Color.accentColor.opacity(configuration.isPressed ? 0.05 : 0.25),
                radius: configuration.isPressed ? 2 : 8,
                y: configuration.isPressed ? 1 : 4
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(TraiAnimation.quick, value: configuration.isPressed)
    }
}

// MARK: - Secondary Button Style

/// Tinted background (accent 12% opacity), accent text, press-scale.
/// For: "Review", "View All", "Add Exercise", "Retake"
struct TraiSecondaryButtonStyle: ButtonStyle {
    var color: Color = .accentColor

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.traiHeadline())
            .foregroundStyle(color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(color.opacity(0.12))
            .clipShape(.rect(cornerRadius: TraiRadius.medium))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(TraiAnimation.quick, value: configuration.isPressed)
    }
}

// MARK: - Tertiary Button Style

/// No background, accent text, press-scale.
/// For: "Cancel", "Skip", inline actions
struct TraiTertiaryButtonStyle: ButtonStyle {
    var color: Color = .accentColor

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.traiHeadline())
            .foregroundStyle(color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.6 : 1)
            .animation(TraiAnimation.quick, value: configuration.isPressed)
    }
}

// MARK: - Pill Button Styles

/// Prominent capsule action style for primary confirmations.
struct TraiPillProminentButtonStyle: ButtonStyle {
    var color: Color = .accentColor
    var foregroundColor: Color = .white
    var horizontalPadding: CGFloat = 16
    var verticalPadding: CGFloat = 10
    var pressedScale: CGFloat = 0.97
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(color)
            .clipShape(.capsule)
            .scaleEffect(configuration.isPressed ? pressedScale : 1)
            .opacity(isEnabled ? 1 : 0.55)
            .animation(TraiAnimation.quick, value: configuration.isPressed)
            .animation(TraiAnimation.quick, value: isEnabled)
    }
}

/// Subtle capsule action style for secondary actions.
struct TraiPillSubtleButtonStyle: ButtonStyle {
    var color: Color = .accentColor
    var fillOpacity: Double = 0.12
    var horizontalPadding: CGFloat = 16
    var verticalPadding: CGFloat = 10
    var pressedScale: CGFloat = 0.97
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let backgroundOpacity = configuration.isPressed ? min(fillOpacity + 0.06, 0.30) : fillOpacity

        return configuration.label
            .foregroundStyle(color)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(color.opacity(backgroundOpacity))
            .clipShape(.capsule)
            .scaleEffect(configuration.isPressed ? pressedScale : 1)
            .opacity(isEnabled ? 1 : 0.55)
            .animation(TraiAnimation.quick, value: configuration.isPressed)
            .animation(TraiAnimation.quick, value: isEnabled)
    }
}

// MARK: - Convenience Extensions

extension ButtonStyle where Self == TraiPrimaryButtonStyle {
    static var traiPrimary: TraiPrimaryButtonStyle { TraiPrimaryButtonStyle() }
}

extension ButtonStyle where Self == TraiSecondaryButtonStyle {
    static var traiSecondary: TraiSecondaryButtonStyle { TraiSecondaryButtonStyle() }

    static func traiSecondary(color: Color) -> TraiSecondaryButtonStyle {
        TraiSecondaryButtonStyle(color: color)
    }
}

extension ButtonStyle where Self == TraiTertiaryButtonStyle {
    static var traiTertiary: TraiTertiaryButtonStyle { TraiTertiaryButtonStyle() }

    static func traiTertiary(color: Color) -> TraiTertiaryButtonStyle {
        TraiTertiaryButtonStyle(color: color)
    }
}

extension ButtonStyle where Self == TraiPillProminentButtonStyle {
    static var traiPillProminent: TraiPillProminentButtonStyle { TraiPillProminentButtonStyle() }

    static func traiPillProminent(color: Color) -> TraiPillProminentButtonStyle {
        TraiPillProminentButtonStyle(color: color)
    }
}

extension ButtonStyle where Self == TraiPillSubtleButtonStyle {
    static var traiPillSubtle: TraiPillSubtleButtonStyle { TraiPillSubtleButtonStyle() }

    static func traiPillSubtle(color: Color) -> TraiPillSubtleButtonStyle {
        TraiPillSubtleButtonStyle(color: color)
    }
}
