import XCTest
@testable import Trai

final class WorkoutPlanGenerationRequestTests: XCTestCase {
    func testFallbackSessionDurationUsesDefaultWhenUnspecified() {
        let request = makeRequest(timePerWorkout: nil)

        XCTAssertEqual(request.fallbackSessionDuration, 45)
    }

    func testFallbackSessionDurationClampsToSupportedBounds() {
        XCTAssertEqual(makeRequest(timePerWorkout: 10).fallbackSessionDuration, 20)
        XCTAssertEqual(makeRequest(timePerWorkout: 75).fallbackSessionDuration, 75)
        XCTAssertEqual(makeRequest(timePerWorkout: 180).fallbackSessionDuration, 120)
    }

    func testIncludesCardioHonorsSelectedWorkoutTypes() {
        let request = makeRequest(
            workoutType: .strength,
            selectedWorkoutTypes: [.strength, .cardio]
        )

        XCTAssertTrue(request.includesCardio)
    }

    func testAccessoryCardioDirectiveKeepsCardioInsideStrengthSession() {
        let request = makeRequest(
            workoutType: .mixed,
            selectedWorkoutTypes: [.strength, .cardio],
            preferences: "I want to add some cardio at the end of one strength session every week.",
            cardioSupportConstraint: .init(role: .finisher, maximumPlacements: 1)
        )

        XCTAssertTrue(request.requestsCardioAsAccessory)
        XCTAssertTrue(request.limitsAccessoryCardioToOneSession)
    }

    func testSupportiveEnduranceDirectiveDoesNotDependOnCardioFinisherPhrase() {
        let request = makeRequest(
            workoutType: .mixed,
            selectedWorkoutTypes: [.strength, .cardio],
            preferences: "Strength is the priority. Add easy running after one lower-body workout, not as a dedicated endurance day.",
            cardioSupportConstraint: .init(role: .accessory)
        )

        XCTAssertTrue(request.requestsCardioAsAccessory)
        XCTAssertFalse(request.limitsAccessoryCardioToOneSession)
        XCTAssertFalse(request.generationDirectives.joined(separator: " ").contains("cardio finisher"))
    }

    func testAccessoryCardioDefaultPlanUsesFinisherInsteadOfStandaloneCardioDay() {
        let request = makeRequest(
            workoutType: .mixed,
            selectedWorkoutTypes: [.strength, .cardio],
            preferences: "Strength should lead and I only want a short easy cardio finisher after one lift each week.",
            cardioSupportConstraint: .init(role: .finisher, maximumPlacements: 1),
            availableDays: 3
        )

        let plan = WorkoutPlan.createDefault(from: request)

        XCTAssertEqual(request.supportiveCardioRole, .finisher)
        XCTAssertEqual(plan.templates.count, 3)
        XCTAssertFalse(plan.templates.contains { $0.sessionType == .cardio })
        XCTAssertEqual(
            plan.templates.flatMap(\.displayBlocks).filter { $0.kind == .cardio && $0.role == .finisher }.count,
            1
        )
    }

    func testSupportiveCardioWithoutEndPlacementUsesAccessoryRole() {
        let request = makeRequest(
            workoutType: .mixed,
            selectedWorkoutTypes: [.strength, .cardio],
            preferences: "Strength is the priority. Include easy cardio support once a week, but not as a dedicated cardio day.",
            cardioSupportConstraint: .init(role: .accessory, maximumPlacements: 1),
            availableDays: 3
        )

        let plan = WorkoutPlan.createDefault(from: request)
        let supportBlocks = plan.templates.flatMap(\.displayBlocks).filter { $0.kind == .cardio }

        XCTAssertTrue(request.requestsCardioAsAccessory)
        XCTAssertEqual(request.supportiveCardioRole, .accessory)
        XCTAssertTrue(request.generationDirectives.joined(separator: " ").contains("role accessory"))
        XCTAssertEqual(supportBlocks.map(\.role), [.accessory])
        XCTAssertFalse(supportBlocks.first?.detail.localizedCaseInsensitiveContains("finish") == true)
    }

    @MainActor
    func testWorkoutPlanValidationRequiresGenericCardioStructureWhenCardioSelected() {
        let request = makeRequest(
            workoutType: .mixed,
            selectedWorkoutTypes: [.strength, .cardio],
            preferences: "Strength should lead and I only want a short easy cardio finisher after one lift each week.",
            cardioSupportConstraint: nil,
            availableDays: 1
        )
        let strengthOnlyPlan = makePlan(
            templateName: "Upper Strength",
            sessionType: .strength,
            focusAreas: ["Upper"],
            blocks: [
                WorkoutPlan.TrainingBlock(
                    kind: .strength,
                    title: "Strength",
                    detail: "Upper-body lifting",
                    activityTypeName: "Strength",
                    order: 0
                )
            ]
        )

        XCTAssertFalse(request.limitsAccessoryCardioToOneSession)
        XCTAssertThrowsError(try AIService.validateGeneratedWorkoutPlanForTesting(strengthOnlyPlan, request: request))
    }

    func testDedicatedCardioSignalOverridesAccessoryCardioDirective() {
        let request = makeRequest(
            workoutType: .mixed,
            selectedWorkoutTypes: [.strength, .cardio],
            preferences: "I want cardio after lifting, but I am training for a 10k race.",
            cardioSupportConstraint: nil
        )

        XCTAssertFalse(request.requestsCardioAsAccessory)
        XCTAssertFalse(request.limitsAccessoryCardioToOneSession)
    }

    func testActivityOnlyTemplateWorkloadSummaryUsesActivityNames() {
        let template = WorkoutPlan.WorkoutTemplate(
            name: "Climb + Mobility",
            sessionType: .custom,
            focusAreas: ["Climbing", "Mobility"],
            targetMuscleGroups: [],
            exercises: [],
            blocks: [
                .init(
                    kind: .sportPractice,
                    title: "Limit Bouldering",
                    detail: "Hard attempts",
                    activityTypeName: "Bouldering",
                    order: 0
                ),
                .init(
                    kind: .mobility,
                    title: "Shoulder Prep",
                    detail: "Controlled range",
                    activityTypeName: "Mobility Flow",
                    order: 1
                )
            ],
            estimatedDurationMinutes: 45,
            order: 0
        )

        XCTAssertEqual(template.displayWorkloadSummary, "Bouldering • Mobility Flow")
    }

    func testPlanSubtitleUsesActivityNameBeforeGenericBlockTitle() {
        let template = WorkoutPlan.WorkoutTemplate(
            name: "Practice Day",
            sessionType: .custom,
            focusAreas: [],
            targetMuscleGroups: [],
            exercises: [],
            blocks: [
                .init(
                    kind: .sportPractice,
                    title: "Skill",
                    detail: "Hard attempts",
                    activityTypeName: "Bouldering",
                    durationMinutes: 30,
                    order: 0
                ),
                .init(
                    kind: .mobility,
                    title: "Mobility",
                    detail: "Shoulder prep",
                    activityTypeName: "Shoulder Mobility",
                    durationMinutes: 10,
                    order: 1
                )
            ],
            estimatedDurationMinutes: 40,
            order: 0
        )

        XCTAssertEqual(template.primaryBlockSummary, "Bouldering 30m • Shoulder Mobility 10m")
        XCTAssertEqual(template.displaySubtitle, "Bouldering 30m • Shoulder Mobility 10m")
    }

    func testStrengthTemplateWorkloadSummaryIncludesSupportActivity() {
        let template = WorkoutPlan.WorkoutTemplate(
            name: "Lower + Easy Spin",
            sessionType: .mixed,
            focusAreas: ["Legs", "Cycling"],
            targetMuscleGroups: ["legs"],
            exercises: [],
            blocks: [
                .init(
                    kind: .strength,
                    title: "Lower Strength",
                    detail: "Primary lifts",
                    exercises: [
                        .init(exerciseName: "Back Squat", muscleGroup: "legs", defaultSets: 3, defaultReps: 5, order: 0),
                        .init(exerciseName: "Romanian Deadlift", muscleGroup: "legs", defaultSets: 3, defaultReps: 8, order: 1)
                    ],
                    activityTypeName: "Strength",
                    order: 0
                ),
                .init(
                    kind: .cardio,
                    role: .accessory,
                    title: "Easy Spin",
                    detail: "Low effort support",
                    activityTypeName: "Cycling",
                    order: 1
                )
            ],
            estimatedDurationMinutes: 50,
            order: 0
        )

        XCTAssertEqual(template.displayWorkloadSummary, "2 exercises • Cycling")
    }

    func testClimbingSelectionRequiresRealPlanRepresentation() {
        let request = makeRequest(
            workoutType: .mixed,
            selectedWorkoutTypes: [.strength, .cardio],
            preferences: "Strength should lead, but climbing should stay in the weekly plan.",
            conversationContext: ["Requested training styles: Strength, Climbing"],
            cardioTypes: [.climbing],
            availableDays: 3
        )

        let directives = request.generationDirectives.joined(separator: " ")
        XCTAssertTrue(directives.contains("Preserve explicit activity identities: Climbing"))
        XCTAssertTrue(directives.contains("real template, meaningful block"))
        XCTAssertTrue(directives.contains("Do not replace a specific selected activity with only generic support work"))
        XCTAssertFalse(directives.contains("Climbing was explicitly selected"))
    }

    func testCustomActivitySelectionUsesGenericIdentityDirective() {
        let request = makeRequest(
            workoutType: .mixed,
            selectedWorkoutTypes: [.strength, .cardio],
            preferences: "I want strength plus weekly pickleball.",
            conversationContext: ["Requested training styles: Strength, Pickleball"],
            customWorkoutType: "Pickleball",
            availableDays: 3
        )

        let directives = request.generationDirectives.joined(separator: " ")
        XCTAssertTrue(directives.contains("Preserve explicit activity identities: Pickleball"))
        XCTAssertTrue(directives.contains("goal scope"))
        XCTAssertFalse(directives.contains("custom focus"))
    }

    func testWorkoutPlanPromptSelfChecksSelectedModalities() {
        let request = makeRequest(
            workoutType: .mixed,
            selectedWorkoutTypes: [.strength, .cardio],
            conversationContext: ["Requested training styles: Strength, Climbing"],
            cardioTypes: [.climbing]
        )

        let prompt = AIPromptBuilder.buildWorkoutPlanGenerationPrompt(request: request)

        XCTAssertTrue(prompt.contains("Preserve every selected or stated modality as real plan structure"))
        XCTAssertTrue(prompt.contains("If a specific activity is named, keep that activity visible"))
        XCTAssertTrue(prompt.contains("Is every explicitly selected modality still visible as a real template or block?"))
        XCTAssertTrue(prompt.contains("Use role finisher only"))
        XCTAssertFalse(prompt.contains("role finisher or accessory"))
        XCTAssertFalse(prompt.contains("Strength and Climbing"))
    }

