//
//  CoachMemory.swift
//  Trai
//
//  AI coach memory system - stores facts and preferences about the user
//

import Foundation
import SwiftData

/// Category for coach memories
enum MemoryCategory: String, Codable, CaseIterable {
    case preference = "preference"       // "Likes chicken", "Prefers morning workouts"
    case restriction = "restriction"     // "Allergic to peanuts", "Can't do squats"
    case habit = "habit"                 // "Usually skips breakfast", "Works out 3x/week"
    case goal = "goal"                   // "Training for marathon", "Wants to hit 180lbs"
    case context = "context"             // "Works night shifts", "Has a home gym"
    case feedback = "feedback"           // "Found portion sizes too large"

    var displayName: String {
        switch self {
        case .preference: return "Preference"
        case .restriction: return "Restriction"
        case .habit: return "Habit"
        case .goal: return "Goal"
        case .context: return "Context"
        case .feedback: return "Feedback"
        }
    }

    var icon: String {
        switch self {
        case .preference: return "heart.fill"
        case .restriction: return "xmark.circle.fill"
        case .habit: return "repeat"
        case .goal: return "target"
        case .context: return "person.fill"
        case .feedback: return "quote.bubble.fill"
        }
    }
}

/// Topic area for coach memories
enum MemoryTopic: String, Codable, CaseIterable, Identifiable {
    case food = "food"
    case workout = "workout"
    case schedule = "schedule"
    case general = "general"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .food: return "Food & Nutrition"
        case .workout: return "Workouts"
        case .schedule: return "Schedule"
        case .general: return "General"
        }
    }
}

/// Persistent memory stored by the AI coach
@Model
final class CoachMemory {
    var id: UUID = UUID()

    /// The memory content (e.g., "User doesn't like fish", "Prefers high-protein breakfast")
    var content: String = ""

    /// Category of memory (preference, restriction, habit, etc.)
    var categoryRaw: String = MemoryCategory.preference.rawValue

    /// Topic area (food, workout, schedule, general)
    var topicRaw: String = MemoryTopic.general.rawValue

    /// When the memory was created
    var createdAt: Date = Date()

    /// Where the memory came from (chat, check-in, onboarding)
    var source: String = "chat"

    /// Whether this memory is still active/relevant
    var isActive: Bool = true

    /// Importance score (1-5) for prioritizing in prompts
    var importance: Int = 3

    // MARK: - Computed Properties

    var category: MemoryCategory {
        get { MemoryCategory(rawValue: categoryRaw) ?? .preference }
        set { categoryRaw = newValue.rawValue }
    }

    var topic: MemoryTopic {
        get { MemoryTopic(rawValue: topicRaw) ?? .general }
        set { topicRaw = newValue.rawValue }
    }

    // MARK: - Init

    init(
        content: String,
        category: MemoryCategory = .preference,
        topic: MemoryTopic = .general,
        source: String = "chat",
        importance: Int = 3
    ) {
        self.id = UUID()
        self.content = content
        self.categoryRaw = category.rawValue
        self.topicRaw = topic.rawValue
        self.createdAt = Date()
        self.source = source
        self.isActive = true
        self.importance = min(5, max(1, importance))
    }

    /// Format for inclusion in AI prompt
    var promptFormat: String {
        "[\(category.displayName)] \(content)"
    }
}

// MARK: - Memory Formatting

extension Array where Element == CoachMemory {
    /// Detect conversation topic from user message
    private static func detectTopic(from message: String) -> MemoryTopic? {
        let lower = message.lowercased()

        let foodKeywords = ["food", "eat", "meal", "calories", "protein", "macro", "nutrition",
                           "diet", "hungry", "breakfast", "lunch", "dinner", "snack", "cook",
                           "recipe", "ingredient", "carb", "fat", "fiber", "sugar"]
        let workoutKeywords = ["workout", "exercise", "gym", "lift", "pull", "push", "cardio",
                              "training", "sets", "reps", "muscle", "weight", "squat", "bench",
                              "deadlift", "run", "jog", "stretch", "rest day", "recovery"]
        let scheduleKeywords = ["time", "morning", "evening", "schedule", "when", "busy",
                               "routine", "tomorrow", "today", "week", "daily", "night shift"]

        let foodScore = foodKeywords.filter { lower.contains($0) }.count
        let workoutScore = workoutKeywords.filter { lower.contains($0) }.count
        let scheduleScore = scheduleKeywords.filter { lower.contains($0) }.count

        let maxScore = Swift.max(foodScore, Swift.max(workoutScore, scheduleScore))
        guard maxScore > 0 else { return nil }

        if maxScore == foodScore { return .food }
        if maxScore == workoutScore { return .workout }
        return .schedule
    }

    /// Filter memories by relevance to the current conversation
    /// - Parameters:
    ///   - message: The user's current message
    ///   - maxCount: Maximum number of memories to include (default 10)
    /// - Returns: Filtered and sorted array of relevant memories
    func filterForRelevance(message: String, maxCount: Int = 10) -> [CoachMemory] {
        guard !isEmpty else { return [] }

        let detectedTopic = Self.detectTopic(from: message)

        // Score each memory for relevance
        let scored: [(memory: CoachMemory, score: Int)] = self.map { memory in
            var score = 0

            // Always include restrictions (safety-critical) - highest priority
            if memory.category == .restriction {
                score += 100
            } else {
                // For non-restrictions, require topic match or high importance for visibility
                if let topic = detectedTopic, memory.topic == topic {
                    // Topic match - high relevance
                    score += 40
                } else if memory.topic == .general {
                    // General memories somewhat relevant
                    score += 25
                } else {
                    // Off-topic memories only included if critical importance
                    if memory.importance >= 5 {
                        score += 20
                    }
                    // Otherwise score stays 0 - not included
                }

                // Recency decay for non-restrictions (stale info less relevant)
                let daysSinceCreation = Date().timeIntervalSince(memory.createdAt) / 86400
                if daysSinceCreation > 30 {
                    score -= 15
                } else if daysSinceCreation < 7 {
                    score += 5
                }
            }

            // Importance adds to score (less weight than before to reduce overuse)
            score += memory.importance

            return (memory, score)
        }

        // Filter out very low scores (not relevant), then sort and take top N
        let sorted = scored
            .filter { $0.score > 5 } // Must have some relevance
            .sorted { $0.score > $1.score }
            .prefix(maxCount)
            .map(\.memory)

        return Array(sorted)
    }

    /// Format memories for inclusion in AI system prompt
    func formatForPrompt() -> String {
        guard !isEmpty else { return "" }

        // Group by topic
        let grouped = Dictionary(grouping: self) { $0.topic }

        var sections: [String] = []

        for topic in MemoryTopic.allCases {
            guard let memories = grouped[topic], !memories.isEmpty else { continue }

            // Sort by importance (highest first) then by date (newest first)
            let sorted = memories.sorted { m1, m2 in
                if m1.importance != m2.importance {
                    return m1.importance > m2.importance
                }
                return m1.createdAt > m2.createdAt
            }

            let items = sorted.map { "• \($0.content)" }.joined(separator: "\n")
            sections.append("\(topic.displayName):\n\(items)")
        }

        return sections.joined(separator: "\n\n")
    }
}
