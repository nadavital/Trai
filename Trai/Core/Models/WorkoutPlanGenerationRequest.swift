//
//  WorkoutPlanGenerationRequest.swift
//  Trai
//
//  Request structure for generating a workout plan with user preferences
//

import Foundation

// MARK: - Plan Generation Request

struct WorkoutPlanGenerationRequest {
    let name: String
    let age: Int
    let gender: UserProfile.Gender
    let goal: UserProfile.GoalType
    let activityLevel: UserProfile.ActivityLevel

    // Core preferences
    let workoutType: WorkoutType              // Primary/derived type
    let selectedWorkoutTypes: [WorkoutType]?  // All types user explicitly selected
    let experienceLevel: ExperienceLevel?
    let equipmentAccess: EquipmentAccess?
    let availableDays: Int?  // nil = flexible/as available
    let timePerWorkout: Int?

    // Conditional/optional preferences
    let preferredSplit: PreferredSplit?
    let cardioTypes: [CardioType]?

    // Custom/Other text inputs
    let customWorkoutType: String?
    let customExperience: String?
    let customEquipment: String?
    let customCardioType: String?

    // Open-ended from conversation
    let specificGoals: [String]?      // "I want to do a pull-up", "visible abs"
    let weakPoints: [String]?         // "shoulders are lagging", "weak core"
    let injuries: String?             // "bad knee", "lower back issues"
    let preferences: String?          // "I love deadlifts", "hate burpees"
    let conversationContext: [String]? // Labeled notes from the intake conversation

    /// Whether cardio should be included in the plan
    var includesCardio: Bool {
        if let types = selectedWorkoutTypes {
            return types.contains(.cardio) || types.contains(.mixed) || types.contains(.hiit)
        }
        return workoutType == .cardio || workoutType == .mixed || workoutType == .hiit
    }

    /// Safe fallback when we need a concrete duration for non-AI defaults.
    var fallbackSessionDuration: Int {
        let bounded = max(20, min(timePerWorkout ?? 45, 120))
        return bounded
    }

    var requestsCardioAsAccessory: Bool {
        guard includesCardio else { return false }
        let text = generationContextText

        let supportivePlacementSignals = [
            "support",
            "supportive",
            "supporting",
            "add-on",
            "addon",
            "warmup",
            "warm-up",
            "cooldown",
            "cool-down",
            "finisher",
            "at the end",
            "at end",
            "after",
            "after strength",
            "after lifting",
            "after one lift",
            "after a lift",
            "after my lift",
            "after my strength",
            "not a full",
            "not standalone",
            "not a dedicated",
            "end of one",
            "end of a strength",
            "end of my strength",
            "finish with",
            "add some"
        ]

        let dedicatedSignals = [
            "cardio leads",
            "cardio the main",
            "dedicated cardio",
            "cardio day",
            "race",
            "5k",
            "10k",
            "half marathon",
            "marathon"
        ]

        let negatedDedicatedSignals = [
            "not a dedicated",
            "not dedicated",
            "no dedicated",
            "without a dedicated",
            "not as a dedicated",
            "not standalone",
            "not a standalone",
            "no standalone"
        ]

        let hasDedicatedSignal = dedicatedSignals.contains { text.contains($0) }
        let negatesDedicatedSignal = negatedDedicatedSignals.contains { text.contains($0) }

        return mentionsCardioLikeTraining(text) &&
            supportivePlacementSignals.contains { text.contains($0) } &&
            (!hasDedicatedSignal || negatesDedicatedSignal)
    }

    var limitsAccessoryCardioToOneSession: Bool {
        guard requestsCardioAsAccessory else { return false }
        let text = generationContextText
        let singlePlacementSignals = [
            "one strength",
            "one workout",
            "one session",
            "one day",
            "one lower",
            "one lower-body",
            "one upper",
            "one upper-body",
            "once",
            "1x",
            "only",
            "just",
            "legs day",
            "leg day",
            "lower day"
        ]
        return singlePlacementSignals.contains { text.contains($0) }
    }

