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

/// A generous, matte action target with a semantic accent.
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
                ? AnyLayout(HStackLayout(spacing: 12))
                : AnyLayout(VStackLayout(spacing: 10))
            layout {
                Image(systemName: icon)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(color)
                    .frame(width: 30, height: 30)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, minHeight: 60)
            .padding(.horizontal, 8)
            .padding(.vertical, 12)
            .background {
                RoundedRectangle(cornerRadius: TraiRadius.medium)
                    .fill(Color(.secondarySystemGroupedBackground))
                    .overlay {
                        RoundedRectangle(cornerRadius: TraiRadius.medium)
                            .fill(color.opacity(0.10))
                    }
            }
            .contentShape(.rect(cornerRadius: TraiRadius.medium))
        }
        .buttonStyle(TraiPressStyle(scale: 0.97))
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

// MARK: - Date Navigation Bar

struct DateNavigationBar: View {
    @Binding var selectedDate: Date
    let isToday: Bool

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
        HStack {
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
            .accessibilityIdentifier("dashboardDatePreviousButton")

            Spacer()

            VStack(spacing: 2) {
                Text(dateText)
                    .font(.headline)
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

            Spacer()

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
            .accessibilityIdentifier("dashboardDateNextButton")
            .disabled(isToday)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}
