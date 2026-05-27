//
//  ReminderDraftCard.swift
//  Trai
//
//  Shared reminder draft confirmation card used by the reminder composer and chat.
//

import SwiftUI

struct ReminderDraftCard: View {
    let suggestion: SuggestedReminder
    var primaryTitle = "Save"
    let onEdit: () -> Void
    let onConfirm: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 10) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "bell.badge.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 30, height: 30)
                        .background(Color.accentColor.opacity(0.12), in: Circle())

                    VStack(alignment: .leading, spacing: 6) {
                        Text(suggestion.title)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)

                        if !suggestion.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text(suggestion.body)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                        .background(Color(.tertiarySystemFill), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss reminder draft")
            }

            VStack(alignment: .leading, spacing: 12) {
                ReminderDraftDetailRow(
                    title: "Time",
                    value: suggestion.formattedTime,
                    systemImage: "clock"
                )
                ReminderDraftDetailRow(
                    title: "Repeats",
                    value: suggestion.scheduleDescription,
                    systemImage: "repeat"
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 10) {
                Button {
                    onEdit()
                } label: {
                    Text("Edit")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.traiSecondary(fullWidth: true))

                Button {
                    onConfirm()
                } label: {
                    Label(primaryTitle, systemImage: "checkmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.traiPrimary(fullWidth: true))
            }
        }
        .padding(14)
        .traiCard(cornerRadius: 16)
    }
}

private struct ReminderDraftDetailRow: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 22)

            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Spacer(minLength: 8)

            Text(value.isEmpty ? "Every day" : value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.trailing)
        }
    }
}
