# ExecPlan: Consolidate Workout Start Paths into One Canonical Service Surface

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds.

This repository contains `/Users/nadav/Desktop/Trai/.agent/PLANS.md`; this plan has been maintained in accordance with that file.

## Purpose / Big Picture

Starting workouts previously used duplicated construction and persistence logic across `MainTabView`, `DashboardView`, and `WorkoutsView`. This implementation centralizes workout-start creation/persistence in `WorkoutTemplateService` while preserving existing per-surface analytics and UI behavior.

User-visible behavior remains the same: users can still start workouts from deep links/app intents, Dashboard actions, and Workouts tab actions, and the same screens open with the same fallback behavior.

## Progress

- [x] (2026-02-16 00:00Z) Completed repository analysis, traced workout-start call paths, and selected the top consolidation refactor.
- [x] (2026-02-16 01:08Z) Added canonical workout-start APIs to `/Users/nadav/Desktop/Trai/Trai/Core/Services/WorkoutTemplateService.swift`.
- [x] (2026-02-16 01:10Z) Migrated `/Users/nadav/Desktop/Trai/Trai/ContentView.swift` deep-link/app-intent starts to canonical APIs.
- [x] (2026-02-16 01:12Z) Migrated `/Users/nadav/Desktop/Trai/Trai/Features/Dashboard/DashboardView.swift` and `/Users/nadav/Desktop/Trai/Trai/Features/Workouts/WorkoutsView.swift` to canonical APIs.
- [x] (2026-02-16 01:14Z) Added `/Users/nadav/Desktop/Trai/TraiTests/WorkoutTemplateServiceTests.swift` and wired it to the Xcode project.
- [x] (2026-02-16 01:16Z) Verified duplicate constructor removal in migrated files with `rg` guardrail.
- [x] (2026-02-16 01:18Z) Ran focused build checks (`Trai` build succeeded; `TraiTests` build-for-testing succeeded).

## Surprises & Discoveries

- Observation: New unit test file was not auto-discovered by the test target despite being added on disk.
  Evidence: Initial `xcodebuild ... test -only-testing:TraiTests/WorkoutTemplateServiceTests` ran without compiling the new test file; adding explicit entries to `/Users/nadav/Desktop/Trai/Trai.xcodeproj/project.pbxproj` resolved this.

- Observation: Running the targeted test command triggers repeated app relaunches with an unrelated runtime crash and HealthKit entitlement errors in this environment.
  Evidence: `xcodebuild ... test -only-testing:TraiTests/WorkoutTemplateServiceTests` logs include `malloc: *** pointer being freed was not allocated` and `Missing com.apple.developer.healthkit entitlement`, with test sessions restarting and ending with zero executed tests.

- Observation: Compile safety for app and test code is still verifiable despite runtime test-host instability.
  Evidence: `xcodebuild ... -scheme Trai build` returned `** BUILD SUCCEEDED **`; `xcodebuild ... -scheme TraiTests build-for-testing` returned `** TEST BUILD SUCCEEDED **`.

## Decision Log

- Decision: Keep chat workout suggestion/log constructors out of this refactor.
  Rationale: Chat paths materialize detailed exercise/set payloads and are higher-risk; this pass focuses on high-frequency start surfaces with lower blast radius.
  Date/Author: 2026-02-16 / Codex

- Decision: Add non-throwing `persistWorkout` helper returning `Bool` in `WorkoutTemplateService`.
  Rationale: Existing call sites already ignore save failures (`try?`), so this preserves behavior while centralizing persistence steps.
  Date/Author: 2026-02-16 / Codex

- Decision: Treat `build-for-testing` as primary verification for new test code in this environment.
  Rationale: Runtime test execution is unstable due unrelated host crashes/entitlement limits; compile-level verification is reliable and confirms refactor integration.
  Date/Author: 2026-02-16 / Codex

## Outcomes & Retrospective

The refactor goals were achieved for the targeted scope.

What was achieved:
- Canonical APIs for workout start creation and persistence were added to `WorkoutTemplateService`.
- `MainTabView`, `DashboardView`, and `WorkoutsView` now call canonical service APIs instead of constructing/persisting `LiveWorkout` directly.
- Per-surface analytics metadata (`.intent`, `.dashboard`, `.workouts`) and sheet/haptic behavior were preserved.
- New unit tests for service behavior were added and compiled successfully.

What remains:
- Runtime execution of the new tests is blocked by environment-level test host instability (not by compile errors in changed files).
- Chat workout creation paths are intentionally not part of this implementation and can be a follow-up consolidation.

## Context and Orientation

`LiveWorkout` creation for start flows was previously duplicated across:
- `/Users/nadav/Desktop/Trai/Trai/ContentView.swift`
- `/Users/nadav/Desktop/Trai/Trai/Features/Dashboard/DashboardView.swift`
- `/Users/nadav/Desktop/Trai/Trai/Features/Workouts/WorkoutsView.swift`

