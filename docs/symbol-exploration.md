# Activity and Weight symbol study

This is a separate DEBUG-only native SwiftUI exploration. The dashboard, production cards and model data are unchanged by this study. Launch with `UITEST_MODE --symbol-exploration --disable-tab-prewarm` to use an in-memory store and the study screen.

## Activity

Open and folded arrangements use one dimensional petal per planned training day. Red/cyan distinguish sample strength/movement sessions. Target and completed days are independently adjustable; extra days remain visible in the count. Petals reveal sample workout detail on tap. The miniature tests whether the same silhouette survives at header size.

Evaluate: does the flower read as personal activity rather than a decorative logo? Can people distinguish completion without counting every petal? Are one-, two- and seven-day targets recognizable? Does the folded version remain readable when petals overlap?

## Weight

Gathered and fanned arrangements give recent check-ins a neutral, tactile identity. Each fixed sample can be selected; the number and date sit below the artwork. No shape, area, height or hue maps to mass, change, health or goal attainment. Empty, one and four samples are available.

Evaluate: do these feel like meaningful check-ins or arbitrary stones? Is selection obvious? Are compact pebbles still recognizable and tappable? This metaphor remains exploratory; do not migrate it into the dashboard without a design decision.

## Boundaries

Native gradients, custom SwiftUI shapes and spring transitions; no bitmaps, no Metal shader, no claim that the hero shapes are Liquid Glass. Native glass is used only on the small action control. Reduced Motion suppresses animated selection and transitions. Light/dark appearance is selectable. All values are fictional samples, with no Health/backend reads or writes from these views.

## Native review — September 25

Built and ran on Trai-Regular-iPhone-Design (`B99B3A5C-52F0-4757-A012-A75D980A8212`). Two focused UI checks passed: variable targets (1/7, extra/empty) and petal/pebble selection, arrangements, completion, light/dark and empty/one/four check-ins. Native screenshots were inspected; incomplete-petal contrast was strengthened and the Weight screen condensed so compact previews fit. Final result: `/private/tmp/trai-symbol-study-final.xcresult`.

Captures: `/Users/nadav/.codex/visualizations/2026/09/19/01a0b6f9-bf5f-7100-8d57-794c1fdf0060/symbol-study/`.

Design judgement: open petals communicate counts more directly; folded petals have the more distinctive silhouette. A one-day target becomes a single bud, so that state needs aesthetic refinement if this direction is chosen. Pebbles are approachable but still need their label to communicate weight/check-ins. This is an exploration, not a final dashboard design. Large-text and physical-device review are not established by these captures.
