//
//  WorkoutPlanChatMessage.swift
//  Trai
//
//  Message model for the unified workout plan chat flow
//

import Foundation

// MARK: - Chat Message

/// A message in the workout plan conversation
struct WorkoutPlanFlowMessage: Identifiable {
    let id: UUID
    let type: MessageType
    let timestamp: Date

    init(type: MessageType) {
        self.id = UUID()
        self.type = type
        self.timestamp = Date()
    }

    enum MessageType {
        /// Trai asks a question with suggestion chips
        case question(TraiQuestionConfig)

        /// User's answer (from chips or typed)
        case userAnswer([String])

        /// Trai is thinking/generating
        case thinking(String)

        /// Generated plan proposal with accept/customize options
        case planProposal(WorkoutPlan, String)

        /// Plan was accepted
        case planAccepted

        /// Regular chat message from Trai
        case traiMessage(String)

        /// Plan was updated after refinement
        case planUpdated(WorkoutPlan)

        /// Error message
        case error(String)
    }
}

// MARK: - Workout Questions

/// All the questions Trai asks during workout plan creation
enum WorkoutPlanQuestion: String, CaseIterable {
    case workoutType
    case experience
    case equipment
    case schedule
    case split       // Conditional: only for strength/mixed
    case cardio      // Conditional: only for cardio/mixed/hiit
    case goals
    case weakPoints
    case injuries
    case preferences

    var config: TraiQuestionConfig {
        switch self {
        case .workoutType:
            return TraiQuestionConfig(
                id: rawValue,
                question: "What type of training are you into?",
                suggestions: [
                    TraiSuggestion("Strength", subtitle: "Build muscle with weights"),
                    TraiSuggestion("Cardio", subtitle: "Running, cycling, swimming"),
                    TraiSuggestion("HIIT", subtitle: "High-intensity intervals"),
                    TraiSuggestion("Flexibility", subtitle: "Stretching and mobility"),
                    TraiSuggestion("Mixed", subtitle: "A bit of everything")
                ],
                selectionMode: .multiple,
                placeholder: "Or describe your preferred style..."
            )

        case .experience:
            return TraiQuestionConfig(
                id: rawValue,
                question: "How would you describe your experience level?",
                suggestions: [
                    TraiSuggestion("Beginner", subtitle: "New to working out"),
                    TraiSuggestion("Intermediate", subtitle: "1-3 years of training"),
                    TraiSuggestion("Advanced", subtitle: "3+ years, solid form")
                ],
                selectionMode: .single,
                placeholder: "Or tell me more about your background..."
            )

        case .equipment:
            return TraiQuestionConfig(
                id: rawValue,
                question: "What equipment do you have access to?",
                suggestions: [
                    TraiSuggestion("Full Gym", subtitle: "Machines, cables, free weights"),
                    TraiSuggestion("Home - Dumbbells", subtitle: "Basic dumbbells and bench"),
                    TraiSuggestion("Home - Full Setup", subtitle: "Rack, barbell, weights"),
                    TraiSuggestion("Bodyweight Only", subtitle: "No equipment needed")
                ],
                selectionMode: .single,
                placeholder: "Or describe what you have..."
            )

        case .schedule:
            return TraiQuestionConfig(
                id: rawValue,
                question: "How many days per week can you train?",
                suggestions: [
                    TraiSuggestion("2 days"),
                    TraiSuggestion("3 days"),
                    TraiSuggestion("4 days"),
                    TraiSuggestion("5 days"),
                    TraiSuggestion("6 days"),
                    TraiSuggestion("Flexible")
                ],
                selectionMode: .single,
                placeholder: "Or tell me about your schedule..."
            )

        case .split:
            return TraiQuestionConfig(
                id: rawValue,
                question: "Do you have a preferred training split?",
                suggestions: [
                    TraiSuggestion("Push/Pull/Legs", subtitle: "6 days: chest+shoulders, back+biceps, legs"),
                    TraiSuggestion("Upper/Lower", subtitle: "4 days: alternate upper and lower body"),
                    TraiSuggestion("Full Body", subtitle: "2-3 days: hit everything each session"),
                    TraiSuggestion("Bro Split", subtitle: "5 days: one muscle group per day"),
                    TraiSuggestion("Let Trai decide", subtitle: "I'll pick the best split for you", isSkip: true)
                ],
                selectionMode: .single,
                placeholder: "Or describe your ideal split..."
            )

        case .cardio:
            return TraiQuestionConfig(
                id: rawValue,
                question: "What type of cardio do you enjoy?",
                suggestions: [
                    TraiSuggestion("Running"),
                    TraiSuggestion("Cycling"),
                    TraiSuggestion("Swimming"),
                    TraiSuggestion("Rowing"),
                    TraiSuggestion("Jump Rope"),
                    TraiSuggestion("Anything works", isSkip: true)
                ],
                selectionMode: .multiple,
                placeholder: "Or tell me what you like..."
            )

        case .goals:
            return TraiQuestionConfig(
                id: rawValue,
                question: "Do you have any specific fitness goals?",
                suggestions: goalSuggestions,
                selectionMode: .multiple,
                placeholder: "Type your goal...",
                skipText: "No specific goal"
            )

        case .weakPoints:
            return TraiQuestionConfig(
                id: rawValue,
                question: "Any areas you feel are weak or want to focus on?",
                suggestions: weakPointSuggestions,
                selectionMode: .multiple,
                placeholder: "Type a focus area...",
                skipText: "Nothing specific"
            )

        case .injuries:
            return TraiQuestionConfig(
                id: rawValue,
                question: "Any injuries or limitations I should know about?",
                suggestions: [
                    TraiSuggestion("Bad knee"),
                    TraiSuggestion("Lower back issues"),
                    TraiSuggestion("Shoulder problem"),
                    TraiSuggestion("Wrist pain"),
                    TraiSuggestion("No injuries", isSkip: true)
                ],
                selectionMode: .single,
                placeholder: "Describe any limitations..."
            )

        case .preferences:
            return TraiQuestionConfig(
                id: rawValue,
                question: "Anything else? Exercises you love or hate?",
                suggestions: preferenceSuggestions,
                selectionMode: .multiple,
                placeholder: "Tell me what you enjoy or want to avoid...",
                skipText: "No preference"
            )
        }
    }

