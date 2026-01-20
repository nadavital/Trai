# Continuity Ledger - Trai

## Goal (incl. success criteria)
Build Trai fitness/nutrition tracking iOS app with AI coach.

## Constraints/Assumptions
- iOS 26.0+, Swift 6.2, SwiftUI, SwiftData with CloudKit
- Must maintain CloudKit compatibility (no @Attribute(.unique), all optionals)
- Use Gemini API for AI features
- Follow CLAUDE.md guidelines (modularity, <300 lines/file, modern Swift)

## Key Decisions
- Trai is the AI coach name (trainer + AI)
- TabView with 4 tabs: Dashboard, Trai (chat), Workouts, Profile
- Energy palette (red/orange) for TraiLens
- Settings accessible via gear icon in Profile tab
- Multi-item food logging with array of suggestions
- Weight stored internally as kg, converted for display
- Sets auto-marked complete on workout finish (if reps > 0)
- Exercise suggestions generated from target muscle groups

## State

### Done (This Session)
**Bug Fixes (8 total):**
1. Multi-item food logging - now supports logging multiple foods at once
2. Unit conversion mid-workout - weights properly convert between kg/lb
3. Muscle recovery not updating - sets auto-marked complete on workout finish
4. "Get my plan" chip no output - fallback for empty text after data functions
5. 0/2 sets display - fixed by same auto-completion logic
6. Exercise suggestions without history - generated from target muscle groups
7. Ask Trai real-time workout state - context now tracks data-entered sets
8. Tap to dismiss keyboard - added to LiveWorkoutView

**Files Modified:**
- GeminiService+FunctionCalling.swift - multi-item food, data function fallback
- GeminiChatTypes.swift - suggestedFoods array
- ChatMessage.swift - multiple meal tracking
- ChatViewActions.swift - per-meal accept/dismiss
- ChatMessageViews.swift - multiple food cards
- ChatContentList.swift - updated callbacks
- ChatView.swift - dismiss callback
- ExerciseCard.swift - unit conversion for weight display/entry
- LiveWorkoutViewModel.swift - auto-complete sets, exercise suggestions
- LiveWorkoutView.swift - real-time workout context, keyboard dismiss

### Now
- All planned bug fixes complete

### Done (Current Session)

**Bug Fixes (3 total):**
1. Reminder time edit not updating notification - `scheduleCustomReminder` now checks authorization directly from UNUserNotificationCenter instead of cached flag
2. Touch area behind chat text field - Added `.contentShape(.rect)` to suggestion buttons and 80pt bottom padding to EmptyChatView
3. "Logged xxx" chip tap not working - Added `loggedFoodEntryIdsData` to ChatMessage to store meal ID → FoodEntry ID mapping; `foodEntryId(for:)` method retrieves correct entry ID

**Files Modified:**
- NotificationService.swift - Check authorization status directly in scheduleCustomReminder
- ChatMessageViews.swift - contentShape on buttons, bottom padding, use foodEntryId(for:)
- ChatMessage.swift - Added loggedFoodEntryIdsData property, loggedFoodEntryIds computed property, foodEntryId(for:) method



**Workout Plan Management Moved to Profile (6 files):**
- Removed `WorkoutPlanOverviewCard` from WorkoutsView top
- WorkoutsView now shows subtle "Get Personalized Workouts" prompt when no plan exists
- Profile shows detailed workout plan card matching nutrition plan card style
- WorkoutPlanDetailView now has Edit button in toolbar
- All plan management (create, view, edit) now happens from Profile tab
- Workouts tab focuses on doing workouts, not plan management

**Workout Plan Card Enhanced:**
- Now matches nutrition plan card layout with header + Adjust button
- Shows big stats: days/week, workouts count, avg duration
- Displays template chips (Push Day, Pull Day, etc.) with color coding
- "View Details" button links to full plan detail view
- "No plan" state shows create prompt with dashed border

**Settings: Workout Plan Access:**
- Added "Adjust Workout Plan" / "Create Workout Plan" button to Settings > Workouts section
- Opens edit sheet if plan exists, setup flow if no plan

**Files Modified:**
- WorkoutsView.swift - Removed plan overview card, removed showingPlanEdit state/sheet
- ProfileView.swift - Added showPlanSetupSheet and showPlanEditSheet states and sheets
- ProfileView+Cards.swift - Detailed workoutPlanCard() with stats, chips, action buttons
- WorkoutPlanDetailView.swift - Added onEditPlan callback and toolbar Edit button
- WorkoutTemplateCard.swift - Added onCreatePlan callback to WorkoutTemplatesSection
- SettingsView.swift - Added workout plan button and sheets

### Done (Previous Session)

