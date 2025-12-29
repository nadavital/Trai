# Continuity Ledger - Plates

## Goal (incl. success criteria)
Enhance onboarding flow to be AI-powered and personalized:
- Collect comprehensive user data (age, gender, height, weight with unit options)
- Auto-fetch user name from CloudKit/iCloud if available
- AI-calculated calorie/macro goals using TDEE formulas + LLM personalization
- Support complex fitness goals beyond basic 3 options (e.g., body recomposition, athletic performance, medical conditions)
- AI generates interpretable nutrition/fitness plan tailored to each user

Success = Users complete onboarding with personalized, scientifically-backed calorie/macro targets without needing to know their own requirements

## Constraints/Assumptions
- iOS 26.0+, Swift 6.2, SwiftUI, SwiftData with CloudKit
- Must maintain CloudKit compatibility (no @Attribute(.unique), all optionals)
- Use existing GeminiService for AI features
- Follow CLAUDE.md guidelines (modularity, <300 lines/file, modern Swift)
- Keep onboarding flow intuitive - don't overwhelm users

## Key decisions
- DECIDED: Ask for name via text field (simple approach)
- DECIDED: 5 activity levels (sedentary → athlete) + free-text notes field
- DECIDED: Generate AI plan DURING onboarding so user can review/alter before completing
- DECIDED: Include common dietary restrictions as toggleable options
- DECIDED: Use Gemini for AI plan generation (richer reasoning)
- DECIDED: AI plan returns JSON schema app can interpret and store

## State

### Done
- [x] Onboarding flow complete with AI-powered plan generation
- [x] PlanChatView with conversational AI, propose/accept flow
- [x] Comprehensive plan designed for app enhancement (6 phases)
- [x] **Sprint 1 Complete:**
  - FoodEntry model: sessionId, sessionOrder, inputMethod
  - LiveWorkout model: workout type, muscle groups, HealthKit merge fields
  - LiveWorkoutEntry model: sets tracking with JSON, cardio support
  - ExerciseHistory model: PR tracking, progress analytics
  - UserProfile extended: training day calories, check-in preferences
  - NutritionPlan: toJSON/fromJSON serialization
  - PlanService: plan retrieval, storage, recalc detection, check-in status
  - Tab restructure: 4 tabs (Dashboard, Workouts, Coach, Profile)
  - ProfileView: redesigned with premium visuals, auto-detected training day, engaging cards
  - ProfileEditSheet: name editing, height text input, activity level with icons/colors, plan nav button
  - PlanAdjustmentSheet: goal type selection (6 options), AI Coach integration, manual macro editing
  - ChatView: session management, auto-new session after 4hr timeout, chat history menu
  - ChatView: markdown rendering, streaming responses, removed timestamps
- [x] **Sprint 2 Complete:**
  - LogWeightSheet: weight logging with text input, unit preferences
  - DailyFoodTimeline: chronological food timeline (no meal type grouping)
  - CalorieProgressCard: tappable with CalorieDetailSheet (large ring, stats, chronological list)
  - MacroBreakdownCard: tappable with MacroDetailSheet (rings, calorie contribution bar, tappable food list)
  - Delete food entries via confirmation dialogs in timeline and detail sheets
  - FloatingActionButton: circular FAB with glassEffect (Food, Weight, Workout)
  - FoodCameraView: camera-first with viewfinder, manual entry, library picker, back button
  - ChatView: image attachment support, AI analyzes and auto-logs meals from photos
  - ChatMessage model: imageData, loggedFoodEntryId for meal tracking via chat
  - GeminiService: analyzeFoodImageWithChat for conversational food logging
  - EditFoodEntrySheet: edit name, macros, serving size, notes for any food entry
  - All food entries are tappable to edit (timeline, calorie sheet, macro sheet)

### Now
- Sprint 3: Plan Management + Weekly Check-ins

