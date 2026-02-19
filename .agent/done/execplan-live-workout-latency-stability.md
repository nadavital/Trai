# Stabilize Live Workout Latency On Real Devices

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds.

This plan is governed by `/Users/nadav/Desktop/Trai/.agent/PLANS.md` and must remain compliant with that file.

## Purpose / Big Picture

The goal is to keep the live workout screen responsive on iPhone even as workout history, exercise history, and CloudKit-backed data grow. After this work, users should be able to edit reps/weight, add sets, and switch exercises in `LiveWorkoutView` without keyboard lag or long pauses, while the rest of the app continues to function correctly in the background. Success is demonstrated by repeatable on-device profiling runs that show reduced main-thread time in live-workout interactions and stable interaction latency on both fresh and data-heavy installs.

## Progress

- [x] (2026-02-16 05:28Z) Captured the problem statement and drafted a full execution plan focused on on-device latency and data-growth stability.
- [x] (2026-02-16 06:10Z) Milestone 1 complete: added deterministic seeder, launch arg wiring, device profiling script, docs, and seeder tests.
- [x] (2026-02-16 06:18Z) Milestone 2 complete: added active workout runtime state and gated Dashboard/Workouts heavy recomputation with tests.
- [x] (2026-02-16 06:26Z) Milestone 3 complete: added update policy, adaptive intent polling, watch payload delta publishing, and TimelineView banner with tests.
- [x] (2026-02-16 06:40Z) Milestone 4 complete: added persistence coordinator, critical flush wiring, fixed coordinator deinit crash by replacing `Task.sleep` scheduling with `DispatchWorkItem`, and passing tests.
- [x] (2026-02-16 06:52Z) Milestone 5 complete: added performance guardrail helper/tests, executed fresh/heavy/long-session device captures, produced report, and updated troubleshooting docs.

## Surprises & Discoveries

- Observation: Simulator traces can look healthy while the phone still feels slow.
  Evidence: Current simulator captures showed acceptable behavior after small optimizations, but user-reported iPhone latency remains high.
- Observation: Non-live-workout paths still appeared in traces while interacting with live workout.
  Evidence: Prior traces included dashboard recovery/template scoring frames and global view work while a workout sheet was open.
- Observation: Data volume is likely a multiplier.
  Evidence: Current runs were done in a relatively fresh simulator state; production phones carry much larger HealthKit and SwiftData histories.
- Observation: The first persistence coordinator implementation could crash on deallocation in tests.
  Evidence: crash reports showed `pointer being freed was not allocated` in `LiveWorkoutPersistenceCoordinator.__deallocating_deinit` with pending/cancelled `Task` storage.
- Observation: Device process attach by PID is less reliable than launch-mode recording for this app/device setup.
  Evidence: repeated `Cannot find process for provided pid` failures despite a visible process; `xctrace --launch -- Nadav.Trai` was stable.
- Observation: Exporting `time-profile` provides symbol-rich frame names, while `time-sample` export tends to collapse into raw PCs.
  Evidence: switching export preference to `time-profile` yielded actionable frame names (e.g., `WorkoutsView.loadRecoveryAndScores`, `MuscleRecoveryService`).

## Decision Log

- Decision: Start with device-first measurement and data-scale reproducibility before further code changes.
  Rationale: Without reproducible baseline and stress datasets, optimization work risks targeting simulator artifacts rather than real bottlenecks.
  Date/Author: 2026-02-16 / Codex
- Decision: Treat background-tab invalidation and persistence frequency as first-class latency causes, not just live-workout row rendering.
  Rationale: Existing traces and architecture indicate sheet presentation does not stop tab-level observation and computed work.
  Date/Author: 2026-02-16 / Codex
- Decision: Use `DispatchWorkItem` coalescing in persistence coordinator instead of task-sleep based scheduling.
  Rationale: avoided coordinator teardown crash path in Swift task deallocation while preserving debounce/flush semantics.
  Date/Author: 2026-02-16 / Codex