**Bug Fixes & Features (5 total):**
1. **PlanHistoryView freeze fix** - Changed from @Query to @State + manual fetch (same pattern as CustomExercisesView)
2. **Calorie counter colors** - Changed orange/red to teal/blue for softer, non-judgmental progress colors
3. **Weight sync to Apple Health** - Added syncWeightToHealthKit preference, toggle in Settings, and sync on weight log
4. **Machine exercise mapping** - Added equipmentName property to Exercise, threads through photo analysis to store machine names
5. **Workout Plan Detail View** - New view showing full workout plan with collapsible templates, progression strategy, guidelines

**Files Modified:**
- PlanHistoryView.swift - @Query → @State + manual fetch
- CalorieDetailSheet.swift - Progress colors green/teal/blue
- DashboardCards.swift - Progress tint green/teal/blue
- UserProfile.swift - Added syncWeightToHealthKit property
- SettingsView.swift - Added weight sync toggle
- LogWeightSheet.swift - Added HealthKit sync on save
- Exercise.swift - Added equipmentName property
- EquipmentPhotoComponents.swift - Pass equipmentName in callback
- ExerciseListView.swift - Accept and store equipmentName
- CustomExercisesView.swift - Display equipmentName on exercise rows
- ProfileView+Cards.swift - Added workoutPlanCard function
- ProfileView.swift - Added workoutPlanCard to body

**Files Created:**
- WorkoutPlanDetailView.swift - Full workout plan detail view

### Done (Previous Session)

**4. Dashboard Add Workout Button:**
- Added `defaultWorkoutAction` setting to UserProfile (custom vs recommended)
- Added Workout preferences section to SettingsView with picker
- Dashboard button now starts workout directly based on setting:
  - Custom Workout (default): Starts empty workout
  - Recommended Workout: Starts best workout from plan based on muscle recovery
- Falls back to custom workout if no plan exists
- Shows recommended workout name under button when set to recommended mode

**Files Modified:**
- UserProfile.swift - added `defaultWorkoutAction` property and `DefaultWorkoutAction` enum
- SettingsView.swift - added Workout preferences section
- DashboardView.swift - implemented `startWorkout()`, `startCustomWorkout()`, `startRecommendedWorkout()`, `quickAddWorkoutName`
- DashboardCards.swift - added `workoutName` parameter to QuickActionsCard
- DashboardHelperComponents.swift - added optional `subtitle` parameter to QuickActionButton

### Done (Previous Session)

**1. Apple Watch Heart Rate Display in LiveWorkoutView:**
- Added heart rate read permission to HealthKitService
- Implemented `HKAnchoredObjectQuery` for streaming heart rate updates
- Created `startHeartRateStreaming()` / `stopHeartRateStreaming()` methods
- Added `fetchRecentHeartRate()` for one-time fetch
- Created `WatchHeartRateCard.swift` - displays live HR with pulse animation
- Updated `LiveWorkoutViewModel` with heart rate properties and monitoring
- Updated `LiveWorkoutView` to show heart rate card and poll for updates

**Files Modified/Created:**
- HealthKitService.swift - heart rate permission + streaming methods
- WatchHeartRateCard.swift (new) - heart rate display UI
- LiveWorkoutViewModel.swift - heart rate state + monitoring
- LiveWorkoutView.swift - heart rate card + timer for updates

**2. Onboarding Categorized Memory Parsing:**
- Created `GeminiService+Memory.swift` with `parseNotesIntoMemories()` method
- Uses structured JSON output to extract multiple categorized memories
- Supports all memory categories (preference, restriction, habit, goal, context, feedback)
- Supports all memory topics (food, workout, schedule, general)
- Updated `OnboardingView+Completion.swift` to use AI parsing
- Falls back to simple memory creation if AI parsing fails

**Files Modified/Created:**
- GeminiService+Memory.swift (new) - AI memory parsing
- OnboardingView+Completion.swift - uses AI parsing for memories

**3. Profile/Settings Restructuring:**
- Added Profile as 4th tab (was accessible from Dashboard toolbar)
- Created SettingsView with all inline editing (no extra sheets)
- Moved stats editing to Settings, Profile shows plan/memories/chat/exercises/reminders
- Settings includes: personal info, nutrition plan adjust, units, macro tracking, Apple Health
- Reminders card counts both built-in and custom reminders
- Custom exercises card matches memories/chat history style

**Files Modified/Created:**
- ContentView.swift - Added Profile tab
- ProfileView.swift - Simplified, shows plan/memories/chat/exercises/reminders
- ProfileView+Cards.swift - Updated cards for consistency
- SettingsView.swift (new) - All settings inline with Adjust Plan button
- DashboardView.swift - Removed profile toolbar button

### Done (Previous Session)
**Bug Fix:**
- **Reminder notifications not scheduling** - `ReminderHabitView` was passing `nil` for `notificationService` to `CustomReminderSheet`, so editing reminders from that view never actually scheduled the notification with the system. Now creates and uses a proper `NotificationService` instance.

