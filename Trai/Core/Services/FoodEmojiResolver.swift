import Foundation

enum FoodEmojiResolver {
    static let fallbackEmoji = "🍽️"

    static func resolve(preferred: String?, foodName: String?) -> String {
        if let preferred {
            let trimmed = preferred.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed
            }
        }

        guard let foodName else { return fallbackEmoji }
        let name = foodName.lowercased()

        if containsAny(of: ["coffee", "espresso", "latte", "cappuccino", "tea"], in: name) { return "☕" }
        if containsAny(of: ["salad", "greens", "kale"], in: name) { return "🥗" }
        if containsAny(of: ["egg", "omelet", "omelette"], in: name) { return "🍳" }
        if containsAny(of: ["chicken", "turkey"], in: name) { return "🍗" }
        if containsAny(of: ["beef", "steak", "burger"], in: name) { return "🥩" }
        if containsAny(of: ["fish", "salmon", "tuna", "shrimp"], in: name) { return "🐟" }
        if containsAny(of: ["pizza"], in: name) { return "🍕" }
        if containsAny(of: ["sandwich", "wrap", "burrito"], in: name) { return "🥪" }
        if containsAny(of: ["rice", "bowl"], in: name) { return "🍚" }
        if containsAny(of: ["pasta", "spaghetti", "noodle"], in: name) { return "🍝" }
        if containsAny(of: ["bread", "toast", "bagel"], in: name) { return "🍞" }
        if containsAny(of: ["soup"], in: name) { return "🍲" }
        if containsAny(of: ["oat", "oatmeal", "porridge"], in: name) { return "🥣" }
        if containsAny(of: ["apple", "banana", "berry", "fruit", "orange", "grape"], in: name) { return "🍎" }
        if containsAny(of: ["avocado"], in: name) { return "🥑" }
        if containsAny(of: ["broccoli", "vegetable", "veggie", "carrot"], in: name) { return "🥦" }
        if containsAny(of: ["yogurt"], in: name) { return "🥛" }
        if containsAny(of: ["milk", "protein shake", "shake", "smoothie"], in: name) { return "🥤" }
        if containsAny(of: ["cookie", "cake", "dessert", "ice cream"], in: name) { return "🍰" }

        return fallbackEmoji
    }

    private static func containsAny(of keywords: [String], in text: String) -> Bool {
        keywords.contains { text.contains($0) }
    }
}
