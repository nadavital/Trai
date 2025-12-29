//
//  BiometricsStepView.swift
//  Plates
//

import SwiftUI

struct BiometricsStepView: View {
    @Binding var dateOfBirth: Date
    @Binding var gender: UserProfile.Gender?
    @Binding var heightValue: String
    @Binding var weightValue: String
    @Binding var targetWeightValue: String
    @Binding var usesMetricHeight: Bool
    @Binding var usesMetricWeight: Bool

    @State private var heightFeet: String = ""
    @State private var heightInches: String = ""

    // Staggered animation states
    @State private var headerVisible = false
    @State private var card1Visible = false
    @State private var card2Visible = false
    @State private var card3Visible = false
    @State private var card4Visible = false

    // Track focused card for keyboard scrolling
    @State private var focusedCard: String?

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                        .padding(.top, 16)

                    VStack(spacing: 18) {
                        birthdayCard
                            .offset(y: card1Visible ? 0 : 30)
                            .opacity(card1Visible ? 1 : 0)

                        genderCard
                            .offset(y: card2Visible ? 0 : 30)
                            .opacity(card2Visible ? 1 : 0)

                        heightCard
                            .id("heightCard")
                            .offset(y: card3Visible ? 0 : 30)
                            .opacity(card3Visible ? 1 : 0)

                        weightCard
                            .id("weightCard")
                            .offset(y: card4Visible ? 0 : 30)
                            .opacity(card4Visible ? 1 : 0)
                    }
                    .padding(.bottom, 140) // Space for floating button
                }
                .padding(.horizontal, 20)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: focusedCard, initial: false) { _, card in
                if let card {
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo(card, anchor: .center)
                    }
                }
            }
        }
        .onAppear {
            startEntranceAnimations()
        }
    }

    private func startEntranceAnimations() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            headerVisible = true
        }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.75).delay(0.1)) {
            card1Visible = true
        }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.75).delay(0.2)) {
            card2Visible = true
        }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.75).delay(0.3)) {
            card3Visible = true
        }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.75).delay(0.4)) {
            card4Visible = true
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 12) {
            ZStack {
                // Animated background rings
                Circle()
                    .stroke(Color.blue.opacity(0.1), lineWidth: 2)
                    .frame(width: 95, height: 95)
                    .scaleEffect(headerVisible ? 1 : 0.5)

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.15), Color.cyan.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)

                Image(systemName: "person.text.rectangle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.blue)
                    .symbolRenderingMode(.hierarchical)
            }
            .scaleEffect(headerVisible ? 1 : 0.8)

            Text("About You")
                .font(.system(size: 28, weight: .bold, design: .rounded))

            Text("This helps us calculate your\npersonalized nutrition plan")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .opacity(headerVisible ? 1 : 0)
        .offset(y: headerVisible ? 0 : -20)
    }

    // MARK: - Birthday Card

    private var birthdayCard: some View {
        VStack(spacing: 12) {
            Label("Birthday", systemImage: "gift.fill")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.pink)
                .frame(maxWidth: .infinity, alignment: .leading)

            DatePicker(
                "Birthday",
                selection: $dateOfBirth,
                in: ...Date(),
                displayedComponents: .date
            )
            .datePickerStyle(.wheel)
            .labelsHidden()
            .frame(height: 120)
            .clipped()
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemBackground))
        .clipShape(.rect(cornerRadius: 16))
    }

    // MARK: - Gender Card

    private var genderCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Biological Sex", systemImage: "figure.stand")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.purple)

                    Text("Used for accurate metabolic calculations")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text("optional")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.tertiarySystemBackground))
                    .clipShape(.capsule)
            }

            HStack(spacing: 10) {
                ForEach(UserProfile.Gender.allCases) { genderOption in
                    GenderSelectionButton(
                        gender: genderOption,
                        isSelected: gender == genderOption
                    ) {
                        withAnimation(.spring(response: 0.3)) {
                            gender = genderOption
                        }
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(.rect(cornerRadius: 16))
    }

    // MARK: - Height Card

    private var heightCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Height", systemImage: "ruler.fill")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.orange)

                Spacer()

                UnitToggle(usesMetric: $usesMetricHeight, metricLabel: "cm", imperialLabel: "ft")
            }

            if usesMetricHeight {
                MeasurementInput(
                    placeholder: "170",
                    value: $heightValue,
                    unit: "cm",
                    onFocus: { focusedCard = "heightCard" }
                )
            } else {
                HStack(spacing: 12) {
                    MeasurementInput(
                        placeholder: "5",
                        value: $heightFeet,
                        unit: "ft",
                        onFocus: { focusedCard = "heightCard" }
                    )
                    MeasurementInput(
                        placeholder: "10",
                        value: $heightInches,
                        unit: "in",
                        onFocus: { focusedCard = "heightCard" }
                    )
                }
                .onChange(of: heightFeet, initial: false) { _, _ in
                    updateHeightFromImperial()
                }
                .onChange(of: heightInches, initial: false) { _, _ in
                    updateHeightFromImperial()
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(.rect(cornerRadius: 16))
            }

    // MARK: - Weight Card

    private var weightCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("Weight", systemImage: "scalemass.fill")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.green)

                Spacer()

                UnitToggle(usesMetric: $usesMetricWeight, metricLabel: "kg", imperialLabel: "lbs")
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Current weight")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                MeasurementInput(
                    placeholder: usesMetricWeight ? "70" : "155",
                    value: $weightValue,
                    unit: usesMetricWeight ? "kg" : "lbs",
                    onFocus: { focusedCard = "weightCard" }
                )
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Target weight")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("optional")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(.tertiarySystemBackground))
                        .clipShape(.capsule)
                }

                MeasurementInput(
                    placeholder: usesMetricWeight ? "65" : "145",
                    value: $targetWeightValue,
                    unit: usesMetricWeight ? "kg" : "lbs",
                    onFocus: { focusedCard = "weightCard" }
                )
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(.rect(cornerRadius: 16))
            }

    // MARK: - Helpers

    private func updateHeightFromImperial() {
        guard let feet = Double(heightFeet) else {
            heightValue = ""
            return
        }
        let inches = Double(heightInches) ?? 0
        let totalInches = (feet * 12) + inches
        let cm = totalInches * 2.54
        heightValue = String(format: "%.0f", cm)
    }
}