    // Dynamic suggestions based on workout type
    private var goalSuggestions: [TraiSuggestion] {
        [
            TraiSuggestion("Do a pull-up"),
            TraiSuggestion("Bench my bodyweight"),
            TraiSuggestion("See my abs"),
            TraiSuggestion("Get stronger overall"),
            TraiSuggestion("Build muscle"),
            TraiSuggestion("Improve endurance"),
            TraiSuggestion("No specific goal", isSkip: true)
        ]
    }

    private var weakPointSuggestions: [TraiSuggestion] {
        [
            TraiSuggestion("Weak shoulders"),
            TraiSuggestion("Small arms"),
            TraiSuggestion("Lagging legs"),
            TraiSuggestion("Weak core"),
            TraiSuggestion("Poor posture"),
            TraiSuggestion("Low endurance"),
            TraiSuggestion("Nothing specific", isSkip: true)
        ]
    }

    private var preferenceSuggestions: [TraiSuggestion] {
        [
            TraiSuggestion("Love deadlifts"),
            TraiSuggestion("Hate leg day"),
            TraiSuggestion("Prefer dumbbells"),
            TraiSuggestion("Love compound lifts"),
            TraiSuggestion("No preference", isSkip: true)
        ]
    }

    /// Whether this question should be shown based on user's previous answers
    func shouldShow(given answers: TraiCollectedAnswers) -> Bool {
        switch self {
        case .split:
            // Only show split question for strength/mixed training
            let workoutTypes = answers.answers(for: WorkoutPlanQuestion.workoutType.rawValue)
            return workoutTypes.contains("Strength") || workoutTypes.contains("Mixed")

        case .cardio:
            // Only show cardio question for cardio/mixed/hiit
            let workoutTypes = answers.answers(for: WorkoutPlanQuestion.workoutType.rawValue)
            return workoutTypes.contains("Cardio") ||
                   workoutTypes.contains("Mixed") ||
                   workoutTypes.contains("HIIT")

        default:
            return true
        }
    }
}

// MARK: - Chat Message for Refinement

/// Simple message type for workout plan refinement conversations
struct WorkoutPlanChatMessage {
    enum Role {
        case user
        case assistant
    }

    let role: Role
    let content: String

    init(role: Role, content: String) {
        self.role = role
        self.content = content
    }
}

// MARK: - Session Duration Config

/// Configuration for session duration question (separate from main questions)
struct SessionDurationConfig {
    static let question = TraiQuestionConfig(
        id: "sessionDuration",
        question: "How long do you want each workout to be?",
        suggestions: [
            TraiSuggestion("30 min"),
            TraiSuggestion("45 min"),
            TraiSuggestion("60 min"),
            TraiSuggestion("90 min")
        ],
        selectionMode: .single,
        placeholder: "Or specify a duration..."
    )
}
