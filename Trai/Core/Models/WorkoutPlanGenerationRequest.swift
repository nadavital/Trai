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
    let cardioSupportConstraint: CardioSupportConstraint?

    init(
        name: String,
        age: Int,
        gender: UserProfile.Gender,
        goal: UserProfile.GoalType,
        activityLevel: UserProfile.ActivityLevel,
        workoutType: WorkoutType,
        selectedWorkoutTypes: [WorkoutType]? = nil,
        experienceLevel: ExperienceLevel? = nil,
        equipmentAccess: EquipmentAccess? = nil,
        availableDays: Int? = nil,
        timePerWorkout: Int? = nil,
        preferredSplit: PreferredSplit? = nil,
        cardioTypes: [CardioType]? = nil,
        customWorkoutType: String? = nil,
        customExperience: String? = nil,
        customEquipment: String? = nil,
        customCardioType: String? = nil,
        specificGoals: [String]? = nil,
        weakPoints: [String]? = nil,
        injuries: String? = nil,
        preferences: String? = nil,
        conversationContext: [String]? = nil,
        cardioSupportConstraint: CardioSupportConstraint? = nil
    ) {
        self.name = name
        self.age = age
        self.gender = gender
        self.goal = goal
        self.activityLevel = activityLevel
        self.workoutType = workoutType
        self.selectedWorkoutTypes = selectedWorkoutTypes
        self.experienceLevel = experienceLevel
        self.equipmentAccess = equipmentAccess
        self.availableDays = availableDays
        self.timePerWorkout = timePerWorkout
        self.preferredSplit = preferredSplit
        self.cardioTypes = cardioTypes
        self.customWorkoutType = customWorkoutType
        self.customExperience = customExperience
        self.customEquipment = customEquipment
        self.customCardioType = customCardioType
        self.specificGoals = specificGoals
        self.weakPoints = weakPoints
        self.injuries = injuries
        self.preferences = preferences
        self.conversationContext = conversationContext
        self.cardioSupportConstraint = cardioSupportConstraint
    }

    /// Whether cardio should be included in the plan
    var includesCardio: Bool {
        if let types = selectedWorkoutTypes {
            return types.contains(.cardio) || types.contains(.mixed) || types.contains(.hiit)
        }
        if let cardioTypes, !cardioTypes.isEmpty {
            return true
        }
        if customWorkoutType?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            return false
        }
        return workoutType == .cardio || workoutType == .mixed || workoutType == .hiit
    }

    /// Safe fallback when we need a concrete duration for non-AI defaults.
    var fallbackSessionDuration: Int {
        let bounded = max(20, min(timePerWorkout ?? 45, 120))
        return bounded
    }

    var requestsCardioAsAccessory: Bool {
        includesCardio && cardioSupportConstraint != nil
    }

    var requiresGenericCardioStructure: Bool {
        guard includesCardio else { return false }
        let selectedOnlyGenericCardio = (cardioTypes ?? []).isEmpty
            || (cardioTypes ?? []).contains(.anyCardio)
        return selectedOnlyGenericCardio
    }

    var limitsAccessoryCardioToOneSession: Bool {
        guard let maximumPlacements = cardioSupportConstraint?.maximumPlacements else { return false }
        return maximumPlacements == 1
    }

    var supportiveCardioRole: WorkoutPlan.TrainingBlock.Role {
        cardioSupportConstraint?.role ?? .main
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

        let explicitActivityIdentities = requiredVisibleActivityIdentityGroups
            .compactMap(\.first)
        if !explicitActivityIdentities.isEmpty {
            directives.append("Preserve explicit activity identities: \(explicitActivityIdentities.joined(separator: ", ")). Each one should appear as a real template, meaningful block, block activityTypeName, block activityTags, focusArea, exercise/activity name, or goal scope unless the personalization brief explicitly says that activity should only be supportive or avoided.")
            directives.append("Do not replace a specific selected activity with only generic support work. For example, preserve the named activity itself instead of reducing it to generic strength accessories, conditioning, mobility, or grip work.")
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
            customWorkoutType
                .components(separatedBy: CharacterSet(charactersIn: ",•\n"))
                .forEach { appendGroup([$0]) }
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

    // MARK: - Workout Type

    struct CardioSupportConstraint {
        let role: WorkoutPlan.TrainingBlock.Role
        let maximumPlacements: Int?

        init(role: WorkoutPlan.TrainingBlock.Role, maximumPlacements: Int? = nil) {
            self.role = role
            self.maximumPlacements = maximumPlacements
        }
    }

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

    enum EquipmentAccess: String, Codable, CaseIterable, Identifiable {
        case fullGym = "fullGym"
        case homeAdvanced = "homeAdvanced"
        case homeBasic = "homeBasic"
        case bodyweightOnly = "bodyweightOnly"

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .fullGym: "Full Gym"
            case .homeAdvanced: "Barbell Setup"
            case .homeBasic: "Dumbbells/Bands"
            case .bodyweightOnly: "Bodyweight Only"
            }
        }

        var description: String {
            switch self {
            case .fullGym: "Access to all machines, barbells, dumbbells, cables"
            case .homeAdvanced: "Rack, barbell, bench, pull-up bar"
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

    enum ExperienceLevel: String, Codable, CaseIterable, Identifiable {
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
