import Foundation

/// A value copy of a food log used for safe replay and deletion undo.
struct FoodEntrySnapshot {
    let id: UUID
    let name: String
    let mealType: String
    let sessionId: UUID?
    let sessionOrder: Int
    let inputMethod: String
    let calories: Int
    let proteinGrams: Double
    let carbsGrams: Double
    let fatGrams: Double
    let fiberGrams: Double?
    let sugarGrams: Double?
    let servingSize: String?
    let servingQuantity: Double
    let imageStorageKey: String?
    let imageData: Data?
    let userDescription: String?
    let aiAnalysis: String?
    let emoji: String?
    let acceptedSnapshotData: Data?
    let acceptedComponentsData: Data?
    let originalLoggedComponentsData: Data?
    let loggedComponentsData: Data?
    let foodMemoryIdString: String?
    let foodMemoryMatchConfidence: Double
    let foodMemoryMatchVersion: Int
    let foodMemoryResolutionStateRaw: String
    let foodMemoryResolvedAt: Date?
    let foodMemoryNeedsResolution: Bool
    let foodMemoryWasUserEdited: Bool
    let foodMemoryResolutionExplanationData: Data?
    let loggedAt: Date

    init(entry: FoodEntry, includeImage: Bool = true) {
        id = entry.id
        name = entry.name
        mealType = entry.mealType
        sessionId = entry.sessionId
        sessionOrder = entry.sessionOrder
        inputMethod = entry.inputMethod
        calories = entry.calories
        proteinGrams = entry.proteinGrams
        carbsGrams = entry.carbsGrams
        fatGrams = entry.fatGrams
        fiberGrams = entry.fiberGrams
        sugarGrams = entry.sugarGrams
        servingSize = entry.servingSize
        servingQuantity = entry.servingQuantity
        imageData = includeImage ? entry.imageData : nil
        imageStorageKey = entry.imageStorageKey
        userDescription = entry.userDescription
        aiAnalysis = entry.aiAnalysis
        emoji = entry.emoji
        acceptedSnapshotData = entry.acceptedSnapshotData
        acceptedComponentsData = entry.acceptedComponentsData
        originalLoggedComponentsData = entry.originalLoggedComponentsData
        loggedComponentsData = entry.loggedComponentsData
        foodMemoryIdString = entry.foodMemoryIdString
        foodMemoryMatchConfidence = entry.foodMemoryMatchConfidence
        foodMemoryMatchVersion = entry.foodMemoryMatchVersion
        foodMemoryResolutionStateRaw = entry.foodMemoryResolutionStateRaw
        foodMemoryResolvedAt = entry.foodMemoryResolvedAt
        foodMemoryNeedsResolution = entry.foodMemoryNeedsResolution
        foodMemoryWasUserEdited = entry.foodMemoryWasUserEdited
        foodMemoryResolutionExplanationData = entry.foodMemoryResolutionExplanationData
        loggedAt = entry.loggedAt
    }

    func makeRestoredEntry() -> FoodEntry {
        makeEntry(
            id: id,
            loggedAt: loggedAt,
            sessionId: sessionId,
            sessionOrder: sessionOrder,
            inputMethod: inputMethod,
            restoreImage: true
        )
    }

    func makeReplayEntry(
        id: UUID = UUID(),
        loggedAt: Date,
        sessionId: UUID?,
        sessionOrder: Int
    ) -> FoodEntry {
        let entry = makeEntry(
            id: id,
            loggedAt: loggedAt,
            sessionId: sessionId,
            sessionOrder: sessionOrder,
            inputMethod: FoodEntry.InputMethod.memorySuggestion.rawValue,
            restoreImage: false
        )
        entry.mealType = FoodEntry.mealType(for: loggedAt).rawValue
        return entry
    }

    private func makeEntry(
        id: UUID,
        loggedAt: Date,
        sessionId: UUID?,
        sessionOrder: Int,
        inputMethod: String,
        restoreImage: Bool
    ) -> FoodEntry {
        let entry = FoodEntry()
        entry.id = id
        entry.name = name
        entry.mealType = mealType
        entry.sessionId = sessionId
        entry.sessionOrder = sessionOrder
        entry.inputMethod = inputMethod
        entry.calories = calories
        entry.proteinGrams = proteinGrams
        entry.carbsGrams = carbsGrams
        entry.fatGrams = fatGrams
        entry.fiberGrams = fiberGrams
        entry.sugarGrams = sugarGrams
        entry.servingSize = servingSize
        entry.servingQuantity = servingQuantity
        entry.userDescription = userDescription
        entry.aiAnalysis = aiAnalysis
        entry.emoji = emoji
        entry.acceptedSnapshotData = acceptedSnapshotData
        entry.acceptedComponentsData = acceptedComponentsData
        entry.originalLoggedComponentsData = originalLoggedComponentsData
        entry.loggedComponentsData = loggedComponentsData
        entry.foodMemoryIdString = foodMemoryIdString
        entry.foodMemoryMatchConfidence = foodMemoryMatchConfidence
        entry.foodMemoryMatchVersion = foodMemoryMatchVersion
        entry.foodMemoryResolutionStateRaw = foodMemoryResolutionStateRaw
        entry.foodMemoryResolvedAt = foodMemoryResolvedAt
        entry.foodMemoryNeedsResolution = foodMemoryNeedsResolution
        entry.foodMemoryWasUserEdited = foodMemoryWasUserEdited
        entry.foodMemoryResolutionExplanationData = foodMemoryResolutionExplanationData
        entry.loggedAt = loggedAt
        if restoreImage {
            entry.imageData = imageData
        }
        return entry
    }
}
