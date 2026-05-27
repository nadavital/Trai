//
//  ChatReminderComponents.swift
//  Trai
//
//  Reminder suggestion UI components for chat
//

import SwiftUI
import SwiftData

// MARK: - Reminder Suggestion Card

struct ReminderSuggestionCard: View {
    let suggestion: SuggestedReminder
    let onConfirm: () -> Void
    let onEdit: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        ReminderDraftCard(
            suggestion: suggestion,
            onEdit: onEdit,
            onConfirm: onConfirm,
            onDismiss: onDismiss
        )
    }
}

// MARK: - Created Reminder Chip

struct CreatedReminderChip: View {
    let suggestion: SuggestedReminder

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "bell.badge.fill")
                .font(.caption)
                .foregroundStyle(.blue)

            Text("Reminder created: \(suggestion.title)")
                .font(.caption)
                .fontWeight(.medium)

            Text("at \(suggestion.formattedTime)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.blue.opacity(0.1))
        .clipShape(.capsule)
    }
}

#Preview {
    VStack {
        ReminderSuggestionCard(
            suggestion: SuggestedReminder(
                title: "Drink water",
                body: "Stay hydrated throughout the day",
                hour: 14,
                minute: 0,
                repeatDays: ""
            ),
            onConfirm: {},
            onEdit: {},
            onDismiss: {}
        )

        CreatedReminderChip(
            suggestion: SuggestedReminder(
                title: "Take vitamins",
                body: "",
                hour: 9,
                minute: 0,
                repeatDays: "2,3,4,5,6"
            )
        )
    }
    .padding()
}
