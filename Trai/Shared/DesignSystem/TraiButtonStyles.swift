//
//  TraiButtonStyles.swift
//  Trai
//
//  Three-tier button hierarchy: Primary, Secondary, Tertiary.
//

import SwiftUI

// MARK: - Shared Button Tokens

private let traiDefaultAccentColor = Color("AccentColor")

enum TraiButtonSize {
    case compact
    case regular
    case large

    var font: Font {
        switch self {
        case .compact: .traiLabel(13)
        case .regular: .traiHeadline(16)
        case .large: .traiHeadline(17)
        }
    }

    var horizontalPadding: CGFloat {
        switch self {
        case .compact: 12
        case .regular: 16
        case .large: 18
        }
    }

    var verticalPadding: CGFloat {
        switch self {
        case .compact: 8
        case .regular: 11
        case .large: 13
        }
    }

    var minimumHeight: CGFloat {
        switch self {
        case .compact: 32
        case .regular: 40
        case .large: 46
        }
    }
}

// MARK: - Primary Button Style

/// Vibrant filled CTA style (pill).
struct TraiPrimaryButtonStyle: ButtonStyle {
    var color: Color = traiDefaultAccentColor
    var size: TraiButtonSize = .regular
    var fullWidth: Bool = false
    var width: CGFloat? = nil
    var height: CGFloat? = nil
    var foregroundColor: Color = .white
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let maxWidth: CGFloat? = (fullWidth && width == nil) ? .infinity : nil

        configuration.label
            .font(size.font)
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, size.horizontalPadding)
            .padding(.vertical, size.verticalPadding)
            .frame(
                width: width,
                height: height
            )
            .frame(
                maxWidth: maxWidth,
                minHeight: height == nil ? size.minimumHeight : nil
            )
            .background(color)
            .clipShape(.capsule)
            .shadow(
                color: color.opacity(configuration.isPressed ? 0.10 : 0.25),
                radius: configuration.isPressed ? 2 : 8,
                y: configuration.isPressed ? 1 : 4
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(isEnabled ? 1 : 0.55)
            .animation(TraiAnimation.quick, value: configuration.isPressed)
            .animation(TraiAnimation.quick, value: isEnabled)
    }
}

// MARK: - Secondary Button Style

/// Muted colored fill style (pill). Use for secondary actions.
struct TraiSecondaryButtonStyle: ButtonStyle {
    var color: Color = traiDefaultAccentColor
    var size: TraiButtonSize = .regular
    var fullWidth: Bool = false
    var width: CGFloat? = nil
    var height: CGFloat? = nil
    var fillOpacity: Double = 0.14
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let maxWidth: CGFloat? = (fullWidth && width == nil) ? .infinity : nil
        let resolvedOpacity = configuration.isPressed
            ? min(fillOpacity + 0.07, 0.30)
            : fillOpacity

        configuration.label
            .font(size.font)
            .foregroundStyle(color)
            .padding(.horizontal, size.horizontalPadding)
            .padding(.vertical, size.verticalPadding)
            .frame(
                width: width,
                height: height
            )
            .frame(
                maxWidth: maxWidth,
                minHeight: height == nil ? size.minimumHeight : nil
            )
            .background(color.opacity(resolvedOpacity))
            .clipShape(.capsule)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(isEnabled ? 1 : 0.55)
            .animation(TraiAnimation.quick, value: configuration.isPressed)
            .animation(TraiAnimation.quick, value: isEnabled)
    }
}

// MARK: - Tertiary Button Style

/// Neutral outlined style (pill). Use as tertiary.
struct TraiTertiaryButtonStyle: ButtonStyle {
    var color: Color = traiDefaultAccentColor
    var size: TraiButtonSize = .regular
    var fullWidth: Bool = false
    var width: CGFloat? = nil
    var height: CGFloat? = nil
    var backgroundColor: Color = Color(.tertiarySystemFill)
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let maxWidth: CGFloat? = (fullWidth && width == nil) ? .infinity : nil

        configuration.label
            .font(size.font)
            .foregroundStyle(color)
            .padding(.horizontal, size.horizontalPadding)
            .padding(.vertical, size.verticalPadding)
            .frame(
                width: width,
                height: height
            )
            .frame(
                maxWidth: maxWidth,
                minHeight: height == nil ? size.minimumHeight : nil
            )
            .background(
                backgroundColor.opacity(configuration.isPressed ? 0.85 : 1.0),
                in: .capsule
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(isEnabled ? 1 : 0.55)
            .animation(TraiAnimation.quick, value: configuration.isPressed)
            .animation(TraiAnimation.quick, value: isEnabled)
    }
}

// MARK: - Pill Button Styles

