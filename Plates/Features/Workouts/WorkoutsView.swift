//
//  WorkoutsView.swift
//  Plates
//
//  Created by Nadav Avital on 12/25/25.
//

import SwiftUI
import SwiftData

struct WorkoutsView: View {
    @Query(sort: \WorkoutSession.loggedAt, order: .reverse)
    private var allWorkouts: [WorkoutSession]

    @Query(sort: \Exercise.name)
    private var exercises: [Exercise]

    @Environment(\.modelContext) private var modelContext
    @State private var showingAddWorkout = false
    @State private var selectedFilter: WorkoutFilter = .all
    @State private var healthKitService = HealthKitService()

    enum WorkoutFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case strength = "Strength"
        case cardio = "Cardio"

        var id: String { rawValue }
    }

    private var filteredWorkouts: [WorkoutSession] {
        switch selectedFilter {
        case .all:
            return allWorkouts
        case .strength:
            return allWorkouts.filter { $0.isStrengthTraining }
        case .cardio:
            return allWorkouts.filter { $0.isCardio }
        }
    }

    private var workoutsByDate: [(date: Date, workouts: [WorkoutSession])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filteredWorkouts) { workout in
            calendar.startOfDay(for: workout.loggedAt)
        }
        return grouped.map { ($0.key, $0.value) }
            .sorted { $0.date > $1.date }
    }

    var body: some View {
        NavigationStack {
            List {
                // Filter picker
                Section {
                    Picker("Filter", selection: $selectedFilter) {
                        ForEach(WorkoutFilter.allCases) { filter in
                            Text(filter.rawValue).tag(filter)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                }

                // Workouts by date
                if workoutsByDate.isEmpty {
                    ContentUnavailableView {
                        Label("No Workouts", systemImage: "figure.run")
                    } description: {
                        Text("Start logging your workouts to track progress")
                    } actions: {
                        Button("Add Workout") {
                            showingAddWorkout = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(workoutsByDate, id: \.date) { dateGroup in
                        Section {
                            ForEach(dateGroup.workouts) { workout in
                                WorkoutSessionRow(workout: workout)
                            }
                            .onDelete { indexSet in
                                deleteWorkouts(from: dateGroup.workouts, at: indexSet)
                            }
                        } header: {
                            Text(dateGroup.date, format: .dateTime.weekday(.wide).month().day())
                        }
                    }
                }
            }
            .navigationTitle("Workouts")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Add", systemImage: "plus") {
                        showingAddWorkout = true
                    }
                }

                ToolbarItem(placement: .secondaryAction) {
                    Button("Sync HealthKit", systemImage: "arrow.triangle.2.circlepath") {
                        Task {
                            await syncHealthKit()
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAddWorkout) {
                AddWorkoutView()
            }
            .refreshable {
                await syncHealthKit()
            }
            .task {
                // Auto-sync HealthKit workouts on app launch
                await syncHealthKit()
            }
        }
    }

    private func deleteWorkouts(from workouts: [WorkoutSession], at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(workouts[index])
        }
        try? modelContext.save()
    }

    private func syncHealthKit() async {
        do {
            try await healthKitService.requestAuthorization()

            let oneMonthAgo = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
            let healthKitWorkouts = try await healthKitService.fetchWorkouts(from: oneMonthAgo, to: Date())

            // Filter out already imported workouts
            let existingIDs = Set(allWorkouts.compactMap { $0.healthKitWorkoutID })
            let newWorkouts = healthKitWorkouts.filter { !existingIDs.contains($0.healthKitWorkoutID ?? "") }

            for workout in newWorkouts {
                modelContext.insert(workout)
            }

            if !newWorkouts.isEmpty {
                try? modelContext.save()
            }
        } catch {
            // Handle error silently for now
        }
    }
}

// MARK: - Workout Session Row

struct WorkoutSessionRow: View {
    let workout: WorkoutSession

    var body: some View {
        HStack {
            // Icon
            Image(systemName: workout.isStrengthTraining ? "dumbbell.fill" : "figure.run")
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 40)

            // Details
            VStack(alignment: .leading, spacing: 4) {
                Text(workout.displayName)
                    .font(.body)

                HStack(spacing: 8) {
                    if workout.isStrengthTraining {
                        Text("\(workout.sets)x\(workout.reps)")
                        if let weight = workout.weightKg {
                            Text("@ \(Int(weight))kg")
                        }
                    } else {
                        if let duration = workout.formattedDuration {
                            Text(duration)
                        }
                        if let distance = workout.formattedDistance {
                            Text(distance)
                        }
                    }

                    if workout.sourceIsHealthKit {
                        Image(systemName: "heart.fill")
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            // Calories
            if let calories = workout.caloriesBurned {
                VStack(alignment: .trailing) {
                    Text("\(calories)")
                        .font(.headline)
                    Text("kcal")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    WorkoutsView()
        .modelContainer(for: [WorkoutSession.self, Exercise.self], inMemory: true)
}
