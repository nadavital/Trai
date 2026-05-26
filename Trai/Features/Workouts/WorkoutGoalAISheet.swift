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
    let onSaveGoals: ([WorkoutGoal]) -> Void

    @State private var aiService = AIService()
    @State private var promptText = ""
    @State private var isGenerating = false
    @State private var suggestions: [WorkoutGoalSuggestion] = []
    @State private var selectedSuggestionIDs: Set<String> = []
    @State private var presentedAccountSetupContext: AccountSetupContext?
    @State private var submittedPromptText: String?
    @State private var selectedSuggestionForDetail: WorkoutGoalSuggestion?
    @FocusState private var isInputFocused: Bool

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

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 14) {
                            traiPromptMessage

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

                Divider()

                SimpleChatInputBar(
                    text: $promptText,
                    placeholder: "Tell Trai what you want to work toward...",
                    isLoading: isGenerating,
                    onSend: submitGoalPrompt,
                    isFocused: $isInputFocused
                )
            }
            .navigationTitle("Set Goals with Trai")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    if !selectedGoals.isEmpty {
                        Button("Save", systemImage: "checkmark") {
                            onSaveGoals(selectedGoals)
                            HapticManager.success()
                            dismiss()
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
            WorkoutGoalSuggestionDetailSheet(
                suggestion: suggestion,
                isSelected: selectedSuggestionIDs.contains(suggestion.id),
                onToggle: { toggleSuggestion(suggestion) },
                onDone: { selectedSuggestionForDetail = nil }
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
                selectedSuggestionIDs = Set(initialSuggestions.map(\.id))
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
        HStack(alignment: .top, spacing: 10) {
            TraiLensView(size: 32, state: .answering, palette: .energy)

            VStack(alignment: .leading, spacing: 10) {
                Text("I’d track these.")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                VStack(spacing: 8) {
                    ForEach(suggestions) { suggestion in
                        WorkoutGoalSuggestionCard(
                            suggestion: suggestion,
                            isSelected: selectedSuggestionIDs.contains(suggestion.id),
                            onToggle: { toggleSuggestion(suggestion) },
                            onDetails: { selectedSuggestionForDetail = suggestion }
                        )
                    }
                }

                Button("Regenerate", systemImage: "arrow.clockwise") {
                    Task { await generateSuggestions() }
                }
                .font(.caption.weight(.semibold))
                .buttonStyle(.traiTertiary(size: .compact, height: 32))
            }
            .padding(12)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
        }
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
            selectedSuggestionIDs = Set(generated.map(\.id))
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

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(80))
            withAnimation(.easeOut(duration: 0.22)) {
                proxy.scrollTo("bottom", anchor: .bottom)
            }
        }
    }
}

private struct WorkoutGoalSuggestionCard: View {
    let suggestion: WorkoutGoalSuggestion
    let isSelected: Bool
    let onToggle: () -> Void
    let onDetails: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onDetails) {
                HStack(alignment: .center, spacing: 10) {
                    Image(systemName: suggestion.goalKind.iconName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.accent)
                        .frame(width: 28, height: 28)
                        .background(
                            Color.accentColor.opacity(isSelected ? 0.18 : 0.1),
                            in: Circle()
                        )

                    VStack(alignment: .leading, spacing: 3) {
                        Text(suggestion.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .lineLimit(2)

                        Text(suggestion.compactDetailText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            Button(action: onToggle) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary.opacity(0.45))
                    .frame(width: 34, height: 34)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isSelected ? "Remove goal" : "Select goal")
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            isSelected ? Color.accentColor.opacity(0.08) : Color(.tertiarySystemFill).opacity(0.55),
            in: RoundedRectangle(cornerRadius: 13, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(isSelected ? Color.accentColor.opacity(0.22) : Color.clear, lineWidth: 1)
        }
    }
}

private struct WorkoutGoalSuggestionDetailSheet: View {
    @Environment(\.dismiss) private var dismiss

    let suggestion: WorkoutGoalSuggestion
    let isSelected: Bool
    let onToggle: () -> Void
    let onDone: () -> Void

    private var goal: WorkoutGoal {
        suggestion.asWorkoutGoal()
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    headerCard
                    detailCard
                    selectionButton
                }
                .padding()
            }
            .navigationTitle("Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", systemImage: "checkmark") {
                        onDone()
                        dismiss()
                    }
                    .labelStyle(.iconOnly)
                    .tint(.accentColor)
                }
            }
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: goal.goalKind.iconName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.accent)
                    .frame(width: 34, height: 34)
                    .background(Color.accentColor.opacity(0.12), in: Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(goal.title)
                        .font(.headline.weight(.bold))
                        .fixedSize(horizontal: false, vertical: true)

                    if let trackingSummary = goal.trackingSummary {
                        Text(trackingSummary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if !suggestion.rationale.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(suggestion.rationale)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 16, style: .continuous))
    }

    private var detailCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !goal.trimmedSuccessCriteria.isEmpty {
                goalDetailRow(
                    title: "How Trai verifies it",
                    value: goal.trimmedSuccessCriteria,
                    icon: "checkmark.seal.fill"
                )
            }

            if let supportingSummary = goal.supportingSummary, supportingSummary != goal.trimmedSuccessCriteria {
                goalDetailRow(
                    title: "Notes",
                    value: supportingSummary,
                    icon: "text.bubble.fill"
                )
            }

            goalDetailRow(
                title: "Scope",
                value: goal.scopeSummary,
                icon: "scope"
            )

            if let horizonSummary = goal.horizonSummary, !horizonSummary.isEmpty {
                goalDetailRow(
                    title: "Timeline",
                    value: horizonSummary,
                    icon: "calendar"
                )
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 16, style: .continuous))
    }

    private var selectionButton: some View {
        Group {
            if isSelected {
                Button {
                    onToggle()
                } label: {
                    Label("Selected", systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.traiSecondary(color: Color.accentColor, fullWidth: true))
            } else {
                Button {
                    onToggle()
                } label: {
                    Label("Add Goal", systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.traiPrimary(fullWidth: true))
            }
        }
    }

    private func goalDetailRow(title: String, value: String, icon: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.accent)
                .frame(width: 20)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text(value)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private extension WorkoutGoalSuggestion {
    var compactDetailText: String {
        let goal = asWorkoutGoal()
        let trackingSummary = goal.trackingSummary
        let supportingSummary = goal.supportingSummary
        return [
            trackingSummary,
            goal.scopeSummary,
            supportingSummary == trackingSummary ? nil : supportingSummary,
            goal.horizonSummary
        ]
        .compactMap { $0 }
        .filter { !$0.isEmpty }
        .joined(separator: " • ")
    }
}
