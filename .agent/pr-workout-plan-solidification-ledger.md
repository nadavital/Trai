# Workout Plan PR Solidification Ledger

## Goal
- Repeat fresh-agent review, verify reported issues locally, fix actual serious issues, and stop only once the PR has no known serious issues.

## Current PR Branch
- `codex-workout-plan-pro-generation-polish`
- Latest pushed fix before current round: `0ede45b Fix workout plan PR review issues`

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
- Preserved recursive AI function-chain workout start/log cards when the model performs multiple context lookups before producing the actionable workout result.
- Prevented stale workout-plan chat proposals from being reused as follow-up refinement context after the active plan changes elsewhere.
- Invalidated generated onboarding workout-plan review state when profile/nutrition inputs change after a generated workout plan/goals already exist.
- Stabilized current-period workout goal tests so they do not fail around a local week/day boundary.

## Fresh Review Rounds

### Round 2026-05-23 After `98b4c7a`
- AI function contracts: fixed verified issues.
- Plan persistence/edit/review flow: no serious verified bugs found.
- Chat/review pending state: fixed verified issue.
- Live workout planned/logged semantics: fixed verified issues.
- Regression-test coverage: fixed verified issue.

### Round 2026-05-23 After `62ce49e`
- AI function contracts: fixed verified dropped-item issue in accepted workout suggestions.
- Plan persistence/edit/review flow: no serious verified bugs found.
- Chat/review pending state: fixed verified focused-meal and refinement-composer issues.
- Live workout planned/logged semantics: fixed verified planned-strength-set and HealthKit merge issues.
- Regression-test coverage: fixed verified active workout chat context coverage gap.

### Round 2026-05-23 After `9e08620`
- AI function contracts: fixed verified generated plan-adherence overcount and saved-plan chat suggestion truncation.
- Live workout planned/logged semantics: fixed verified weight-goal progress from unlogged planned set weights and legacy ExerciseHistory duplicate risk.
- Chat/review pending state: fixed verified generated-plan refinement trap by adding cancellation/restore controls for toolbar and embedded surfaces.
- Plan persistence/edit/review flow: fixed verified draft-restore loss of generated workout goals and workout setup preferences.
- Regression-test coverage: added focused coverage for generated plan template identity, saved-plan suggestion structure, workout draft persistence, and unlogged weight sets.

### Round 2026-05-23 After `fcb8ee2`
- AI function contracts: fixed verified `log_workout` plan-adherence gap with durable `source_plan_template_id` support and exact template IDs in workout-plan context.
- Live workout planned/logged semantics: fixed verified generated plan-adherence relevance on unrelated workouts and chat-created plan-adherence goals with empty template IDs.
- Chat/review pending state: fixed verified retry cancellation handle, stale workout-plan proposal cards, and no-plan refinement response restoring the prior saveable review.
- Plan persistence/edit/review flow: fixed verified non-onboarding chat plan saves dropping generated goals and structured plan preferences; manual edit/chat plan saves now refresh day count and duration from structured plan data only.
- Regression-test coverage: added focused coverage for relevant-goal filtering, AI log template IDs, chat-created adherence goal normalization, template source IDs, structured profile preference updates, and legacy ExerciseHistory duplicate suppression.

### Round 2026-05-23 After `1c4afbc`
- AI function contracts: fixed verified direct `start_live_workout` plan-adherence gap by adding durable `source_plan_template_id` support and prompt guidance.
- Plan persistence/edit/review flow: fixed verified first-run onboarding workout setup reachability and pending proposal follow-up edit context preservation.
- Chat/review pending state: fixed verified cancelled-refinement race with per-request refinement identity.
- Live workout planned/logged semantics: fixed verified generated plan-adherence detachment after plan edits by reconciling active adherence goals to revised template IDs and day count.
- Regression-test coverage: added focused coverage for direct start source IDs, onboarding workout setup flow inclusion, and plan-adherence goal reconciliation.

### Round 2026-05-23 After `d4a8ece`
- AI function contracts: fixed verified dropped `activity_role` data by requiring and preserving role on AI-started and AI-logged workout items.
- Plan persistence/edit/review flow: fixed verified parent-state gap where unsaved generated workout-plan proposals/goals from onboarding/profile/workouts setup were local to the setup view instead of reopenable draft state.
- Chat/review pending state: fixed verified retry gaps where failed follow-up edits lost pending workout-plan proposal context and app-initiated Review with Trai retries had no user prompt to resend.
- Live workout planned/logged semantics: fixed verified generated plan-adherence progress overcount by counting distinct generated template IDs, and accepted AI `days` units for generated-plan adherence goals.
- Regression-test coverage: added focused coverage for activity role propagation, generated-plan adherence `days`, distinct-template counting, profile/workouts setup call sites, and the updated onboarding UI skip path.

### Round 2026-05-23 After `2384c04`
- AI function contracts: fixed verified single non-strength `log_workout` rejection when the AI supplied one top-level duration but no per-exercise duration.
- Plan persistence/edit/review flow: fixed verified generated setup dismiss/reopen stale-state risk and reconciled existing generated plan-adherence goals when setup saves replace the active plan.
- Chat/review pending state: fixed verified stale cancelled-task cleanup that could clear newer send/retry state, and preserved pending workout-plan proposal context for app-initiated prompts.
- Live workout planned/logged semantics: no new serious issue beyond the generated plan-adherence reconciliation already fixed in plan save paths.
- Regression-test coverage: added focused coverage for top-level single-activity duration inheritance and structured generated-goal deduplication/normalization.