    func testLegacyWorkoutPlanJSONSynthesizesBlocks() throws {
        let json = """
        {
          "splitType": "upperLower",
          "daysPerWeek": 3,
          "templates": [
            {
              "id": "11111111-1111-1111-1111-111111111111",
              "name": "Upper Strength",
              "targetMuscleGroups": ["chest", "back"],
              "exercises": [
                {
                  "id": "22222222-2222-2222-2222-222222222222",
                  "exerciseName": "Bench Press",
                  "muscleGroup": "chest",
                  "defaultSets": 3,
                  "defaultReps": 8,
                  "order": 0
                }
              ],
              "estimatedDurationMinutes": 45,
              "order": 0
            }
          ],
          "rationale": "Legacy",
          "guidelines": [],
          "progressionStrategy": {
            "type": "doubleProgression",
            "weightIncrementKg": 2.5,
            "repsTrigger": 12,
            "description": "Progress reps, then load."
          }
        }
        """

        let plan = try XCTUnwrap(WorkoutPlan.fromJSON(json))
        let template = try XCTUnwrap(plan.templates.first)

        XCTAssertNil(plan.planIntent)
        XCTAssertNil(plan.modalityProgression)
        XCTAssertEqual(template.sessionType, .strength)
        XCTAssertTrue(template.blocks.isEmpty)
        XCTAssertEqual(template.displayBlocks.count, 1)
        XCTAssertEqual(template.displayBlocks.first?.kind, .strength)
        XCTAssertEqual(template.structuredExercises.map(\.exerciseName), ["Bench Press"])
    }

    func testWorkoutPlanJSONAcceptsAISemanticStringIDs() throws {
        let json = """
        {
          "splitType": "custom",
          "daysPerWeek": 1,
          "planIntent": {
            "primaryFocus": "Bench strength",
            "supportingFocuses": ["Short cardio support"],
            "sessionAllocation": "One strength session with one short cardio finisher",
            "honoredInputs": ["No standalone cardio day"],
            "avoided": ["Standalone cardio day"],
            "summary": "Strength first."
          },
          "templates": [
            {
              "id": "session-1",
              "name": "Strength A + Easy Run Finisher",
              "sessionType": "mixed",
              "focusAreas": ["Bench Press", "Easy Cardio Support"],
              "targetMuscleGroups": ["Chest", "Back"],
              "exercises": [
                {
                  "id": "bench-press",
                  "exerciseName": "Bench Press",
                  "muscleGroup": "Chest",
                  "defaultSets": 3,
                  "defaultReps": 6,
                  "repRange": "5-8",
                  "restSeconds": 120,
                  "notes": "Smooth reps.",
                  "order": 1
                }
              ],
              "blocks": [
                {
                  "id": "session-1-strength",
                  "kind": "strength",
                  "role": "main",
                  "title": "Strength",
                  "detail": "Bench work",
                  "exercises": [
                    {
                      "id": "bench-press",
                      "exerciseName": "Bench Press",
                      "muscleGroup": "Chest",
                      "defaultSets": 3,
                      "defaultReps": 6,
                      "order": 1
                    }
                  ],
                  "durationMinutes": 35,
                  "intensity": "moderate",
                  "target": "Pressing strength",
                  "order": 1,
                  "notes": null
                },
                {
                  "id": "session-1-cardio",
                  "kind": "cardio",
                  "role": "finisher",
                  "title": "Cardio Support",
                  "detail": "Easy incline walk",
                  "exercises": [],
                  "durationMinutes": 5,
                  "intensity": "easy",
                  "target": "Aerobic support",
                  "order": 2,
                  "notes": "Do not turn this into a standalone day."
                }
              ],
              "estimatedDurationMinutes": 45,
              "order": 1,
              "notes": "Strength leads."
            }
          ],
          "rationale": "Cardio is kept as a finisher.",
          "guidelines": ["Keep cardio easy."],
          "progressionStrategy": {
            "type": "doubleProgression",
            "weightIncrementKg": 2.5,
            "repsTrigger": 8,
            "description": "Add reps, then load."
          },
          "modalityProgression": {
            "focus": "mixed",
            "weeklyProgression": "Progress bench while keeping cardio easy.",
            "targets": [
              {
                "id": "bench-strength",
                "label": "Bench Press performance",
                "metric": "reps or load on bench",
                "direction": "up"
              }
            ]
          },
          "warnings": []
        }
        """

        let firstDecode = try XCTUnwrap(WorkoutPlan.fromJSON(json))
        let secondDecode = try XCTUnwrap(WorkoutPlan.fromJSON(json))
        let template = try XCTUnwrap(firstDecode.templates.first)

        XCTAssertEqual(template.sessionType, .mixed)
        XCTAssertEqual(template.displayBlocks.map(\.kind), [.strength, .cardio])
        XCTAssertEqual(template.displayBlocks.map(\.role), [.main, .finisher])
        XCTAssertEqual(template.structuredExercises.map(\.exerciseName), ["Bench Press"])
        XCTAssertEqual(firstDecode.templates.first?.id, secondDecode.templates.first?.id)
        XCTAssertEqual(firstDecode.templates.first?.blocks.first?.id, secondDecode.templates.first?.blocks.first?.id)
        XCTAssertEqual(firstDecode.modalityProgression?.targets.first?.id, secondDecode.modalityProgression?.targets.first?.id)
    }

    func testWorkoutPlanJSONRejectsFreeTextBlockKind() throws {
        let json = workoutPlanJSON(blockKind: "bouldering", blockRole: "main")

        XCTAssertNil(WorkoutPlan.fromJSON(json))
    }

    func testWorkoutPlanJSONKeepsLegacyPlacementKindCompatibility() throws {
        let warmupPlan = try XCTUnwrap(WorkoutPlan.fromJSON(workoutPlanJSON(blockKind: "warmup", blockRole: nil)))
        let warmupBlock = try XCTUnwrap(warmupPlan.templates.first?.displayBlocks.first)

        XCTAssertEqual(warmupBlock.kind, .mobility)
        XCTAssertEqual(warmupBlock.role, .warmup)

        let cooldownPlan = try XCTUnwrap(WorkoutPlan.fromJSON(workoutPlanJSON(blockKind: "cooldown", blockRole: nil)))
        let cooldownBlock = try XCTUnwrap(cooldownPlan.templates.first?.displayBlocks.first)

        XCTAssertEqual(cooldownBlock.kind, .recovery)
        XCTAssertEqual(cooldownBlock.role, .cooldown)
    }

    func testWorkoutPlanRefinementSchemaRequiresModalityFields() throws {
        let schema = AIPromptBuilder.workoutPlanRefinementSchema
        let properties = try XCTUnwrap(schema["properties"] as? [String: Any])
        let proposedPlan = try XCTUnwrap(properties["proposedPlan"] as? [String: Any])
        let planProperties = try XCTUnwrap(proposedPlan["properties"] as? [String: Any])
        let templates = try XCTUnwrap(planProperties["templates"] as? [String: Any])
        let templateSchema = try XCTUnwrap(templates["items"] as? [String: Any])
        let required = try XCTUnwrap(templateSchema["required"] as? [String])
        let envelopeRequired = try XCTUnwrap(schema["required"] as? [String])

        XCTAssertTrue(required.contains("sessionType"))
        XCTAssertTrue(required.contains("focusAreas"))
        XCTAssertTrue(required.contains("blocks"))
        XCTAssertTrue(required.contains("notes"))
        XCTAssertTrue(envelopeRequired.contains("changesWeeklySchedule"))
        XCTAssertTrue(envelopeRequired.contains("changesActivitySemantics"))

        let planIntent = try XCTUnwrap(planProperties["planIntent"] as? [String: Any])
        let planIntentRequired = try XCTUnwrap(planIntent["required"] as? [String])
        XCTAssertTrue(planIntentRequired.contains("supportiveCardioConstraint"))
    }

    @MainActor
    func testWorkoutPlanRefinementValidationPreservesCurrentPlanDayCount() {
        let currentPlan = makePlan(
            templateName: "Upper Strength",
            sessionType: .strength,
            focusAreas: ["Upper"],
            blocks: [
                WorkoutPlan.TrainingBlock(
                    kind: .strength,
                    title: "Strength",
                    detail: "Upper-body lifting",
                    activityTypeName: "Strength",
                    order: 0
                )
            ]
        )
        let shortenedPlan = WorkoutPlan(
            splitType: currentPlan.splitType,
            daysPerWeek: 1,
            templates: [],
            planIntent: currentPlan.planIntent,
            rationale: currentPlan.rationale,
            guidelines: currentPlan.guidelines,
            progressionStrategy: currentPlan.progressionStrategy,
            modalityProgression: currentPlan.modalityProgression
        )
        let wrongDaysPerWeekPlan = WorkoutPlan(
            splitType: currentPlan.splitType,
            daysPerWeek: 3,
            templates: currentPlan.templates,
            planIntent: currentPlan.planIntent,
            rationale: currentPlan.rationale,
            guidelines: currentPlan.guidelines,
            progressionStrategy: currentPlan.progressionStrategy,
            modalityProgression: currentPlan.modalityProgression
        )

        XCTAssertNil(AIService.validateRefinedWorkoutPlanForTesting(shortenedPlan, currentPlan: currentPlan))
        XCTAssertEqual(
            AIService.validateRefinedWorkoutPlanForTesting(
                wrongDaysPerWeekPlan,
                currentPlan: currentPlan
            )?.daysPerWeek,
            currentPlan.daysPerWeek
        )
    }

    @MainActor
    func testWorkoutPlanRefinementValidationAllowsStructuredDayCountChange() {
        let currentPlan = makePlan(
            templateName: "Upper Strength",
            sessionType: .strength,
            focusAreas: ["Upper"],
            blocks: [
                WorkoutPlan.TrainingBlock(
                    kind: .strength,
                    title: "Strength",
                    detail: "Upper-body lifting",
                    activityTypeName: "Strength",
                    order: 0
                )
            ]
        )
        let addedTemplate = WorkoutPlan.WorkoutTemplate(
            name: "Lower Strength",
            sessionType: .strength,
            focusAreas: ["Lower"],
            targetMuscleGroups: [],
            exercises: [],
            blocks: [
                WorkoutPlan.TrainingBlock(
                    kind: .strength,
                    title: "Strength",
                    detail: "Lower-body lifting",
                    activityTypeName: "Strength",
                    order: 0
                )
            ],
            estimatedDurationMinutes: 45,
            order: 1
        )
        let expandedPlan = WorkoutPlan(
            splitType: currentPlan.splitType,
            daysPerWeek: 1,
            templates: currentPlan.templates + [addedTemplate],
            planIntent: currentPlan.planIntent,
            rationale: currentPlan.rationale,
            guidelines: currentPlan.guidelines,
            progressionStrategy: currentPlan.progressionStrategy,
            modalityProgression: currentPlan.modalityProgression
        )

        XCTAssertNil(
            AIService.validateRefinedWorkoutPlanForTesting(
                expandedPlan,
                currentPlan: currentPlan
            )
        )
        XCTAssertEqual(
            AIService.validateRefinedWorkoutPlanForTesting(
                expandedPlan,
                currentPlan: currentPlan,
                allowsTemplateCountChange: true
            )?.daysPerWeek,
            2
        )
    }

