# Core journey validation — September 27, 2026

## Cold workout launch

Reproduced a blank first frame with Trai using about one CPU core. The first sample repeatedly visited native tab accessory layout. Removing the accessory did not eliminate the stall. A second sample exposed repeated `selectedTabState` → `persistedSelectedTabRaw` → `selectedTabState` updates during cold routing.

Fixed the selection feedback loop in `ContentView.swift`: saved selection is restored once; subsequent selection changes persist one way. The original native bottom accessory is retained. Experimental deferred insertion, fixed height, and safe-area replacement were removed.

Three independent cold-launch / reopen / finish runs passed after the fix. The tests now require workout-specific controls rather than accepting any navigation bar. The stress path asserts failures instead of skipping when explicitly requested, adds 12 sets in three bursts, and proves those sets survive actual sheet dismissal and reopening. Minimize checks wait for the workout sheet to disappear and the banner to become hittable.

## Food and weight

Food correction focuses immediately when Adjust estimate is tapped, dismisses the keyboard on Update, and keeps portion-adjusted values. Naming supports Done. The default portion label omits a redundant 1 × prefix.

Seven simulator journey tests passed together: camera analysis and save updating the nutrition section; local portion edit and save; AI correction of the adjusted portion; retake/cancel without save; weight save updating the scale, header and history; workout minimize/reopen/finish; workout mutation stress and pause/resume toggle.

Screenshots: `/Users/nadav/.codex/visualizations/2026/09/19/01a0b6f9-bf5f-7100-8d57-794c1fdf0060/core-journeys/`.

## Proof boundaries

Fixture AI and in-memory app data were used for simulator journeys. These results do not establish physical camera quality, live AI estimates, Apple Watch synchronization, HealthKit exports, persistence across process termination, or pause-state restoration after termination. The iPhone is paired; the Apple Watch was unavailable during device inventory. No physical-device or Watch pass is claimed.

The repository command `scripts/run_live_workout_stability.sh --mode sim` passed all stages: 10 focused unit tests, the strengthened UI stress test, and both startup/tab-switch and Add Exercise latency smoke tests.

## Release

Trai 1.2 (42) was archived, exported with `testFlightInternalTestingOnly=true`, uploaded, and processed successfully. App Store Connect confirms `IN_BETA_TESTING` in the existing internal Friends and Family group and `NOT_APPLICABLE` for external testing. See [release evidence](internal-testflight-2026-09-27.md).
