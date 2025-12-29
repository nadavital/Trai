//
//  ContentView.swift
//  Plates
//
//  Created by Nadav Avital on 12/25/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Query private var profiles: [UserProfile]
    @Environment(\.modelContext) private var modelContext

    private var hasCompletedOnboarding: Bool {
        profiles.first?.hasCompletedOnboarding ?? false
    }

    var body: some View {
        if hasCompletedOnboarding {
            MainTabView()
        } else {
            OnboardingView()
        }
    }
}

// MARK: - Main Tab View

struct MainTabView: View {
    var body: some View {
        TabView {
            Tab("Dashboard", systemImage: "house.fill") {
                DashboardView()
            }

            Tab("Workouts", systemImage: "figure.run") {
                WorkoutsView()
            }

            Tab("Coach", systemImage: "bubble.left.and.bubble.right.fill") {
                ChatView()
            }

            Tab("Profile", systemImage: "person.fill") {
                ProfileView()
            }
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