    func testWorkoutGoalSuggestionsDropDuplicateTitles() {
        let first = makeGoalSuggestion(title: "Complete the weekly plan")
        let duplicate = makeGoalSuggestion(title: "  Complete The Weekly Plan  ")

        let validated = WorkoutGoalSuggestion.validatedUnique([first, duplicate])

        XCTAssertEqual(validated.map(\.title), ["Complete the weekly plan"])
    }

    func testWorkoutGoalSuggestionsDropUntrackableNumericGoals() {
        let untrackable = makeGoalSuggestion(
            title: "Complete the weekly habit",
            targetValue: nil,
            targetUnit: "sessions"
        )
        let trackable = makeGoalSuggestion(title: "Complete one planned habit each week")

        let validated = WorkoutGoalSuggestion.validatedUnique([untrackable, trackable])

        XCTAssertEqual(validated.map(\.title), ["Complete one planned habit each week"])
    }

    func testWorkoutGoalSuggestionsDropGoalsWithoutSuccessCriteria() {
        let vague = makeGoalSuggestion(
            title: "Improve climbing",
            goalKindRaw: WorkoutGoal.GoalKind.milestone.rawValue,
            targetValue: nil,
            targetUnit: nil,
            periodUnitRaw: nil,
            periodCount: nil,
            successCriteria: "   "
        )
        let specific = makeGoalSuggestion(
            title: "Complete the plan milestone",
            goalKindRaw: WorkoutGoal.GoalKind.milestone.rawValue,
            targetValue: nil,
            targetUnit: nil,
            periodUnitRaw: nil,
            periodCount: nil,
            successCriteria: "Complete the defined plan milestone with the criteria Trai can verify."
        )

        let validated = WorkoutGoalSuggestion.validatedUnique([vague, specific])

        XCTAssertEqual(validated.map(\.title), ["Complete the plan milestone"])
    }

    func testWorkoutGoalSuggestionsDropGoalsWithoutTrackableScope() {
        let unscoped = WorkoutGoalSuggestion(
            title: "Improve training",
            rationale: "Too broad.",
            goalKindRaw: WorkoutGoal.GoalKind.milestone.rawValue,
            linkedWorkoutTypeRaw: nil,
            linkedActivityName: nil,
            linkedActivityTags: nil,
            linkedActivityKindRaw: nil,
            linkedActivityRoleRaw: WorkoutPlan.TrainingBlock.Role.accessory.rawValue,
            targetValue: nil,
            targetUnit: nil,
            periodUnitRaw: nil,
            periodCount: nil,
            successCriteria: "You improve your training over time.",
            notes: nil,
            targetDateISO8601: nil,
            checkInCadenceDays: nil
        )
        let scoped = WorkoutGoalSuggestion(
            title: "Build climbing consistency",
            rationale: "Matches the plan.",
            goalKindRaw: WorkoutGoal.GoalKind.milestone.rawValue,
            linkedWorkoutTypeRaw: nil,
            linkedActivityName: nil,
            linkedActivityTags: ["Climbing"],
            linkedActivityKindRaw: nil,
            linkedActivityRoleRaw: nil,
            targetValue: nil,
            targetUnit: nil,
            periodUnitRaw: nil,
            periodCount: nil,
            successCriteria: "You complete the climbing work Trai places in your plan.",
            notes: nil,
            targetDateISO8601: nil,
            checkInCadenceDays: nil
        )

        let validated = WorkoutGoalSuggestion.validatedUnique([unscoped, scoped])

        XCTAssertEqual(validated.map(\.title), ["Build climbing consistency"])
    }

    func testWorkoutGoalSuggestionsKeepUnscopedPlanAdherenceFrequencyGoals() {
        let planAdherence = WorkoutGoalSuggestion(
            title: "Complete all 3 planned sessions",
            rationale: "Matches the generated weekly plan.",
            goalKindRaw: WorkoutGoal.GoalKind.frequency.rawValue,
            linkedWorkoutTypeRaw: nil,
            linkedActivityName: nil,
            linkedActivityTags: nil,
            linkedActivityKindRaw: nil,
            linkedActivityRoleRaw: nil,
            targetValue: 3,
            targetUnit: "sessions",
            periodUnitRaw: WorkoutGoal.PeriodUnit.week.rawValue,
            periodCount: 1,
            successCriteria: "You complete all three planned sessions each week.",
            notes: nil,
            targetDateISO8601: nil,
            checkInCadenceDays: nil,
            tracksGeneratedPlanAdherence: true
        )

        let validated = WorkoutGoalSuggestion.validatedUnique([planAdherence])

        XCTAssertEqual(validated.map(\.title), ["Complete all 3 planned sessions"])
    }

    func testWorkoutGoalSuggestionsKeepStructurallyTrackableWeightGoals() {
        let suggestion = makeGoalSuggestion(
            title: "Add weight to squat",
            goalKindRaw: WorkoutGoal.GoalKind.weight.rawValue,
            targetValue: 5,
            targetUnit: "kg",
            periodUnitRaw: nil,
            periodCount: nil,
            successCriteria: "You add 5 kg to your squat working weight."
        )

        let validated = WorkoutGoalSuggestion.validatedUnique([suggestion])

        XCTAssertEqual(validated.map(\.title), ["Add weight to squat"])
    }

    func testWorkoutGoalSuggestionPreservesSuccessCriteria() throws {
        let suggestion = makeGoalSuggestion(
            title: "Complete the plan milestone",
            goalKindRaw: WorkoutGoal.GoalKind.milestone.rawValue,
            targetValue: nil,
            targetUnit: nil,
            periodUnitRaw: nil,
            periodCount: nil,
            successCriteria: "Complete the defined plan milestone with the criteria Trai can verify."
        )

        let goal = try XCTUnwrap(WorkoutGoalSuggestion.validatedUnique([suggestion]).first?.asWorkoutGoal())

        XCTAssertEqual(goal.trimmedSuccessCriteria, "Complete the defined plan milestone with the criteria Trai can verify.")
        XCTAssertEqual(goal.trackingSummary, "Complete the defined plan milestone with the criteria Trai can verify.")
    }

    func testWorkoutGoalPlanSetupDeduplicationUsesStructuredTrackingFields() {
        let first = WorkoutGoal(
            title: "Hit the weekly rhythm",
            goalKind: .frequency,
            linkedWorkoutType: .mixed,
            linkedActivityTags: ["Climbing", "Technique"],
            targetValue: 2,
            targetUnit: "sessions",
            periodUnit: .week,
            periodCount: 1,
            successCriteria: "You log two climbing technique sessions each week."
        )
        let sameTrackingDifferentWords = WorkoutGoal(
            title: "Keep climbing practice consistent",
            goalKind: .frequency,
            linkedWorkoutType: .mixed,
            linkedActivityTags: ["Technique", "Climbing"],
            targetValue: 2,
            targetUnit: "sessions",
            periodUnit: .week,
            periodCount: 1,
            successCriteria: "You complete your two weekly climbing practice sessions."
        )

        XCTAssertEqual(first.planSetupDeduplicationKey, sameTrackingDifferentWords.planSetupDeduplicationKey)
    }

    func testWorkoutGoalPlanSetupDeduplicationKeepsDifferentStructuredScopesSeparate() {
        let supportBlockGoal = WorkoutGoal(
            title: "Complete cardio support",
            goalKind: .frequency,
            linkedWorkoutType: .mixed,
            linkedActivityTags: ["Cardio"],
            linkedActivityKind: .cardio,
            linkedActivityRole: .accessory,
            targetValue: 1,
            targetUnit: "blocks",
            periodUnit: .week,
            periodCount: 1,
            successCriteria: "You log the planned cardio support block each week."
        )
        let standaloneCardioGoal = WorkoutGoal(
            title: "Complete cardio support",
            goalKind: .frequency,
            linkedWorkoutType: .mixed,
            linkedActivityTags: ["Cardio"],
            linkedActivityKind: .cardio,
            linkedActivityRole: .main,
            targetValue: 1,
            targetUnit: "blocks",
            periodUnit: .week,
            periodCount: 1,
            successCriteria: "You log the planned cardio session each week."
        )

        XCTAssertNotEqual(supportBlockGoal.planSetupDeduplicationKey, standaloneCardioGoal.planSetupDeduplicationKey)
    }

    func testDurationGoalSuggestionPreservesPeriodForCumulativeTracking() throws {
        let missingPeriod = makeGoalSuggestion(
            title: "Build cardio support",
            goalKindRaw: WorkoutGoal.GoalKind.duration.rawValue,
            targetValue: 45,
            targetUnit: "min",
            periodUnitRaw: nil,
            periodCount: nil,
            successCriteria: "You log 45 minutes of cardio support in one week."
        )
        let suggestion = makeGoalSuggestion(
            title: "Build weekly cardio support",
            goalKindRaw: WorkoutGoal.GoalKind.duration.rawValue,
            targetValue: 45,
            targetUnit: "min",
            periodUnitRaw: WorkoutGoal.PeriodUnit.week.rawValue,
            periodCount: 1,
            successCriteria: "You log 45 minutes of cardio support in one week."
        )

        let goals = WorkoutGoalSuggestion.validatedUnique([missingPeriod, suggestion]).map { $0.asWorkoutGoal() }

        let goal = try XCTUnwrap(goals.first)
        XCTAssertEqual(goals.count, 1)
        XCTAssertEqual(goal.goalKind, .duration)
        XCTAssertEqual(goal.periodUnit, .week)
        XCTAssertEqual(goal.periodCount, 1)
        XCTAssertEqual(goal.trackingSummary, "45 min / week")
    }

    func testDistanceGoalSuggestionRequiresPeriodForCumulativeTracking() throws {
        let missingPeriod = makeGoalSuggestion(
            title: "Build running volume",
            goalKindRaw: WorkoutGoal.GoalKind.distance.rawValue,
            targetValue: 10,
            targetUnit: "km",
            periodUnitRaw: nil,
            periodCount: nil,
            successCriteria: "You log 10 km of running in one week."
        )
        let trackable = makeGoalSuggestion(
            title: "Build weekly running volume",
            goalKindRaw: WorkoutGoal.GoalKind.distance.rawValue,
            targetValue: 10,
            targetUnit: "km",
            periodUnitRaw: WorkoutGoal.PeriodUnit.week.rawValue,
            periodCount: 1,
            successCriteria: "You log 10 km of running in one week."
        )

        let goals = WorkoutGoalSuggestion.validatedUnique([missingPeriod, trackable]).map { $0.asWorkoutGoal() }

        let goal = try XCTUnwrap(goals.first)
        XCTAssertEqual(goals.count, 1)
        XCTAssertEqual(goal.goalKind, .distance)
        XCTAssertEqual(goal.periodUnit, .week)
        XCTAssertEqual(goal.periodCount, 1)
        XCTAssertEqual(goal.trackingSummary, "10 km / week")
    }

