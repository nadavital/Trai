# Activity disc / petal exploration

Separate DEBUG launch: `UITEST_MODE --activity-disc-study --disable-tab-prewarm`. No dashboard integration, model reads/writes or HealthKit writes. Add `--disc-bloom --disc-autoplay` for the slow Bloom playback capture.

## Meaning

One region means one planned training day. Red = strength, cyan = cardio, purple = mixed sample workout. Completed days fill regions; planned days remain visible in neutral material. A completed goal preserves its shape and reports additional days beside the count. Goals span one through seven days. This is a day count, not time/calorie distribution.

## Alternatives

- Petal disc: fitted rounded sectors, narrow seams, restrained gradients and edge highlights. Strongest count readability and compact representation.
- Bloom: broader scalloped lobes sharing the same radial division. Outer contour was revised after native review to remove visible curve joins.
- Glass: native SwiftUI Liquid Glass applied to the same fitted sector shapes. Useful comparison, but against this quiet background it adds less visible depth than the shaded version. Do not describe it as a convincing refractive hero simply because the API is present.

## Interaction

Tap a day to lift it slightly and reveal sample workout detail. Log a day fills only the next region using an animated mask. Reset clears regions. Play states runs empty through one additional day; Slow provides a deliberate comparison. Target changes preserve completed count and clear selection. Reduce Motion disables spring/mask interpolation; inactive scenes stop playback. Miniatures are static, non-glass, noninteractive previews.

## Native review and validation

Focused XCTest scenario passed: selection, reset, completion, extra-day accessibility label, all materials, partial Bloom/Glass, dark mode and one/seven-day targets. Result: `/private/tmp/trai-disc-study-final.xcresult`. Initial assertion used visual '+1' rather than its spoken label and was corrected. Final singular-day copy and smooth contour refinements were rebuilt for motion capture.

Captured regular-iPhone screens are in `/Users/nadav/.codex/visualizations/2026/09/19/01a0b6f9-bf5f-7100-8d57-794c1fdf0060/activity-disc-study/`. A second agent reviewed native stills: planned sectors remained visible, compact42pt previews stayed countable, and dark mode had no observed clipping. These captures do not establish physical-device or exhaustive accessibility validation.

Final motion review: `bloom-transitions.mp4` records actual native playback; `bloom-motion.mp4` trims the launch interval without changing playback speed. Frames were examined at half-second intervals through reset, individual fills, completion and the additional-day badge. The unchanged sectors hold their positions; the filling mask animates on the changing sector and the count updates at the transition start. The final continuous Bloom contour has no observed shoulder joins. Bloom partial/complete stills were refreshed from that same recording. Fitted-disc selection/reset motion was also inspected from the first XCTest screen recording. No claim of frame-rate profiling or physical-device validation.

Independent motion review caught a brief mismatch between hero and compact count transitions. Both count labels now disable inherited animation, keeping animation on the petals. This final adjustment passed a project build (`/private/tmp/trai-disc-count-build.log`); the saved video predates that adjustment.

## Flower revision — September 25

The user rejected the disc-like silhouette and filling metaphor. The Flower experiment now uses separate overlapping blue-indigo petals, one per goal day. Completion changes the whole petal's color rather than filling a vessel. Extra days introduce slimmer champagne-gold petals **on top**, with stable angular slots between planned petals and independent selection. The earlier behind-the-flower and broad gold foreground renders were rejected during review. Nutrition remains unchanged; this experiment is not integrated into the dashboard.

Native review includes a partial, selected, empty, complete and extra-day sequence, plus light/dark and varying goals. Gold petals intentionally differ from the planned petals in both layer and hue. With a one- or two-day target, the mark cannot read as a full flower without inventing goal petals; keep the exact day count honest.

Validation for this revision: `TraiTests/testActivityFlowerStudy` passed in `/private/tmp/trai-flower-native.xcresult`, including planned and bonus selection, reset, completion, light/dark, and goals 1, 2, 3 and 7. Subsequent geometry refinements reduced the gold petal footprint and tapered its roots; `/private/tmp/trai-flower-refined-build.log` passed. The native recording in `activity-flower-study/flower-states.mp4` uses the final geometry. The final gold petals occupy adjacent foreground positions; the previous opposite arrangement read as a bow and was rejected during review.

## Orbit / thin-petal motion study

The user rejected the flower silhouette and supplied Meta AI's newer logo as a reference. Inspected the 2026 mark visually in the browser: separate angled elliptical forms around an open center, with soft volume and edge highlights (https://commons.wikimedia.org/wiki/File:Meta_AI_Logo_(2026).svg). A new `Orbit` treatment (`--disc-orbit`, sample target five) explores those geometric qualities without using the logo asset. Petals shift whole-surface color on completion; extras appear in a smaller foreground layer.

The latest request adds slight 3D rotation and raises concern about similarity to Trai's bubble mark. Orbit now has a thin shaded edge, a 20-degree tilt with a restrained nine-degree oscillation and three-degree in-plane motion. SwiftUI perspective transforms create the effect; these are not 3D mesh petals. The miniature and Reduce Motion rendering are static. The study includes the actual `TraiIdentityMark` beside the activity mark for comparison. Review agrees that the six-day orbit remains structurally too close to Trai's six surrounding nodes; animation and blue color alone do not resolve that. Do not treat this as an approved Activity identity or migrate it into the dashboard.

