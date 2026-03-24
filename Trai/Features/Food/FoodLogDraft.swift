//
//  FoodLogDraft.swift
//  Trai
//
//  Internal draft state for the food logging flow
//

import Foundation
import UIKit

enum FoodLogInputSource: String {
    case camera
    case photo
    case description
    case manual

    var foodEntryInputMethod: FoodEntry.InputMethod {
        switch self {
        case .camera:
            return .camera
        case .photo:
            return .photo
        case .description:
            return .description
        case .manual:
            return .manual
        }
    }

    var behaviorSource: String {
        rawValue
    }
}

struct FoodLogDraft {
    var sessionId: UUID?
    var image: UIImage?
    var description: String
    var inputSource: FoodLogInputSource
    var analysisResult: FoodAnalysis?
    var refinedSuggestion: SuggestedFoodEntry?

    init(
        sessionId: UUID? = nil,
        image: UIImage? = nil,
        description: String = "",
        inputSource: FoodLogInputSource
    ) {
        self.sessionId = sessionId
        self.image = image
        self.description = description
        self.inputSource = inputSource
        self.analysisResult = nil
        self.refinedSuggestion = nil
    }
}
