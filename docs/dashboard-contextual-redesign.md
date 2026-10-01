# Contextual dashboard and account migration

This follow-up replaces the Profile-tab layout shown in the September 23 migration review.

## Navigation

| Previous destination | Current home |
| --- | --- |
| Profile tab | Removed; Dashboard, Workouts and Trai remain |
| Personal details, settings, reminders | Account button in dashboard header |
| Memories, saved conversations, sign-in and subscription | Account |
| Nutrition plan editing, Trai review, plan history | Dashboard → Nutrition → Nutrition plan |
| Workout plan editing, Trai review, plan history | Workouts → Plan → Manage plan |
| Custom exercises and workout templates | Workouts → Plan, retained |

Old stored Profile-tab selections resolve to Dashboard. Explicit legacy Profile requests open Account. Account no longer depends on a hidden tab being selected to load its data, and chat actions dismiss the destination before switching tabs.

## Visual changes

- Activity has a seven-day calendar of recorded training. Raised red/cyan day tiles carry session identity and counts; selecting a day reveals its records. No target, readiness score or unlogged activity is invented. Today uses a static miniature; the full section provides selection. The next named workout and Start/Resume action sit alongside this context.
- Weight has a teal/cyan filled trend, timestamped samples, a latest-point marker, a numeric scale and an optional goal reference. Today shows the compact version. The detailed section is unframed, with logging adjacent to the latest measurement. Weight changes remain neutral.
- The old four-column Activity card and its unused helpers are removed. Health movement is subordinate to the training visual, with a loading/unavailable state instead of initial fake zeroes.
- Profile's large identity/plan-card dashboard is removed. Account uses a native grouped list; relevant plan controls retain their existing review/save flows in contextual destinations.
- No Health export, deduplication or Watch ownership behavior is changed. The training view preserves merged HealthKit ID filtering and flags partial history if dashboard fetch caps limit coverage.

## Native review corrections

- Actions and legend names use primary text contrast; teal/cyan remains an identifying accent.
- The compact weight trend includes the plotted date span and signed measurement change.
- The generic Chat with Trai card is removed; Trai remains directly available in the tab bar.
- Activity initially selects the latest logged day, with explicit date labeling; selecting an empty day intentionally shows no logged workouts.
- The workout invitation respects the preferred action: custom workout vs the cached recommendation. It does not promise a named template while a recommendation is still loading.

## Screenshots

Seeded native iPhone captures. The Activity screenshot deliberately selects an empty day to verify that state; normal entry selects the latest logged day.

| Today: compact visuals and actions | Activity: selectable training days |
| --- | --- |
| ![Today cards](/Users/nadav/.codex/visualizations/2026/09/19/01a0b6f9-bf5f-7100-8d57-794c1fdf0060/trai-contextual-dashboard/light-today-context.png) | ![Activity section](/Users/nadav/.codex/visualizations/2026/09/19/01a0b6f9-bf5f-7100-8d57-794c1fdf0060/trai-contextual-dashboard/light-dashboard-activity.png) |

| Weight: measurement trend | Account: migrated settings |
| --- | --- |
| ![Weight section](/Users/nadav/.codex/visualizations/2026/09/19/01a0b6f9-bf5f-7100-8d57-794c1fdf0060/trai-contextual-dashboard/light-dashboard-weight.png) | ![Account](/Users/nadav/.codex/visualizations/2026/09/19/01a0b6f9-bf5f-7100-8d57-794c1fdf0060/trai-contextual-dashboard/light-account.png) |

[Dark mode with larger text](/Users/nadav/.codex/visualizations/2026/09/19/01a0b6f9-bf5f-7100-8d57-794c1fdf0060/trai-contextual-dashboard/dark-dashboard-activity.png) · [Weight at larger text](/Users/nadav/.codex/visualizations/2026/09/19/01a0b6f9-bf5f-7100-8d57-794c1fdf0060/trai-contextual-dashboard/dark-dashboard-weight.png)

## Verification

First native build: three prewarm-policy tests and three UI flows passed (Account/settings, full section tour, both plan destinations). Visual review covered Account, Activity and Weight in light mode. Independent review corrected disabled miniature controls, day hit targets, large-text header layout and legacy selection storage.

Final light and dark/accessibility-medium builds: the section tour, Activity day selection and both contextual plan destinations passed. Subsequent native critique corrected cyan text contrast, added date span/change to the compact weight chart, removed the duplicated chat shortcut and aligned the Activity header preview. Reviewed light and dark tours passed. The final light build/tour also passed (`trai-contextual-dashboard-contrast.xcresult`); its screenshot confirms primary-color Log weight text. Dark/accessibility captures precede that final foreground-only correction.

Screenshots are seeded native simulator states, not live Health or physical Watch proof. This work is a visual/navigation iteration; backend-generated daily summaries and deeper exercise analytics remain separate work.

## Personal weekly rhythm and neutral weight check-in — September 24 follow-up

Activity now measures distinct training days in the current calendar week against `workoutPlan.daysPerWeek`. The primary visual has only that many slots (one through seven), preserves movement/strength colors, and reports extra days without increasing the goal. No saved plan means no invented target. The full section retains the selectable calendar as supporting history; future days say Upcoming. Header previews use the same target and colors.

Weight now uses a teal scale-inspired check-in visual with the latest recorded measurement and date. It removes the primary slope, change amount and target line; weight history remains one action away. The compact dashboard version keeps logging local. The illustration carries no health score, implied healthy range, streak, or pressure to weigh daily.

Validation for this follow-up: native iPhone simulator screen tour passed; the focused Activity selection / Weight history navigation check passed on the reviewed build in light mode and dark mode with Accessibility Medium text. Screenshots were visually inspected and use seeded data, not a live Health account. The first accessibility run attempted an offscreen header pill; the test was corrected to navigate adjacent visible sections and passed. This does not establish live Health or physical-device behavior.

Native captures: `/Users/nadav/.codex/visualizations/2026/09/19/01a0b6f9-bf5f-7100-8d57-794c1fdf0060/trai-personal-rhythm/` (light/dark Today, Activity, Weight). Results: `/private/tmp/trai-personal-rhythm-final.xcresult` and `/private/tmp/trai-personal-rhythm-dark-reviewed.xcresult`.
