//
//  AddWorkoutView.swift
//  Plates
//
//  Created by Nadav Avital on 12/25/25.
//

import SwiftUI
import SwiftData

struct AddWorkoutView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Exercise.name) private var exercises: [Exercise]

    @State private var selectedExercise: Exercise?
    @State private var customExerciseName = ""
    @State private var selectedCategory: Exercise.Category = .strength
    @State private var selectedMuscleGroup: Exercise.MuscleGroup = .chest

    // Strength training fields
    @State private var sets = ""
    @State private var reps = ""
    @State private var weight = ""

    // Cardio fields
    @State private var durationMinutes = ""
    @State private var distance = ""
    @State private var caloriesBurned = ""

    @State private var notes = ""
    @State private var workoutDate = Date()
    @State private var showingExerciseList = false

    private var isStrengthTraining: Bool {
        selectedExercise?.exerciseCategory == .strength || selectedCategory == .strength
    }

    var body: some View {
        NavigationStack {
            Form {
                exerciseSection
                workoutDetailsSection
                dateAndNotesSection
                saveButtonSection
            }
            .navigationTitle("Add Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingExerciseList) {
                ExerciseListView(selectedExercise: $selectedExercise)
            }
        }
    }

    // MARK: - Sections

    private var exerciseSection: some View {
        Section("Exercise") {
            Button {
                showingExerciseList = true
            } label: {
                HStack {
                    Text("Exercise")
                    Spacer()
                    Text(selectedExercise?.name ?? "Select...")
                        .foregroundStyle(.secondary)
                }
            }

            if selectedExercise == nil {
                TextField("Or enter custom exercise", text: $customExerciseName)

                if !customExerciseName.isEmpty {
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(Exercise.Category.allCases) { category in
                            Text(category.displayName).tag(category)
                        }
                    }

                    if selectedCategory == .strength {
                        Picker("Muscle Group", selection: $selectedMuscleGroup) {
                            ForEach(Exercise.MuscleGroup.allCases) { group in
                                Text(group.displayName).tag(group)
                            }
                        }
                    }
                }
            }
        }
    }

    private var workoutDetailsSection: some View {
        Group {
            if isStrengthTraining || (!customExerciseName.isEmpty && selectedCategory == .strength) {
                strengthTrainingSection
            } else {
                cardioSection
            }
        }
    }

    private var strengthTrainingSection: some View {
        Section("Details") {
            HStack {
                Text("Sets")
                Spacer()
                TextField("3", text: $sets)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 60)
            }

            HStack {
                Text("Reps")
                Spacer()
                TextField("10", text: $reps)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 60)
            }

            HStack {
                Text("Weight (kg)")
                Spacer()
                TextField("0", text: $weight)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 60)
            }
        }
    }

    private var cardioSection: some View {
        Section("Details") {
            HStack {
                Text("Duration (min)")
                Spacer()
                TextField("30", text: $durationMinutes)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 60)
            }

            HStack {
                Text("Distance (km)")
                Spacer()
                TextField("Optional", text: $distance)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
            }

            HStack {
                Text("Calories burned")
                Spacer()
                TextField("Optional", text: $caloriesBurned)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
            }
        }
    }

    private var dateAndNotesSection: some View {
        Section {
            DatePicker("Date", selection: $workoutDate, displayedComponents: [.date, .hourAndMinute])
            TextField("Notes (optional)", text: $notes, axis: .vertical)
                .lineLimit(2...4)
        }
    }

    private var saveButtonSection: some View {
        Section {
            Button("Save Workout", systemImage: "checkmark.circle.fill") {
                saveWorkout()
            }
            .frame(maxWidth: .infinity)
            .disabled(!canSave)
        }
    }

    // MARK: - Logic

    private var canSave: Bool {
        let hasExercise = selectedExercise != nil || !customExerciseName.isEmpty

        if isStrengthTraining || (!customExerciseName.isEmpty && selectedCategory == .strength) {
            return hasExercise && !sets.isEmpty && !reps.isEmpty
        } else {
            return hasExercise && !durationMinutes.isEmpty
        }
    }

    private func saveWorkout() {
        let workout = WorkoutSession()

        if let exercise = selectedExercise {
            workout.exercise = exercise
            workout.exerciseName = exercise.name
        } else if !customExerciseName.isEmpty {
            let newExercise = Exercise(
                name: customExerciseName,
                category: selectedCategory.rawValue,
                muscleGroup: selectedCategory == .strength ? selectedMuscleGroup.rawValue : nil
            )
            newExercise.isCustom = true
            modelContext.insert(newExercise)
            workout.exercise = newExercise
            workout.exerciseName = customExerciseName
        }

        if isStrengthTraining || selectedCategory == .strength {
            workout.sets = Int(sets) ?? 0
            workout.reps = Int(reps) ?? 0
            workout.weightKg = Double(weight)
        } else {
            workout.durationMinutes = Double(durationMinutes)
            if let dist = Double(distance) {
                workout.distanceMeters = dist * 1000
            }
            workout.caloriesBurned = Int(caloriesBurned)
        }

        workout.loggedAt = workoutDate
        workout.notes = notes.isEmpty ? nil : notes

        modelContext.insert(workout)
        try? modelContext.save()
        dismiss()
    }
}

#Preview {
    AddWorkoutView()
        .modelContainer(for: [WorkoutSession.self, Exercise.self], inMemory: true)
}
