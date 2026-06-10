//
//  TraiChatContextAttachment.swift
//  Trai
//
//  Reusable context attachment model and composer card for Trai chat.
//

import SwiftUI

struct TraiChatContextAttachment: Identifiable, Codable, Equatable {
    enum Kind: String, Codable {
        case meal
        case workout
        case liveWorkout
        case plan
    }

    enum Accent: String, Codable {
        case accent
        case orange
        case green
        case blue
        case purple

        var color: Color {
            switch self {
            case .accent:
                return .accent
            case .orange:
                return .orange
            case .green:
                return .green
            case .blue:
                return .blue
            case .purple:
                return .purple
            }
        }
    }

    let id: UUID
    let kind: Kind
    let title: String
    let subtitle: String
    let iconName: String
    let accent: Accent
    let promptContext: String

    init(
        id: UUID = UUID(),
        kind: Kind,
        title: String,
        subtitle: String,
        iconName: String,
        accent: Accent,
        promptContext: String
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.subtitle = subtitle
        self.iconName = iconName
        self.accent = accent
        self.promptContext = promptContext
    }

    var requestContextPrefix: String {
        """
        The user attached this \(kind.displayName.lowercased()) as context for the conversation.
        Use the attached context to answer the user's message. Do not treat the attached context as a standalone user request.
        \(promptContext)

        User message:
        """
    }
}

extension TraiChatContextAttachment.Kind {
    var displayName: String {
        switch self {
        case .meal:
            return "Meal"
        case .workout:
            return "Workout"
        case .liveWorkout:
            return "Workout"
        case .plan:
            return "Plan"
        }
    }
}

struct TraiChatContextAttachmentCard: View {
    let attachment: TraiChatContextAttachment
    let onRemove: () -> Void

    var body: some View {
        content
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(minHeight: 50)
            .glassEffect(
                .regular
                    .tint(attachment.accent.color.opacity(0.14)),
                in: .capsule
            )
            .overlay {
                Capsule()
                    .strokeBorder(attachment.accent.color.opacity(0.18), lineWidth: 1)
            }
    }

    private var content: some View {
        HStack(spacing: 10) {
            icon

            VStack(alignment: .leading, spacing: 3) {
                Text(attachment.kind.contextLabel)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(attachment.accent.color)
                    .lineLimit(1)

                Text(attachment.title)
                    .font(.traiLabel(14))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .symbolRenderingMode(.hierarchical)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove attached context")
        }
    }

    private var icon: some View {
        Image(systemName: attachment.iconName)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(attachment.accent.color)
            .frame(width: 34, height: 34)
            .background(
                attachment.accent.color.opacity(0.16),
                in: Circle()
            )
    }
}

private extension TraiChatContextAttachment.Kind {
    var contextLabel: String {
        switch self {
        case .meal:
            return "MEAL CONTEXT"
        case .workout, .liveWorkout:
            return "WORKOUT CONTEXT"
        case .plan:
            return "PLAN CONTEXT"
        }
    }
}

extension TraiChatContextAttachment {
    private static let encoder = JSONEncoder()
    private static let decoder = JSONDecoder()

    var storageValue: String {
        guard let data = try? Self.encoder.encode(self) else { return "" }
        return data.base64EncodedString()
    }

    init?(storageValue: String) {
        guard !storageValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let data = Data(base64Encoded: storageValue),
              let attachment = try? Self.decoder.decode(Self.self, from: data) else {
            return nil
        }
        self = attachment
    }
}

extension PendingTraiChatLaunchRequest {
    static func hasValidPendingTraiChatPayload(in defaults: UserDefaults = .standard) -> Bool {
        let prompt = defaults.string(forKey: SharedStorageKeys.Chat.pendingPrompt) ?? ""
        let contextAttachment = defaults.string(forKey: SharedStorageKeys.Chat.pendingContextAttachment) ?? ""
        return !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || TraiChatContextAttachment(storageValue: contextAttachment) != nil
    }
}

extension FoodEntry {
    var traiChatContextAttachment: TraiChatContextAttachment {
        let subtitle = [
            "\(calories) kcal",
            "\(Int(proteinGrams.rounded()))g protein"
        ].joined(separator: " · ")

        return TraiChatContextAttachment(
            id: id,
            kind: .meal,
            title: name,
            subtitle: subtitle,
            iconName: semanticMeal.iconName,
            accent: .orange,
            promptContext: traiMealContext
        )
    }

    private var traiMealContext: String {
        var lines: [String] = [
            "Meal: \(name)",
            "Logged: \(loggedAt.formatted(date: .abbreviated, time: .shortened))",
            "Semantic meal: \(semanticMeal.displayName)",
            "Nutrition: \(calories) kcal, \(Self.traiFormatMacroValue(proteinGrams))g protein, \(Self.traiFormatMacroValue(carbsGrams))g carbs, \(Self.traiFormatMacroValue(fatGrams))g fat."
        ]

        if let fiberGrams {
            lines.append("Fiber: \(Self.traiFormatMacroValue(fiberGrams))g.")
        }
        if let sugarGrams {
            lines.append("Sugar: \(Self.traiFormatMacroValue(sugarGrams))g.")
        }
        if let servingSize, !servingSize.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            lines.append("Serving size: \(servingSize).")
        }
        if let userDescription, !userDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            lines.append("User notes: \(userDescription).")
        }

        return lines.joined(separator: "\n")
    }

    private static func traiFormatMacroValue(_ value: Double) -> String {
        let rounded = value.rounded()
        if abs(value - rounded) < 0.05 {
            return String(Int(rounded))
        }
        return value.formatted(.number.precision(.fractionLength(1)))
    }
}

extension WorkoutSession {
    var traiChatContextAttachment: TraiChatContextAttachment {
        let details = [
            formattedDuration,
            formattedDistance,
            setMetricPhrase
        ].compactMap { $0 }

        return TraiChatContextAttachment(
            id: id,
            kind: .workout,
            title: displayName,
            subtitle: details.isEmpty ? displayTypeName : details.prefix(2).joined(separator: " · "),
            iconName: iconName,
            accent: .green,
            promptContext: traiReviewPrompt
        )
    }
}

extension LiveWorkout {
    var traiChatContextAttachment: TraiChatContextAttachment {
        let loggedEntryCount = entrySummaryStats.entryCount
        let subtitle = loggedEntryCount > 0
            ? "\(formattedDuration) · \(loggedEntryCount) logged \(loggedEntryCount == 1 ? "entry" : "entries")"
            : formattedDuration

        return TraiChatContextAttachment(
            id: id,
            kind: .liveWorkout,
            title: name,
            subtitle: subtitle,
            iconName: type.iconName,
            accent: .green,
            promptContext: traiReviewPrompt
        )
    }
}
