# Activity dial integration

The approved open dial is now shared between the exploration and production app via `WorkoutGauge.swift`. Dashboard Activity card, section header, and Activity detail all use the same lap colors and geometry. The header shows session count; the larger detail centers count/goal inside the dial. Weight and nutrition retain their own visual identities.

## Data and goals
- Counts completed LiveWorkout sessions and standalone WorkoutSession records in the selected calendar week, including multiple sessions on one day.
- Retains the dashboard's existing merged HealthKit UUID exclusion so merged Watch copies are not counted twice; unfinished LiveWorkout records are excluded.
- Adds optional `UserProfile.weeklyWorkoutSessionGoal`; this is separate from plan training days. Existing users have no inferred session goal. A native goal sheet sets, edits, or removes it using the profile's existing SwiftData persistence.
- No HealthKit writes or changes to workout export ownership.
- Existing fetch-limit partial state is shown as a lower bound.
- Counts are not capped. Material palette settles at the seventh color; over-goal shimmer respects Reduce Motion and inactive scenes. Small header marks use ordinary fills.

## Verification
`testIntegratedActivityDial` verifies an isolated fixture with two completed sessions on the same day, one unfinished session, and an imported Watch copy merged to the first. The result is 2. Setting the goal to 3 produces 2/3; changing to 1 produces 2/1. Captures include the full Today context alongside Weight.
`testActivityGaugeWorkoutCount` verifies 6/1 and 8/1 and the unbounded numerator.
Light results: `/private/tmp/trai-integrated-dial-final.xcresult`. Dark final-layout result: `/private/tmp/trai-integrated-dial-dark.xcresult`.
Physical-device Health sync and existing persistent-store migration are not covered by these simulator fixtures.
