//
//  ExerciseListView.swift
//  Trai
//
//  Exercise selection with search, filters, and recent exercises
//

import SwiftUI
import SwiftData

private enum ExerciseSelectionPerformanceConfig {
    static let usageHistorySampleLimit = 400
}

struct ExerciseListView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AccountSessionService.self) private var accountSessionService: AccountSessionService?
    @Environment(MonetizationService.self) private var monetizationService: MonetizationService?
    @Environment(ProUpsellCoordinator.self) private var proUpsellCoordinator: ProUpsellCoordinator?
    @Query(sort: \Exercise.name) private var exercises: [Exercise]

    // Selection callback
    private let onSelect: ((Exercise) -> Void)?
    @Binding private var selectedExercise: Exercise?

    // Target muscle groups and activity categories from current workout (for prioritized sorting)
    private let targetMuscleGroups: [Exercise.MuscleGroup]
    private let targetActivityCategories: [Exercise.Category]
    private let targetActivityTypes: [String]

    // Search and filter state
    @State private var searchText = ""
    @State private var selectedCategory: Exercise.Category?
    @State private var selectedMuscleGroup: Exercise.MuscleGroup?
    @State private var selectedActivityTypeFilter: String?
    @State private var showingAddCustom = false
    @State private var customExerciseName = ""

    // Photo identification state
    @State private var showingCamera = false
    @State private var showingEquipmentResult = false
    @State private var equipmentAnalysis: ExercisePhotoAnalysis?
    @State private var pendingEquipmentResultPresentation = false
    @State private var equipmentResultPresentationTask: Task<Void, Never>?
    @State private var isAnalyzingPhoto = false
    @State private var photoAnalysisError: String?
    @State private var lastCapturedImageData: Data?
    @State private var usageSummaryCache: UsageSummary = .empty
    @State private var usageSummaryFingerprint: UsageSummaryFingerprint?
    @State private var pendingCustomExerciseCreation: PendingCustomExerciseCreation?
    @State private var presentedAccountSetupContext: AccountSetupContext?

    // MARK: - Initializers

    /// Closure-based initializer for adding exercises to workouts
    init(
        targetMuscleGroups: [Exercise.MuscleGroup] = [],
        targetActivityCategories: [Exercise.Category] = [],
        targetActivityTypes: [String] = [],
        onSelect: @escaping (Exercise) -> Void
    ) {
        self.targetMuscleGroups = targetMuscleGroups
        self.targetActivityCategories = targetActivityCategories
        self.targetActivityTypes = targetActivityTypes
        self.onSelect = onSelect
        self._selectedExercise = .constant(nil)
        self._selectedCategory = State(initialValue: Self.initialCategory(
            targetMuscleGroups: targetMuscleGroups,
            targetActivityCategories: targetActivityCategories,
            targetActivityTypes: targetActivityTypes
        ))
        self._selectedActivityTypeFilter = State(initialValue: Self.initialActivityTypeFilter(targetActivityTypes))
    }

    /// Binding-based initializer for form selection
    init(selectedExercise: Binding<Exercise?>) {
        self.targetMuscleGroups = []
        self.targetActivityCategories = []
        self.targetActivityTypes = []
        self.onSelect = nil
        self._selectedExercise = selectedExercise
    }

    // MARK: - View Data

    private struct UsageSummary {
        let usageFrequencyByExerciseName: [String: Int]
        let mostRecentUsageByExerciseName: [String: Date]
        let recentExerciseNames: [String]

        static let empty = UsageSummary(
            usageFrequencyByExerciseName: [:],
            mostRecentUsageByExerciseName: [:],
            recentExerciseNames: []
        )
    }

    private struct ListData {
        let filteredExercises: [Exercise]
        let recentExercises: [Exercise]
        let exercisesByMuscleGroup: [Exercise.MuscleGroup: [Exercise]]
        let sortedMuscleGroups: [Exercise.MuscleGroup]
        let noMuscleGroupExercises: [Exercise]
        let showCustomOption: Bool
    }

    private struct UsageSummaryFingerprint: Equatable {
        let historyCount: Int
        let newestPerformedAt: Date?
    }

    private struct PendingCustomExerciseCreation {
        let name: String
        let activityTypeName: String
        let activityAliases: [String]
        let muscleGroup: Exercise.MuscleGroup?
        let category: Exercise.Category
        let secondaryMuscles: [String]?
        let targetTags: [String]
        let trackingFields: [Exercise.TrackingField]
    }

    private var targetMusclePriority: [Exercise.MuscleGroup: Int] {
        var priority: [Exercise.MuscleGroup: Int] = [:]
        for (index, muscle) in targetMuscleGroups.enumerated() {
            priority[muscle] = min(priority[muscle] ?? index, index)
        }
        return priority
    }

    private var targetCategoryPriority: [Exercise.Category: Int] {
        var priority: [Exercise.Category: Int] = [:]
        for (index, category) in targetActivityCategories.enumerated() {
            for suggestionCategory in category.suggestionCategories {
                priority[suggestionCategory] = min(priority[suggestionCategory] ?? index, index)
            }
        }
        return priority
    }

    private var targetActivityTypePriority: [String: Int] {
        var priority: [String: Int] = [:]
        for (index, activityType) in targetActivityTypes.enumerated() {
            let key = Exercise.normalizedActivityKey(activityType)
            guard !key.isEmpty else { continue }
            priority[key] = min(priority[key] ?? index, index)
        }
        return priority
    }

    private static func initialCategory(
        targetMuscleGroups: [Exercise.MuscleGroup],
        targetActivityCategories: [Exercise.Category],
        targetActivityTypes: [String]
    ) -> Exercise.Category? {
        if !targetActivityTypes.isEmpty {
            return nil
        }
        return targetActivityCategories.first
    }

    private static func initialActivityTypeFilter(_ targetActivityTypes: [String]) -> String? {
        let trimmed = targetActivityTypes.first?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private var muscleGroupDefaultOrder: [Exercise.MuscleGroup: Int] {
        Dictionary(uniqueKeysWithValues: Exercise.MuscleGroup.allCases.enumerated().map { ($1, $0) })
    }

    private func buildUsageSummary(from history: [ExerciseHistory]) -> UsageSummary {
        guard !history.isEmpty else { return .empty }
        var usageFrequencyByExerciseName: [String: Int] = [:]
        var mostRecentUsageByExerciseName: [String: Date] = [:]
        var recentExerciseNames: [String] = []
        var seenRecentNames = Set<String>()

        for entry in history.prefix(ExerciseSelectionPerformanceConfig.usageHistorySampleLimit) {
            usageFrequencyByExerciseName[entry.exerciseName, default: 0] += 1
            if mostRecentUsageByExerciseName[entry.exerciseName] == nil {
                mostRecentUsageByExerciseName[entry.exerciseName] = entry.performedAt
            }
            if seenRecentNames.insert(entry.exerciseName).inserted, recentExerciseNames.count < 5 {
                recentExerciseNames.append(entry.exerciseName)
            }
        }

        return UsageSummary(
            usageFrequencyByExerciseName: usageFrequencyByExerciseName,
            mostRecentUsageByExerciseName: mostRecentUsageByExerciseName,
            recentExerciseNames: recentExerciseNames
        )
    }

    private func refreshUsageSummaryIfNeeded(force: Bool = false) {
        var descriptor = FetchDescriptor<ExerciseHistory>(
            sortBy: [SortDescriptor(\.performedAt, order: .reverse)]
        )
        descriptor.fetchLimit = ExerciseSelectionPerformanceConfig.usageHistorySampleLimit
        let sampledHistory = (try? modelContext.fetch(descriptor)) ?? []
        let fingerprint = UsageSummaryFingerprint(
            historyCount: sampledHistory.count,
            newestPerformedAt: sampledHistory.first?.performedAt
        )
        guard force || fingerprint != usageSummaryFingerprint else { return }
        usageSummaryCache = buildUsageSummary(from: sampledHistory)
        usageSummaryFingerprint = fingerprint
    }

    private func makeListData() -> ListData {
        let usageSummary = usageSummaryCache
        let targetPriority = targetMusclePriority
        let categoryPriority = targetCategoryPriority
        let activityTypePriority = targetActivityTypePriority
        let muscleOrder = muscleGroupDefaultOrder

        var result = exercises

        // Apply search filter across visible names plus semantic aliases/tags.
        if !searchText.isEmpty {
            result = result.filter { exercise in
                exercise.name.localizedStandardContains(searchText) ||
                exercise.activityTypeName.localizedStandardContains(searchText) ||
                exercise.activityAliases.contains { $0.localizedStandardContains(searchText) } ||
                exercise.targetTags.contains { $0.localizedStandardContains(searchText) } ||
                (exercise.equipmentName?.localizedStandardContains(searchText) ?? false)
            }
        }

        // Apply category filter
        if let category = selectedCategory {
            result = result.filter { category.suggestionCategories.contains($0.exerciseCategory) }
        }

        // Apply user-facing activity type filter. This is intentionally independent
        // from the broad fallback category so custom types like climbing, boxing,
        // rowing, or sport-specific practice can behave like first-class targets.
        if let selectedActivityTypeFilter {
            let key = Exercise.normalizedActivityKey(selectedActivityTypeFilter)
            if !key.isEmpty {
                result = result.filter { $0.activityMatchingTokens.contains(key) }
            }
        }

        // Apply muscle group filter
        if let muscleGroup = selectedMuscleGroup {
            result = result.filter { $0.targetMuscleGroup == muscleGroup }
        }

        result.sort { a, b in
            let aTargetPriority = a.targetMuscleGroup.flatMap { targetPriority[$0] } ?? Int.max
            let bTargetPriority = b.targetMuscleGroup.flatMap { targetPriority[$0] } ?? Int.max
            if aTargetPriority != bTargetPriority { return aTargetPriority < bTargetPriority }

            let aActivityTypePriority = bestActivityTypePriority(for: a, priorities: activityTypePriority)
            let bActivityTypePriority = bestActivityTypePriority(for: b, priorities: activityTypePriority)
            if aActivityTypePriority != bActivityTypePriority { return aActivityTypePriority < bActivityTypePriority }

            let aCategoryPriority = categoryPriority[a.exerciseCategory] ?? Int.max
            let bCategoryPriority = categoryPriority[b.exerciseCategory] ?? Int.max
            if aCategoryPriority != bCategoryPriority { return aCategoryPriority < bCategoryPriority }

            // Keep section ordering stable by using muscle default order.
            let aMuscleOrder = a.targetMuscleGroup.flatMap { muscleOrder[$0] } ?? Int.max
            let bMuscleOrder = b.targetMuscleGroup.flatMap { muscleOrder[$0] } ?? Int.max
            if aMuscleOrder != bMuscleOrder { return aMuscleOrder < bMuscleOrder }

            // Then prioritize most recently performed exercises.
            let aRecent = usageSummary.mostRecentUsageByExerciseName[a.name] ?? .distantPast
            let bRecent = usageSummary.mostRecentUsageByExerciseName[b.name] ?? .distantPast
            if aRecent != bRecent { return aRecent > bRecent }

            // Then by usage frequency.
            let aFreq = usageSummary.usageFrequencyByExerciseName[a.name] ?? 0
            let bFreq = usageSummary.usageFrequencyByExerciseName[b.name] ?? 0
            if aFreq != bFreq { return aFreq > bFreq }

            // Finally alphabetically.
            return a.name < b.name
        }

        var exercisesByMuscleGroup: [Exercise.MuscleGroup: [Exercise]] = [:]
        var noMuscleGroupExercises: [Exercise] = []
        let targetRawValues = Set(targetMuscleGroups.map(\.rawValue))
        let targetExerciseCategories = Set(targetActivityCategories.flatMap(\.suggestionCategories))
        let targetActivityTypeKeys = Set(targetActivityTypes.map(Exercise.normalizedActivityKey).filter { !$0.isEmpty })
        let exerciseByName = exercises.reduce(into: [String: Exercise]()) { result, exercise in
            if result[exercise.name] == nil {
                result[exercise.name] = exercise
            }
        }

        let recentExercises = usageSummary.recentExerciseNames.compactMap { name -> Exercise? in
            guard let exercise = exerciseByName[name] else { return nil }
            guard !targetRawValues.isEmpty || !targetExerciseCategories.isEmpty || !targetActivityTypeKeys.isEmpty else { return exercise }
            if !targetActivityTypeKeys.isDisjoint(with: exercise.activityMatchingTokens) {
                return exercise
            }
            if targetExerciseCategories.contains(exercise.exerciseCategory) {
                return exercise
            }
            guard let muscleGroup = exercise.muscleGroup else { return nil }
            return targetRawValues.contains(muscleGroup) ? exercise : nil
        }

        for exercise in result {
            if let muscleGroup = exercise.targetMuscleGroup {
                exercisesByMuscleGroup[muscleGroup, default: []].append(exercise)
            } else {
                noMuscleGroupExercises.append(exercise)
            }
        }

        let sortedMuscleGroups = Array(exercisesByMuscleGroup.keys).sorted { a, b in
            let aPriority = targetPriority[a] ?? Int.max
            let bPriority = targetPriority[b] ?? Int.max
            if aPriority != bPriority { return aPriority < bPriority }

            let aOrder = muscleOrder[a] ?? Int.max
            let bOrder = muscleOrder[b] ?? Int.max
            if aOrder != bOrder { return aOrder < bOrder }

            return a.displayName < b.displayName
        }

        return ListData(
            filteredExercises: result,
            recentExercises: recentExercises,
            exercisesByMuscleGroup: exercisesByMuscleGroup,
            sortedMuscleGroups: sortedMuscleGroups,
            noMuscleGroupExercises: noMuscleGroupExercises,
            showCustomOption: !searchText.isEmpty && result.isEmpty
        )
    }

    private func bestActivityTypePriority(for exercise: Exercise, priorities: [String: Int]) -> Int {
        exercise.activityMatchingTokens
            .compactMap { priorities[$0] }
            .min() ?? Int.max
    }

    private var muscleGroupsForFilterChips: [Exercise.MuscleGroup] {
        let grouped = exercises.reduce(into: Set<Exercise.MuscleGroup>()) { partialResult, exercise in
            if let group = exercise.targetMuscleGroup {
                partialResult.insert(group)
            }
        }

        let targetPriority = targetMusclePriority
        let muscleOrder = muscleGroupDefaultOrder
        return grouped.sorted { a, b in
            let aPriority = targetPriority[a] ?? Int.max
            let bPriority = targetPriority[b] ?? Int.max
            if aPriority != bPriority { return aPriority < bPriority }

            let aOrder = muscleOrder[a] ?? Int.max
            let bOrder = muscleOrder[b] ?? Int.max
            if aOrder != bOrder { return aOrder < bOrder }
            return a.displayName < b.displayName
        }
    }

    private var quickAddCategory: Exercise.Category {
        if let selectedCategory {
            return selectedCategory
        }

        if let activityType = quickAddActivityTypeName {
            let key = Exercise.normalizedActivityKey(activityType)
            if let matchingExercise = exercises.first(where: { $0.activityMatchingTokens.contains(key) }) {
                return matchingExercise.exerciseCategory.userFacingEquivalent
            }
            if let inferred = Exercise.Category.normalized(from: activityType) {
                return inferred.userFacingEquivalent
            }
        }

        return .strength
    }

    private var quickAddActivityTypeName: String? {
        let trimmed = selectedActivityTypeFilter?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private var quickAddMuscleGroup: Exercise.MuscleGroup? {
        guard quickAddCategory == .strength else { return nil }
        return selectedMuscleGroup ?? targetMuscleGroups.first
    }

    private var activityTypesForFilterChips: [String] {
        let targetKeys = targetActivityTypePriority
        var bestNameByKey: [String: String] = [:]
        for exercise in exercises where exercise.exerciseCategory != .strength {
            let title = exercise.activityTypeName.trimmingCharacters(in: .whitespacesAndNewlines)
            let key = Exercise.normalizedActivityKey(title)
            guard !title.isEmpty, !key.isEmpty else { continue }
            if bestNameByKey[key] == nil {
                bestNameByKey[key] = title
            }
        }

        return bestNameByKey
            .values
            .sorted { lhs, rhs in
                let lhsPriority = targetKeys[Exercise.normalizedActivityKey(lhs)] ?? Int.max
                let rhsPriority = targetKeys[Exercise.normalizedActivityKey(rhs)] ?? Int.max
                if lhsPriority != rhsPriority { return lhsPriority < rhsPriority }
                return lhs.localizedStandardCompare(rhs) == .orderedAscending
            }
            .prefix(14)
            .map { $0 }
    }

    private var canAccessExerciseAI: Bool {
        monetizationService?.canAccessAIFeatures ?? true
    }

    private var requiresAuthenticatedAccountForExerciseAI: Bool {
        accountSessionService?.isAuthenticated != true
    }

    // MARK: - Body

    var body: some View {
        let listData = makeListData()

        NavigationStack {
            VStack(spacing: 0) {
                // Filter chips
                filterSection(muscleGroups: muscleGroupsForFilterChips)

                List {
                    if exercises.isEmpty {
                        Section {
                            ContentUnavailableView(
                                "No Exercises Yet",
                                systemImage: "dumbbell.fill",
                                description: Text("Trai is preparing your exercise library.")
                            )
                        }
                    } else {
                        // Create custom exercise option (always available at top)
                        Section {
                            Button {
                                showingAddCustom = true
                            } label: {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundStyle(.accent)
                                    Text("Create Custom Exercise")
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .foregroundStyle(.primary)

                            Button {
                                if requiresAuthenticatedAccountForExerciseAI {
                                    presentedAccountSetupContext = .aiFeatures
                                } else if canAccessExerciseAI {
                                    showingCamera = true
                                } else {
                                    proUpsellCoordinator?.present(source: .exerciseAnalysis)
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "camera.fill")
                                        .foregroundStyle(.accent)
                                    Text("Identify Exercise from Photo")
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .foregroundStyle(.primary)
                            .disabled(isAnalyzingPhoto)
                        }

                        // Option to add searched exercise directly
                        if listData.showCustomOption {
                            Section {
                                Button {
                                    addCustomExercise(
                                        name: searchText,
                                        activityTypeName: quickAddActivityTypeName,
                                        muscleGroup: quickAddMuscleGroup,
                                        category: quickAddCategory
                                    )
                                } label: {
                                    HStack {
                                        Image(systemName: "plus.circle")
                                            .foregroundStyle(.accent)
                                        Text("Add \"\(searchText)\"")
                                        Spacer()
                                    }
                                }
                                .foregroundStyle(.primary)
                            } header: {
                                Text("Not in list?")
                            }
                        }

                        // Recent exercises section
                        if searchText.isEmpty,
                           selectedCategory == nil,
                           selectedMuscleGroup == nil,
                           selectedActivityTypeFilter == nil,
                           !listData.recentExercises.isEmpty {
                            Section {
                                ForEach(listData.recentExercises) { exercise in
                                    exerciseRow(exercise)
                                }
                            } header: {
                                Label("Recently Used", systemImage: "clock.arrow.circlepath")
                            }
                        }

                        // Exercises by muscle group (primary grouping)
                        ForEach(listData.sortedMuscleGroups) { muscleGroup in
                            if let muscleExercises = listData.exercisesByMuscleGroup[muscleGroup], !muscleExercises.isEmpty {
                                Section {
                                    ForEach(muscleExercises) { exercise in
                                        exerciseRow(exercise)
                                    }
                                } header: {
                                    Label(muscleGroup.displayName, systemImage: muscleGroup.iconName)
                                }
                            }
                        }

                        // Show exercises without muscle group (cardio, etc.)
                        if !listData.noMuscleGroupExercises.isEmpty {
                            Section {
                                ForEach(listData.noMuscleGroupExercises) { exercise in
                                    exerciseRow(exercise)
                                }
                            } header: {
                                Label(
                                    selectedActivityTypeFilter ?? selectedCategory?.displayName ?? "Activities",
                                    systemImage: selectedCategory?.iconName ?? "figure.mixed.cardio"
                                )
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search exercises")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingAddCustom) {
                AddCustomExerciseSheet(
                    initialName: searchText,
                    onSave: { name, activityTypeName, activityAliases, muscleGroup, category, secondaryMuscles, targetTags, trackingFields in
                        queueCustomExerciseCreation(
                            name: name,
                            activityTypeName: activityTypeName,
                            activityAliases: activityAliases,
                            muscleGroup: muscleGroup,
                            category: category,
                            secondaryMuscles: secondaryMuscles,
                            targetTags: targetTags,
                            trackingFields: trackingFields
                        )
                    }
                )
                .traiSheetBranding()
            }
            .fullScreenCover(isPresented: $showingCamera) {
                EquipmentCameraView { imageData in
                    showingEquipmentResult = false
                    pendingEquipmentResultPresentation = false
                    equipmentResultPresentationTask?.cancel()
                    showingCamera = false
                    lastCapturedImageData = imageData
                    Task { await analyzeEquipmentPhoto(imageData) }
                }
                .traiSheetBranding()
            }
            .alert("Equipment Analysis Failed", isPresented: .init(
                get: { photoAnalysisError != nil },
                set: { if !$0 { photoAnalysisError = nil } }
            )) {
                if lastCapturedImageData != nil {
                    Button("Try Again") {
                        if let imageData = lastCapturedImageData {
                            Task { await analyzeEquipmentPhoto(imageData) }
                        }
                    }
                }
                Button("Take New Photo") {
                    photoAnalysisError = nil
                    showingEquipmentResult = false
                    pendingEquipmentResultPresentation = false
                    equipmentAnalysis = nil
                    equipmentResultPresentationTask?.cancel()
                    showingCamera = true
                }
                Button("Cancel", role: .cancel) {
                    photoAnalysisError = nil
                }
            } message: {
                Text(photoAnalysisError ?? "Unable to identify the exercise. Try taking a clearer photo.")
            }
            .sheet(isPresented: $showingEquipmentResult) {
                if let analysis = equipmentAnalysis {
                    EquipmentAnalysisSheet(
                        analysis: analysis,
                        onSelectExercise: { suggestion, equipmentName in
                            let category = suggestion.resolvedCategory(equipmentName: equipmentName)
                            addCustomExercise(
                                name: suggestion.name,
                                activityTypeName: suggestion.resolvedActivityTypeName(category: category, equipmentName: equipmentName),
                                activityAliases: suggestion.activityAliases ?? [],
                                muscleGroup: suggestion.muscleGroup.flatMap(Exercise.MuscleGroup.init(rawValue:)),
                                category: category,
                                equipmentName: equipmentName,
                                targetTags: suggestion.targetTags ?? [],
                                trackingFields: suggestion.resolvedTrackingFields(category: category)
                            )
                        }
                    )
                    .traiSheetBranding()
                }
            }
            .sheet(item: $presentedAccountSetupContext) { context in
                AccountSetupView(context: context)
                    .traiSheetBranding()
            }
            .overlay {
                // Photo analysis loading overlay
                if isAnalyzingPhoto {
                    ZStack {
                        Color.black.opacity(0.4)
                            .ignoresSafeArea()
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                                .tint(.white)
                            Text("Analyzing exercise...")
                                .font(.headline)
                                .foregroundStyle(.white)
                            Text("Identifying tracking and setup details")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        .padding(32)
                        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
                    }
                }
            }
            .onAppear {
                ExerciseLibrarySeeder.ensureDefaults(in: modelContext)
                refreshUsageSummaryIfNeeded(force: true)
            }
            .onChange(of: showingCamera) { _, isShowing in
                guard !isShowing else { return }
                presentPendingEquipmentResultIfNeeded()
            }
            .onChange(of: showingAddCustom) { _, isShowing in
                guard !isShowing, let pendingCustomExerciseCreation else { return }
                self.pendingCustomExerciseCreation = nil
                addCustomExercise(
                    name: pendingCustomExerciseCreation.name,
                    activityTypeName: pendingCustomExerciseCreation.activityTypeName,
                    activityAliases: pendingCustomExerciseCreation.activityAliases,
                    muscleGroup: pendingCustomExerciseCreation.muscleGroup,
                    category: pendingCustomExerciseCreation.category,
                    secondaryMuscles: pendingCustomExerciseCreation.secondaryMuscles,
                    targetTags: pendingCustomExerciseCreation.targetTags,
                    trackingFields: pendingCustomExerciseCreation.trackingFields
                )
            }
            .onDisappear {
                equipmentResultPresentationTask?.cancel()
            }
            .accessibilityIdentifier("exerciseListView")
        }
        .traiSheetBranding()
    }

    // MARK: - Photo Analysis

    private func analyzeEquipmentPhoto(_ imageData: Data) async {
        guard !requiresAuthenticatedAccountForExerciseAI else {
            presentedAccountSetupContext = .aiFeatures
            return
        }
        guard canAccessExerciseAI else {
            proUpsellCoordinator?.present(source: .exerciseAnalysis)
            return
        }

        isAnalyzingPhoto = true
        defer { isAnalyzingPhoto = false }

        let aiService = AIService()

        // Pass existing exercise names so the AI service can match to them
        let existingNames = exercises.map(\.name)

        do {
            let analysis = try await aiService.analyzeExercisePhoto(
                imageData: imageData,
                existingExerciseNames: existingNames
            )
            equipmentAnalysis = analysis
            pendingEquipmentResultPresentation = true
            presentPendingEquipmentResultIfNeeded()
            HapticManager.success()
        } catch {
            HapticManager.error()
            pendingEquipmentResultPresentation = false
            equipmentResultPresentationTask?.cancel()
            photoAnalysisError = "Couldn't identify the exercise. Make sure the movement, equipment, or label is clearly visible and try again."
        }
    }

    @MainActor
    private func presentPendingEquipmentResultIfNeeded() {
        guard pendingEquipmentResultPresentation, !showingCamera, equipmentAnalysis != nil else {
            return
        }

        equipmentResultPresentationTask?.cancel()
        equipmentResultPresentationTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled, !showingCamera, equipmentAnalysis != nil else { return }
            pendingEquipmentResultPresentation = false
            showingEquipmentResult = true
        }
    }

    // MARK: - Filter Section

    private func filterSection(muscleGroups: [Exercise.MuscleGroup]) -> some View {
        let activityTypes = activityTypesForFilterChips

        return VStack(spacing: 0) {
            if !activityTypes.isEmpty && selectedMuscleGroup == nil {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        FilterChip(
                            label: "All",
                            isSelected: selectedCategory == nil && selectedMuscleGroup == nil && selectedActivityTypeFilter == nil
                        ) {
                            selectedCategory = nil
                            selectedMuscleGroup = nil
                            selectedActivityTypeFilter = nil
                        }

                        ForEach(activityTypes, id: \.self) { activityType in
                            FilterChip(
                                label: activityType,
                                isSelected: selectedActivityTypeFilter == activityType,
                                isHighlighted: targetActivityTypes.contains { Exercise.normalizedActivityKey($0) == Exercise.normalizedActivityKey(activityType) }
                            ) {
                                if selectedActivityTypeFilter == activityType {
                                    selectedActivityTypeFilter = nil
                                } else {
                                    selectedActivityTypeFilter = activityType
                                    selectedCategory = nil
                                    selectedMuscleGroup = nil
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        FilterChip(
                            label: "All",
                            isSelected: selectedCategory == nil && selectedMuscleGroup == nil && selectedActivityTypeFilter == nil
                        ) {
                            selectedCategory = nil
                            selectedMuscleGroup = nil
                            selectedActivityTypeFilter = nil
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Exercise.Category.userFacingCases) { category in
                        FilterChip(
                            label: category.displayName,
                            icon: category.iconName,
                            isSelected: isCategoryFilterSelected(category)
                        ) {
                            if isCategoryFilterSelected(category) {
                                selectedCategory = nil
                            } else {
                                selectedCategory = category
                                selectedMuscleGroup = nil
                                selectedActivityTypeFilter = nil
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }

            if !activityTypes.isEmpty && selectedMuscleGroup != nil {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(activityTypes, id: \.self) { activityType in
                            FilterChip(
                                label: activityType,
                                isSelected: selectedActivityTypeFilter == activityType,
                                isHighlighted: targetActivityTypes.contains { Exercise.normalizedActivityKey($0) == Exercise.normalizedActivityKey(activityType) }
                            ) {
                                if selectedActivityTypeFilter == activityType {
                                    selectedActivityTypeFilter = nil
                                } else {
                                    selectedActivityTypeFilter = activityType
                                    selectedCategory = nil
                                    selectedMuscleGroup = nil
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }
            }

            // Row 3: Muscle group filters (only for strength or all)
            if selectedCategory == .strength || selectedCategory == nil {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(muscleGroups) { muscleGroup in
                            FilterChip(
                                label: muscleGroup.displayName,
                                icon: muscleGroup.iconName,
                                isSelected: selectedMuscleGroup == muscleGroup,
                                isHighlighted: targetMuscleGroups.contains(muscleGroup)
                            ) {
                                if selectedMuscleGroup == muscleGroup {
                                    selectedMuscleGroup = nil
                                } else {
                                    selectedMuscleGroup = muscleGroup
                                    selectedCategory = .strength
                                    selectedActivityTypeFilter = nil
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
            }
        }
        .background(Color(.secondarySystemBackground))
    }

    private func isCategoryFilterSelected(_ category: Exercise.Category) -> Bool {
        guard let selectedCategory else { return false }
        return !selectedCategory.suggestionCategories.isDisjoint(with: category.suggestionCategories)
    }

    // MARK: - Exercise Row

    private func exerciseRow(_ exercise: Exercise) -> some View {
        Button {
            selectExercise(exercise)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(exercise.name)
                        .font(.body)

                    HStack(spacing: 4) {
                        if let muscleGroup = exercise.targetMuscleGroup {
                            Text(muscleGroup.displayName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else if !exercise.activityTypeName.isEmpty {
                            Text(exercise.activityTypeName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        // Show equipment name (stored or inferred)
                        if let equipment = exercise.displayEquipment {
                            Text("•")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                            Text(equipment)
                                .font(.caption)
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                }

                Spacer()

                if selectedExercise?.id == exercise.id {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.tint)
                }
            }
        }
        .foregroundStyle(.primary)
    }

    // MARK: - Actions

    private func selectExercise(_ exercise: Exercise) {
        if let onSelect {
            onSelect(exercise)
        } else {
            selectedExercise = exercise
        }
        dismiss()
    }

    private func queueCustomExerciseCreation(
        name: String,
        activityTypeName: String,
        activityAliases: [String],
        muscleGroup: Exercise.MuscleGroup?,
        category: Exercise.Category,
        secondaryMuscles: [String]?,
        targetTags: [String],
        trackingFields: [Exercise.TrackingField]
    ) {
        let resolvedCategory = category.userFacingEquivalent
        let request = PendingCustomExerciseCreation(
            name: name,
            activityTypeName: activityTypeName,
            activityAliases: activityAliases,
            muscleGroup: muscleGroup,
            category: resolvedCategory,
            secondaryMuscles: secondaryMuscles,
            targetTags: targetTags,
            trackingFields: trackingFields
        )

        guard showingAddCustom else {
            addCustomExercise(
                name: request.name,
                activityTypeName: request.activityTypeName,
                activityAliases: request.activityAliases,
                muscleGroup: request.muscleGroup,
                category: request.category,
                secondaryMuscles: request.secondaryMuscles,
                targetTags: request.targetTags,
                trackingFields: request.trackingFields
            )
            return
        }

        pendingCustomExerciseCreation = request
        showingAddCustom = false
    }

    private func addCustomExercise(
        name: String,
        activityTypeName: String? = nil,
        activityAliases: [String] = [],
        muscleGroup: Exercise.MuscleGroup? = nil,
        category: Exercise.Category = .strength,
        equipmentName: String? = nil,
        secondaryMuscles: [String]? = nil,
        targetTags: [String] = [],
        trackingFields: [Exercise.TrackingField]? = nil
    ) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let resolvedCategory = category.userFacingEquivalent
        let normalizedMuscleGroup = resolvedCategory == .strength ? muscleGroup : nil
        let normalizedSecondaryMuscles = resolvedCategory == .strength ? secondaryMuscles : nil

        // Check if exercise already exists
        if let existing = exercises.first(where: { $0.name.lowercased() == trimmed.lowercased() }) {
            // Backfill missing muscle group for existing strength entries when we now have context.
            if existing.exerciseCategory == .strength,
               existing.targetMuscleGroup == nil,
               let normalizedMuscleGroup {
                existing.targetMuscleGroup = normalizedMuscleGroup
            }
            if let secondary = normalizedSecondaryMuscles, !secondary.isEmpty {
                existing.secondaryMuscles = secondary.joined(separator: ",")
            } else if existing.exerciseCategory != .strength {
                existing.secondaryMuscles = nil
            }
            if !targetTags.isEmpty {
                existing.targetTags = targetTags
            }
            if let trackingFields, !trackingFields.isEmpty {
                existing.trackingFields = trackingFields
            }
            if let activityTypeName,
               !activityTypeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                existing.activityTypeName = activityTypeName
            }
            if !activityAliases.isEmpty {
                existing.activityAliases = activityAliases
            }
            try? modelContext.save()
            selectExercise(existing)
            return
        }

        // Create new custom exercise
        let exercise = Exercise(
            name: trimmed,
            category: resolvedCategory,
            muscleGroup: normalizedMuscleGroup
        )
        exercise.isCustom = true
        exercise.equipmentName = equipmentName
        exercise.activityTypeName = activityTypeName ?? Exercise.defaultActivityTypeName(for: trimmed, category: resolvedCategory)
        exercise.activityAliases = activityAliases
        exercise.targetTags = targetTags.isEmpty ? Exercise.defaultTargetTags(for: resolvedCategory) : targetTags
        exercise.trackingFields = trackingFields ?? Exercise.defaultTrackingFields(for: resolvedCategory)
        if let secondary = normalizedSecondaryMuscles, !secondary.isEmpty {
            exercise.secondaryMuscles = secondary.joined(separator: ",")
        }
        modelContext.insert(exercise)
        try? modelContext.save()

        selectExercise(exercise)
    }
}

// MARK: - Filter Chip

struct FilterChip: View {
    let label: String
    var icon: String?
    let isSelected: Bool
    var isHighlighted: Bool = false  // For target muscles
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon {
                    Image(systemName: icon)
                        .font(.caption2)
                }
                Text(label)
                    .font(.caption)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.accentColor : Color(.tertiarySystemFill))
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(.capsule)
            .overlay {
                // Subtle border for target muscles
                if isHighlighted && !isSelected {
                    Capsule()
                        .strokeBorder(Color.accentColor, lineWidth: 1.5)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    ExerciseListView { exercise in
        print("Selected: \(exercise.name)")
    }
    .modelContainer(for: [Exercise.self, ExerciseHistory.self], inMemory: true)
}
