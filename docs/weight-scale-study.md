# Weight scale study

Isolated SwiftUI study, launched with `--scale-study` (optional `--scale-dark`). The scale is rendered from rounded shapes, gradients, shallow perspective, and a recessed coral display. Compact header, dashboard card, and hero share the same geometry; the smallest mark removes numeric detail.

Sample-only logging updates local state and illuminates the display. No app model or HealthKit writes. No goal progress, weight judgement, streak, or animated ambient effect. Production navigation is unchanged.

Native capture and check-in verification: `TraiUITests/testWeightScaleStudy`. Accessibility sizes and physical-device interaction remain outside this focused visual study.

## Native review
- Final app build succeeded (`/private/tmp/trai-scale-final-build.log`).
- Captured and inspected both light and dark appearances on the regular iPhone simulator.
- First capture exposed compact mark positioning outside its container; corrected scaled-frame alignment and rebuilt, then confirmed corrected native captures.
- Automated interaction test was interrupted after simulator startup stalled. Do not treat the sample save flow as runtime-tested.
- Captures: `scale-study/light.png`, `dark.png`, `comparison.png` in this thread's visualization directory.

## Integration
Promoted the accepted mark to `Trai/Shared/DesignSystem/WeightScaleMark.swift`. Dashboard section header, Today weight card, and Weight section now share it. Latest measurement and kg/lb conversion come from the existing dashboard data; missing measurements retain an empty display. The latest value also remains in readable adjacent text and the existing accessibility value. Logging and history routing are unchanged. Weight actions now use the brand accent.

`testIntegratedWeightScale` passed in light and dark appearances, including Today → Weight detail → existing Log Weight sheet. Native captures reviewed. Results: `/private/tmp/trai-integrated-scale.xcresult` and `/private/tmp/trai-integrated-scale-dark.xcresult`. No real HealthKit writes were made by the test.

Activity still uses the existing training-day tiles in production. The separately explored session-count gauge has not been integrated by this weight change.