### Gemini Function Calling Refactor (Complete)
- [x] Replaced intent classification with Gemini function calling
- [x] Created GeminiFunctionDeclarations.swift with 7 functions:
  - suggest_food_log: Suggest meal for user to confirm
  - edit_food_entry: Edit existing food entry
  - get_todays_food_log: Get food log + nutrition progress
  - get_user_plan: Get nutrition plan and goals
  - update_user_plan: Propose plan changes
  - get_recent_workouts: Get workout history
  - log_workout: Log a workout session
- [x] Created GeminiFunctionExecutor.swift to execute functions locally
- [x] Added chatWithFunctions method to GeminiService.swift
- [x] Updated ChatView.swift to use function calling
- [x] Removed deprecated code: GeminiIntentRouter.swift, intent classification, chatWithIntentRouting
- [x] Cleaned up GeminiChatPrompts.swift (kept only used prompts)
- [x] Build verified successfully

### File Modularity Refactor (Complete)
- [x] Split GeminiFunctionExecutor.swift:
  - GeminiFunctionExecutor.swift (96 lines) - Core types and routing
  - GeminiFunctionExecutor+Food.swift (171 lines) - Food functions
  - GeminiFunctionExecutor+PlanWorkout.swift (131 lines) - Plan/workout functions
- [x] Split GeminiService.swift:
  - GeminiService.swift (195 lines) - Core API helpers
  - GeminiService+Chat.swift (140 lines) - Chat methods
  - GeminiService+Food.swift (241 lines) - Food analysis
  - GeminiService+FunctionCalling.swift (299 lines) - Function calling
  - GeminiService+Plan.swift (200 lines) - Plan generation
- [x] Split ChatView.swift:
  - ChatView.swift (354 lines) - Main view with extensions
  - ChatMessageViews.swift (190 lines) - EmptyChatView, ChatBubble, LoadingBubble
  - ChatMealComponents.swift (299 lines) - Meal suggestion UI
  - ChatInputBar.swift (109 lines) - Input bar
  - ChatCameraComponents.swift (251 lines) - Camera views
  - ChatHistoryMenu.swift (50 lines) - Session history menu
  - ChatContentList.swift (53 lines) - Message list
  - ChatSheetModifiers.swift (65 lines) - Sheet modifiers
- [x] All files now ~300 lines or less
- [x] Build verified successfully

### Next
- Sprint 4: Workout tracking system
- Sprint 5: Analytics & Progress
- Sprint 6: Polish

### Intent-Based Chat Routing (Complete)
- [x] Created GeminiIntentRouter with 6 intent types:
  - `log_food` - User wants to log a meal
  - `modify_suggestion` - User wants to change pending meal suggestion
  - `query_progress` - Asking about today's intake (includes "what did I eat")
  - `question_nutrition` - Nutrition questions (not personal intake)
  - `question_fitness` - Workout questions
  - `general_chat` - General conversation
- [x] Two-step routing architecture:
  - Step 1: Fast intent classification (low temperature, structured output)
  - Step 2: Route to specialized handler with intent-specific prompt
- [x] Streaming support for conversational intents (questions, general chat)
- [x] Food log included in general chat context (safety net)
- [x] EnhancedFitnessContext carries full context (food log, conversation history, pending suggestion)
- [x] Modular prompt files:
  - GeminiPromptBuilder.swift (~180 lines) - Core prompts
  - GeminiChatPrompts.swift (~350 lines) - Chat/intent prompts
  - GeminiPlanPrompts.swift (~280 lines) - Plan prompts
- [x] Build verified successfully

### Sprint 2 Refinements (Complete)
- [x] FAB circular with glassEffect (not buttonStyle, which caused cropping)
- [x] Removed meal type categorization - chronological order only
- [x] EditFoodEntrySheet for editing name, macros, serving size, notes
- [x] All food entries tappable to edit (timeline, calorie sheet, macro sheet)
- [x] Food session grouping - entries with same sessionId grouped together
- [x] "Add to this meal" button to add more items to existing session
- [x] Camera viewfinder delay fixed - keep camera view in hierarchy with opacity toggle
- [x] Structured outputs for food analysis (GeminiService uses JSON schema)
- [x] ChatInputBar redesign:
  - Plus/send buttons with colored backgrounds and white icons
  - Image preview inside text input (like iMessage)
  - PhotosPicker via `.photosPicker(isPresented:)` modifier
  - No background on input bar (floating elements only)
