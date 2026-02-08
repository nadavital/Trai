# ExecPlan: Consolidate Nutrition Plan State Handling and Remove `PlanService`

## Problem Statement
Nutrition plan state is currently spread across a thin service abstraction plus direct field mutations in multiple features. This creates duplicate ways to perform the same update and increases regression risk whenever plan semantics change.

Current state (evidence):
- Thin wrapper service with mostly forwarding logic:
  - `/Users/nadav/Desktop/Trai/Trai/Core/Services/PlanService.swift`
- `PlanService` usage is limited to three calls in one UI card:
  - `/Users/nadav/Desktop/Trai/Trai/Features/Profile/ProfileView+Cards.swift:45`
  - `/Users/nadav/Desktop/Trai/Trai/Features/Profile/ProfileView+Cards.swift:113`
  - `/Users/nadav/Desktop/Trai/Trai/Features/Profile/ProfileView+Cards.swift:114`
- Nutrition plan fields are also mutated directly in multiple other flows:
  - `/Users/nadav/Desktop/Trai/Trai/Features/Onboarding/OnboardingView+Completion.swift:43`
  - `/Users/nadav/Desktop/Trai/Trai/Features/Profile/PlanAdjustmentSheet.swift:299`
  - `/Users/nadav/Desktop/Trai/Trai/Features/Chat/ChatViewActions.swift:107`
- Some `PlanService` APIs are currently unused outside their own file (`getCurrentPlan`, `hasSavedPlan`, `getCalorieInfo`, `comparePlans`, training-day helpers), indicating dead abstraction surface.

Why this is a problem:
- Duplicate abstraction: nutrition-plan logic exists in both model helpers and `PlanService`.
- Shotgun surgery risk: plan schema/semantics changes require touching several feature files and a service wrapper.
- Cognitive overhead: engineers must decide whether to use direct profile writes, model helpers, or `PlanService`.

Acceptance criteria:
1. No app code references `PlanService`.
2. Nutrition plan writes have one canonical mutation API at model/domain level.
3. Onboarding, profile plan adjustment, and chat plan-apply flows all use the same API.
4. Project compiles for `Trai` target after the refactor.

## Repository Mental Model (Evidence-Based)
- App entry and tab routing:
  - `/Users/nadav/Desktop/Trai/Trai/TraiApp.swift`
  - `/Users/nadav/Desktop/Trai/Trai/ContentView.swift`
- Core AI and workout call paths:
  - Chat: `/Users/nadav/Desktop/Trai/Trai/Features/Chat/ChatViewMessaging.swift:201` -> `/Users/nadav/Desktop/Trai/Trai/Core/Services/GeminiService+FunctionCalling.swift:17` -> `/Users/nadav/Desktop/Trai/Trai/Core/Services/GeminiFunctionExecutor.swift:95`
  - Nutrition onboarding: `/Users/nadav/Desktop/Trai/Trai/Features/Onboarding/OnboardingView+PlanGeneration.swift:41` -> `/Users/nadav/Desktop/Trai/Trai/Core/Services/GeminiService+Plan.swift:31`
  - Workout planning: `/Users/nadav/Desktop/Trai/Trai/Features/Workouts/WorkoutPlanChatFlow.swift:480` -> `/Users/nadav/Desktop/Trai/Trai/Core/Services/GeminiService+WorkoutPlan.swift:31`
- Highest-reference entities from repo scan (file-count mentions):
  - `UserProfile` (51), `LiveWorkout` (32), `GeminiService` (26), `ExerciseHistory` (15), `HealthKitService` (14)

Dependency highlight:
- `UserProfile` already contains plan-related computed logic (`effectiveCalorieGoal`, recalculation threshold), while `PlanService` re-wraps overlapping concerns. Consolidation belongs at the model/domain boundary, not an extra service layer.

## Assumptions
- Production-level caution is required (default conservative risk tolerance).
- `UserProfile` remains the source of truth for persisted nutrition targets and metadata.
- No migration is needed if field names/types stay unchanged.
- Refactor should not change user-visible behavior in plan cards, plan adjustment, or chat plan-apply actions.

## Scope
In scope:
- Introduce/extend canonical nutrition-plan mutation helpers on `UserProfile` (or a tightly-coupled model extension).
- Rewire feature call sites to use canonical helpers.
- Remove `PlanService` and its remaining references.

Out of scope:
- Reworking Gemini prompting/pipelines.
- Redesigning plan assessment strategy.
- Broad architecture rewrite of profile or chat features.

