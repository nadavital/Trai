# Native visual cleanup — September 27, 2026

Scope: regular iPhone simulator, seeded app data. This is a targeted visual cleanup, not a new visual direction. Screenshots were captured before editing, then inspected again after the fixes. A separate read-only agent reviewed normal and accessibility captures.

[Before/after comparison](/Users/nadav/.codex/visualizations/2026/09/19/01a0b6f9-bf5f-7100-8d57-794c1fdf0060/visual-cleanup/before-after.png)

1. **Dashboard — Healthy in reviewed states.** Today: Account icon no longer clips at accessibility sizes; oversized section chips become a section menu. [Screenshot](/Users/nadav/.codex/visualizations/2026/09/19/01a0b6f9-bf5f-7100-8d57-794c1fdf0060/visual-cleanup/after-migration-today.png)

2. **Nutrition — Improved.** Nutrition section and detail sheet: Macro names identify the spheres; Fat and Fiber match chip order. Filled spheres use darker label ink in dark mode. Details and Log food stack at accessibility sizes. [Screenshot](/Users/nadav/.codex/visualizations/2026/09/19/01a0b6f9-bf5f-7100-8d57-794c1fdf0060/visual-cleanup/after-migration-nutrition.png)

3. **Activity — Improved.** Activity section: The dial caption uses two short centered lines, raised into the dial; empty track contrast increased. [Screenshot](/Users/nadav/.codex/visualizations/2026/09/19/01a0b6f9-bf5f-7100-8d57-794c1fdf0060/visual-cleanup/after-migration-dashboard-activity.png)

4. **Weight — Improved.** Weight section and history: History leads with the current measurement rather than pounds remaining. Standardized lb units in Weight surfaces; target remains available in the chart. [Screenshot](/Users/nadav/.codex/visualizations/2026/09/19/01a0b6f9-bf5f-7100-8d57-794c1fdf0060/visual-cleanup/after-migration-weight-history.png)

5. **Workouts — Improved.** Train and Plan: Secondary plan actions have consistent hierarchy. Train icon is contained and muscle descriptions wrap at accessibility sizes. [Screenshot](/Users/nadav/.codex/visualizations/2026/09/19/01a0b6f9-bf5f-7100-8d57-794c1fdf0060/visual-cleanup/after-migration-workout-plan.png)

6. **Progress and History — Healthy in reviewed states.** Workout Progress and History: No new visual defect identified in the sampled screens. [Screenshot](/Users/nadav/.codex/visualizations/2026/09/19/01a0b6f9-bf5f-7100-8d57-794c1fdf0060/visual-cleanup/after-migration-workout-progress.png)

7. **Live workout — Improved.** Initial workout and scrolled suggestions: Bottom actions reserve layout space with opaque backing. Set headings and muscle labels have stronger contrast. [Screenshot](/Users/nadav/.codex/visualizations/2026/09/19/01a0b6f9-bf5f-7100-8d57-794c1fdf0060/visual-cleanup/after-migration-live-workout.png)

8. **Food capture — Healthy in reviewed states.** Half-sheet and suggested-meal review: Camera fills the sheet; direct meal pills and review remain accessible. Opening a suggestion does not save it. [Screenshot](/Users/nadav/.codex/visualizations/2026/09/19/01a0b6f9-bf5f-7100-8d57-794c1fdf0060/visual-cleanup/after-camera-suggestion-review.png)

9. **Chat — Improved.** Empty chat: Accessibility layout gives text full width, keeps decorative symbols contained, and backs the composer to prevent text bleeding through it. [Screenshot](/Users/nadav/.codex/visualizations/2026/09/19/01a0b6f9-bf5f-7100-8d57-794c1fdf0060/visual-cleanup/after-migration-chat.png)

10. **Account and settings — Improved.** Account and Settings: Account settings row now signals navigation with a disclosure chevron. No new issue in the sampled settings screen. [Screenshot](/Users/nadav/.codex/visualizations/2026/09/19/01a0b6f9-bf5f-7100-8d57-794c1fdf0060/visual-cleanup/after-migration-account.png)

## Verification

- Light-mode screen tour, live-workout layout, suggested-meal review safety, and largest-text screen tour passed after the initial cleanup.
- Final dark-mode screen tour and largest-text screen tour passed, including Chat composer backing.
- All 10 focused live-workout unit tests passed. The stress UI launch stalled before reaching the workout; it was stopped. The script therefore did not reach its latency smoke checks. Live-workout layout screenshots passed separately in light mode.
- The first dark live-workout attempt also stalled at launch. The ordinary dark screen tour passed after restarting the dedicated simulator. This audit does not establish that cold workout launch is reliable.
- Final dark nutrition contrast follow-up screen tour passed.

[Final largest-text Chat screenshot](/Users/nadav/.codex/visualizations/2026/09/19/01a0b6f9-bf5f-7100-8d57-794c1fdf0060/visual-cleanup/dark-large-text-chat.png)

[Final largest-text Train screenshot](/Users/nadav/.codex/visualizations/2026/09/19/01a0b6f9-bf5f-7100-8d57-794c1fdf0060/visual-cleanup/dark-large-text-train.png)

## Boundaries

These captures cover the named screens and fixture states, not every sheet, error case, keyboard state, or localization. Accessibility review used the largest Dynamic Type size; this is not a VoiceOver or comprehensive accessibility certification. Simulator camera/AI used fixtures. No physical-device, Apple Watch, live HealthKit, or backend validation is claimed.

## Follow-up

The cold-launch stall was traced to tab selection persistence feedback and fixed in the next pass; see [Core journey validation](core-journey-validation.md) for the new evidence.