### Round 2026-05-23 After `245dcfb`
- AI function contracts: fixed verified `start_live_workout` template-ID gap by resolving current-plan template IDs to the stored template instead of requiring or trusting AI-invented exercise payloads.
- Plan persistence/edit/review flow: no serious issues found in the fresh pass.
- Chat/review pending state: fixed verified stale request mutations before request-id cleanup, stopped-request pending review prompts, first empty-chat double-send window, stale workout-plan cards across chat history, and durable nutrition-card applied save.
- Live workout planned/logged semantics: fixed verified generated plan-adherence progress from empty finished planned guidance; generated adherence now requires logged entry data before counting a completed template.
- Regression-test coverage: added focused coverage for ID-only current-plan workout starts and empty generated-plan guidance not counting as adherence progress.

### Round 2026-05-23 After `ec94f0a`
- AI function contracts: fixed verified context-tool chaining gap by merging workout start/log suggestions from follow-up function results, and rejected stale/hallucinated `log_workout.source_plan_template_id` values that do not belong to the current plan.
- Plan persistence/edit/review flow: fixed verified stale workout-plan chat cards that were older than a newer plan saved through another surface.
- Chat/review pending state: fixed verified stale nutrition-plan chat cards by requiring the latest pending nutrition card and rejecting cards older than the current nutrition plan timestamp.
- Live workout planned/logged semantics: no new serious issue found in the fresh pass beyond the validated source-template guard.
- Regression-test coverage: added focused coverage for current-plan `log_workout` template IDs, invalid template ID rejection, and stale-card freshness decisions.

### Round 2026-05-24 After `406769a`
- AI function contracts: fixed verified recursive context-tool chaining gap where a second-level follow-up could still drop `suggestedWorkout` / `suggestedWorkoutLog` cards.
- Plan persistence/edit/review flow: fixed verified stale refinement-base gap where an old workout-plan proposal could still be passed to AI as context after an external plan save, while preserving fresh retired proposal context for retries.
- Chat/review pending state: no additional serious issue found beyond the stale refinement-base fix.
- Live workout planned/logged semantics: no serious issue found in the fresh pass.
- Regression-test coverage: added focused coverage for recursive function-result merge, stale workout-plan suggestion context, retrying fresh retired plan suggestions, onboarding workout-review invalidation, and date-stable current-period goal fixtures.

### Round 2026-05-24 After `cae67dd`
- Chat/review pending state: fixed verified nutrition-plan follow-up edit gap where typing a tweak to an unsaved nutrition proposal retired the card before AI context was built, causing the model to revise from saved targets instead of the pending structured draft.
- Retry/stop behavior: preserved fresh retired nutrition proposals only for retry context, while still rejecting applied or externally stale cards.
- AI function contracts: added durable pending nutrition-plan proposal data to chat function context and prompt guidance so the model revises from structured target fields rather than keyword-derived local inference.
- Plan persistence/edit/review flow and live workout planned/logged semantics: no additional serious issue was part of this verified fix.
- Regression-test coverage: added focused coverage for stale nutrition cards, retrying fresh retired nutrition proposals, and prompt inclusion of pending nutrition-plan targets.

### Round 2026-05-24 After Durable Route Review
- Live workout planned/logged semantics: fixed verified Start Workout routing gap where AppIntents/deep links carried only display names and `WorkoutTemplateService` matched saved templates by partial name, so overlapping generated-plan names could start the wrong stored template and attach the wrong `sourcePlanTemplateID`.
- Intent/deep-link contracts: added durable `template_id` route data, switched `StartWorkoutIntent` to use the existing `WorkoutNameEntity` ID, and resolved workouts by template ID first.
- Legacy compatibility: kept old name-only routes working through exact case-insensitive name matches only; ambiguous partial names now create a custom named workout instead of guessing a generated-plan template.
- Regression-test coverage: added focused route parsing coverage for `template_id` and service coverage proving durable IDs win over labels while partial names do not bind to saved templates.
- Fresh verification follow-up: fixed stale durable-ID fallback where a route with an obsolete `template_id` could still bind to a different current template with the same display name; name matching is now only used for ID-less legacy routes.

### Round 2026-05-24 After `0ede45b`
- Chat proposal lifecycle: no serious issue found in the requested read-only pass. Session-scoped retirement, stale nutrition/workout rendering, apply/save freshness checks, and app-initiated Review with Trai startup guards are present in current code.
- Prior serious findings: current code includes cancellation/request identity for setup generation, stale edit-base guards for workout-plan chat save, durable activity semantic preservation, strict `source_plan_template_id` validation, planned strength exercise prefill, and widget template IDs.
- Intent/deep-link contracts: fixed verified malformed durable route gap where a present but invalid `template_id` was treated as an ID-less legacy name route. Malformed durable workout routes no longer fall back to saved-template name matching.
- Setup generation lifecycle: fixed verified queued Pro generation race where the 180ms delayed task could still start after Back/dismiss before `isGenerating` became true.
- Durable workout semantics: fixed verified non-semantic refinement gaps by requiring existing template IDs to survive, preserving legacy exercise-only/display-block activity identities, and treating explicit strength-main activity names as durable even without tags.
- Intent/deep-link contracts: fixed verified stale durable-ID route gap where an obsolete `template_id` still started a custom workout named like the old plan. Stale durable IDs now resolve to no workout; legacy name-only routes still work.
- Planned workout starts: fixed verified chat/function-call path so strength entries carry `sourcePlanBlockID`, matching direct Workouts/Dashboard starts.
- Validation note: focused XCTest pass succeeded for route parsing, route resolution, planned-start provenance, malformed `source_plan_template_id`, and semantic refinement regressions; `git diff --check` is clean.

