//
//  LiveWorkoutPerformanceGuardrails.swift
//  Trai
//
//  Deterministic helper logic for summarizing live-workout performance traces.
//

import Foundation

struct LiveWorkoutPerformanceGuardrails {
    struct FrameSample: Equatable {
        let threadName: String
        let frames: [Frame]

        init(threadName: String, frames: [Frame]) {
            self.threadName = threadName
            self.frames = frames
        }
    }

    struct Frame: Equatable {
        let symbol: String
        let binaryName: String

        init(symbol: String, binaryName: String) {
            self.symbol = symbol
            self.binaryName = binaryName
        }
    }

    struct Thresholds: Equatable {
        var minimumAppStackSampleShare: Double
        var maximumBackgroundShareWithinAppSamples: Double

        static let defaultDeviceThresholds = Thresholds(
            minimumAppStackSampleShare: 0.05,
            maximumBackgroundShareWithinAppSamples: 0.35
        )
    }

    struct Summary: Equatable {
        struct FrameCount: Equatable {
            let symbol: String
            let samples: Int
        }

        let totalSamples: Int
        let mainThreadSamples: Int
        let appStackSamples: Int
        let liveWorkoutSamples: Int
        let backgroundSamples: Int
        let topAppFrames: [FrameCount]

        var mainThreadShare: Double {
            ratio(mainThreadSamples, totalSamples)
        }

        var appStackSampleShare: Double {
            ratio(appStackSamples, totalSamples)
        }

        var backgroundShareWithinAppSamples: Double {
            ratio(backgroundSamples, appStackSamples)
        }

        func meetsTargets(_ thresholds: Thresholds = .defaultDeviceThresholds) -> Bool {
            appStackSampleShare >= thresholds.minimumAppStackSampleShare
                && backgroundShareWithinAppSamples <= thresholds.maximumBackgroundShareWithinAppSamples
        }

        private func ratio(_ numerator: Int, _ denominator: Int) -> Double {
            guard denominator > 0 else { return 0 }
            return Double(numerator) / Double(denominator)
        }
    }

    static func summarize(_ samples: [FrameSample], topFrameLimit: Int = 10) -> Summary {
        var mainThreadSamples = 0
        var appStackSamples = 0
        var liveWorkoutSamples = 0
        var backgroundSamples = 0
        var appFrameCounts: [String: Int] = [:]

        for sample in samples {
            if sample.threadName.localizedCaseInsensitiveContains("main thread") {
                mainThreadSamples += 1
            }

            guard let firstAppFrame = sample.frames.first(where: { $0.binaryName == "Trai.debug.dylib" }) else {
                continue
            }

            appStackSamples += 1
            appFrameCounts[firstAppFrame.symbol, default: 0] += 1

            if isBackgroundFrame(firstAppFrame.symbol) {
                backgroundSamples += 1
            }
            if isLiveWorkoutFrame(firstAppFrame.symbol) {
                liveWorkoutSamples += 1
            }
        }

        let sortedTopFrames = appFrameCounts
            .sorted { lhs, rhs in
                if lhs.value != rhs.value {
                    return lhs.value > rhs.value
                }
                return lhs.key.localizedStandardCompare(rhs.key) == .orderedAscending
            }
            .prefix(max(1, topFrameLimit))
            .map { Summary.FrameCount(symbol: $0.key, samples: $0.value) }

        return Summary(
            totalSamples: samples.count,
            mainThreadSamples: mainThreadSamples,
            appStackSamples: appStackSamples,
            liveWorkoutSamples: liveWorkoutSamples,
            backgroundSamples: backgroundSamples,
            topAppFrames: sortedTopFrames
        )
    }

    private static func isLiveWorkoutFrame(_ symbol: String) -> Bool {
        let lower = symbol.lowercased()
        return lower.contains("liveworkout")
            || lower.contains("setrow")
            || lower.contains("exercisecard")
            || lower.contains("compactliveworkoutrow")
    }

    private static func isBackgroundFrame(_ symbol: String) -> Bool {
        let lower = symbol.lowercased()
        return lower.contains("dashboard")
            || lower.contains("workoutsview")
            || lower.contains("musclerecoveryservice")
            || lower.contains("loadrecoveryandscores")
            || lower.contains("widgetdataprovider")
    }
}
