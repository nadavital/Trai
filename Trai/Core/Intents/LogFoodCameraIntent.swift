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

    /// Camera capture always continues in Trai's foreground UI.
    static var supportedModes: IntentModes { .foreground(.immediate) }

    @available(iOS 27.0, *)
    static var allowedExecutionTargets: ExecutionTargets { .main }

    @MainActor
    func perform() async throws -> some IntentResult {
        PendingAppRouteStore.setPendingRoute(.logFood)
        return .result()
    }
}
