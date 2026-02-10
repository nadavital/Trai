//
//  LogFoodCameraIntent.swift
//  Trai
//
//  App Intent for logging food via camera (opens app)
//

import AppIntents

/// Intent for opening the app to the food camera for photo-based logging
struct LogFoodCameraIntent: AppIntent {
    static var title: LocalizedStringResource = "Scan Food Photo"
    static var description = IntentDescription("Open camera to log food by taking a photo")

    /// This intent opens the app UI
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        PendingAppRouteStore.setPendingRoute(.logFood)
        return .result()
    }
}
