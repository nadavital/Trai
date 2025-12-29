//
//  ExerciseListView.swift
//  Plates
//
//  Created by Nadav Avital on 12/25/25.
//

import SwiftUI
import SwiftData

struct ExerciseListView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Exercise.name) private var exercises: [Exercise]

    @Binding var selectedExercise: Exercise?
    @State private var searchText = ""

    private var filteredExercises: [Exercise] {
        if searchText.isEmpty {
            return exercises
        }
        return exercises.filter { $0.name.localizedStandardContains(searchText) }
    }

    private var exercisesByCategory: [Exercise.Category: [Exercise]] {
        Dictionary(grouping: filteredExercises) { $0.exerciseCategory }
    }

    var body: some View {
        NavigationStack {
            List {
                if exercises.isEmpty {
                    Section {
                        Button("Load Default Exercises") {
                            loadDefaultExercises()
                        }
                    }
                } else {
                    ForEach(Exercise.Category.allCases) { category in
                        if let categoryExercises = exercisesByCategory[category], !categoryExercises.isEmpty {
                            Section {
                                ForEach(categoryExercises) { exercise in
                                    ExerciseRow(
                                        exercise: exercise,
                                        isSelected: selectedExercise?.id == exercise.id
                                    ) {
                                        selectedExercise = exercise
                                        dismiss()
                                    }
                                }
                            } header: {
                                Label(category.displayName, systemImage: category.iconName)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search exercises")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func loadDefaultExercises() {
        for (name, category, muscleGroup) in Exercise.defaultExercises {
            let exercise = Exercise(name: name, category: category, muscleGroup: muscleGroup)
            modelContext.insert(exercise)
        }
    }
}

// MARK: - Exercise Row

struct ExerciseRow: View {
    let exercise: Exercise
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading) {
                    Text(exercise.name)
                    if let muscleGroup = exercise.targetMuscleGroup {
                        Text(muscleGroup.displayName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.tint)
                }
            }
        }
        .foregroundStyle(.primary)
    }
}

#Preview {
    ExerciseListView(selectedExercise: .constant(nil))
        .modelContainer(for: Exercise.self, inMemory: true)
}
