# Continuity Ledger - Trai

## Goal (incl. success criteria)
Implement bug fixes and UX improvements from user testing sessions.

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
- LiveActivityManager is now a singleton to prevent duplicate activities

## State

### Done (Previous Phases)
- Phase 1-6: All previous bug fixes completed
- Memory relevance filtering, Live Activity entitlement, etc.

### Done (User Testing Bug Fixes - January 2026)
- **Issue #6 & #13**: Fixed Live Activity deduplication
  - Made LiveActivityManager a singleton (`LiveActivityManager.shared`)
  - Added guard in `startActivity()` to prevent duplicates
  - Added `cancelAllActivities()` call on app launch
  - Added guard in ContentView to prevent multiple workouts
- **Issue #2**: Fixed typing slow in Live Workout View
  - Reduced Live Activity timer from 1s to 5s
  - Reduced heart rate polling from 2s to 5s
- **Issue #5**: Fixed up-next recommending same exercise
  - Added filter to exclude exercises already in current workout
- **Issue #10**: Fixed weight suggestion logic
  - Prioritizes current workout's last set weight when user modifies it
  - Falls back to historical pattern only when user hasn't changed weight
- **Issue #8**: Fixed floating point weight issues (90 showing as 89.9)
  - Added rounding to nearest 0.5 when saving weights
  - Applied to SetRow weight input and ExerciseHistory storage
- **Issue #1**: Improved photo loading indicator
  - Added modal overlay with descriptive text ("Analyzing equipment...")
  - Removed tiny inline ProgressView
- **Issue #3**: Fixed heart rate display in Live Activity
  - Shows "--" when heart rate unavailable instead of hiding the section
- **Issue #11**: Fixed description text alignment
  - Added `.multilineTextAlignment(.leading)` to description texts

### Done (January 2026 - Phase 2)
- **Issue #4**: PR management screen implemented
  - Created `PersonalRecordsView.swift` with full PR tracking
  - Shows PRs grouped by muscle group with search/filter
  - Displays max weight, max reps, max volume, estimated 1RM per exercise
  - Detail view shows PR cards and recent history
  - Accessible via trophy button in WorkoutsView toolbar
- **Issue #7**: Timer removed from Live Activity
  - Removed timer from Lock Screen view
  - Removed timer from Dynamic Island expanded and compact views
  - Replaced with volume display and current exercise name
- **Issue #9**: Machine info for non-photo exercises
  - Updated `defaultExercises` tuple to include equipment names
  - Added `inferEquipment(from:)` static method to infer equipment from exercise names
  - Added `displayEquipment` computed property that returns stored or inferred equipment
  - Updated `LiveWorkoutEntry` init to use `displayEquipment`

### Not Implemented (Deferred)
- **Issue #12**: End confirmation morphing (iOS 26 API research needed)

### Done (January 2026 - PR View Improvements)
- PersonalRecordsView improvements:
  - Fixed StatBox to use equal width distribution with consistent height
  - Fixed ExercisePRRow to use Grid layout for consistent column alignment
  - Fixed color reference (`.accent` → `Color.accentColor`)
  - Added edit functionality via EditHistorySheet (weight, reps, date)
  - Added swipe-to-delete for individual history entries
  - Added context menu with Edit/Delete options
  - Added "Delete All Records" button for exercise
  - Added confirmation dialogs for all delete actions
  - **Weight unit support**: Respects user's lbs/kg preference from UserProfile
    - All weight displays now convert kg↔lbs based on `usesMetricExerciseWeight`
    - Affects ExercisePRRow, PRDetailSheet, HistoryRow, EditHistorySheet
    - Volume displays also converted to proper units
- WorkoutsView data consistency fix:
  - `deleteLiveWorkout()` now also deletes associated ExerciseHistory entries
  - Prevents orphaned PR records when workouts are deleted
- LiveWorkoutDetailSheet edit sync:
  - When editing a completed workout, ExerciseHistory is now synced
  - `syncExerciseHistory()` updates all history entries linked to workout entries

### Done (January 2026 - Centralized Weight Utility with Dual-Unit Storage)
- **Issue A1 & A2**: Centralized weight logic with dual-unit storage
  - Created `WeightUtility.swift` with:
    - `WeightUnit` enum (kg/lbs)
    - `CleanWeight` struct storing both `kg` and `lbs` values pre-rounded
    - Rounding: 2.5 lbs for lbs users, 0.5 kg for metric users
    - `cleanWeight(from:inputUnit:)` computes both clean values from user input
    - `cleanWeightFromKg(_:)` for converting legacy kg-only data
    - `parseToCleanWeight(_:inputUnit:)` for string input
  - **Dual-Unit Storage** - both kg and lbs stored, no runtime conversion artifacts:
    - `LiveWorkoutEntry.SetData` now has `weightKg` AND `weightLbs`
    - `ExerciseHistory` now has `bestSetWeightKg` AND `bestSetWeightLbs`
    - Custom decoder migrates legacy data (computes lbs from kg)
    - Helper methods: `displayWeight(usesMetric:)`, `formattedWeight(usesMetric:showUnit:)`
  - Updated Live Activity to respect user's unit preference:
    - Added `usesMetricWeight` to `ContentState` in both files
    - `LiveActivityManager.updateActivity()` accepts `usesMetricWeight`
    - `LiveWorkoutViewModel` passes user's preference to Live Activity
  - Updated all weight save/display points:
    - ExerciseCard.swift, LiveWorkoutDetailSheet.swift
    - LiveWorkoutViewModel.swift, WorkoutTemplateService.swift
    - ChatViewActions.swift, PersonalRecordsView.swift
  - **Guarantees**: No `.9` or `.2` decimals ever displayed - all weights are clean