- [x] AI meal logging confirmation flow:
  - AI decides whether to suggest logging based on image content
  - SuggestedMealCard shows meal details with accept/dismiss buttons
  - User must confirm before meal is logged to diary
  - Works for food, but doesn't suggest for gym equipment, body photos, etc.
- [x] ChatInputBar UX improvements:
  - Plus button: always red with glassEffect, white icon
  - Send button: gray glassEffect when disabled, accent when active
  - Buttons vertically centered with text field (HStack alignment: .center)
  - Tap anywhere outside input to dismiss keyboard
  - Image preview tappable to enlarge (fullscreen with pinch-to-zoom, double-tap toggle)
- [x] Text-based meal logging:
  - New `chatStructured` method returns structured output with optional meal suggestions
  - AI can suggest logging meals from text descriptions (e.g., "I had a chicken salad")
  - Current date/time added to prompts for context
  - SuggestedMealCard shown for text-based food mentions too
- [x] AI can modify pending meal suggestions:
  - Pending suggestion context passed to AI in prompts
  - User can say "add more calories" or "make it 600 kcal" to adjust
  - Previous suggestion auto-dismissed when AI provides updated one
- [x] SuggestedMealCard improvements:
  - Two buttons: "Edit" (bordered) and "Log" (green prominent)
  - Edit opens EditMealSuggestionSheet to manually adjust values
  - Log button confirms and saves to diary immediately
- [x] Time-aware meal logging:
  - AI can parse times like "I had lunch at 2pm" and include loggedAtTime in response
  - Schema updated with loggedAtTime field (HH:mm 24-hour format)
  - FoodEntry created with correct loggedAt timestamp
- [x] LoggedMealBadge position fixed - now appears after message content, not before
- [x] Smooth animations for meal suggestions:
  - SuggestedMealCard has scale+opacity transition on appear/disappear
  - LoggedMealBadge animates in when meal is logged
  - Old suggestion animates out when AI provides updated one
- [x] Improved JSON parsing for structured output:
  - Simplified parsing - no regex, just decode directly (structured output is pure JSON)
  - Better error logging with detailed decoding error messages
- [x] Consolidated chat prompts into GeminiPromptBuilder:
  - `buildImageChatPrompt` for image analysis
  - `buildTextChatPrompt` for text chat with optional pending suggestion
  - Consistent format and instructions across both methods

### Gemini 3 API Optimizations (Complete)
- [x] Added `ThinkingLevel` enum (minimal, low, medium) for task-appropriate reasoning
  - `minimal`: Intent classification, general chat
  - `low`: Progress queries, modify suggestion, plan refinement
  - `medium`: Food logging, questions, plan generation, image analysis
- [x] Updated API calls to use `responseJsonSchema` parameter
- [x] Set temperature to 1.0 for Gemini 3
- [x] Added `MEDIA_RESOLUTION_HIGH` for food photo analysis
- [x] Streaming structured output with incremental JSON parsing
  - `extractMessageFromPartialJSON` parses message field as JSON streams
  - Shows message text incrementally, meal card appears when complete

### Chat UX Improvements (Complete)
- [x] Fixed prompts to say "suggest logging" not "I've logged this"
  - AI must not claim to have logged food (user still needs to confirm)
  - Updated image and text chat prompts
- [x] Added emoji field to meal suggestions
  - `emoji` field in SuggestedFoodEntry (☕, 🥗, 🍳, etc.)
  - `displayEmoji` computed property with fallback to 🍽️
  - Added emoji to `SuggestMealLogData` struct in GeminiService parsing
  - SuggestedMealCard header uses food emoji
  - LoggedMealBadge displays food emoji
