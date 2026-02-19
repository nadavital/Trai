# App Latency Regression Report

- Timestamp (UTC): 20260217T070204Z
- Destination: `platform=iOS Simulator,id=343702CB-BE8E-4A8C-BA86-67898FFCDD7C`
- Result bundle: `/tmp/trai-app-latency-20260217T070204Z.xcresult`
- Baseline file: `/Users/nadav/Desktop/Trai/scripts/latency_baseline_simulator.json`
- Metrics file: `/tmp/trai-app-latency-metrics-20260217T070204Z.json`
- xcodebuild status: `65`
- Overall status: **FAIL**

## Metrics

| Metric | Value (s) | Budget (s) | Status |
| --- | ---: | ---: | --- |
| `live_workout_add_exercise_sheet` | 1.947 | 3.000 | PASS |
| `reopen_to_tabbar` | 1.204 | 1.800 | PASS |
| `startup_to_tabbar` | 6.027 | 5.800 | FAIL |
| `tab_switch_dashboard_ready` | 1.905 | 2.000 | PASS |
| `tab_switch_profile_ready` | 1.539 | 1.900 | PASS |
| `tab_switch_trai_ready` | 1.579 | 1.900 | PASS |
| `tab_switch_workouts_ready` | 1.693 | 2.500 | PASS |