    var supportiveCardioRole: WorkoutPlan.TrainingBlock.Role {
        guard requestsCardioAsAccessory else { return .main }
        let text = generationContextText
        let endPlacementSignals = [
            "finisher",
            "at the end",
            "at end",
            "after strength",
            "after lifting",
            "after one lift",
            "after a lift",
            "after my lift",
            "after my strength",
            "end of one",
            "end of a strength",
            "end of my strength",
            "finish with"
        ]
        return endPlacementSignals.contains { text.contains($0) } ? .finisher : .accessory
    }

    var generationDirectives: [String] {
        var directives: [String] = []

        if let availableDays {
            directives.append("Return exactly \(availableDays) sessions.")
        }

        if requestsCardioAsAccessory {
            directives.append("Primary focus is not standalone cardio; cardio should appear only as a supportive cardio block with role \(supportiveCardioRole.rawValue).")
            directives.append("Dedicated cardio or HIIT templates are not allowed unless the user explicitly asks for them later.")
            directives.append("Use finisher language only if the user explicitly asked for cardio at the end of a workout; otherwise describe supportive cardio by its purpose, such as endurance support, conditioning, intervals, or recovery.")
        }

        if limitsAccessoryCardioToOneSession {
            directives.append("The user limited supportive cardio to one placement. Include exactly one cardio block with role \(supportiveCardioRole.rawValue) in the whole plan, on the requested day when one is named.")
        }

        if let selectedWorkoutTypes, selectedWorkoutTypes.count > 1 {
            directives.append("Selected training styles are inputs, not equal session allocations. Use the personalization brief to decide priority and placement.")
            directives.append("Every explicitly selected training style must remain visible in the returned plan as a dedicated template or meaningful block unless the personalization brief explicitly says that style should only be background support or avoided.")
        }

        if let cardioTypes, cardioTypes.contains(.climbing) {
            directives.append("Climbing was explicitly selected. Include climbing or bouldering as a real session or meaningful skill/sport block with activityTypeName such as Climbing or Bouldering unless the personalization brief explicitly says climbing should only be supportive grip work. Do not reduce the climbing selection to generic grip exercises alone.")
        }

        if let customWorkoutType,
           !customWorkoutType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            directives.append("The custom focus must be preserved as user-facing activity identity in template focusAreas, block activityTypeName, block activityTags, or goal linkedActivityTags when relevant.")
        }

        if let preferredSplit, preferredSplit != .letTraiDecide {
            directives.append("Use the requested split direction unless it conflicts with a higher-priority personalization answer.")
        }

