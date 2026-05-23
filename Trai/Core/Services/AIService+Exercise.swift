//
//  AIService+Exercise.swift
//  Trai
//
//  AI-powered exercise analysis for custom exercise creation
//

import Foundation
import os.log

// MARK: - Exercise Analysis Types

struct ExerciseAnalysis: Codable {
    let category: String
    let activityTypeName: String?
    let activityAliases: [String]?
    let muscleGroup: String?   // Primary muscle group (nil for non-strength exercises)
    let secondaryMuscles: [String]?  // Secondary muscles worked
    let targetTags: [String]?
    let trackingFields: [String]?
    let description: String    // Brief description of the exercise
    let tips: String?          // Optional form tips
}

/// Result from identifying an exercise, activity, or equipment from a photo
struct ExercisePhotoAnalysis: Codable {
    let equipmentName: String       // Name of the visible exercise, activity setup, machine, or equipment
    let suggestedExercises: [SuggestedExercise]  // Exercises or activities the user can add
    let description: String         // What the photo appears to show
    let tips: String?               // Setup or usage tips

    struct SuggestedExercise: Codable, Identifiable {
        var id: String { name }
        let name: String
        let category: String?
        let activityTypeName: String?
        let activityAliases: [String]?
        let muscleGroup: String?
        let targetTags: [String]?
        let trackingFields: [String]?
        let howTo: String?          // Brief instruction
    }
}

extension ExercisePhotoAnalysis.SuggestedExercise {
    func resolvedCategory(equipmentName: String? = nil) -> Exercise.Category {
        if let category = Exercise.Category.normalized(from: category) {
            return category.userFacingEquivalent
        }

        for candidate in [activityTypeName, name, equipmentName] {
            if let category = Exercise.Category.normalized(from: candidate) {
                return category.userFacingEquivalent
            }
        }

        let fields = resolvedTrackingFields(category: .custom)
        if fields.contains(where: { $0 != .sets && $0 != .weight }) {
            return .custom
        }

        return .strength
    }

    func resolvedActivityTypeName(category: Exercise.Category, equipmentName: String? = nil) -> String {
        let explicit = activityTypeName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard explicit.isEmpty else { return explicit }
        let nameDefault = Exercise.defaultActivityTypeName(for: name, category: category)
        if nameDefault != category.displayName {
            return nameDefault
        }
        if let equipmentName {
            let equipmentDefault = Exercise.defaultActivityTypeName(for: equipmentName, category: category)
            if equipmentDefault != category.displayName {
                return equipmentDefault
            }
        }
        return nameDefault
    }

    func resolvedTrackingFields(category: Exercise.Category) -> [Exercise.TrackingField] {
        let fields = trackingFields?
            .compactMap(Exercise.TrackingField.init(rawValue:))
            ?? []
        return fields.isEmpty
            ? Exercise.defaultTrackingFields(for: category)
            : Exercise.normalizedTrackingFields(fields, for: category)
    }

    func resolvedDisplayLabel(equipmentName: String? = nil) -> String {
        let category = resolvedCategory(equipmentName: equipmentName)
        if category == .strength {
            if let muscleGroup,
               let group = Exercise.MuscleGroup(rawValue: muscleGroup) {
                return group.displayName
            }
            return category.displayName
        }

        let activityName = resolvedActivityTypeName(category: category, equipmentName: equipmentName)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return activityName.isEmpty ? category.displayName : activityName
    }
}

// MARK: - AIService Exercise Extension

