//
//  FoodCameraReview.swift
//  Trai
//
//  Review captured food image/description with AI analysis
//

import SwiftUI

struct FoodCameraReviewView: View {
    let image: UIImage?
    let inputSource: FoodLogInputSource
    @Binding var description: String
    let isAnalyzing: Bool
    let analysisResult: FoodAnalysis?
    let refinedSuggestion: SuggestedFoodEntry?
    let errorMessage: String?
    let refinementErrorMessage: String?
    var enabledMacros: Set<MacroType> = MacroType.defaultEnabled
    let isLoadingRefinement: Bool
    let isSaving: Bool
    let onAnalyze: () -> Void
    let onSave: (SuggestedFoodEntry, Bool) -> Void
    let onRefine: (String) -> Void
    let onManualEntry: () -> Void

    @State private var isRefining = false
    @State private var refinementText = ""
    @FocusState private var isRefinementFocused: Bool

    private var isTextOnly: Bool {
        image == nil
    }

    private var currentSuggestion: SuggestedFoodEntry? {
        if let refined = refinedSuggestion {
            return refined
        }
        guard let result = analysisResult else { return nil }
        return SuggestedFoodEntry(
            name: result.name,
            calories: result.calories,
            proteinGrams: result.proteinGrams,
            carbsGrams: result.carbsGrams,
            fatGrams: result.fatGrams,
            fiberGrams: result.fiberGrams,
            sugarGrams: result.sugarGrams,
            servingSize: result.servingSize,
            emoji: result.emoji,
            components: result.components?.map(SuggestedFoodComponent.init(component:)) ?? [],
            mealKind: result.mealKind,
            notes: result.notes,
            confidence: result.confidence,
            schemaVersion: 2
        )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: TraiSpacing.md) {
                FoodReviewInputCard(
                    image: image,
                    title: headerTitle,
                    systemImage: headerSystemImage,
                    inputSource: inputSource
                )

                FoodReviewNotesCard(
                    label: descriptionLabel,
                    text: $description,
                    isDisabled: isAnalyzing || (isTextOnly && analysisResult != nil && inputSource != .memorySuggestion)
                )

                // Analysis section
                if let suggestion = currentSuggestion {
                    FoodCameraSuggestionCard(
                        suggestion: suggestion,
                        isRefining: isRefining,
                        enabledMacros: enabledMacros,
                        isSaving: isSaving,
                        onSave: {
                            onSave(suggestion, refinedSuggestion != nil)
                        },
                        onStartRefine: {
                            withAnimation(.spring(response: 0.3)) {
                                isRefining = true
                            }
                            isRefinementFocused = true
                        }
                    )
                } else if let error = errorMessage {
                    FoodCameraErrorCard(
                        message: error,
                        onRetry: onAnalyze,
                        onManualEntry: onManualEntry
                    )
                }

                // Refinement chat interface
                if isRefining {
                    VStack(spacing: 12) {
                        FoodRefinementInput(
                            text: $refinementText,
                            isLoading: isLoadingRefinement,
                            isFocused: $isRefinementFocused,
                            onSend: sendRefinement,
                            onCancel: {
                                withAnimation(.spring(response: 0.3)) {
                                    isRefining = false
                                    refinementText = ""
                                }
                            }
                        )

                        if let refinementErrorMessage, !refinementErrorMessage.isEmpty {
                            Text(refinementErrorMessage)
                                .font(.caption)
                                .foregroundStyle(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }

                // Initial analyze control
                if currentSuggestion == nil && errorMessage == nil {
                    if isAnalyzing {
                        FoodAnalysisLoadingCard(inputSource: inputSource)
                            .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    } else {
                        FoodAnalyzeButton(action: onAnalyze)
                            .transition(.opacity)
                    }
                }
            }
            .padding(.horizontal, TraiSpacing.md)
            .padding(.top, TraiSpacing.xs)
            .padding(.bottom, TraiSpacing.md)
        }
        .traiBackground(intensity: 0.45)
        .animation(TraiAnimation.standard, value: isAnalyzing)
        .onChange(of: refinedSuggestion) { _, newValue in
            guard newValue != nil, isRefining else { return }

            withAnimation(.spring(response: 0.3)) {
                isRefining = false
            }
            refinementText = ""
            isRefinementFocused = false
        }
    }

    private var headerTitle: String {
        switch inputSource {
        case .memorySuggestion:
            return "Using remembered food"
        case .description:
            return "Analyzing from description"
        default:
            return "Review your food"
        }
    }

    private var headerSystemImage: String {
        switch inputSource {
        case .memorySuggestion:
            return "sparkles.rectangle.stack.fill"
        case .description:
            return "text.bubble.fill"
        default:
            return "fork.knife.circle.fill"
        }
    }

    private var descriptionLabel: String {
        switch inputSource {
        case .memorySuggestion:
            return "Notes (optional)"
        default:
            return isTextOnly ? "Notes" : "Notes (optional)"
        }
    }

    private func sendRefinement() {
        guard !refinementText.trimmingCharacters(in: .whitespaces).isEmpty,
              currentSuggestion != nil else { return }

        let correction = refinementText.trimmingCharacters(in: .whitespacesAndNewlines)
        refinementText = ""
        onRefine(correction)
    }
}

// MARK: - Food Review Input

private struct FoodReviewInputCard: View {
    let image: UIImage?
    let title: String
    let systemImage: String
    let inputSource: FoodLogInputSource

