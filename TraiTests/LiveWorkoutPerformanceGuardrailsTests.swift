import XCTest
@testable import Trai

final class LiveWorkoutPerformanceGuardrailsTests: XCTestCase {
    func testSummarizeClassifiesLiveWorkoutVsBackgroundFrames() {
        let samples: [LiveWorkoutPerformanceGuardrails.FrameSample] = [
            .init(threadName: "Main Thread", frames: [
                .init(symbol: "SetRow.body.getter", binaryName: "Trai.debug.dylib")
            ]),
            .init(threadName: "Main Thread", frames: [
                .init(symbol: "WorkoutsView.loadRecoveryAndScores()", binaryName: "Trai.debug.dylib")
            ]),
            .init(threadName: "Main Thread", frames: [
                .init(symbol: "MuscleRecoveryService.getLastTrainedDates(modelContext:)", binaryName: "Trai.debug.dylib")
            ]),
            .init(threadName: "com.apple.SwiftUI.AsyncRenderer", frames: [
                .init(symbol: "DisplayList.ViewUpdater.updateInheritedViewAsync(...)", binaryName: "SwiftUI")
            ]),
            .init(threadName: "Main Thread", frames: [
                .init(symbol: "CompactLiveWorkoutRow.body.getter", binaryName: "Trai.debug.dylib")
            ])
        ]

        let summary = LiveWorkoutPerformanceGuardrails.summarize(samples, topFrameLimit: 3)

        XCTAssertEqual(summary.totalSamples, 5)
        XCTAssertEqual(summary.mainThreadSamples, 4)
        XCTAssertEqual(summary.appStackSamples, 4)
        XCTAssertEqual(summary.liveWorkoutSamples, 2)
        XCTAssertEqual(summary.backgroundSamples, 2)
        XCTAssertEqual(summary.topAppFrames.count, 3)
    }

    func testGuardrailEvaluationFailsWhenBackgroundWorkDominatesAppSamples() {
        let samples: [LiveWorkoutPerformanceGuardrails.FrameSample] = [
            .init(threadName: "Main Thread", frames: [
                .init(symbol: "WorkoutsView.loadRecoveryAndScores()", binaryName: "Trai.debug.dylib")
            ]),
            .init(threadName: "Main Thread", frames: [
                .init(symbol: "MuscleRecoveryService.getLastTrainedDates(modelContext:)", binaryName: "Trai.debug.dylib")
            ]),
            .init(threadName: "Main Thread", frames: [
                .init(symbol: "SetRow.body.getter", binaryName: "Trai.debug.dylib")
            ])
        ]

        let summary = LiveWorkoutPerformanceGuardrails.summarize(samples)
        let thresholds = LiveWorkoutPerformanceGuardrails.Thresholds(
            minimumAppStackSampleShare: 0.5,
            maximumBackgroundShareWithinAppSamples: 0.5
        )

        XCTAssertFalse(summary.meetsTargets(thresholds))
    }
}