extension AIService {
    /// Analyze an exercise name to determine its category, target muscles, and description
    func analyzeExercise(name: String) async throws -> ExerciseAnalysis {
        log("Analyzing exercise: \(name)", type: .info)
        return try await performAIRequest(for: .exerciseAnalysis) {
            let prompt = """
            Analyze this exercise and provide details about it.

            Exercise name: "\(name)"

            Determine:
            1. Category: Choose the stable tracking template from strength, cardio, conditioning, mobility, skill, sportPractice, recovery, flexibility, or custom. This is not the user-facing label.
            2. activityTypeName: Choose the specific user-facing activity identity, such as Climbing, Bouldering, Cycling, Running, Mobility Flow, Boxing, Basketball, Pickleball, or Strength.
            3. activityAliases: Common names Trai should treat as the same activity type, when useful.
            4. Primary muscle group for strength exercises only: chest, back, shoulders, biceps, triceps, legs, core, or fullBody.
            5. Secondary muscles worked, when relevant.
            6. Target tags that describe what the user is training with this exercise.
            7. Tracking fields the user should see while logging it.
            8. A brief 1-sentence description of the exercise.
            9. Optional quick form or execution tip.

            Use these tracking fields only: sets, reps, weight, duration, distance, notes.
            Pick fields that match how the exercise is actually tracked. For example:
            - Strength usually tracks sets, weight, and reps.
            - Running usually tracks duration and distance.
            - Mobility usually tracks duration and notes.
            - Conditioning may track duration, reps, and notes.
            - Skill or sport practice may track duration, reps or attempts, distance when relevant, and notes.

            Return targetTags as concise user-facing outcomes or focuses, not internal category names. Do not use calories.
            When the exercise name is a specific sport or activity, preserve that specificity in activityTypeName instead of flattening it to Sport, Skill, Conditioning, or Custom.
            If you don't recognize the exercise, make your best educated guess based on the name.
            """

            let schema: [String: Any] = [
                "type": "object",
                "properties": [
                    "category": [
                        "type": "string",
                        "enum": ["strength", "cardio", "conditioning", "mobility", "skill", "sportPractice", "recovery", "flexibility", "custom"]
                    ],
                    "activityTypeName": [
                        "type": "string",
                        "nullable": true
                    ],
                    "activityAliases": [
                        "type": "array",
                        "items": ["type": "string"],
                        "nullable": true
                    ],
                    "muscleGroup": [
                        "type": "string",
                        "enum": ["chest", "back", "shoulders", "biceps", "triceps", "legs", "core", "fullBody"],
                        "nullable": true
                    ],
                    "secondaryMuscles": [
                        "type": "array",
                        "items": ["type": "string"],
                        "nullable": true
                    ],
                    "targetTags": [
                        "type": "array",
                        "items": ["type": "string"],
                        "nullable": true
                    ],
                    "trackingFields": [
                        "type": "array",
                        "items": [
                            "type": "string",
                            "enum": ["sets", "reps", "weight", "duration", "distance", "notes"]
                        ],
                        "nullable": true
                    ],
                    "description": [
                        "type": "string"
                    ],
                    "tips": [
                        "type": "string",
                        "nullable": true
                    ]
                ],
                "required": ["category", "description"]
            ]

            let request = AIBackendPayloadBuilder.canonicalRequest(
                messages: [
                    AIBackendPayloadBuilder.canonicalTextMessage(role: .user, text: prompt)
                ],
                output: AIBackendPayloadBuilder.canonicalOutput(
                    kind: .jsonSchema,
                    schema: schema
                ),
                generation: AIBackendPayloadBuilder.canonicalGeneration(
                    reasoningLevel: .minimal
                )
            )

            logPrompt(prompt)

            let response = try await makeRequest(request: request)
            logResponse(response)

            guard let data = response.data(using: .utf8) else {
                throw AIServiceError.invalidResponse
            }

            let analysis = try JSONDecoder().decode(ExerciseAnalysis.self, from: data)
            log("Exercise analyzed: \(analysis.category), activity: \(analysis.activityTypeName ?? "none"), muscle: \(analysis.muscleGroup ?? "none")", type: .info)

            return analysis
        }
    }