## Verified Issues
- Invalid non-empty `activity_kind` / `activity_role` in workout goal tool calls silently wrote or cleared durable scope data.
- Generated workout plan blocks decoded unknown free-text `kind` values as `.custom`, letting malformed AI payloads store generic behavior data.
- Skipped planned activity blocks could still count toward activity-scoped goal progress through workout-level focus fallback.
- AI-started non-strength workouts stored planned duration/target/segments, but active workout chat context omitted those planned details.
- Queued in-chat logged-meal review prompts dropped the focused food entry id while Trai was already generating.
- Manual plan edits that cleared blocks could leave only focus-area semantics, and later chat refinements were not required to preserve that activity identity.
- Accepting a mixed AI workout suggestion only materialized the first suggested item while preserving semantic focus from all items, so skipped durable activity work could later count through workout-level goal fallback.
- Suggested/default strength sets with reps were treated as logged work in active chat/progress and auto-completed on Finish.
- HealthKit workout merge selected the first/newest strength overlap instead of the best actual overlap, which could copy the wrong calories/heart-rate and hide the wrong imported workout row.
- Dashboard meal "Ask Trai" could lose focused meal context for older/crowded logs because pending chat resolution only searched the capped recent food query.
- Workout plan refinement hid the composer while Trai was updating a generated plan.
- Active workout chat context fallback for AI-started planned activities was not directly covered by tests.
- Generated plan-adherence goals counted unrelated completed workouts because plan-level goals had no durable template identity check.
- Chat `suggest_workout` recommendations from a saved plan only exposed the first strength exercise or first activity block, dropping the rest of the saved plan structure before acceptance.
- Weight-goal progress counted unlogged planned set weights and auto-baselines could read those planned weights too.
- Editing older completed workouts could duplicate `ExerciseHistory` rows because legacy rows without `sourceWorkoutEntryId` were not reused.
- Generated-plan refinement could leave the user trapped in an in-flight AI request with dismissal disabled and no stop/restore path.
- Onboarding draft restore persisted the generated workout plan but dropped generated workout goals and workout setup preferences needed at completion.
- Generated plan-adherence goals still appeared as relevant goals on unrelated workout surfaces even though progress no longer counted them.
- Chat retry requests were not assigned to `currentMessageTask`, so Stop cleared loading state without cancelling the retry.
- Older workout-plan proposal cards stayed saveable after a newer chat proposal.
- Generated-plan refinement responses with no valid updated plan removed the previous proposal/save action instead of restoring it.
- `log_workout` could not advance generated plan-adherence goals because completed chat logs had no durable source template id.
- Chat-created or chat-updated plan-adherence goals did not store generated template ids, so they could never accrue progress.
- Non-onboarding generated plan saves could show `+ Goals` but only save the plan, and chat/manual plan saves left structured day count/duration preferences stale.
- Direct chat `start_live_workout` could not carry `source_plan_template_id`, so starting a named generated-plan session from chat lost plan-adherence identity.
- First-run onboarding could persist generated workout plans, but the user-facing workout setup decision step was unreachable from the current onboarding flow.
- Follow-up edits to an unsaved workout-plan proposal in main chat retired the pending proposal before building AI context, causing revisions to fall back to the saved plan.
- Cancelled generated-plan refinement tasks could restore old review cards over a newer refinement request.
- Existing generated plan-adherence goals could detach from the current plan after manual/chat plan edits because their stored template IDs were not reconciled to the revised plan.
- Generated plan-adherence progress could be completed by repeating the same generated template instead of completing each distinct planned template.
- Generated plan-adherence goals using AI-produced `day` / `days` units were not recognized as plan-adherence targets.
- AI-started and AI-logged workout items dropped durable block role, so role-scoped goals could not progress from those accepted suggestions.
- Unsaved generated workout-plan proposals/goals in onboarding/profile/workouts setup were owned by the setup view, making them vulnerable to dismissal/reopen state loss before final save.
- Retrying a failed follow-up edit to an unsaved workout-plan proposal rebuilt context from the saved plan instead of the pending proposal.
- Retrying a failed app-initiated Review with Trai request was a no-op because the synthetic review prompt was never inserted as a user message.
- Onboarding UI tests used an exact label for a compound workout setup card, so they failed even when the real skip card was visible.
- Single non-strength workout logs with a top-level duration and no per-exercise duration were rejected even though the AI supplied durable activity data.
- Profile, Settings, and Workouts setup saves could leave existing generated plan-adherence goals attached to the replaced plan's old template IDs.
- Profile, Settings, and Workouts generated setup sheets could retain abandoned generated plan/goals/draft state after dismiss and later save stale review content.
- Generated workout goals from setup and the Workouts AI goal sheet were deduped by title instead of durable setup scope, so same-title goals with different structured scope could be dropped.
- Workouts AI goal sheet plan-adherence goals were not normalized against the current plan before insert.
- A cancelled chat request's cleanup could clear loading/task state for a newer send or retry.
- App-initiated chat prompts could retire a pending workout-plan proposal before snapshotting it as context.
- Stale AI request chunks/results could still mutate message content or apply suggestions before final request-id cleanup.
- Stopping a busy chat response could leave queued Review-with-Trai startup actions stranded and keep the composer disabled.
- First send in an empty chat had a transition window where a second send could start before loading/task state was installed.
- Stale pending workout-plan cards in older chat sessions could be reopened and accepted after a newer plan proposal existed.
- Accepted nutrition-plan cards were marked applied only after the explicit save, so the applied state could fail to persist.
- Generated plan-adherence goals counted completed workouts that only contained passive planned guidance and no logged entry data.
- AI-started strength workout suggestions preserved planned set counts in data but accepted live workouts materialized only one set.
- `start_live_workout` could receive a current-plan template ID but could not resolve it to the stored template, forcing the AI to invent duplicate workout items.
- Chained context-tool follow-ups could drop `suggestedWorkout` / `suggestedWorkoutLog` outputs, so a valid "what should I train today?" or workout-log answer after context lookup could return text without the actionable card.
- `log_workout` accepted arbitrary non-empty `source_plan_template_id` values, letting stale or hallucinated template IDs create saved logs that could never count toward the current generated plan.
- Older nutrition-plan chat cards stayed saveable after newer nutrition targets were saved elsewhere, so accepting the old card could overwrite current targets.
- Older workout-plan chat cards stayed saveable after a newer workout plan was saved from Profile, Workouts, Settings, or plan edit flows.
- Recursive chained context-tool follow-ups could still drop workout start/log cards if the actionable card appeared only after another follow-up depth.
- Older workout-plan chat proposals could still become the AI refinement base after the active workout plan had been replaced outside that chat.
- Onboarding generated workout-plan review state was not invalidated when profile/nutrition inputs changed after workout plan/goals generation.
- Current-period workout goal tests could fail around midnight or the locale week boundary because fixtures used `Date() - 1 hour`.
- Follow-up edits to an unsaved nutrition-plan proposal in chat retired the pending card before building AI context, so revisions could fall back to the saved nutrition targets.
- Start Workout intents/deep links used name-only, partial template matching, so generated plans with overlapping names could launch the wrong stored template and corrupt generated plan-adherence identity.
- Start Workout routes with a stale durable template ID could still fall back to an exact display-name match, binding to a different current template after plan replacement.
- Start Workout routes with a malformed non-empty durable template ID could still fall back to an exact display-name match, binding to a generated-plan template even though the durable ID was invalid.
- Queued Pro workout-plan generation could still run after Back/dismiss if the user left during the short pre-generation delay.
- Workout plan refinement could rotate template IDs during non-semantic edits, breaking durable plan routing/adherence contracts.
- Legacy exercise-only workout plans and explicit strength-main activity names without tags were not fully protected by durable semantic validation.
- Stale durable-ID workout routes could still start an unlinked custom workout named like the old planned session.
- Chat/function-call planned starts preserved `sourcePlanTemplateID` but dropped strength-entry `sourcePlanBlockID`.