    var body: some View {
        VStack(alignment: .leading, spacing: TraiSpacing.sm) {
            TraiSectionHeader("Food", icon: sectionIcon)

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 220)
                    .frame(maxWidth: .infinity)
                    .clipShape(.rect(cornerRadius: 14, style: .continuous))
                    .accessibilityLabel("Food photo")
            } else {
                HStack(spacing: TraiSpacing.md) {
                    ZStack {
                        Circle()
                            .fill(TraiGradient.cardSurface(TraiColors.brandAccent))
                            .frame(width: 54, height: 54)

                        Image(systemName: systemImage)
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(TraiColors.brandAccent)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(title)
                            .font(.traiHeadline(16))

                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(
                    Color(.tertiarySystemBackground),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
            }
        }
        .traiCard(tint: TraiColors.brandAccent)
    }

    private var sectionIcon: String {
        switch inputSource {
        case .camera:
            return "camera.fill"
        case .photo:
            return "photo.fill"
        case .description:
            return "text.bubble.fill"
        case .memorySuggestion:
            return "sparkles.rectangle.stack.fill"
        case .manual:
            return "square.and.pencil"
        }
    }

    private var subtitle: String {
        switch inputSource {
        case .memorySuggestion:
            return "Matched from a saved food memory."
        case .description:
            return "Trai will estimate from your description."
        case .manual:
            return "Ready for manual details."
        case .camera, .photo:
            return "Trai will estimate from the image and notes."
        }
    }
}

private struct FoodReviewNotesCard: View {
    let label: String
    @Binding var text: String
    let isDisabled: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: TraiSpacing.sm) {
            TraiSectionHeader(label, icon: "text.alignleft")

            TextField("Add notes, extra items, portions...", text: $text, axis: .vertical)
                .lineLimit(2...4)
                .padding(12)
                .background(
                    Color(.tertiarySystemBackground),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
                .disabled(isDisabled)
                .opacity(isDisabled ? 0.72 : 1)
        }
        .traiCard()
    }
}

private struct FoodAnalyzeButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: TraiSpacing.sm) {
                TraiLensSymbolIcon(size: 17, variant: .enclosed, color: .white)
                Text("Analyze with Trai")
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.traiPrimary())
    }
}

private struct FoodAnalysisLoadingCard: View {
    let inputSource: FoodLogInputSource

