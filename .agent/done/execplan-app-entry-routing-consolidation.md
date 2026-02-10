# ExecPlan: Consolidate App Entry Routing into One Canonical Route Contract

## Problem Statement
App-entry routing for the same destinations is currently split across three mechanisms:
1. URL deep links (`trai://...`) parsed in app shell routing.
2. launch-intent `UserDefaults` flags/payloads consumed in `MainTabView`.
3. widget/control intents that sometimes trigger both mechanisms for one action.

This duplicates one concept ("open Trai into destination X") across app, intents, and widgets, increasing cold-launch miss/race risk and forcing multi-file edits for every new destination.

Evidence:
- Deep-link parsing in app shell:
  - `/Users/nadav/Desktop/Trai/Trai/TraiApp.swift:109`
  - `/Users/nadav/Desktop/Trai/Trai/TraiApp.swift:113`
- Separate launch-intent polling in main tab:
  - `/Users/nadav/Desktop/Trai/Trai/ContentView.swift:229`
  - `/Users/nadav/Desktop/Trai/Trai/ContentView.swift:231`
  - `/Users/nadav/Desktop/Trai/Trai/ContentView.swift:238`
- App intents writing launch flags:
  - `/Users/nadav/Desktop/Trai/Trai/Core/Intents/LogFoodCameraIntent.swift:22`
  - `/Users/nadav/Desktop/Trai/Trai/Core/Intents/StartWorkoutIntent.swift:30`
- Control widget sets launch flag and also opens URL (double path):
  - `/Users/nadav/Desktop/Trai/TraiWidgets/TraiWidgetsControl.swift:39`
  - `/Users/nadav/Desktop/Trai/TraiWidgets/TraiWidgetsControl.swift:40`
- Widget URLs are repeated as raw strings:
  - `/Users/nadav/Desktop/Trai/TraiWidgets/TraiWidgets.swift:113`
  - `/Users/nadav/Desktop/Trai/TraiWidgets/TraiWidgets.swift:176`
  - `/Users/nadav/Desktop/Trai/TraiWidgets/TraiWidgets.swift:280`

Acceptance criteria:
1. One canonical route model encodes/decodes destinations (`logFood`, `logWeight`, `workout(template?)`, `chat`) for app + widgets + intents.
2. `MainTabView` consumes one unified pending-route source and one deep-link handling path (no parallel launch-intent key polling).
3. No raw `trai://...` destination literals remain outside the canonical route type.
4. `Trai` build compiles after refactor; widget quick actions and start-workout intent behavior remain unchanged.

## Repository Mental Model (Evidence-Based)
- App shell/routing boundary:
  - `/Users/nadav/Desktop/Trai/Trai/TraiApp.swift`
  - `/Users/nadav/Desktop/Trai/Trai/ContentView.swift`
- Intent entry boundary:
  - `/Users/nadav/Desktop/Trai/Trai/Core/Intents/LogFoodCameraIntent.swift`
  - `/Users/nadav/Desktop/Trai/Trai/Core/Intents/StartWorkoutIntent.swift`
  - `/Users/nadav/Desktop/Trai/TraiWidgets/TraiWidgetsControl.swift`
- Widget link sources:
  - `/Users/nadav/Desktop/Trai/TraiWidgets/TraiWidgets.swift`
  - `/Users/nadav/Desktop/Trai/TraiWidgets/TraiWidgetsLiveActivity.swift`

Core flow traces:
1. Home widget "Log Food": `Link("trai://logfood")` -> app `onOpenURL` parse -> tab-level route handling -> `showingFoodCamera`.
2. Siri/App Shortcut "Start Workout": `StartWorkoutIntent` writes launch key -> `MainTabView.checkForAppIntentTriggers()` reads key -> `startWorkoutFromIntent`.
3. Control Center "Start Workout": writes launch key and opens `trai://workout`, meaning two routing signals can be active for one user action.

Dependency highlights (repo reference counts from scan):
- `LiveWorkout` (200), `UserProfile` (139), `FoodEntry` (101), `WorkoutPlan` (99), `ChatMessage` (94), `GeminiService` (51).
- These are stable high-coupling domains; app-entry routing is lower fan-out but high break impact because it gates app launch flows.

Identified smells:
- Duplicate abstractions: deep-link enum + launch-intent flags both represent destination routing.
- Shotgun surgery: adding/changing destinations requires edits in app shell, tab view, intents, and widgets.
- Leaky boundary: feature views are aware of persistence-key mechanics (`SharedStorageKeys.LaunchIntents`) instead of route semantics.

## Assumptions
- Production caution applies; behavior must remain user-visible equivalent.
- URL scheme `trai://` remains the public external route scheme.
- App Intents that cannot pass URL directly still can write a shared pending route payload.
- No data migration is required (ephemeral launch routing only).

## Scope
In scope:
- Introduce one shared route contract + pending-route store helper.
- Rewire deep links, app intents, and widgets to use canonical route encode/decode helpers.
- Remove parallel launch-intent boolean/string key handling in `MainTabView`.

Out of scope:
- Redesigning tab navigation UX.
- Changing widget visual layout.
- Broader refactor of workout creation flows.

