# Weight mark study

Isolated DEBUG route: `--weight-mark-study`. Sample-only values; no writes to HealthKit or user history.

## Direction

Weight should be an approachable check-in, without a score, fill target, streak, celebratory change in body size, or foregrounded gain/loss. The large mark keeps the same geometry and palette for every measurement. An explicit latest value and timestamp carry the information. The compact card pairs a static mark with the latest value and a local log action.

Two candidates are retained for review:
- Fold: two broad, curved tinted-glass pieces; a personal saved-entry metaphor.
- Imprint: overlapping rounded glass tiles with two quiet lines; a personal record metaphor.

Both avoid the nutrition sphere silhouette and activity's goal-filling gauge. Compact variants use a flat gradient for clarity and rendering cost. Reduce Transparency also uses that fallback. Save feedback respects Reduce Motion. Entry sheet is deliberately sample-only and uses kilograms for this visual study; production integration must reuse the existing weight logging flow, preferred units, validation, and HealthKit ownership.

## Next integration decisions

The approved activity gauge counts completed workouts, not distinct dates. Production still uses the saved plan's daysPerWeek goal, so integration must expose an explicit session goal and deduplicate Trai/Watch records before applying the visual. Do not silently reinterpret existing day goals.

Weight marks remain experimental until chosen. Then review nutrition/activity/weight together at actual header and dashboard sizes; primary dashboard cards remain opaque, with glass reserved for section chips, visual material, and selected controls. Live workout is the next flow to audit after these core dashboard representations.

## Native review — September 27

Focused UI test passed for concept switching, opening/saving a sample check-in, dark mode, and missing measurement. Native captures exposed oversized transformed glass tiles despite a passing interaction test; replacing view transforms with rotated shape paths fixed the rendering. Final captures were inspected by parent and independent reviewer. Both symbols remain readable at compact size; Imprint suggests a saved record more directly, while Fold can suggest a loop or refresh. Neither is yet a definitive weight identity. No production migration is implied by this study.

Evidence: /private/tmp/trai-weight-marks-path.xcresult; /private/tmp/trai-weight-final-captures.
