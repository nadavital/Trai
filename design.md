# Trai Design Notes

Trai uses a warm, rounded SwiftUI design language with opaque semantic card surfaces. Keep main screens compact and card-based, and move secondary detail into toolbars, sheets, or drill-down views instead of making primary scroll surfaces taller.

## Tokens

Prefer the existing design system tokens and helpers:

- `traiCard`
- `traiPrimary`
- `traiSecondary`
- `traiTertiary`
- `traiBackground`
- `traiSheetBranding`
- `TraiSpacing`
- `TraiRadius`
- `traiHero`
- `traiBold`
- `traiHeadline`
- `traiLabel`

## Product Rules

- Keep the Trai lens/hexagon icon intact unless the brand direction changes explicitly.
- Match confirmation actions to the Trai accent palette, usually with `.tint(.accentColor)`.
- Keep widgets aligned with the existing `LogFoodCameraIntent` and `showingFoodCamera` routing.
- Keep primary cards and dashboard action tiles opaque. Reserve Liquid Glass for section navigation, nutrition orb/fill visualizations, and selected small controls; do not use it for whole content cards.
- Today has one compact food action beside its daily context, plus a secondary Add menu. Activity and Weight cards own their actions. Surface Resume beside food only while a workout is active. Avoid a second row of navigation-like action tiles.

## Layout

- Cards should usually have internal padding around 14-20 points.
- Use the shared spacing scale: 4, 8, 16, 24, and 32.
- Prefer concise sections with clear hierarchy over long explanatory blocks.
- Avoid oversized marketing-style surfaces inside the app.

## Redesign ethos — current migration

Trai complements Health as both a reader and a tool. Design around the next useful action, then progressively reveal history, customization and explanation. The Health references inform hierarchy, dynamic section navigation and approachable data; do not duplicate its navigation or its read-only interaction model.

- **Quiet structure, expressive data:** opaque rounded content cards, warm semantic backgrounds, consistent red brand. Glass is reserved for navigation, capture suggestions, small controls and the nutrient vessels. No glass content-card stack.
- **One primary action:** food capture on Today; the next workout on Train; the active exercise/next set during a session. Put other actions with relevant cards or a compact menu. Avoid duplicate toolbars, headings and competing action-tile rows.
- **Color has meaning:** protein red, carbs cyan, fat purple, fiber green, sugar orange across dashboard, settings, details and widgets. Pair colors with names and quantities. No activity rings for nutrition; no workout stock photography.
- **Honest state:** missing targets stay unset, missing optional nutrients stay partial, zero is empty, and over-target values remain readable without moral judgement. Photos belong to actual meals.
- **Delight through feedback:** direct meal pills, native selection/press feedback, subtle orb motion, clear progression. Respect Reduce Motion, Reduce Transparency and larger text. Do not add copy or animation without a purpose.
- Pause decorative nutrition motion when its page is hidden, offscreen, or the app is inactive. Keep optional setup collapsed and unavailable Health data concise. Workout entry prioritizes session name and Start; recovery reasoning expands on demand.
- **Personal and customizable:** preserve all plan templates, custom exercises, goals, records, history and editing paths. Chat helps explain and adjust; it does not duplicate the dashboard's action tiles.
- **Safe write paths:** suggestions open review before saving. Preserve camera/widget routes, original date/session, estimate provenance, Watch session state and Health export ownership. Do not manufacture precision or duplicate Watch data for visual completeness.

Regular iPhone is the primary review target. Native forms/menus remain where they are the clearest interaction; consistent does not mean every screen has the same layout.

## Contextual navigation and visual identity

- Main tabs are Dashboard, Workouts and Trai. Account is a compact destination opened from the Dashboard header; it contains personal settings, reminders, memories, saved conversations and account/subscription controls.
- Nutrition plan management lives in Nutrition. Workout plan management lives in Workouts → Plan. Never restore a second plan dashboard inside Account.
- Nutrition uses filled nutrient vessels; Activity uses a continuous open dial against an explicit weekly workout-session goal; Weight uses a neutral scale-inspired latest check-in, with trends in history. Give each data type its own representation rather than repeating orbs, rings or generic stat tiles everywhere.
- Today uses compact versions of those representations with local actions; detailed sections expand the same visual idea. Training gaps mean no workouts logged, not a claim of inactivity. Mixed sessions belong to the strength/mixed category. Weight does not foreground gain/loss, goal distance or weigh-in streaks. The activity dial counts completed sessions in the calendar week, including multiple sessions on one day, and excludes merged Watch duplicates and unfinished live workouts. Its optional session-count goal is separate from plan days; an unset goal remains unset. Over-goal laps change color from the left and eventually clamp their color while the count remains uncapped.

## Dashboard page ownership

- Today summarizes and offers immediate logging; its summary cards navigate to the corresponding section.
- Nutrition owns today's meal list and selectable seven-day nutrient trends. Its overview is unboxed; trend navigation scrolls within the page rather than presenting another summary sheet.
- Activity owns the weekly session goal, recorded sessions and Health movement summary. Use the expanded glass dial on the Activity page; compact dials belong in Today cards and header previews. Workouts remains the home for plan building, full session history and live training.
- Weight owns the latest check-in, selectable history range, chart and entries directly. Do not create a sparse landing page whose main purpose is to open a history sheet.
- Sheets are for focused logging, editing and configuration. Use the shared primary, secondary and tertiary capsule button styles on page surfaces; camera input and suggestions retain interactive glass capsules.

## Detail-page visual hierarchy

- Detail pages lead with an unboxed, expressive visual and its current value. Do not reuse the miniature dashboard illustration at detail-page scale.
- Put the primary action in a centered capsule row beneath the visual/state, with secondary options alongside it. Keep configuration and range controls with the content they affect rather than scattering actions above and below the hero.
- Supporting charts use the same opaque rounded surfaces, quiet sparse axes, rounded strokes and semantic accent palette as the rest of the app. Weight stays neutral about direction; retain explicit units, dates and user-selected goals.

- Paged Dashboard and Workouts containers extend beneath the native floating tab bar. Let their child scroll views retain native inset behavior, and verify the final row can scroll completely above the bar. Do not mask the lower viewport with an opaque spacer.

## Workout workspace

- Workouts uses one compact glass section strip: Train, Plan, Progress, History. Train prioritizes starting or resuming the actual session; Plan lets users inspect a template before pressing its explicit Start action.
- Live training is a focused exercise workspace, not a stack of equally weighted editors. The session strip switches between exercises; the selected exercise owns the prominent Add Set action. Keep weight, reps and units immediately editable, with notes, warmup and deletion in the set's options.
- Phone selection and Live Activity shortcuts share the same focused exercise. Preserve visited editor state across selection so pending validation and debounced edits are not lost.
- Elapsed time stays unboxed and secondary to logging. Watch connection details, suggestions, targets, session volume and notes disclose on demand. Keep actual Watch measurements visible when available; never fabricate missing readings.
- History shows available sessions inline, grouped by day. Progress previews recorded bests and goals with deeper record/recovery destinations. Completion shows the session result first and expands the detailed log on demand.
- Indigo identifies training content and selection; red remains the app brand. Opaque cards hold content, glass marks navigation and small controls. Celebration respects Reduce Motion.
