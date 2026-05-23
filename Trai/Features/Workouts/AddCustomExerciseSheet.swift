//
//  AddCustomExerciseSheet.swift
//  Trai
//
//  Sheet for adding custom exercises with AI analysis
//

import SwiftUI

// MARK: - Add Custom Exercise Sheet

struct AddCustomExerciseSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AccountSessionService.self) private var accountSessionService: AccountSessionService?
    @Environment(MonetizationService.self) private var monetizationService: MonetizationService?
    @Environment(ProUpsellCoordinator.self) private var proUpsellCoordinator: ProUpsellCoordinator?

    let initialName: String
    let onSave: (String, String, [String], Exercise.MuscleGroup?, Exercise.Category, [String]?, [String], [Exercise.TrackingField]) -> Void

    @State private var exerciseName: String = ""
    @State private var activityTypeName: String = ""
    @State private var lastAutoActivityTypeName: String = ""
    @State private var selectedCategory: Exercise.Category = .strength
    @State private var selectedTargets: Set<String> = []
    @State private var selectedTrackingFields: Set<Exercise.TrackingField> = Set(Exercise.defaultTrackingFields(for: .strength))
    @State private var customTargetText = ""
    @State private var didChooseTrackingTemplate = false

    // AI Analysis state
    @State private var aiService = AIService()
    @State private var isAnalyzing = false
    @State private var analysisResult: ExerciseAnalysis?
    @State private var hasAnalyzed = false
    @State private var presentedAccountSetupContext: AccountSetupContext?
    @State private var isCategoryExpanded = false
    @State private var isTargetsExpanded = false
    @State private var isTrackingExpanded = false

    @FocusState private var isNameFocused: Bool

    private var canAccessExerciseAI: Bool {
        monetizationService?.canAccessAIFeatures ?? true
    }

    private var requiresAuthenticatedAccountForExerciseAI: Bool {
        accountSessionService?.isAuthenticated != true
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    exerciseSetupCard
                        .traiCard(cornerRadius: 16)

                    categoryDisclosure
                        .traiCard(cornerRadius: 16)

                    targetDisclosure
                        .traiCard(cornerRadius: 16)

                    trackingDisclosure
                        .traiCard(cornerRadius: 16)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("New Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Add", systemImage: "checkmark") {
                        onSave(
                            exerciseName,
                            resolvedActivityTypeName,
                            resolvedActivityAliases,
                            primaryMuscleGroup,
                            selectedCategory,
                            secondaryMuscleGroups,
                            Array(selectedTargets).sorted(),
                            orderedSelectedTrackingFields
                        )
                        HapticManager.success()
                        dismiss()
                    }
                    .labelStyle(.iconOnly)
                    .disabled(exerciseName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                exerciseName = initialName
                if let inferredCategory = Exercise.Category.normalized(from: initialName) {
                    selectedCategory = inferredCategory.userFacingEquivalent
                }
                resetDefaultsForSelectedCategory()
                if canAccessExerciseAI
                    && !requiresAuthenticatedAccountForExerciseAI
                    && !initialName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Task { await analyzeExercise() }
                } else {
                    isNameFocused = true
                }
            }
        }
        .sheet(item: $presentedAccountSetupContext) { context in
            AccountSetupView(context: context)
                .traiSheetBranding()
        }
        .traiSheetBranding()
        .proUpsellPresenter()
    }

    // MARK: - Name Input Card

    private var exerciseSetupCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Exercise or Activity", icon: "figure.run")

            TextField("e.g. Incline DB Press, Rowing, Bouldering", text: $exerciseName)
                .textInputAutocapitalization(.words)
                .font(.traiHeadline(18))
                .padding(12)
                .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                .focused($isNameFocused)
                .onChange(of: exerciseName) { _, _ in
                    if hasAnalyzed {
                        hasAnalyzed = false
                        analysisResult = nil
                    }
                    inferTrackingTemplateIfNeeded()
                    if shouldReplaceDefaultActivityName {
                        applyDefaultActivityTypeName()
                    }
                }

            VStack(alignment: .leading, spacing: 6) {
                Text("Activity")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                TextField("e.g. Climbing, Cycling, Mobility Flow", text: $activityTypeName)
                    .textInputAutocapitalization(.words)
                    .font(.traiLabel(15))
                    .padding(12)
                    .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                    .onChange(of: activityTypeName) { _, _ in
                        inferTrackingTemplateIfNeeded()
                    }
            }

            if !canAccessExerciseAI {
                lockedExerciseAnalysisCard
            } else {
                aiAnalysisCard
            }
        }
    }

    // MARK: - AI Analysis Card

    private var aiAnalysisCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            if isAnalyzing {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Analyzing exercise...")
                        .font(.traiHeadline(15))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(12)
                .background(TraiColors.brandAccent.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
            } else if let analysis = analysisResult {
                VStack(alignment: .leading, spacing: 10) {
                    Text(analysis.description)
                        .font(.traiHeadline(15))

                    if let tips = analysis.tips {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "lightbulb.fill")
                                .font(.traiLabel(12))
                                .foregroundStyle(.yellow)
                            Text(tips)
                                .font(.traiLabel(12))
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let secondary = analysis.secondaryMuscles, !secondary.isEmpty {
                        Text("Also works: \(secondary.joined(separator: ", "))")
                            .font(.traiLabel(12))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(12)
                .background(TraiColors.brandAccent.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
            } else {
                Button {
                    Task { await analyzeExercise() }
                } label: {
                    Label("Analyze with Trai", systemImage: "circle.hexagongrid.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.traiSecondary(color: TraiColors.brandAccent, fullWidth: true))
                .disabled(exerciseName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private var lockedExerciseAnalysisCard: some View {
        ProUpsellInlineCard(
            source: .exerciseAnalysis,
            title: "Let Trai set it up",
            message: "Identify the exercise, choose targets, and pick the right tracking fields automatically.",
            systemImage: "circle.hexagongrid.circle.fill",
            actionTitle: "Unlock Trai Pro",
            usesIconContainer: false
        ) {
            proUpsellCoordinator?.present(source: .exerciseAnalysis)
        }
    }

    // MARK: - Category Selector

    private var categoryPickerContent: some View {
        FlowLayout(spacing: 8) {
            ForEach(Exercise.Category.userFacingCases) { category in
                CategoryButton(
                    category: category,
                    isSelected: category.suggestionCategories.contains(selectedCategory)
                ) {
                    withAnimation(.snappy(duration: 0.2)) {
                        selectedCategory = category
                        didChooseTrackingTemplate = true
                        resetDefaultsForSelectedCategory()
                        HapticManager.selectionChanged()
                    }
                }
            }
        }
    }

    // MARK: - Target Selector

    private var targetPickerContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            FlowLayout(spacing: 8) {
                ForEach(visibleTargetOptions, id: \.self) { target in
                    TargetButton(
                        title: target,
                        isSelected: selectedTargets.contains(target)
                    ) {
                        withAnimation(.snappy(duration: 0.2)) {
                            if selectedTargets.contains(target) {
                                selectedTargets.remove(target)
                            } else {
                                selectedTargets.insert(target)
                            }
                            HapticManager.selectionChanged()
                        }
                    }
                }
            }

            HStack(spacing: 8) {
                TextField("Add a target", text: $customTargetText)
                    .textInputAutocapitalization(.words)
                    .font(.traiLabel(14))
                    .padding(.horizontal, 12)
                    .frame(height: 38)
                    .background(Color(.tertiarySystemBackground), in: Capsule())

                Button {
                    addCustomTarget()
                } label: {
                    Image(systemName: "plus")
                        .font(.traiLabel(13).weight(.semibold))
                        .frame(width: 38, height: 38)
                        .background(Color.accentColor.opacity(0.16), in: Circle())
                }
                .buttonStyle(.plain)
                .disabled(customTargetText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private var trackingFieldPickerContent: some View {
        FlowLayout(spacing: 8) {
            ForEach(Exercise.trackingFieldOptions(for: selectedCategory)) { field in
                TargetButton(
                    title: trackingFieldTitle(field),
                    icon: field.iconName,
                    isSelected: selectedTrackingFields.contains(field),
                    isDisabled: false
                ) {
                    withAnimation(.snappy(duration: 0.2)) {
                        if selectedTrackingFields.contains(field) {
                            selectedTrackingFields.remove(field)
                        } else {
                            selectedTrackingFields.insert(field)
                        }
                        HapticManager.selectionChanged()
                    }
                }
            }
        }
    }

    private var categoryDisclosure: some View {
        collapsibleManualSection(
            isExpanded: $isCategoryExpanded,
            title: "Logging Style",
            icon: "square.grid.2x2",
            summary: selectedCategory.userFacingEquivalent.displayName
        ) {
            categoryPickerContent
        }
    }

    private var targetDisclosure: some View {
        collapsibleManualSection(
            isExpanded: $isTargetsExpanded,
            title: "Targets",
            icon: selectedCategory.iconName,
            summary: selectedTargets.isEmpty ? "None selected" : selectedTargets.sorted().prefix(3).joined(separator: ", ")
        ) {
            targetPickerContent
        }
    }

    private var trackingDisclosure: some View {
        collapsibleManualSection(
            isExpanded: $isTrackingExpanded,
            title: "Track",
            icon: "slider.horizontal.3",
            summary: orderedSelectedTrackingFields.map(trackingFieldTitle).joined(separator: ", ")
        ) {
            trackingFieldPickerContent
        }
    }

    private func collapsibleManualSection<Content: View>(
        isExpanded: Binding<Bool>,
        title: String,
        icon: String,
        summary: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.snappy(duration: 0.2)) {
                    isExpanded.wrappedValue.toggle()
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: icon)
                        .font(.subheadline)
                        .foregroundStyle(.accent)
                        .frame(width: 28, height: 28)
                        .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.traiHeadline())
                            .foregroundStyle(.primary)
                        Text(summary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    Image(systemName: isExpanded.wrappedValue ? "chevron.up" : "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded.wrappedValue {
                content()
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private func sectionHeader(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.traiHeadline())
            .foregroundStyle(.primary)
    }

    // MARK: - Analysis

    private func analyzeExercise() async {
        let name = exerciseName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        guard !requiresAuthenticatedAccountForExerciseAI else {
            presentedAccountSetupContext = .aiFeatures
            return
        }
        guard canAccessExerciseAI else {
            proUpsellCoordinator?.present(source: .exerciseAnalysis)
            return
        }

        isAnalyzing = true
        defer { isAnalyzing = false }

        do {
            let analysis = try await aiService.analyzeExercise(name: name)
            analysisResult = analysis
            hasAnalyzed = true

            withAnimation(.snappy(duration: 0.2)) {
                if let category = Exercise.Category.normalized(from: analysis.category) {
                    selectedCategory = category.userFacingEquivalent
                    resetDefaultsForSelectedCategory()
                }

                if let analyzedActivityType = analysis.activityTypeName?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !analyzedActivityType.isEmpty {
                    activityTypeName = analyzedActivityType
                    lastAutoActivityTypeName = ""
                } else {
                    applyDefaultActivityTypeName()
                }

                if let targetTags = analysis.targetTags, !targetTags.isEmpty {
                    selectedTargets = Set(targetTags.map(Self.displayTargetTag))
                }

                if let fields = analysis.trackingFields?
                    .compactMap(Exercise.TrackingField.init(rawValue:)),
                   !fields.isEmpty {
                    selectedTrackingFields = Set(Exercise.normalizedTrackingFields(fields, for: selectedCategory))
                }

                if let muscleGroupStr = analysis.muscleGroup,
                   let muscleGroup = Exercise.MuscleGroup(rawValue: muscleGroupStr) {
                    selectedTargets.insert(muscleGroup.displayName)
                }
            }
        } catch {
            print("Exercise analysis failed: \(error)")
        }
    }

    private var primaryMuscleGroup: Exercise.MuscleGroup? {
        selectedMuscleTargets.first
    }

    private var secondaryMuscleGroups: [String]? {
        guard selectedCategory == .strength else { return nil }
        let secondary = selectedMuscleTargets.dropFirst().map(\.rawValue)
        if !secondary.isEmpty {
            return Array(secondary)
        }

        let rawAnalyzed = analysisResult?.secondaryMuscles?
            .compactMap(Self.normalizedMuscleGroupRawValue) ?? []
        let analyzed = Self.dedupedNormalizedValues(rawAnalyzed)
        return analyzed.isEmpty ? nil : analyzed
    }

    private var selectedMuscleTargets: [Exercise.MuscleGroup] {
        selectedTargets
            .compactMap { target in
                Exercise.MuscleGroup.allCases.first { $0.displayName == target || $0.rawValue == target }
            }
            .sorted { $0.displayName < $1.displayName }
    }

    private var orderedSelectedTrackingFields: [Exercise.TrackingField] {
        let selected = Exercise.trackingFieldOptions(for: selectedCategory).filter { selectedTrackingFields.contains($0) }
        return Exercise.normalizedTrackingFields(selected, for: selectedCategory)
    }

    private var resolvedActivityTypeName: String {
        let explicit = activityTypeName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard explicit.isEmpty else { return explicit }
        return Exercise.defaultActivityTypeName(for: exerciseName, category: selectedCategory)
    }

    private var resolvedActivityAliases: [String] {
        analysisResult?.activityAliases?
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty } ?? []
    }

    private var visibleTargetOptions: [String] {
        let defaults = Exercise.targetOptions(for: selectedCategory)
        let extra = selectedTargets
            .filter { !defaults.contains($0) }
            .sorted()
        return defaults + extra
    }

    private func resetDefaultsForSelectedCategory() {
        let defaults = Exercise.defaultTargetTags(for: selectedCategory)
        selectedTargets = Set(defaults)
        selectedTrackingFields = Set(Exercise.defaultTrackingFields(for: selectedCategory))
        if shouldReplaceDefaultActivityName {
            applyDefaultActivityTypeName()
        }
    }

    private var shouldReplaceDefaultActivityName: Bool {
        let trimmed = activityTypeName.trimmingCharacters(in: .whitespacesAndNewlines)
        let lastAuto = lastAutoActivityTypeName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty
            || (!lastAuto.isEmpty && trimmed.goalNormalizedKey == lastAuto.goalNormalizedKey)
            || trimmed == Exercise.defaultActivityTypeName(for: exerciseName, category: .strength)
            || Exercise.Category.userFacingCases.contains { category in
                trimmed == category.displayName || trimmed == category.trackingTemplateName
            }
    }

    private func applyDefaultActivityTypeName() {
        let value = Exercise.defaultActivityTypeName(for: exerciseName, category: selectedCategory)
        activityTypeName = value
        lastAutoActivityTypeName = value
    }

    private func inferTrackingTemplateIfNeeded() {
        guard !didChooseTrackingTemplate else { return }
        let inferredCategory = [activityTypeName, exerciseName]
            .compactMap(Exercise.Category.normalized(from:))
            .first?
            .userFacingEquivalent
        guard let inferredCategory,
            inferredCategory != selectedCategory else {
            return
        }
        selectedCategory = inferredCategory
        resetDefaultsForSelectedCategory()
    }

    private func addCustomTarget() {
        let target = Self.displayTargetTag(customTargetText)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !target.isEmpty else { return }
        withAnimation(.snappy(duration: 0.2)) {
            selectedTargets.insert(target)
            customTargetText = ""
        }
        HapticManager.selectionChanged()
    }

    private func trackingFieldTitle(_ field: Exercise.TrackingField) -> String {
        if field == .sets, selectedCategory != .strength {
            return "Segments"
        }
        guard field == .reps else { return field.displayName }
        switch selectedCategory {
        case .cardio, .mobility, .flexibility, .recovery:
            return "Reps"
        case .conditioning:
            return "Rounds"
        case .skill, .sportPractice:
            return "Attempts"
        case .custom:
            return "Reps"
        default:
            return field.displayName
        }
    }

    nonisolated private static func displayTargetTag(_ tag: String) -> String {
        tag
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .split(separator: " ")
            .map { word in
                word.prefix(1).uppercased() + word.dropFirst()
            }
            .joined(separator: " ")
    }

    nonisolated private static func normalizedMuscleGroupRawValue(_ value: String) -> String? {
        let normalized = Exercise.normalizedActivityKey(value)
        return Exercise.MuscleGroup.allCases.first { muscle in
            Exercise.normalizedActivityKey(muscle.rawValue) == normalized
                || Exercise.normalizedActivityKey(displayName(for: muscle)) == normalized
        }?.rawValue
    }

    nonisolated private static func displayName(for muscle: Exercise.MuscleGroup) -> String {
        switch muscle {
        case .chest: "Chest"
        case .back: "Back"
        case .shoulders: "Shoulders"
        case .biceps: "Biceps"
        case .triceps: "Triceps"
        case .legs: "Legs"
        case .core: "Core"
        case .fullBody: "Full Body"
        }
    }

    nonisolated private static func dedupedNormalizedValues(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for value in values {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            let key = Exercise.normalizedActivityKey(trimmed)
            guard !trimmed.isEmpty, !key.isEmpty, seen.insert(key).inserted else { continue }
            result.append(trimmed)
        }
        return result
    }
}

// MARK: - Category Button

private struct CategoryButton: View {
    let category: Exercise.Category
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            label
                .padding(.horizontal, 12)
                .frame(height: 38)
                .frame(maxWidth: 180)
                .background(
                    isSelected ? Color.accentColor.opacity(0.18) : Color(.tertiarySystemFill),
                    in: Capsule()
                )
                .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
        }
        .buttonStyle(.plain)
    }

    private var label: some View {
        HStack(spacing: 6) {
            Image(systemName: category.iconName)
                .font(.traiLabel(12))
            Text(category.displayName)
                .font(.traiLabel(12))
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }
}

// MARK: - Muscle Button

private struct TargetButton: View {
    let title: String
    var icon: String?
    let isSelected: Bool
    var isDisabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            label
                .padding(.horizontal, 12)
                .frame(height: 36)
                .frame(maxWidth: 190)
                .background(
                    isSelected ? Color.accentColor.opacity(0.18) : Color(.tertiarySystemFill),
                    in: Capsule()
                )
                .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.45 : 1)
    }

    private var label: some View {
        HStack(spacing: 6) {
            if let icon {
                Image(systemName: icon)
                    .font(.traiLabel(13))
            }
            Text(title)
                .font(.traiLabel(11))
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }
}
