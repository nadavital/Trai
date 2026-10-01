//
//  CalorieDetailSheet.swift
//  Trai
//
//  Created by Nadav Avital on 12/28/25.
//

import SwiftUI
import SwiftData
import Charts

struct CalorieDetailSheet: View {
    let entries: [FoodEntry]
    let goal: Int
    var isToday: Bool = true
    var historicalEntries: [FoodEntry] = []
    var onAddFood: (() -> Void)?
    let onEditEntry: (FoodEntry) -> Void
    let onDeleteEntry: (FoodEntry) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var showTrends = true
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private var consumed: Int {
        entries.reduce(0) { $0 + $1.calories }
    }

    private var calorieState: NutritionDisplayPolicy.CalorieState {
        NutritionDisplayPolicy.calorieState(consumed: consumed, target: goal)
    }

    /// Entries sorted chronologically (most recent first)
    private var sortedEntries: [FoodEntry] {
        entries.sorted { $0.loggedAt > $1.loggedAt }
    }

    private var trendData: [TrendsService.DailyNutrition] {
        TrendsService.aggregateNutritionByDay(entries: historicalEntries, days: 7)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .firstTextBaseline) {
                            Text("\(consumed.formatted())").font(.largeTitle.weight(.semibold)).monospacedDigit()
                            Text("kcal").font(.subheadline).foregroundStyle(.secondary)
                        }
                        if goal > 0 {
                            Text(consumed > goal ? "+\((consumed - goal).formatted()) above target · \(goal.formatted()) kcal target" : "\(goal.formatted()) kcal target")
                                .font(.subheadline).foregroundStyle(.secondary)
                        } else {
                            Text("Target not set").font(.subheadline).foregroundStyle(.secondary)
                        }
                        CalorieGlassBar(value: consumed, target: goal > 0 ? goal : nil, reduceTransparency: reduceTransparency)
                            .frame(height: 28)
                            .accessibilityHidden(true)
                    }.traiCard()

                    // 7-Day Trend Chart
                    if !historicalEntries.isEmpty && showTrends {
                        NutritionTrendChart(
                            data: trendData,
                            goal: goal,
                            metric: .calories,
                            title: "7-Day Trend"
                        )
                    }

                    // Food list
                    VStack(alignment: .leading, spacing: 12) {
                        Text(isToday ? "Today's Food" : "Food Log")
                            .font(.headline)
                            .padding(.horizontal)

                        if sortedEntries.isEmpty {
                            EmptyStateView(onAddFood: onAddFood)
                        } else {
                            VStack(spacing: 8) {
                                ForEach(sortedEntries) { entry in
                                    FoodEntryTimelineRow(
                                        entry: entry,
                                        onTap: { onEditEntry(entry) },
                                        onDelete: { onDeleteEntry(entry) }
                                    )
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Calories")
            .toolbarTitleDisplayMode(.inlineLarge)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", systemImage: "checkmark") { dismiss() }
                        .labelStyle(.iconOnly)
                }

                if let addAction = onAddFood {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Add Food", systemImage: "plus", action: addAction)
                    }
                }
            }
        }
        .traiBackground()
    }
}

// MARK: - Empty State

private struct EmptyStateView: View {
    var onAddFood: (() -> Void)?

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "fork.knife.circle")
                .font(.largeTitle)
                .foregroundStyle(.secondary)

            Text(onAddFood != nil ? "No food logged today" : "No food logged")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let addAction = onAddFood {
                Button("Log Your First Meal", action: addAction)
                    .buttonStyle(.traiPrimary())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .traiCard()
    }
}

#Preview {
    CalorieDetailSheet(
        entries: [
            FoodEntry(name: "Oatmeal", mealType: "breakfast", calories: 350, proteinGrams: 12, carbsGrams: 60, fatGrams: 8),
            FoodEntry(name: "Chicken Salad", mealType: "lunch", calories: 450, proteinGrams: 40, carbsGrams: 15, fatGrams: 22),
        ],
        goal: 2000,
        onAddFood: {},
        onEditEntry: { _ in },
        onDeleteEntry: { _ in }
    )
}
