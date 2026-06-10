//
//  TraiLensLabView.swift
//  Trai
//

import SwiftUI

enum TraiLensDemoState: String, CaseIterable, Identifiable {
    case idle = "Idle"
    case listening = "Listening"
    case thinking = "Thinking"
    case answering = "Answering"

    var id: String { rawValue }

    var lensState: TraiLensState {
        switch self {
        case .idle:
            return .idle
        case .listening:
            return .listening
        case .thinking:
            return .thinking
        case .answering:
            return .answering
        }
    }

    var description: String {
        switch self {
        case .idle:
            return "Calm breathing while Trai waits."
        case .listening:
            return "The cluster leans inward around the user signal."
        case .thinking:
            return "Outer nodes pass energy around the lens."
        case .answering:
            return "The center emits a steady response pulse."
        }
    }
}

struct TraiLensLabView: View {
    @State private var selectedState: TraiLensDemoState = .idle
    @State private var selectedNodeStyle: TraiIdentityNodeStyle = .glossy
    @State private var selectedLensPlacement: TraiIdentityLensPlacement = .behind
    @State private var showsNodeShadow = true
    @State private var animatesPreview = true
    @State private var previewSize: Double = 112

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: TraiSpacing.xl) {
                    heroPreview
                    surfacePreviews
                    stateGrid
                    sizeRamp
                }
                .padding(.horizontal, TraiSpacing.lg)
                .padding(.vertical, TraiSpacing.xl)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Trai Lens Lab")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var heroPreview: some View {
        VStack(spacing: TraiSpacing.lg) {
            TraiIdentityMark(
                size: previewSize,
                state: selectedState.lensState,
                nodeStyle: selectedNodeStyle,
                lensPlacement: selectedLensPlacement,
                showsNodeShadow: showsNodeShadow,
                animates: animatesPreview
            )
            .frame(maxWidth: .infinity)
            .padding(.top, TraiSpacing.lg)
            .padding(.bottom, TraiSpacing.md)

            VStack(spacing: TraiSpacing.xs) {
                Text(selectedState.rawValue)
                    .font(.traiHeadline())
                Text(selectedState.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Text(selectedNodeStyle.description)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }

            controls
        }
        .padding(TraiSpacing.lg)
        .traiCard()
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: TraiSpacing.sm) {
            VStack(spacing: TraiSpacing.sm) {
                HStack {
                    Text("Size")
                    Spacer()
                    Text("\(Int(previewSize.rounded())) pt")
                        .foregroundStyle(.secondary)
                }
                .font(.subheadline)

                Slider(value: $previewSize, in: 24...160, step: 1)
                    .tint(TraiColors.brandAccent)
            }

            Picker("Nodes", selection: $selectedNodeStyle) {
                ForEach(TraiIdentityNodeStyle.allCases) { style in
                    Text(style.rawValue).tag(style)
                }
            }
            .pickerStyle(.segmented)

            Picker("Clear lens", selection: $selectedLensPlacement) {
                ForEach(TraiIdentityLensPlacement.allCases) { placement in
                    Text(placement.rawValue).tag(placement)
                }
            }
            .pickerStyle(.segmented)

            Toggle("Chromatic shadow", isOn: $showsNodeShadow)
                .tint(TraiColors.brandAccent)

            Toggle("Animate preview", isOn: $animatesPreview)
                .tint(TraiColors.brandAccent)
        }
    }

    private var stateGrid: some View {
        VStack(alignment: .leading, spacing: TraiSpacing.md) {
            Text("States")
                .font(.traiLabel())

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 132), spacing: TraiSpacing.sm)], spacing: TraiSpacing.sm) {
                ForEach(TraiLensDemoState.allCases) { state in
                    Button {
                        withAnimation(.smooth(duration: 0.25)) {
                            selectedState = state
                        }
                    } label: {
                        HStack(spacing: TraiSpacing.sm) {
                            TraiIdentityMark(
                                size: 34,
                                state: state.lensState,
                                nodeStyle: selectedNodeStyle,
                                showsNodeShadow: showsNodeShadow,
                                showsOuterLens: false
                            )
                            Text(state.rawValue)
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.82)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, TraiSpacing.md)
                        .padding(.vertical, TraiSpacing.sm)
                        .background(
                            selectedState == state
                            ? TraiColors.brandAccent.opacity(0.14)
                            : Color(.secondarySystemGroupedBackground),
                            in: RoundedRectangle(cornerRadius: TraiRadius.medium)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: TraiRadius.medium)
                                .stroke(
                                    selectedState == state ? TraiColors.brandAccent.opacity(0.45) : .clear,
                                    lineWidth: 1
                                )
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(TraiSpacing.lg)
        .traiCard()
    }

    private var surfacePreviews: some View {
        VStack(alignment: .leading, spacing: TraiSpacing.md) {
            Text("Surfaces")
                .font(.traiLabel())

            VStack(spacing: TraiSpacing.md) {
                appIconPreview
                chatPreview
                compactControlsPreview
                widgetPreview
            }
        }
        .padding(TraiSpacing.lg)
        .traiCard()
    }

    private var appIconPreview: some View {
        HStack(spacing: TraiSpacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: 22)
                    .fill(.white)
                    .shadow(color: .black.opacity(0.10), radius: 12, y: 6)

                TraiIdentityMark(
                    size: 72,
                    state: selectedState.lensState,
                    nodeStyle: selectedNodeStyle,
                    lensPlacement: .behind,
                    showsNodeShadow: showsNodeShadow,
                    animates: false
                )
            }
            .frame(width: 92, height: 92)

            VStack(alignment: .leading, spacing: 4) {
                Text("App icon")
                    .font(.subheadline.weight(.semibold))
                Text("Large mark inside a white icon field.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
    }

    private var chatPreview: some View {
        HStack(alignment: .top, spacing: TraiSpacing.sm) {
            TraiIdentityMark(
                size: 38,
                state: .thinking,
                nodeStyle: selectedNodeStyle,
                lensPlacement: .none,
                showsNodeShadow: showsNodeShadow,
                showsOuterLens: false,
                animates: true
            )
            .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: 5) {
                Text("Trai")
                    .font(.caption.weight(.semibold))
                Text("Checking your recent meals and workout rhythm...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(TraiSpacing.md)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: TraiRadius.medium))
    }

    private var compactControlsPreview: some View {
        HStack(spacing: TraiSpacing.md) {
            compactChip(title: "Ask Trai", size: 28, state: .idle)
            compactChip(title: "Thinking", size: 28, state: .thinking)
        }
    }

    private func compactChip(title: String, size: CGFloat, state: TraiLensDemoState) -> some View {
        HStack(spacing: 8) {
            TraiIdentityMark(
                size: size,
                state: state.lensState,
                nodeStyle: selectedNodeStyle,
                lensPlacement: .none,
                showsNodeShadow: showsNodeShadow,
                showsOuterLens: false,
                animates: false
            )
            Text(title)
                .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(TraiColors.brandAccent.opacity(0.10), in: Capsule())
    }

    private var widgetPreview: some View {
        HStack(spacing: TraiSpacing.md) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Widget action")
                    .font(.subheadline.weight(.semibold))
                Text("Small target, no outer lens.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            TraiIdentityMark(
                size: 32,
                state: .idle,
                nodeStyle: selectedNodeStyle,
                lensPlacement: .none,
                showsNodeShadow: showsNodeShadow,
                showsOuterLens: false,
                animates: false
            )
            .frame(width: 44, height: 44)
            .background(TraiColors.brandAccent.opacity(0.12), in: Circle())
        }
        .padding(TraiSpacing.md)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: TraiRadius.medium))
    }

    private var sizeRamp: some View {
        VStack(alignment: .leading, spacing: TraiSpacing.md) {
            Text("Scale")
                .font(.traiLabel())

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 48), spacing: TraiSpacing.md)], spacing: TraiSpacing.md) {
                ForEach([24.0, 32.0, 44.0, 64.0, 96.0, 132.0], id: \.self) { size in
                    VStack(spacing: TraiSpacing.xs) {
                        TraiIdentityMark(
                            size: size,
                            state: selectedState.lensState,
                            nodeStyle: selectedNodeStyle,
                            lensPlacement: size >= 56 ? selectedLensPlacement : .none,
                            showsNodeShadow: showsNodeShadow,
                            showsOuterLens: size >= 56,
                            animates: false
                        )
                        .frame(width: max(size, 34), height: max(size, 34))

                        Text("\(Int(size))")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(TraiSpacing.lg)
        .traiCard()
    }
}

#Preview("Trai Lens Lab") {
    TraiLensLabView()
}
