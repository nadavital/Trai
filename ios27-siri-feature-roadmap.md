# Trai iOS 27 and Siri AI Feature Roadmap

Research date: July 14, 2026

Branch: `codex/ios27-siri-integration`

Base: `origin/main` at `38179a5ffb11feb3e04453c1f0edc78b8d7b06d3`

## Objective

Adopt iOS 27 features that materially improve Trai while keeping the current iOS 26 app behavior intact. New APIs should be introduced behind availability checks and narrow adapters rather than by replacing proven flows wholesale.

## What Trai already has

Trai already exposes five App Shortcuts: text food logging, camera food logging, weight logging, Ask Trai, and workout start. `WorkoutNameEntity` and `WorkoutNameQuery` provide an initial App Entity implementation. The app also already has an agent/tool system, a backend AI provider, HealthKit workout data, widgets, and a workout Live Activity.

The opportunity is to turn these isolated integrations into a coherent system model that Siri and Apple Intelligence can understand and test.

## Recommended feature priorities

### 1. Siri-native Trai entities and actions

Priority: highest

Create stable, privacy-conscious App Entities for:

- Workout templates and active workouts.
- Completed workout summaries.
- Food-log summaries, not raw private meal history by default.
- Nutrition progress for the current day.
- Custom reminders.

Use stable identifiers and adopt `SyncableEntity` only for entities whose IDs remain valid across devices. Add `IndexedEntity` selectively so Spotlight and Siri can resolve workout templates, saved exercises, and user-created reminders. Avoid indexing free-form coach memories or detailed health data.

Candidate Siri experiences:

- “Start my push workout in Trai.”
- “How many calories do I have left today in Trai?”
- “What was my last workout?”
- “Log 180 pounds in Trai.”
- “Open my upper-body workout plan.”
- “Ask Trai whether I hit my protein goal.”

Use schema-backed intents where an Apple App Schema genuinely matches the action. Do not force health or nutrition actions into unrelated schema domains. Keep existing shortcuts intact when adding schema-specific replacements so saved user shortcuts do not break.

Add:

- Structured `DisplayRepresentation` values and snippet views.
- Concise full and supporting Siri dialog variants.
- Clarifying questions for incomplete values such as an ambiguous workout.
- Confirmations for destructive actions such as canceling an active workout.
- Explicit `allowedExecutionTargets` so read-only queries can run in an extension while SwiftData writes run in the main app.

### 2. Onscreen awareness and interaction donations

Priority: high

Annotate the current workout, workout plan, food review, and daily-summary screens with the App Entity they represent. This allows Siri to understand references like “this workout” or “this meal” while the content is visible.

Donate meaningful UI actions that the system cannot observe automatically:

- Starting a particular workout template.
- Repeating a recent breakfast.
- Completing a custom reminder.
- Opening a frequently used plan or goal.

Donation should be sparse and accurate. Do not donate passive screen views or every set edit.

### 3. AppIntentsTesting as the Siri compatibility suite

Priority: high

Add iOS 27 out-of-process tests for all Trai intents and entity queries. The new framework executes through the same infrastructure used by Siri, Shortcuts, and Spotlight without depending on Siri UI automation.

Minimum test matrix:

- Resolve a workout by natural-language name and start it.
- Handle an ambiguous or missing workout.
- Log food and weight exactly once.
- Reject writes when authentication, subscription, or storage is unavailable.
- Verify Spotlight indexing and removal.
- Verify the entity annotation shown on workout and food-detail screens.
- Chain intents the way a Shortcut would.
- Confirm main-app versus extension execution targets.

### 4. HealthKit workout zones

Priority: high

iOS 27 adds first-class heart-rate and cycling-power workout zones. This is a direct fit for Trai’s existing live heart-rate and workout-summary surfaces.

Feature slice:

- Request and read the person’s preferred heart-rate zone configuration.
- Show the current zone alongside live heart rate.
- Add optional target-zone guidance to relevant cardio or interval workouts.
- Display time-in-zone after a completed workout.
- Feed zone distribution into recovery and effort insights.

Keep the existing anchored-query stream as the iOS 26 fallback. Treat zone coaching as guidance, not a medical claim, and avoid noisy haptics when the heart rate briefly crosses a boundary.

### 5. Foundation Models provider abstraction

Priority: medium-high, prototype before migration

iOS 27’s `LanguageModel` and `LanguageModelExecutor` protocols allow Apple on-device models, Private Cloud Compute, Core AI, MLX, and third-party providers to share `LanguageModelSession` infrastructure.

Trai should prototype a `TraiLanguageModel` adapter around its existing authenticated backend rather than immediately replacing `AIService`. The prototype should prove that Trai’s current tool declarations, streaming, structured output, quota handling, and error metadata can cross the Foundation Models executor boundary.

Potential routing policy:

- On-device model: classification, rewriting, extraction, compact summaries, and privacy-sensitive local transformations.
- Existing Trai backend/provider: current coaching and tool-driven workflows.
- Private Cloud Compute: optional high-complexity reasoning where eligibility and product economics fit.
- Dynamic Profiles: swap instructions, tools, and models between nutrition, workout planning, reminder drafting, and general coaching while preserving a continuous session.

