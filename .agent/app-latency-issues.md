# Trai App Latency Issue Register

This file tracks launch, reopen, and tab-switch latency work so regressions stay visible as the app grows.

## Active Issues

- `APP-LAT-001` Startup to usable tab shell is too slow.
  - Status: In Progress
  - Baseline signal: `startup_to_tabbar` was previously measured around `5.10s` to `5.14s`.
  - Latest signal (2026-02-17):
    - simulator: `startup_to_tabbar=5.430s` in regression run.
    - real-data device: repeated runs between `8.571s` and `10.682s` (`startup_to_tabbar_real_data`).
  - Current direction: continue startup-path trimming with focus on `TraiApp.init` (container/service init) and first-dashboard render path; keep simulator budget gate at `5.8s`.

- `APP-LAT-002` Foreground reopen can feel slow and must be measured independently.
  - Status: Resolved
  - Baseline signal: no dedicated guardrail existed before this plan.
  - Resolution: dedicated reopen smoke test + regression budget gate (`1.8s`) added.
  - Latest signal (2026-02-17): `reopen_to_tabbar=1.127s`.

- `APP-LAT-003` Tab switches are measured by selection state, not by content readiness.
  - Status: Resolved
  - Baseline signal: tab switch tests passed while still feeling slow.
  - Resolution: per-tab readiness markers (`dashboardRootReady`, `traiRootReady`, `workoutsRootReady`, `profileRootReady`) + content-ready smoke metrics + baseline budgets.

- `APP-LAT-004` Heavy tab activation work still competes with first-paint responsiveness.
  - Status: In Progress
  - Baseline signal: root tabs still run broad data/query hydration and activation tasks.
  - Latest signal (2026-02-17):
    - after fast-history rollout (today+yesterday eager, older lazy), real-data run measured:
      - `workouts=1.374s`, `trai=3.349s`, `profile=4.423s`, `dashboard=1.798s`.
    - launch/reopen in same run: `startup_to_tabbar_real_data=7.195s`, `reopen_to_tabbar_real_data=1.148s`.
  - New instrumentation finding (2026-02-16, real-user device):
    - `dashboard.refreshFoodDateCaches` is the largest measured app-side startup/switch hotspot:
      - measured at `~594ms` with `food=90` rows.
      - after query cap reduction (`food` fetch limit `90 -> 48`), measured between `~381ms` and `~407ms` in repeat runs.
  - Follow-up instrumentation finding (2026-02-17, real-user device):
    - `dashboard.refreshFoodDateCaches` dropped to `1.9ms` with `allFood=5` after eager window was capped to today+yesterday and older slices moved on-demand.
    - other measured tab activation functions were much smaller:
      - `workouts.refreshWorkoutHistoryCaches ~10-11ms`
      - `workouts.loadRecoveryAndScores ~36-45ms`
      - `chat.handleChatTabAppear/rebuildSessionMessages ~0.1ms`
      - profile heavy refresh often deferred (`Profile probe=pending` in several runs).
  - Additional mitigation (2026-02-17):
    - `ProfileView` heavy refresh scheduling is now gated by actual selected tab (`appTabSelection == .profile`), not only `onAppear`, to avoid off-screen prewarm-triggered work.
    - profile auto-stale windows were widened to `24h` for both metrics and reminders so launch/reopen does not repeatedly trigger profile-heavy fetches for mostly static data.
    - Validation so far: simulator UI latency smoke still passes (`testTabSwitchContentReadyLatencySmoke`, profile switch observed at `~1.484s` in UITEST_MODE).
    - Real-data device smoke (`testTabSwitchContentReadyLatencySmokeWithExistingUserData`, iPhone `00008150-000445911140401C`) measured `tab_switch_profile_ready_real_data=3.360s` with `Profile probe=pending`, indicating deferred profile-heavy refresh did not execute on that switch path.
  - Current direction: keep fast-history model, keep probe markers in real-data UI tests, and shift optimization focus to remaining high-latency tabs (`profile` first, then `trai` activation scheduling).

- `APP-LAT-007` Device real-data latency numbers are highly volatile across identical UI test runs.
  - Status: In Progress
  - Signal: same test paths vary materially run-to-run (for example startup `9.2s` to `10.7s`; tab profile/dash swings by multiple seconds).
  - Evidence: XCTest logs show `Setting up automation session` time itself fluctuates substantially before app idle (recent startup/tab runs ranged from ~`2.46s` to `5.58s`).
  - New evidence (2026-02-16): app-side latency probes show low internal tab work while XCTest tab-ready can still read high (for example Trai probe `~0.1ms` while UI metric remained `2.4s+`), confirming significant harness/idle-noise contribution.
  - Current direction: keep app-side probe output in the real-data tab test and make optimization decisions from probe timings + data cardinality, not raw XCTest duration alone.

- `APP-LAT-005` No automated budget gate for launch/reopen/tab metrics.
  - Status: Resolved
  - Baseline signal: latency values lived mostly in ad-hoc test logs.
  - Resolution: scripted `.xcresult` extraction + baseline compare + JSON/markdown report is live.
  - Latest run (2026-02-17): regression script overall `PASS`.

## Resolved Issues

- `APP-LAT-002` Foreground reopen latency guardrail shipped.
- `APP-LAT-003` Tab content-ready latency guardrail shipped.
- `APP-LAT-005` Automated regression gate + reports shipped.

## Risks / Gaps

- `APP-LAT-006` `MuscleRecoveryService` direct performance test currently skipped in XCTest host.
  - Status: Open
  - Signal: Instantiating service in host unit test currently crashes (`malloc: pointer being freed was not allocated`).
  - Current direction: keep latency smoke + profiler guardrails active; revisit isolated service test harness once host crash is resolved.

- `APP-LAT-008` UI latency suite can fail from unrelated live-workout stability test.
  - Status: Open
  - Signal: full `TraiUITests` run on 2026-02-17 failed in `testLiveWorkoutStabilityPresetHandlesRepeatedMutationsAndReopen` because `liveWorkoutEndButton` did not appear after launch route.
  - Impact: latency signal tests can be green while the suite still reports failure for a separate stability path.
  - Current direction: run latency-only selector in perf loops; keep stability test in dedicated reliability pass.

## Update Protocol

- Update issue status after each milestone.
- When changing budgets in `scripts/latency_baseline_simulator.json`, add a one-line rationale under the matching issue.
