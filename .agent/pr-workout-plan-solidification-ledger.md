# Workout Plan PR Solidification Ledger

## Goal
- Repeat fresh-agent review, verify reported issues locally, fix actual serious issues, and stop only once the PR has no known serious issues.

## Current PR Branch
- `codex-workout-plan-pro-generation-polish`
- Latest pushed fix at ledger creation: `98b4c7a Fix remaining workout review regressions`

## Fixes Already Landed In This Loop
- Blocked review-flow breakage when generated workout plan review switches into Trai chat.
- Blocked saving stale generated workout plans while an edit/refinement is in progress.
- Ensured generated workout plans saved from profile/settings/onboarding persist through the same save paths.
- Tightened AI workout tools so durable enum/category/activity fields are required instead of local keyword inference.
- Rejected empty `start_live_workout` suggestions so approving a card cannot create an empty live workout.
- Rejected non-strength activity logs that contain set/round-style metrics but omit durable `activity_name`.
- Blocked stale or malformed suggested workout cards from falling back to local category/activity inference.
- Added auth and pending-prompt guards for Review with Trai entry points from meal/workout/plan sheets.
- Preserved explicit `daysPerWeek` choices in plan edit save while still reducing impossible counts when workout days are deleted.
- Normalized generated plan-adherence goals consistently across Profile, Settings, chat save, and onboarding save paths.

## Fresh Review Rounds

### Round 2026-05-23 After `98b4c7a`
- AI function contracts: fixed verified issues.
- Plan persistence/edit/review flow: no serious verified bugs found.
- Chat/review pending state: fixed verified issue.
- Live workout planned/logged semantics: fixed verified issues.
- Regression-test coverage: fixed verified issue.

## Verified Issues
- Invalid non-empty `activity_kind` / `activity_role` in workout goal tool calls silently wrote or cleared durable scope data.
- Generated workout plan blocks decoded unknown free-text `kind` values as `.custom`, letting malformed AI payloads store generic behavior data.
- Skipped planned activity blocks could still count toward activity-scoped goal progress through workout-level focus fallback.
- AI-started non-strength workouts stored planned duration/target/segments, but active workout chat context omitted those planned details.
- Queued in-chat logged-meal review prompts dropped the focused food entry id while Trai was already generating.
- Manual plan edits that cleared blocks could leave only focus-area semantics, and later chat refinements were not required to preserve that activity identity.

## Rejected / Not Actual Issues
- Plan persistence/edit/review flow had no serious verified issue in the fresh pass after `98b4c7a`.

## Validation
- `xcodebuild test -project Trai.xcodeproj -scheme TraiTests -destination 'platform=iOS Simulator,id=A7C646DC-750A-4AB4-A28F-0B40813E3D0E' -derivedDataPath /tmp/TraiPRSolidDerived CODE_SIGN_IDENTITY='' CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO -only-testing:TraiTests/WorkoutSemanticParsingTests -only-testing:TraiTests/WorkoutPlanGenerationRequestTests -only-testing:TraiTests/LiveWorkoutViewModelInvalidationTests`
- Result: 164 selected tests, 0 failures.

## User Manual Test Checklist Once Agents Are Clean
- From Profile, generate a workout plan, review it with Trai, save it, quit/reopen, and confirm the plan persists.
- In plan edit, ask Trai to edit/refine the plan and confirm the old plan cannot still be saved during the edit flow.
- While chat is busy, tap Review with Trai from profile/plan/workout/meal surfaces and confirm the app does not allow an immediate manual send that interrupts the review flow.
- Try a generated non-strength plan day, start it as a live workout, and confirm activity rows have real activity names/tracking fields instead of generic inferred labels.
- Accept a generated workout log for a non-strength activity and confirm it saves with the AI-provided activity identity, not a name-derived guess.
- Edit a plan to have more training days per week than concrete templates, save, reopen, and confirm the chosen day count persists.
- Start a generated plan with a support activity, skip that support activity, finish the workout, and confirm activity-scoped goals do not count it as completed.
- Start an AI-suggested rowing/cycling workout, open Trai during the live workout, and confirm the planned duration/target is available in the conversation.
- In chat while Trai is generating, open an old logged meal and ask Trai about it; follow up with an edit request and confirm it still targets the exact meal.
