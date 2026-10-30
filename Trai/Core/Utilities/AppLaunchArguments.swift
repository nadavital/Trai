//
//  AppLaunchArguments.swift
//  Trai
//
//  Shared launch arguments used for app/runtime test behavior.
//

import Foundation

enum AppLaunchArguments {
    static let uiTestMode = "UITEST_MODE"
    static let uiTestOnboardingFlow = "--ui-test-onboarding-flow"
    static let uiTestFreePlan = "--ui-test-free-plan"
    static let uiTestAuthenticatedFreePlan = "--ui-test-authenticated-free-plan"
    static let uiTestProPlan = "--ui-test-pro-plan"
    static let uiTestLiveAIBackend = "--ui-test-live-ai-backend"
    static let pendingAppRoute = "-pendingAppRoute"
    static let seedLiveWorkoutPerfData = "--seed-live-workout-perf-data"
    static let seedGoalPreviewData = "--goal-preview-seed"
    static let uiTestLiveWorkoutPreset = "--ui-test-live-workout-preset"
    static let uiTestAutoStartWorkout = "--ui-test-auto-start-workout"
    static let mockFoodAIResponses = "--ui-test-mock-food-ai"
    static let forceFoodCameraPermissionFallback = "--ui-test-force-no-camera-food-flow"
    static let appStoreScreenshotMode = "--app-store-screenshot-mode"
    static let appStoreScreenshotInitialTab = "--app-store-screenshot-tab"
    static let appStoreScreenshotFoodReview = "--app-store-screenshot-food-review"
    static let appStoreScreenshotPlanReview = "--app-store-screenshot-plan-review"
    static let appStoreScreenshotWatchConnected = "--app-store-screenshot-watch-connected"
    static let appStoreScreenshotChatScenario = "--app-store-screenshot-chat-scenario"
    static let enableTabPrewarm = "--enable-tab-prewarm"
    static let disableTabPrewarm = "--disable-tab-prewarm"
    static let disableHeavyTabDeferral = "--disable-heavy-tab-deferral"
    static let enableLatencyProbe = "--enable-latency-probe"
    static let traiLensLab = "--trai-lens-lab"
    static let useInMemoryStore = "--use-in-memory-store"
    static let usePersistentStore = "--use-persistent-store"
    static let testPersona = "--test-persona"
    static let testPersonaAI = "--test-persona-ai"
    static let testFoodImagePath = "--test-food-image-path"
    static let runFoodRecommendationReplayEvaluation = "--run-food-recommendation-replay-evaluation"
    static let foodRecommendationReplayCases = "--food-recommendation-replay-cases"
    static let onboardingCompletedCacheKey = "hasCompletedOnboardingCached"
    private static let processStartupUptime = ProcessInfo.processInfo.systemUptime
    private static let startupSuppressedAnimationWindowSeconds: TimeInterval = 4

    static var isUITesting: Bool {
        ProcessInfo.processInfo.arguments.contains(uiTestMode) || activeTestPersona != nil
    }

    enum TestPersona: String {
        case new, consistent, returning
    }

    enum TestPersonaAIMode: String {
        case deterministic, live
        case localLive = "local-live"
    }

    /// Test personas cannot be activated on a physical device or in release builds.
    static var activeTestPersona: TestPersona? {
        #if DEBUG && targetEnvironment(simulator)
        guard let rawValue = value(after: testPersona) else { return nil }
        return TestPersona(rawValue: rawValue)
        #else
        return nil
        #endif
    }

    static var testPersonaAIMode: TestPersonaAIMode? {
        guard activeTestPersona != nil else { return nil }
        return value(after: testPersonaAI).flatMap(TestPersonaAIMode.init(rawValue:)) ?? .live
    }

    static var shouldUseHostedAIForTestPersona: Bool {
        activeTestPersona != nil && testPersonaAIMode == .live
    }

    static var shouldUseLocalLiveAIForTestPersona: Bool {
        activeTestPersona != nil && testPersonaAIMode == .localLive
    }

    static var shouldUseFoodCaptureFixture: Bool {
        activeTestPersona != nil
    }

    static var foodCaptureFixturePath: String? {
        guard shouldUseFoodCaptureFixture else { return nil }
        return value(after: testFoodImagePath)
    }

    static var shouldRunOnboardingFlowUITest: Bool {
        ProcessInfo.processInfo.arguments.contains(uiTestOnboardingFlow) || activeTestPersona == .new
    }

    static var shouldUseFreePlanForUITest: Bool {
        ProcessInfo.processInfo.arguments.contains(uiTestFreePlan)
    }

    static var shouldUseAuthenticatedFreePlanForUITest: Bool {
        ProcessInfo.processInfo.arguments.contains(uiTestAuthenticatedFreePlan)
    }

    static var shouldUseProPlanForUITest: Bool {
        ProcessInfo.processInfo.arguments.contains(uiTestProPlan)
    }

    static var shouldUseLiveAIBackendForUITest: Bool {
        if activeTestPersona != nil { return shouldUseLocalLiveAIForTestPersona }
        return ProcessInfo.processInfo.arguments.contains(uiTestLiveAIBackend)
            || shouldUseLocalLiveAIForTestPersona
    }

