# Connected food camera sheet

The compact camera sheet is now the default food-logging presentation, including dashboard actions, meal-session additions, and widget/deep-link entry points. It preserves the originating date and meal session. There is no separate experimental dashboard route.

The sheet uses `FoodCameraView(compactPresentation: true)`, the shared camera/photo/description draft, authenticated `AIService` analysis and refinement, and the same accepted-snapshot/persistence/widget/food-memory/HealthKit save path. It does not have a second networking or persistence implementation. Health export continues to respect existing profile permissions.

The camera occupies the sheet; review exposes name, estimate, portion, nutrition disclosure, correction and Save. Native sheet corners and concentric inset shapes are used. Retaking or dismissing invalidates pending results. Portion adjustments scale optional nutrients and component quantities without inventing unknown values. Local edits have separate snapshot provenance from AI refinements.

## Verification boundary

UI tests with `UITEST_MODE --ui-test-mock-food-ai` use a bundled photo and deterministic estimate. They exercise real UI, draft, edit, persistence and dashboard update code in an in-memory test store, not hosted AI or a physical camera. The design simulator currently has a test identity. A normal signed-in hosted account is required to verify a real estimate. Do not reuse the fake UI-test identity against a hosted backend.

Focused tests: `testFoodSheetSavesEditedPortion`, `testFoodSheetRefinesAdjustedPortion`, `testFoodSheetRetakeAndCancelDoNotSave`, `testDashboardCameraLogAutomaticallyAnalyzesAndUpdatesNutrition`, and `testCapturePortionScalesNutrientsAndComponentsWithoutInventingMissingValues`.

Verified 2026-09-21: all five focused checks passed in `/private/tmp/trai-food-sheet-check.xcresult`. After the final edit-lock change, the refinement UI test passed again (`/private/tmp/trai-food-sheet-refinement-final.log`). Capture/review screenshots exported to the session's `connected-food-sheet` visualization folder and visually inspected. Hosted AI, physical camera and actual HealthKit delivery remain unverified.


## Default rollout — 2026-09-23

The dashboard nutrition title and Nutrition page heading/caption were removed, sphere spacing increased, and Nutrition retains one top Log food action. Reminders now appear as compact rows on Today; meals use an open photo-led timeline on Nutrition. Existing edit, delete, session-add, and reminder callbacks are retained.

Native simulator validation: dashboard capture/save, direct Nutrition navigation, portion save, and pending widget/deep-link camera presentation passed in `/private/tmp/trai-airy-default-sheet.xcresult`. The correction test initially used an obsolete TextView query; after targeting the correction field explicitly it passed in `/private/tmp/trai-airy-refinement-final.xcresult`. Final layout rebuild and capture/save/navigation tests passed in `/private/tmp/trai-airy-layout-final.xcresult`; dashboard and Nutrition screenshots were visually reviewed. AI estimates were deterministic test fixtures, not hosted AI calls. These changes have not been uploaded to TestFlight.


## Contextual actions and remembered meals

Today now places compact Log food and secondary Add controls with its daily context. Opaque Activity and Weight cards carry their own start/resume and logging actions; their headings switch dashboard sections. The three large action tiles are removed. An active workout also exposes Resume near Log food.

The camera exposes a Recent & usual menu before capture whenever existing food suggestions are available. Selecting a remembered meal opens the shared review without saving automatically; there is no additional gateway before the camera. Suggestions continue to use the existing ranking, cache and provenance callbacks. The deterministic --ui-test-food-suggestions fixture is gated by UITEST_MODE.

Four simulator checks passed in /private/tmp/trai-context-cards.xcresult: photo logging, remembered-meal selection and cancel without saving, contextual weight logging, and active workout resume. Native dashboard, cards and camera screenshots reviewed. These checks use test data and do not establish hosted AI or real-camera behavior.
