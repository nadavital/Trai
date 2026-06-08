//
//  FoodCameraNoCameraFallbackView.swift
//  Trai
//
//  Fallback capture screen used when camera access is unavailable.
//

import SwiftUI
import PhotosUI

struct FoodCameraNoCameraFallbackView: View {
    @Binding var description: String
    let suggestions: [FoodSuggestion]
    let onSelectSuggestion: (FoodSuggestion) -> Void
    let onManualEntry: () -> Void
    let onSubmitDescription: () -> Void
    let onEnableCamera: () -> Void
    @Binding var selectedPhotoItem: PhotosPickerItem?

    @FocusState private var isDescriptionFocused: Bool

    private var canSubmitDescription: Bool {
        !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TraiSpacing.md) {
                loggingPanel
            }
            .padding(.horizontal, TraiSpacing.md)
            .padding(.vertical, 14)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color(.systemGroupedBackground))
        .traiBackground(intensity: 0.8)
        .accessibilityIdentifier("foodCameraNoCameraFallback")
    }

    private var loggingPanel: some View {
        VStack(alignment: .leading, spacing: TraiSpacing.md) {
            statusRow

            if !suggestions.isEmpty {
                Divider()
                quickPicksSection
            }

            Divider()
            notesSection
        }
        .traiCard(cornerRadius: TraiRadius.medium)
    }

    private var statusRow: some View {
        HStack(spacing: TraiSpacing.sm) {
            Image(systemName: "camera.slash")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(TraiColors.brandAccent)
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(TraiGradient.cardSurface(TraiColors.brandAccent))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text("Camera off")
                    .font(.traiHeadline(16))

                Text("Use text, your library, or manual entry.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Button(action: onEnableCamera) {
                Label("Enable", systemImage: "camera.fill")
            }
            .buttonStyle(.traiTertiary(color: .accentColor, size: .compact, width: 96, height: 36))
        }
    }

    private var quickPicksSection: some View {
        VStack(alignment: .leading, spacing: TraiSpacing.sm) {
            TraiSectionHeader("Quick picks", icon: "clock.arrow.circlepath")

            VStack(spacing: TraiSpacing.sm) {
                ForEach(suggestions) { suggestion in
                    FoodCameraCompactSuggestionCard(suggestion: suggestion) {
                        isDescriptionFocused = false
                        onSelectSuggestion(suggestion)
                    }
                }
            }
        }
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            TraiSectionHeader("Describe meal", icon: "text.alignleft")

            TextField("What did you eat?", text: $description, axis: .vertical)
                .lineLimit(3...6)
                .padding(12)
                .background(
                    Color(.tertiarySystemBackground),
                    in: RoundedRectangle(cornerRadius: 12)
                )
                .focused($isDescriptionFocused)
                .submitLabel(.done)
                .onSubmit(submitDescription)

            Button {
                submitDescription()
            } label: {
                Label("Analyze with Trai", systemImage: "circle.hexagongrid.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.traiPrimary(fullWidth: true))
            .disabled(!canSubmitDescription)

            alternateInputRow
                .padding(.top, 2)
        }
    }

    private var alternateInputRow: some View {
        HStack(spacing: TraiSpacing.sm) {
            Text("Or")
                .font(.caption)
                .foregroundStyle(.secondary)

            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                Label("Choose photo", systemImage: "photo.on.rectangle")
                    .font(.traiLabel(13))
            }
            .buttonStyle(.plain)
            .foregroundStyle(TraiColors.brandAccent)

            Text("•")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Button(action: onManualEntry) {
                Label("Manual entry", systemImage: "square.and.pencil")
                    .font(.traiLabel(13))
            }
            .buttonStyle(.plain)
            .foregroundStyle(TraiColors.brandAccent)
            .accessibilityIdentifier("foodCameraManualButton")
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
 
    private func submitDescription() {
        guard canSubmitDescription else { return }
        isDescriptionFocused = false
        onSubmitDescription()
    }
}

private struct FoodCameraCompactSuggestionCard: View {
    let suggestion: FoodSuggestion
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: TraiSpacing.sm) {
                Text(suggestion.emoji)
                    .font(.title3)
                    .frame(width: 30, alignment: .leading)

                VStack(alignment: .leading, spacing: 3) {
                    Text(suggestion.title)
                        .font(.traiHeadline(14))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(suggestion.detail)
                        .font(.traiLabel(11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: TraiSpacing.sm)

                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(TraiColors.brandAccent)
            }
            .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
            .padding(12)
            .background(
                Color(.tertiarySystemBackground),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct FoodCameraCompactActionLabel: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.traiLabel(14))
            .lineLimit(1)
    }
}