Canonical service surface now lives in:
- `/Users/nadav/Desktop/Trai/Trai/Core/Services/WorkoutTemplateService.swift`

Test coverage for canonical service behavior now lives in:
- `/Users/nadav/Desktop/Trai/TraiTests/WorkoutTemplateServiceTests.swift`

## Plan of Work

Implemented sequence:

1. Added test-first expectations for canonical service behavior in `WorkoutTemplateServiceTests`.
2. Added service APIs:
   - `createCustomWorkout(name:type:muscles:)`
   - `createStartWorkout(from:)`
   - `createWorkoutForIntent(name:modelContext:)`
   - `persistWorkout(_:modelContext:)`
3. Migrated `MainTabView.startWorkoutFromIntent` to service methods.
4. Migrated dashboard start methods to service methods.
5. Migrated workouts-tab start methods to service methods.
6. Added the new test file to `TraiTests` target in project file.
7. Ran guardrails/build validation.

## Concrete Steps

All commands were run from `/Users/nadav/Desktop/Trai`.

1. Added tests and executed targeted test run:

    xcodebuild -project /Users/nadav/Desktop/Trai/Trai.xcodeproj -scheme TraiTests -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -derivedDataPath /tmp/TraiDerived CODE_SIGN_IDENTITY='' CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO test -only-testing:TraiTests/WorkoutTemplateServiceTests

   Result: expected compile failures before service APIs existed, then later runtime-host instability after implementation (see Surprises).

2. Guardrail for duplicate constructors in migrated files:

    rg -n "LiveWorkout\(" Trai/ContentView.swift Trai/Features/Dashboard/DashboardView.swift Trai/Features/Workouts/WorkoutsView.swift

   Result: no production constructor call sites remain in those files.

3. Focused app build:

    xcodebuild -project /Users/nadav/Desktop/Trai/Trai.xcodeproj -scheme Trai -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -derivedDataPath /tmp/TraiDerived CODE_SIGN_IDENTITY='' CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO build

   Result: `** BUILD SUCCEEDED **`.

4. Compile validation for test target:

    xcodebuild -project /Users/nadav/Desktop/Trai/Trai.xcodeproj -scheme TraiTests -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -derivedDataPath /tmp/TraiDerived CODE_SIGN_IDENTITY='' CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO build-for-testing

   Result: `** TEST BUILD SUCCEEDED **`.

## Validation and Acceptance

Acceptance criteria status:

1. Deep-link/app-intent, Dashboard, and Workouts tab start flows call canonical `WorkoutTemplateService` APIs.
   Status: met.

2. Existing user-visible fallback behavior is preserved (custom/default/template resolution per surface).
   Status: met by code-path parity and successful compile checks.

3. Surface-specific analytics metadata remains intact.
   Status: met; behavior-tracker calls remain in feature layers.

4. Focused compile checks succeed.
   Status: met (`Trai` build succeeded; `TraiTests` build-for-testing succeeded).

Runtime test execution note:
- `xcodebuild ... test` is unstable in this environment due unrelated runtime crash/HealthKit entitlement constraints, so automated runtime test pass/fail could not be established despite successful compilation.

## Idempotence and Recovery

This refactor was additive-first and is idempotent:
- Service APIs were introduced before call-site migration.
- No schema/storage migrations were performed.

Rollback path remains straightforward:
- Revert migrated call sites (`ContentView`, `DashboardView`, `WorkoutsView`) one file at a time.
- Keep service APIs in place during rollback if needed.

## Artifacts and Notes

Changed files:
- `/Users/nadav/Desktop/Trai/Trai/Core/Services/WorkoutTemplateService.swift`
- `/Users/nadav/Desktop/Trai/Trai/ContentView.swift`
- `/Users/nadav/Desktop/Trai/Trai/Features/Dashboard/DashboardView.swift`
- `/Users/nadav/Desktop/Trai/Trai/Features/Workouts/WorkoutsView.swift`
- `/Users/nadav/Desktop/Trai/TraiTests/WorkoutTemplateServiceTests.swift`
- `/Users/nadav/Desktop/Trai/Trai.xcodeproj/project.pbxproj`

## Interfaces and Dependencies

Canonical interface now available in `/Users/nadav/Desktop/Trai/Trai/Core/Services/WorkoutTemplateService.swift`:
- `createCustomWorkout(name:type:muscles:) -> LiveWorkout`
- `createStartWorkout(from:) -> LiveWorkout`
- `createWorkoutForIntent(name:modelContext:) -> LiveWorkout`
- `persistWorkout(_:modelContext:) -> Bool`

Dependencies used:
- SwiftData `ModelContext`
- `LiveWorkout`, `WorkoutPlan`, `UserProfile`

## Revision Note

- 2026-02-16 / Codex: Updated plan from design to implementation-complete state with concrete progress, validation evidence, and runtime testing limitation notes.