Orbit validation: focused native test passed in `/private/tmp/trai-orbit-tilt-reviewed.xcresult` (selection, reset, complete, bonus selection, two extras, dark mode, seven/four goals and identity comparison). The first run exposed duplicate accessibility controls from the decorative comparison; miniature Orbit instances now hide accessibility and disable hit testing at the component boundary. Full-size lenses use minimum44pt hit regions. No claim of exhaustive overlapping-target or performance validation; the full hero currently updates at30fps while mounted, so profile and add visibility gating before any production reuse.

## Latest direction: same-row Sweep

User then rejected the stacked gold layer for this design and asked for more separation from Meta. `Sweep` supersedes the Orbit presentation: an open arc capped at260degrees, gently bent blunt-ended petals, and identical radius/size for planned and extra days. Gold extras append to the same sequence. The arrangement redistributes when the total visible day count changes, while remaining fixed during ordinary completion color changes. A one-day goal centers its single petal rather than leaving an empty orbit. Gentle3D tilt remains; the compact and Reduce Motion versions are static. Prior foreground-layer guidance is historical, not the current decision.

## Current selected experiment: tinted-glass gauge

The user abandoned petals for a partial speedometer-shaped gauge, then specifically requested tinting the glass itself rather than refracting a colored backing through a clear shell. `Gauge` is now the default study. The native glass branch contains separate `.regular.tint(...)` surfaces for completed blue, neutral remaining, and gold extra-day accent sections. It has no colored fill underneath a clear overlay. A small seam separates the materials. The non-glass toggle and compact thumbnail retain simple opaque fills, including the Reduce Transparency fallback.

The240degree gauge fills according to completed/target training days, clamps at the goal, and retains an inline +N for surplus days. Inner marks correspond to the configurable weekly goal. Initial native captures exposed holes where independently appended end-cap contours overlapped the band; the glass band was rewritten as a single closed outline. Blue and gold tint opacities were softened to preserve material detail. The corrected build passed (`/private/tmp/trai-gauge-tinted-final-build.log`). Focused UI checks passed before that cap/tint refinement (`/private/tmp/trai-gauge-tinted.xcresult`), covering reset, completion, surplus, material toggle and dark mode. Final recorded native states are in `activity-gauge-study/tinted-glass-states.mp4`. Large accessibility typography remains a prototype follow-up; this is not integrated into the dashboard.

Motion review found an off-track curved fragment during zero/full glass surface insertion. The tinted-glass container now disables inherited geometry animation, so integer day updates change glass sections directly without automatic insertion/removal morphing. The satin preview retains its animated fill. The corrected build passed (`/private/tmp/trai-gauge-stable-build.log`); final native playback is `activity-gauge-study/tinted-glass-stable.mp4`. Do not use the earlier `tinted-glass-states.mp4` as the final transition reference.

## Continuous lap fill — latest behavior

Removed day tick marks, material seams and the terminal gold stop. The partial gauge now fills continuously from left to right, and each extra goal multiple starts a new color from the left over the completed lap: blue to1×, gold to2×, teal to3×, rose to4×, then further distinct colors within the seven-day range. Exact multiples retain the fully completed color; they do not reset to an empty next lap. The +N label follows the current lap color.

`GaugeLapFill` interpolates total goal multiples with monotonic ease-in-out (not a spring that could overshoot an integer threshold and flash a false next lap). Two fixed full-track native tinted-glass surfaces are revealed with complementary radial masks. The glass geometry never inserts or morphs, and the radial masks preserve optical edges/shadows while meeting without a deliberate gap. The miniature uses the same lap model with flat colors. `--disc-laps` sets a two-day sample goal so a legitimate seven-day week demonstrates3.5×. The normal goal remains user-adjustable; no real data is written.

Focused native checks passed in `/private/tmp/trai-gauge-laps.xcresult` for exact1×/2×/3×, intermediate1.5×/2.5×/3.5×, reset and dark mode. Final easing/optical-mask refinements built successfully (`/private/tmp/trai-gauge-laps-optics.log`) and were recorded natively in `activity-gauge-laps/continuous-laps.mp4` for transition review.

### Session counts — latest refinement

The gauge now counts workout sessions, including multiple sessions on the same day. It shows the actual numerator (for example 6 / 1), with no additional +N badge. The compact preview shows only the completed count (6 workouts). Logging is no longer capped at seven, and the prototype goal control supports 1–21 workouts per week. Legacy day/petal studies retain their old semantics.

This remains an isolated sample-data study. Production currently derives its goal from workoutPlan.daysPerWeek; integration must introduce an explicit session-count goal rather than relabel that day goal. Count completed sessions only, deduplicating matching Trai/Watch/Health records for the same workout.

### Over-goal shimmer and terminal color

Workout totals remain uncapped. The seven-color sequence now clamps to its final warm orange at 7× rather than cycling back to blue; later totals retain that full material. Tiny white glints appear only in the over-goal portion of the first extra lap, then across the band beyond 2×. Their positions are fixed, with gentle independent brightness changes at 24 fps. Reduce Motion holds them still, inactive scenes pause them, and compact marks omit the effect. This is a native Canvas accent over the existing tinted glass, not a change to HealthKit or the dashboard.