## Impacted Paths
- `/Users/nadav/Desktop/Trai/Shared/Contracts/` (new route contract/store file)
- `/Users/nadav/Desktop/Trai/Shared/Contracts/SharedStorageKeys.swift`
- `/Users/nadav/Desktop/Trai/Trai/TraiApp.swift`
- `/Users/nadav/Desktop/Trai/Trai/ContentView.swift`
- `/Users/nadav/Desktop/Trai/Trai/Core/Intents/LogFoodCameraIntent.swift`
- `/Users/nadav/Desktop/Trai/Trai/Core/Intents/StartWorkoutIntent.swift`
- `/Users/nadav/Desktop/Trai/TraiWidgets/TraiWidgets.swift`
- `/Users/nadav/Desktop/Trai/TraiWidgets/TraiWidgetsControl.swift`
- `/Users/nadav/Desktop/Trai/TraiWidgets/TraiWidgetsLiveActivity.swift`
- `/Users/nadav/Desktop/Trai/Trai.xcodeproj/project.pbxproj` (if new shared file requires registration)

## Execution Plan

### Phase 1: Introduce canonical app route contract
- [x] Add a shared `AppRoute` model in `/Users/nadav/Desktop/Trai/Shared/Contracts/`:
  - Cases: `.logFood`, `.logWeight`, `.workout(templateName: String?)`, `.chat`
  - URL builder/parser helpers (single authority for host/query mapping)
  - Convenience `urlString`/`url` accessors for widgets/intents
- [x] Add a small `PendingAppRouteStore` helper to write/read/clear one pending route payload in `UserDefaults`.
- [x] Replace launch-intent key naming in `SharedStorageKeys` with a single pending-route key (keep backwards-compatible fallback read during migration window if needed).

### Phase 2: Collapse app-side routing to one path
- [x] In `/Users/nadav/Desktop/Trai/Trai/TraiApp.swift`, parse incoming URL into canonical `AppRoute` and pass that into `ContentView`.
- [x] In `/Users/nadav/Desktop/Trai/Trai/ContentView.swift`, replace `checkForAppIntentTriggers()` with unified `consumePendingRoute()` and route executor.
- [x] Ensure `onAppear` still processes pending routes for cold-launch reliability and `.onChange` handles live deep links.

### Phase 3: Rewire intents and widgets to shared route helpers
- [x] Update app intents (`LogFoodCameraIntent`, `StartWorkoutIntent`) to write `PendingAppRouteStore` instead of separate keys.
- [x] Update control widget intent to use one mechanism (canonical route + URL helper) and remove redundant dual signaling.
- [x] Replace hardcoded `trai://...` literals in widget files with `AppRoute` URL helpers, including template workout URL construction.

### Phase 4: Remove dead routing branches
- [x] Delete old launch-intent polling logic and legacy key usage in app UI code.
- [x] Remove stale helper code that duplicates route parsing/encoding.
- [x] Run grep guardrails to ensure route strings/keys are centralized.

### Phase 5: Compile + behavior validation
- [x] Build app target:
  - `xcodebuild -project /Users/nadav/Desktop/Trai/Trai.xcodeproj -scheme Trai -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/TraiDerived CODE_SIGN_IDENTITY='' CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO build`
  - Result: blocked by existing Xcode preview macro host/plugin errors in widget preview sections (`PreviewsMacros.Common`), not by route-refactor compile errors in modified routing files.
- [ ] Focused runtime checks:
  - Widget `Log Food` opens food camera on cold launch and warm launch.
  - Shortcut `Start Workout` starts or opens in-progress workout exactly once.
  - `trai://workout?template=...` still preselects template flow.

## Validation Checklist
- [x] No references remain to `SharedStorageKeys.LaunchIntents.openFoodCamera` or `SharedStorageKeys.LaunchIntents.startWorkout`.
- [x] No raw destination literals `trai://logfood`, `trai://logweight`, `trai://workout`, `trai://chat` remain outside canonical route file(s).
- [ ] App cold-launch routing works from widget and Siri shortcut paths.
- [ ] App build succeeds for the `Trai` scheme. (Blocked by environment-level preview macro plugin errors.)

## Risks and Mitigations
- Risk: Launch regression for existing shortcuts during migration.
  - Mitigation: keep one-release fallback read for old launch keys before full removal.
- Risk: URL encoding mismatch for template names.
  - Mitigation: centralize percent-encoding/decoding in one route helper with targeted tests.
- Risk: Double-trigger behavior changes perceived by users.
  - Mitigation: explicitly consume-and-clear pending route atomically before handling.

## Rollback
- Revert new shared route/store files and call-site rewires.
- Restore prior `DeepLinkDestination` + `checkForAppIntentTriggers` path.
- Restore launch-intent key writers in app/control intents.
- No persistence/data migration rollback required.

## Candidate Ranking (Scored)
| Candidate | Payoff (30%) | Blast Radius (25%) | Cognitive Load (20%) | Velocity Unlock (15%) | Validation/Rollback (10%) | Weighted |
|---|---:|---:|---:|---:|---:|---:|
| Consolidate app-entry routing (deep links + launch intents + widget route strings) **(chosen)** | 4 | 4 | 5 | 4 | 5 | 4.30 |
| Consolidate workout creation/start logic behind one launcher/service (currently spread across `ContentView`, `WorkoutsView`, `DashboardView`, `ChatViewActions`) | 5 | 2 | 4 | 4 | 3 | 3.70 |
| Normalize `HealthKitService` lifecycle ownership (remove mixed per-view instances vs app environment instance) | 3 | 3 | 4 | 3 | 3 | 3.20 |
| Remove thin `LiveActivityIntentKeys` wrapper and use `SharedStorageKeys` directly | 2 | 5 | 2 | 2 | 5 | 3.05 |
