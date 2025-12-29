//
//  ChatContentList.swift
//  Plates
//
//  Chat message list with loading indicator
//

import SwiftUI

struct ChatContentList: View {
    let messages: [ChatMessage]
    let isLoading: Bool
    let isStreamingResponse: Bool
    let onSuggestionTapped: (String) -> Void
    let onAcceptMeal: (SuggestedFoodEntry, ChatMessage) -> Void
    let onEditMeal: (ChatMessage, SuggestedFoodEntry) -> Void
    let onDismissMeal: (ChatMessage) -> Void
    let onViewLoggedMeal: (UUID) -> Void

    var body: some View {
        LazyVStack(spacing: 12) {
            if messages.isEmpty {
                EmptyChatView(onSuggestionTapped: onSuggestionTapped)
            } else {
                ForEach(messages) { message in
                    if !message.content.isEmpty || message.isFromUser || message.errorMessage != nil || message.hasPendingMealSuggestion || message.loggedFoodEntryId != nil {
                        ChatBubble(
                            message: message,
                            onAcceptMeal: { meal in
                                onAcceptMeal(meal, message)
                            },
                            onEditMeal: { meal in
                                onEditMeal(message, meal)
                            },
                            onDismissMeal: {
                                onDismissMeal(message)
                            },
                            onViewLoggedMeal: { entryId in
                                onViewLoggedMeal(entryId)
                            }
                        )
                        .id(message.id)
                    }
                }
            }

            if isLoading && !isStreamingResponse {
                LoadingBubble()
            }
        }
        .padding()
    }
}