**Reminders UX Overhaul (Previous):**
1. **Notification long-press actions** - Added "Mark Complete" and "Snooze 10 min" actions to all reminder notifications
2. **Better notification text** - Changed from "Tap to open Trai" to "Time for your reminder"
3. **Dashboard animation** - Reminders now show checkmark animation before fading out when completed
4. **Notification tap handling** - Tapping notification now opens dashboard and shows reminders sheet
5. **Removed "On time"/"Late" labels** - Changed to simple "Completed" text (no judgment for being a few minutes late)

**Files Modified:**
- NotificationService.swift - Added notification categories with actions, snooze function, userInfo for tracking
- NotificationDelegate.swift (new) - Handles notification taps and action buttons
- TraiApp.swift - Sets up notification delegate
- ContentView.swift - Added environment key for notification trigger, passes binding to dashboard
- DashboardView.swift - Accepts binding from parent for notification-triggered sheet
- TodaysRemindersCard.swift - Added animated checkmark and smooth removal transition
- ReminderHabitView.swift - Changed "On time"/"Late" to "Completed"

### Done (Previous Session)
1. **Apple Health food sync** - Food logged via chat now syncs to Apple Health
   - Added `syncFoodToHealthKit` preference to UserProfile
   - Modified `acceptMealSuggestion` to call `saveDietaryEnergy`
   - Added toggle in Profile preferences

2. **Confetti on workout complete** - Workout summary shows confetti animation
   - Reused existing ConfettiView from PlanReviewAnimations
   - Added to WorkoutSummarySheet with bounce effect on checkmark

3. **Track max weight (PRs)** - Personal records shown on exercise cards
   - Added `getPersonalRecord` to WorkoutTemplateService
   - Added PR cache to LiveWorkoutViewModel
   - Display trophy icon with PR weight on ExerciseCard

4. **Edit past workouts** - Can now edit sets in completed workouts
   - Added Edit/Save button to LiveWorkoutDetailSheet
   - Created EditableSetRow for inline editing
   - Changes persist via SwiftData

5. **Redo custom exercise screen** - Modern card-based UI
   - Visual category buttons (Strength/Cardio/Flexibility)
   - Grid-based muscle group selector with icons
   - Cleaner AI analysis card with purple theme

6. **Review live workout view** - PR display integrated (done with #3)

7. **Custom exercise management** - New screen to manage exercises
   - Created CustomExercisesView with search and delete
   - Added "My Exercises" card to Profile
   - Swipe to delete with confirmation

**Bug Fixes (Session 2):**
8. **Confetti animation improved** - Now 100 particles, full screen coverage, varied shapes (circles, rectangles, stars), rotation, better timing
9. **Workout start button always enabled** - Removed `.disabled(recoveryScore < 0.3)` - users can override recovery warnings
10. **CustomExercisesView freeze fixed** - Changed from @Query to @State + manual fetch (documented in COMMON_ISSUES.md)
11. **HealthKit food sync debugging** - Added proper error logging instead of silent `try?`

**Documentation:**
- Created `COMMON_ISSUES.md` with solutions for:
  - @Query freeze in navigation destinations
  - HealthKit authorization issues
  - SwiftData CloudKit constraints
  - Unit conversion mid-workout
  - Keyboard dismissal

### Next
- Machine-based exercise mapping
- Workout templates (save/reuse workout structures)
- Multi-image food logging

### Done (Previous Sessions)
- Custom reminders feature (create, edit, Trai integration, dashboard card)
- Trends visualization (TrendsService, NutritionTrendChart)
- Rest timer (auto-start on set complete)
- Plan history (NutritionPlanVersion, archive before updates)
- Apple Health activity data integration
- Plan reassessment recommendation system
- Weight history view with unit preferences

## Backlog

### Workout Polish
- Workout templates (save/reuse workout structures)
- Multi-image food logging
- Custom exercise improvements
- Machine-based exercise mapping (store machine names for photo-added exercises)

### Visualization & Gamification
- Unified gamification system for reminders, food logging, workouts
- Streak tracking, achievement badges
- Calendar heatmap for activity
- Workout progress charts

## Open Questions
- Should machine name be stored separately for photo-added exercises?
- Where should custom exercise management live (Profile section)?
- What gamification elements to add (streaks, badges)?

## Working Set
**Recently Modified:**
- ContentView.swift - 4-tab layout with Profile tab
- ProfileView.swift - simplified profile view
- ProfileView+Cards.swift - consistent card styling
- SettingsView.swift (new) - inline settings with plan adjust
- DashboardView.swift - removed profile toolbar
- HealthKitService.swift - heart rate streaming
- WatchHeartRateCard.swift (new) - HR display component
- LiveWorkoutViewModel.swift - heart rate monitoring
- LiveWorkoutView.swift - heart rate card integration
- GeminiService+Memory.swift (new) - memory parsing
- OnboardingView+Completion.swift - AI memory parsing