## Open Questions
- None

## Working Set
- WeightUtility.swift (CleanWeight dual-unit storage)
- LiveWorkoutEntry.swift (SetData with kg + lbs)
- ExerciseHistory.swift (bestSetWeightKg + bestSetWeightLbs)
- TraiWorkoutAttributes.swift (Live Activity with user units)
- TraiWidgetsLiveActivity.swift (widget Live Activity)
- ExerciseCard.swift (dual-unit input/display)
- LiveWorkoutDetailSheet.swift (dual-unit edit mode)
- LiveWorkoutViewModel.swift (CleanWeight set creation)
- PersonalRecordsView.swift (WeightUtility display)
- WorkoutTemplateService.swift (CleanWeight)
- ChatViewActions.swift (CleanWeight)

---

# Master Bug/Feature List (January 2026 Testing Session)

## Already Fixed - Verification Results
- [x] Photo loading indicator ✅ VERIFIED
- [ ] Typing slow - ❌ FAILED (maybe worse, needs deep investigation)
- [x] Heart rate placeholder "--" ✅ VERIFIED
- [ ] Up-next recommending same exercise - ❌ FAILED (still happens, possible duplicate exercise issue)
- [x] Multiple live activities / one workout limit ✅ VERIFIED
- [x] Timer removed from live activity ✅ VERIFIED
- [x] Floating point rounding - Fixed with WeightUtility (rounds to 2.5 lbs for lbs users, 0.5 kg for metric)
- [x] Machine info in live workout ✅ VERIFIED
- [x] Suggested weight logic ✅ VERIFIED
- [ ] Description text alignment - ❌ FAILED (still center aligned in "exercises you can do")
- [x] Three-dot change exercise menu ✅ VERIFIED
- [ ] End confirmation morphing (Deferred - iOS 26 research)

## New/Remaining Issues

### A. Weight & Units (Centralization) - HIGH PRIORITY
- [x] A1: Centralized weight logic for rounding + unit conversion throughout app
- [x] A2: Live activity shows kg instead of user's preferred units
- [ ] A3: Flag large weight jumps, ask confirmation before saving

### B. Workout Summary View
- [ ] B1: Exercises section doesn't take full width
- [ ] B2: Doesn't show correct machine names
- [ ] B3: Remove "total lifted" (reps × weight)
- [ ] B4: Show actual PR value when set, not just category
- [ ] B5: Show machine names

### C. Machine Recognition / Photo Flow
- [ ] C1: Sometimes doesn't work / shows nothing (structured output?)
- [ ] C2: "Exercises you can do" lost card views, descriptions center-aligned (should be left)
- [ ] C3: Some machines incorrectly default to bodyweight - only match if exact
- [ ] C4: Exercise descriptions cut off at 1 line
- [ ] C5: Replace Trai icon + purple accent with red to match app

### D. Exercise Differentiation
- [ ] D1: Differentiate machine vs bar/dumbbells (incline press machine vs bar)
- [ ] D2: Differentiate cardio rowing vs weightlifting rowing

### E. Body Diagram (New Feature)
- [ ] E1: Visual body diagram at top of muscle recovery section
- [ ] E2: Ready/recovering/needs rest sections more compact below diagram

### F. Trai Chat Tab
- [ ] F1: Trai should know current workout when user starts chat mid-workout
- [ ] F2: "Pull day" query checked muscle recovery but never returned answer
- [ ] F3: Trai overuses memories (Zepbound in every conversation) - rebalance prompts
- [ ] F4: Add vertical padding for text input background
- [ ] F5: Trai system prompt too chatty - tone down

### G. Live Workout View
- [ ] G1: Typing/scrolling/animation latency (deeper investigation needed)
- [ ] G2: Don't show PRs during input, only on workout finish
- [x] G3: Three-dot menu "change exercise" - ALREADY IMPLEMENTED
- [ ] G4: Custom exercise from photo doesn't use default rep count from settings
- [ ] G5: Support sets with different weights per set

### H. Live Activity
- [ ] H1: Doesn't update when adding exercises
- [ ] H2: Add action buttons (add exercise / add set)
- [ ] H3: Show current exercise info
- [ ] H4: User couldn't see it during actual workout

### I. Widgets (Design Overhaul)
- [ ] I1: Larger size adds no utility
- [ ] I2: Doesn't match app colors/vibe
- [ ] I3: Feels crammed, margins/borders too large
- [ ] I4: Food logging doesn't work from widget

### J. Apple Watch
- [ ] J1: Workout detection doesn't work

### K. Workout Details View (Edit Mode)
- [ ] K1: Flip pencil/checkmark positions, make checkmark red
- [ ] K2: Two checkmarks when editing - confusing UX

### L. Muscle Tracking
- [ ] L1: Store "also trains" muscle groups
- [ ] L2: Affect recovery calculations (weighted less than primary muscles)

### M. Notifications
- [ ] M1: App title missing in reminder notifications
- [ ] M2: Time-sensitive notifications for all reminders (like Apple Reminders)

### N. Graphs/Trends
- [ ] N1: Add graphs/trends for exercises

### O. Camera
- [ ] O1: Pinch-to-zoom before taking photo (machine recognition + food logging)

### P. Needs Testing
- [ ] P1: Editing reminder time doesn't update notification time
- [ ] P2: App intents/shortcuts

---
**Total: 42 items** (11 already done, 1 deferred, 30 new)