    func testCountGoalSuggestionRequiresAndPreservesPeriodForActivityTracking() throws {
        let missingPeriod = makeGoalSuggestion(
            title: "Build climbing attempts",
            goalKindRaw: WorkoutGoal.GoalKind.count.rawValue,
            targetValue: 12,
            targetUnit: "attempts",
            periodUnitRaw: nil,
            periodCount: nil,
            successCriteria: "You log 12 climbing attempts in one week."
        )
        let trackable = makeGoalSuggestion(
            title: "Build weekly climbing attempts",
            goalKindRaw: WorkoutGoal.GoalKind.count.rawValue,
            targetValue: 12,
            targetUnit: "attempts",
            periodUnitRaw: WorkoutGoal.PeriodUnit.week.rawValue,
            periodCount: 1,
            successCriteria: "You log 12 climbing attempts in one week."
        )

        let goals = WorkoutGoalSuggestion.validatedUnique([missingPeriod, trackable]).map { $0.asWorkoutGoal() }

        let goal = try XCTUnwrap(goals.first)
        XCTAssertEqual(goals.count, 1)
        XCTAssertEqual(goal.goalKind, .count)
        XCTAssertEqual(goal.periodUnit, .week)
        XCTAssertEqual(goal.periodCount, 1)
        XCTAssertEqual(goal.trackingSummary, "12 attempts / week")
    }

    func testWorkoutGoalContextIncludesMixedActivityMetrics() {
        let workout = LiveWorkout(name: "Strength + Climb", workoutType: .mixed)
        workout.focusAreas = ["Strength", "Climbing"]
        workout.completedAt = Date()

        let entry = LiveWorkoutEntry(
            exerciseName: "Limit Bouldering",
            orderIndex: 0,
            exerciseType: "sportPractice"
        )
        entry.activityTypeName = "Bouldering"
        entry.targetTags = ["Climbing"]
        entry.activitySegments = [
            .init(durationSeconds: 600, reps: 4),
            .init(durationSeconds: 600, reps: 3)
        ]
        workout.entries = [entry]

        let summaries = WorkoutGoalRecommendationContextBuilder.recentSessionSummaries(
            workouts: [workout],
            sessions: []
        )

        XCTAssertEqual(summaries.count, 1)
        XCTAssertTrue(summaries[0].contains("Limit Bouldering"))
        XCTAssertTrue(summaries[0].contains("Bouldering"))
        XCTAssertTrue(summaries[0].contains("20 min"))
        XCTAssertTrue(summaries[0].contains("7 attempts"))
    }

    func testWorkoutGoalExerciseSummariesIncludeActivityHistoryMetrics() throws {
        let firstEntry = LiveWorkoutEntry(
            exerciseName: "Limit Bouldering",
            orderIndex: 0,
            exerciseType: "sportPractice"
        )
        firstEntry.activityTypeName = "Bouldering"
        firstEntry.targetTags = ["Climbing"]
        firstEntry.activitySegments = [
            .init(durationSeconds: 600, reps: 4),
            .init(durationSeconds: 600, reps: 3)
        ]

        let secondEntry = LiveWorkoutEntry(
            exerciseName: "Limit Bouldering",
            orderIndex: 0,
            exerciseType: "sportPractice"
        )
        secondEntry.activityTypeName = "Bouldering"
        secondEntry.targetTags = ["Climbing"]
        secondEntry.activitySegments = [
            .init(durationSeconds: 900, reps: 5)
        ]

        let history = [
            ExerciseHistory(from: firstEntry, performedAt: Date().addingTimeInterval(-86_400)),
            ExerciseHistory(from: secondEntry, performedAt: Date())
        ]

        let summaries = WorkoutGoalRecommendationContextBuilder.exerciseSummaries(
            history: history,
            prefersMetricWeight: true
        )

        let summary = try XCTUnwrap(summaries.first)
        XCTAssertTrue(summary.contains("Limit Bouldering: 2 sessions"))
        XCTAssertTrue(summary.contains("Bouldering"))
        XCTAssertTrue(summary.contains("35 min total"))
        XCTAssertTrue(summary.contains("12 attempts total"))
    }

    func testWorkoutTemplateDisplayBlocksSortByDeclaredOrder() {
        let template = WorkoutPlan.WorkoutTemplate(
            name: "Hybrid Day",
            sessionType: .mixed,
            focusAreas: ["Hybrid"],
            targetMuscleGroups: [],
            exercises: [],
            blocks: [
                WorkoutPlan.TrainingBlock(
                    kind: .cardio,
                    role: .finisher,
                    title: "Finisher",
                    detail: "Bike",
                    order: 2
                ),
                WorkoutPlan.TrainingBlock(
                    kind: .mobility,
                    role: .warmup,
                    title: "Warmup",
                    detail: "Move",
                    order: 0
                ),
                WorkoutPlan.TrainingBlock(
                    kind: .strength,
                    title: "Strength",
                    detail: "Lift",
                    order: 1
                )
            ],
            estimatedDurationMinutes: 45,
            order: 0
        )

        XCTAssertEqual(template.displayBlocks.map(\.title), ["Warmup", "Strength", "Finisher"])
        XCTAssertEqual(template.displayBlocks.map(\.order), [0, 1, 2])
    }

    func testRequiredActivityIdentitiesIncludeExplicitCardioAndCustomSelections() {
        let request = makeRequest(
            selectedWorkoutTypes: [.strength, .cardio],
            conversationContext: ["Personalization brief (highest priority): include climbing performance"],
            cardioTypes: [.climbing, .anyCardio],
            availableDays: 3
        )

        XCTAssertTrue(request.requiredVisibleActivityIdentityGroups.contains { $0.contains("Climbing") })
        XCTAssertFalse(request.requiredVisibleActivityIdentityGroups.contains { $0.contains("Any / No Preference") })
    }

    func testWorkoutPlanVisibleActivityIdentityMatchesSpecificActivityAliases() {
        let plan = makePlan(
            templateName: "Bouldering + Strength",
            sessionType: .mixed,
            focusAreas: ["Bouldering", "Upper Strength"],
            blocks: [
                WorkoutPlan.TrainingBlock(
                    kind: .sportPractice,
                    title: "Limit Bouldering",
                    detail: "Focused attempts",
                    activityTypeName: "Bouldering",
                    activityTags: ["Climbing", "Power"],
                    durationMinutes: 35,
                    order: 0
                )
            ]
        )

        XCTAssertTrue(plan.containsVisibleActivityIdentity(matching: ["Climbing", "Bouldering", "Climb"]))
        XCTAssertFalse(plan.containsVisibleActivityIdentity(matching: ["Cycling", "Bike"]))
    }

    func testWorkoutPlanVisibleActivityIdentityRequiresExactSemanticValue() {
        let plan = makePlan(
            templateName: "Trunk Rotation",
            sessionType: .strength,
            focusAreas: ["Trunk"],
            blocks: [
                WorkoutPlan.TrainingBlock(
                    kind: .strength,
                    title: "Trunk Rotation",
                    detail: "Core control",
                    activityTypeName: "Strength",
                    activityTags: ["Core"],
                    order: 0
                )
            ]
        )

        XCTAssertFalse(plan.containsVisibleActivityIdentity(matching: ["Running", "Run"]))
    }

    func testWorkoutPlanVisibleActivityIdentityIgnoresBroadBlockKindLabels() {
        let plan = makePlan(
            templateName: "Conditioning Support",
            sessionType: .mixed,
            focusAreas: ["Athletic support"],
            blocks: [
                WorkoutPlan.TrainingBlock(
                    kind: .conditioning,
                    title: "Conditioning",
                    detail: "Short support work",
                    activityTypeName: "Athletic Support",
                    order: 0
                )
            ]
        )

        XCTAssertFalse(plan.containsVisibleActivityIdentity(matching: ["HIIT", "Intervals"]))
    }

    @MainActor
    func testWorkoutPlanValidationRejectsBlocksWithoutAuthoredActivityIdentity() {
        let request = makeRequest(workoutType: .mixed, selectedWorkoutTypes: [.strength], availableDays: 1)
        let plan = makePlan(
            templateName: "Upper Strength",
            sessionType: .strength,
            focusAreas: ["Upper"],
            blocks: [
                WorkoutPlan.TrainingBlock(
                    kind: .strength,
                    title: "Strength",
                    detail: "Upper-body lifting",
                    order: 0
                )
            ]
        )

        XCTAssertThrowsError(try AIService.validateGeneratedWorkoutPlanForTesting(plan, request: request))
    }

    func testRequestReportsMissingExplicitActivityIdentityFromPlanStructure() {
        let request = makeRequest(
            selectedWorkoutTypes: [.strength, .cardio],
            cardioTypes: [.climbing],
            availableDays: 3
        )
        let genericStrengthPlan = makePlan(
            templateName: "Upper Strength",
            sessionType: .strength,
            focusAreas: ["Upper"],
            blocks: [
                WorkoutPlan.TrainingBlock(
                    kind: .strength,
                    title: "Strength",
                    detail: "Upper-body lifting",
                    activityTypeName: "Strength",
                    activityTags: ["Upper"],
                    order: 0
                )
            ]
        )

        XCTAssertEqual(request.missingVisibleActivityIdentityDescriptions(in: genericStrengthPlan), ["Climbing"])
    }

    @MainActor
    func testWorkoutPlanRefinementRejectsDroppedActivitySemantics() {
        let currentPlan = makePlan(
            templateName: "Climbing Skill",
            sessionType: .mixed,
            focusAreas: ["Climbing"],
            blocks: [
                WorkoutPlan.TrainingBlock(
                    kind: .skill,
                    title: "Limit Bouldering",
                    detail: "Skill work",
                    activityTypeName: "Bouldering",
                    activityTags: ["Climbing"],
                    order: 0
                )
            ]
        )
        let genericPlan = makePlan(
            templateName: "Strength",
            sessionType: .strength,
            focusAreas: ["Strength"],
            blocks: [
                WorkoutPlan.TrainingBlock(
                    kind: .strength,
                    title: "Strength",
                    detail: "Generic lifting",
                    activityTypeName: "Strength",
                    order: 0
                )
            ]
        )

        XCTAssertNil(AIService.validateRefinedWorkoutPlanForTesting(genericPlan, currentPlan: currentPlan))
    }