/// Backward-compatible alias for primary style.
struct TraiPillProminentButtonStyle: ButtonStyle {
    var color: Color = traiDefaultAccentColor
    var size: TraiButtonSize = .regular
    var fullWidth: Bool = false
    var width: CGFloat? = nil
    var height: CGFloat? = nil
    var foregroundColor: Color = .white

    func makeBody(configuration: Configuration) -> some View {
        TraiPrimaryButtonStyle(
            color: color,
            size: size,
            fullWidth: fullWidth,
            width: width,
            height: height,
            foregroundColor: foregroundColor
        ).makeBody(configuration: configuration)
    }
}

/// Backward-compatible alias for secondary style.
struct TraiPillSubtleButtonStyle: ButtonStyle {
    var color: Color = traiDefaultAccentColor
    var size: TraiButtonSize = .regular
    var fullWidth: Bool = false
    var width: CGFloat? = nil
    var height: CGFloat? = nil
    var fillOpacity: Double = 0.12

    func makeBody(configuration: Configuration) -> some View {
        TraiSecondaryButtonStyle(
            color: color,
            size: size,
            fullWidth: fullWidth,
            width: width,
            height: height,
            fillOpacity: fillOpacity
        ).makeBody(configuration: configuration)
    }
}

// MARK: - Convenience Extensions

extension ButtonStyle where Self == TraiPrimaryButtonStyle {
    static var traiPrimary: TraiPrimaryButtonStyle { TraiPrimaryButtonStyle() }

    static func traiPrimary(
        color: Color = traiDefaultAccentColor,
        size: TraiButtonSize = .regular,
        fullWidth: Bool = false,
        width: CGFloat? = nil,
        height: CGFloat? = nil
    ) -> TraiPrimaryButtonStyle {
        TraiPrimaryButtonStyle(
            color: color,
            size: size,
            fullWidth: fullWidth,
            width: width,
            height: height
        )
    }
}

extension ButtonStyle where Self == TraiSecondaryButtonStyle {
    static var traiSecondary: TraiSecondaryButtonStyle { TraiSecondaryButtonStyle() }

    static func traiSecondary(
        color: Color = traiDefaultAccentColor,
        size: TraiButtonSize = .regular,
        fullWidth: Bool = false,
        width: CGFloat? = nil,
        height: CGFloat? = nil,
        fillOpacity: Double = 0.14
    ) -> TraiSecondaryButtonStyle {
        TraiSecondaryButtonStyle(
            color: color,
            size: size,
            fullWidth: fullWidth,
            width: width,
            height: height,
            fillOpacity: fillOpacity
        )
    }
}

extension ButtonStyle where Self == TraiTertiaryButtonStyle {
    static var traiTertiary: TraiTertiaryButtonStyle {
        TraiTertiaryButtonStyle()
    }

    static func traiTertiary(
        color: Color = traiDefaultAccentColor,
        size: TraiButtonSize = .regular,
        fullWidth: Bool = false,
        width: CGFloat? = nil,
        height: CGFloat? = nil,
        backgroundColor: Color = Color(.tertiarySystemFill)
    ) -> TraiTertiaryButtonStyle {
        TraiTertiaryButtonStyle(
            color: color,
            size: size,
            fullWidth: fullWidth,
            width: width,
            height: height,
            backgroundColor: backgroundColor
        )
    }
}

extension ButtonStyle where Self == TraiPillProminentButtonStyle {
    static var traiPillProminent: TraiPillProminentButtonStyle { TraiPillProminentButtonStyle() }

    static func traiPillProminent(
        color: Color = traiDefaultAccentColor,
        size: TraiButtonSize = .regular,
        fullWidth: Bool = false,
        width: CGFloat? = nil,
        height: CGFloat? = nil
    ) -> TraiPillProminentButtonStyle {
        TraiPillProminentButtonStyle(
            color: color,
            size: size,
            fullWidth: fullWidth,
            width: width,
            height: height
        )
    }
}

extension ButtonStyle where Self == TraiPillSubtleButtonStyle {
    static var traiPillSubtle: TraiPillSubtleButtonStyle { TraiPillSubtleButtonStyle() }

    static func traiPillSubtle(
        color: Color = traiDefaultAccentColor,
        size: TraiButtonSize = .regular,
        fullWidth: Bool = false,
        width: CGFloat? = nil,
        height: CGFloat? = nil,
        fillOpacity: Double = 0.14
    ) -> TraiPillSubtleButtonStyle {
        TraiPillSubtleButtonStyle(
            color: color,
            size: size,
            fullWidth: fullWidth,
            width: width,
            height: height,
            fillOpacity: fillOpacity
        )
    }
}
