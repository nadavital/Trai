import Foundation

/// Keeps expensive chat activation tasks from replaying on every tab revisit.
struct ChatActivationWorkPolicy: Sendable {
    private let fullActivationCooldownSeconds: TimeInterval
    private let recommendationCooldownSeconds: TimeInterval

    private(set) var hasCompletedInitialActivation = false
    private(set) var lastFullActivationAt: Date?
    private(set) var lastRecommendationCheckAt: Date?

    init(
        fullActivationCooldownSeconds: TimeInterval,
        recommendationCooldownSeconds: TimeInterval
    ) {
        self.fullActivationCooldownSeconds = max(0, fullActivationCooldownSeconds)
        self.recommendationCooldownSeconds = max(0, recommendationCooldownSeconds)
    }

    func shouldRunFullActivation(
        hasPendingStartupActions: Bool,
        now: Date = Date()
    ) -> Bool {
        if hasPendingStartupActions {
            return true
        }
        guard hasCompletedInitialActivation else {
            return true
        }
        guard let lastFullActivationAt else {
            return true
        }
        return now.timeIntervalSince(lastFullActivationAt) >= fullActivationCooldownSeconds
    }

    mutating func markFullActivationRun(at now: Date = Date()) {
        hasCompletedInitialActivation = true
        lastFullActivationAt = now
    }

    func shouldRunRecommendationCheck(now: Date = Date()) -> Bool {
        guard let lastRecommendationCheckAt else { return true }
        return now.timeIntervalSince(lastRecommendationCheckAt) >= recommendationCooldownSeconds
    }

    mutating func markRecommendationCheckRun(at now: Date = Date()) {
        lastRecommendationCheckAt = now
    }
}
