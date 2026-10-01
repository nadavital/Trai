# Routine dashboard prototype

Launch DEBUG with `--routine-study`. Separate from the live app and all persisted data. Fixed sample week September 21–27, with Thursday as today. No notifications, HealthKit writes, or saved preference changes.

## Structure

- Today retains a compact weight card: latest measurement, last check-in, direct logging, and history.
- Routine is a swipeable section in top dashboard navigation, not a new bottom tab.
- Weight check-ins lead Routine. The week shows logged days and the user's scheduled days; days without a schedule are neutral. The calendar opens schedule editing through its visible Edit cue.
- Checking in updates the latest value, calendar, history and Today card together. Rechecking today edits that sample entry instead of adding a second consistency mark.
- Reminders sit immediately below with complete/undo, snooze to tomorrow, edit, and add. Editing preserves the time.
- There are no streak resets, weight-direction rewards, or generic habit scores. Calendar cells have semantic accessibility labels; large text wraps the calendar and footer. Sheets scroll and expand.

## Validation and boundaries

Focused native UI coverage exercises check-in, weekly completion, reminder completion, snooze, edit preserving time, theme switching, and Today navigation. Visual captures are reviewed for density and hierarchy. Schedule/add/history entry points exist, but this is not a claim of exhaustive accessibility, notification, or production data validation.

Before production migration, reuse existing weight validation, preferred units, HealthKit ownership and reminder scheduling models. Offer user-chosen check-in frequency; do not infer or prescribe daily weighing. Keep the real Today nutrition/activity content when integrating the compact weight card—the prototype Today surface only demonstrates weight placement.

Final native result: /private/tmp/trai-routine-draft.xcresult passed. Reminder edits now present an atomic draft containing the reminder identity/title/time and dismiss from the editor. Test explicitly asserts populated fields, enabled save, sheet dismissal and actual Dark appearance before capture. Native light/dark and compact Today captures: /private/tmp/trai-routine-ready. Earlier incomplete checks that only found underlying page text did not prove editor dismissal; these have been replaced.