    @MainActor
    func testWorkoutPlanRefinementRejectsDroppedDurableBlockTagsWithoutSemanticChange() {
        let templateID = UUID()
        let blockID = UUID()
        let currentPlan = makePlan(
            templateID: templateID,
            templateName: "Climbing Skill",
            sessionType: .mixed,
            focusAreas: ["Climbing"],
            blocks: [
                WorkoutPlan.TrainingBlock(
                    id: blockID,
                    kind: .skill,
                    title: "Limit Bouldering",
                    detail: "Skill work",
                    activityTypeName: "Bouldering",
                    activityTags: ["Climbing", "Power"],
                    order: 0
                )
            ]
        )
        let planWithDroppedTags = makePlan(
            templateID: templateID,
            templateName: "Climbing Skill",
            sessionType: .mixed,
            focusAreas: ["Climbing"],
            blocks: [
                WorkoutPlan.TrainingBlock(
                    id: blockID,
                    kind: .skill,
                    title: "Limit Bouldering",
                    detail: "Skill work",
                    activityTypeName: "Bouldering",
                    activityTags: ["Climbing"],
                    order: 0
                )
            ]
        )

        XCTAssertNil(AIService.validateRefinedWorkoutPlanForTesting(planWithDroppedTags, currentPlan: currentPlan))
        XCTAssertNil(
            AIService.validateRefinedWorkoutPlanForTesting(
                planWithDroppedTags,
                currentPlan: currentPlan,
                allowsActivitySemanticChange: true
            )
        )
        XCTAssertNotNil(
            AIService.validateRefinedWorkoutPlanForTesting(
                planWithDroppedTags,
                currentPlan: currentPlan,
                allowsActivitySemanticChange: true,
                changedBlockIDs: [blockID]
            )
        )
    }

    @MainActor
    func testWorkoutPlanRefinementRejectsChangedDurableBlockIDWithoutSemanticChange() {
        let currentPlan = makePlan(
            templateName: "Climbing Skill",
            sessionType: .mixed,
            focusAreas: ["Climbing"],
            blocks: [
                WorkoutPlan.TrainingBlock(
                    kind: .skill,
                    title: "Limit Bouldering",
                    detail: "Skill work",
                    activityTypeName: "Bouldering",
                    activityTags: ["Climbing"],
                    order: 0
                )
            ]
        )
        let changedIDPlan = makePlan(
            templateName: "Climbing Skill",
            sessionType: .mixed,
            focusAreas: ["Climbing"],
            blocks: [
                WorkoutPlan.TrainingBlock(
                    kind: .skill,
                    title: "Limit Bouldering",
                    detail: "Skill work",
                    activityTypeName: "Bouldering",
                    activityTags: ["Climbing"],
                    order: 0
                )
            ]
        )

        XCTAssertNil(AIService.validateRefinedWorkoutPlanForTesting(changedIDPlan, currentPlan: currentPlan))
    }

    @MainActor
    func testWorkoutPlanRefinementRejectsChangedTemplateIDWithoutSemanticChange() {
        let templateID = UUID()
        let blockID = UUID()
        let currentPlan = makePlan(
            templateID: templateID,
            templateName: "Climbing Skill",
            sessionType: .mixed,
            focusAreas: ["Climbing"],
            blocks: [
                WorkoutPlan.TrainingBlock(
                    id: blockID,
                    kind: .skill,
                    title: "Limit Bouldering",
                    detail: "Skill work",
                    activityTypeName: "Bouldering",
                    activityTags: ["Climbing"],
                    order: 0
                )
            ]
        )
        let changedTemplateIDPlan = makePlan(
            templateID: UUID(),
            templateName: "Climbing Skill",
            sessionType: .mixed,
            focusAreas: ["Climbing"],
            blocks: [
                WorkoutPlan.TrainingBlock(
                    id: blockID,
                    kind: .skill,
                    title: "Limit Bouldering",
                    detail: "Skill work",
                    activityTypeName: "Bouldering",
                    activityTags: ["Climbing"],
                    order: 0
                )
            ]
        )

        XCTAssertNil(AIService.validateRefinedWorkoutPlanForTesting(changedTemplateIDPlan, currentPlan: currentPlan))
    }

    @MainActor
    func testWorkoutPlanRefinementRejectsChangedTemplateIDWithActivitySemanticChange() {
        let templateID = UUID()
        let blockID = UUID()
        let currentPlan = makePlan(
            templateID: templateID,
            templateName: "Climbing Skill",
            sessionType: .mixed,
            focusAreas: ["Climbing"],
            blocks: [
                WorkoutPlan.TrainingBlock(
                    id: blockID,
                    kind: .skill,
                    title: "Limit Bouldering",
                    detail: "Skill work",
                    activityTypeName: "Bouldering",
                    activityTags: ["Climbing"],
                    order: 0
                )
            ]
        )
        let changedTemplateIDPlan = makePlan(
            templateID: UUID(),
            templateName: "Climbing + Mobility",
            sessionType: .mixed,
            focusAreas: ["Climbing", "Mobility"],
            blocks: [
                WorkoutPlan.TrainingBlock(
                    id: blockID,
                    kind: .skill,
                    title: "Limit Bouldering",
                    detail: "Skill work",
                    activityTypeName: "Bouldering",
                    activityTags: ["Climbing"],
                    order: 0
                ),
                WorkoutPlan.TrainingBlock(
                    kind: .mobility,
                    role: .cooldown,
                    title: "Mobility Cooldown",
                    detail: "Shoulder and hip mobility",
                    activityTypeName: "Mobility Flow",
                    activityTags: ["Mobility"],
                    order: 1
                )
            ]
        )

        XCTAssertNil(
            AIService.validateRefinedWorkoutPlanForTesting(
                changedTemplateIDPlan,
                currentPlan: currentPlan,
                allowsActivitySemanticChange: true
            )
        )
    }

    @MainActor
    func testWorkoutPlanRefinementRejectsScheduleReductionThatDropsUnchangedTemplateSemantics() {
        let keptTemplateID = UUID()
        let removedTemplateID = UUID()
        let keptBlockID = UUID()
        let removedBlockID = UUID()
        let keptTemplate = WorkoutPlan.WorkoutTemplate(
            id: keptTemplateID,
            name: "Upper Strength",
            sessionType: .strength,
            focusAreas: ["Upper"],
            targetMuscleGroups: [],
            exercises: [],
            blocks: [
                WorkoutPlan.TrainingBlock(
                    id: keptBlockID,
                    kind: .strength,
                    title: "Strength",
                    detail: "Upper-body lifting",
                    activityTypeName: "Strength",
                    activityTags: ["Upper"],
                    order: 0
                )
            ],
            estimatedDurationMinutes: 45,
            order: 0
        )
        let removedTemplate = WorkoutPlan.WorkoutTemplate(
            id: removedTemplateID,
            name: "Lower Strength",
            sessionType: .strength,
            focusAreas: ["Lower"],
            targetMuscleGroups: [],
            exercises: [],
            blocks: [
                WorkoutPlan.TrainingBlock(
                    id: removedBlockID,
                    kind: .strength,
                    title: "Strength",
                    detail: "Lower-body lifting",
                    activityTypeName: "Strength",
                    activityTags: ["Lower"],
                    order: 0
                )
            ],
            estimatedDurationMinutes: 45,
            order: 1
        )
        let currentPlan = makePlan(templates: [keptTemplate, removedTemplate], daysPerWeek: 2)
        let reducedPlan = makePlan(templates: [keptTemplate], daysPerWeek: 2)

        XCTAssertNil(
            AIService.validateRefinedWorkoutPlanForTesting(
                reducedPlan,
                currentPlan: currentPlan,
                allowsTemplateCountChange: true
            )
        )
    }

    @MainActor
    func testWorkoutPlanRefinementAllowsExplicitScheduleReductionToDropChangedTemplate() {
        let keptTemplateID = UUID()
        let removedTemplateID = UUID()
        let keptBlockID = UUID()
        let removedBlockID = UUID()
        let keptTemplate = WorkoutPlan.WorkoutTemplate(
            id: keptTemplateID,
            name: "Upper Strength",
            sessionType: .strength,
            focusAreas: ["Upper"],
            targetMuscleGroups: [],
            exercises: [],
            blocks: [
                WorkoutPlan.TrainingBlock(
                    id: keptBlockID,
                    kind: .strength,
                    title: "Strength",
                    detail: "Upper-body lifting",
                    activityTypeName: "Strength",
                    activityTags: ["Upper"],
                    order: 0
                )
            ],
            estimatedDurationMinutes: 45,
            order: 0
        )
        let removedTemplate = WorkoutPlan.WorkoutTemplate(
            id: removedTemplateID,
            name: "Lower Strength",
            sessionType: .strength,
            focusAreas: ["Lower"],
            targetMuscleGroups: [],
            exercises: [],
            blocks: [
                WorkoutPlan.TrainingBlock(
                    id: removedBlockID,
                    kind: .strength,
                    title: "Strength",
                    detail: "Lower-body lifting",
                    activityTypeName: "Strength",
                    activityTags: ["Lower"],
                    order: 0
                )
            ],
            estimatedDurationMinutes: 45,
            order: 1
        )
        let currentPlan = makePlan(templates: [keptTemplate, removedTemplate], daysPerWeek: 2)
        let reducedPlan = makePlan(templates: [keptTemplate], daysPerWeek: 2)

        let validated = AIService.validateRefinedWorkoutPlanForTesting(
            reducedPlan,
            currentPlan: currentPlan,
            allowsTemplateCountChange: true,
            allowsActivitySemanticChange: true,
            changedTemplateIDs: [removedTemplateID]
        )

        XCTAssertEqual(validated?.templates.map(\.id), [keptTemplateID])
        XCTAssertEqual(validated?.daysPerWeek, 1)
    }

