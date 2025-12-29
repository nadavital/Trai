//
//  FloatingActionButton.swift
//  Plates
//
//  Created by Nadav Avital on 12/28/25.
//

import SwiftUI

struct FloatingActionButton: View {
    let onLogFood: () -> Void
    let onLogWeight: () -> Void
    let onAddWorkout: () -> Void

    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 12) {
            // Expanded options
            if isExpanded {
                VStack(spacing: 10) {
                    FABOption(
                        icon: "scalemass.fill",
                        label: "Weight",
                        color: .blue
                    ) {
                        collapse()
                        onLogWeight()
                    }

                    FABOption(
                        icon: "figure.run",
                        label: "Workout",
                        color: .orange
                    ) {
                        collapse()
                        onAddWorkout()
                    }

                    FABOption(
                        icon: "fork.knife",
                        label: "Food",
                        color: .green
                    ) {
                        collapse()
                        onLogFood()
                    }
                }
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.5).combined(with: .opacity),
                    removal: .scale(scale: 0.8).combined(with: .opacity)
                ))
            }

            // Main FAB button
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    isExpanded.toggle()
                }
                HapticManager.mediumTap()
            } label: {
                Image(systemName: isExpanded ? "xmark" : "plus")
                    .font(.title2)
                    .bold()
                    .foregroundStyle(.white)
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
                    .frame(width: 56, height: 56)
            }
            .glassEffect(.regular.tint(.accent).interactive(), in: .circle)
        }
    }

    private func collapse() {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
            isExpanded = false
        }
    }
}

// MARK: - FAB Option Button

private struct FABOption: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: {
            HapticManager.lightTap()
            action()
        }) {
            HStack(spacing: 10) {
                Text(label)
                    .font(.subheadline)
                    .bold()
                    .foregroundStyle(.primary)

                Image(systemName: icon)
                    .font(.body)
                    .foregroundStyle(color)
                    .frame(width: 40, height: 40)
                    .background(.ultraThinMaterial)
                    .clipShape(.circle)
            }
            .padding(.leading, 14)
            .padding(.trailing, 4)
            .padding(.vertical, 4)
            .background(.ultraThinMaterial)
            .clipShape(.capsule)
            .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Backdrop

struct FABBackdrop: View {
    let isVisible: Bool
    let onTap: () -> Void

    var body: some View {
        if isVisible {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture(perform: onTap)
                .transition(.opacity)
        }
    }
}

#Preview {
    ZStack {
        Color(.systemBackground)
            .ignoresSafeArea()

        VStack {
            Spacer()
            HStack {
                Spacer()
                FloatingActionButton(
                    onLogFood: {},
                    onLogWeight: {},
                    onAddWorkout: {}
                )
                .padding()
            }
        }
    }
}
