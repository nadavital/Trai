//
//  GoalsStepView.swift
//  Plates
//

import SwiftUI

struct GoalsStepView: View {
    @Binding var selectedGoal: UserProfile.GoalType?
    @Binding var dietaryRestrictions: Set<DietaryRestriction>
    @Binding var additionalNotes: String

    /// Filtered goals (6 instead of 7 - removed "health" as too generic)
    private var availableGoals: [UserProfile.GoalType] {
        [.loseWeight, .loseFat, .buildMuscle, .recomposition, .maintenance, .performance]
    }

    @State private var headerVisible = false
    @State private var goalsVisible = false
    @State private var dietaryVisible = false
    @State private var notesVisible = false
    @State private var showAllRestrictions = false
    @FocusState private var isNotesFocused: Bool

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                        .padding(.top, 16)

                    goalsSection
                        .offset(y: goalsVisible ? 0 : 30)
                        .opacity(goalsVisible ? 1 : 0)

                    dietarySection
                        .offset(y: dietaryVisible ? 0 : 30)
                        .opacity(dietaryVisible ? 1 : 0)

                    notesSection
                        .id("notesSection")
                        .offset(y: notesVisible ? 0 : 30)
                        .opacity(notesVisible ? 1 : 0)
                        .padding(.bottom, 140) // Space for floating button
                }
                .padding(.horizontal, 20)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: isNotesFocused, initial: false) { _, focused in
                if focused {
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo("notesSection", anchor: .center)
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
        withAnimation(.spring(response: 0.5, dampingFraction: 0.75).delay(0.15)) {
            goalsVisible = true
        }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.75).delay(0.3)) {
            dietaryVisible = true
        }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.75).delay(0.45)) {
            notesVisible = true
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 12) {
            ZStack {
                // Animated rings
                Circle()
                    .stroke(Color.green.opacity(0.15), lineWidth: 2)
                    .frame(width: 95, height: 95)
                    .scaleEffect(headerVisible ? 1 : 0.5)

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.green.opacity(0.15), Color.mint.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)

                Image(systemName: "target")
                    .font(.system(size: 36))
                    .foregroundStyle(.green)
                    .symbolRenderingMode(.hierarchical)
            }
            .scaleEffect(headerVisible ? 1 : 0.8)

            Text("Your Goals")
                .font(.system(size: 28, weight: .bold, design: .rounded))

            Text("What would you like to achieve?")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .opacity(headerVisible ? 1 : 0)
        .offset(y: headerVisible ? 0 : -20)
    }

    // MARK: - Goals Section

    private var goalsSection: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(availableGoals) { goal in
                GoalCardWithDescription(
                    goal: goal,
                    isSelected: selectedGoal == goal
                ) {
                    HapticManager.cardSelected()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                        selectedGoal = goal
                    }
                }
            }
        }
    }

    // MARK: - Dietary Section

    private var dietarySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Label("Dietary Preferences", systemImage: "leaf.fill")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.mint)

                Text("Select any that apply to you")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            let displayedRestrictions = showAllRestrictions
                ? DietaryRestriction.allCases
                : Array(DietaryRestriction.allCases.prefix(6))

            FlowLayout(spacing: 10) {
                ForEach(displayedRestrictions) { restriction in
                    DietaryChip(
                        restriction: restriction,
                        isSelected: dietaryRestrictions.contains(restriction)
                    ) {
                        HapticManager.toggleSwitched()
                        withAnimation(.spring(response: 0.3)) {
                            if dietaryRestrictions.contains(restriction) {
                                dietaryRestrictions.remove(restriction)
                            } else {
                                dietaryRestrictions.insert(restriction)
                            }
                        }
                    }
                }
            }

            if !showAllRestrictions {
                Button {
                    HapticManager.lightTap()
                    withAnimation(.spring(response: 0.4)) {
                        showAllRestrictions = true
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text("Show more options")
                        Image(systemName: "chevron.down")
                            .font(.caption)
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.tint)
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(.secondarySystemBackground))
        )
    }

    // MARK: - Notes Section

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Label("Anything else?", systemImage: "sparkles")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.purple)

                    Spacer()

                    Text("optional")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.tertiarySystemBackground))
                        .clipShape(.capsule)
                }

                Text("Medical conditions, injuries, or specific needs")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            TextEditor(text: $additionalNotes)
                .font(.body)
                .frame(minHeight: 80)
                .padding(12)
                .scrollContentBackground(.hidden)
                .background(Color(.tertiarySystemBackground))
                .clipShape(.rect(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(
                            isNotesFocused ? Color.accentColor : Color.clear,
                            lineWidth: 2
                        )
                )
                .focused($isNotesFocused)
                .onChange(of: isNotesFocused, initial: false) { _, focused in
                    if focused {
                        HapticManager.lightTap()
                    }
                }
                .overlay(alignment: .topLeading) {
                    if additionalNotes.isEmpty && !isNotesFocused {
                        Text("e.g., I have PCOS, training for a marathon...")
                            .font(.body)
                            .foregroundStyle(.tertiary)
                            .padding(16)
                            .allowsHitTesting(false)
                    }
                }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(
                    isNotesFocused ? Color.accentColor.opacity(0.3) : Color.clear,
                    lineWidth: 1.5
                )
        )
        .shadow(
            color: isNotesFocused ? Color.accentColor.opacity(0.1) : Color.clear,
            radius: 12,
            y: 4
        )
        .animation(.spring(response: 0.3), value: isNotesFocused)
    }
}

// MARK: - Goal Card

