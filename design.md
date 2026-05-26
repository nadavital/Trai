# Trai Design Notes

Trai uses a warm, rounded, material-backed SwiftUI design language. Keep main screens compact and card-based, and move secondary detail into toolbars, sheets, or drill-down views instead of making primary scroll surfaces taller.

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
- Use Liquid Glass only as a small interactive accent on micro-surfaces like chat input controls or tiny buttons. Do not make it the default language for primary cards.

## Layout

- Cards should usually have internal padding around 14-20 points.
- Use the shared spacing scale: 4, 8, 16, 24, and 32.
- Prefer concise sections with clear hierarchy over long explanatory blocks.
- Avoid oversized marketing-style surfaces inside the app.
