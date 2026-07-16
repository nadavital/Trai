//
//  DashboardHelperComponents.swift
//  Trai
//
//  Helper components for dashboard cards
//

import SwiftUI

// MARK: - Macro Ring Item

struct MacroRingItem: View {
    let name: String
    var compactLabel: String? = nil
    let current: Double
    let goal: Double
    let color: Color
    var diameter: CGFloat = 60
    var prefersCompactLabel: Bool = false

    @State private var animatedProgress: Double = 0

    private var progress: Double {
        guard goal > 0 else { return 0 }
        return min(current / goal, 1.0)
    }

    private var labelText: String {
        if prefersCompactLabel, let compactLabel, !compactLabel.isEmpty {
            return compactLabel
        }
        return name
    }

    var body: some View {
        VStack(spacing: TraiSpacing.sm) {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.15), lineWidth: 5)

                Circle()
                    .trim(from: 0, to: animatedProgress)
                    .stroke(
                        TraiGradient.ring(color),
                        style: StrokeStyle(lineWidth: 5, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .shadow(color: color.opacity(0.3), radius: 3, y: 1)

                Text("\(Int(current))g")
                    .font(.traiLabel(diameter < 54 ? 11 : 12))
                    .bold()
            }
            .frame(width: diameter, height: diameter)

            Text(labelText)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(prefersCompactLabel ? 0.9 : 0.7)
        }
        .onAppear {
            withAnimation(TraiAnimation.bouncy) {
                animatedProgress = progress
            }
        }
        .onChange(of: progress) { _, newValue in
            withAnimation(TraiAnimation.bouncy) {
                animatedProgress = newValue
            }
        }
    }
}

// MARK: - Quick Action Button

struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Button {
            HapticManager.lightTap()
            action()
        } label: {
            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(HStackLayout(spacing: TraiSpacing.md))
                : AnyLayout(VStackLayout(spacing: TraiSpacing.sm))
            layout {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.78))
                        .frame(width: 40, height: 40)

                    Image(systemName: icon)
                        .font(.body)
                        .bold()
                        .foregroundStyle(.white)
                }

                Text(title)
                    .font(.traiLabel())
                    .foregroundStyle(color)
                    .multilineTextAlignment(.leading)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                    .minimumScaleFactor(dynamicTypeSize.isAccessibilitySize ? 1 : 0.8)

                if dynamicTypeSize.isAccessibilitySize {
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .foregroundStyle(color)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 44)
            .padding(.horizontal, dynamicTypeSize.isAccessibilitySize ? 14 : 8)
            .padding(.vertical, 14)
            .glassEffect(
                .regular.tint(color.opacity(0.28)).interactive(),
                in: .rect(cornerRadius: TraiRadius.medium)
            )
            .overlay {
                RoundedRectangle(cornerRadius: TraiRadius.medium, style: .continuous)
                    .strokeBorder(.white.opacity(0.18), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.03), radius: 5, y: 3)
        }
        .buttonStyle(TraiPressStyle(scale: 0.93))
    }
}

struct ShortcutChipButton: View {
    let title: String
    let icon: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button {
            HapticManager.lightTap()
            action()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.traiLabel(12))
                Text(title)
                    .font(.traiLabel(12))
                    .lineLimit(1)
            }
            .foregroundStyle(tint)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(tint.opacity(0.12), in: Capsule())
        }
        .buttonStyle(TraiPressStyle(scale: 0.96))
    }
}

struct ChatWithTraiCard: View {
    let isUnlocked: Bool
    let action: () -> Void

    var body: some View {
        Button {
            HapticManager.lightTap()
            action()
        } label: {
            HStack(spacing: TraiSpacing.sm) {
                TraiLensSymbolIcon(size: 30, variant: .enclosedFilled, color: Color.accentColor)
                    .frame(width: 30, height: 30)

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 6) {
                        Text("Chat with Trai")
                            .font(.traiHeadline(14))
                            .foregroundStyle(Color.accentColor)

                        if !isUnlocked {
                            Text("PRO")
                                .font(.traiLabel(10))
                                .foregroundStyle(TraiColors.ember)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(TraiColors.ember.opacity(0.10), in: Capsule())
                        }
                    }

                    HStack(spacing: 6) {
                        Text("Chat")
                            .font(.traiHeadline(14))
                            .foregroundStyle(Color.accentColor)

                        if !isUnlocked {
                            Text("PRO")
                                .font(.traiLabel(10))
                                .foregroundStyle(TraiColors.ember)
                        }
                    }
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .glassEffect(
                .regular.tint(Color.accentColor.opacity(0.20)).interactive(),
                in: .capsule
            )
            .overlay {
                Capsule()
                    .strokeBorder(.white.opacity(0.18), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.03), radius: 5, y: 3)
        }
        .buttonStyle(TraiPressStyle(scale: 0.96))
    }
}

// MARK: - Date Navigation Bar

struct DateNavigationBar: View {
    @Binding var selectedDate: Date
    let isToday: Bool
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private let calendar = Calendar.current

    private var dateText: String {
        if isToday {
            return "Today"
        }

        let formatter = DateFormatter()
        if calendar.isDate(selectedDate, equalTo: Date(), toGranularity: .year) {
            formatter.dateFormat = "EEEE, MMM d"
        } else {
            formatter.dateFormat = "EEEE, MMM d, yyyy"
        }
        return formatter.string(from: selectedDate)
    }

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: TraiSpacing.xs) {
                    dateLabel
                    HStack {
                        previousButton
                        Spacer()
                        nextButton
                    }
                }
            } else {
                HStack {
                    previousButton
                    Spacer()
                    dateLabel
                    Spacer()
                    nextButton
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var previousButton: some View {
        Button {
            withAnimation {
                selectedDate = calendar.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
            }
            HapticManager.lightTap()
        } label: {
            Image(systemName: "chevron.left")
                .font(.title3)
                .foregroundStyle(.primary)
                .frame(width: 44, height: 44)
        }
        .accessibilityLabel("Previous day")
        .accessibilityIdentifier("dashboardDatePreviousButton")
    }

    private var dateLabel: some View {
        VStack(spacing: 2) {
            Text(dateText)
                .font(.headline)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("dashboardDateLabel")

            if !isToday {
                Button {
                    withAnimation {
                        selectedDate = Date()
                    }
                    HapticManager.lightTap()
                } label: {
                    Text("Jump to Today")
                        .font(.caption)
                        .foregroundStyle(.accent)
                }
                .accessibilityIdentifier("dashboardJumpToTodayButton")
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var nextButton: some View {
        Button {
            withAnimation {
                selectedDate = calendar.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
            }
            HapticManager.lightTap()
        } label: {
            Image(systemName: "chevron.right")
                .font(.title3)
                .foregroundStyle(isToday ? .tertiary : .primary)
                .frame(width: 44, height: 44)
        }
        .accessibilityLabel("Next day")
        .accessibilityIdentifier("dashboardDateNextButton")
        .disabled(isToday)
    }
}
