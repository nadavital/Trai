# Trai Coach Surface Reference Map

## Scope
- Workspace: `/Users/nadav/Desktop/Trai`
- Audit date: 2026-02-24
- Goal: remove the legacy dashboard coaching surface, keep direct entry into chat, and keep internal naming coach-neutral.

## Completed Changes
- Removed the legacy dashboard hero surface and its UI component stack.
- Removed legacy chat handoff keys/state tied to that dashboard surface.
- Removed unused generation/orchestration services and orphaned tests from the legacy stack.
- Renamed remaining analytics/context services to coach-neutral names:
  - `Trai/Core/Services/TraiCoachAdaptivePreferences.swift`
  - `Trai/Core/Services/TraiCoachContextAssembler.swift`
  - `Trai/Core/Services/TraiCoachPatternService.swift`
  - `Trai/Core/Services/TraiCoachTypes.swift`
- Renamed tests to coach-neutral names:
  - `TraiTests/TraiCoachContextAssemblerTests.swift`
  - `TraiTests/TraiCoachPatternServiceTests.swift`
- Kept dashboard visual continuity with a permanent top gradient:
  - `Trai/Features/Dashboard/DashboardView.swift`
- Kept direct user access to conversation via Quick Actions:
  - `Trai/Features/Dashboard/DashboardCards.swift`
  - `Trai/Features/Dashboard/DashboardView.swift`

## Current Product State
- Dashboard no longer renders the removed hero coaching surface.
- Dashboard keeps the top gradient permanently.
- Quick Actions includes direct `Chat with Trai`.
- Cross-tab handoff plumbing from the removed surface is gone.
- Remaining internal coaching context services consistently use `TraiCoach*` names.

## Follow-up
1. Revisit `DailyCoachEngine` ownership/scope once dashboard and chat boundaries are finalized.
