//
//  FoodTrackingView.swift
//  Plates
//
//  Created by Nadav Avital on 12/25/25.
//

import SwiftUI
import SwiftData

struct FoodTrackingView: View {
    @Query(sort: \FoodEntry.loggedAt, order: .reverse)
    private var allFoodEntries: [FoodEntry]

    @Environment(\.modelContext) private var modelContext
    @State private var showingAddFood = false
    @State private var selectedDate = Date()

    private var todaysEntries: [FoodEntry] {
        let calendar = Calendar.current
        return allFoodEntries.filter { calendar.isDate($0.loggedAt, inSameDayAs: selectedDate) }
    }

    private var entriesByMeal: [FoodEntry.MealType: [FoodEntry]] {
        Dictionary(grouping: todaysEntries) { $0.meal }
    }

    var body: some View {
        NavigationStack {
            List {
                // Date selector
                Section {
                    DatePicker(
                        "Date",
                        selection: $selectedDate,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.compact)
                }

                // Daily summary
                Section {
                    DailySummaryRow(entries: todaysEntries)
                }

                // Meals by type
                ForEach(FoodEntry.MealType.allCases) { mealType in
                    Section {
                        if let entries = entriesByMeal[mealType], !entries.isEmpty {
                            ForEach(entries) { entry in
                                FoodEntryRow(entry: entry)
                            }
                            .onDelete { indexSet in
                                deleteEntries(entries: entries, at: indexSet)
                            }
                        } else {
                            Button {
                                // Add food for this meal type
                                showingAddFood = true
                            } label: {
                                Label("Add \(mealType.displayName)", systemImage: "plus")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } header: {
                        Label(mealType.displayName, systemImage: mealType.iconName)
                    }
                }
            }
            .navigationTitle("Food")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Add Food", systemImage: "plus") {
                        showingAddFood = true
                    }
                }
            }
            .sheet(isPresented: $showingAddFood) {
                AddFoodView()
            }
        }
    }

    private func deleteEntries(entries: [FoodEntry], at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(entries[index])
        }
    }
}

// MARK: - Daily Summary Row

struct DailySummaryRow: View {
    let entries: [FoodEntry]

    private var totalCalories: Int {
        entries.reduce(0) { $0 + $1.calories }
    }

    private var totalProtein: Double {
        entries.reduce(0) { $0 + $1.proteinGrams }
    }

    private var totalCarbs: Double {
        entries.reduce(0) { $0 + $1.carbsGrams }
    }

    private var totalFat: Double {
        entries.reduce(0) { $0 + $1.fatGrams }
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Today's Total")
                    .font(.headline)
                Spacer()
                Text("\(totalCalories) kcal")
                    .font(.title3)
                    .bold()
            }

            HStack(spacing: 16) {
                MacroLabel(name: "Protein", value: totalProtein, color: .blue)
                MacroLabel(name: "Carbs", value: totalCarbs, color: .orange)
                MacroLabel(name: "Fat", value: totalFat, color: .purple)
            }
        }
        .padding(.vertical, 4)
    }
}

struct MacroLabel: View {
    let name: String
    let value: Double
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text("\(Int(value))g")
                .font(.subheadline)
                .bold()
                .foregroundStyle(color)

            Text(name)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Food Entry Row

struct FoodEntryRow: View {
    let entry: FoodEntry

    var body: some View {
        HStack {
            if let imageData = entry.imageData,
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 50, height: 50)
                    .clipShape(.rect(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.tertiarySystemBackground))
                    .frame(width: 50, height: 50)
                    .overlay {
                        Image(systemName: "fork.knife")
                            .foregroundStyle(.secondary)
                    }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.name)
                    .font(.body)

                if let serving = entry.servingSize {
                    Text(serving)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("\(entry.calories)")
                    .font(.headline)

                Text("kcal")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    FoodTrackingView()
        .modelContainer(for: FoodEntry.self, inMemory: true)
}
