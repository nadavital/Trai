//
//  ActiveWorkoutRuntimeState.swift
//  Trai
//
//  Shared runtime state used to throttle non-essential work while a live workout is on screen.
//

import Foundation
import Combine
import os

struct ActiveWorkoutPresentationTracker {
    private(set) var activePresentationCount: Int = 0
    private(set) var isLiveWorkoutPresented: Bool = false
    private(set) var lastActivatedAt: Date?

    mutating func begin(now: Date = Date()) {
        activePresentationCount += 1
        isLiveWorkoutPresented = true
        if lastActivatedAt == nil {
            lastActivatedAt = now
        }
    }

    mutating func end() {
        activePresentationCount = max(0, activePresentationCount - 1)
        isLiveWorkoutPresented = activePresentationCount > 0
        if !isLiveWorkoutPresented {
            lastActivatedAt = nil
        }
    }

    mutating func reset() {
        activePresentationCount = 0
        isLiveWorkoutPresented = false
        lastActivatedAt = nil
    }
}

final class ActiveWorkoutRuntimeState: ObservableObject {
    private var tracker = ActiveWorkoutPresentationTracker()
    @Published private(set) var isLiveWorkoutPresented: Bool = false
    @Published private(set) var lastActivatedAt: Date?

    func beginLiveWorkoutPresentation() {
        tracker.begin()
        syncPublishedState()
    }

    func endLiveWorkoutPresentation() {
        tracker.end()
        syncPublishedState()
    }

    func setLiveWorkoutPresented(_ isPresented: Bool) {
        if isPresented {
            beginLiveWorkoutPresentation()
        } else {
            tracker.reset()
            syncPublishedState()
        }
    }

    private func syncPublishedState() {
        isLiveWorkoutPresented = tracker.isLiveWorkoutPresented
        lastActivatedAt = tracker.lastActivatedAt
    }
}

enum DashboardRefreshPolicy {
    static func shouldRefreshRecovery(isWorkoutRuntimeActive: Bool) -> Bool {
        !isWorkoutRuntimeActive
    }
}

enum PerformanceTrace {
    enum Category {
        case launch
        case dataLoad
    }

    typealias Interval = OSSignpostIntervalState

    private static let subsystem = Bundle.main.bundleIdentifier ?? "Nadav.Trai"
    private static let launchSignposter = OSSignposter(subsystem: subsystem, category: "Launch")
    private static let dataLoadSignposter = OSSignposter(subsystem: subsystem, category: "DataLoad")

    @discardableResult
    static func begin(_ name: StaticString, category: Category = .launch) -> Interval {
        signposter(for: category).beginInterval(name)
    }

    static func end(
        _ name: StaticString,
        _ interval: Interval,
        category: Category = .launch
    ) {
        signposter(for: category).endInterval(name, interval)
    }

    static func event(_ name: StaticString, category: Category = .launch) {
        signposter(for: category).emitEvent(name)
    }

    private static func signposter(for category: Category) -> OSSignposter {
        switch category {
        case .launch:
            launchSignposter
        case .dataLoad:
            dataLoadSignposter
        }
    }
}

enum LatencyProbe {
    static func timerStart() -> UInt64 {
        DispatchTime.now().uptimeNanoseconds
    }

    static func elapsedMilliseconds(since startNanoseconds: UInt64) -> Double {
        let elapsedNanoseconds = DispatchTime.now().uptimeNanoseconds - startNanoseconds
        return Double(elapsedNanoseconds) / 1_000_000.0
    }

    static func makeEntry(
        operation: String,
        durationMilliseconds: Double,
        counts: [String: Int] = [:]
    ) -> String {
        let durationString = String(format: "%.1f", durationMilliseconds)
        guard !counts.isEmpty else {
            return "\(operation)=\(durationString)ms"
        }
        let detail = counts
            .sorted { lhs, rhs in lhs.key < rhs.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: ",")
        return "\(operation)=\(durationString)ms{\(detail)}"
    }

    static func append(
        entry: String,
        to entries: inout [String],
        maxEntries: Int = 8
    ) {
        entries.append(entry)
        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }
    }
}
