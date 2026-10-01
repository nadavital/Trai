//
//  FoodTimelineComponents.swift
//  Trai
//
//  Components for the daily food timeline
//

import SwiftUI
import SwiftData

// MARK: - Food Group Type

enum FoodGroup: Identifiable {
    case single(FoodEntry)
    case session(id: UUID, entries: [FoodEntry])

    var id: String {
        switch self {
        case .single(let entry):
            return entry.id.uuidString
        case .session(let id, _):
            return "session-\(id.uuidString)"
        }
    }
}

// MARK: - Empty Meals View

struct EmptyMealsView: View {
    var onAddFood: (() -> Void)?

    var body: some View {
        Text("No meals logged")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 12)
    }
}

// MARK: - Food Session Card

struct FoodSessionCard: View {
    let entries: [FoodEntry]
    var enabledMacros: Set<MacroType> = MacroType.defaultEnabled
    var onAddMore: (() -> Void)?
    let onEditEntry: (FoodEntry) -> Void
    let onDeleteEntry: (FoodEntry) -> Void

    @State private var isExpanded = false

    private var totalCalories: Int { entries.reduce(0) { $0 + $1.calories } }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button {
                withAnimation(.snappy) { isExpanded.toggle() }
                HapticManager.selectionChanged()
            } label: {
                HStack(spacing: 14) {
                    if let first = entries.first {
                        MealTimelineThumbnail(entry: first)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Meal · \(entries.count) items")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        if let first = entries.first {
                            Text(first.loggedAt, format: .dateTime.hour().minute())
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer(minLength: 8)
                    Text("\(totalCalories) kcal")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")

            if isExpanded {
                VStack(spacing: 4) {
                    ForEach(entries) { entry in
                        SessionEntryRow(
                            entry: entry,
                            onTap: { onEditEntry(entry) },
                            onDelete: { onDeleteEntry(entry) }
                        )
                    }
                    if let addAction = onAddMore {
                        Button("Add to this meal", systemImage: "plus", action: addAction)
                            .font(.subheadline)
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    }
                }
                .padding(.leading, 16)
            }
        }
    }
}

// MARK: - Session Entry Row

struct SessionEntryRow: View {
    let entry: FoodEntry
    let onTap: () -> Void
    let onDelete: () -> Void

    var body: some View {
        FoodEntryTimelineRow(entry: entry, onTap: onTap, onDelete: onDelete)
    }
}

// MARK: - Food Entry Timeline Row

struct FoodEntryTimelineRow: View {
    let entry: FoodEntry
    var enabledMacros: Set<MacroType> = MacroType.defaultEnabled
    let onTap: () -> Void
    let onDelete: () -> Void

    @State private var showingDeleteConfirm = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        HStack(spacing: 4) {
            Button(action: onTap) {
                HStack(spacing: 14) {
                    MealTimelineThumbnail(entry: entry)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                        Text(entry.loggedAt, format: .dateTime.hour().minute())
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if dynamicTypeSize.isAccessibilitySize {
                            calorieLabel
                        }
                    }
                    Spacer(minLength: 8)
                    if !dynamicTypeSize.isAccessibilitySize {
                        calorieLabel
                    }
                }
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Edit meal")

            Menu {
                Button("Edit meal", systemImage: "pencil", action: onTap)
                Button("Delete meal", systemImage: "trash", role: .destructive) {
                    showingDeleteConfirm = true
                }
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundStyle(.secondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Options for \(entry.name)")
        }
        .confirmationDialog(
            "Delete \(entry.name)?",
            isPresented: $showingDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive, action: onDelete)
            Button("Cancel", role: .cancel) {}
        }
    }

    private var calorieLabel: some View {
        Text("\(entry.calories) kcal")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: true, vertical: false)
    }
}

private struct MealTimelineThumbnail: View {
    let entry: FoodEntry

    var body: some View {
        Group {
            if let data = entry.imageData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Text(entry.displayEmoji)
                    .font(.system(size: 24))
            }
        }
        .frame(width: 52, height: 52)
        .background(.quaternary, in: .rect(cornerRadius: 14))
        .clipShape(.rect(cornerRadius: 14))
        .accessibilityHidden(true)
    }
}
