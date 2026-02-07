# ExecPlan: Consolidate Gemini Plan Pipelines (`NutritionPlan` + `WorkoutPlan`)

## Problem Statement
`GeminiService` maintains two near-parallel plan pipelines with duplicated request orchestration, JSON cleaning, refinement parsing, and decode-fallback behavior:
- Nutrition: `/Users/nadav/Desktop/Trai/Trai/Core/Services/GeminiService+Plan.swift`
- Workout: `/Users/nadav/Desktop/Trai/Trai/Core/Services/GeminiService+WorkoutPlan.swift`

This creates duplicate abstractions for one concept ("generate/refine a plan with Gemini"), increasing bug surface and making future Gemini contract changes (schema/response cleaning/error handling) a two-file edit every time.

Acceptance criteria:
1. Shared pipeline code owns JSON cleaning + parse/decode fallback flow for both plan domains.
2. Public API behavior remains unchanged for callers in onboarding and workout flows.
3. Existing call sites compile unchanged:
   - `generateNutritionPlan`, `refinePlan`
   - `generateWorkoutPlan`, `refineWorkoutPlan`
4. Project builds successfully for `Trai` target after refactor.

## Why This Refactor (Evidence)
- Duplicate abstraction: both files implement the same lifecycle with domain-specific types swapped.
  - `/Users/nadav/Desktop/Trai/Trai/Core/Services/GeminiService+Plan.swift:31`
  - `/Users/nadav/Desktop/Trai/Trai/Core/Services/GeminiService+WorkoutPlan.swift:31`
- Duplicate refinement parsing flow (`responseType/message/proposed/updated` envelope):
  - `/Users/nadav/Desktop/Trai/Trai/Core/Services/GeminiService+Plan.swift:106`
  - `/Users/nadav/Desktop/Trai/Trai/Core/Services/GeminiService+WorkoutPlan.swift:106`
- Duplicate JSON cleanup and decode-error handling strategy:
  - `/Users/nadav/Desktop/Trai/Trai/Core/Services/GeminiService+Plan.swift:128`
  - `/Users/nadav/Desktop/Trai/Trai/Core/Services/GeminiService+WorkoutPlan.swift:163`

Call-path coupling (same duplicated service logic hit by two core user flows):
- Nutrition generation/refinement callers:
  - `/Users/nadav/Desktop/Trai/Trai/Features/Onboarding/OnboardingView+PlanGeneration.swift:41`
  - `/Users/nadav/Desktop/Trai/Trai/Features/Onboarding/PlanChatView.swift:119`
- Workout generation/refinement callers:
  - `/Users/nadav/Desktop/Trai/Trai/Features/Workouts/WorkoutPlanChatFlow.swift:480`
  - `/Users/nadav/Desktop/Trai/Trai/Features/Workouts/WorkoutPlanChatFlow.swift:575`

## Assumptions
- `GeminiPromptBuilder` schemas/prompts remain domain-specific and should not be unified in this refactor.
- Domain model types (`NutritionPlan`, `WorkoutPlan`) and fallback constructors remain unchanged.
- No API contract changes are required for current chat/onboarding UX.

## Scope
In scope:
- Introduce one shared internal pipeline helper for plan generation/refinement.
- Keep existing public entrypoints as thin adapters.
- Remove duplicated cleanup/decode/error utilities from plan-specific extensions.

Out of scope:
- Rewriting chat UI flows.
- Reworking Gemini function-calling stack.
- Changing prompt text, schema definitions, or model selection.

## Impacted Paths
- `/Users/nadav/Desktop/Trai/Trai/Core/Services/GeminiService+Plan.swift`
- `/Users/nadav/Desktop/Trai/Trai/Core/Services/GeminiService+WorkoutPlan.swift`
- `/Users/nadav/Desktop/Trai/Trai/Core/Services/GeminiService.swift` (if shared helpers live here)
- `/Users/nadav/Desktop/Trai/Trai/Core/Services/` (new shared internal file, e.g. `GeminiService+PlanPipeline.swift`)
- `/Users/nadav/Desktop/Trai/Trai.xcodeproj/project.pbxproj` (only if file registration is needed)