    var body: some View {
        VStack(spacing: TraiSpacing.md) {
            TraiLensView(size: 64, state: .thinking, palette: .energy)
                .accessibilityHidden(true)

            VStack(spacing: 4) {
                Text("Trai is analyzing")
                    .font(.traiHeadline(17))

                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, TraiSpacing.sm)
        .traiCard(tint: TraiColors.brandAccent)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Trai is analyzing food")
    }

    private var statusText: String {
        switch inputSource {
        case .camera, .photo:
            return "Reading the food, notes, and portion cues."
        case .description:
            return "Estimating nutrition from your description."
        case .memorySuggestion:
            return "Checking this remembered food."
        case .manual:
            return "Preparing the food estimate."
        }
    }
}

// MARK: - Food Camera Suggestion Card

struct FoodCameraSuggestionCard: View {
    let suggestion: SuggestedFoodEntry
    let isRefining: Bool
    var enabledMacros: Set<MacroType> = MacroType.defaultEnabled
    let isSaving: Bool
    let onSave: () -> Void
    let onStartRefine: () -> Void

    private var orderedEnabledMacros: [MacroType] {
        MacroType.displayOrder.filter { enabledMacros.contains($0) }
    }

    private func valueFor(_ macro: MacroType) -> Double {
        switch macro {
        case .protein: suggestion.proteinGrams
        case .carbs: suggestion.carbsGrams
        case .fat: suggestion.fatGrams
        case .fiber: suggestion.fiberGrams ?? 0
        case .sugar: suggestion.sugarGrams ?? 0
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                HStack(spacing: 6) {
                    Text(suggestion.displayEmoji)
                    Text("Log this?")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                .foregroundStyle(.green)

                Spacer()

                NutritionSourcesLink(
                    context: .foodAnalysis,
                    title: "Sources"
                )
            }

            // Meal name and calories
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(suggestion.name)
                        .font(.headline)

                    if let servingSize = suggestion.servingSize {
                        Text(servingSize)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(suggestion.calories)")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("kcal")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Macros (filtered by enabledMacros)
            if !orderedEnabledMacros.isEmpty {
                HStack(spacing: 12) {
                    ForEach(orderedEnabledMacros) { macro in
                        FoodCameraMacroPill(
                            label: macro.displayName,
                            value: Int(valueFor(macro)),
                            color: macro.color
                        )
                    }
                }
            }

            // Action buttons
            if !isRefining {
                HStack(spacing: 10) {
                    Button(action: onStartRefine) {
                        HStack(spacing: 6) {
                            Image(systemName: "bubble.left.and.text.bubble.right")
                                .font(.subheadline)
                            Text("Refine")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.traiTertiary())
                    .disabled(isSaving)
                    .accessibilityIdentifier("foodCameraReviewRefineButton")

                    Button(action: onSave) {
                        HStack(spacing: 6) {
                            if isSaving {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.subheadline)
                            }
                            Text(isSaving ? "Saving" : "Save")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.traiPrimary())
                    .disabled(isSaving)
                    .accessibilityIdentifier("foodCameraReviewSaveButton")
                }
            }
            }
            .traiCard(tint: .green)
    }
}

// MARK: - Food Camera Macro Pill

struct FoodCameraMacroPill: View {
    let label: String
    let value: Int
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 2) {
                Text("\(value)")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text("g")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.1))
        .clipShape(.rect(cornerRadius: 8))
    }
}

// MARK: - Food Refinement Input

struct FoodRefinementInput: View {
    @Binding var text: String
    let isLoading: Bool
    var isFocused: FocusState<Bool>.Binding
    let onSend: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("What should I change?")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                Button("Cancel", action: onCancel)
                    .font(.subheadline)
                    .accessibilityIdentifier("foodCameraRefinementCancelButton")
            }

            HStack(spacing: 10) {
                TextField("e.g., \"It's actually a wrap\" or \"Add 100 more calories\"", text: $text, axis: .vertical)
                    .lineLimit(1...3)
                    .padding(12)
                    .background(Color(.tertiarySystemBackground))
                    .clipShape(.rect(cornerRadius: 12))
                    .focused(isFocused)
                    .accessibilityIdentifier("foodCameraRefinementField")

                Button {
                    onSend()
                } label: {
                    if isLoading {
                        ProgressView()
                            .frame(width: 44, height: 44)
                    } else {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title)
                            .foregroundStyle(text.trimmingCharacters(in: .whitespaces).isEmpty ? Color.secondary : Color.accentColor)
                    }
                }
                .accessibilityIdentifier("foodCameraRefinementSendButton")
                .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)
            }
        }
        .traiCard()
    }
}

