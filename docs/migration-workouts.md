# Workout design migration — 23 September 2026

## Intent

The workout space should answer “what can I do now?” before asking the user to browse. Keep real logging controls, Watch provenance and custom tracking capabilities. Opaque rounded cards hold content; glass marks section navigation and a small number of floating actions. Bright semantic color identifies real state, not decorative imagery.

## Source audit and changes

| Surface / source | Finding and disposition |
| --- | --- |
| `WorkoutsView` | A single stack put glass shortcut chips, next workout, alternative workouts, goals and history on one surface. Split into swipeable Train, Plan, Progress and History pages. Train opens with next workout or active Resume. Plan owns alternatives/custom exercises; Progress owns records, recovery and goals. Existing sheet routes, queries, recovery scheduling and start/resume logic retained. |
| `WorkoutsViewComponents` | Keep the native next-workout card and actual plan/recovery information. Hide alternatives on Train; show every template on Plan instead of silently limiting to six. Shorten plan empty-state copy. Progress shortcut controls use soft semantic color rather than glass. |
| `LiveWorkoutView`, `LiveWorkoutComponents` | The large timer and target controls dominated before any logging. Compact adaptive elapsed-time/control row leaves more space for exercise entries. Workout focus is expandable; general session notes are expandable. Keep Apple Watch sync action and connection explanation. Keep stable exercise/set identities, focus scrolling, runtime and save callbacks. |
| `ExerciseCard`, `CardioExerciseCard` | Already opaque with expandable exercise content and contextual options. Preserve strength set entry and cardio intervals/custom fields rather than hiding essential input. No replacement of logging semantics. |
| `GeneralWorkoutComponents`, `MuscleGroupSelector`, `ExerciseSuggestions` | Existing semantic controls support broad activity types and arbitrary focus; retain within progressive disclosure. Suggestions still add directly. |
| `WorkoutHistorySection`, `WorkoutHistoryRows`, `AllWorkoutsSheet` | Tiny horizontal history tiles were poor on a dedicated History page. Use readable vertical rows with real duration/focus/provenance and existing contextual deletion confirmation. All-history native grouped list retained. |
| `PersonalRecordsView`, `ExerciseTrendsChart`, `PRPresentation` | Keep native searchable/sortable records, history drilldown, metric-specific charts and edit/delete controls. Change standalone translucent statistics tiles to opaque semantic cards. |
| `WatchHeartRateCard` | Full content material changed to opaque semantic surface. No acquisition, synchronization, or HealthKit changes. |
| `WorkoutPlanEditSheet`, `WorkoutTemplateCard`, `WorkoutPlanTemplateDisplay`, `WorkoutPlanOverviewCard` | Preserve native grouped plan editor and customizable day/target/exercise sheets. Change editor summary material to opaque. Existing shared opaque overview/template cards retained. |
| `WorkoutGoalComponents`, `WorkoutGeneratedGoalComponents`, `WorkoutGoalCheckInView`, `WorkoutGoalAISheet` | Goal detail, generated proposals and check-in already separate primary conversation from deeper controls. Change whole-card glass “Review with Trai” to opaque rounded surface; retain small floating composer surfaces and brand accent. |
| `WorkoutPlanChatFlow`, `WorkoutPlanChatMessage`, `WorkoutPlanProposalCard` | Keep editable AI proposal and native conversation flow; content already uses shared card tokens. Do not alter generation or acceptance logic. |
| `ExerciseListView`, `AddCustomExerciseSheet`, `EquipmentPhotoComponents` | Search/filter, custom tracking disclosures and user-supplied equipment images are functional, not decorative. Retain native forms and opaque cards. The transient photo-analysis overlay keeps material for modal separation. |
| `WorkoutDetailSheet`, `LiveWorkoutDetailSheet`, `WorkoutSummarySheet` | Retain opaque data cards, real achievement celebration, goal contribution, user notes and source information. No artificial workout photography. These use the updated shared review component. |
| `WorkoutBanner`, `LiveWorkoutPresentation` | Persistent ongoing-workout affordance and full-screen presentation remain. Do not disturb resume/end routing or Watch runtime ownership. |
| `LiveWorkoutViewModel`, `LiveWorkoutViewModel+HealthKit` | Deliberately unchanged: model mutation, timed state, pause accounting, Watch synchronization, saving and workout deduplication are not visual migration work. |

## Validation boundary

Swift frontend parse passed for edited workout files; scoped whitespace check passed. Root owns native build, simulator screenshots, accessibility and exercise-interaction checks. Source audit is not proof that every state was exercised on device. Required visual review: Train with/without plan, active Resume, all four section pages, live strength and cardio, dark mode, accessibility text. Required interaction review: Start/Resume, Add Exercise, Add Set and focus scrolling, plan edit, history/records drilldown, Watch sync action still present.

## Remaining evaluation

Do not label physical Apple Watch sync, HealthKit export/deduplication, or live backend coaching as revalidated by this visual pass. The design intentionally keeps the existing set grid; if native QA reveals crowding at accessibility sizes, address that concrete state separately rather than changing logging semantics in this pass.

## Independent review corrections

A second source review identified repetition on Plan and two history regressions. Plan now renders one heading/Edit action, all actionable template rows, and custom start; it no longer combines an overview with another copy of the template/empty state. Fixed-size alternative session components were removed. Progress links use semantic typography and stack vertically at accessibility text sizes. History rows explicitly show their date/time, expose a 44-point options menu with confirmation before deletion, and keep See All available even with fewer than six workouts. These corrections passed the same whole-workout syntax and scoped whitespace checks; native proof remains owned by the root task.

## Native screenshot follow-up

Integrated screenshots revealed the horizontal section scroll lacked a constrained height and did not visibly render its controls. Added a Dynamic Type-scaled navigation height and intrinsic single-line pill labels. The live strength screenshot also showed every exercise expanded. Live entry editors now receive an optional expansion binding: initially the first unfinished entry is open, remaining entries are summaries, and adding an entry focuses its editor. Users can expand or collapse any entry independently; standalone editor usages retain their former expansion default. No set logging or completion behavior changed. Root will rerun native rendering and interactions after these fixes.

## Accessible set editing

The native review prompted an accessibility-size alternative for the fixed set table. `SetRow` now uses `AnyLayout` to keep the same weight/repetition input identities and focus/debounce handlers while arranging them vertically at accessibility sizes. Inputs no longer have fixed column widths in that mode, fields have explicit VoiceOver labels, set/warmup status is written out, and notes/delete targets expand to 44 points. Repeated table headers are hidden in this layout. This passed syntax and whitespace checks; native largest-text editing remains part of root verification.

## Coordinated validation

See `redesign-migration.md` for the root agent's integrated native screenshot review, subsequent corrections, test results and remaining proof boundaries. Earlier pending notes above describe this subtask's handoff, not the final integrated status.
