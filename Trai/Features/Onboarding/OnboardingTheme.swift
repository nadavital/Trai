//
//  OnboardingTheme.swift
//  Trai
//
//  Shared design system for onboarding screens
//

import SwiftUI

// MARK: - Gradients

enum OnboardingGradient {
    static let primary = LinearGradient(
        colors: [Color.accentColor, Color.accentColor.opacity(0.7)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let background = LinearGradient(
        colors: [
            Color(.systemBackground),
            Color.accentColor.opacity(0.05)
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    static let card = LinearGradient(
        colors: [
            Color(.secondarySystemBackground),
            Color(.secondarySystemBackground).opacity(0.8)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - Animated Background

struct AnimatedGradientBackground: View {
    @State private var animateGradient = false

    var body: some View {
        LinearGradient(
            colors: [
                Color.accentColor.opacity(0.1),
                Color.purple.opacity(0.05),
                Color.accentColor.opacity(0.08)
            ],
            startPoint: animateGradient ? .topLeading : .bottomLeading,
            endPoint: animateGradient ? .bottomTrailing : .topTrailing
        )
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 5).repeatForever(autoreverses: true)) {
                animateGradient.toggle()
            }
        }
    }
}

// MARK: - Section Header

struct OnboardingSectionHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 12) {
            Text(title)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)

            Text(subtitle)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}

// MARK: - Glass Card

struct GlassCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(.rect(cornerRadius: 20))
            .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
    }
}

// MARK: - Primary Button Style

struct OnboardingPrimaryButtonStyle: ButtonStyle {
    let isEnabled: Bool

    init(isEnabled: Bool = true) {
        self.isEnabled = isEnabled
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                Group {
                    if isEnabled {
                        LinearGradient(
                            colors: [Color.accentColor, Color.accentColor.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    } else {
                        Color.gray.opacity(0.3)
                    }
                }
            )
            .clipShape(.rect(cornerRadius: 16))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.3), value: configuration.isPressed)
    }
}

// MARK: - Secondary Button Style

struct OnboardingSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(.ultraThinMaterial)
            .clipShape(.rect(cornerRadius: 16))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.3), value: configuration.isPressed)
    }
}

// MARK: - Selection Card

struct SelectionCard<Content: View>: View {
    let isSelected: Bool
    let content: Content
    let action: () -> Void

    init(isSelected: Bool, action: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.isSelected = isSelected
        self.action = action
        self.content = content()
    }

    var body: some View {
        Button(action: action) {
            content
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    Group {
                        if isSelected {
                            LinearGradient(
                                colors: [Color.accentColor, Color.accentColor.opacity(0.85)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        } else {
                            Color(.secondarySystemBackground)
                        }
                    }
                )
                .clipShape(.rect(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(
                            isSelected ? Color.clear : Color.gray.opacity(0.2),
                            lineWidth: 1
                        )
                )
                .shadow(
                    color: isSelected ? Color.accentColor.opacity(0.3) : .clear,
                    radius: 8,
                    y: 4
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Animated Icon

struct AnimatedIcon: View {
    let systemName: String
    let size: CGFloat
    @State private var isAnimating = false

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size, weight: .medium))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(.tint)
            .scaleEffect(isAnimating ? 1.05 : 1)
            .onAppear {
                withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                    isAnimating = true
                }
            }
    }
}

// MARK: - Progress Dots

struct OnboardingProgressDots: View {
    let currentStep: Int
    let totalSteps: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalSteps, id: \.self) { step in
                Capsule()
                    .fill(step <= currentStep ? Color.accentColor : Color.gray.opacity(0.3))
                    .frame(width: step == currentStep ? 24 : 8, height: 8)
                    .animation(.spring(response: 0.4), value: currentStep)
            }
        }
    }
}

// MARK: - Floating Elements (decorative)

struct FloatingElement: View {
    let delay: Double
    @State private var offset: CGFloat = 0

    var body: some View {
        Circle()
            .fill(Color.accentColor.opacity(0.1))
            .frame(width: 100, height: 100)
            .blur(radius: 30)
            .offset(y: offset)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 3)
                    .repeatForever(autoreverses: true)
                    .delay(delay)
                ) {
                    offset = 20
                }
            }
    }
}

// MARK: - Input Field Style

struct OnboardingTextField: View {
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        TextField(placeholder, text: $text)
            .font(.body)
            .padding()
            .background(Color(.tertiarySystemBackground))
            .clipShape(.rect(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.gray.opacity(0.2), lineWidth: 1)
            )
            .keyboardType(keyboardType)
    }
}

// MARK: - Chip/Tag Style

struct OnboardingChip: View {
    let title: String
    let icon: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon {
                    Image(systemName: icon)
                        .font(.caption)
                }
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(isSelected ? Color.accentColor : Color(.tertiarySystemBackground))
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(.capsule)
            .overlay(
                Capsule()
                    .strokeBorder(
                        isSelected ? Color.clear : Color.gray.opacity(0.3),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - View Extensions

extension View {
    func onboardingCard() -> some View {
        self
            .padding()
            .background(Color(.secondarySystemBackground))
            .clipShape(.rect(cornerRadius: 20))
    }

    func appearAnimation(delay: Double = 0) -> some View {
        self
            .modifier(AppearAnimationModifier(delay: delay))
    }
}

struct AppearAnimationModifier: ViewModifier {
    let delay: Double
    @State private var isVisible = false

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 20)
            .onAppear {
                withAnimation(.spring(response: 0.6).delay(delay)) {
                    isVisible = true
                }
            }
    }
}
