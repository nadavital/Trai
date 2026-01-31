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

### Done (January 2026 - Personalized Trai Suggestions)
Implemented personalized suggestion tracking and prioritization:
- [x] Phase 1: Created `SuggestionUsage` SwiftData model with hourly tap tracking
- [x] Phase 2: Added `type` property to SmartStarter, implemented tap tracking
- [x] Phase 3: Implemented scoring algorithm (contextual bonus, usage frequency, time match, recency)
- [x] Phase 4: Replaced marquee with user-controlled horizontal scroll (2 independently scrolling rows, pinned above chat bar)

**Files created/modified:**
- `Trai/Core/Models/SuggestionUsage.swift` (NEW)
- `TraiApp.swift` (added to schema)
- `ChatMessageViews.swift` (SmartStarter + EmptyChatView)
- `ChatContentList.swift` (pass through usage data)
- `ChatView.swift` (query usage, pass to content)
- `ChatViewActions.swift` (trackSuggestionTap function)

### Done (January 2026 - Trai Chat Fixes v2)
Refined implementation based on Gemini 3 Flash prompting best practices research:

**Phase 1: Critical Bug Fixes**
- [x] Plan Review now starts new conversation (ChatViewActions.swift)
- [x] Thinking indicator shows before content arrives - `isStreamingResponse` checks `!lastMessage.content.isEmpty`
- [x] Retry button hidden on manual stop - added `wasManuallyStopped` flag to ChatMessage

**Phase 2: Data & Function Fixes**
- [x] Food log retrieval: explicit timezone + new periods (past_3_days, past_7_days, past_14_days)
- [x] Recovery query: added guidance to synthesize answer with recommendations
- [x] Active workout context: condensed to 2-3 sentence response expectation

**Phase 3: System Prompt Refactored (Gemini 3 Best Practices)**
- [x] Researched Gemini 3 Flash prompting guidelines (temperature=1.0, avoid overly broad constraints)
- [x] Removed XML rule (symptomatic, not root cause)
- [x] Condensed guidelines from ~65 lines to ~25 lines
- [x] Memory relevance rebalanced with topic matching + recency decay (CoachMemory.swift)