- [x] Emoji persisted to FoodEntry model and shown in dashboard
  - Added `emoji` field to FoodEntry model
  - `displayEmoji` computed property on FoodEntry
  - DailyFoodTimeline shows emoji instead of fork.knife icon
  - CalorieDetailSheet shows emoji for entries without photos
- [x] Unified emoji support across all food logging flows
  - Added `emoji` field to `FoodAnalysis` struct (camera/photo flow)
  - Updated `foodAnalysisSchema` to include emoji
  - FoodCameraView saves emoji when logging from camera/photo
  - AnalysisResultCard displays emoji next to food name
- [x] Text-only food logging from FAB/camera view
  - Added send button to description field (appears when focused with text)
  - Submits text description for AI analysis without requiring a photo
  - ReviewCaptureView handles text-only mode with distinct UI
  - Input method set to "description" for text-only entries
- [x] LoggedMealBadge is now tappable to view the logged meal
  - Opens EditFoodEntrySheet for the logged food entry
  - Chevron indicator shows it's interactive
  - Shows "Logged {food name}" with emoji instead of generic text
  - Meal data preserved after logging (not cleared)
- [x] Added streaming debug logging to help diagnose streaming issues
- [x] Build verified successfully

### Plan Chat Enhancement (v7) - COMPLETE
- [x] Changed AI icon from sparkles to dumbbell throughout chat UI
- [x] Updated Gemini prompt for conversational style (short, chat-like responses)
- [x] Added "proposePlan" response type - AI proposes plans for user approval
- [x] Mini plan visualization (ProposedPlanCard) shows calories + macros + split bar
- [x] "Accept This Plan" button accepts proposal and dismisses sheet
- [x] Moved "Ask About Your Plan" to floating button (purple, above main button)
- [x] AI encouraged to ask follow-ups before making plan changes
- [x] Build verified successfully

### Plan Chat Integration (v6) - COMPLETE
- [x] Created PlanChatView.swift with chat interface
- [x] Added refinePlan method to GeminiService
- [x] Added buildPlanRefinementPrompt and planRefinementSchema to GeminiPromptBuilder
- [x] Integrated "Ask about your plan" button in PlanReviewStepView
- [x] Sheet presentation for PlanChatView with plan update handling
- [x] Updated OnboardingView to pass planRequest binding
- [x] Build verified successfully

### Gemini Structured Outputs (v5) - COMPLETE
- [x] Updated GeminiService to use `responseMimeType: "application/json"` and `responseSchema`
- [x] Added JSON schema in GeminiPromptBuilder for NutritionPlan structure
- [x] Removed manual JSON format instructions from prompt
- [x] Added ProgressInsights to NutritionPlan model with timeline estimations
- [x] Added progressInsightsCard to PlanReviewStepView displaying:
  - Weekly change estimate (e.g., "-0.5 kg", "+0.2 kg")
  - Time to goal (if target weight provided)
  - Calorie deficit/surplus indicator
  - Short-term milestone (first month)
  - Long-term outlook (3-6 months)
- [x] Fallback plan generator also creates ProgressInsights
- [x] Build verified successfully

### Onboarding UX Polish (v4) - COMPLETE
- [x] Back button moved to top left navigation style
- [x] Floating button has more vertical padding
- [x] Biological sex starts unselected (optional field)
- [x] Birthday uses wheel picker (centered, better UX)
- [x] Activity level scroll conflict fixed (removed DragGesture)
- [x] Added Summary step (step 5) before AI plan generation
- [x] Updated Gemini model to `gemini-3-flash-preview`
- [x] 6-step onboarding: Welcome → Biometrics → Activity → Goals → Summary → Plan Review

### UI Transitions Polish (v3) - COMPLETE
- [x] Fixed jarring transitions with smooth `.asymmetric()` animations
- [x] Gradient background extends under floating button (ZStack layout)
- [x] Each step is a scroll view with floating button overlay
- [x] iOS 26 `.glassProminent` button style