Do not silently move health or account context between providers. Show a clear privacy boundary and keep server authentication behind token providers or the existing backend session, never an embedded API key.

### 6. Evaluations and agent instrumentation

Priority: medium-high

Adopt Apple’s Evaluations framework alongside the existing Trai evals rather than replacing them. Use it for:

- Tool-call trajectory expectations.
- Prompt/model comparisons across the iOS 26 and iOS 27 system models.
- Synthetic edge cases for ambiguous foods, workout edits, and incomplete reminders.
- Regression gates for unsupported claims and unsafe write actions.

Use the Foundation Models Instruments template to measure time-to-first-token, token use, tool loops, and model handoffs. Preserve Trai’s existing product metrics so Apple framework results can be compared with production behavior.

### 7. Visual Intelligence food handoff

Priority: experimental

Visual Intelligence can send image-derived values to an app’s `IntentValueQuery` and display matching app entities. Trai could use this to surface recognized saved foods, recent meals, or known food memories, then deep-link into the existing review flow.

This should initially search Trai-owned content rather than promise general nutrition recognition. A useful first version is: point at a familiar meal, see a recent matching Trai meal, and continue through the existing editable food-review screen.

### 8. Additional iOS 27 platform improvements

Priority: opportunistic

- Use the new `MetricManager` async sequences and state-contextualized metrics to compare launch, chat, camera, and live-workout performance.
- Consider the landscape Dynamic Island presentation for the workout Live Activity.
- Use pinned and overflow toolbar APIs where workout or memory actions compete for limited space.
- Add native reorder support to ScrollView-based exercise cards while keeping iOS 26 controls available.
- Use item-bound alert and confirmation-dialog APIs where one optional item already represents presentation state.

## Delivery plan

### Phase A: preservation and test foundation

1. Keep deployment target at iOS 26.
2. Establish clean iOS 26 and iOS 27 build/runtime baselines.
3. Add AppIntentsTesting coverage for the five existing shortcuts.
4. Complete the previously identified storage, queue, and cancellation stability fixes.

### Phase B: Siri entity graph

1. Introduce reusable entity adapters and queries.
2. Add Spotlight indexing only for approved non-sensitive entity fields.
3. Add onscreen annotations and interaction donations.
4. Improve dialogs, snippets, confirmations, and execution targets.

### Phase C: workout intelligence

1. Add HealthKit workout-zone adapters with iOS 26 fallbacks.
2. Add live zone display and post-workout summaries.
3. Add optional, low-noise target-zone coaching.

### Phase D: model abstraction experiment

1. Build the Trai `LanguageModel` adapter behind an internal feature flag.
2. Run the same eval dataset through the existing path and the adapter.
3. Prototype one local task and one Dynamic Profile flow.
4. Decide whether to migrate shared chat infrastructure only after parity is measured.

### Phase E: exploratory system surfaces

1. Prototype Visual Intelligence matching against saved meals.
2. Evaluate landscape Live Activity improvements.
3. Adopt iOS 27 SwiftUI conveniences only where they improve a proven flow.

## Compatibility rules

- Every iOS 27 API needs an iOS 26 fallback or an isolated iOS 27-only surface.
- Do not change existing App Intent identifiers or parameter shapes without a migration path.
- Do not expose health, nutrition, memory, or conversation content to Spotlight by default.
- Destructive Siri actions require explicit confirmation and a verified persistence result.
- AI provider changes stay behind an adapter and feature flag until eval parity is demonstrated.
- Beta APIs and behavior must be revalidated against the final Xcode 27 and iOS 27 releases.

## Official Apple research

- [WWDC26 iOS guide](https://developer.apple.com/wwdc26/guides/ios/)
- [Build intelligent Siri experiences with App Schemas](https://developer.apple.com/videos/play/wwdc2026/240/)
- [Explore advanced App Intents features for Siri and Apple Intelligence](https://developer.apple.com/videos/play/wwdc2026/343/)
- [Discover new capabilities in the App Intents framework](https://developer.apple.com/videos/play/wwdc2026/345/)
- [Validate your App Intents adoption with AppIntentsTesting](https://developer.apple.com/videos/play/wwdc2026/295/)
- [App Intents updates](https://developer.apple.com/documentation/updates/appintents)
- [Foundation Models updates](https://developer.apple.com/documentation/updates/foundationmodels)
- [Build agentic app experiences with the Foundation Models framework](https://developer.apple.com/videos/play/wwdc2026/242/)
- [Bring an LLM provider to the Foundation Models framework](https://developer.apple.com/videos/play/wwdc2026/339/)
- [Create robust evaluations for agentic apps](https://developer.apple.com/videos/play/wwdc2026/299/)
- [HealthKit updates](https://developer.apple.com/documentation/updates/healthkit)
- [Deliver workout insights with HealthKit workout zones](https://developer.apple.com/videos/play/wwdc2026/207/)
- [Best practices for integrating visual intelligence in your app](https://developer.apple.com/videos/play/wwdc2026/297/)
- [MetricKit updates](https://developer.apple.com/documentation/updates/metrickit)