- Decision: Prefer `xctrace` launch-mode capture for device profiling in the script and keep PID attach for explicit `--skip-launch` mode only.
  Rationale: launch-mode proved consistently attachable during repeated runs on iPhone.
  Date/Author: 2026-02-16 / Codex
- Decision: Prefer `time-profile` export for hotspot generation.
  Rationale: provides symbol-rich frame names and supports actionable classification for report guardrails.
  Date/Author: 2026-02-16 / Codex

## Outcomes & Retrospective

- Milestone 1 outcome:
  - Deterministic heavy-data seeding and reproducible device profiling commands are now first-class workflow artifacts.
  - Residual risk: profile script robustness needed hardening (now addressed with launch-mode + resilient export handling).
- Milestone 2 outcome:
  - Active workout runtime gating prevents constant forced refreshes, but traces still show low-level background indicators under heavy/long-session scenarios.
  - Residual risk: additional suppression may still be needed for certain `WorkoutsView`/`MuscleRecoveryService` paths.
- Milestone 3 outcome:
  - Timer/polling churn was reduced structurally (adaptive intent polling + delta watch publishing + TimelineView banner rendering).
  - Residual risk: SwiftUI graph update cost remains visible when list/filter work is triggered.
- Milestone 4 outcome:
  - Save coalescing and critical flush logic are centralized and covered by tests, with a resolved coordinator teardown crash.
  - Residual risk: long-session data integrity under force-close still requires explicit manual scenario validation.
- Milestone 5 outcome:
  - Three device captures (`fresh`, `heavy`, `long-session`) were produced and summarized in `/Users/nadav/Desktop/Trai/.agent/done/live-workout-latency-report.md`.
  - Acceptance status is partially met: background-tab indicators are reduced but not eliminated, and full manual 90s edit-burst validation remains to be repeated with operator-driven input during capture.

## Context and Orientation

The live workout flow starts from `MainTabView` in `/Users/nadav/Desktop/Trai/Trai/ContentView.swift`, which presents `/Users/nadav/Desktop/Trai/Trai/Features/Workouts/LiveWorkoutView.swift` in a sheet while the underlying tabs remain mounted. Live workout state and side effects are concentrated in `/Users/nadav/Desktop/Trai/Trai/Features/Workouts/LiveWorkoutViewModel.swift` and health streaming is in `/Users/nadav/Desktop/Trai/Trai/Core/Services/HealthKitService.swift`.

`LiveWorkoutViewModel` currently performs high-frequency activities during active sessions: App Group polling for Live Activity intents, periodic Live Activity updates, debounced SwiftData saves, and watch-data synchronization. In parallel, dashboard/workout tabs still own expensive computed paths, notably recovery/template scoring in `/Users/nadav/Desktop/Trai/Trai/Features/Dashboard/DashboardView.swift`, `/Users/nadav/Desktop/Trai/Trai/Core/Services/MuscleRecoveryService.swift`, and `/Users/nadav/Desktop/Trai/Trai/Features/Workouts/WorkoutsView.swift`.

In this repository, “background-tab work” means code still executing in non-visible tabs because `TabView` keeps view trees and `@Query`/computed properties live. “Persistence pressure” means frequent writes to `ModelContext` causing merge, observation invalidation, and CloudKit synchronization overhead. “Data-growth stability” means latency remains acceptable after large workout/history datasets, not only on fresh installs.

## Plan of Work

Milestone 1 will establish reproducible on-device baselines for two states: fresh data and synthetic heavy data. This milestone adds a small profiling helper script and a deterministic local seed utility so the team can reproduce the same workload repeatedly.

Milestone 2 will introduce active-workout runtime gating so expensive dashboard/workouts recomputation is suspended (or heavily throttled) while a live workout sheet is presented. This keeps background tabs from competing with set-entry interactions.

