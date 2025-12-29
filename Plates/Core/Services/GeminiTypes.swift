//
//  GeminiTypes.swift
//  Plates
//
//  Created by Nadav Avital on 12/25/25.
//

import Foundation

/// Response from Gemini API for food analysis
struct FoodAnalysis: Codable, Sendable {
    let name: String
    let calories: Int
    let proteinGrams: Double
    let carbsGrams: Double
    let fatGrams: Double
    let servingSize: String?
    let confidence: String
    let notes: String?
    let emoji: String?

    /// Display emoji with fallback
    var displayEmoji: String {
        emoji ?? "🍽️"
    }
}

/// Result from chat-based food analysis (with optional meal logging)
struct ChatFoodAnalysisResult: Sendable {
    let message: String
    let suggestedFoodEntry: SuggestedFoodEntry?
}

/// Food entry suggested by AI for logging
struct SuggestedFoodEntry: Codable, Sendable {
    let name: String
    let calories: Int
    let proteinGrams: Double
    let carbsGrams: Double
    let fatGrams: Double
    let servingSize: String?
    let emoji: String?  // Relevant emoji for the food (☕, 🥗, 🍳, etc.)
    let loggedAtTime: String?  // HH:mm format if user specified a time

    /// Parse the loggedAtTime into a Date (today at that time)
    var loggedAtDate: Date? {
        guard let timeString = loggedAtTime else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        guard let time = formatter.date(from: timeString) else { return nil }

        // Combine today's date with the parsed time
        let calendar = Calendar.current
        let now = Date()
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: time)
        components.hour = timeComponents.hour
        components.minute = timeComponents.minute
        return calendar.date(from: components)
    }

    /// Display emoji or default fork and knife
    var displayEmoji: String {
        emoji ?? "🍽️"
    }

    init(name: String, calories: Int, proteinGrams: Double, carbsGrams: Double, fatGrams: Double, servingSize: String?, emoji: String? = nil, loggedAtTime: String? = nil) {
        self.name = name
        self.calories = calories
        self.proteinGrams = proteinGrams
        self.carbsGrams = carbsGrams
        self.fatGrams = fatGrams
        self.servingSize = servingSize
        self.emoji = emoji
        self.loggedAtTime = loggedAtTime
    }
}

/// Context provided to AI for fitness-aware responses
struct FitnessContext: Sendable {
    let userGoal: String
    let dailyCalorieGoal: Int
    let dailyProteinGoal: Int
    let todaysCalories: Int
    let todaysProtein: Double
    let recentWorkouts: [String]
    let currentWeight: Double?
    let targetWeight: Double?

    init(
        userGoal: String,
        dailyCalorieGoal: Int,
        dailyProteinGoal: Int,
        todaysCalories: Int,
        todaysProtein: Double,
        recentWorkouts: [String] = [],
        currentWeight: Double? = nil,
        targetWeight: Double? = nil
    ) {
        self.userGoal = userGoal
        self.dailyCalorieGoal = dailyCalorieGoal
        self.dailyProteinGoal = dailyProteinGoal
        self.todaysCalories = todaysCalories
        self.todaysProtein = todaysProtein
        self.recentWorkouts = recentWorkouts
        self.currentWeight = currentWeight
        self.targetWeight = targetWeight
    }
}

// MARK: - Errors

enum GeminiError: LocalizedError {
    case invalidInput(String)
    case invalidResponse
    case apiError(statusCode: Int, message: String)
    case parsingError

    var errorDescription: String? {
        switch self {
        case .invalidInput(let message):
            return message
        case .invalidResponse:
            return "Invalid response from AI service"
        case .apiError(let statusCode, let message):
            return "API Error (\(statusCode)): \(message)"
        case .parsingError:
            return "Failed to parse AI response"
        }
    }
}