## Impacted Paths
- `/Users/nadav/Desktop/Trai/Trai/Core/Models/UserProfile.swift`
- `/Users/nadav/Desktop/Trai/Trai/Core/Models/` (new extension file if introduced)
- `/Users/nadav/Desktop/Trai/Trai/Features/Profile/ProfileView.swift`
- `/Users/nadav/Desktop/Trai/Trai/Features/Profile/ProfileView+Cards.swift`
- `/Users/nadav/Desktop/Trai/Trai/Features/Profile/PlanAdjustmentSheet.swift`
- `/Users/nadav/Desktop/Trai/Trai/Features/Onboarding/OnboardingView+Completion.swift`
- `/Users/nadav/Desktop/Trai/Trai/Features/Chat/ChatViewActions.swift`
- `/Users/nadav/Desktop/Trai/Trai/Core/Services/PlanService.swift` (removal)
- `/Users/nadav/Desktop/Trai/Trai.xcodeproj/project.pbxproj` (only if file membership changes are required)

## Execution Plan

### Phase 1: Define one canonical nutrition-plan mutation API
- [ ] Add model-level helpers (in `UserProfile` extension) for:
  - applying a full `NutritionPlan` payload to profile fields/metadata
  - applying partial target updates (chat/profile edits) without duplicating assignment logic
  - computing weight-diff/recalculation checks where needed by UI
- [ ] Ensure helpers preserve existing semantics for training/rest day calories and plan metadata.

### Phase 2: Rewire call sites to canonical API
- [ ] Replace direct plan-target field writes in onboarding completion:
  - `/Users/nadav/Desktop/Trai/Trai/Features/Onboarding/OnboardingView+Completion.swift`
- [ ] Replace direct plan-target field writes in chat accept-plan flow:
  - `/Users/nadav/Desktop/Trai/Trai/Features/Chat/ChatViewActions.swift`
- [ ] Replace direct plan-target field writes in profile adjustment sheet:
  - `/Users/nadav/Desktop/Trai/Trai/Features/Profile/PlanAdjustmentSheet.swift`
- [ ] Replace `planService.*` usage in profile card UI with canonical model helpers:
  - `/Users/nadav/Desktop/Trai/Trai/Features/Profile/ProfileView+Cards.swift`

### Phase 3: Remove dead abstraction surface
- [ ] Remove `PlanService` state from `ProfileView`.
- [ ] Delete `/Users/nadav/Desktop/Trai/Trai/Core/Services/PlanService.swift`.
- [ ] Confirm no references remain:
  - `rg -n "\\bPlanService\\b|planService\\." /Users/nadav/Desktop/Trai/Trai -g"*.swift"`

### Phase 4: Validate compile safety
- [ ] Run focused project build for `Trai` scheme:
  - `xcodebuild -project /Users/nadav/Desktop/Trai/Trai.xcodeproj -scheme Trai -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/TraiDerived CODE_SIGN_IDENTITY='' CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO build`
- [ ] Confirm no errors for modified files.

## Validation Checklist
- [ ] Profile card still shows effective calories and recalculation prompt correctly.
- [ ] Accepting a chat plan suggestion still updates targets and marks suggestion as applied.
- [ ] Onboarding completion still persists targets and plan metadata.
- [ ] Manual plan adjustments still persist and reflect immediately in UI.
- [ ] `PlanService` is fully removed with no orphan references.

## Risks and Mitigations
- Risk: subtle behavior drift when replacing direct assignments.
  - Mitigation: keep helper behavior field-for-field equivalent; add targeted assertions in debug.
- Risk: partial updates (chat) accidentally overwrite unrelated targets.
  - Mitigation: explicit optional-parameter merge semantics and tests/spot checks.
- Risk: profile card computations change due to helper move.
  - Mitigation: preserve existing formulas from `UserProfile` (`effectiveCalorieGoal`, weight diff threshold).

## Rollback
- Revert helper introduction + call-site rewires.
- Restore `/Users/nadav/Desktop/Trai/Trai/Core/Services/PlanService.swift` and original `ProfileView` wiring.
- No data migration rollback required.

## Candidate Ranking (Scored)
| Candidate | Payoff (30%) | Blast Radius (25%) | Cognitive Load Reduction (20%) | Velocity Unlock (15%) | Validation/Rollback (10%) | Weighted |
|---|---:|---:|---:|---:|---:|---:|
| Consolidate nutrition plan mutations + remove `PlanService` (chosen) | 4 | 4 | 4 | 4 | 5 | 4.10 |
| Consolidate Siri-intent Gemini helpers into one intent-facing service file | 2 | 5 | 2 | 2 | 5 | 3.00 |
| Further unify nutrition/workout plan refinement response wrappers | 2 | 4 | 2 | 3 | 4 | 2.90 |
| Collapse `ChatViewMessaging` + `ChatViewActions` into a single coordinator type | 5 | 2 | 5 | 4 | 2 | 3.95 |

