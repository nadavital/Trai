//
//  FoodCameraView.swift
//  Trai
//
//  Created by Nadav Avital on 12/28/25.
//

import SwiftUI
import SwiftData
import PhotosUI
import OSLog

private let foodCameraSuggestionLogger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "Nadav.Trai",
    category: "FoodCameraSuggestions"
)

@MainActor
final class FoodCameraPresentation: Identifiable {
    let id = UUID()
    let sessionId: UUID?
    let targetDate: Date?

    init(sessionId: UUID? = nil, targetDate: Date? = nil) {
        self.sessionId = sessionId
        self.targetDate = targetDate
    }
}

private enum FoodCameraRoute: Hashable {
    case review
}

struct FoodCameraView: View {
    /// Session ID to add this food entry to (for grouping related entries)
    var sessionId: UUID?
    var targetDate: Date?
    var compactPresentation = true

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(HealthKitService.self) private var healthKitService: HealthKitService?
    @Environment(AccountSessionService.self) private var accountSessionService: AccountSessionService?
    @Environment(MonetizationService.self) private var monetizationService: MonetizationService?
    @Environment(ProUpsellCoordinator.self) private var proUpsellCoordinator: ProUpsellCoordinator?
    @Query private var profiles: [UserProfile]

    @State private var draft: FoodLogDraft?
    @State private var navigationPath: [FoodCameraRoute] = []
    @State private var showingManualEntry = false
    @State private var pendingManualEntry: FoodEntry?
    @State private var foodSaveErrorMessage: String?
    @State private var didSeedAppStoreScreenshotReview = false

    private var enabledMacros: Set<MacroType> {
        profiles.first?.enabledMacros ?? MacroType.defaultEnabled
    }

    private var canAccessFoodAI: Bool {
        monetizationService?.canAccessAIFeatures ?? true
    }

    private var requiresAuthenticatedAccountForFoodAI: Bool {
        accountSessionService?.isAuthenticated != true
    }

    var body: some View {
        Group {
            if !canAccessFoodAI {
                Color(.systemBackground)
                    .ignoresSafeArea()
            } else if requiresAuthenticatedAccountForFoodAI {
                AccountSetupView(context: .aiFeatures)
            } else if compactPresentation {
                Group {
                    if draft != nil {
                        FoodLogReviewStepView(
                            draft: draftBinding, enabledMacros: enabledMacros,
                            onManualEntry: { showingManualEntry = true },
                            onFinish: { dismiss() }, targetDate: targetDate,
                            compactPresentation: true,
                            onRetake: { draft = nil }
                        )
                    } else {
                        FoodLogCaptureStepView(
                            sessionId: sessionId, targetDate: targetDate,
                            onDraftReady: { draft = $0 },
                            onManualEntryRequested: { showingManualEntry = true },
                            onCancel: { dismiss() }, compactPresentation: true
                        )
                    }
                }
                .presentationDetents([.height(draft == nil ? 470 : 410), .large])
                .presentationDragIndicator(.hidden)
            } else {
                NavigationStack(path: $navigationPath) {
                    FoodLogCaptureStepView(
                        sessionId: sessionId,
                        targetDate: targetDate,
                        onDraftReady: { nextDraft in
                            draft = nextDraft
                            navigationPath = [.review]
                        },
                        onManualEntryRequested: { showingManualEntry = true },
                        onCancel: { dismiss() }
                    )
                    .navigationDestination(for: FoodCameraRoute.self) { route in
                        switch route {
                        case .review:
                            FoodLogReviewStepView(
                                draft: draftBinding,
                                enabledMacros: enabledMacros,
                                onManualEntry: { showingManualEntry = true },
                                onFinish: { dismiss() },
                                targetDate: targetDate
                            )
                        }
                    }
                }
            }
        }
        .task {
            seedAppStoreScreenshotReviewIfNeeded()
        }
        .sheet(isPresented: $showingManualEntry) {
            ManualFoodEntrySheet(sessionId: sessionId, targetDate: targetDate) { entry in
                pendingManualEntry = entry
                showingManualEntry = false
            }
            .traiSheetBranding()
        }
        .onChange(of: showingManualEntry) { _, isShowing in
            guard !isShowing else { return }

            if let pendingManualEntry {
                self.pendingManualEntry = nil
                saveManualEntry(pendingManualEntry)
            } else if !canAccessFoodAI {
                dismiss()
            }
        }
        .task(id: canAccessFoodAI) {
            if !canAccessFoodAI && !showingManualEntry {
                showingManualEntry = true
            }
        }
        .onChange(of: navigationPath) { _, newPath in
            if newPath.isEmpty, draft != nil {
                draft = nil
            }
        }
        .alert("Couldn’t Save Food", isPresented: saveErrorBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(foodSaveErrorMessage ?? "Please try again.")
        }
        .tint(TraiColors.brandAccent)
        .accentColor(TraiColors.brandAccent)
        .proUpsellPresenter()
    }