    /// Identify an exercise, activity, or piece of equipment from a photo and suggest trackable entries.
    /// - Parameters:
    ///   - imageData: JPEG image data of the exercise, activity setup, or equipment
    ///   - existingExerciseNames: Names of exercises already in the user's library (for matching)
    func analyzeExercisePhoto(imageData: Data, existingExerciseNames: [String] = []) async throws -> ExercisePhotoAnalysis {
        log("Analyzing exercise photo", type: .info)
        return try await performAIRequest(for: .exercisePhotoAnalysis) {
            let existingExercisesContext: String
            if !existingExerciseNames.isEmpty {
                let exerciseList = existingExerciseNames.joined(separator: ", ")
                existingExercisesContext = """

                IMPORTANT: The user already has these exercises in their library:
                \(exerciseList)

                When suggesting exercises, use the EXACT name from this list if the exercise matches (even if you'd name it slightly differently). Only suggest a new name if none of the existing exercises match.
                """
            } else {
                existingExercisesContext = ""
            }

            let prompt = """
            Look at this image related to training. It may show a movement, sport setup, gym machine, cardio machine, free weights, mobility tool, placard, route/problem, field/court setup, or other exercise context.

            The image may show:
            - the person performing an exercise or activity
            - the full machine or part of the machine
            - an instruction placard or diagram
            - a brand/model label
            - close-up text describing how equipment or a movement is used
            - activity context such as a climbing wall, bike, rower, running route, court, bands, mobility setup, or recovery tool

            Identify:
            1. What visible exercise, activity setup, machine, or equipment this is (e.g., "Lat Pulldown Machine", "Rowing Machine", "Climbing Wall", "Band Mobility Setup")
            2. What trackable exercises or activities the user can add from it (list 1-4 main options)
            3. A brief description of what the photo shows
            4. Any setup tips or key things to know
            \(existingExercisesContext)
            IMPORTANT:
            - Use any visible text, diagrams, labels, route/problem markings, or setup instructions in the image to help identify the exercise or equipment.
            - Prioritize what is clearly visible in the image over guessing.
            - Do NOT invent hidden attachments, stations, exercise variants, routes, grades, machines, or activity details that are not supported by the visible image.
            - If the image only shows a partial view or descriptive signage, use the visible clues but keep the answer generic if needed instead of forcing a highly specific name.
            - Be specific when similar exercises or machines exist, but only when the image supports that level of certainty.
            - If brand/model text is clearly visible on the machine, include that in equipmentName. If the image is an activity setup rather than equipment, use a concise visible activity name such as "Climbing Wall" or "Mobility Band Setup".
            - For each suggested exercise, include category, activityTypeName, activityAliases, muscleGroup when it is strength, targetTags, and trackingFields so the app can save it correctly.
            - Categories are stable tracking templates and must be one of: strength, cardio, conditioning, mobility, skill, sportPractice, recovery, flexibility, custom. They are not the user-facing labels.
            - activityTypeName is the specific user-facing identity and can be specific, such as Climbing, Bouldering, Cycling, Running, Mobility Flow, Boxing, Basketball, Pickleball, or Strength.
            - Tracking fields must be chosen from: sets, reps, weight, duration, distance, notes. Do not use calories.
            - Strength exercises usually track sets, weight, and reps. Cardio activities usually track duration and distance. Skill, sport, mobility, recovery, and custom activities usually track duration, reps or attempts, distance when relevant, and notes.
            - Keep targetTags as user-facing outcomes or focuses, not broad category labels. Preserve a specific visible sport/activity in activityTypeName instead of flattening it to Sport, Skill, Conditioning, or Custom.
            - If the image is too unclear to confidently identify an exercise, activity, or equipment, return:
              equipmentName: "Unclear exercise photo"
              suggestedExercises: []
              description: "The image does not clearly show an identifiable exercise, activity, or equipment setup."
              tips: "Retake the photo with the full movement, setup, placard, or visible labels."
            - If the image is not exercise-related, do not force it into a workout category. Use a generic visible label, keep suggestedExercises empty unless they are clearly supported by the image, and explain the uncertainty in description or tips.
            """

            let preparedImageData = AIImagePayloadPreparer.prepareJPEGData(from: imageData) ?? imageData
            logImagePayloadSummary(preparedImageData, label: "Exercise photo analysis image")

            let schema: [String: Any] = [
                "type": "object",
                "properties": [
                    "equipmentName": [
                        "type": "string",
                        "description": "Name of the visible exercise, activity setup, machine, or equipment"
                    ],
                    "suggestedExercises": [
                        "type": "array",
                        "items": [
                            "type": "object",
                            "properties": [
                                "name": ["type": "string"],
                                "category": [
                                    "type": "string",
                                    "enum": ["strength", "cardio", "conditioning", "mobility", "skill", "sportPractice", "recovery", "flexibility", "custom"],
                                    "nullable": true
                                ],
                                "activityTypeName": [
                                    "type": "string",
                                    "nullable": true
                                ],
                                "activityAliases": [
                                    "type": "array",
                                    "items": ["type": "string"],
                                    "nullable": true
                                ],
                                "muscleGroup": [
                                    "type": "string",
                                    "enum": ["chest", "back", "shoulders", "biceps", "triceps", "legs", "core", "fullBody"],
                                    "nullable": true
                                ],
                                "targetTags": [
                                    "type": "array",
                                    "items": ["type": "string"],
                                    "nullable": true
                                ],
                                "trackingFields": [
                                    "type": "array",
                                    "items": [
                                        "type": "string",
                                        "enum": ["sets", "reps", "weight", "duration", "distance", "notes"]
                                    ],
                                    "nullable": true
                                ],
                                "howTo": [
                                    "type": "string",
                                    "nullable": true
                                ]
                            ],
                            "required": ["name"]
                        ]
                    ],
                    "description": [
                        "type": "string",
                        "description": "Brief description of what the photo appears to show"
                    ],
                    "tips": [
                        "type": "string",
                        "nullable": true
                    ]
                ],
                "required": ["equipmentName", "suggestedExercises", "description"]
            ]

            let request = AIBackendPayloadBuilder.canonicalRequest(
                messages: [
                    AIBackendPayloadBuilder.canonicalMessage(
                        role: .user,
                        parts: [
                            .text(prompt),
                            AIBackendPayloadBuilder.imagePart(preparedImageData)
                        ]
                    )
                ],
                output: AIBackendPayloadBuilder.canonicalOutput(
                    kind: .jsonSchema,
                    schema: schema
                ),
                generation: AIBackendPayloadBuilder.canonicalGeneration(
                    reasoningLevel: .minimal,
                    imageResolution: .high
                )
            )

            logPrompt(prompt)

            let response = try await makeRequest(request: request)
            logResponse(response)

            guard let data = response.data(using: .utf8) else {
                throw AIServiceError.invalidResponse
            }

            let analysis = try JSONDecoder().decode(ExercisePhotoAnalysis.self, from: data)
            log("Exercise photo identified: \(analysis.equipmentName) with \(analysis.suggestedExercises.count) suggestions", type: .info)

            return analysis
        }
    }
}
