//
//  GeminiFunctionExecutor+Food.swift
//  Plates
//
//  Food-related function execution
//

import Foundation
import SwiftData

extension GeminiFunctionExecutor {

    // MARK: - Food Functions

    func executeSuggestFoodLog(_ args: [String: Any]) -> ExecutionResult {
        guard let name = args["name"] as? String,
              let calories = args["calories"] as? Int,
              let protein = args["protein_grams"] as? Double ?? (args["protein_grams"] as? Int).map(Double.init),
              let carbs = args["carbs_grams"] as? Double ?? (args["carbs_grams"] as? Int).map(Double.init),
              let fat = args["fat_grams"] as? Double ?? (args["fat_grams"] as? Int).map(Double.init) else {
            return .dataResponse(FunctionResult(
                name: "suggest_food_log",
                response: ["error": "Missing required parameters"]
            ))
        }

        let entry = SuggestedFoodEntry(
            name: name,
            calories: calories,
            proteinGrams: protein,
            carbsGrams: carbs,
            fatGrams: fat,
            servingSize: args["serving_size"] as? String,
            emoji: args["emoji"] as? String,
            loggedAtTime: args["logged_at_time"] as? String
        )

        return .suggestedFood(entry)
    }

    func executeEditFoodEntry(_ args: [String: Any]) -> ExecutionResult {
        guard let entryIdString = args["entry_id"] as? String,
              let entryId = UUID(uuidString: entryIdString) else {
            return .dataResponse(FunctionResult(
                name: "edit_food_entry",
                response: ["error": "Invalid or missing entry_id"]
            ))
        }

        // Find the entry
        let descriptor = FetchDescriptor<FoodEntry>(
            predicate: #Predicate { $0.id == entryId }
        )

        guard let entry = try? modelContext.fetch(descriptor).first else {
            return .dataResponse(FunctionResult(
                name: "edit_food_entry",
                response: ["error": "Food entry not found"]
            ))
        }

        // Apply updates
        var changes: [String] = []

        if let newName = args["name"] as? String {
            entry.name = newName
            changes.append("name")
        }
        if let newCalories = args["calories"] as? Int {
            entry.calories = newCalories
            changes.append("calories")
        }
        if let newProtein = args["protein_grams"] as? Double ?? (args["protein_grams"] as? Int).map(Double.init) {
            entry.proteinGrams = newProtein
            changes.append("protein")
        }
        if let newCarbs = args["carbs_grams"] as? Double ?? (args["carbs_grams"] as? Int).map(Double.init) {
            entry.carbsGrams = newCarbs
            changes.append("carbs")
        }
        if let newFat = args["fat_grams"] as? Double ?? (args["fat_grams"] as? Int).map(Double.init) {
            entry.fatGrams = newFat
            changes.append("fat")
        }

        try? modelContext.save()

        return .dataResponse(FunctionResult(
            name: "edit_food_entry",
            response: [
                "success": true,
                "updated_fields": changes,
                "entry": [
                    "id": entry.id.uuidString,
                    "name": entry.name,
                    "calories": entry.calories,
                    "protein": entry.proteinGrams,
                    "carbs": entry.carbsGrams,
                    "fat": entry.fatGrams
                ]
            ]
        ))
    }

    func executeGetTodaysFoodLog() -> ExecutionResult {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let descriptor = FetchDescriptor<FoodEntry>(
            predicate: #Predicate { $0.loggedAt >= startOfDay && $0.loggedAt < endOfDay },
            sortBy: [SortDescriptor(\.loggedAt)]
        )

        let entries = (try? modelContext.fetch(descriptor)) ?? []

        // Calculate totals
        let totalCalories = entries.reduce(0) { $0 + $1.calories }
        let totalProtein = entries.reduce(0.0) { $0 + $1.proteinGrams }
        let totalCarbs = entries.reduce(0.0) { $0 + $1.carbsGrams }
        let totalFat = entries.reduce(0.0) { $0 + $1.fatGrams }

        // Get targets from profile
        let targetCalories = userProfile?.dailyCalorieGoal ?? 2000
        let targetProtein = userProfile?.dailyProteinGoal ?? 150
        let targetCarbs = userProfile?.dailyCarbsGoal ?? 200
        let targetFat = userProfile?.dailyFatGoal ?? 65

        // Format entries
        let formattedEntries = entries.map { entry -> [String: Any] in
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "h:mm a"
            return [
                "id": entry.id.uuidString,
                "name": entry.name,
                "emoji": entry.displayEmoji,
                "calories": entry.calories,
                "protein": entry.proteinGrams,
                "carbs": entry.carbsGrams,
                "fat": entry.fatGrams,
                "time": timeFormatter.string(from: entry.loggedAt)
            ]
        }

        return .dataResponse(FunctionResult(
            name: "get_todays_food_log",
            response: [
                "entries": formattedEntries,
                "totals": [
                    "calories": totalCalories,
                    "protein": Int(totalProtein),
                    "carbs": Int(totalCarbs),
                    "fat": Int(totalFat)
                ],
                "targets": [
                    "calories": targetCalories,
                    "protein": targetProtein,
                    "carbs": targetCarbs,
                    "fat": targetFat
                ],
                "remaining": [
                    "calories": targetCalories - totalCalories,
                    "protein": targetProtein - Int(totalProtein),
                    "carbs": targetCarbs - Int(totalCarbs),
                    "fat": targetFat - Int(totalFat)
                ],
                "entry_count": entries.count
            ]
        ))
    }
}