**Phase 4: Smart Context-Aware Empty State (v2 + Animated)**
- [x] `SmartStarterContext` with userName, calories, protein, lastWorkoutDate, goal
- [x] **Personalized greetings** via `generateGreeting()`:
  - Uses user's first name when available
  - Time-based variations (morning/afternoon/evening/night)
  - Context-aware messages (protein goal close, workout recovery, meal times)
  - Consistent per day (doesn't change on re-render)
- [x] **Unified SuggestionCard design**:
  - Horizontal layout: icon | title
  - Fixed size (160x60pt), neutral background
  - Only icons are tinted (not backgrounds)
- [x] **Continuous scrolling marquee**:
  - Two horizontal rows that scroll automatically
  - Top row scrolls left, bottom row scrolls right
  - Seamless looping with duplicated content
  - Users can still tap cards to interact
- [x] **16+ Smart suggestions**: Log meal (time-aware), Protein tracking, Start workout, Snap a meal, My progress, Muscle recovery, Am I on track?, Meal ideas, Healthy snacks, Log weight, Review plan, Calories left, My PRs, Rest day tips, Water intake, Daily activity

### Done (January 2026 - C1-C4 Machine Recognition Fixes)
- **C1**: Added error alert for photo analysis failures with "Try Again" and "Take New Photo" options
  - ExerciseListView.swift: Added `photoAnalysisError` and `lastCapturedImageData` state
  - Shows user-friendly error message instead of silent failure
- **C2 + C4**: Fixed howTo description layout in EquipmentAnalysisSheet
  - Moved howTo to separate line below muscle group badge
  - Added `multilineTextAlignment(.leading)` and `fixedSize(horizontal: false, vertical: true)`
  - Allows multi-line descriptions instead of cutting off
- **C3**: Fixed equipment inference to not misclassify machine exercises as bodyweight
  - Added `isMachineExercise` check for machine/cable/smith/seated/assisted keywords
  - Bodyweight inference only runs when `!isMachineExercise`
  - Prevents "Machine Crunch" from being tagged as "Bodyweight"

### Done (January 2026 - G4 Default Rep Count Fix)
- **G4**: Custom exercise from photo/suggestions now uses default rep count from settings
  - Fixed `loadExerciseSuggestions()` at line 385: Was hardcoded `defaultReps: 10`, now uses `getUserDefaultRepCount()`
  - Fixed `addExerciseFromSuggestion()` at line 570: Was falling back to `suggestion.defaultReps`, now uses `getUserDefaultRepCount()`
  - Affects: suggestion chips in live workout, "Up Next" exercise, all exercises added via suggestions

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

### Done (January 2026 - Workout Summary View B1-B5)
- **B1**: Fixed exercises section full-width
  - Added `.frame(maxWidth: .infinity, alignment: .leading)` to ExerciseSummaryRow
- **B4**: Fixed PR value display to respect user's unit preference
  - Added `@Query private var profiles: [UserProfile]` to WorkoutSummarySheet and WorkoutSummaryContent
  - PRRow now accepts `usesMetric` parameter and formats weights accordingly
  - ExerciseSummaryRow now accepts `usesMetric` parameter for condensed format
  - SetBadge now accepts `usesMetric` parameter and uses `displayWeight(usesMetric:)`
- **B2/B5**: Equipment names already displayed (verified existing implementation)
- **B3**: "Total lifted" confirmed never existed - no action needed

## Open Questions
- None

### Verification Checklist (Personalized Suggestions)
- [x] Build succeeds
- [ ] Tap a suggestion → SuggestionUsage record created/updated
- [ ] Tap same suggestion 5+ times → appears earlier in list
- [ ] Horizontal scroll with 2 brick-offset rows (no auto-animation)

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
- [x] Typing slow - Fixed with input debouncing (500ms delay before committing to parent)
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
- [x] B1: Exercises section doesn't take full width (added `frame(maxWidth: .infinity)` to ExerciseSummaryRow)
- [x] B2: Doesn't show correct machine names (equipment already displayed via `entry.equipmentName`)
- [x] B3: Remove "total lifted" (reps × weight) - CONFIRMED: never existed
- [x] B4: Show actual PR value when set, not just category (PRRow now respects user's kg/lbs preference)
- [x] B5: Show machine names (same as B2 - equipment shown when available)

### C. Machine Recognition / Photo Flow
- [x] C1: Photo analysis error handling - shows alert with retry/take new photo options
- [x] C2: "Exercises you can do" howTo now on separate line, left-aligned
- [x] C3: Equipment inference checks machine keywords before bodyweight (fixes "Machine Crunch" → Bodyweight)
- [x] C4: Exercise descriptions now multi-line with fixedSize vertical expansion
- [x] C5: Replace Trai icon + purple accent with red to match app

### D. Exercise Differentiation
- [ ] D1: Differentiate machine vs bar/dumbbells (incline press machine vs bar)
- [ ] D2: Differentiate cardio rowing vs weightlifting rowing

### E. Body Diagram (New Feature) - REMOVED
- [ ] ~~E1: Visual body diagram at top of muscle recovery section~~ (decided not to implement)
- [ ] ~~E2: Ready/recovering/needs rest sections more compact below diagram~~ (decided not to implement)

### F. Trai Chat Tab
- [x] F1: Trai knows current workout - enhanced active workout section in system prompt
- [x] F2: Recovery query now synthesizes answer with specific recommendations
- [x] F3: Memory relevance rebalanced - topic matching, recency decay, reduced overuse
- [x] F4: Add vertical padding for text input background
- [x] F5: System prompt condensed from ~65 to ~25 lines, less chatty

### G. Live Workout View
- [x] G1: Typing/scrolling/animation latency - Fixed with input debouncing (500ms delay)
- [x] G2: Don't show PRs during input, only on workout finish
- [x] G3: Three-dot menu "change exercise" - ALREADY IMPLEMENTED
- [x] G4: Custom exercise from photo doesn't use default rep count from settings
- [x] G5: Support sets with different weights per set → moved to U2

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
- [x] K1: Flip pencil/checkmark positions, make checkmark red
- [x] K2: Two checkmarks when editing - confusing UX

### L. Muscle Tracking
- [ ] L1: Store "also trains" muscle groups
- [ ] L2: Affect recovery calculations (weighted less than primary muscles)

### M. Notifications
- [ ] M1: App title missing in reminder notifications
- [ ] M2: Time-sensitive notifications for all reminders (like Apple Reminders)

### N. Graphs/Trends
- [x] N1: Add graphs/trends for exercises
  - Created `ExerciseTrendsChart.swift` with metric picker (Weight/Volume/1RM) and time range picker (1M/3M/6M/1Y)
  - Integrated into PRDetailSheet as first section when >= 2 history entries
  - Shows trend badge with percentage change
  - **Improved (v2)**: Better Y-axis scale with proper domain, cleaner date format (M/d), current value display in header, reduced height (120pt)
- [x] N2: Condensed PRDetailSheet UI
  - Replaced 4 separate PRCards with compact 2x2 PRStatsGrid
  - Condensed HistoryRow to single line (date | weight×reps | sets/reps)
  - Reduced overall vertical spacing
- [x] N3: Access exercise PR detail from workout detail view
  - Added tap navigation to `LiveWorkoutDetailSheet` - tap any exercise to see PR/history
  - Added tap navigation to `WorkoutSummarySheet` - drill into exercises right after workout
  - Made `PRDetailSheet`, `ExercisePR`, and supporting views accessible from other files
  - Added `ExercisePR.from(exerciseName:history:muscleGroup:)` factory method
  - Shows PR stats, trends chart, and history when tapped

### O. Camera
- [ ] O1: Pinch-to-zoom before taking photo (machine recognition + food logging)

### P. Needs Testing
- [ ] P1: Editing reminder time doesn't update notification time
- [ ] P2: App intents/shortcuts
- [x] P3: Verify workout delete/edit syncs ExerciseHistory (PR data) ✅ VERIFIED
  - Delete workout → deletes all associated ExerciseHistory entries
  - Edit workout (change weight/reps) → updates corresponding ExerciseHistory

### Q. Custom Workout Creation
- [ ] Q1: Better name saving for custom workouts (name not persisting or auto-generated poorly)
  - Also: Generate better titles based on muscle groups worked
- [ ] Q2: Add exercise suggestions based on selected muscle groups when creating custom workout

### R. Exercise Selection
- [x] R1: "Recently used" exercises should filter to muscles you're currently targeting
  - Modified `recentExercises` computed property in ExerciseListView.swift
  - Now filters by `targetMuscleGroups` when specified (e.g., during a leg workout, only shows leg exercises)

### S. Trai Chat
- [x] S1: Logging weight with Trai didn't work and no response given
  - Root cause: `log_weight` function was never implemented
  - Added function declaration in GeminiFunctionDeclarations.swift
  - Added handler in GeminiFunctionExecutor+PlanWorkout.swift
  - Supports kg/lbs input, optional date, optional notes
  - Updates UserProfile.currentWeightKg when logging for today

### T. UI Consistency
- [ ] T1: Replace weight log sheet (from weight history page) with the quick actions version
- [x] T2: Calorie breakdown screen - text doesn't fit within the ring at top
  - Reduced font size from 44 to 36 with minimumScaleFactor(0.7)
  - Reduced padding and spacing for better fit
  - Shortened "remaining" to "left" for space

### U. Live Workout Flexibility
- [ ] U1: Be able to switch target muscle groups mid-workout
- [ ] U2: Support sets with different weights per set (moved from G5)

### V. Workout History/Details
- [ ] V1: Show PRs you hit in workout detail view (not just summary)

### W. Branding
- [ ] W1: Rethink Trai symbol/icon

### X. Machine Recognition (Enhanced)
- [ ] X1: Differentiate similar machines (chest press vs converging chest press)
- [ ] X2: Default to machine name visible in image when possible (edit vision prompt)

### Y. Live Activity Bugs
- [x] Y1: Weight rounding issue - 200lb in app shows as 199 in Live Activity
  - Root cause: Runtime conversion `weight * 2.20462` caused floating point errors
  - Fix: Added `currentWeightLbs` and `totalVolumeLbs` to ContentState (dual-unit storage)
  - Now uses pre-cleaned weight values, same pattern as SetData/ExerciseHistory
  - Files: TraiWorkoutAttributes.swift, TraiWidgetsLiveActivity.swift, LiveWorkoutViewModel.swift

---
**Total: 56 items** (33 done, 1 deferred, 2 removed, 20 remaining)
