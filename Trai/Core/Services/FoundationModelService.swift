import Foundation
import FoundationModels

/// Service for on-device AI using iOS 26 Foundation Models
@MainActor @Observable
final class FoundationModelService {
    private var session: LanguageModelSession?

    var isAvailable: Bool {
        SystemLanguageModel.default.isAvailable
    }

    var isLoading = false

    init() {
        setupSession()
    }

    private func setupSession() {
        guard isAvailable else { return }

        Task {
            do {
                session = LanguageModelSession()
            }
        }
    }

    // MARK: - Text Processing

    /// Categorize an exercise into a muscle group
    func categorizeExercise(_ name: String) async throws -> String {
        let prompt = """
        Categorize this exercise into one of these muscle groups: chest, back, shoulders, biceps, triceps, legs, core, fullBody.
        Exercise: \(name)
        Reply with ONLY the muscle group name, nothing else.
        """

        return try await generate(prompt: prompt)
    }

    /// Generate a brief meal summary
    func formatMealSummary(_ entries: [FoodEntry]) async throws -> String {
        let mealList = entries.map { "\($0.name): \($0.calories) cal" }.joined(separator: ", ")
        let totalCalories = entries.reduce(0) { $0 + $1.calories }

        let prompt = """
        Summarize these meals in one short sentence (max 15 words):
        Meals: \(mealList)
        Total: \(totalCalories) calories
        """

        return try await generate(prompt: prompt)
    }

    /// Suggest an appropriate meal time for a food entry
    func suggestMealTime(for entry: FoodEntry) async throws -> String {
        let prompt = """
        What meal is this most appropriate for? Reply with ONLY one of: breakfast, lunch, dinner, snack
        Food: \(entry.name)
        """

        let result = try await generate(prompt: prompt)
        let normalized = result.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // Validate response
        let validMeals = ["breakfast", "lunch", "dinner", "snack"]
        return validMeals.first { normalized.contains($0) } ?? "snack"
    }

    /// Sort exercises by muscle group
    func sortExercisesByMuscleGroup(_ exercises: [String]) async throws -> [String: [String]] {
        let exerciseList = exercises.joined(separator: ", ")

        let prompt = """
        Group these exercises by muscle group. Return as a simple list with format "MuscleGroup: exercise1, exercise2"
        Exercises: \(exerciseList)
        """

        let result = try await generate(prompt: prompt)

        // Parse the result into a dictionary
        var grouped: [String: [String]] = [:]
        for line in result.components(separatedBy: "\n") {
            let parts = line.components(separatedBy: ":")
            if parts.count == 2 {
                let group = parts[0].trimmingCharacters(in: .whitespaces)
                let exercises = parts[1].components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                grouped[group] = exercises
            }
        }

        return grouped
    }

    // MARK: - Private

    private func generate(prompt: String) async throws -> String {
        guard isAvailable else {
            throw FoundationModelError.notAvailable
        }

        isLoading = true
        defer { isLoading = false }

        let session = LanguageModelSession()
        let response = try await session.respond(to: prompt)
        return response.content
    }
}

// MARK: - Errors

enum FoundationModelError: LocalizedError {
    case notAvailable
    case generationFailed

    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "On-device AI is not available"
        case .generationFailed:
            return "Failed to generate response"
        }
    }
}
