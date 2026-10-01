# Workout experience overhaul

## Scope and rationale

The native baseline showed timer/Watch information, workout focus, every exercise, suggestions and the bottom utilities competing with the set-logging action. Add Set sat below the full table. The workout pages also repeated the old dashboard's preview-to-sheet pattern.

Implemented a focused live workspace: compact session context, an exercise selection strip, a single visible editor, a prominent Add Set before editable rows, optional history/PR details, and secondary set options. Visited editors remain mounted but hidden to preserve pending field validations and edits. Selection is shared with Live Activity actions, including when returning to an earlier or completed exercise. Cardio/flexible activity tracking callbacks and fields remain in their existing model path.

Train, Plan, Progress and History now use a compact section header. Plan separates inspection from Start. Progress shows meaningful record previews; History shows the available history window directly in grouped cards. Completion leads with session results and expands the detailed log. Both summary presentations respect Reduce Motion.

## Boundaries

No changes to HealthKit export ownership, merged Watch workout deduplication, authentication, backend, or release delivery. The existing bounded history queries remain bounded; the new previews do not establish all-time completeness. No claim of physical Watch/phone verification or measured battery improvement.

## Verification record

Baseline native capture: `/private/tmp/trai-workout-before.xcresult`.

Initial focused workspace compiled and rendered: `/private/tmp/trai-workout-focus.xcresult`. A first full logging/completion UI test passed in `/private/tmp/trai-workout-journey.xcresult`; that batch also contained a test launch assumption corrected to navigate through the real Workouts tab.

Repository stability script ran against only Trai Persona QA (`EB8CAC82-A215-4787-A283-C4998175DB04`). Persistence/runtime/update-policy/performance guardrails, repeated mutations with minimize/reopen, and startup/tab-switch checks passed. Its Add Exercise accessibility check initially failed after the bottom-control change; the label/containment correction passed the focused check in `/private/tmp/trai-workout-review2.xcresult`.

Three new view-model regressions passed in that same batch: selecting an earlier exercise routes Live Activity Add Set correctly, explicitly selecting a completed strength entry avoids cardio fallback, and invalid selection preserves focus. The retained editor required scoping UI test queries to the visible editor rather than globally matching duplicated field labels.

Final full `run_live_workout_stability.sh --mode sim` passed: 10 targeted unit tests, the mutation/minimize/reopen flow, and both latency smoke tests. Log: `/private/tmp/trai-workout-stability-verified.log`. The automated Add Exercise measurement was 2.580 seconds; these simulator smoke measurements are not physical-device performance claims.

The strengthened native navigation and logging batch passed in `/private/tmp/trai-workout-navigation.xcresult`. It checks actual page content after selecting each section, confirms a 200 kg input through the existing validation, switches between exercises, adds sets, and completes the workout. Visual review led to removing the conflicting animated section selection and fullscreen completion confetti. The QA persona now includes actual exercise histories for populated record previews.

Final dark-mode batch passed in `/private/tmp/trai-workout-final-dark.xcresult`: three focus regressions, full logging/completion, section navigation, and accessibility-size text logging. Inspected the native captures for live editing, vertical large-text fields, Train, Plan, populated Progress, History, and the unobstructed completion overview. Simulator appearance restored to light afterward.

Nine reviewed captures are saved under `/Users/nadav/.codex/visualizations/2026/09/19/01a0b6f9-bf5f-7100-8d57-794c1fdf0060/persona-validation/`, named `workout-*.png`. Cardio-specific end-to-end interaction and physical Apple Watch behavior were not verified in this pass. Changes remain local; no TestFlight upload.