Milestone 3 will reduce high-frequency main-thread churn in the active workout loop by consolidating timers/polling, moving non-UI processing off the main actor when safe, and ensuring only UI-relevant deltas are published.

Milestone 4 will harden persistence behavior for continuous editing by centralizing save scheduling and explicitly separating “critical flush points” (finish workout, app background, dismissal) from high-frequency incremental edits.

Milestone 5 will validate outcomes with on-device traces and behavior checks, then document measured deltas and remaining follow-up work.

## Milestones

### Milestone 1: Device Baseline + Data-Scale Repro Harness

At the end of this milestone, any contributor can run identical on-device traces for fresh and heavy datasets.

1. Tests to write first:
   - Add `/Users/nadav/Desktop/Trai/TraiTests/LiveWorkoutPerformanceDataSeederTests.swift`.
   - Add `testSeedDeterministicWorkoutCountAndEntryShape()` asserting deterministic record counts for a fixed seed.
   - Add `testSeedGeneratesCompletedAndActiveWorkoutMix()` asserting both completed and in-progress workouts exist.
2. Implementation:
   - Add `/Users/nadav/Desktop/Trai/Trai/Core/Performance/LiveWorkoutPerformanceDataSeeder.swift` for deterministic synthetic data generation.
   - Add `/Users/nadav/Desktop/Trai/scripts/profile_live_workout_device.sh` to wrap `xctrace` attach/export commands for a connected device.
   - Add developer-facing usage notes in `/Users/nadav/Desktop/Trai/COMMON_ISSUES.md` (short section, exact commands).
3. Verification:
   - Run tests and confirm they fail before implementation and pass after.
   - Seed synthetic dataset in debug build and confirm counts with a simple debug log/assertion path.
   - Capture one fresh-data and one heavy-data trace with script; store output paths under `/tmp`.
4. Commit:
   - Commit with message: `Milestone 1: Add device profiling harness and deterministic data seeder`.

### Milestone 2: Suspend Background Tab Heavy Work During Active Workout

At the end of this milestone, live workout interactions no longer trigger repeated heavy dashboard/workout recomputation while sheet is open.

1. Tests to write first:
   - Add `/Users/nadav/Desktop/Trai/TraiTests/ActiveWorkoutRuntimeStateTests.swift`.
   - Add `testMarksActiveWhileLiveWorkoutSheetPresented()`.
   - Add `testDashboardRefreshPolicySkipsRecoveryWhenWorkoutActive()`.
2. Implementation:
   - Add `/Users/nadav/Desktop/Trai/Trai/Core/Performance/ActiveWorkoutRuntimeState.swift` as a lightweight observable runtime flag.
   - Wire runtime state in `/Users/nadav/Desktop/Trai/Trai/ContentView.swift` and sheet presentation lifecycle.
   - In `/Users/nadav/Desktop/Trai/Trai/Features/Dashboard/DashboardView.swift`, gate `dailyCoachContext` and related recovery/template recomputation when active workout runtime is true, using cached last-known values.
   - In `/Users/nadav/Desktop/Trai/Trai/Features/Workouts/WorkoutsView.swift`, defer `loadRecoveryAndScores()` while active workout runtime is true.
3. Verification:
   - Unit tests fail before changes and pass after.
   - Manual scenario: start workout, enter sets for 60 seconds, verify no visible dashboard-triggered stutter.
   - Trace comparison: reduced samples in `DashboardView` / `MuscleRecoveryService` during live workout.
4. Commit:
   - Commit with message: `Milestone 2: Gate dashboard/workouts heavy recomputation during active workout`.

### Milestone 3: Reduce Timer/Polling and Main-Actor Churn in Active Workout Loop

At the end of this milestone, only necessary updates hit the main actor during active workouts.

1. Tests to write first:
   - Add `/Users/nadav/Desktop/Trai/TraiTests/LiveWorkoutUpdatePolicyTests.swift`.
   - Add `testLiveActivityIntentPollingBacksOffWhenAppForegrounded()`.
   - Add `testWatchDataPublishSkipsUnchangedPayloads()`.
