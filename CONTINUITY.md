# Continuity Ledger - Trai

## Goal (incl. success criteria)
Implement 20+ bug fixes and UX improvements across 6 phases:
- Phase 1: Critical blockers (Live Activity, Apple Watch, AI responses, widget)
- Phase 2: Memory system rebalancing
- Phase 3: Live workout view fixes
- Phase 4: Workout summary/details fixes
- Phase 5: Custom exercise & UI polish
- Phase 6: Notifications & secondary features

## Constraints/Assumptions
- iOS 26.0+, Swift 6.2, SwiftUI, SwiftData with CloudKit
- Must maintain CloudKit compatibility (no @Attribute(.unique), all optionals)
- Use Gemini API for AI features
- Follow CLAUDE.md guidelines (modularity, <300 lines/file, modern Swift)
- App accent color is RED (not orange) - set in Assets

## Key Decisions
- **Cancel/Dismiss**: `Button("Cancel", systemImage: "xmark")` with `.cancellationAction` placement
- **Confirm/Done/Save**: `Button("Done", systemImage: "checkmark")` with `.confirmationAction` placement
- "Trai" / "Ask Trai" uses hexagon icon (`circle.hexagongrid.circle`) everywhere

## State

### Done
- Phase 1: Critical Blockers
  - 1.1 Added ActivityKit entitlement to Trai.entitlements
  - 1.2 Added HealthKitService to TraiApp environment
  - 1.3 Fixed AI response visibility (added hasSavedMemories to filter, explicit save after handleChatResult)
  - 1.4 Widget already uses deep links which are properly handled in ContentView
- Phase 2: Memory relevance filtering
  - Added filterForRelevance() method to CoachMemory array extension
  - Added topic detection (food/workout/schedule keywords)
  - Always includes restrictions, high-importance memories, and topic-matched content
  - Applied filtering in ChatViewMessaging.swift when building context

### Done (Phase 3)
- 3.1 Removed live PR display from ExerciseCard (PRs only shown in summary)
- 3.2 Added "Change Exercise" menu option with sheet for replacement
- 3.3 Added equipmentName to LiveWorkoutEntry, displayed in ExerciseCard header
- 3.4 Changed spring animations to easeInOut for better performance
- 3.5 Fixed toolbar in LiveWorkoutDetailSheet (Edit/Cancel/Save/Done flow)

### Done (Phase 4)
- 4.1 Removed "Total Volume" from WorkoutSummarySheet stats
- 4.3 Added equipment name display in ExerciseSummaryRow

### Done (Phase 5)
- 5.2 Fixed purple colors in AddCustomExerciseSheet → accent color
- 5.3 Removed lineLimit(1) from exercise descriptions in EquipmentPhotoComponents
- 5.4 Increased chat input vertical padding (10→14, added vertical padding to container)

### Done (Phase 6)
- 6.1 Added notification persistence (interruptionLevel = .timeSensitive, .list in completionHandler)

### Done (Deferred Tasks - Completed)
- 5.5 Added "Rowing Machine" as strength/back exercise (separate from cardio Rowing)
- 6.2 Added secondaryMuscles field to Exercise model with computed properties; updated AddCustomExerciseSheet and ExerciseListView to pass/save secondary muscles from AI analysis
- 5.1 Replaced hardcoded `10` with `getUserDefaultRepCount()` in addExercise(), addExerciseByName(), and replaceExercise()
- 4.2 Created PRValue struct with actual values (newValue, previousValue, isFirstTime); updated createExerciseHistoryEntries() to track PR details; added PRRow component to WorkoutSummarySheet for rich PR display

## Open Questions
- None

## Working Set
- NotificationService.swift
- NotificationDelegate.swift
