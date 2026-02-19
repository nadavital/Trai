//
//  LiveWorkoutPersistenceCoordinator.swift
//  Trai
//
//  Coalesces frequent edit saves and guarantees flushes on critical events.
//

import Foundation

@MainActor
final class LiveWorkoutPersistenceCoordinator {
    enum FlushTrigger: Equatable {
        case finishWorkout
        case stopWorkout
        case appBackground
        case sheetDismissed
        case manual
    }

    struct Configuration {
        var coalescingDelay: Duration
        var maxUnsavedInterval: Duration

        nonisolated static let liveWorkoutDefault = Configuration(
            coalescingDelay: .milliseconds(1200),
            maxUnsavedInterval: .seconds(8)
        )
    }

    private let configuration: Configuration
    private let saveHandler: @MainActor () throws -> Void

    private var firstPendingSaveAt: Date?
    private var pendingSaveWorkItem: DispatchWorkItem?
    private(set) var lastSaveAt: Date?

    init(
        configuration: Configuration = .liveWorkoutDefault,
        saveHandler: @escaping @MainActor () throws -> Void
    ) {
        self.configuration = configuration
        self.saveHandler = saveHandler
    }

    deinit {
        pendingSaveWorkItem?.cancel()
        pendingSaveWorkItem = nil
    }

    func requestSave() {
        let now = Date()
        if firstPendingSaveAt == nil {
            firstPendingSaveAt = now
        }

        pendingSaveWorkItem?.cancel()
        let delay = effectiveDelay(now: now)
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.pendingSaveWorkItem = nil
            self.performSave()
        }
        pendingSaveWorkItem = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + delay,
            execute: workItem
        )
    }

    func flushNow(trigger _: FlushTrigger) {
        pendingSaveWorkItem?.cancel()
        pendingSaveWorkItem = nil
        performSave()
    }

    func cancelPending() {
        pendingSaveWorkItem?.cancel()
        pendingSaveWorkItem = nil
        firstPendingSaveAt = nil
    }

    private func effectiveDelay(now: Date) -> TimeInterval {
        guard let firstPendingSaveAt else {
            return durationToSeconds(configuration.coalescingDelay)
        }

        let elapsed = now.timeIntervalSince(firstPendingSaveAt)
        let maxUnsavedSeconds = durationToSeconds(configuration.maxUnsavedInterval)
        let remaining = max(0, maxUnsavedSeconds - elapsed)
        let coalesceSeconds = durationToSeconds(configuration.coalescingDelay)
        return min(coalesceSeconds, remaining)
    }

    private func performSave() {
        do {
            try saveHandler()
        } catch {
            // Keep app interactions responsive; save failures can retry on the next flush.
        }
        firstPendingSaveAt = nil
        lastSaveAt = Date()
    }

    private func durationToSeconds(_ duration: Duration) -> Double {
        let components = duration.components
        return Double(components.seconds) + (Double(components.attoseconds) / 1_000_000_000_000_000_000)
    }
}
