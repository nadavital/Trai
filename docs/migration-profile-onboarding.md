# Profile, onboarding, account, and subscription migration

## Ethos applied

Trai is a tool for acting as well as understanding. Preserve fast access to editing plans and settings; remove decorative surfaces that postpone those actions. Opaque cards hold content. Small native controls can use glass. Color identifies nutrients and activities, rather than making every surface red. Secondary detail expands in place or opens the existing destination. Retain native forms and system account/Health permission flows.

## Evidence and changes

Reviewed native baseline `/private/tmp/trai-migration-baseline/profile.png`: the avatar/name card consumed roughly 250 points; the first screen barely reached Workout Plan. Large calorie typography and four macro tiles repeated dashboard information. The redesigned Profile uses a compact horizontal identity row, semantic-size calorie/training values, and disclosures for macro targets and individual workouts. Adjust, Review with Trai, History, account access, memories, exercise library, and reminders remain reachable. Old decorative profile badge helpers were removed. Editing Profile now begins with the name field rather than another large avatar.

Reminder management had a large Create Reminder card that restated the button label and introduction. It is now a compact native bordered action above the existing reminders, retaining permission handling, schedule editing, AI draft review, presets, and custom reminders. The composer introduction is shorter. Permission card duplicate padding removed.

Macro tracking and onboarding previews showed fictional partial activity rings and claimed to preview a dashboard that no longer uses that design. Replaced those with adaptive color-coded selected-nutrient chips and an honest “Your nutrients” heading. No invented intake/target amounts. Nutrient settings selection exposes On/Off to accessibility. Colors derive from MacroType, whose shared palette is migrated by the parent agent.

Onboarding choice cards, AI response cards, welcome chat demo, and the plan detail surface no longer use whole-card glass. Existing local modifier names are retained for API compatibility, but their backing is an opaque semantic surface; selected choices keep a tinted outline. Native glass chips and small controls are retained. Onboarding large heading and sign-in heading use semantic fonts.

Subscription module tiles changed from a large two-column glass grid to compact opaque feature rows, allowing the purchase controls to appear sooner. Product loading, entitlement gating, legal links, restore purchases, purchase actions, and the existing branded offer background remain unchanged. Account authentication remains the system Sign in with Apple control.

Exercise-library action menus have 44-point targets and explicit labels; their cards grow vertically with text instead of cropping at a fixed height.

## Inventory and disposition

| Surface / source group | Disposition |
| --- | --- |
| ProfileView and ProfileView+Cards | Compact identity and plan summaries; preserve all routes. |
| ProfileCards, ProfileEditComponents | Existing opaque secondary controls retained. |
| SettingsView, DeveloperSettingsView | Native lists appropriate for settings/debug controls; retained. |
| ProfileEditSheet | Remove ornamental hero; preserve fields and validation. |
| MacroTrackingSettingsSheet | Replace obsolete ring preview, adaptive chips and selection accessibility. |
| PlanAdjustmentSheet / Components | Existing goal selection and manual fields retained; primary adjustment actions stay explicit. |
| PlanHistoryView, WorkoutPlanHistoryView | Native historical lists and detail values retained. |
| WorkoutPlanDetailView | Opaque sections and contextual Edit action already suitable. |
| CustomExercisesView | Existing grouped library retained; fix target size and clipping risk. |
| MemoryViews, ProfileChatHistory | Native browsing/editing lists retained; data management remains explicit. |
| ReminderSettingsView | Remove create hero, keep compact action and existing schedule list. |
| ReminderQuickSetupSheet | Shorten introduction; preserve draft-before-save semantics. |
| CustomReminderSheet, ReminderHabitView, ReminderDraftCard | Native form/list and opaque review card retained. |
| OnboardingTheme / OnboardingStepViews | Opaque choice/response surfaces, keep selected outlines and brand lens. |
| MacroPreferencesStepView | Honest selected-nutrient preview and adaptive layout. |
| GoalsStepView, GoalCardComponents, ActivityLevelStepView, BiometricsStepView / Components | Existing sequential choices and validation retained; locally themed surfaces inherit migration. |
| OnboardingAccountAndHealthStepViews | System permission/account workflow retained, locally themed cards inherit migration. |
| SummaryStepView, PlanReviewStepView / Cards / Components | Existing plan review and confirmation remain; current target values are appropriate here. |
| PlanChatView / Components | Existing conversational adjustment retained; response surface inherits migration. |
| WorkoutPlanDecisionView, WorkoutPlanSetupChoiceFlow, PlanGenerationChoiceSheet | Preserve AI/manual choices and access gates; small glass controls remain intentional. |
| OnboardingWorkoutPlanSetupView | Opaque plan detail surface; preserve customization and manual/AI generation logic. |
| OnboardingView and persistence/generation/completion helpers, OnboardingProAccessState, PlanReviewAnimations | No data-flow changes. |
| AccountSetupView, BackendRequirementCard | Native account workflow retained; semantic heading improves scaling. |
| ProUpsellContent | Opaque compact feature rows. |
| ProUpsellView, ProUpsellComponents | Purchase/legal/access behavior retained; small glass controls appropriate. |