### UI Polish Complete (v2)
- [x] Created OnboardingTheme.swift with shared styles
- [x] Welcome screen with animated hero, gradient text, feature cards
- [x] Biometrics with color-coded cards, unit toggles, gender buttons
- [x] Activity level with visual intensity bars, animated selection
- [x] Goals with 2-column grid, dietary chips, flow layout
- [x] Plan review with confetti celebration, editable macro cards
- [x] Modern progress dots, gradient buttons, smooth spring transitions
- [x] **NEW:** Staggered entrance animations on all steps
- [x] **NEW:** Press/release micro-interactions on all cards/chips
- [x] **NEW:** Haptic feedback on all selections and transitions
- [x] **NEW:** Pulsing/breathing icon animations
- [x] **NEW:** Enhanced loading spinner with gradient ring
- [x] **NEW:** Comprehensive Gemini logging with emoji prefixes

## Open questions (UNCONFIRMED if needed)
- None currently

## Working set (files/ids/commands)

### Dashboard (Sprint 2)
- `Plates/Features/Dashboard/DashboardView.swift` - Main dashboard with FAB and sheet management
- `Plates/Features/Dashboard/DashboardCards.swift` - Tappable CalorieProgressCard, MacroBreakdownCard
- `Plates/Features/Dashboard/DailyFoodTimeline.swift` - Chronological food timeline with tappable entries
- `Plates/Features/Dashboard/LogWeightSheet.swift` - Weight logging with text input
- `Plates/Features/Dashboard/CalorieDetailSheet.swift` - Detailed calorie breakdown with ring
- `Plates/Features/Dashboard/MacroDetailSheet.swift` - Macro breakdown with calorie contribution
- `Plates/Features/Dashboard/FloatingActionButton.swift` - Circular FAB with glassEffect
- `Plates/Features/Dashboard/EditFoodEntrySheet.swift` - Edit macros, notes, serving size for entries

### Food (Sprint 2)
- `Plates/Features/Food/FoodCameraView.swift` - Camera-first food logging with viewfinder

### Onboarding (Sprint 0)
- `Plates/Features/Onboarding/OnboardingView.swift` - Main coordinator (5-step flow) + haptics
- `Plates/Features/Onboarding/OnboardingStepViews.swift` - Welcome step + enhanced animations
- `Plates/Features/Onboarding/BiometricsStepView.swift` - Age, gender, height, weight + staggered animations
- `Plates/Features/Onboarding/ActivityLevelStepView.swift` - 5 activity levels + haptics
- `Plates/Features/Onboarding/GoalsStepView.swift` - Goals + dietary restrictions + haptics
- `Plates/Features/Onboarding/PlanReviewStepView.swift` - AI plan review + enhanced loading

### Utilities
- `Plates/Core/Utilities/HapticManager.swift` - Centralized haptic feedback manager

### Models
- `Plates/Core/Models/UserProfile.swift` - Extended with gender, activity, units, restrictions
- `Plates/Core/Models/NutritionPlan.swift` - AI-generated plan structure

### Services
- `Plates/Core/Services/GeminiService.swift` - Chat with intent routing, classifyIntent, chatWithIntentRouting, streaming support
- `Plates/Core/Services/GeminiPromptBuilder.swift` - Core prompts (food analysis, workout, system, nutrition advice) ~180 lines
- `Plates/Core/Services/GeminiChatPrompts.swift` - Chat prompts (intent classification, intent-specific handlers) ~350 lines
- `Plates/Core/Services/GeminiPlanPrompts.swift` - Plan prompts (generation, refinement) ~280 lines
- `Plates/Core/Services/GeminiIntentRouter.swift` - ChatIntent enum, IntentClassification, EnhancedFitnessContext

### Profile (Sprint 1)
- `Plates/Features/Profile/ProfileView.swift` - Main profile tab with stats, plan, check-in cards
- `Plates/Features/Profile/ProfileEditSheet.swift` - Edit name, height, target weight, activity level
- `Plates/Features/Profile/PlanAdjustmentSheet.swift` - Goal selection + manual macro adjustment + AI Coach
