//
//  WorkoutGoalAISheet.swift
//  Trai
//

import SwiftUI

struct WorkoutGoalAISheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AccountSessionService.self) private var accountSessionService: AccountSessionService?
    @Environment(MonetizationService.self) private var monetizationService: MonetizationService?
    @Environment(ProUpsellCoordinator.self) private var proUpsellCoordinator: ProUpsellCoordinator?

    let userGoal: String?
    let workoutPlan: WorkoutPlan?
    let workouts: [LiveWorkout]
    let sessions: [WorkoutSession]
    let exerciseHistory: [ExerciseHistory]
    let memoryContext: [String]
    let existingGoals: [WorkoutGoal]
    let prefersMetricWeight: Bool
    var initialSuggestions: [WorkoutGoalSuggestion] = []
    var onSuggestionsGenerated: (([WorkoutGoalSuggestion]) -> Void)? = nil
    let onSaveGoals: ([WorkoutGoal]) -> Bool

    @State private var aiService = AIService()
    @State private var promptText = ""
    @State private var isGenerating = false
    @State private var suggestions: [WorkoutGoalSuggestion] = []
    @State private var selectedSuggestionIDs: Set<String> = []
    @State private var presentedAccountSetupContext: AccountSetupContext?
    @State private var submittedPromptText: String?
    @State private var selectedSuggestionForDetail: WorkoutGoalSuggestion?
    @FocusState private var isInputFocused: Bool

    private struct GoalPromptSuggestion: Identifiable, Hashable {
        let title: String
        let prompt: String

        var id: String { title + "|" + prompt }
    }

    private var canAccessWorkoutGoalAI: Bool {
        monetizationService?.canAccessAIFeatures ?? true
    }

    private var requiresAuthenticatedAccount: Bool {
        accountSessionService?.isAuthenticated != true
    }

    private var selectedGoals: [WorkoutGoal] {
        suggestions
            .filter { selectedSuggestionIDs.contains($0.id) }
            .map { $0.asWorkoutGoal() }
    }

    private var plannedSessionSummaries: [String] {
        (workoutPlan?.templates ?? []).prefix(6).map { template in
            let blockDetail = template.blocks
                .sorted { $0.order < $1.order }
                .prefix(4)
                .map { block in
                    "\(block.title) [blockID=\(block.id.uuidString), kind=\(block.kind.rawValue), role=\(block.role.rawValue)]"
                }
                .joined(separator: ", ")
            let detail = [
                template.focusAreasDisplay.isEmpty ? template.sessionType.displayName : template.focusAreasDisplay,
                template.primaryBlockSummary,
                blockDetail
            ]
            .filter { !$0.isEmpty }
            .joined(separator: " • ")
            return "\(template.name) [templateID=\(template.id.uuidString)] (\(template.sessionType.displayName) • \(detail))"
        }
    }

    private var recentSessionSummaries: [String] {
        WorkoutGoalRecommendationContextBuilder.recentSessionSummaries(
            workouts: workouts,
            sessions: sessions
        )
    }

    private var existingGoalTitles: [String] {
        existingGoals.map(\.trimmedTitle).filter { !$0.isEmpty }
    }

    private var hasActiveGoals: Bool {
        existingGoals.contains { $0.status == .active }
    }

    private var shouldShowInitialPromptMessage: Bool {
        suggestions.isEmpty && !isGenerating && submittedPromptText == nil && canAccessWorkoutGoalAI
    }

    private var goalPromptSuggestions: [GoalPromptSuggestion] {
        var items: [GoalPromptSuggestion] = []

        if let workoutPlan {
            items.append(
                GoalPromptSuggestion(
                    title: "Plan consistency",
                    prompt: "Generate goals that help me follow my current workout plan consistently."
                )
            )

            for template in workoutPlan.templates.prefix(4) {
                let focus = template.focusAreasDisplay.isEmpty ? template.sessionType.displayName : template.focusAreasDisplay
                let title = focus.isEmpty ? template.name : focus
                let detail = [template.name, template.primaryBlockSummary]
                    .filter { !$0.isEmpty }
                    .joined(separator: " with ")
                items.append(
                    GoalPromptSuggestion(
                        title: title,
                        prompt: "Generate goals around \(detail.isEmpty ? title : detail)."
                    )
                )
            }
        }

        if items.isEmpty {
            items = [
                GoalPromptSuggestion(title: "Strength goal", prompt: "Generate strength goals from my recent training."),
                GoalPromptSuggestion(title: "Consistency", prompt: "Generate a consistency goal from my recent workouts."),
                GoalPromptSuggestion(title: "Recovery", prompt: "Generate a recovery or mobility goal from my recent training.")
            ]
        }

        var seen: Set<String> = []
        return Array(items.filter { seen.insert($0.title.goalNormalizedKey).inserted }.prefix(4))
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 14) {
                        if shouldShowInitialPromptMessage {
                            traiPromptMessage
                        }

                        if let submittedPromptText {
                            userMessage(submittedPromptText)
                                .id("submittedPrompt")
                        }

                        if !canAccessWorkoutGoalAI {
                            ProUpsellInlineCard(
                                source: .workoutPlan,
                                actionTitle: "Unlock Trai Pro"
                            ) {
                                proUpsellCoordinator?.present(source: .workoutPlan)
                            }
                        } else if isGenerating {
                            generatingMessage
                                .id("generating")
                        } else if suggestions.isEmpty {
                            emptyConversationState
                                .id("empty")
                        } else {
                            generatedGoalsMessage
                                .id("suggestions")
                        }

                        Color.clear
                            .frame(height: 12)
                            .id("bottom")
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: suggestions.count) { _, _ in
                    scrollToBottom(proxy)
                }
                .onChange(of: isGenerating) { _, _ in
                    scrollToBottom(proxy)
                }
            }
            .safeAreaInset(edge: .bottom) {
                bottomPromptBar
            }
            .background(alignment: .bottom) {
                TraiChatInputBackdrop()
            }
            .navigationTitle("Set Goals with Trai")
            .toolbarTitleDisplayMode(.inlineLarge)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    if !selectedGoals.isEmpty {
                        Button("Save", systemImage: "checkmark") {
                            if onSaveGoals(selectedGoals) {
                                HapticManager.success()
                                dismiss()
                            } else {
                                HapticManager.error()
                            }
                        }
                        .labelStyle(.iconOnly)
                        .tint(.accentColor)
                    }
                }
            }
        }
        .sheet(item: $presentedAccountSetupContext) { context in
            AccountSetupView(context: context)
                .traiSheetBranding()
        }
        .sheet(item: $selectedSuggestionForDetail) { suggestion in
            GeneratedWorkoutGoalDetailSheet(
                goal: suggestion.asWorkoutGoal(),
                rationale: suggestion.rationale,
                selection: .init(
                    isSelected: selectedSuggestionIDs.contains(suggestion.id),
                    onToggle: { toggleSuggestion(suggestion) }
                )
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .traiSheetBranding()
        }
        .traiSheetBranding()
        .proUpsellPresenter()
        .onAppear {
            if suggestions.isEmpty, !initialSuggestions.isEmpty {
                suggestions = initialSuggestions
                selectedSuggestionIDs = []
                submittedPromptText = nil
                return
            }

            guard suggestions.isEmpty, !hasActiveGoals, canAccessWorkoutGoalAI else { return }
            Task { await generateSuggestions() }
        }
    }

    private var traiPromptMessage: some View {
        HStack(alignment: .top, spacing: 10) {
            TraiLensView(size: 32, state: isGenerating ? .thinking : .idle, palette: .energy)

            VStack(alignment: .leading, spacing: 10) {
                Text("What should we work toward?")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Text("Tell me the lift, route, habit, or training target. I’ll turn it into a goal Trai can track.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))

            Spacer(minLength: 28)
        }
    }

    private func userMessage(_ text: String) -> some View {
        HStack {
            Spacer(minLength: 40)

            Text(text)
                .font(.subheadline)
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private var emptyConversationState: some View {
        HStack(alignment: .top, spacing: 10) {
            TraiLensView(size: 32, state: .idle, palette: .energy)
            Button {
                Task { await generateSuggestions() }
            } label: {
                Label("Generate goal ideas", systemImage: "sparkles")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.traiSecondary(color: TraiColors.brandAccent))
        }
    }

    private var generatingMessage: some View {
        HStack(alignment: .top, spacing: 10) {
            TraiLensView(size: 32, state: .thinking, palette: .energy)
            HStack(spacing: 10) {
                ProgressView()
                Text("Looking through your plan and training...")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(12)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private var generatedGoalsMessage: some View {
        GeneratedWorkoutGoalsCardContainer(title: "Goals Trai will track") {
            VStack(spacing: 8) {
                ForEach(suggestions) { suggestion in
                    SelectableGeneratedWorkoutGoalRow(
                        goal: suggestion.asWorkoutGoal(),
                        isSelected: selectedSuggestionIDs.contains(suggestion.id),
                        onSelect: { selectedSuggestionForDetail = suggestion },
                        onToggle: { toggleSuggestion(suggestion) }
                    )
                }
            }
        }
    }

    private var bottomPromptBar: some View {
        VStack(spacing: 6) {
            if canAccessWorkoutGoalAI, !isGenerating {
                promptSuggestionChips
            }

            SimpleChatInputBar(
                text: $promptText,
                placeholder: "Ask Trai for a different goal...",
                isLoading: isGenerating,
                onSend: submitGoalPrompt,
                isFocused: $isInputFocused
            )
        }
    }

    private var promptSuggestionChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(goalPromptSuggestions) { suggestion in
                    TraiSelectableChip(text: suggestion.title, isSelected: false) {
                        submitGoalPrompt(suggestion.prompt)
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.top, 6)
        .padding(.bottom, 2)
    }

    private func toggleSuggestion(_ suggestion: WorkoutGoalSuggestion) {
        if selectedSuggestionIDs.contains(suggestion.id) {
            selectedSuggestionIDs.remove(suggestion.id)
        } else {
            selectedSuggestionIDs.insert(suggestion.id)
        }
        HapticManager.selectionChanged()
    }

    private func generateSuggestions(userIntent: String? = nil) async {
        guard canAccessWorkoutGoalAI else {
            proUpsellCoordinator?.present(source: .workoutPlan)
            return
        }

        guard !requiresAuthenticatedAccount else {
            presentedAccountSetupContext = .aiFeatures
            return
        }

        isGenerating = true
        defer { isGenerating = false }

        do {
            let generated = try await aiService.suggestWorkoutGoals(
                userGoal: userGoal,
                plannedSessions: plannedSessionSummaries,
                recentSessions: recentSessionSummaries,
                recentTrainingSummary: WorkoutGoalRecommendationContextBuilder.recentTrainingSummary(
                    workouts: workouts,
                    sessions: sessions
                ),
                exerciseSummaries: WorkoutGoalRecommendationContextBuilder.exerciseSummaries(
                    history: exerciseHistory,
                    prefersMetricWeight: prefersMetricWeight
                ),
                memoryContext: memoryContext,
                existingGoals: existingGoalTitles,
                userIntent: userIntent ?? promptText,
                prefersMetricWeight: prefersMetricWeight
            )

            suggestions = generated
            selectedSuggestionIDs = []
            onSuggestionsGenerated?(generated)
        } catch {
            print("Workout goal suggestion generation failed: \(error)")
        }
    }

    private func submitGoalPrompt() {
        let trimmed = promptText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isGenerating else { return }
        submittedPromptText = trimmed
        promptText = ""
        Task { await generateSuggestions(userIntent: trimmed) }
    }

    private func submitGoalPrompt(_ prompt: String) {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isGenerating else { return }
        submittedPromptText = trimmed
        promptText = ""
        Task { await generateSuggestions(userIntent: trimmed) }
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(80))
            withAnimation(.easeOut(duration: 0.22)) {
                proxy.scrollTo("bottom", anchor: .bottom)
            }
        }
    }
}
