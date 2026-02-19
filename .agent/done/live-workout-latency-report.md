# Live Workout Latency Report (Device)

Date: 2026-02-16

## Environment
- Device: Nadav's iPhone (iPhone 17 Pro Max, iOS 26.3 / 23D127)
- App: `Nadav.Trai`
- Tooling: `xctrace` (Xcode 17C519)

## Capture Artifacts
- Fresh:
  - `/tmp/Trai-liveworkout-fresh-20260215-215840.trace`
  - `/tmp/Trai-liveworkout-fresh-time-sample.xml`
  - `/tmp/Trai-liveworkout-fresh-hotspots.csv`
- Heavy:
  - `/tmp/Trai-liveworkout-heavy-20260215-220223.trace`
  - `/tmp/Trai-liveworkout-heavy-time-sample.xml`
  - `/tmp/Trai-liveworkout-heavy-hotspots.csv`
- Long session:
  - `/tmp/Trai-liveworkout-long-session-20260215-220422.trace`
  - `/tmp/Trai-liveworkout-long-session-time-sample.xml`
  - `/tmp/Trai-liveworkout-long-session-hotspots.csv`

## Summary Metrics
(derived from exported `time-profile` rows)

| Run | Exported Samples | Main Thread Share | App-Owned Stack Share | Background-Tab Indicators in App Frames |
|---|---:|---:|---:|---:|
| fresh | 10,998 | 91.7% | 6.2% | present (low) |
| heavy | 1,317 | 83.9% | 8.4% | present (low-moderate) |
| long-session | 1,446 | 83.1% | 11.1% | present (low-moderate) |

## Top App-Owned Frames (First App Frame in Stack)

### Fresh
- `closure #1 in ExerciseListView.mostRecentUsageByExerciseName.getter` (21)
- `closure #1 in closure #1 in SetRow.body.getter` (18)
- `closure #4 in ExerciseListView.filteredExercises.getter` (13)
- `Collection.map<A, B>(_)` (11)
- `ExerciseHistory.performedAt.getter` (11)

Background indicator frames observed:
- `closure #1 in WorkoutsView.body.getter` (6)
- `DashboardView.init(showRemindersBinding:)` (3)

### Heavy
- `WorkoutPlan.ExerciseTemplate.init(from:)` (6)
- `closure #1 in WorkoutsView.body.getter` (5)
- `LiveWorkout.mergedHealthKitWorkoutID.getter` (4)
- `WorkoutPlan.WorkoutTemplate.init(from:)` (4)
- `MuscleRecoveryService.getLastTrainedDates(modelContext:)` (3)

Background indicator frames observed:
- `closure #1 in WorkoutsView.body.getter` (5)
- `MuscleRecoveryService.getLastTrainedDates(modelContext:)` (3)
- `WorkoutsView.loadRecoveryAndScores()` (2)

### Long Session
- `closure #1 in CompactLiveWorkoutRow.body.getter` (4)
- `WorkoutPlan.ExerciseTemplate.init(from:)` (4)
- `MuscleRecoveryService.getLastTrainedDates(modelContext:)` (3)
- `LiveWorkout.mergedHealthKitWorkoutID.getter` (3)
- `LiveWorkoutEntry.init(backingData:)` (3)

Background indicator frames observed:
- `MuscleRecoveryService.getLastTrainedDates(modelContext:)` (3)
- `WorkoutsView.loadRecoveryAndScores()` (2)
- `closure #1 in WorkoutsView.filteredWorkouts.getter` (2)

## Baseline Notes
Prior baseline artifacts existed:
- `/tmp/Trai-liveworkout-time-sample.xml`
- `/tmp/Trai-liveworkout-hotspots.csv`
- `/tmp/Trai-liveworkout-postopt-time-sample.xml`
- `/tmp/Trai-liveworkout-postopt-hotspots.csv`

Those baseline exports were unsymbolicated (`PC:0x...`), so they are retained as historical references but not directly comparable frame-by-frame to the current symbolized table exports.

## Acceptance Targets Status
1. 90s continuous edit responsiveness with no multi-second stalls: **Partial**.
   - Device traces were collected, but this run did not include a tightly scripted human input workload while capture was active.
2. Hotspots dominated by live-workout code instead of dashboard/recovery during active sheet: **Partial**.
   - Background-tab indicators are reduced but still present in heavy and long-session captures.
3. Heavy-data responsiveness comparable to fresh-data behavior: **Partial**.
   - Main-thread share does not regress under heavy data, but background-tab indicators remain.
4. Data integrity after long session + abrupt lifecycle transitions: **Not fully verified in this pass**.
   - Persistence coordinator tests pass; manual force-close integrity scenario still needs explicit run-through.

## Recommended Follow-up
- Add a scripted/manual interaction protocol during capture (continuous set edits for full 90s).
- Further suppress `WorkoutsView`/`MuscleRecoveryService` work while live workout is active.
- Re-run this exact report after those changes and compare background-indicator frame counts.