2. Implementation:
   - In `/Users/nadav/Desktop/Trai/Trai/Features/Workouts/LiveWorkoutViewModel.swift`, introduce a small update policy object that controls polling intervals by app state.
   - Back off App Group intent polling from 0.5s to a slower interval in foreground, keep faster behavior only when necessary for lock-screen intent responsiveness.
   - Keep `updateWatchDataFromService()` delta-based and move any non-UI transforms out of main actor boundaries where safe.
   - In `/Users/nadav/Desktop/Trai/Trai/Features/Workouts/WorkoutBanner.swift`, replace manual `Timer` with lighter timeline-driven rendering and cached stats.
3. Verification:
   - Unit tests fail before implementation and pass after.
   - Manual scenario: continuous typing in set rows for 90 seconds should not hitch while watch data updates.
   - Trace comparison: reduced samples in timer callback thunks and main-actor update glue.
4. Commit:
   - Commit with message: `Milestone 3: Throttle active-workout polling and main-thread update churn`.

### Milestone 4: Persistence Coalescing for Long Sessions and Large Stores

At the end of this milestone, frequent set edits do not force excessive save/merge/sync cycles while preserving data safety.

1. Tests to write first:
   - Add `/Users/nadav/Desktop/Trai/TraiTests/LiveWorkoutPersistenceCoordinatorTests.swift`.
   - Add `testCoalescesRapidEditBurstsIntoSingleSaveWindow()`.
   - Add `testCriticalEventsForceImmediateFlush()` for finish workout, app background, and explicit stop.
2. Implementation:
   - Add `/Users/nadav/Desktop/Trai/Trai/Core/Performance/LiveWorkoutPersistenceCoordinator.swift`.
   - Use coordinator in `/Users/nadav/Desktop/Trai/Trai/Features/Workouts/LiveWorkoutViewModel.swift` for all save paths.
   - Ensure explicit flush on `finishWorkout()`, `stopTimer()`, and scene transition to background in `/Users/nadav/Desktop/Trai/Trai/TraiApp.swift`.
   - Keep behavior correct for crash safety by bounding maximum unsaved interval.
3. Verification:
   - Tests fail before implementation and pass after.
   - Manual scenario: 5-minute edit session with rapid changes; data remains intact after force-closing and relaunching.
   - Device trace comparison: reduced main-thread and sync-related churn during edit bursts.
4. Commit:
   - Commit with message: `Milestone 4: Add persistence coordinator for live workout edit coalescing`.

### Milestone 5: Device Regression Pass and Stability Sign-Off

At the end of this milestone, measured results and acceptance thresholds are documented and reproducible.

1. Tests to write first:
   - Add `/Users/nadav/Desktop/Trai/TraiTests/LiveWorkoutPerformanceGuardrailsTests.swift` for deterministic helper logic used in performance reports (not runtime FPS assertions).
2. Implementation:
   - Add `/Users/nadav/Desktop/Trai/.agent/done/live-workout-latency-report.md` template and fill with measured before/after summary for fresh and heavy data traces.
   - Update `/Users/nadav/Desktop/Trai/COMMON_ISSUES.md` with troubleshooting matrix for phone-only latency.
3. Verification:
   - Execute three scripted on-device runs: fresh data, seeded heavy data, and long-session edit burst.
   - Confirm report includes trace paths, top hotspots, and whether acceptance targets are met.
4. Commit:
   - Commit with message: `Milestone 5: Document device performance regression results and guardrails`.

## Concrete Steps

All commands run from `/Users/nadav/Desktop/Trai` unless stated otherwise.

1. Baseline build and tests:

    xcodebuild -project Trai.xcodeproj -scheme Trai -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug build CODE_SIGNING_ALLOWED=NO
    xcodebuild -project Trai.xcodeproj -scheme Trai -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug test CODE_SIGNING_ALLOWED=NO