    static var isRunningUnitTests: Bool {
        let environment = ProcessInfo.processInfo.environment
        guard environment["XCTestConfigurationFilePath"] != nil else { return false }
        // UI tests launch the app as a separate process without test-bundle injection.
        return environment["XCInjectBundleInto"] != nil
    }

    static var isRunningTests: Bool {
        isUITesting || isRunningUnitTests
    }

    static var shouldUseInMemoryStore: Bool {
        if activeTestPersona != nil { return true }
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains(usePersistentStore) {
            return false
        }
        if arguments.contains(useInMemoryStore) {
            return true
        }
        return isUITesting || isRunningUnitTests
    }

    static var shouldSeedLiveWorkoutPerfData: Bool {
        ProcessInfo.processInfo.arguments.contains(seedLiveWorkoutPerfData)
    }

    static var shouldSeedGoalPreviewData: Bool {
        ProcessInfo.processInfo.arguments.contains(seedGoalPreviewData)
    }

    static var shouldUseLiveWorkoutUITestPreset: Bool {
        ProcessInfo.processInfo.arguments.contains(uiTestLiveWorkoutPreset)
    }

    static var shouldAutoStartWorkoutForUITest: Bool {
        ProcessInfo.processInfo.arguments.contains(uiTestAutoStartWorkout)
    }

    static var shouldUseMockFoodAIResponses: Bool {
        if activeTestPersona != nil {
            return testPersonaAIMode == .deterministic
        }
        return ProcessInfo.processInfo.arguments.contains(mockFoodAIResponses)
    }

    static var shouldUseAppStoreScreenshotSeed: Bool {
        ProcessInfo.processInfo.arguments.contains(appStoreScreenshotMode)
    }

    static var appStoreScreenshotInitialTabRawValue: String? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let flagIndex = arguments.firstIndex(of: appStoreScreenshotInitialTab) else {
            return nil
        }
        let valueIndex = arguments.index(after: flagIndex)
        guard arguments.indices.contains(valueIndex) else {
            return nil
        }
        return arguments[valueIndex]
    }

    static var appStoreScreenshotChatScenarioRawValue: String? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let flagIndex = arguments.firstIndex(of: appStoreScreenshotChatScenario) else {
            return nil
        }
        let valueIndex = arguments.index(after: flagIndex)
        guard arguments.indices.contains(valueIndex) else {
            return nil
        }
        return arguments[valueIndex]
    }

    static var shouldShowAppStoreScreenshotFoodReview: Bool {
        ProcessInfo.processInfo.arguments.contains(appStoreScreenshotFoodReview)
    }

    static var shouldShowAppStoreScreenshotPlanReview: Bool {
        ProcessInfo.processInfo.arguments.contains(appStoreScreenshotPlanReview)
    }

    static var shouldShowAppStoreScreenshotWatchConnected: Bool {
        ProcessInfo.processInfo.arguments.contains(appStoreScreenshotWatchConnected)
    }

    static var shouldForceFoodCameraPermissionFallback: Bool {
        ProcessInfo.processInfo.arguments.contains(forceFoodCameraPermissionFallback)
    }

    static var shouldEnableTabPrewarm: Bool {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains(disableTabPrewarm) {
            return false
        }
        if arguments.contains(enableTabPrewarm) {
            return true
        }
        // Enable by default so real users benefit from background tab warming.
        return true
    }

    static var shouldAggressivelyDeferHeavyTabWork: Bool {
        !isRunningTests && !ProcessInfo.processInfo.arguments.contains(disableHeavyTabDeferral)
    }

    static var shouldEnableLatencyProbe: Bool {
        ProcessInfo.processInfo.arguments.contains(enableLatencyProbe)
    }

    static var shouldShowTraiLensLab: Bool {
        ProcessInfo.processInfo.arguments.contains(traiLensLab)
    }

    #if DEBUG
    static var shouldRunFoodRecommendationReplayEvaluation: Bool {
        ProcessInfo.processInfo.arguments.contains(runFoodRecommendationReplayEvaluation)
    }

    static var foodRecommendationReplayMaximumCases: Int? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let flagIndex = arguments.firstIndex(of: foodRecommendationReplayCases) else { return nil }
        let valueIndex = arguments.index(after: flagIndex)
        guard arguments.indices.contains(valueIndex) else { return nil }
        return Int(arguments[valueIndex]).map { max($0, 1) }
    }
    #else
    static var shouldRunFoodRecommendationReplayEvaluation: Bool {
        false
    }

    static var foodRecommendationReplayMaximumCases: Int? {
        nil
    }
    #endif

    static var shouldSuppressStartupAnimations: Bool {
        if isUITesting {
            return true
        }
        return (ProcessInfo.processInfo.systemUptime - processStartupUptime) < startupSuppressedAnimationWindowSeconds
    }

    static var launchPendingRoute: AppRoute? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let routeFlagIndex = arguments.firstIndex(of: pendingAppRoute) else {
            return nil
        }
        let valueIndex = arguments.index(after: routeFlagIndex)
        guard arguments.indices.contains(valueIndex) else {
            return nil
        }
        return AppRoute(urlString: arguments[valueIndex])
    }

    private static func value(after flag: String) -> String? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: flag),
              arguments.indices.contains(index + 1) else { return nil }
        let value = arguments[index + 1]
        return value.hasPrefix("--") ? nil : value
    }
}