    private func seedAppStoreScreenshotReviewIfNeeded() {
        guard !didSeedAppStoreScreenshotReview,
              AppLaunchArguments.shouldUseAppStoreScreenshotSeed,
              AppLaunchArguments.shouldShowAppStoreScreenshotFoodReview else {
            return
        }

        didSeedAppStoreScreenshotReview = true
        var seededDraft = FoodLogDraft(
            sessionId: sessionId,
            image: UIImage(named: "AppStoreFoodCameraSample"),
            description: "salmon rice bowl with avocado, edamame, carrots, cucumber, and sesame",
            inputSource: .photo
        )
        seededDraft.refinedSuggestion = SuggestedFoodEntry(
            id: "app-store-salmon-bowl",
            name: "Salmon Rice Power Bowl",
            calories: 690,
            proteinGrams: 48,
            carbsGrams: 66,
            fatGrams: 24,
            fiberGrams: 10,
            sugarGrams: 8,
            servingSize: "1 bowl",
            emoji: "🍣",
            components: [
                SuggestedFoodComponent(displayName: "grilled salmon", role: "protein", quantity: 6, unit: "oz", calories: 320, proteinGrams: 38, carbsGrams: 0, fatGrams: 18, fiberGrams: 0, sugarGrams: 0, confidence: "high"),
                SuggestedFoodComponent(displayName: "rice and vegetables", role: "base", quantity: 1, unit: "bowl", calories: 370, proteinGrams: 10, carbsGrams: 66, fatGrams: 6, fiberGrams: 10, sugarGrams: 8, confidence: "high")
            ],
            mealKind: "lunch",
            notes: "Balanced protein-forward bowl with rice, avocado, and vegetables.",
            confidence: "high",
            schemaVersion: 2
        )
        draft = seededDraft
        if !compactPresentation {
            navigationPath = [.review]
        }
    }

    private var draftBinding: Binding<FoodLogDraft> {
        Binding(
            get: { draft ?? FoodLogDraft(sessionId: sessionId, inputSource: .description) },
            set: { draft = $0 }
        )
    }

    private func saveManualEntry(_ entry: FoodEntry) {
        if entry.acceptedSnapshot == nil {
            let acceptedSnapshot = FoodSnapshotBuilder().buildAcceptedSnapshot(
                from: entry,
                source: .manual,
                userEditedFields: ["manualEntry"]
            )
            entry.setAcceptedSnapshot(acceptedSnapshot)
        }
        modelContext.insert(entry)
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            foodSaveErrorMessage = error.localizedDescription
            HapticManager.error()
            return
        }
        WidgetDataProvider.shared.scheduleRefresh()
        invalidateFoodCameraSuggestions()
        scheduleFoodMemoryResolution(for: entry.id)
        recordFoodLogBehavior(entry: entry, source: "manual_entry", modelContext: modelContext)
        FoodHealthKitMacroSync.saveIfAllowed(entry, profile: profiles.first, healthKitService: healthKitService)
        HapticManager.success()
        dismiss()
    }

    private var saveErrorBinding: Binding<Bool> {
        Binding(
            get: { foodSaveErrorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    foodSaveErrorMessage = nil
                }
            }
        )
    }
}

private struct FoodLogCaptureStepView: View {
    let sessionId: UUID?
    let targetDate: Date?
    let onDraftReady: (FoodLogDraft) -> Void
    let onManualEntryRequested: () -> Void
    let onCancel: () -> Void
    var compactPresentation = false

    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL

    @State private var cameraService = CameraService()
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var foodDescription = ""
    @State private var isCapturingPhoto = false
    @State private var memorySuggestions: [FoodSuggestion] = []
    @State private var suggestionLoadTask: Task<Void, Never>?
    @State private var didRecordShownSuggestions = false
    @State private var hasResolvedCameraAvailability = false
    @State private var isCaptureVisible = false
    @State private var photoLoadTask: Task<Void, Never>?
    @State private var captureError: String?