2. Device profiling wrapper usage (after Milestone 1 adds script):

    ./scripts/profile_live_workout_device.sh --udid <DEVICE_UDID> --bundle-id Nadav.Trai --duration 90 --tag fresh
    ./scripts/profile_live_workout_device.sh --udid <DEVICE_UDID> --bundle-id Nadav.Trai --duration 90 --tag heavy

3. Synthetic heavy dataset seeding (after Milestone 1):

    xcrun simctl launch booted Nadav.Trai --seed-live-workout-perf-data

4. Acceptance profiling loop (after Milestones 2-4):

    ./scripts/profile_live_workout_device.sh --udid <DEVICE_UDID> --bundle-id Nadav.Trai --duration 90 --tag postopt

Expected evidence artifacts:

- `/tmp/Trai-liveworkout-*.trace`
- `/tmp/Trai-liveworkout-*.xml`
- `/tmp/Trai-liveworkout-*-hotspots.csv`
- `/Users/nadav/Desktop/Trai/.agent/done/live-workout-latency-report.md`

## Validation and Acceptance

Acceptance is behavior-focused and must pass on a physical iPhone, not only simulator:

1. During a 90-second continuous edit scenario (typing reps/weight, adding sets), UI input remains responsive with no multi-second stalls.
2. Trace hotspots are dominated by live-workout code paths rather than dashboard/recovery paths while the sheet is active.
3. Under seeded heavy data, responsiveness remains comparable to fresh-data runs (no major regression in interaction quality).
4. Data integrity remains correct after long sessions and abrupt app lifecycle transitions.

For each milestone, follow the required workflow: write failing tests, implement, run tests to pass, run milestone verification commands, then commit.

## Idempotence and Recovery

All milestones are additive and can be repeated safely. Seeding must be deterministic and either idempotent by key or protected by a clear reset flag to prevent duplicate runaway data creation. Profiling scripts must write timestamped filenames under `/tmp` to avoid overwriting previous captures. If a milestone introduces instability, revert only that milestone commit and keep the profiling harness and tests intact for diagnosis.

## Artifacts and Notes

Existing trace artifacts that motivated this plan:

- `/tmp/Trai-liveworkout-20260215-205926.trace`
- `/tmp/Trai-liveworkout-time-sample.xml`
- `/tmp/Trai-liveworkout-hotspots.csv`
- `/tmp/Trai-liveworkout-postopt-20260215-210411.trace`
- `/tmp/Trai-liveworkout-postopt-time-sample.xml`
- `/tmp/Trai-liveworkout-postopt-hotspots.csv`

Short note for implementer: simulator smoothness is not sufficient evidence. Always validate on device with both low and high data volume.

## Interfaces and Dependencies

New internal interfaces expected by the end of this plan:

- `ActiveWorkoutRuntimeState` in `/Users/nadav/Desktop/Trai/Trai/Core/Performance/ActiveWorkoutRuntimeState.swift`.
  - Responsibility: expose whether a live workout is actively presented/running so non-visible tabs can throttle work.
- `LiveWorkoutPersistenceCoordinator` in `/Users/nadav/Desktop/Trai/Trai/Core/Performance/LiveWorkoutPersistenceCoordinator.swift`.
  - Responsibility: coalesce non-critical save requests and force flush on critical lifecycle events.
- `LiveWorkoutPerformanceDataSeeder` in `/Users/nadav/Desktop/Trai/Trai/Core/Performance/LiveWorkoutPerformanceDataSeeder.swift`.
  - Responsibility: generate deterministic local stress data for reproducible profiling.

No new third-party library is required. Use existing SwiftUI, SwiftData, HealthKit, and xctrace tooling.

Plan revision note: Initial ExecPlan draft created to address device-only live workout latency and data-growth concerns raised by the user, with explicit on-device measurement gates to avoid simulator-only conclusions.
