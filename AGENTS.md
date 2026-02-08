# AGENTS.md

## Purpose
- Shared operating notes for coding agents working in this repository.

## Project Scope
- App code: `/Users/nadav/Desktop/Trai/Trai`
- Widgets: `/Users/nadav/Desktop/Trai/TraiWidgets`
- Xcode project: `/Users/nadav/Desktop/Trai/Trai.xcodeproj`

## Working Rules
- Make targeted, minimal changes.
- Preserve existing architecture and naming conventions.
- Run a focused build/test check after edits when possible.
- Do not revert unrelated local changes.

## Validation
- Prefer project-level build checks for modified Swift files.
- If full build is expensive, run the smallest check that still validates compile safety.

## Product Notes
- Branding: keep the Trai lens/hexagon icon unless explicitly discussed; avoid changing icon shapes unilaterally.
- Color consistency: match accents (e.g., Review with Trai buttons, toolbar checkmarks) to the Trai Memories hexagon colors; use `.tint(.accentColor)` for confirmation actions where applicable.
- Widgets: the Trai widget "Log Food" button was reported as non-functional; verify the widget action/deep link flow.