        return directives
    }

    var requiredVisibleActivityIdentityGroups: [[String]] {
        var groups: [[String]] = []

        func appendGroup(_ values: [String]) {
            let cleaned = values
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty && $0.goalNormalizedKey != WorkoutPlanGenerationRequest.CardioType.anyCardio.displayName.goalNormalizedKey }
            guard !cleaned.isEmpty else { return }
            let keys = Set(cleaned.map(\.goalNormalizedKey))
            guard !groups.contains(where: { Set($0.map(\.goalNormalizedKey)) == keys }) else { return }
            groups.append(cleaned)
        }

        for type in selectedWorkoutTypes ?? [workoutType] {
            if let aliases = type.requiredVisibleIdentityAliases {
                appendGroup(aliases)
            }
        }

        cardioTypes?.forEach { type in
            guard type != .anyCardio else { return }
            appendGroup(type.visibleIdentityAliases)
        }

        if let customWorkoutType {
            appendGroup([customWorkoutType])
        }

        if let customCardioType {
            appendGroup([customCardioType])
        }

        return groups
    }

    func missingVisibleActivityIdentityDescriptions(in plan: WorkoutPlan) -> [String] {
        requiredVisibleActivityIdentityGroups.compactMap { aliases in
            plan.containsVisibleActivityIdentity(matching: aliases) ? nil : aliases.first
        }
    }

    private var generationContextText: String {
        ([
            preferences ?? "",
            injuries ?? "",
            customWorkoutType ?? "",
            customCardioType ?? ""
        ] + (specificGoals ?? []) + (conversationContext ?? []))
        .joined(separator: " ")
        .lowercased()
    }

    private func mentionsCardioLikeTraining(_ text: String) -> Bool {
        var terms = [
            "cardio",
            "conditioning",
            "endurance",
            "aerobic",
            "run",
            "running",
            "bike",
            "cycling",
            "row",
            "rowing",
            "swim",
            "swimming",
            "walk",
            "walking",
            "hike",
            "hiking",
            "intervals"
        ]

        if let cardioTypes {
            terms.append(contentsOf: cardioTypes.map { $0.displayName.lowercased() })
        }

        if let customCardioType {
            terms.append(customCardioType.lowercased())
        }

        return terms.contains { term in
            let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
            return !trimmed.isEmpty && text.contains(trimmed)
        }
    }

    // MARK: - Workout Type

    enum WorkoutType: String, CaseIterable, Identifiable, Codable {
        case strength = "strength"
        case cardio = "cardio"
        case hiit = "hiit"
        case flexibility = "flexibility"
        case mixed = "mixed"

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .strength: "Strength Training"
            case .cardio: "Cardio & Endurance"
            case .hiit: "HIIT & Conditioning"
            case .flexibility: "Yoga & Flexibility"
            case .mixed: "Mixed / Varied"
            }
        }

        var description: String {
            switch self {
            case .strength: "Build muscle and get stronger with weights"
            case .cardio: "Improve endurance with running, cycling, etc."
            case .hiit: "High-intensity intervals for fat loss and conditioning"
            case .flexibility: "Improve mobility and reduce stress"
            case .mixed: "A balanced mix of different training styles"
            }
        }

        var iconName: String {
            switch self {
            case .strength: "dumbbell.fill"
            case .cardio: "figure.run"
            case .hiit: "bolt.fill"
            case .flexibility: "figure.yoga"
            case .mixed: "square.grid.2x2"
            }
        }

        var shouldAskAboutSplit: Bool {
            self == .strength || self == .mixed
        }

        var shouldAskAboutCardioType: Bool {
            self == .cardio || self == .mixed
        }

        var requiredVisibleIdentityAliases: [String]? {
            switch self {
            case .hiit:
                return ["HIIT", "Conditioning", "Intervals"]
            case .flexibility:
                return ["Flexibility", "Mobility", "Yoga"]
            case .strength, .cardio, .mixed:
                return nil
            }
        }
    }

    // MARK: - Preferred Split

    enum PreferredSplit: String, CaseIterable, Identifiable, Codable {
        case pushPullLegs = "pushPullLegs"
        case upperLower = "upperLower"
        case fullBody = "fullBody"
        case broSplit = "broSplit"
        case letTraiDecide = "letTraiDecide"

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .pushPullLegs: "Push/Pull/Legs"
            case .upperLower: "Upper/Lower"
            case .fullBody: "Full Body"
            case .broSplit: "Body Part Split"
            case .letTraiDecide: "Let Trai Decide"
            }
        }

        var description: String {
            switch self {
            case .pushPullLegs: "Push muscles one day, pull the next, then legs"
            case .upperLower: "Alternate between upper and lower body"
            case .fullBody: "Train your whole body each session"
            case .broSplit: "One muscle group per day (chest day, back day, etc.)"
            case .letTraiDecide: "Trai will pick the best split for you"
            }
        }

        var iconName: String {
            switch self {
            case .pushPullLegs: "arrow.left.arrow.right"
            case .upperLower: "arrow.up.arrow.down"
            case .fullBody: "figure.strengthtraining.traditional"
            case .broSplit: "rectangle.split.3x1"
            case .letTraiDecide: "sparkles"
            }
        }
    }

    // MARK: - Cardio Type

    enum CardioType: String, CaseIterable, Identifiable, Codable {
        case running = "running"
        case cycling = "cycling"
        case swimming = "swimming"
        case climbing = "climbing"
        case rowing = "rowing"
        case walking = "walking"
        case stairClimber = "stairClimber"
        case elliptical = "elliptical"
        case jumpRope = "jumpRope"
        case anyCardio = "anyCardio"

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .running: "Running"
            case .cycling: "Cycling"
            case .swimming: "Swimming"
            case .climbing: "Climbing"
            case .rowing: "Rowing"
            case .walking: "Walking"
            case .stairClimber: "Stair Climber"
            case .elliptical: "Elliptical"
            case .jumpRope: "Jump Rope"
            case .anyCardio: "Any / No Preference"
            }
        }

        var iconName: String {
            switch self {
            case .running: "figure.run"
            case .cycling: "figure.outdoor.cycle"
            case .swimming: "figure.pool.swim"
            case .climbing: "figure.climbing"
            case .rowing: "figure.rower"
            case .walking: "figure.walk"
            case .stairClimber: "figure.stair.stepper"
            case .elliptical: "figure.elliptical"
            case .jumpRope: "figure.jumprope"
            case .anyCardio: "heart.fill"
            }
        }

        var visibleIdentityAliases: [String] {
            switch self {
            case .running:
                return ["Running", "Run"]
            case .cycling:
                return ["Cycling", "Bike", "Biking"]
            case .swimming:
                return ["Swimming", "Swim"]
            case .climbing:
                return ["Climbing", "Bouldering", "Climb"]
            case .rowing:
                return ["Rowing", "Rower"]
            case .walking:
                return ["Walking", "Walk"]
            case .stairClimber:
                return ["Stair Climber", "Stairs"]
            case .elliptical:
                return ["Elliptical"]
            case .jumpRope:
                return ["Jump Rope", "Skipping"]
            case .anyCardio:
                return []
            }
        }
    }

    // MARK: - Equipment Access

    enum EquipmentAccess: String, CaseIterable, Identifiable {
        case fullGym = "fullGym"
        case homeAdvanced = "homeAdvanced"
        case homeBasic = "homeBasic"
        case bodyweightOnly = "bodyweightOnly"

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .fullGym: "Full Gym"
            case .homeAdvanced: "Home Gym"
            case .homeBasic: "Dumbbells/Bands"
            case .bodyweightOnly: "Bodyweight Only"
            }
        }

        var description: String {
            switch self {
            case .fullGym: "Access to all machines, barbells, dumbbells, cables"
            case .homeAdvanced: "Barbell, dumbbells, bench, pull-up bar"
            case .homeBasic: "Dumbbells and resistance bands"
            case .bodyweightOnly: "No equipment needed"
            }
        }

        var iconName: String {
            switch self {
            case .fullGym: "building.2"
            case .homeAdvanced: "dumbbell.fill"
            case .homeBasic: "figure.strengthtraining.functional"
            case .bodyweightOnly: "figure.walk"
            }
        }
    }

    // MARK: - Experience Level

    enum ExperienceLevel: String, CaseIterable, Identifiable {
        case beginner = "beginner"
        case intermediate = "intermediate"
        case advanced = "advanced"

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .beginner: "Beginner"
            case .intermediate: "Intermediate"
            case .advanced: "Advanced"
            }
        }

        var description: String {
            switch self {
            case .beginner: "New to strength training or less than 6 months experience"
            case .intermediate: "6 months to 2 years of consistent training"
            case .advanced: "2+ years of serious training with good technique"
            }
        }

        var iconName: String {
            switch self {
            case .beginner: "1.circle.fill"
            case .intermediate: "2.circle.fill"
            case .advanced: "3.circle.fill"
            }
        }
    }

    // MARK: - Recommended Split

    /// Recommend a split type based on preferences, available days and experience
    var recommendedSplit: WorkoutPlan.SplitType {
        switch workoutType {
        case .cardio, .hiit, .flexibility:
            return .custom
        case .mixed:
            if includesCardio {
                return .custom
            }
        case .strength:
            break
        }

        // If user chose a specific split, use it
        if let preferred = preferredSplit, preferred != .letTraiDecide {
            switch preferred {
            case .pushPullLegs: return .pushPullLegs
            case .upperLower: return .upperLower
            case .fullBody: return .fullBody
            case .broSplit: return .bodyPartSplit
            case .letTraiDecide: break
            }
        }

        // Otherwise recommend based on days and experience
        switch availableDays {
        case 2:
            return .fullBody
        case 3:
            return experienceLevel == .beginner ? .fullBody : .pushPullLegs
        case 4:
            return .upperLower
        case 5, 6:
            return experienceLevel == .advanced ? .bodyPartSplit : .pushPullLegs
        default:
            return .fullBody
        }
    }
}