// MARK: - Gender Selection Button

struct GenderSelectionButton: View {
    let gender: UserProfile.Gender
    let isSelected: Bool
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button {
            HapticManager.cardSelected()
            action()
        } label: {
            VStack(spacing: 10) {
                ZStack {
                    // Glow effect when selected
                    if isSelected {
                        Circle()
                            .fill(Color.accentColor.opacity(0.3))
                            .frame(width: 64, height: 64)
                            .blur(radius: 8)
                    }

                    Circle()
                        .fill(
                            isSelected
                                ? LinearGradient(
                                    colors: [Color.accentColor, Color.accentColor.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                                : LinearGradient(
                                    colors: [Color(.tertiarySystemBackground), Color(.tertiarySystemBackground)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                        )
                        .frame(width: 58, height: 58)
                        .shadow(
                            color: isSelected ? Color.accentColor.opacity(0.3) : Color.clear,
                            radius: 8,
                            y: 4
                        )

                    Image(systemName: iconName)
                        .font(.title2)
                        .fontWeight(.medium)
                        .foregroundStyle(isSelected ? .white : .secondary)
                        .scaleEffect(isSelected ? 1.1 : 1)
                }

                Text(gender.displayName)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .medium)
                    .foregroundStyle(isSelected ? .primary : .secondary)
            }
            .frame(maxWidth: .infinity)
            .scaleEffect(isPressed ? 0.95 : 1)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        .pressEvents {
            withAnimation(.easeInOut(duration: 0.1)) { isPressed = true }
        } onRelease: {
            withAnimation(.easeInOut(duration: 0.1)) { isPressed = false }
        }
    }

    private var iconName: String {
        switch gender {
        case .male: "figure.stand"
        case .female: "figure.stand.dress"
        case .notSpecified: "person.fill.questionmark"
        }
    }
}

// MARK: - Press Events Modifier

extension View {
    func pressEvents(onPress: @escaping () -> Void, onRelease: @escaping () -> Void) -> some View {
        self.simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in onPress() }
                .onEnded { _ in onRelease() }
        )
    }
}

// MARK: - Unit Toggle

struct UnitToggle: View {
    @Binding var usesMetric: Bool
    let metricLabel: String
    let imperialLabel: String

    var body: some View {
        HStack(spacing: 0) {
            toggleButton(label: imperialLabel, isSelected: !usesMetric) {
                if usesMetric {
                    HapticManager.toggleSwitched()
                    usesMetric = false
                }
            }
            toggleButton(label: metricLabel, isSelected: usesMetric) {
                if !usesMetric {
                    HapticManager.toggleSwitched()
                    usesMetric = true
                }
            }
        }
        .padding(3)
        .background(Color(.tertiarySystemBackground))
        .clipShape(.capsule)
    }

    private func toggleButton(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.caption)
                .fontWeight(.semibold)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    isSelected
                        ? AnyShapeStyle(
                            LinearGradient(
                                colors: [Color.accentColor, Color.accentColor.opacity(0.85)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        : AnyShapeStyle(Color.clear)
                )
                .foregroundStyle(isSelected ? .white : .secondary)
                .clipShape(.capsule)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isSelected)
    }
}

// MARK: - Measurement Input

struct MeasurementInput: View {
    let placeholder: String
    @Binding var value: String
    let unit: String
    var onFocus: (() -> Void)?

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 10) {
            TextField(placeholder, text: $value)
                .keyboardType(.decimalPad)
                .font(.title3)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.tertiarySystemBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(
                            isFocused ? Color.accentColor.opacity(0.5) : Color.clear,
                            lineWidth: 2
                        )
                )
                .focused($isFocused)
                .onChange(of: isFocused, initial: false) { _, focused in
                    if focused {
                        HapticManager.lightTap()
                        onFocus?()
                    }
                }

            Text(unit)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
                .frame(width: 32)
        }
        .animation(.easeInOut(duration: 0.2), value: isFocused)
    }
}

#Preview {
    BiometricsStepView(
        dateOfBirth: .constant(Calendar.current.date(byAdding: .year, value: -25, to: Date())!),
        gender: .constant(.notSpecified),
        heightValue: .constant(""),
        weightValue: .constant(""),
        targetWeightValue: .constant(""),
        usesMetricHeight: .constant(true),
        usesMetricWeight: .constant(true)
    )
}
