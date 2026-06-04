import Foundation
import SwiftData

@Model
final class FoodSuggestionFeedback {
    var id: UUID = UUID()
    var suggestionIDString: String = ""
    var statsData: Data?
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(suggestionID: UUID, stats: FoodMemorySuggestionStats, createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = UUID()
        self.suggestionIDString = suggestionID.uuidString
        self.stats = stats
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init() {}
}

extension FoodSuggestionFeedback {
    private static let encoder = JSONEncoder()
    private static let decoder = JSONDecoder()

    var suggestionID: UUID? {
        UUID(uuidString: suggestionIDString)
    }

    var stats: FoodMemorySuggestionStats? {
        get {
            guard let statsData else { return nil }
            return try? Self.decoder.decode(FoodMemorySuggestionStats.self, from: statsData)
        }
        set {
            statsData = try? Self.encoder.encode(newValue)
        }
    }
}

struct FoodSuggestionFeedbackSnapshot: Sendable {
    let suggestionID: UUID
    let stats: FoodMemorySuggestionStats
}