    @MainActor
    func testWorkoutPlanRefinementAllowsScheduleReductionThatMovesRemovedTemplateBlock() {
        let keptTemplateID = UUID()
        let removedTemplateID = UUID()
        let keptBlockID = UUID()
        let movedBlockID = UUID()
        let keptTemplate = WorkoutPlan.WorkoutTemplate(
            id: keptTemplateID,
            name: "Upper Strength",
            sessionType: .strength,
            focusAreas: ["Upper"],
            targetMuscleGroups: [],
            exercises: [],
            blocks: [
                WorkoutPlan.TrainingBlock(
                    id: keptBlockID,
                    kind: .strength,
                    title: "Strength",
                    detail: "Upper-body lifting",
                    activityTypeName: "Strength",
                    activityTags: ["Upper"],
                    order: 0
                )
            ],
            estimatedDurationMinutes: 45,
            order: 0
        )
        let removedTemplate = WorkoutPlan.WorkoutTemplate(
            id: removedTemplateID,
            name: "Bouldering Skill",
            sessionType: .climbing,
            focusAreas: ["Climbing"],
            targetMuscleGroups: [],
            exercises: [],
            blocks: [
                WorkoutPlan.TrainingBlock(
                    id: movedBlockID,
                    kind: .skill,
                    title: "Limit Bouldering",
                    detail: "Climbing skill work",
                    activityTypeName: "Bouldering",
                    activityTags: ["Climbing"],
                    order: 0
                )
            ],
            estimatedDurationMinutes: 45,
            order: 1
        )
        let mergedTemplate = WorkoutPlan.WorkoutTemplate(
            id: keptTemplateID,
            name: "Upper Strength + Bouldering",
            sessionType: .mixed,
            focusAreas: ["Upper", "Climbing"],
            targetMuscleGroups: [],
            exercises: [],
            blocks: keptTemplate.blocks + [
                WorkoutPlan.TrainingBlock(
                    id: movedBlockID,
                    kind: .skill,
                    title: "Limit Bouldering",
                    detail: "Climbing skill work",
                    activityTypeName: "Bouldering",
                    activityTags: ["Climbing"],
                    order: 1
                )
            ],
            estimatedDurationMinutes: 60,
            order: 0
        )
        let currentPlan = makePlan(templates: [keptTemplate, removedTemplate], daysPerWeek: 2)
        let reducedPlan = makePlan(templates: [mergedTemplate], daysPerWeek: 1)

        let validated = AIService.validateRefinedWorkoutPlanForTesting(
            reducedPlan,
            currentPlan: currentPlan,
            allowsTemplateCountChange: true
        )

        XCTAssertEqual(validated?.templates.map(\.id), [keptTemplateID])
        XCTAssertEqual(validated?.templates.first?.blocks.map(\.id), [keptBlockID, movedBlockID])
    }

    @MainActor
    func testWorkoutPlanRefinementRejectsDuplicateTemplateIDsWhenAddingSchedule() {
        let upperTemplate = WorkoutPlan.WorkoutTemplate(
            id: UUID(),
            name: "Upper Strength",
            sessionType: .strength,
            focusAreas: ["Upper"],
            targetMuscleGroups: [],
            exercises: [],
            blocks: [
                WorkoutPlan.TrainingBlock(
                    id: UUID(),
                    kind: .strength,
                    title: "Upper Strength",
                    detail: "Upper-body lifting",
                    activityTypeName: "Strength",
                    activityTags: ["Upper"],
                    order: 0
                )
            ],
            estimatedDurationMinutes: 45,
            order: 0
        )
        let lowerTemplate = WorkoutPlan.WorkoutTemplate(
            id: UUID(),
            name: "Lower Strength",
            sessionType: .strength,
            focusAreas: ["Lower"],
            targetMuscleGroups: [],
            exercises: [],
            blocks: [
                WorkoutPlan.TrainingBlock(
                    id: UUID(),
                    kind: .strength,
                    title: "Lower Strength",
                    detail: "Lower-body lifting",
                    activityTypeName: "Strength",
                    activityTags: ["Lower"],
                    order: 0
                )
            ],
            estimatedDurationMinutes: 45,
            order: 1
        )
        let currentPlan = makePlan(templates: [upperTemplate, lowerTemplate], daysPerWeek: 2)
        let duplicatedPlan = makePlan(
            templates: [upperTemplate, lowerTemplate, lowerTemplate],
            daysPerWeek: 3
        )

        XCTAssertNil(
            AIService.validateRefinedWorkoutPlanForTesting(
                duplicatedPlan,
                currentPlan: currentPlan,
                allowsTemplateCountChange: true
            )
        )
    }

    @MainActor
    func testWorkoutPlanRefinementAllowsScopedSupportCardioRemoval() {
        let templateID = UUID()
        let strengthBlockID = UUID()
        let cardioBlockID = UUID()
        let currentTemplate = WorkoutPlan.WorkoutTemplate(
            id: templateID,
            name: "Upper + Finisher",
            sessionType: .mixed,
            focusAreas: ["Upper", "Cardio"],
            targetMuscleGroups: [],
            exercises: [],
            blocks: [
                WorkoutPlan.TrainingBlock(
                    id: strengthBlockID,
                    kind: .strength,
                    title: "Upper Strength",
                    detail: "Pressing and pulling",
                    activityTypeName: "Strength",
                    activityTags: ["Upper"],
                    order: 0
                ),
                WorkoutPlan.TrainingBlock(
                    id: cardioBlockID,
                    kind: .cardio,
                    role: .finisher,
                    title: "Bike Finisher",
                    detail: "Easy conditioning",
                    activityTypeName: "Cycling",
                    activityTags: ["Cardio"],
                    order: 1
                )
            ],
            estimatedDurationMinutes: 55,
            order: 0
        )
        let currentPlan = makePlan(
            templates: [currentTemplate],
            daysPerWeek: 1,
            planIntent: WorkoutPlan.PlanIntent(
                primaryFocus: "Strength",
                sessionAllocation: "One strength session with a cardio finisher",
                supportiveCardioConstraint: .init(role: .finisher, maximumPlacements: 1),
                summary: "Strength with one cardio finisher."
            )
        )
        let updatedTemplate = WorkoutPlan.WorkoutTemplate(
            id: templateID,
            name: "Upper Strength",
            sessionType: .strength,
            focusAreas: ["Upper"],
            targetMuscleGroups: [],
            exercises: [],
            blocks: [
                WorkoutPlan.TrainingBlock(
                    id: strengthBlockID,
                    kind: .strength,
                    title: "Upper Strength",
                    detail: "Pressing and pulling",
                    activityTypeName: "Strength",
                    activityTags: ["Upper"],
                    order: 0
                )
            ],
            estimatedDurationMinutes: 45,
            order: 0
        )
        let updatedPlan = makePlan(
            templates: [updatedTemplate],
            daysPerWeek: 1,
            planIntent: WorkoutPlan.PlanIntent(
                primaryFocus: "Strength",
                sessionAllocation: "One strength session",
                supportiveCardioConstraint: nil,
                summary: "Strength only."
            )
        )

        XCTAssertNil(
            AIService.validateRefinedWorkoutPlanForTesting(
                updatedPlan,
                currentPlan: currentPlan,
                allowsActivitySemanticChange: true
            )
        )
        XCTAssertNotNil(
            AIService.validateRefinedWorkoutPlanForTesting(
                updatedPlan,
                currentPlan: currentPlan,
                allowsActivitySemanticChange: true,
                changedBlockIDs: [cardioBlockID]
            )
        )
    }

    @MainActor
    func testWorkoutPlanRefinementRejectsChangedTemplateBypassForRetainedBlockSemantics() {
        let templateID = UUID()
        let strengthBlockID = UUID()
        let cardioBlockID = UUID()
        let currentTemplate = WorkoutPlan.WorkoutTemplate(
            id: templateID,
            name: "Upper + Finisher",
            sessionType: .mixed,
            focusAreas: ["Upper", "Cardio"],
            targetMuscleGroups: [],
            exercises: [],
            blocks: [
                WorkoutPlan.TrainingBlock(
                    id: strengthBlockID,
                    kind: .strength,
                    title: "Upper Strength",
                    detail: "Pressing and pulling",
                    activityTypeName: "Strength",
                    activityTags: ["Upper"],
                    order: 0
                ),
                WorkoutPlan.TrainingBlock(
                    id: cardioBlockID,
                    kind: .cardio,
                    role: .finisher,
                    title: "Bike Finisher",
                    detail: "Easy conditioning",
                    activityTypeName: "Cycling",
                    activityTags: ["Cardio"],
                    order: 1
                )
            ],
            estimatedDurationMinutes: 55,
            order: 0
        )
        let currentPlan = makePlan(templates: [currentTemplate], daysPerWeek: 1)
        let mutatedTemplate = WorkoutPlan.WorkoutTemplate(
            id: templateID,
            name: "Upper Strength",
            sessionType: .strength,
            focusAreas: ["Upper"],
            targetMuscleGroups: [],
            exercises: [],
            blocks: [
                WorkoutPlan.TrainingBlock(
                    id: strengthBlockID,
                    kind: .mobility,
                    title: "Mobility Flow",
                    detail: "Unrequested mutation",
                    activityTypeName: "Mobility Flow",
                    activityTags: ["Mobility"],
                    order: 0
                )
            ],
            estimatedDurationMinutes: 45,
            order: 0
        )
        let mutatedPlan = makePlan(templates: [mutatedTemplate], daysPerWeek: 1)

        XCTAssertNil(
            AIService.validateRefinedWorkoutPlanForTesting(
                mutatedPlan,
                currentPlan: currentPlan,
                allowsActivitySemanticChange: true,
                changedTemplateIDs: [templateID],
                changedBlockIDs: [cardioBlockID]
            )
        )
    }

    @MainActor
    func testWorkoutPlanRefinementRejectsDroppedLegacyExerciseOnlyActivitySemantics() {
        let exercise = WorkoutPlan.ExerciseTemplate(
            exerciseName: "Limit Bouldering",
            muscleGroup: "forearms",
            defaultSets: 4,
            defaultReps: 5,
            order: 0
        )
        let legacyTemplate = WorkoutPlan.WorkoutTemplate(
            name: "Bouldering Day",
            sessionType: .climbing,
            focusAreas: ["Bouldering", "Climbing"],
            targetMuscleGroups: ["forearms"],
            exercises: [exercise],
            blocks: [],
            estimatedDurationMinutes: 45,
            order: 0
        )
        let currentPlan = WorkoutPlan(
            splitType: .custom,
            daysPerWeek: 1,
            templates: [legacyTemplate],
            planIntent: WorkoutPlan.PlanIntent(
                primaryFocus: "Climbing",
                sessionAllocation: "One climbing session",
                summary: "Climbing stays in the plan."
            ),
            rationale: "Legacy climbing plan",
            guidelines: [],
            progressionStrategy: .defaultStrategy,
            modalityProgression: WorkoutPlan.ModalityProgression(
                focus: .skill,
                weeklyProgression: "Build climbing volume.",
                targets: []
            )
        )
        let genericPlan = makePlan(
            templateID: legacyTemplate.id,
            templateName: "Strength",
            sessionType: .strength,
            focusAreas: ["Strength"],
            blocks: [
                WorkoutPlan.TrainingBlock(
                    kind: .strength,
                    title: "Strength",
                    detail: "Generic lifting",
                    activityTypeName: "Strength",
                    order: 0
                )
            ]
        )

        XCTAssertNil(AIService.validateRefinedWorkoutPlanForTesting(genericPlan, currentPlan: currentPlan))
    }