## Validation and remaining evidence

All 13 edited Swift files passed `swiftc -frontend -parse`; scoped `git diff --check` passed. This is syntax evidence, not type-check or runtime proof. Parent agent owns the integrated native build, interaction checks, and post-change screenshot review. Baseline Profile was visually inspected; post-change Profile, onboarding, subscription, largest Dynamic Type, and dark-mode screenshots were not captured by this agent. Settings/HealthKit/account/paywall behavior was preserved source-wise, not re-executed with live services. Do not represent this inventory as full device QA or a new release.

## Final consistency correction

The Plan Adjustment coaching action was the final whole-card material surface in this scope; replaced its ultra-thin material with opaque secondary grouped background. Remaining glass/material matches are small capsule/circle controls. Nutrient controls, legends, and summaries use `MacroType.color`; a source search found no adjacent protein/carbs/fat/fiber/sugar hardcoded palette mismatches. Selected-nutrient chip labels use primary text for contrast, with color reserved for their dots/background. Profile Settings has an explicit accessibility label and identifier.

## Native review follow-up

Parent-captured Profile and Settings screenshots were visually reviewed after migration. The Profile identity card is now substantially smaller and both plans are reachable in the initial viewport. Settings retains readable native grouped rows. Review caught the duplicate empty height unit placeholder and an actual target-weight conversion defect: a stored kilogram value was labeled pounds. Settings now displays/converts through an optional binding, stores kilograms for both unit preferences, and preserves nil on clearing. No standalone conversion helper existed; the binding was reviewed for both directions and nil rather than adding an implementation-mirroring test.

Profile's today-workout query and the equivalent WorkoutDayTargetContext fetch contained SwiftData-unsupported forced unwrap expressions. Replaced them with null coalescing to startedAt. This preserves the original started-today OR completed-today behavior, including active workouts, while removing ForcedUnwrap from the store predicate. Parent owns native build/recheck of that warning. All three edited files parse.

## Coordinated validation

See `redesign-migration.md` for the root agent's integrated native screenshot review, subsequent corrections, test results and remaining proof boundaries. Earlier pending notes above describe this subtask's handoff, not the final integrated status.

## Account relocation — 24 September

Profile is now a reusable destination, not a tab dashboard: `ProfileView(mode: .account/.nutritionPlan/.workoutPlan, onSelectTab: optionalCallback)`. Each owns navigation and Done dismissal. Account is a native grouped list for personal details/settings, reminders, memories, saved conversations, sign-in/status, and subscription access. Nutrition and workout modes expose their respective existing management/review/history surfaces for contextual entry points. Root owns Dashboard/Workouts/ContentView integration. Removed obsolete Profile header and old navigation-card helpers rather than keeping a hidden duplicate dashboard.

Lifecycle activation now follows destination visibility and does not require AppTab.profile. Saved conversations and plan-review actions dismiss the destination before selecting Trai, falling back to the environment tab binding when no callback is supplied. Existing persistence, account gates, plan generation/editing, and history logic are reused. Source parsing passed; root owns native route testing.