## Execution Plan

### Phase 1: Introduce shared internal pipeline primitives
- [x] Add internal helper(s) for:
  - JSON fence stripping/cleanup
  - common generation request execution (prompt -> schema -> decode/fallback)
  - common refinement envelope decode (`responseType`, `message`, optional proposed/updated payloads)
- [x] Keep helper API generic over model type with domain-provided decode/fallback closures.

### Phase 2: Migrate nutrition plan extension to shared pipeline
- [x] Refactor `generateNutritionPlan` to call shared generation helper.
- [x] Refactor `refinePlan` to call shared refinement helper.
- [x] Remove duplicated cleanup/decoding code from nutrition extension.

### Phase 3: Migrate workout plan extension to shared pipeline
- [x] Refactor `generateWorkoutPlan` to call shared generation helper.
- [x] Refactor `refineWorkoutPlan` to call shared refinement helper.
- [x] Remove duplicated cleanup/decoding code from workout extension.

### Phase 4: Validate parity and simplify
- [x] Verify the four public APIs preserve signatures and return semantics.
- [x] Ensure fallback behavior still returns `createDefault(...)` on decode failures.
- [x] Remove any dead private helpers left behind in both extensions.

### Phase 5: Compile validation
- [x] Run focused build:
  - `xcodebuild -project /Users/nadav/Desktop/Trai/Trai.xcodeproj -scheme Trai -destination 'platform=iOS Simulator,name=iPhone 16' build`
  - If destination unavailable, use any installed simulator.
  - Result: build could not complete in this environment because CoreSimulator runtime/service is unavailable; failure occurs in `TraiWidgets` asset catalog step before Swift compile completion.

## Validation Checklist
- [x] `generateNutritionPlan` still returns a valid plan for onboarding flow. (API parity + fallback behavior preserved in service code)
- [x] `refinePlan` still supports `message`, `proposePlan`, `planUpdate`. (response envelope mapping unchanged)
- [x] `generateWorkoutPlan` still returns a valid plan proposal. (API parity + fallback behavior preserved in service code)
- [x] `refineWorkoutPlan` still supports `message`, `proposePlan`, `planUpdate`. (response envelope mapping unchanged)
- [ ] No behavior regression in caller flows:
  - `/Users/nadav/Desktop/Trai/Trai/Features/Onboarding/PlanChatView.swift`
  - `/Users/nadav/Desktop/Trai/Trai/Features/Workouts/WorkoutPlanChatFlow.swift`
  - Runtime verification blocked by missing simulator runtime/service in this environment.

## Risks and Mitigations
- Risk: Generic helper obscures domain-specific logging context.
  - Mitigation: keep domain log prefixes/messages passed as parameters.
- Risk: Type-erasure mistakes in generic decode path.
  - Mitigation: keep strongly-typed generic constraints and dedicated unit-like parse tests where possible.
- Risk: Subtle change in fallback behavior.
  - Mitigation: preserve fallback constructors at adapter layer and add targeted assertions in debug builds.

## Rollback
- Revert shared helper file + adapter changes in both extensions.
- Restore prior private parsing/cleanup methods in each extension.
- No data migration rollback required.

## Candidate Ranking (Scored)
| Candidate | Payoff (30%) | Blast Radius (25%) | Cognitive Load (20%) | Velocity Unlock (15%) | Validation/Rollback (10%) | Weighted |
|---|---:|---:|---:|---:|---:|---:|
| Consolidate duplicated Gemini plan pipelines (chosen) | 4 | 4 | 4 | 4 | 5 | 4.10 |
| Unify `PlanChatView` + workout refine chat shell into shared chat container | 3 | 3 | 3 | 3 | 3 | 3.00 |
| Introduce `ChatCoordinator` to collapse `ChatView` + `ChatViewActions` fragmentation | 5 | 2 | 5 | 4 | 2 | 3.80 |
| Collapse `PlanService` into `UserProfile`/utility extensions | 2 | 4 | 2 | 2 | 4 | 2.70 |
