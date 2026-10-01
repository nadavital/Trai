# Food, chat, and weight migration audit

Source review and native chat baseline inspection, 2026-09-23. This is a bounded feature audit, not a claim that every app screen has been rebuilt or visually verified. Dashboard, shared tokens, project configuration, services, and tests belong to the coordinating agent.

## Implemented

- **Compact food capture:** replaced the Recent & usual menu with a horizontal strip of directly tappable glass meal pills. Existing suggestion titles and emoji remain readable, with up to two lines; the full name, nutritional detail, and review-before-saving hint are exposed to accessibility. Hidden while typing, disabled during capture, and absent when no suggestions exist. Uses the existing selection callback, so selecting a pill opens review and retains existing memory/provenance behavior. No automatic saving, networking, or persistence change.
- **Manual food entry:** moved optional serving size alongside meal name, removed its separate card and the redundant Calories heading. All fields, validations, session/date handling, and save logic remain intact; macro inputs stay exposed because nutrition entry is the purpose of this screen.
- **Chat context attachment:** opaque semantic rounded surface replaces the large glass capsule. Two-line semantic title accommodates context names; remove control has a 44-point target. Prompt context and attachment serialization unchanged.
- **Chat empty state:** inspected native baseline `/private/tmp/trai-migration-baseline/chat.png`. The oversized separated greeting and two composer-pinned rows repeated dashboard logging actions. Replaced this with a compact lens and invitation followed immediately by three ranked question/advice prompts in the scrolling content. Start workout, Snap a meal, Log weight and meal-log starters are filtered from this surface; those capabilities remain available via chat and existing controls. Original prompt-send and usage-tracking callbacks remain unchanged. The composer now only contains its input controls. The legacy standalone SuggestionCard width also scales with Dynamic Type.
- **Plan and meal proposals:** comparison values stack with explicit before/after units at accessibility text sizes; apply/edit/cancel actions stack instead of squeezing into columns. Suggested meal nutrients wrap in an adaptive grid, with one column at accessibility sizes. Plan-review dismiss has a 44-point target and explicit accessibility label. Compact food review uses exact shared MacroType colors for every nutrient.
- **Chat history:** explicit accessibility label on history menu.
- **Weight history:** current, chart, and history surfaces share opaque Trai cards. Latest weight is left aligned, rounded and scaled, with a quiet timestamp. Goal distance is neutral instead of coloring above-target orange and below-target green. Date range uses a native menu, avoiding a cramped four-part segmented control at large text sizes. Toolbar explicitly says Log weight. Health import and data filtering remain unchanged.

## Feature inventory and disposition

| Feature / source | Current treatment and decision |
| --- | --- |
| FoodCaptureSheetView | Default camera/review; direct suggestions improved as above. Full camera half-sheet retained. Review already progressively discloses nutrients and correction; Save remains explicit. |
| FoodCameraView / FoodLogDraft / CameraService | Orchestration, automatic estimate/refinement, permissions, memory callback, saving and Health export; left untouched by this pass. |
| FoodCameraViewfinder / FoodCameraNoCameraFallbackView | Legacy explicit noncompact presentation; retained for compatibility. Default route already uses compact sheet. Existing glass input/camera controls are small interactive surfaces. |
| FoodCameraReview | Legacy review and nutrition source disclosure; content cards inherit opaque shared traiCard. Source and error detail remain available; bottom material action inset is a control surface. |
| ManualFoodEntrySheet | Reachable from capture overflow; simplified grouping, unchanged fields and saving. |
| FoodTrackingView / AddFoodView | Legacy Food screen and manual/AI add flow; source references only connect these to each other and previews, not main navigation. Existing opaque cards retained; no speculative removal or routing change. |
| ChatView / ChatContentList / ChatMessageViews | Streaming transcript, starters, temporary-chat disclosure and bubbles. Compact contextual question starters sit with the greeting rather than above the composer; existing opaque message surfaces retained. Privacy wording unchanged. |
| ChatInputBar / ChatDictationController | Glass confined to composer and send/voice controls; fits interactive-surface policy. Dictation and submission behavior unchanged. |
| TraiChatContextAttachment | Composer attachment surface simplified; data model untouched. |
| ChatMealComponents | Opaque meal suggestions, edit proposals, explicit log/apply actions and native edit Form. Preserve reviewable AI edits and nutrient disclosure. |
| ChatWorkoutCards | Suggested workout/start/log cards already opaque or shared traiCard; preserve exercise review and explicit start/save. |
| ChatPlanComponents / PlanReviewRecommendationCard | Opaque plan proposals and native edit Form, with detail sheet. Preserve visible before/after values and explicit Apply; dismiss target improved. |
| ChatMemoryComponents / ChatReminderComponents | Small status badges and detail sheets; preserve saved-memory disclosure, deletion error handling and explicit reminder actions. |
| ChatHistoryMenu | Native menu and destructive confirmation retained; history label improved. |
| ChatCameraComponents | Full capture for conversational image attachment, distinct from food logging; retained because replacing it would change another workflow. |
| ChatViewActions / ChatViewMessaging / ChatSheetModifiers | Routing, chat actions and presentation only; no visual redesign needed in these files. |
| WeightTrackingView | Reachable from Dashboard history; cards/type/range control refined, chart and provenance retained. |

## Remaining gaps / validation boundaries

- Coordinating agent must compile and capture native light/dark views, camera pills with real suggestions, large Dynamic Type, and review/save regression. Swift parser validation and scoped diff check passed; no build or simulator run by this agent. Native chat baseline was inspected; updated rendering remains the coordinating agent's verification.
- Broad UI audit here is source-backed; it does not establish that every chat suggestion state renders perfectly on every screen size. Multi-column plan/meal comparisons and action rows now have explicit accessibility layouts; updated native accessibility screenshots remain a verification step, not deferred implementation.
- Weight history keeps its existing most-recent-ten list while the range picker filters the chart. Source behavior is intentionally preserved; a future history UX should make that scope more explicit.
- Weight Health synchronization silently ignores import errors in existing code. Reliability change is outside this visual pass.
- Legacy AddFoodView/FoodTrackingView remain in source; verify external/deep-link reachability before deleting them.
- No new backend summary, workout renderer, nutrient model, or Health export semantics added by this pass.

## Coordinated validation

See `redesign-migration.md` for the root agent's integrated native screenshot review, subsequent corrections, test results and remaining proof boundaries. Earlier pending notes above describe this subtask's handoff, not the final integrated status.
