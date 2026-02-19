# App Latency Real-User Device Baseline

- Timestamp (local): 2026-02-16 22:47:11 -0800
- Timestamp (UTC): 2026-02-17 06:47:11Z
- Device: `Nadav's iPhone` (`00008150-000445911140401C`)
- Data profile: existing app user data (`includeUITestMode: false`)
- Test log: `/tmp/trai-device-latency-real-user-full.log`
- Result bundle: `/Users/nadav/Library/Developer/Xcode/DerivedData/Trai-goarqoujnnzjtudeqgkojuncfjbl/Logs/Test/Test-TraiTests-2026.02.16_22-47-11--0800.xcresult`
- xcodebuild status: `0`
- Overall status: **PASS** (telemetry-only real-data assertions)

## Metrics

| Metric | Value (s) | Existing smoke budget (s) | Delta vs budget (s) |
| --- | ---: | ---: | ---: |
| `startup_to_tabbar_real_data` | 8.105 | 5.800 | +2.305 |
| `reopen_to_tabbar_real_data` | 6.567 | 1.800 | +4.767 |
| `tab_switch_workouts_ready_real_data` | 4.165 | 3.500 | +0.665 |
| `tab_switch_trai_ready_real_data` | 3.159 | 3.500 | -0.341 |
| `tab_switch_profile_ready_real_data` | 5.110 | 3.500 | +1.610 |
| `tab_switch_dashboard_ready_real_data` | 3.714 | 3.500 | +0.214 |

## Notes

- These metrics intentionally skip strict budget assertions to avoid failing CI when real user data size changes.
- Budget-enforced smoke tests remain in `UITEST_MODE` for stable regression detection.

## 2026-02-16 Probe Update (Real-User Device)

- Device run log: `/tmp/trai-device-tab-latency-probe.log`
- Follow-up logs:
  - `/tmp/trai-device-tab-latency-probe-after-query-caps.log`
  - `/tmp/trai-device-tab-latency-probe-after-external-storage.log`
  - `/tmp/trai-device-tab-latency-probe-after-external-storage-rerun.log`

### Key findings

- App-side hotspot attribution:
  - `Dashboard.refreshFoodDateCaches` dominated measured startup/tab work.
    - Before query cap adjustment: `~593.8ms` with `allFood=90`.
    - After reducing dashboard food/workout query caps: commonly `~381-407ms` with `allFood=48`.
- Other measured activation calls were comparatively small:
  - `Workouts.refreshWorkoutHistoryCaches ~10-11ms`.
  - `Workouts.loadRecoveryAndScores ~36-45ms`.
  - `Trai.handleChatTabAppear` and `rebuildSessionMessages` around `~0.1ms`.
- Real-data tab latency metrics remained volatile across runs despite similar app-side probe values, confirming XCTest/session-idle overhead noise.

## 2026-02-17 Fast-History Validation (Real Device)

- Device: `Nadav's iPhone` (`00008150-000445911140401C`)
- Command: `xcodebuild -project Trai.xcodeproj -scheme TraiTests -destination 'id=00008150-000445911140401C' -only-testing:TraiUITests test`
- Result bundle: `/Users/nadav/Library/Developer/Xcode/DerivedData/Trai-goarqoujnnzjtudeqgkojuncfjbl/Logs/Test/Test-TraiTests-2026.02.17_00-01-01--0800.xcresult`
- Suite status: `13` UI tests executed, `1` failure.
  - Failing test: `testLiveWorkoutStabilityPresetHandlesRepeatedMutationsAndReopen` (`liveWorkoutEndButton` not found after launch path).
  - Target latency test passed: `testTabSwitchContentReadyLatencySmokeWithExistingUserData`.

### Key latency metrics (real data)

| Metric | Value (s) |
| --- | ---: |
| `startup_to_tabbar_real_data` | 7.195 |
| `reopen_to_tabbar_real_data` | 1.148 |
| `tab_switch_workouts_ready_real_data` | 1.374 |
| `tab_switch_trai_ready_real_data` | 3.349 |
| `tab_switch_profile_ready_real_data` | 4.423 |
| `tab_switch_dashboard_ready_real_data` | 1.798 |

### Probe highlights

- Dashboard probe now reports:
  - `refreshFoodDateCaches=1.9ms {allFood=5, fastWindow=1, last7Food=5, selectedFood=0}`
  - `refreshDateScopedCaches=3.1ms`
- Prior dashboard food-cache probe values were `~381-594ms` before fast-window lazy history.
- Interpretation: limiting eager food history to today+yesterday and lazy-loading older slices removed the dominant measured app-side hotspot from tab activation.
