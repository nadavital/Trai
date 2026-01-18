//
//  TraiQuestionTypes.swift
//  Trai
//
//  Types for the reusable TraiQuestion component system
//

import Foundation

// MARK: - Selection Mode

/// Determines how users can select answers to a question
enum TraiSelectionMode {
    /// User can only select one answer (auto-advances after selection)
    case single
    /// User can select multiple answers (must tap Continue to proceed)
    case multiple
}

// MARK: - Question Config

/// Configuration for a Trai question that can be used anywhere in the app
struct TraiQuestionConfig: Identifiable, Equatable {
    let id: String
    let question: String
    let suggestions: [TraiSuggestion]
    let selectionMode: TraiSelectionMode
    let placeholder: String
    let skipText: String?
    let isRequired: Bool

    init(
        id: String,
        question: String,
        suggestions: [TraiSuggestion],
        selectionMode: TraiSelectionMode = .single,
        placeholder: String = "Type your answer...",
        skipText: String? = nil,
        isRequired: Bool = false
    ) {
        self.id = id
        self.question = question
        self.suggestions = suggestions
        self.selectionMode = selectionMode
        self.placeholder = placeholder
        self.skipText = skipText
        self.isRequired = isRequired
    }

    static func == (lhs: TraiQuestionConfig, rhs: TraiQuestionConfig) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Suggestion

/// A suggestion chip that Trai provides as a possible answer
struct TraiSuggestion: Identifiable, Hashable {
    let id: String
    let text: String
    let subtitle: String?
    let isSkip: Bool

    init(_ text: String, subtitle: String? = nil, isSkip: Bool = false) {
        self.id = text
        self.text = text
        self.subtitle = subtitle
        self.isSkip = isSkip
    }

    init(id: String, text: String, subtitle: String? = nil, isSkip: Bool = false) {
        self.id = id
        self.text = text
        self.subtitle = subtitle
        self.isSkip = isSkip
    }
}

// MARK: - Answer

/// A user's answer to a Trai question
struct TraiAnswer: Identifiable, Hashable {
    let id: String
    let text: String
    let questionId: String
    let isCustom: Bool

    init(text: String, questionId: String, isCustom: Bool = false) {
        self.id = UUID().uuidString
        self.text = text
        self.questionId = questionId
        self.isCustom = isCustom
    }
}

// MARK: - Collected Answers

/// Collection of answers for a multi-step question flow
struct TraiCollectedAnswers {
    private var answersByQuestion: [String: [String]] = [:]

    /// Get answers for a specific question
    func answers(for questionId: String) -> [String] {
        answersByQuestion[questionId] ?? []
    }

    /// Check if any answers exist for a question
    func hasAnswers(for questionId: String) -> Bool {
        !(answersByQuestion[questionId]?.isEmpty ?? true)
    }

    /// Add an answer for a question
    mutating func add(_ answer: String, for questionId: String) {
        var current = answersByQuestion[questionId] ?? []
        if !current.contains(answer) {
            current.append(answer)
            answersByQuestion[questionId] = current
        }
    }

    /// Remove an answer from a question
    mutating func remove(_ answer: String, from questionId: String) {
        answersByQuestion[questionId]?.removeAll { $0 == answer }
    }

    /// Toggle an answer (add if not present, remove if present)
    mutating func toggle(_ answer: String, for questionId: String) {
        if answers(for: questionId).contains(answer) {
            remove(answer, from: questionId)
        } else {
            add(answer, for: questionId)
        }
    }

    /// Clear answers for a question
    mutating func clear(for questionId: String) {
        answersByQuestion[questionId] = []
    }

    /// Set a single answer (for single-select questions)
    mutating func setSingle(_ answer: String, for questionId: String) {
        answersByQuestion[questionId] = [answer]
    }

    /// Get all answers as a dictionary
    func allAnswers() -> [String: [String]] {
        answersByQuestion
    }
}
