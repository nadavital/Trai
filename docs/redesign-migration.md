# Trai redesign migration ledger

September 24 follow-up: [Profile removal and contextual dashboard visuals](/Users/nadav/Desktop/Trai/docs/dashboard-contextual-redesign.md) supersede the Profile-tab screenshots below.

Scope: reachable iPhone app screens, connected sheets, shared surfaces and nutrient-color consistency in widgets. Preserve data/service/Watch/Health behavior. Personal release publishing is not part of this pass.

## Acceptance

- Direct camera meal pills open review without an intermediate menu or auto-save.
- Primary actions/context are evident; secondary content expands or has a purposeful destination.
- No old whole-content glass surfaces in active app flows; stable opaque cards and native forms.
- Consistent nutrient identity; no legacy activity-style nutrition rings in active detail routes.
- Workouts exposes Train, Plan, Progress and History with all templates/actions preserved.
- Profile/settings/onboarding/chat/weight align with the same hierarchy, spacing and readable semantics.
- Independent source review corrected before native validation; screenshots accepted only when loaded.
- Build and relevant flows verified. Native screenshots are UI evidence, not physical camera, Watch sync, Health delivery or hosted AI proof.

## Coverage

| Area | Source audit / implementation | Native proof |
| --- | --- | --- |
| Today/Nutrition/Activity/Weight | Prior iteration; current detail/optional nutrient/palette pass | Light and dark/accessibility section tours inspected |
| Food capture/review/manual/edit | docs/migration-food-chat-weight.md + root edit-food review | Direct pill review + mocked portion refinement passed; camera light/dark inspected |
| Workouts/plan/PR/history/live/custom exercises | docs/migration-workouts.md | Light and dark/accessibility tours; reopen/unit checks passed; Add Exercise latency remains inconclusive after a snapshot timeout |
| Profile/settings/reminders/memories/plan history | docs/migration-profile-onboarding.md | Light and dark/accessibility Profile/Settings inspected |
| Onboarding/account/subscription | docs/migration-profile-onboarding.md | Critical onboarding flow passed; other account/purchase states source reviewed |
| Chat/proposals/weight history | docs/migration-food-chat-weight.md | Chat and weight history inspected in light/dark/accessibility |
| Shared controls/forms/widgets | Shared opaque card token; macro palette unified; native forms retained | App/widget compilation; widget delivery unchanged |

## Baseline evidence

Current-run baseline captures /private/tmp/trai-migration-baseline/profile.png and chat.png accepted: Profile overemphasized identity/stat cards; Chat left a large gap and duplicated logging actions. workouts.png recaptured after load and accepted: browsing shortcuts, start, alternatives, goals and history competed in one stack. The live screenshot stayed blank and was rejected; live assessment must use the UI-test flow.

## Independent review corrections

- Plan duplicate empty and populated content removed.
- Workout history dates and confirmed deletion restored; See All remains reachable.
- Large-text Plan/Progress rows made adaptive.
- Nutrient chips use primary text with semantic color accents.
- Missing optional nutrient data displayed as partial; detail routes do not invent missing targets.
- Sugar included when enabled, with missing-data coverage.

## Explicit boundaries

This is a design migration of existing capabilities. A backend-generated once-daily summary, new Foundation Models evaluation, physical Watch reconciliation and new Health export types are separate functional projects; do not label the existing local day heading an AI-generated summary. Developer-only labs and unreachable legacy food routes are not silently deleted.

## Native review corrections

- Replaced the invisible custom workout-header glass composition with native glass buttons. Safe-area placement and explicit height alone did not resolve it. Final composition uses an explicit heading and navigation row above page content; the native large-title bar is hidden. Final light screenshots visibly confirm the controls.
- Live workouts initially expand the first unfinished exercise; others remain summaries. Add Exercise opens the new editor. Large-text set inputs stack while keeping the same focus and debounced-save handlers.
- Direct meal pills retain accessible full names and open review without saving. Review nutrient text has primary contrast with colored identity dots.
- Weight now exposes its recent trend directly in the section, rather than offering only another history button. History has an explicit Done action and labels the latest entries separately from chart range.
- Profile plan actions stack at accessibility sizes; macro targets become one column. Large-text headers align with the card content. History reserves intrinsic width at ordinary text sizes, avoiding mid-word wrapping.
- Workout recommendation badges, floating actions and historical statistics adapt to large text without splitting words into narrow columns.
- Removed the nested delete-inside-edit button in calorie detail by reusing the accessible meal row and confirmed delete menu.
- Fixed the Settings kg/pounds target display/edit binding and duplicate height unit placeholder discovered during visual review.
- Replaced unsupported SwiftData forced-unwrap predicates in Profile and day-target context with equivalent nil-coalescing predicates. Nutrition-target regression tests pass.
- Isolated onboarding tests from persisted screenshot-fixture setup-dismissal flags; onboarding now completes with its checklist available.

## Validation record

- `trai-migration-pass3.xcresult`: 9 nutrition-target tests and 2 UI tests (full section tour + onboarding), all passed.
- `trai-migration-pass2.xcresult`: direct meal suggestions, mocked food refinement, live layout and section tour passed; onboarding fixture contamination was subsequently fixed and rerun in pass3.
- `trai-migration-dark-ax.xcresult`: direct suggestions, live layout and full section tour passed with dark appearance and accessibility-medium text. Screenshots exposed the final wrapping/alignment corrections above.
- Final light build and UI checks (`trai-migration-final-polish-light.xcresult`): section tour and minimize/cancel passed. Screenshots confirm visible workout navigation and unbroken Profile History buttons.
- Final stability script: 10 focused unit tests, repeated minimize/reopen, and startup/tab latency passed. Add Exercise latency failed with a simulator accessibility snapshot timeout; a previous run passed at 2.438 seconds. The overall script is not a clean pass. Its runner subsequently stalled during finalization and was terminated after results were recorded.
- Debug-only synthetic UI sessions are now excluded from account refresh and billing synchronization. A test fixture token had reached the real backend and caused a sign-out. Real sessions and explicit live-backend test sessions keep normal behavior; the previously failing cancellation test passes after correction.
- Final dark/accessibility checks (`trai-migration-final-polish-dark.xcresult`): direct meal-pill review, live workout layout and full section tour all passed. Native captures confirm visible workout navigation, two-line meal pills, readable set inputs and full Add Exercise label at accessibility-medium text.

The source inventory covers reachable feature families; the native tour covers representative screens and interactions, not every possible data state or maximum accessibility setting. Camera photo input/AI use deterministic UI-test fixtures here. This is not a fresh production backend, physical camera, Apple Watch, or TestFlight validation.