## Rejected / Not Actual Issues
- Plan persistence/edit/review flow had no serious verified issue in the fresh pass after `98b4c7a`.
- Plan persistence/edit/review flow had no serious verified issue in the fresh pass after `62ce49e`.
- Fresh live workout/adherence review after `ec94f0a` found no additional serious issue beyond source-template validation covered in the current fix.
- A general chat lifecycle/stale-card coverage gap was real as test risk, but the source-level stale-card bugs were fixed directly and covered with focused freshness tests.

## Validation
- `xcodebuild test -project Trai.xcodeproj -scheme TraiTests -destination 'platform=iOS Simulator,id=A7C646DC-750A-4AB4-A28F-0B40813E3D0E' -derivedDataPath /tmp/TraiPRSolidDerived CODE_SIGN_IDENTITY='' CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO -only-testing:TraiTests/WorkoutSemanticParsingTests -only-testing:TraiTests/WorkoutPlanGenerationRequestTests -only-testing:TraiTests/LiveWorkoutViewModelInvalidationTests`
- Result after `62ce49e` fix round: 169 selected tests, 0 failures.
- `xcodebuild test -project Trai.xcodeproj -scheme TraiTests -destination 'platform=iOS Simulator,id=A7C646DC-750A-4AB4-A28F-0B40813E3D0E' -derivedDataPath /tmp/TraiPRSolidDerived CODE_SIGN_IDENTITY='' CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO -only-testing:TraiTests/WorkoutSemanticParsingTests -only-testing:TraiTests/WorkoutPlanGenerationRequestTests -only-testing:TraiTests/LiveWorkoutViewModelInvalidationTests -only-testing:TraiTests/UserProfileWorkoutPlanRequestTests`
- Result after current fix round: 181 selected tests, 0 failures.
- `xcodebuild test -project Trai.xcodeproj -scheme TraiTests -destination 'platform=iOS Simulator,id=A7C646DC-750A-4AB4-A28F-0B40813E3D0E' -derivedDataPath /tmp/TraiPRSolidDerived CODE_SIGN_IDENTITY='' CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO -only-testing:TraiTests/WorkoutSemanticParsingTests -only-testing:TraiTests/WorkoutPlanGenerationRequestTests -only-testing:TraiTests/LiveWorkoutViewModelInvalidationTests -only-testing:TraiTests/UserProfileWorkoutPlanRequestTests -only-testing:TraiTests/WorkoutTemplateServiceTests`
- Result after `fcb8ee2` review fix round: 204 selected tests, 0 failures.
- `xcodebuild test -project Trai.xcodeproj -scheme TraiTests -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/TraiPRSolidDerived CODE_SIGN_IDENTITY='' CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO -only-testing:TraiTests/WorkoutSemanticParsingTests -only-testing:TraiTests/WorkoutPlanGenerationRequestTests -only-testing:TraiTests/LiveWorkoutViewModelInvalidationTests -only-testing:TraiTests/UserProfileWorkoutPlanRequestTests -only-testing:TraiTests/WorkoutTemplateServiceTests -only-testing:TraiTests/OnboardingFlowPlannerTests`
- Result after `1c4afbc` review fix round: 207 selected tests, 0 failures.
- `xcodebuild test -project Trai.xcodeproj -scheme TraiTests -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/TraiPRSolidDerived CODE_SIGN_IDENTITY='' CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO -only-testing:TraiTests/WorkoutSemanticParsingTests -only-testing:TraiTests/WorkoutPlanGenerationRequestTests -only-testing:TraiTests/LiveWorkoutViewModelInvalidationTests -only-testing:TraiTests/UserProfileWorkoutPlanRequestTests -only-testing:TraiTests/WorkoutTemplateServiceTests -only-testing:TraiTests/OnboardingFlowPlannerTests`
- Result after `d4a8ece` review fix round: 209 selected tests, 0 failures.
- `xcodebuild test -project Trai.xcodeproj -scheme TraiTests -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/TraiPRSolidDerived CODE_SIGN_IDENTITY='' CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO -only-testing:TraiUITests/TraiUITests/testOnboardingCriticalFlowCompletesIntoDashboard -only-testing:TraiUITests/TraiUITests/testPostOnboardingChecklistOffersWorkoutAndHealthSetupForExistingPro`
- Result after `d4a8ece` review fix round: 2 selected UI tests, 0 failures.
- `xcodebuild test -project Trai.xcodeproj -scheme TraiTests -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/TraiPRSolidDerived CODE_SIGN_IDENTITY='' CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO -only-testing:TraiTests/WorkoutSemanticParsingTests -only-testing:TraiTests/WorkoutPlanGenerationRequestTests -only-testing:TraiTests/LiveWorkoutViewModelInvalidationTests -only-testing:TraiTests/UserProfileWorkoutPlanRequestTests -only-testing:TraiTests/WorkoutTemplateServiceTests -only-testing:TraiTests/OnboardingFlowPlannerTests`
- Result after `2384c04` review fix round: 211 selected tests, 0 failures.
- `xcodebuild test -project Trai.xcodeproj -scheme TraiTests -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/TraiPRSolidDerived CODE_SIGN_IDENTITY='' CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO -only-testing:TraiUITests/TraiUITests/testOnboardingCriticalFlowCompletesIntoDashboard -only-testing:TraiUITests/TraiUITests/testPostOnboardingChecklistOffersWorkoutAndHealthSetupForExistingPro`
- Result after `2384c04` review fix round: 2 selected UI tests, 0 failures.
- `xcodebuild test -project Trai.xcodeproj -scheme TraiTests -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/TraiPRSolidDerived CODE_SIGN_IDENTITY='' CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO -only-testing:TraiTests/WorkoutSemanticParsingTests -only-testing:TraiTests/LiveWorkoutViewModelInvalidationTests -only-testing:TraiTests/WorkoutPlanGenerationRequestTests -only-testing:TraiTests/WorkoutTemplateServiceTests`
- Result after `245dcfb` review fix round: 200 selected tests, 0 failures.
- `xcodebuild test -project Trai.xcodeproj -scheme TraiTests -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/TraiPRSolidDerived CODE_SIGN_IDENTITY='' CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO -only-testing:TraiTests/UserProfileWorkoutPlanRequestTests -only-testing:TraiTests/OnboardingFlowPlannerTests`
- Result after `245dcfb` review fix round: 12 selected tests, 0 failures.
- `git diff --check`
- Result after `ec94f0a` review fix round: no whitespace errors.
- `xcodebuild test -project Trai.xcodeproj -scheme TraiTests -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/TraiPRSolidDerived CODE_SIGN_IDENTITY='' CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO -only-testing:TraiTests/WorkoutSemanticParsingTests -only-testing:TraiTests/UserProfileWorkoutPlanRequestTests`
- Result after `ec94f0a` review fix round: 81 selected tests, 0 failures.
- `xcodebuild test -project Trai.xcodeproj -scheme TraiTests -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/TraiPRSolidDerived CODE_SIGN_IDENTITY='' CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO -only-testing:TraiTests/WorkoutSemanticParsingTests -only-testing:TraiTests/LiveWorkoutViewModelInvalidationTests -only-testing:TraiTests/WorkoutPlanGenerationRequestTests -only-testing:TraiTests/WorkoutTemplateServiceTests -only-testing:TraiTests/UserProfileWorkoutPlanRequestTests -only-testing:TraiTests/OnboardingFlowPlannerTests`
- Result after `ec94f0a` review fix round: 215 selected tests, 0 failures.
- `git diff --check`
- Result after `406769a` review fix round: no whitespace errors.
- `xcodebuild test -project Trai.xcodeproj -scheme TraiTests -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/TraiPRSolidDerived2 CODE_SIGN_IDENTITY='' CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO -only-testing:TraiTests/WorkoutSemanticParsingTests/testChatWorkoutPlanSuggestionContextCanUseFreshRetiredSuggestionForRetry -only-testing:TraiTests/WorkoutSemanticParsingTests/testFunctionFollowUpMergePreservesChainedWorkoutStartAndLogSuggestions -only-testing:TraiTests/LiveWorkoutViewModelInvalidationTests/testGeneratedPlanAdherenceCountsDistinctTemplatesOnly -only-testing:TraiTests/LiveWorkoutViewModelInvalidationTests/testPeriodCountGoalSumsActivityAttemptsInsideMixedWorkouts -only-testing:TraiTests/LiveWorkoutViewModelInvalidationTests/testPeriodDurationGoalSumsMatchingActivityWork`
- Result after `406769a` focused rerun: 5 selected tests, 0 failures.
- `xcodebuild test -project Trai.xcodeproj -scheme TraiTests -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/TraiPRSolidDerived3 CODE_SIGN_IDENTITY='' CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO -only-testing:TraiTests/WorkoutSemanticParsingTests -only-testing:TraiTests/LiveWorkoutViewModelInvalidationTests -only-testing:TraiTests/WorkoutPlanGenerationRequestTests -only-testing:TraiTests/WorkoutTemplateServiceTests -only-testing:TraiTests/UserProfileWorkoutPlanRequestTests -only-testing:TraiTests/OnboardingFlowPlannerTests`
- Result after `406769a` broad focused rerun: 219 selected tests, 0 failures.
- `git diff --check`
- Result after `cae67dd` nutrition-context fix round: no whitespace errors.
- `xcodebuild test -project Trai.xcodeproj -scheme TraiTests -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/TraiPRSolidDerived CODE_SIGN_IDENTITY='' CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO -only-testing:TraiTests/WorkoutSemanticParsingTests`
- Result after `cae67dd` nutrition-context fix round: app/tests compiled, but XCTest runner failed before bootstrapping in the simulator environment with early unexpected exit; no XCTest assertions ran or failed.
- `xcodebuild test -project Trai.xcodeproj -scheme TraiTests -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/TraiPRSolidDerivedNarrow CODE_SIGN_IDENTITY='' CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO -only-testing:TraiTests/WorkoutSemanticParsingTests/testChatNutritionPlanSuggestionContextRejectsExternallyStaleCards -only-testing:TraiTests/WorkoutSemanticParsingTests/testChatNutritionPlanSuggestionContextCanUseFreshRetiredSuggestionForRetry -only-testing:TraiTests/WorkoutSemanticParsingTests/testChatWorkoutPlanSuggestionContextCanUseFreshRetiredSuggestionForRetry`
- Result after `cae67dd` nutrition-context fix round: app/tests compiled, but XCTest runner exited before establishing its connection; no XCTest assertions ran or failed.
- `xcodebuild build -project Trai.xcodeproj -scheme Trai -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/TraiPRSolidBuild CODE_SIGN_IDENTITY='' CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO`
- Result after `cae67dd` nutrition-context fix round: build succeeded.
- `git diff --check`
- Result after durable workout-route fix round: no whitespace errors.
- `xcodebuild test -project Trai.xcodeproj -scheme TraiTests -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/TraiPRRouteFixDerived CODE_SIGN_IDENTITY='' CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO -only-testing:TraiTests/AppRouteTests -only-testing:TraiTests/WorkoutTemplateServiceTests -only-testing:TraiTests/WorkoutSemanticParsingTests/testChatNutritionPlanSuggestionContextRejectsExternallyStaleCards -only-testing:TraiTests/WorkoutSemanticParsingTests/testChatNutritionPlanSuggestionContextCanUseFreshRetiredSuggestionForRetry -only-testing:TraiTests/WorkoutSemanticParsingTests/testFunctionCallingPromptIncludesPendingNutritionPlanSuggestion -only-testing:TraiTests/WorkoutSemanticParsingTests/testChatWorkoutPlanSuggestionContextRejectsExternallyStaleCards -only-testing:TraiTests/WorkoutSemanticParsingTests/testChatWorkoutPlanSuggestionContextCanUseFreshRetiredSuggestionForRetry -only-testing:TraiTests/WorkoutSemanticParsingTests/testFunctionFollowUpMergePreservesChainedWorkoutStartAndLogSuggestions`
- Result after durable workout-route fix round: app/tests compiled, but XCTest runner exited before establishing its connection; no XCTest assertions ran or failed.
- `xcodebuild build -project Trai.xcodeproj -scheme Trai -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/TraiRouteFixBuild CODE_SIGN_IDENTITY='' CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO`
- Result after durable workout-route fix round: build succeeded.
- `xcodebuild test -project Trai.xcodeproj -scheme TraiTests -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/TraiRouteFixTests2 CODE_SIGN_IDENTITY='' CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO -only-testing:TraiTests/AppRouteTests -only-testing:TraiTests/WorkoutTemplateServiceTests`
- Result after stale durable-ID fallback fix: CoreSimulator stopped listing simulator devices; no app code assertions ran.
- `xcodebuild build -project Trai.xcodeproj -scheme Trai -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/TraiRouteFixBuild2 CODE_SIGN_IDENTITY='' CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO`
- Result after stale durable-ID fallback fix: blocked by CoreSimulator/actool runtime failure before useful Swift diagnostics; earlier route-fix app build had succeeded before CoreSimulator entered this bad state.
- `xcodebuild test -project Trai.xcodeproj -scheme TraiTests -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/TraiPRSolidCurrent CODE_SIGN_IDENTITY='' CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO -only-testing:TraiTests/AppRouteTests -only-testing:TraiTests/WorkoutTemplateServiceTests -only-testing:TraiTests/WorkoutSemanticParsingTests -only-testing:TraiTests/WorkoutPlanGenerationRequestTests -only-testing:TraiTests/UserProfileWorkoutPlanRequestTests -only-testing:TraiTests/OnboardingFlowPlannerTests`
- Result after `0ede45b` current pass: blocked before app code because CoreSimulator could not find/list simulator devices; no XCTest assertions ran.
- `xcodebuild build -project Trai.xcodeproj -scheme Trai -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/TraiPRSolidCurrentBuild CODE_SIGN_IDENTITY='' CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO`
- Result after `0ede45b` current pass: blocked before Swift diagnostics by CoreSimulator/actool runtime failure: no available simulator runtimes for `iphonesimulator`.
- `xcodebuild build -project Trai.xcodeproj -scheme Trai -destination 'id=00006030-0006096E3628001C' -derivedDataPath /tmp/TraiPRSolidDesignedBuild CODE_SIGN_IDENTITY='' CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO`
- Result after `0ede45b` current pass: blocked before Swift diagnostics by the same CoreSimulator/actool runtime failure.
- `git diff --check`
- Result after `0ede45b` current pass: no whitespace errors.
- `xcodebuild test -project Trai.xcodeproj -scheme TraiTests -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -derivedDataPath /tmp/TraiPRSolidDerivedTest8Esc CODE_SIGN_IDENTITY='' CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO -only-testing:TraiTests/AppRouteTests -only-testing:TraiTests/WorkoutTemplateServiceTests -only-testing:TraiTests/WorkoutSemanticParsingTests/testSuggestWorkoutPreservesAllSavedPlanBlocksWhenNoExplicitPreference -only-testing:TraiTests/WorkoutSemanticParsingTests/testStartLiveWorkoutRejectsMalformedSourcePlanTemplateID -only-testing:TraiTests/WorkoutSemanticParsingTests/testStartLiveWorkoutPreservesSourcePlanTemplateID -only-testing:TraiTests/WorkoutPlanGenerationRequestTests/testWorkoutPlanRefinementRejectsDroppedDurableBlockTagsWithoutSemanticChange -only-testing:TraiTests/WorkoutPlanGenerationRequestTests/testWorkoutPlanRefinementRejectsChangedDurableBlockIDWithoutSemanticChange -only-testing:TraiTests/WorkoutPlanGenerationRequestTests/testWorkoutPlanRefinementRejectsChangedTemplateIDWithoutSemanticChange -only-testing:TraiTests/WorkoutPlanGenerationRequestTests/testWorkoutPlanRefinementRejectsDroppedLegacyExerciseOnlyActivitySemantics -only-testing:TraiTests/WorkoutPlanGenerationRequestTests/testWorkoutPlanRefinementRejectsDroppedExplicitStrengthMainActivityNameWithoutTags`
- Result after current fixes: passed, 40 tests, 0 failures.

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
- Accept a mixed AI-suggested live workout with both a strength item and a non-strength activity item; confirm both rows appear and skipped activity rows do not count toward matching goals.
- Start a suggested strength workout, do not edit/check the prefilled first set, finish, and confirm it does not appear as completed history or goal progress.
- Finish a Trai workout near multiple Apple Watch workouts and confirm the merged calories/HR come from the actually overlapping Watch workout.
- While a workout-plan refinement response is generating, confirm the composer remains visible and typing is possible even though sending is disabled until the response finishes.
- Start/complete one generated plan template, then complete an unrelated custom workout, and confirm generated plan-adherence goals only count the generated template workout.
- Ask Trai to suggest a workout when a saved plan has multiple exercises plus a conditioning/cardio block; confirm the start card/live workout includes every planned item.
- Start a planned strength workout with prefilled/unlogged heavy sets, finish without checking them off, and confirm weight goals/history do not count those planned weights.
- Restore onboarding after generating a workout plan/goals but before completing onboarding, then finish onboarding and confirm both the workout plan preferences and goals persist.
- Trigger an onboarding/profile generated-plan refinement, tap Stop while Trai is generating, and confirm the previous plan review returns and the stale plan is not saved as an edited result.
- Ask chat to log a completed session from the current generated workout plan and confirm the resulting generated plan-adherence goal advances for that template.
- In chat, get a workout-plan proposal, ask for a newer tweak, then scroll back and confirm the older workout-plan proposal cannot be saved.
- After a chat retry starts, tap Stop and confirm no late AI response/card appears from the cancelled retry.
- Ask for a plan refinement that returns explanation only or fails validation and confirm the previous plan review/save card is restored.
- Save a generated plan with goals from the regular Workouts edit chat path and confirm the goals persist.
- Save a manual or chat plan edit that changes days/duration and confirm later plan requests use the updated structured day count/duration.
- From first-run onboarding, complete nutrition-plan review, continue to workout setup, create or skip a workout plan, and confirm completion behaves correctly.
- In main chat, get an unsaved workout-plan proposal, ask for a follow-up tweak before saving, and confirm the tweak applies to the pending proposal rather than the previously saved plan.
- Start a specific generated plan session directly from chat and confirm the accepted live workout advances the generated plan-adherence goal for that template.
- Start a generated-plan refinement, tap Stop, immediately submit a new refinement, and confirm the cancelled request does not restore old review cards over the new request.
- Save a generated plan with an adherence goal, edit the plan manually or through chat to change days/templates, then confirm the adherence goal tracks the revised template IDs and updated session count.
- Repeat the same generated template multiple times in a week and confirm generated-plan adherence only counts it once until distinct planned templates are completed.
- Ask AI to create a generated-plan adherence goal using a `days` unit and confirm the goal tracks the generated plan.
- Start/log an AI workout with warmup/accessory/finisher roles and confirm matching role-scoped goals progress.
- Generate a workout plan in onboarding/profile/workouts setup, dismiss/reopen before final save, and confirm the review proposal/goals are still available.
- Retry a failed Review with Trai request and a failed pending-plan follow-up edit; confirm both resend with the right plan context.
- Log a single running/cardio activity where AI supplies only top-level duration and confirm the accepted suggestion keeps the duration.
- Replace a generated plan through Profile, Settings, and Workouts and confirm existing plan-adherence goals track the new templates.
- Dismiss a generated setup review without saving, reopen setup, and confirm abandoned review content is not still saveable.
- Accept generated workout goals with the same title but different structured scope and confirm both persist.
- Create a plan-adherence goal through the Workouts AI goal sheet and confirm it is tied to the current plan templates.
- Tap Stop and immediately retry/send in chat, and confirm the cancelled request does not clear the newer loading state or response.
- Trigger an app-initiated prompt from a pending workout-plan proposal and confirm the proposal remains the context for the answer.
- Start a saved/generated plan session directly from chat by name and confirm the live workout uses the stored template items and set counts.
- Accept a chat-suggested strength workout from a plan template and confirm each exercise opens with the planned number of sets.
- Start a generated plan day, log nothing, finish it, and confirm generated plan-adherence goals do not progress.
- While a response is streaming, tap a Review with Trai entry point, then Stop; confirm the queued review starts and the composer is not stuck disabled.
- Generate a plan card in one chat, create a newer plan card in another chat, reopen the old session, and confirm the old card cannot replace the current plan.
- Accept a nutrition-plan update card, relaunch, and confirm the card remains applied rather than saveable.
- Save/edit nutrition targets after a nutrition-plan chat card exists, then accept the older card and confirm it is rejected as no longer current.
- Save/replace a workout plan from Profile, Workouts, Settings, or plan edit after a workout-plan chat card exists, then accept the older card and confirm it is rejected as no longer current.
- Ask "what should I train today?" in a situation where Trai first checks context/recovery, and confirm the final answer still includes the workout start card.
- Ask Trai to log a generated-plan workout and confirm a valid current template advances adherence, while an old/stale template cannot be logged against the current plan.
- Generate chat workout-plan proposal A, save or replace plan B from Profile/Workouts/Settings, return to the old chat and ask for a tweak; confirm Trai uses current plan B or asks for clarification instead of refining proposal A.
- Generate a workout-plan proposal, ask for a follow-up tweak that fails, then retry; confirm the retry still uses the fresh unsaved proposal as context.
- During onboarding, generate a workout plan/goals, go back and change profile/nutrition inputs, then continue; confirm the old workout plan/goals are cleared and must be regenerated/reconfirmed.
- In chat, get a nutrition-plan proposal, type a follow-up like "before applying, keep calories but raise carbs and reduce fat," and confirm the old card retires while the new AI proposal is based on the pending card's full structured targets, not the saved plan.
- Retry a failed nutrition-plan follow-up edit and confirm the retry still uses the fresh retired unsaved proposal when building the next AI response.
- Create or keep two generated plan templates with overlapping names, invoke Start Workout from Shortcuts/Siri/widget/deep link for one template, and confirm the live workout uses that exact template's items plus `sourcePlanTemplateID`; a legacy partial-name route like "upper body" should open a custom named workout rather than a generated-plan template.
- Open a workout deep link with a malformed `template_id` plus a valid-looking `template` name and confirm it does not attach to a saved generated-plan template.
- After replacing/editing a workout plan, tap an old large-widget/Shortcut planned workout route and confirm it does not start an empty custom workout named like the stale planned session.
- In Profile workout-plan setup Pro flow, answer the final personalization prompt and immediately tap Back/dismiss; confirm the old queued generation does not later show a stale review plan.
- Ask Trai in chat to start a planned strength or mixed session, accept the workout card, and confirm planned strength rows still count against the correct generated-plan block/template.