    @MainActor
    func testWorkoutPlanRefinementRejectsMovedLegacyDisplayActivityIdentity() {
        let climbingTemplateID = UUID()
        let strengthTemplateID = UUID()
        let climbingTemplate = WorkoutPlan.WorkoutTemplate(
            id: climbingTemplateID,
            name: "Bouldering Day",
            sessionType: .climbing,
            focusAreas: ["Bouldering", "Climbing"],
            targetMuscleGroups: ["forearms"],
            exercises: [
                .init(exerciseName: "Limit Bouldering", muscleGroup: "forearms", defaultSets: 4, defaultReps: 5, order: 0)
            ],
            blocks: [],
            estimatedDurationMinutes: 45,
            order: 0
        )
        let strengthTemplate = WorkoutPlan.WorkoutTemplate(
            id: strengthTemplateID,
            name: "Upper Strength",
            sessionType: .strength,
            focusAreas: ["Upper"],
            targetMuscleGroups: ["chest"],
            exercises: [
                .init(exerciseName: "Bench Press", muscleGroup: "chest", defaultSets: 3, defaultReps: 8, order: 0)
            ],
            blocks: [],
            estimatedDurationMinutes: 45,
            order: 1
        )
        let currentPlan = makePlan(templates: [climbingTemplate, strengthTemplate], daysPerWeek: 2)
        let mutatedClimbingTemplate = WorkoutPlan.WorkoutTemplate(
            id: climbingTemplateID,
            name: "Generic Strength",
            sessionType: .strength,
            focusAreas: ["Strength"],
            targetMuscleGroups: ["legs"],
            exercises: [
                .init(exerciseName: "Back Squat", muscleGroup: "legs", defaultSets: 3, defaultReps: 8, order: 0)
            ],
            blocks: [],
            estimatedDurationMinutes: 45,
            order: 0
        )
        let movedIdentityTemplate = WorkoutPlan.WorkoutTemplate(
            id: strengthTemplateID,
            name: "Upper Strength + Bouldering",
            sessionType: .mixed,
            focusAreas: ["Upper", "Bouldering"],
            targetMuscleGroups: ["chest"],
            exercises: [
                .init(exerciseName: "Bench Press", muscleGroup: "chest", defaultSets: 3, defaultReps: 8, order: 0),
                .init(exerciseName: "Limit Bouldering", muscleGroup: "forearms", defaultSets: 4, defaultReps: 5, order: 1)
            ],
            blocks: [],
            estimatedDurationMinutes: 60,
            order: 1
        )
        let mutatedPlan = makePlan(templates: [mutatedClimbingTemplate, movedIdentityTemplate], daysPerWeek: 2)

        XCTAssertNil(AIService.validateRefinedWorkoutPlanForTesting(mutatedPlan, currentPlan: currentPlan))
    }

    @MainActor
    func testWorkoutPlanRefinementRejectsMovedAuthoredBlockToDifferentTemplate() {
        let climbingTemplateID = UUID()
        let strengthTemplateID = UUID()
        let climbingBlockID = UUID()
        let strengthBlockID = UUID()
        let climbingTemplate = WorkoutPlan.WorkoutTemplate(
            id: climbingTemplateID,
            name: "Climbing Skill",
            sessionType: .mixed,
            focusAreas: ["Climbing"],
            targetMuscleGroups: [],
            exercises: [],
            blocks: [
                WorkoutPlan.TrainingBlock(
                    id: climbingBlockID,
                    kind: .skill,
                    title: "Limit Bouldering",
                    detail: "Board climbing",
                    activityTypeName: "Bouldering",
                    activityTags: ["Climbing", "Power"],
                    order: 0
                )
            ],
            estimatedDurationMinutes: 45,
            order: 0
        )
        let strengthTemplate = WorkoutPlan.WorkoutTemplate(
            id: strengthTemplateID,
            name: "Upper Strength",
            sessionType: .strength,
            focusAreas: ["Upper"],
            targetMuscleGroups: [],
            exercises: [],
            blocks: [
                WorkoutPlan.TrainingBlock(
                    id: strengthBlockID,
                    kind: .strength,
                    title: "Upper Strength",
                    detail: "Pressing volume",
                    activityTypeName: "Strength",
                    activityTags: ["Upper"],
                    order: 0
                )
            ],
            estimatedDurationMinutes: 45,
            order: 1
        )
        let currentPlan = makePlan(templates: [climbingTemplate, strengthTemplate], daysPerWeek: 2)
        let mutatedClimbingTemplate = WorkoutPlan.WorkoutTemplate(
            id: climbingTemplateID,
            name: "Generic Strength",
            sessionType: .strength,
            focusAreas: ["Strength"],
            targetMuscleGroups: [],
            exercises: [],
            blocks: [
                WorkoutPlan.TrainingBlock(
                    kind: .strength,
                    title: "Generic Strength",
                    detail: "Unrequested replacement",
                    activityTypeName: "Strength",
                    activityTags: ["Strength"],
                    order: 0
                )
            ],
            estimatedDurationMinutes: 45,
            order: 0
        )
        let mutatedStrengthTemplate = WorkoutPlan.WorkoutTemplate(
            id: strengthTemplateID,
            name: "Upper Strength + Climbing",
            sessionType: .mixed,
            focusAreas: ["Upper", "Climbing"],
            targetMuscleGroups: [],
            exercises: [],
            blocks: [
                WorkoutPlan.TrainingBlock(
                    id: strengthBlockID,
                    kind: .strength,
                    title: "Upper Strength",
                    detail: "Pressing volume",
                    activityTypeName: "Strength",
                    activityTags: ["Upper"],
                    order: 0
                ),
                WorkoutPlan.TrainingBlock(
                    id: climbingBlockID,
                    kind: .skill,
                    title: "Limit Bouldering",
                    detail: "Board climbing",
                    activityTypeName: "Bouldering",
                    activityTags: ["Climbing", "Power"],
                    order: 1
                )
            ],
            estimatedDurationMinutes: 60,
            order: 1
        )
        let mutatedPlan = makePlan(
            templates: [mutatedClimbingTemplate, mutatedStrengthTemplate],
            daysPerWeek: 2
        )

        XCTAssertNil(AIService.validateRefinedWorkoutPlanForTesting(mutatedPlan, currentPlan: currentPlan))
    }

    @MainActor
    func testWorkoutPlanRefinementRejectsDroppedExplicitStrengthMainActivityNameWithoutTags() {
        let templateID = UUID()
        let blockID = UUID()
        let currentPlan = makePlan(
            templateID: templateID,
            templateName: "Bouldering Strength",
            sessionType: .strength,
            focusAreas: ["Bouldering"],
            blocks: [
                WorkoutPlan.TrainingBlock(
                    id: blockID,
                    kind: .strength,
                    title: "Limit Bouldering",
                    detail: "Board climbing",
                    activityTypeName: "Bouldering",
                    activityTags: [],
                    order: 0
                )
            ]
        )
        let genericPlan = makePlan(
            templateID: templateID,
            templateName: "Bouldering Strength",
            sessionType: .strength,
            focusAreas: ["Bouldering"],
            blocks: [
                WorkoutPlan.TrainingBlock(
                    id: blockID,
                    kind: .strength,
                    title: "Strength",
                    detail: "Generic lifting",
                    activityTypeName: "Strength",
                    activityTags: [],
                    order: 0
                )
            ]
        )

        XCTAssertNil(AIService.validateRefinedWorkoutPlanForTesting(genericPlan, currentPlan: currentPlan))
    }

    @MainActor
    func testWorkoutPlanRefinementRejectsDroppedManualActivityFocusWithoutAuthoredBlocks() {
        let currentPlan = makePlan(
            templateName: "Bouldering Day",
            sessionType: .climbing,
            focusAreas: ["Bouldering", "Climbing"],
            blocks: []
        )
        let genericPlan = makePlan(
            templateName: "Strength",
            sessionType: .strength,
            focusAreas: ["Strength"],
            blocks: [
                WorkoutPlan.TrainingBlock(
                    kind: .strength,
                    title: "Strength",
                    detail: "Generic lifting",
                    activityTypeName: "Strength",
                    order: 0
                )
            ]
        )

        XCTAssertNil(AIService.validateRefinedWorkoutPlanForTesting(genericPlan, currentPlan: currentPlan))
    }

    @MainActor
    func testWorkoutPlanRefinementAllowsExplicitActivitySemanticChange() {
        let templateID = UUID()
        let blockID = UUID()
        let currentPlan = makePlan(
            templateID: templateID,
            templateName: "Climbing Skill",
            sessionType: .mixed,
            focusAreas: ["Climbing"],
            blocks: [
                WorkoutPlan.TrainingBlock(
                    id: blockID,
                    kind: .skill,
                    title: "Limit Bouldering",
                    detail: "Skill work",
                    activityTypeName: "Bouldering",
                    activityTags: ["Climbing"],
                    order: 0
                )
            ]
        )
        let mobilityPlan = makePlan(
            templateID: templateID,
            templateName: "Mobility Flow",
            sessionType: .mobility,
            focusAreas: ["Mobility"],
            blocks: [
                WorkoutPlan.TrainingBlock(
                    kind: .mobility,
                    title: "Mobility Flow",
                    detail: "Replace climbing with mobility work.",
                    activityTypeName: "Mobility Flow",
                    activityTags: ["Mobility"],
                    order: 0
                )
            ]
        )

        XCTAssertNotNil(
            AIService.validateRefinedWorkoutPlanForTesting(
                mobilityPlan,
                currentPlan: currentPlan,
                allowsActivitySemanticChange: true,
                changedTemplateIDs: [templateID],
                changedBlockIDs: [blockID]
            )
        )
    }