    var body: some View {
        Group {
            if compactPresentation {
                FoodCaptureSheetView(
                    cameraService: cameraService, isCapturing: isCapturingPhoto,
                    cameraUnavailable: compactCameraUnavailable,
                    description: $foodDescription, selectedPhoto: $selectedPhotoItem,
                    suggestions: memorySuggestions, onSelectSuggestion: applyMemorySuggestion,
                    onCapture: capturePhoto, onDescribe: submitTextDescription,
                    onEnableCamera: enableCamera, onManualEntry: onManualEntryRequested,
                    onCancel: { recordIgnoredSuggestionsIfNeeded(); onCancel() }
                )
            } else if shouldShowNoCameraFallback {
                FoodCameraNoCameraFallbackView(
                    description: $foodDescription,
                    suggestions: memorySuggestions,
                    onSelectSuggestion: applyMemorySuggestion,
                    onManualEntry: onManualEntryRequested,
                    onSubmitDescription: submitTextDescription,
                    onEnableCamera: enableCamera,
                    selectedPhotoItem: $selectedPhotoItem
                )
            } else {
                FoodCameraViewfinder(
                    cameraService: cameraService,
                    isCapturingPhoto: isCapturingPhoto,
                    description: $foodDescription,
                    suggestions: memorySuggestions,
                    onCapture: capturePhoto,
                    onSelectSuggestion: applyMemorySuggestion,
                    onManualEntry: onManualEntryRequested,
                    onSubmitDescription: submitTextDescription,
                    selectedPhotoItem: $selectedPhotoItem
                )
            }
        }
        .overlay(alignment: .topLeading) {
            Text(shouldShowNoCameraFallback ? "fallback-ready" : "ready")
                .font(.system(size: 1))
                .frame(width: 1, height: 1)
                .opacity(0.01)
                .accessibilityElement(children: .ignore)
                .accessibilityIdentifier(
                    shouldShowNoCameraFallback
                        ? "foodCameraNoCameraReady"
                        : "foodCameraCaptureReady"
                )
        }
        .navigationTitle(shouldShowNoCameraFallback ? "Log Food" : "")
        .toolbarTitleDisplayMode(.inlineLarge)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    recordIgnoredSuggestionsIfNeeded()
                    onCancel()
                } label: {
                    Image(systemName: "xmark")
                        .font(.headline.weight(.semibold))
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.plain)
                .foregroundStyle(shouldShowNoCameraFallback ? Color.primary : .white)
                .accessibilityLabel("Cancel")
            }
        }
        .toolbarBackground(shouldShowNoCameraFallback ? .visible : .hidden, for: .navigationBar)
        .alert("Couldn’t Open Photo", isPresented: Binding(
            get: { captureError != nil }, set: { if !$0 { captureError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: { Text(captureError ?? "Please try again.") }
        .onChange(of: selectedPhotoItem) { _, newValue in
            guard let newValue else { return }
            photoLoadTask?.cancel()
            photoLoadTask = Task { @MainActor in
                do {
                    guard let data = try await newValue.loadTransferable(type: Data.self),
                          let image = UIImage(data: data) else {
                        if isCaptureVisible { captureError = "Choose another photo or try taking one with the camera." }
                        return
                    }
                    guard !Task.isCancelled, isCaptureVisible else { return }
                    recordShownSuggestionsIfNeeded()
                    var nextDraft = FoodLogDraft(
                        sessionId: sessionId, image: image,
                        description: trimmedDescription, inputSource: .photo
                    )
                    nextDraft.shownSuggestionIDs = memorySuggestions.map(\.memoryID)
                    selectedPhotoItem = nil
                    onDraftReady(nextDraft)
                } catch {
                    guard !Task.isCancelled, isCaptureVisible else { return }
                    captureError = "This photo couldn’t be loaded. Please choose it again."
                    selectedPhotoItem = nil
                }
            }
        }
        .task {
            isCaptureVisible = true
            suggestionLoadTask?.cancel()
            suggestionLoadTask = Task {
                await loadSuggestions()
            }
            guard !AppLaunchArguments.shouldUseFoodCaptureFixture else { return }
            guard !AppLaunchArguments.shouldForceFoodCameraPermissionFallback else {
                hasResolvedCameraAvailability = true
                return
            }
            guard !AppLaunchArguments.isUITesting else { return }
            await cameraService.requestPermission()
            hasResolvedCameraAvailability = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            guard !AppLaunchArguments.shouldUseFoodCaptureFixture else { return }
            guard !AppLaunchArguments.isUITesting else { return }
            Task { @MainActor in
                await cameraService.requestPermission()
                hasResolvedCameraAvailability = true
            }
        }
        .onDisappear {
            isCaptureVisible = false
            photoLoadTask?.cancel()
            photoLoadTask = nil
            suggestionLoadTask?.cancel()
            suggestionLoadTask = nil
            cameraService.stopSession()
        }
    }

    private var compactCameraUnavailable: Bool {
        if AppLaunchArguments.shouldUseFoodCaptureFixture { return false }
        if AppLaunchArguments.isUITesting && AppLaunchArguments.shouldUseMockFoodAIResponses,
           !AppLaunchArguments.shouldForceFoodCameraPermissionFallback { return false }
        return shouldShowNoCameraFallback || (hasResolvedCameraAvailability && !cameraService.isSessionReady)
    }

    private var shouldShowNoCameraFallback: Bool {
        AppLaunchArguments.shouldForceFoodCameraPermissionFallback
            || (hasResolvedCameraAvailability && !cameraService.isAuthorized)
    }

    private var trimmedDescription: String {
        foodDescription.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func enableCamera() {
        Task { @MainActor in
            guard !AppLaunchArguments.shouldForceFoodCameraPermissionFallback else { return }

            await cameraService.requestPermission()
            hasResolvedCameraAvailability = true

            guard !cameraService.isAuthorized,
                  let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
            openURL(settingsURL)
        }
    }

    private func capturePhoto() {
        guard !isCapturingPhoto else { return }

        Task { @MainActor in
            isCapturingPhoto = true
            defer { isCapturingPhoto = false }

            let reviewImage: UIImage
            if AppLaunchArguments.shouldUseFoodCaptureFixture {
                let fixtureImage: UIImage?
                if let path = AppLaunchArguments.foodCaptureFixturePath {
                    fixtureImage = UIImage(contentsOfFile: path)
                } else {
                    fixtureImage = UIImage(named: "AppStoreFoodCameraSample")
                }
                guard let fixtureImage else {
                    captureError = "The test meal image could not be opened. Check the fixture path."
                    return
                }
                reviewImage = fixtureImage
            } else if AppLaunchArguments.isUITesting,
               AppLaunchArguments.shouldUseMockFoodAIResponses,
               let fixtureImage = UIImage(named: "AppStoreFoodCameraSample") {
                // The simulator camera has no reliable shutter surface. Keep the
                // capture interaction real while supplying a stable review image
                // for the mock-AI UI test path only.
                reviewImage = fixtureImage
            } else {
                let capturedImage = await cameraService.capturePhoto()
                guard isCaptureVisible else { return }
                guard let capturedImage else {
                    captureError = "The camera couldn’t capture this photo. Try again or choose a photo from your library."
                    return
                }
                reviewImage = capturedImage
            }
            HapticManager.mediumTap()
            onDraftReady(
                {
                    recordShownSuggestionsIfNeeded()
                    var draft = FoodLogDraft(
                        sessionId: sessionId,
                        image: reviewImage,
                        description: trimmedDescription,
                        inputSource: .camera
                    )
                    draft.shownSuggestionIDs = memorySuggestions.map(\.memoryID)
                    return draft
                }()
            )
        }
    }

    private func submitTextDescription() {
        guard !trimmedDescription.isEmpty else { return }
        onDraftReady(
            {
                recordShownSuggestionsIfNeeded()
                var draft = FoodLogDraft(
                    sessionId: sessionId,
                    image: nil,
                    description: trimmedDescription,
                    inputSource: .description
                )
                draft.shownSuggestionIDs = memorySuggestions.map(\.memoryID)
                return draft
            }()
        )
    }

    private func applyMemorySuggestion(_ suggestion: FoodSuggestion) {
        recordShownSuggestionsIfNeeded()
        var draft = FoodLogDraft(
            sessionId: sessionId,
            image: nil,
            description: "",
            inputSource: .memorySuggestion
        )
        draft.memorySuggestionID = suggestion.memoryID
        draft.shownSuggestionIDs = memorySuggestions.map(\.memoryID)
        draft.refinedSuggestion = suggestion.suggestedEntry
        recordSuggestionOutcome(.tapped, memoryIDs: [suggestion.memoryID])
        HapticManager.mediumTap()
        onDraftReady(draft)
    }

    private func recordShownSuggestionsIfNeeded() {
        guard !didRecordShownSuggestions else { return }
        let shownIDs = memorySuggestions.map(\.memoryID)
        guard !shownIDs.isEmpty else { return }
        didRecordShownSuggestions = true
        recordSuggestionOutcome(.shown, memoryIDs: shownIDs)
    }

    private func recordIgnoredSuggestionsIfNeeded() {
        let ignoredIDs = memorySuggestions.map(\.memoryID)
        guard !ignoredIDs.isEmpty else { return }
        recordShownSuggestionsIfNeeded()
        recordSuggestionOutcome(.ignored, memoryIDs: ignoredIDs)
    }

    private func recordSuggestionOutcome(_ outcome: FoodSuggestionOutcome, memoryIDs: [UUID]) {
        guard let modelContainer = TraiApp.sharedModelContainer else { return }
        Task.detached(priority: .utility) {
            try? await FoodSuggestionService().recordOutcome(
                outcome,
                for: memoryIDs,
                modelContainer: modelContainer
            )
        }
    }

    @MainActor
    private func loadSuggestions() async {
        let startedAt = LatencyProbe.timerStart()

        if AppLaunchArguments.shouldUseAppStoreScreenshotSeed ||
            (AppLaunchArguments.isUITesting && ProcessInfo.processInfo.arguments.contains("--ui-test-food-suggestions")) {
            memorySuggestions = [
                FoodSuggestion(
                    memoryID: UUID(uuidString: "2F6D93DF-6762-4C2A-A3C2-BC7A9E48C101") ?? UUID(),
                    title: "Salmon rice bowl",
                    subtitle: "Lunch you repeat",
                    detail: "620 cal · 44g protein",
                    emoji: "🍣",
                    relevanceScore: 0.94,
                    suggestedEntry: SuggestedFoodEntry(
                        name: "Salmon Rice Bowl",
                        calories: 620,
                        proteinGrams: 44,
                        carbsGrams: 58,
                        fatGrams: 22,
                        fiberGrams: 7,
                        sugarGrams: 6,
                        servingSize: "1 bowl",
                        emoji: "🍣",
                        mealKind: "lunch",
                        notes: "Matched to the meal in view and your usual bowl pattern.",
                        confidence: "high",
                        schemaVersion: 2
                    )
                ),
                FoodSuggestion(
                    memoryID: UUID(uuidString: "89FDF30F-3636-4E01-A4D6-08FD7C5C39B5") ?? UUID(),
                    title: "Post-workout bowl",
                    subtitle: "Training-day favorite",
                    detail: "680 cal · 52g protein",
                    emoji: "🥗",
                    relevanceScore: 0.88,
                    suggestedEntry: SuggestedFoodEntry(
                        name: "Post-Workout Chicken Bowl",
                        calories: 680,
                        proteinGrams: 52,
                        carbsGrams: 72,
                        fatGrams: 16,
                        fiberGrams: 8,
                        sugarGrams: 5,
                        servingSize: "1 bowl",
                        emoji: "🥗",
                        mealKind: "dinner",
                        notes: "A fast high-protein option for lifting days.",
                        confidence: "high",
                        schemaVersion: 2
                    )
                )
            ]
            return
        }

        let recommendationDate = resolvedFoodLogDate(
            targetDate: targetDate,
            sessionId: sessionId,
            modelContext: modelContext
        )
        guard let modelContainer = TraiApp.sharedModelContainer else {
            memorySuggestions = []
            foodCameraSuggestionLogger.warning("Food camera suggestions skipped: missing model container")
            return
        }

        if let cachedSuggestions = await FoodSuggestionWarmCache.shared.cachedSuggestions(
            limit: 3,
            targetDate: recommendationDate,
            sessionId: sessionId
        ) {
            memorySuggestions = cachedSuggestions
            foodCameraSuggestionLogger.info("Food camera suggestion cache hit count=\(cachedSuggestions.count)")
        } else {
            foodCameraSuggestionLogger.info("Food camera suggestion cache miss")
        }

        let suggestions = await FoodSuggestionWarmCache.shared.suggestions(
            limit: 3,
            targetDate: recommendationDate,
            sessionId: sessionId,
            modelContainer: modelContainer
        )
        guard !Task.isCancelled else { return }
        let duration = LatencyProbe.elapsedMilliseconds(since: startedAt)
        if memorySuggestions != suggestions {
            memorySuggestions = suggestions
        }
        if suggestions.isEmpty {
            Task.detached(priority: .utility) {
                await FoodLogCaptureStepView.logEmptySuggestionDiagnostics(
                    targetDate: recommendationDate,
                    sessionId: sessionId,
                    durationMilliseconds: duration,
                    modelContainer: modelContainer
                )
            }
        } else {
            foodCameraSuggestionLogger.info("Food camera suggestions ready count=\(suggestions.count) durationMs=\(duration)")
        }
    }

    private nonisolated static func logEmptySuggestionDiagnostics(
        targetDate: Date,
        sessionId: UUID?,
        durationMilliseconds: Double,
        modelContainer: ModelContainer
    ) async {
        let summary = try? await FoodSuggestionService().debugCameraSuggestions(
            limit: 3,
            targetDate: targetDate,
            sessionId: sessionId,
            modelContainer: modelContainer
        )
        await MainActor.run {
            foodCameraSuggestionLogger.warning(
                """
                Food camera suggestions empty durationMs=\(durationMilliseconds) \
                memories=\(summary?.totalMemories ?? -1) \
                observations=\(summary?.totalObservations ?? -1) \
                patterns=\(summary?.patternCount ?? -1) \
                retrieved=\(summary?.retrievedCandidateCount ?? -1) \
                finalEligible=\(summary?.finalEligibleCount ?? -1)
                """
            )
        }
    }
}

private struct FoodLogReviewStepView: View {
    @Binding var draft: FoodLogDraft
    let enabledMacros: Set<MacroType>
    let onManualEntry: () -> Void
    let onFinish: () -> Void
    var targetDate: Date?
    var compactPresentation = false
    var onRetake: () -> Void = {}

    @Environment(\.modelContext) private var modelContext
    @Environment(HealthKitService.self) private var healthKitService: HealthKitService?
    @Environment(MonetizationService.self) private var monetizationService: MonetizationService?
    @Environment(ProUpsellCoordinator.self) private var proUpsellCoordinator: ProUpsellCoordinator?

    @State private var aiService = AIService()
    @State private var isAnalyzing = false
    @State private var analysisErrorMessage: String?
    @State private var isLoadingRefinement = false
    @State private var refinementErrorMessage: String?
    @State private var isSaving = false
    @State private var analyzedDescription: String?
    @State private var didAutoAnalyzeOnArrival = false
    @State private var activeRefinementRequestID: UUID?
    @State private var activeAnalysisRequestID: UUID?
    @State private var suggestionRevision = 0
    @State private var acceptedLocalEditedFields: Set<String> = []
    @Query private var profiles: [UserProfile]

    var body: some View {
        Group {
            if compactPresentation {
                FoodCaptureSheetReview(
                    image: draft.image, suggestion: currentSuggestion, suggestionRevision: suggestionRevision,
                    enabledMacros: enabledMacros, isAnalyzing: isAnalyzing,
                    isSaving: isSaving, isRefining: isLoadingRefinement,
                    error: analysisErrorMessage ?? refinementErrorMessage,
                    onRetry: analyzeFood, onRetake: onRetake, onClose: onFinish,
                    onManualEntry: onManualEntry, onRefine: { correction, adjusted in
                        refineFood(correction, baseSuggestion: adjusted)
                    },
                    onSave: { suggestion, editedFields in
                        saveEntry(suggestion, isRefined: draft.refinedSuggestion != nil, editedFields: editedFields)
                    }
                )
            } else {
        FoodCameraReviewView(
            image: draft.image,
            inputSource: draft.inputSource,
            description: $draft.description,
            isAnalyzing: isAnalyzing,
            analysisResult: draft.analysisResult,
            refinedSuggestion: draft.refinedSuggestion,
            errorMessage: analysisErrorMessage,
            refinementErrorMessage: refinementErrorMessage,
            enabledMacros: enabledMacros,
            isLoadingRefinement: isLoadingRefinement,
            isSaving: isSaving,
            onAnalyze: analyzeFood,
            onSave: { saveEntry($0, isRefined: $1) },
            onRefine: { refineFood($0) },
            onManualEntry: onManualEntry
        )
        }
        }
        .toolbarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
        .task {
            autoAnalyzeOnArrivalIfNeeded()
        }
        .onDisappear {
            activeAnalysisRequestID = nil
            activeRefinementRequestID = nil
            isAnalyzing = false
            isLoadingRefinement = false
        }
        .onChange(of: draft.description) { _, newValue in
            resetAnalysisIfNotesChanged(to: newValue)
        }
    }

    private var trimmedDescription: String {
        draft.description.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func autoAnalyzeOnArrivalIfNeeded() {
        guard !didAutoAnalyzeOnArrival,
              draft.inputSource != .memorySuggestion,
              draft.analysisResult == nil,
              draft.refinedSuggestion == nil,
              !isAnalyzing,
              draft.image != nil || !trimmedDescription.isEmpty else {
            return
        }

        // This is deliberately a one-shot arrival action. Failed requests stay
        // retryable through the review UI instead of creating an automatic loop.
        didAutoAnalyzeOnArrival = true
        analyzeFood()
    }

    private var currentSuggestion: SuggestedFoodEntry? {
        if let refinedSuggestion = draft.refinedSuggestion {
            return refinedSuggestion
        }

        guard let analysisResult = draft.analysisResult else { return nil }
        return SuggestedFoodEntry(
            name: analysisResult.name,
            calories: analysisResult.calories,
            proteinGrams: analysisResult.proteinGrams,
            carbsGrams: analysisResult.carbsGrams,
            fatGrams: analysisResult.fatGrams,
            fiberGrams: analysisResult.fiberGrams,
            sugarGrams: analysisResult.sugarGrams,
            servingSize: analysisResult.servingSize,
            emoji: analysisResult.emoji,
            components: analysisResult.components?.map(SuggestedFoodComponent.init(component:)) ?? [],
            mealKind: analysisResult.mealKind,
            notes: analysisResult.notes,
            confidence: analysisResult.confidence,
            schemaVersion: 2
        )
    }

    private func analyzeFood() {
        guard !isAnalyzing else { return }
        guard draft.image != nil || !trimmedDescription.isEmpty else { return }
        guard monetizationService?.canAccessAIFeatures ?? true else {
            proUpsellCoordinator?.present(source: .foodAnalysis)
            return
        }

        isAnalyzing = true
        analysisErrorMessage = nil
        refinementErrorMessage = nil
        draft.refinedSuggestion = nil
        let requestID = UUID()
        activeAnalysisRequestID = requestID
        let imageData = draft.image?.jpegData(compressionQuality: 0.8)
        let requestDescription = trimmedDescription

        Task { @MainActor in
            do {
                let result = try await aiService.analyzeFoodImage(
                    imageData,
                    description: requestDescription.isEmpty ? nil : requestDescription
                )
                guard activeAnalysisRequestID == requestID else { return }
                draft.analysisResult = result
                suggestionRevision += 1
                analyzedDescription = requestDescription
                HapticManager.success()
            } catch {
                guard activeAnalysisRequestID == requestID else { return }
                analysisErrorMessage = error.aiUserFacingMessage(
                    fallback: "We couldn’t analyze this food right now. Please try again or enter it manually."
                )
                HapticManager.error()
            }
            guard activeAnalysisRequestID == requestID else { return }
            activeAnalysisRequestID = nil
            isAnalyzing = false
        }
    }

    private func resetAnalysisIfNotesChanged(to description: String) {
        guard draft.inputSource != .memorySuggestion else {
            return
        }

        let nextDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard nextDescription != analyzedDescription else { return }
        guard isAnalyzing || draft.analysisResult != nil || draft.refinedSuggestion != nil else {
            return
        }

        // Editing notes while a request is in flight invalidates that request;
        // its eventual response must not be allowed to populate this draft.
        if isAnalyzing {
            activeAnalysisRequestID = nil
            isAnalyzing = false
        }
        activeRefinementRequestID = nil
        isLoadingRefinement = false
        acceptedLocalEditedFields = []
        draft.analysisResult = nil
        draft.refinedSuggestion = nil
        analysisErrorMessage = nil
        refinementErrorMessage = nil
        analyzedDescription = nil
        activeAnalysisRequestID = nil
    }

    private func refineFood(_ correction: String, baseSuggestion: SuggestedFoodEntry? = nil) {
        let originalSuggestion = currentSuggestion
        guard !isLoadingRefinement, let currentSuggestion = baseSuggestion ?? originalSuggestion else { return }
        var requestEditedFields = Set<String>()
        if let baseSuggestion, let originalSuggestion {
            if baseSuggestion.name != originalSuggestion.name { requestEditedFields.insert("name") }
            if baseSuggestion.servingSize != originalSuggestion.servingSize { requestEditedFields.insert("portion") }
        }
        guard monetizationService?.canAccessAIFeatures ?? true else {
            proUpsellCoordinator?.present(source: .foodAnalysis)
            return
        }

        isLoadingRefinement = true
        refinementErrorMessage = nil
        let requestID = UUID()
        activeRefinementRequestID = requestID
        let imageData = draft.image?.jpegData(compressionQuality: 0.8)

        Task { @MainActor in
            defer {
                if activeRefinementRequestID == requestID {
                    isLoadingRefinement = false
                    activeRefinementRequestID = nil
                }
            }

            do {
                let refinedSuggestion = try await aiService.refineFoodAnalysis(
                    correction: correction,
                    currentSuggestion: currentSuggestion,
                    imageData: imageData
                )
                guard activeRefinementRequestID == requestID else { return }
                draft.refinedSuggestion = refinedSuggestion
                acceptedLocalEditedFields.formUnion(requestEditedFields)
                suggestionRevision += 1
                HapticManager.success()
            } catch {
                guard activeRefinementRequestID == requestID else { return }
                refinementErrorMessage = error.aiUserFacingMessage(
                    fallback: "We couldn’t update this suggestion right now. Please try again."
                )
                HapticManager.error()
            }
        }
    }

    private func saveEntry(_ suggestion: SuggestedFoodEntry, isRefined: Bool, editedFields: [String] = []) {
        guard !isSaving else { return }
        isSaving = true

        let snapshotBuilder = FoodSnapshotBuilder()
        let entry = FoodEntry()
        entry.name = suggestion.name
        entry.calories = suggestion.calories
        entry.proteinGrams = suggestion.proteinGrams
        entry.carbsGrams = suggestion.carbsGrams
        entry.fatGrams = suggestion.fatGrams
        entry.fiberGrams = suggestion.fiberGrams
        entry.sugarGrams = suggestion.sugarGrams
        entry.servingSize = suggestion.servingSize
        entry.emoji = FoodEmojiResolver.resolve(preferred: suggestion.emoji, foodName: suggestion.name)
        entry.imageData = draft.image?.jpegData(compressionQuality: 0.8)
        entry.userDescription = trimmedDescription.isEmpty ? nil : trimmedDescription
        entry.aiAnalysis = if draft.inputSource == .memorySuggestion {
            "Saved from remembered food suggestion"
        } else if isRefined {
            "Refined from initial analysis"
        } else {
            draft.analysisResult?.notes
        }
        entry.input = draft.inputSource.foodEntryInputMethod
        entry.loggedAt = resolvedFoodLogDate(targetDate: targetDate, sessionId: draft.sessionId, modelContext: modelContext)
        entry.meal = FoodEntry.mealType(for: entry.loggedAt)
        entry.ensureDisplayMetadata()
        let acceptedSnapshot = snapshotBuilder.buildAcceptedSnapshot(
            from: suggestion,
            source: acceptedSource(for: draft.inputSource),
            loggedAt: entry.loggedAt,
            userEditedFields: acceptedLocalEditedFields.union(editedFields).union(Set(isRefined ? ["refinement"] : []))
        )
        entry.setAcceptedSnapshot(acceptedSnapshot)

        assignFoodSession(draft.sessionId, to: entry, modelContext: modelContext)
        modelContext.insert(entry)
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            isSaving = false
            analysisErrorMessage = "We couldn’t save this food entry. Please try again."
            HapticManager.error()
            return
        }
        WidgetDataProvider.shared.scheduleRefresh()
        invalidateFoodCameraSuggestions()
        scheduleFoodMemoryResolution(for: entry.id)

        let behaviorSource = isRefined
            ? "refined_\(draft.inputSource.behaviorSource)"
            : draft.inputSource.behaviorSource
        recordFoodLogBehavior(entry: entry, source: behaviorSource, modelContext: modelContext)
        FoodHealthKitMacroSync.saveIfAllowed(entry, profile: profiles.first, healthKitService: healthKitService)
        reconcileShownSuggestionsAfterSave(
            draft.shownSuggestionIDs,
            preferredMemoryID: draft.memorySuggestionID,
            acceptedSnapshot: acceptedSnapshot,
            isRefined: isRefined,
            modelContext: modelContext
        )

        HapticManager.success()
        onFinish()
    }

    private func acceptedSource(for inputSource: FoodLogInputSource) -> AcceptedFoodSource {
        switch inputSource {
        case .camera:
            return .camera
        case .photo:
            return .photo
        case .description:
            return .description
        case .manual:
            return .manual
        case .memorySuggestion:
            return .memorySuggestion
        }
    }
}

private func scheduleFoodMemoryResolution(for entryID: UUID) {
    guard let modelContainer = TraiApp.sharedModelContainer else { return }
    FoodMemoryBackgroundService.shared.scheduleResolveEntry(
        id: entryID,
        modelContainer: modelContainer
    )
}

private func assignFoodSession(_ sessionId: UUID?, to entry: FoodEntry, modelContext: ModelContext) {
    guard let sessionId else { return }
    entry.sessionId = sessionId
    let existingCount = try? modelContext.fetchCount(
        FetchDescriptor<FoodEntry>(predicate: #Predicate { $0.sessionId == sessionId })
    )
    entry.sessionOrder = existingCount ?? 0
}

func resolvedFoodLogDate(targetDate: Date?, sessionId: UUID?, modelContext: ModelContext) -> Date {
    if let sessionId {
        let descriptor = FetchDescriptor<FoodEntry>(
            predicate: #Predicate { $0.sessionId == sessionId },
            sortBy: [SortDescriptor(\FoodEntry.sessionOrder)]
        )

        if let sessionDate = try? modelContext.fetch(descriptor).first?.loggedAt {
            return sessionDate
        }
    }

    guard let targetDate else { return Date() }
    return combineDay(targetDate, withTimeFrom: Date())
}

@MainActor
func prewarmFoodCameraSuggestions(sessionId: UUID? = nil, targetDate: Date? = nil, modelContext: ModelContext) {
    guard !AppLaunchArguments.shouldUseAppStoreScreenshotSeed else { return }
    guard let modelContainer = TraiApp.sharedModelContainer else { return }
    let recommendationDate = resolvedFoodLogDate(
        targetDate: targetDate,
        sessionId: sessionId,
        modelContext: modelContext
    )

    Task(priority: .utility) {
        await FoodSuggestionWarmCache.shared.prewarm(
            limit: 3,
            targetDate: recommendationDate,
            sessionId: sessionId,
            modelContainer: modelContainer
        )
    }
}

func invalidateFoodCameraSuggestions() {
    Task(priority: .utility) {
        await FoodSuggestionWarmCache.shared.invalidate()
    }
}

private func combineDay(_ day: Date, withTimeFrom timeSource: Date) -> Date {
    let calendar = Calendar.current
    var dateComponents = calendar.dateComponents([.year, .month, .day], from: day)
    let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: timeSource)
    dateComponents.hour = timeComponents.hour
    dateComponents.minute = timeComponents.minute
    dateComponents.second = timeComponents.second
    return calendar.date(from: dateComponents) ?? day
}

private func recordFoodLogBehavior(entry: FoodEntry, source: String, modelContext: ModelContext) {
    BehaviorTracker(modelContext: modelContext).record(
        actionKey: BehaviorActionKey.logFood,
        domain: .nutrition,
        surface: .food,
        outcome: .completed,
        relatedEntityId: entry.id,
        metadata: [
            "source": source,
            "name": entry.name
        ]
    )
}

private func reconcileShownSuggestionsAfterSave(
    _ shownMemoryIDs: [UUID],
    preferredMemoryID: UUID?,
    acceptedSnapshot: AcceptedFoodSnapshot,
    isRefined: Bool,
    modelContext: ModelContext
) {
    guard !shownMemoryIDs.isEmpty else { return }

    Task { @MainActor in
        try? await Task.sleep(for: .seconds(4))
        guard !Task.isCancelled else { return }
        guard let modelContainer = TraiApp.sharedModelContainer else { return }
        let modelContext = ModelContext(modelContainer)
        try? FoodSuggestionService().reconcileShownSuggestions(
            shownMemoryIDs,
            preferredMemoryID: preferredMemoryID,
            with: acceptedSnapshot,
            isRefined: isRefined,
            modelContext: modelContext
        )
    }
}