struct GoalCard: View {
    let goal: UserProfile.GoalType
    let isSelected: Bool
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                ZStack {
                    // Glow effect when selected
                    if isSelected {
                        Circle()
                            .fill(colorForGoal.opacity(0.3))
                            .frame(width: 58, height: 58)
                            .blur(radius: 8)
                    }

                    Circle()
                        .fill(
                            isSelected
                                ? LinearGradient(
                                    colors: [colorForGoal, colorForGoal.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                                : LinearGradient(
                                    colors: [colorForGoal.opacity(0.15), colorForGoal.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                        )
                        .frame(width: 52, height: 52)

                    Image(systemName: goal.iconName)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(isSelected ? .white : colorForGoal)
                        .scaleEffect(isSelected ? 1.1 : 1)
                }

                Text(goal.displayName)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(
                        isSelected ? colorForGoal.opacity(0.6) : Color.clear,
                        lineWidth: 2
                    )
            )
            .shadow(
                color: isSelected ? colorForGoal.opacity(0.3) : Color.black.opacity(0.03),
                radius: isSelected ? 10 : 4,
                y: isSelected ? 5 : 2
            )
            .scaleEffect(isPressed ? 0.96 : 1)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        .pressEvents {
            withAnimation(.easeInOut(duration: 0.1)) { isPressed = true }
        } onRelease: {
            withAnimation(.easeInOut(duration: 0.1)) { isPressed = false }
        }
    }

    private var colorForGoal: Color {
        switch goal {
        case .loseWeight: .red
        case .loseFat: .orange
        case .buildMuscle: .blue
        case .recomposition: .purple
        case .maintenance: .gray
        case .performance: .green
        case .health: .pink
        }
    }
}

// MARK: - Goal Card With Description

struct GoalCardWithDescription: View {
    let goal: UserProfile.GoalType
    let isSelected: Bool
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                ZStack {
                    if isSelected {
                        Circle()
                            .fill(colorForGoal.opacity(0.3))
                            .frame(width: 50, height: 50)
                            .blur(radius: 8)
                    }

                    Circle()
                        .fill(
                            isSelected
                                ? LinearGradient(
                                    colors: [colorForGoal, colorForGoal.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                                : LinearGradient(
                                    colors: [colorForGoal.opacity(0.15), colorForGoal.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                        )
                        .frame(width: 44, height: 44)

                    Image(systemName: goal.iconName)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(isSelected ? .white : colorForGoal)
                        .scaleEffect(isSelected ? 1.1 : 1)
                }

                VStack(spacing: 4) {
                    Text(goal.displayName)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(shortDescription)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(
                        isSelected ? colorForGoal.opacity(0.6) : Color.clear,
                        lineWidth: 2
                    )
            )
            .shadow(
                color: isSelected ? colorForGoal.opacity(0.3) : Color.black.opacity(0.03),
                radius: isSelected ? 10 : 4,
                y: isSelected ? 5 : 2
            )
            .scaleEffect(isPressed ? 0.96 : 1)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        .pressEvents {
            withAnimation(.easeInOut(duration: 0.1)) { isPressed = true }
        } onRelease: {
            withAnimation(.easeInOut(duration: 0.1)) { isPressed = false }
        }
    }

    private var shortDescription: String {
        switch goal {
        case .loseWeight: "Reduce overall weight"
        case .loseFat: "Preserve muscle mass"
        case .buildMuscle: "Strength & size gains"
        case .recomposition: "Lose fat, gain muscle"
        case .maintenance: "Keep current weight"
        case .performance: "Optimize for athletics"
        case .health: "Balanced nutrition"
        }
    }

    private var colorForGoal: Color {
        switch goal {
        case .loseWeight: .red
        case .loseFat: .orange
        case .buildMuscle: .blue
        case .recomposition: .purple
        case .maintenance: .gray
        case .performance: .green
        case .health: .pink
        }
    }
}

// MARK: - Dietary Chip

struct DietaryChip: View {
    let restriction: DietaryRestriction
    let isSelected: Bool
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: restriction.iconName)
                    .font(.system(size: 12, weight: .semibold))
                    .scaleEffect(isSelected ? 1.1 : 1)

                Text(restriction.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                isSelected
                    ? LinearGradient(
                        colors: [Color.accentColor, Color.accentColor.opacity(0.85)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    : LinearGradient(
                        colors: [Color(.tertiarySystemBackground), Color(.tertiarySystemBackground)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
            )
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(.capsule)
            .overlay(
                Capsule()
                    .strokeBorder(
                        isSelected ? Color.clear : Color.gray.opacity(0.15),
                        lineWidth: 1
                    )
            )
            .shadow(
                color: isSelected ? Color.accentColor.opacity(0.25) : Color.clear,
                radius: 6,
                y: 3
            )
            .scaleEffect(isPressed ? 0.95 : 1)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isSelected)
        .pressEvents {
            withAnimation(.easeInOut(duration: 0.08)) { isPressed = true }
        } onRelease: {
            withAnimation(.easeInOut(duration: 0.08)) { isPressed = false }
        }
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)

        for (index, subview) in subviews.enumerated() {
            let frame = result.frames[index]
            subview.place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                proposal: ProposedViewSize(frame.size)
            )
        }
    }

    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, frames: [CGRect]) {
        let maxWidth = proposal.width ?? .infinity
        var frames: [CGRect] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }

            frames.append(CGRect(origin: CGPoint(x: currentX, y: currentY), size: size))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
        }

        let totalHeight = currentY + lineHeight
        return (CGSize(width: maxWidth, height: totalHeight), frames)
    }
}

#Preview {
    GoalsStepView(
        selectedGoal: .constant(.loseWeight),
        dietaryRestrictions: .constant([.vegetarian]),
        additionalNotes: .constant("")
    )
}