    @MainActor
    func testWorkoutPlanRefinementRejectsUnscopedRetainedActivityMutation() {
        let pushTemplateID = UUID()
        let pushBlockID = UUID()
        let climbingTemplateID = UUID()
        let climbingBlockID = UUID()
        let currentPlan = makePlan(
            templates: [
                WorkoutPlan.WorkoutTemplate(
                    id: pushTemplateID,
                    name: "Push Strength",
                    sessionType: .strength,
                    focusAreas: ["Push"],
                    targetMuscleGroups: [],
                    exercises: [],
                    blocks: [
                        WorkoutPlan.TrainingBlock(
                            id: pushBlockID,
                            kind: .strength,
                            title: "Push Strength",
                            detail: "Pressing volume",
                            activityTypeName: "Strength",
                            activityTags: ["Push"],
                            order: 0
                        )
                    ],
                    estimatedDurationMinutes: 45,
                    order: 0
                ),
                WorkoutPlan.WorkoutTemplate(
                    id: climbingTemplateID,
                    name: "Climbing Skill",
                    sessionType: .mixed,
                    focusAreas: ["Climbing"],
                    targetMuscleGroups: [],
                    exercises: [],
                    blocks: [
                        WorkoutPlan.TrainingBlock(
                            id: climbingBlockID,
                            kind: .skill,
                            title: "Limit Bouldering",
                            detail: "Board climbing",
                            activityTypeName: "Bouldering",
                            activityTags: ["Climbing", "Power"],
                            order: 0
                        )
                    ],
                    estimatedDurationMinutes: 45,
                    order: 1
                )
            ],
            daysPerWeek: 2
        )
        let mutatedPlan = makePlan(
            templates: [
                WorkoutPlan.WorkoutTemplate(
                    id: pushTemplateID,
                    name: "Push + Mobility",
                    sessionType: .mobility,
                    focusAreas: ["Mobility"],
                    targetMuscleGroups: [],
                    exercises: [],
                    blocks: [
                        WorkoutPlan.TrainingBlock(
                            id: pushBlockID,
                            kind: .mobility,
                            title: "Mobility Flow",
                            detail: "Intentional replacement",
                            activityTypeName: "Mobility Flow",
                            activityTags: ["Mobility"],
                            order: 0
                        )
                    ],
                    estimatedDurationMinutes: 45,
                    order: 0
                ),
                WorkoutPlan.WorkoutTemplate(
                    id: climbingTemplateID,
                    name: "Climbing Skill",
                    sessionType: .mixed,
                    focusAreas: ["Climbing"],
                    targetMuscleGroups: [],
                    exercises: [],
                    blocks: [
                        WorkoutPlan.TrainingBlock(
                            id: climbingBlockID,
                            kind: .strength,
                            title: "Generic Strength",
                            detail: "Unrequested mutation",
                            activityTypeName: "Strength",
                            activityTags: ["Strength"],
                            order: 0
                        )
                    ],
                    estimatedDurationMinutes: 45,
                    order: 1
                )
            ],
            daysPerWeek: 2
        )

        XCTAssertNil(
            AIService.validateRefinedWorkoutPlanForTesting(
                mutatedPlan,
                currentPlan: currentPlan,
                allowsActivitySemanticChange: true,
                changedTemplateIDs: [pushTemplateID]
            )
        )
    }

    @MainActor
    func testWorkoutPlanEditSheetRejectsStaleEditingBase() {
        let editingBase = makePlan(
            templateName: "Upper Strength",
            sessionType: .strength,
            focusAreas: ["Upper"],
            blocks: [
                WorkoutPlan.TrainingBlock(
                    kind: .strength,
                    title: "Strength",
                    detail: "Upper-body lifting",
                    activityTypeName: "Strength",
                    order: 0
                )
            ]
        )
        let newerSavedPlan = makePlan(
            templateName: "Lower Strength",
            sessionType: .strength,
            focusAreas: ["Lower"],
            blocks: [
                WorkoutPlan.TrainingBlock(
                    kind: .strength,
                    title: "Strength",
                    detail: "Lower-body lifting",
                    activityTypeName: "Strength",
                    order: 0
                )
            ]
        )

        XCTAssertTrue(WorkoutPlanEditSheet.canSaveCurrentPlan(savedPlan: editingBase, editingBase: editingBase))
        XCTAssertFalse(WorkoutPlanEditSheet.canSaveCurrentPlan(savedPlan: newerSavedPlan, editingBase: editingBase))
        XCTAssertFalse(WorkoutPlanEditSheet.canSaveCurrentPlan(savedPlan: nil, editingBase: editingBase))
    }

    func testWorkoutPlanSetupSaveGuardRejectsPlanChangedWhileOpen() {
        let setupBase = makePlan(
            templateName: "Upper Strength",
            sessionType: .strength,
            focusAreas: ["Upper"],
            blocks: [
                WorkoutPlan.TrainingBlock(
                    kind: .strength,
                    title: "Strength",
                    detail: "Upper-body lifting",
                    activityTypeName: "Strength",
                    order: 0
                )
            ]
        )
        let newerSavedPlan = makePlan(
            templateName: "Lower Strength",
            sessionType: .strength,
            focusAreas: ["Lower"],
            blocks: [
                WorkoutPlan.TrainingBlock(
                    kind: .strength,
                    title: "Strength",
                    detail: "Lower-body lifting",
                    activityTypeName: "Strength",
                    order: 0
                )
            ]
        )

        XCTAssertTrue(WorkoutPlanEditSheet.canSaveSetupPlan(savedPlan: setupBase, setupBase: setupBase))
        XCTAssertTrue(WorkoutPlanEditSheet.canSaveSetupPlan(savedPlan: nil, setupBase: nil))
        XCTAssertFalse(WorkoutPlanEditSheet.canSaveSetupPlan(savedPlan: newerSavedPlan, setupBase: setupBase))
        XCTAssertFalse(WorkoutPlanEditSheet.canSaveSetupPlan(savedPlan: newerSavedPlan, setupBase: nil))
    }

    private func makeGoalSuggestion(
        title: String,
        goalKindRaw: String = WorkoutGoal.GoalKind.frequency.rawValue,
        targetValue: Double? = 1,
        targetUnit: String? = "sessions",
        periodUnitRaw: String? = WorkoutGoal.PeriodUnit.week.rawValue,
        periodCount: Int? = 1,
        successCriteria: String = "Complete the tracked target."
    ) -> WorkoutGoalSuggestion {
        WorkoutGoalSuggestion(
            title: title,
            rationale: "Fits the plan.",
            goalKindRaw: goalKindRaw,
            linkedWorkoutTypeRaw: WorkoutMode.mixed.rawValue,
            linkedActivityName: "Planned Habit",
            linkedActivityTags: nil,
            linkedActivityKindRaw: nil,
            linkedActivityRoleRaw: nil,
            targetValue: targetValue,
            targetUnit: targetUnit,
            periodUnitRaw: periodUnitRaw,
            periodCount: periodCount,
            successCriteria: successCriteria,
            notes: nil,
            targetDateISO8601: nil,
            checkInCadenceDays: nil
        )
    }

    private func makePlan(
        templateID: UUID = UUID(),
        templateName: String,
        sessionType: WorkoutMode,
        focusAreas: [String],
        blocks: [WorkoutPlan.TrainingBlock]
    ) -> WorkoutPlan {
        WorkoutPlan(
            splitType: .custom,
            daysPerWeek: 1,
            templates: [
                WorkoutPlan.WorkoutTemplate(
                    id: templateID,
                    name: templateName,
                    sessionType: sessionType,
                    focusAreas: focusAreas,
                    targetMuscleGroups: [],
                    exercises: [],
                    blocks: blocks,
                    estimatedDurationMinutes: 45,
                    order: 0,
                    notes: "Test template"
                )
            ],
            planIntent: WorkoutPlan.PlanIntent(
                primaryFocus: "Test",
                sessionAllocation: "One test session",
                summary: "I built this around the requested activity."
            ),
            rationale: "Test rationale",
            guidelines: [],
            progressionStrategy: .defaultStrategy,
            modalityProgression: WorkoutPlan.ModalityProgression(
                focus: .mixed,
                weeklyProgression: "Repeat and refine.",
                targets: []
            ),
            warnings: nil
        )
    }

    private func makePlan(
        templates: [WorkoutPlan.WorkoutTemplate],
        daysPerWeek: Int,
        planIntent: WorkoutPlan.PlanIntent? = nil
    ) -> WorkoutPlan {
        WorkoutPlan(
            splitType: .custom,
            daysPerWeek: daysPerWeek,
            templates: templates,
            planIntent: planIntent ?? WorkoutPlan.PlanIntent(
                primaryFocus: "Test",
                sessionAllocation: "\(templates.count) test sessions",
                summary: "I built this around the requested activity."
            ),
            rationale: "Test rationale",
            guidelines: [],
            progressionStrategy: .defaultStrategy,
            modalityProgression: WorkoutPlan.ModalityProgression(
                focus: .mixed,
                weeklyProgression: "Repeat and refine.",
                targets: []
            ),
            warnings: nil
        )
    }

    private func workoutPlanJSON(blockKind: String, blockRole: String?) -> String {
        let roleLine = blockRole.map { #""role": "\#($0)","# } ?? ""
        return """
        {
          "splitType": "custom",
          "daysPerWeek": 1,
          "templates": [
            {
              "id": "activity-day",
              "name": "Activity Day",
              "sessionType": "mixed",
              "focusAreas": ["Bouldering"],
              "targetMuscleGroups": [],
              "exercises": [],
              "blocks": [
                {
                  "id": "activity-block",
                  "kind": "\(blockKind)",
                  \(roleLine)
                  "title": "Bouldering",
                  "detail": "Limit bouldering session",
                  "exercises": [],
                  "activityTypeName": "Bouldering",
                  "activityTags": ["Climbing"],
                  "durationMinutes": 45,
                  "intensity": "moderate",
                  "target": "Technique",
                  "order": 0,
                  "notes": null
                }
              ],
              "estimatedDurationMinutes": 45,
              "order": 0,
              "notes": "Test template"
            }
          ],
          "planIntent": {
            "primaryFocus": "Bouldering",
            "supportingFocuses": [],
            "sessionAllocation": "One activity day",
            "honoredInputs": ["Bouldering"],
            "avoided": [],
            "supportiveCardioConstraint": null,
            "summary": "Activity plan"
          },
          "rationale": "Test rationale",
          "guidelines": [],
          "progressionStrategy": {
            "type": "doubleProgression",
            "weightIncrementKg": 2.5,
            "repsTrigger": 12,
            "description": "Progress gradually."
          },
          "modalityProgression": null,
          "warnings": []
        }
        """
    }

    private func makeRequest(
        workoutType: WorkoutPlanGenerationRequest.WorkoutType = .mixed,
        selectedWorkoutTypes: [WorkoutPlanGenerationRequest.WorkoutType]? = nil,
        timePerWorkout: Int? = nil,
        preferences: String? = nil,
        conversationContext: [String]? = nil,
        cardioTypes: [WorkoutPlanGenerationRequest.CardioType]? = nil,
        customWorkoutType: String? = nil,
        cardioSupportConstraint: WorkoutPlanGenerationRequest.CardioSupportConstraint? = nil,
        availableDays: Int? = 4
    ) -> WorkoutPlanGenerationRequest {
        WorkoutPlanGenerationRequest(
            name: "Test User",
            age: 30,
            gender: .notSpecified,
            goal: .health,
            activityLevel: .moderate,
            workoutType: workoutType,
            selectedWorkoutTypes: selectedWorkoutTypes,
            experienceLevel: .intermediate,
            equipmentAccess: .fullGym,
            availableDays: availableDays,
            timePerWorkout: timePerWorkout,
            preferredSplit: nil,
            cardioTypes: cardioTypes,
            customWorkoutType: customWorkoutType,
            customExperience: nil,
            customEquipment: nil,
            customCardioType: nil,
            specificGoals: nil,
            weakPoints: nil,
            injuries: nil,
            preferences: preferences,
            conversationContext: conversationContext,
            cardioSupportConstraint: cardioSupportConstraint
        )
    }
}
