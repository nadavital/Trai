import Foundation

/// Coordinates deferred heavy tab work so it runs only after a minimum dwell
/// and is ignored if the tab loses focus before execution.
struct TabActivationPolicy: Sendable {
    private let minimumDwellSeconds: TimeInterval
    private(set) var activationToken: UInt64 = 0
    private(set) var activeSince: Date?

    init(minimumDwellMilliseconds: Int) {
        let clamped = max(0, minimumDwellMilliseconds)
        self.minimumDwellSeconds = Double(clamped) / 1000.0
    }

    @discardableResult
    mutating func activate(now: Date = Date()) -> UInt64 {
        activationToken &+= 1
        activeSince = now
        return activationToken
    }

    mutating func deactivate() {
        activationToken &+= 1
        activeSince = nil
    }

    func effectiveDelayMilliseconds(
        requested requestedDelayMilliseconds: Int,
        now: Date = Date()
    ) -> Int {
        let requested = max(0, requestedDelayMilliseconds)
        guard let activeSince else { return requested }

        let elapsed = max(0, now.timeIntervalSince(activeSince))
        let remaining = max(0, minimumDwellSeconds - elapsed)
        let remainingMilliseconds = Int((remaining * 1000.0).rounded(.up))
        return max(requested, remainingMilliseconds)
    }

    func shouldRunHeavyRefresh(for token: UInt64, now: Date = Date()) -> Bool {
        guard token == activationToken else { return false }
        guard let activeSince else { return false }
        return now.timeIntervalSince(activeSince) >= minimumDwellSeconds
    }
}