struct NutritionSourcesLink: View {
    let context: NutritionSourcesSheet.Context
    var title: String = "Sources & limitations"
    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented = true
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "info.circle")
                    .font(.caption2)
                Text(title)
                    .font(.caption2)
            }
            .foregroundStyle(.secondary)
            .opacity(0.88)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("nutritionSourcesLink")
        .sheet(isPresented: $isPresented) {
            NutritionSourcesSheet(context: context)
                .traiSheetBranding()
        }
    }
}

struct NutritionSourcesSheet: View {
    enum Context {
        case foodAnalysis
        case nutritionPlan
    }

    private enum SourceURL {
        static let fdaCalories = URL(string: "https://www.fda.gov/food/nutrition-facts-label/calories-nutrition-facts-label")!
        static let foodDataCentral = URL(string: "https://fdc.nal.usda.gov/")!
        static let mifflinStJeor = URL(string: "https://www.ncbi.nlm.nih.gov/books/NBK278991/table/diet-treatment-obes.table12est/")!
    }

    let context: Context
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(primaryCopy)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineSpacing(3)

                    VStack(alignment: .leading, spacing: 10) {
                        switch context {
                        case .foodAnalysis:
                            sourceLink(
                                title: "USDA FoodData Central",
                                subtitle: "Reference database for checking foods, ingredients, and nutrient values.",
                                destination: SourceURL.foodDataCentral
                            )

                            sourceLink(
                                title: "FDA Nutrition Facts: calories",
                                subtitle: "Label guidance for calories and packaged-food nutrition context.",
                                destination: SourceURL.fdaCalories
                            )
                        case .nutritionPlan:
                            sourceLink(
                                title: "Mifflin-St Jeor equation",
                                subtitle: "Reference equation for estimating resting metabolic rate from profile inputs.",
                                destination: SourceURL.mifflinStJeor
                            )

                            sourceLink(
                                title: "FDA Nutrition Facts: calories",
                                subtitle: "General calorie and nutrition-label context for interpreting targets.",
                                destination: SourceURL.fdaCalories
                            )
                        }
                    }
                }
                .padding()
            }
            .navigationTitle(navigationTitle)
            .toolbarTitleDisplayMode(.inlineLarge)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", systemImage: "checkmark") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var primaryCopy: String {
        switch context {
        case .foodAnalysis:
            "Trai's food analysis is an AI estimate based on the photo, description, and saved context. Portion size, hidden ingredients, cooking method, and labels can change the result, so verify packaged or restaurant food against official nutrition information. These estimates are for general nutrition insight and are not medical advice."
        case .nutritionPlan:
            "Trai's plan targets are generated from your profile, goal, and activity level using standard nutrition-estimation methods. They are planning estimates, not medical advice, and should not replace guidance from a qualified medical or nutrition professional."
        }
    }

    private var navigationTitle: String {
        switch context {
        case .foodAnalysis:
            "Food Estimate"
        case .nutritionPlan:
            "Plan Sources"
        }
    }

    private func sourceLink(title: String, subtitle: String, destination: URL) -> some View {
        Link(destination: destination) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "link")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(TraiColors.brandAccent)
                    .frame(width: 18, height: 18)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Food Camera Error Card

struct FoodCameraErrorCard: View {
    let message: String
    let onRetry: () -> Void
    let onManualEntry: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title)
                .foregroundStyle(.orange)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 10) {
                Button("Try Again", action: onRetry)
                    .buttonStyle(.traiPrimary())

                Button("Log Manually", action: onManualEntry)
                    .buttonStyle(.traiSecondary())
            }
        }
        .frame(maxWidth: .infinity)
        .traiCard()
    }
}
