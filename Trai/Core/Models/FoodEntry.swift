import Foundation
import SwiftData

/// Represents a logged food item with nutritional information
@Model
final class FoodEntry {
    var id: UUID = UUID()
    var name: String = ""

    /// Meal type: "breakfast", "lunch", "dinner", or "snack"
    /// Deprecated: Use sessionId for grouping instead
    var mealType: String = "snack"

    // Session-based grouping (replaces rigid meal types)
    /// Groups items logged together in the same session
    var sessionId: UUID?
    /// Order within the session (0-based)
    var sessionOrder: Int = 0
    /// How the food was logged: "manual", "camera", "photo", "description"
    var inputMethod: String = "manual"

    // Nutritional information
    var calories: Int = 0
    var proteinGrams: Double = 0
    var carbsGrams: Double = 0
    var fatGrams: Double = 0
    var fiberGrams: Double?
    var sugarGrams: Double?

    var servingSize: String?
    var servingQuantity: Double = 1.0

    /// Local storage key for image data (blob is stored on-device, not in CloudKit).
    var imageStorageKey: String?

    /// Legacy CloudKit-backed image blob. Kept for one-way migration to local store.
    @Attribute(.externalStorage, originalName: "imageData") private var legacyImageData: Data?

    /// Image data from photo taken of the food (local-only).
    @Transient
    var imageData: Data? {
        get {
            if let key = imageStorageKey,
               let data = LocalImageStore.shared.loadData(for: key) {
                return data
            }

            guard migrateLegacyImageToLocalStoreIfNeeded() else { return nil }
            return imageStorageKey.flatMap { LocalImageStore.shared.loadData(for: $0) }
        }
        set {
            guard let data = newValue, !data.isEmpty else {
                if let key = imageStorageKey {
                    LocalImageStore.shared.removeData(for: key)
                }
                imageStorageKey = nil
                legacyImageData = nil
                return
            }

            let key = imageStorageKey ?? localImageKey
            LocalImageStore.shared.storeData(data, for: key)
            imageStorageKey = key
            legacyImageData = nil
        }
    }

    /// User's text description of the food
    var userDescription: String?

    /// AI's analysis response (stored for reference)
    var aiAnalysis: String?

    /// Emoji representing the food (from AI suggestion)
    var emoji: String?

    var loggedAt: Date = Date()

    init() {}

    init(
        name: String,
        mealType: String,
        calories: Int,
        proteinGrams: Double,
        carbsGrams: Double,
        fatGrams: Double
    ) {
        self.name = name
        self.mealType = mealType
        self.calories = calories
        self.proteinGrams = proteinGrams
        self.carbsGrams = carbsGrams
        self.fatGrams = fatGrams
        self.emoji = FoodEmojiResolver.resolve(preferred: nil, foodName: name)
    }
}

// MARK: - Meal Type Helper

extension FoodEntry {
    enum MealType: String, CaseIterable, Identifiable {
        case breakfast = "breakfast"
        case lunch = "lunch"
        case dinner = "dinner"
        case snack = "snack"

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .breakfast: "Breakfast"
            case .lunch: "Lunch"
            case .dinner: "Dinner"
            case .snack: "Snack"
            }
        }

        var iconName: String {
            switch self {
            case .breakfast: "sun.horizon.fill"
            case .lunch: "sun.max.fill"
            case .dinner: "moon.fill"
            case .snack: "carrot.fill"
            }
        }
    }

    var meal: MealType {
        get { MealType(rawValue: mealType) ?? .snack }
        set { mealType = newValue.rawValue }
    }
}

// MARK: - Input Method Helper

extension FoodEntry {
    enum InputMethod: String, CaseIterable, Identifiable {
        case manual = "manual"
        case camera = "camera"
        case photo = "photo"
        case description = "description"

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .manual: "Manual Entry"
            case .camera: "Camera Capture"
            case .photo: "Photo Library"
            case .description: "Text Description"
            }
        }

        var iconName: String {
            switch self {
            case .manual: "square.and.pencil"
            case .camera: "camera.fill"
            case .photo: "photo.fill"
            case .description: "text.bubble.fill"
            }
        }
    }

    var input: InputMethod {
        get { InputMethod(rawValue: inputMethod) ?? .manual }
        set { inputMethod = newValue.rawValue }
    }
}

// MARK: - Computed Properties

extension FoodEntry {
    private var localImageKey: String {
        "food-\(id.uuidString.lowercased())"
    }

    /// Make sure all entries have a persisted emoji for image-less rendering on other devices.
    func ensureDisplayMetadata() {
        emoji = FoodEmojiResolver.resolve(preferred: emoji, foodName: name)
    }

    @discardableResult
    func migrateLegacyImageToLocalStoreIfNeeded() -> Bool {
        guard let legacyImageData, !legacyImageData.isEmpty else { return false }
        let key = imageStorageKey ?? localImageKey
        LocalImageStore.shared.storeData(legacyImageData, for: key)
        imageStorageKey = key
        self.legacyImageData = nil
        return true
    }

    /// Display emoji with fallback to fork and knife
    var displayEmoji: String {
        FoodEmojiResolver.resolve(preferred: emoji, foodName: name)
    }

    /// Total macros in grams
    var totalMacroGrams: Double {
        proteinGrams + carbsGrams + fatGrams
    }

    /// Protein percentage of total calories
    var proteinPercentage: Double {
        guard calories > 0 else { return 0 }
        return (proteinGrams * 4 / Double(calories)) * 100
    }

    /// Carbs percentage of total calories
    var carbsPercentage: Double {
        guard calories > 0 else { return 0 }
        return (carbsGrams * 4 / Double(calories)) * 100
    }

    /// Fat percentage of total calories
    var fatPercentage: Double {
        guard calories > 0 else { return 0 }
        return (fatGrams * 9 / Double(calories)) * 100
    }
}
