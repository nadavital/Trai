//
//  GeminiFunctionDeclarations.swift
//  Plates
//
//  Function declarations (tools) for Gemini function calling API
//

import Foundation

/// Function declarations for Gemini API function calling
enum GeminiFunctionDeclarations {

    // MARK: - All Chat Functions

    /// All function declarations for chat interactions
    static var chatFunctions: [[String: Any]] {
        [
            suggestFoodLog,
            editFoodEntry,
            getTodaysFoodLog,
            getUserPlan,
            updateUserPlan,
            getRecentWorkouts,
            logWorkout
        ]
    }

    // MARK: - Food Functions

    /// Suggest a food entry for the user to confirm before logging
    static var suggestFoodLog: [String: Any] {
        [
            "name": "suggest_food_log",
            "description": "Suggest a food entry for the user to log. The user must confirm before it's added to their diary. Use this when the user mentions eating something or shares a food photo. Always provide accurate nutritional estimates.",
            "parameters": [
                "type": "object",
                "properties": [
                    "name": [
                        "type": "string",
                        "description": "Name of the food or meal (e.g., 'Chicken Caesar Salad', 'Black Coffee')"
                    ],
                    "calories": [
                        "type": "integer",
                        "description": "Total calories"
                    ],
                    "protein_grams": [
                        "type": "number",
                        "description": "Protein in grams"
                    ],
                    "carbs_grams": [
                        "type": "number",
                        "description": "Carbohydrates in grams"
                    ],
                    "fat_grams": [
                        "type": "number",
                        "description": "Fat in grams"
                    ],
                    "serving_size": [
                        "type": "string",
                        "description": "Serving size description (e.g., '1 large bowl', '16 oz')"
                    ],
                    "emoji": [
                        "type": "string",
                        "description": "A single relevant food emoji (e.g., ☕, 🥗, 🍳, 🍕)"
                    ],
                    "logged_at_time": [
                        "type": "string",
                        "description": "Time to log the meal in HH:mm 24-hour format, if the user specified a time (e.g., '14:30' for 2:30 PM)"
                    ]
                ],
                "required": ["name", "calories", "protein_grams", "carbs_grams", "fat_grams", "emoji"]
            ]
        ]
    }

    /// Edit an existing food entry
    static var editFoodEntry: [String: Any] {
        [
            "name": "edit_food_entry",
            "description": "Edit an existing food entry in the user's diary. Use when the user asks to modify a logged meal's details.",
            "parameters": [
                "type": "object",
                "properties": [
                    "entry_id": [
                        "type": "string",
                        "description": "The UUID of the food entry to edit"
                    ],
                    "name": [
                        "type": "string",
                        "description": "New name for the food (optional)"
                    ],
                    "calories": [
                        "type": "integer",
                        "description": "New calorie count (optional)"
                    ],
                    "protein_grams": [
                        "type": "number",
                        "description": "New protein in grams (optional)"
                    ],
                    "carbs_grams": [
                        "type": "number",
                        "description": "New carbs in grams (optional)"
                    ],
                    "fat_grams": [
                        "type": "number",
                        "description": "New fat in grams (optional)"
                    ]
                ],
                "required": ["entry_id"]
            ]
        ]
    }

    /// Get today's food log with nutrition totals
    static var getTodaysFoodLog: [String: Any] {
        [
            "name": "get_todays_food_log",
            "description": "Get the user's food log for today, including all entries and nutrition totals vs targets. Use when the user asks what they've eaten, their progress, remaining calories/macros, or nutrition status.",
            "parameters": [
                "type": "object",
                "properties": [:],
                "required": []
            ]
        ]
    }

    // MARK: - Plan/Goal Functions

    /// Get the user's current nutrition plan and goals
    static var getUserPlan: [String: Any] {
        [
            "name": "get_user_plan",
            "description": "Get the user's current nutrition plan, including their goal, daily calorie/macro targets, and plan rationale. Use when the user asks about their goals, targets, or plan details.",
            "parameters": [
                "type": "object",
                "properties": [:],
                "required": []
            ]
        ]
    }

    /// Propose updates to the user's plan/goals
    static var updateUserPlan: [String: Any] {
        [
            "name": "update_user_plan",
            "description": "Propose changes to the user's nutrition plan or goals. The user must confirm before changes are applied. Use when the user wants to adjust their calorie/macro targets or change their goal.",
            "parameters": [
                "type": "object",
                "properties": [
                    "calories": [
                        "type": "integer",
                        "description": "New daily calorie target"
                    ],
                    "protein_grams": [
                        "type": "integer",
                        "description": "New daily protein target in grams"
                    ],
                    "carbs_grams": [
                        "type": "integer",
                        "description": "New daily carbs target in grams"
                    ],
                    "fat_grams": [
                        "type": "integer",
                        "description": "New daily fat target in grams"
                    ],
                    "goal": [
                        "type": "string",
                        "description": "New fitness goal (e.g., 'lose_weight', 'build_muscle', 'maintain')"
                    ],
                    "rationale": [
                        "type": "string",
                        "description": "Brief explanation of why these changes are recommended"
                    ]
                ],
                "required": []
            ]
        ]
    }

    // MARK: - Workout Functions

    /// Get recent workout history
    static var getRecentWorkouts: [String: Any] {
        [
            "name": "get_recent_workouts",
            "description": "Get the user's recent workout history. Use when the user asks about their workout history, exercise patterns, or training frequency.",
            "parameters": [
                "type": "object",
                "properties": [
                    "limit": [
                        "type": "integer",
                        "description": "Maximum number of workouts to return (default: 5)"
                    ]
                ],
                "required": []
            ]
        ]
    }

    /// Log a workout session
    static var logWorkout: [String: Any] {
        [
            "name": "log_workout",
            "description": "Log a workout session for the user. Use when the user mentions completing a workout or exercise.",
            "parameters": [
                "type": "object",
                "properties": [
                    "type": [
                        "type": "string",
                        "description": "Type of workout (e.g., 'strength', 'cardio', 'hiit', 'yoga', 'running')"
                    ],
                    "duration_minutes": [
                        "type": "integer",
                        "description": "Duration of the workout in minutes"
                    ],
                    "notes": [
                        "type": "string",
                        "description": "Optional notes about the workout"
                    ],
                    "exercises": [
                        "type": "array",
                        "items": [
                            "type": "object",
                            "properties": [
                                "name": ["type": "string"],
                                "sets": ["type": "integer"],
                                "reps": ["type": "integer"],
                                "weight_kg": ["type": "number"]
                            ]
                        ],
                        "description": "List of exercises performed (for strength training)"
                    ]
                ],
                "required": ["type"]
            ]
        ]
    }
}
