//
//  ContentView.swift
//  Trai
//
//  Created by Nadav Avital on 12/25/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Query private var profiles: [UserProfile]
    @Environment(\.modelContext) private var modelContext
    @State private var isWaitingForSync = true

    private var hasCompletedOnboarding: Bool {
        profiles.first?.hasCompletedOnboarding ?? false
    }

    var body: some View {
        Group {
            if isWaitingForSync {
                // Show loading while waiting for CloudKit sync
                ZStack {
                    Color(.systemBackground)
                        .ignoresSafeArea()
                    ProgressView()
                        .scaleEffect(1.2)
                }
            } else if hasCompletedOnboarding {
                MainTabView()
            } else {
                OnboardingView()
            }
        }
        .task {
            await waitForCloudKitSync()
        }
    }

    private func waitForCloudKitSync() async {
        // If profile already exists locally, no need to wait
        if hasCompletedOnboarding {
            isWaitingForSync = false
            return
        }

        // Wait up to 3 seconds for CloudKit to sync profile
        let maxWaitTime: TimeInterval = 3.0
        let checkInterval: TimeInterval = 0.2
        var elapsed: TimeInterval = 0

        while elapsed < maxWaitTime {
            try? await Task.sleep(for: .milliseconds(200))
            elapsed += checkInterval

            // Check if profile synced
            if hasCompletedOnboarding {
                break
            }
        }

        isWaitingForSync = false
    }
}

// MARK: - Main Tab View

enum AppTab: String, CaseIterable {
    case dashboard
    case trai
    case workouts
}

struct MainTabView: View {
    @State private var selectedTab: AppTab = .dashboard
    @Query(filter: #Predicate<LiveWorkout> { $0.completedAt == nil })
    private var activeWorkouts: [LiveWorkout]

    // Capture the workout when opening sheet to avoid nil issues when workout completes
    @State private var presentedWorkout: LiveWorkout?
    @State private var showingEndConfirmation = false

    private var activeWorkout: LiveWorkout? {
        activeWorkouts.first
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Dashboard", systemImage: "house.fill", value: .dashboard) {
                DashboardView()
            }

            Tab("Trai", systemImage: "circle.hexagongrid.circle", value: .trai, role: .search) {
                ChatView()
            }

            Tab("Workouts", systemImage: "figure.run", value: .workouts) {
                WorkoutsView()
            }
        }
        .tabViewBottomAccessory(isEnabled: activeWorkout != nil) {
            if let workout = activeWorkout {
                WorkoutBanner(
                    workout: workout,
                    onTap: { presentedWorkout = workout },
                    onEnd: { showingEndConfirmation = true }
                )
            }
        }
        .sheet(item: $presentedWorkout) { workout in
            NavigationStack {
                LiveWorkoutView(workout: workout)
            }
        }
        .confirmationDialog(
            "End Workout?",
            isPresented: $showingEndConfirmation,
            titleVisibility: .visible
        ) {
            Button("End Workout", role: .destructive) {
                if let workout = activeWorkout {
                    workout.completedAt = Date()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to end this workout?")
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [
            UserProfile.self,
            FoodEntry.self,
            Exercise.self,
            WorkoutSession.self,
            WeightEntry.self,
            ChatMessage.self,
            LiveWorkout.self,
            LiveWorkoutEntry.self,
            ExerciseHistory.self
        ], inMemory: true)
}
