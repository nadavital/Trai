import Foundation
import NaturalLanguage

struct FoodSemanticNutritionProfile {
    let calories: Double
    let proteinGrams: Double
    let carbsGrams: Double
    let fatGrams: Double
}

struct FoodSemanticServingProfile {
    let servingText: String?
    let quantity: Double?
    let unit: String?
}

struct FoodSemanticSatisfactionDecision: Sendable, Equatable {
    let score: Double
    let isSatisfied: Bool
    let isSemanticVariant: Bool
}

struct FoodSemanticSatisfactionScorer {
    private static let alreadySatisfiedThreshold = 0.62
    private static let semanticVariantSatisfiedThreshold = 0.52
    private static let semanticVariantSignalThreshold = 0.28
    private static let embeddingDistanceScale = 1.25
    private static let wordEmbedding = NLEmbedding.wordEmbedding(for: .english)

    func decision(
        exactComponentScore: Double,
        componentSemanticScore: Double,
        nameScore: Double,
        macroScore: Double,
        servingScore: Double
    ) -> FoodSemanticSatisfactionDecision {
        let componentScore = max(exactComponentScore, componentSemanticScore)
        let score = semanticSatisfactionScore(
            componentScore: componentScore,
            nameScore: nameScore,
            macroScore: macroScore,
            servingScore: servingScore
        )
        if score >= Self.alreadySatisfiedThreshold {
            return FoodSemanticSatisfactionDecision(
                score: score,
                isSatisfied: true,
                isSemanticVariant: false
            )
        }

        let semanticVariantSignal = max(componentSemanticScore, nameScore)
        let isSemanticVariant = exactComponentScore == 0
            && score >= Self.semanticVariantSatisfiedThreshold
            && semanticVariantSignal >= Self.semanticVariantSignalThreshold
            && macroScore >= 0.82
            && servingScore >= 0.55

        return FoodSemanticSatisfactionDecision(
            score: score,
            isSatisfied: isSemanticVariant,
            isSemanticVariant: isSemanticVariant
        )
    }

    func nameSimilarity(candidateNames: [String], loggedName: String) -> Double {
        let names = candidateNames.filter { !$0.isEmpty }
        guard !names.isEmpty, !loggedName.isEmpty else { return 0 }
        return names.map { textSemanticSimilarity($0, loggedName) }.max() ?? 0
    }

    func componentSemanticSimilarity(candidateComponents: [String], loggedComponents: [String]) -> Double {
        guard !candidateComponents.isEmpty, !loggedComponents.isEmpty else { return 0 }
        return symmetricBestAverage(lhs: candidateComponents, rhs: loggedComponents) {
            textSemanticSimilarity($0, $1)
        }
    }

    func macroSimilarity(
        candidate: FoodSemanticNutritionProfile?,
        logged: FoodSemanticNutritionProfile
    ) -> Double {
        guard let candidate else { return 0.75 }
        return (
            toleranceScore(lhs: candidate.calories, rhs: logged.calories, absoluteTolerance: 160, relativeTolerance: 0.35)
                + toleranceScore(lhs: candidate.proteinGrams, rhs: logged.proteinGrams, absoluteTolerance: 12, relativeTolerance: 0.45)
                + toleranceScore(lhs: candidate.carbsGrams, rhs: logged.carbsGrams, absoluteTolerance: 18, relativeTolerance: 0.45)
                + toleranceScore(lhs: candidate.fatGrams, rhs: logged.fatGrams, absoluteTolerance: 10, relativeTolerance: 0.50)
        ) / 4
    }

    func servingSimilarity(
        candidate: FoodSemanticServingProfile?,
        logged: FoodSemanticServingProfile
    ) -> Double {
        guard let candidate else { return 0.75 }
        if let candidateUnit = candidate.unit?.lowercased(),
           let loggedUnit = logged.unit?.lowercased(),
           candidateUnit == loggedUnit {
            if let candidateQuantity = candidate.quantity,
               let loggedQuantity = logged.quantity {
                return toleranceScore(
                    lhs: candidateQuantity,
                    rhs: loggedQuantity,
                    absoluteTolerance: 0.5,
                    relativeTolerance: 0.40
                )
            }
            return 1
        }

        let candidateText = candidate.servingText?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let loggedText = logged.servingText?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if candidateText != nil || loggedText != nil {
            return candidateText == loggedText ? 1 : 0.55
        }
        return 0.75
    }

    static func jaccard<T: Hashable>(lhs: Set<T>, rhs: Set<T>) -> Double {
        guard !lhs.isEmpty, !rhs.isEmpty else { return 0 }
        return Double(lhs.intersection(rhs).count) / Double(lhs.union(rhs).count)
    }

    private func semanticSatisfactionScore(
        componentScore: Double,
        nameScore: Double,
        macroScore: Double,
        servingScore: Double
    ) -> Double {
        if componentScore > 0 {
            return 0.46 * componentScore
                + 0.22 * nameScore
                + 0.24 * macroScore
                + 0.08 * servingScore
        }

        return 0.44 * nameScore
            + 0.38 * macroScore
            + 0.18 * servingScore
    }

    private func textSemanticSimilarity(_ lhs: String, _ rhs: String) -> Double {
        max(tokenSimilarity(lhs, rhs), embeddingTokenSimilarity(lhs, rhs))
    }

    private func tokenSimilarity(_ lhs: String, _ rhs: String) -> Double {
        let lhsTokens = Set(lhs.split(separator: " ").map(String.init).filter { !$0.isEmpty })
        let rhsTokens = Set(rhs.split(separator: " ").map(String.init).filter { !$0.isEmpty })
        return Self.jaccard(lhs: lhsTokens, rhs: rhsTokens)
    }

    private func embeddingTokenSimilarity(_ lhs: String, _ rhs: String) -> Double {
        let lhsTokens = lhs.split(separator: " ").map(String.init).filter { !$0.isEmpty }
        let rhsTokens = rhs.split(separator: " ").map(String.init).filter { !$0.isEmpty }
        guard !lhsTokens.isEmpty, !rhsTokens.isEmpty, let wordEmbedding = Self.wordEmbedding else { return 0 }

        return symmetricBestAverage(lhs: lhsTokens, rhs: rhsTokens) { lhsToken, rhsToken in
            let distance = wordEmbedding.distance(between: lhsToken, and: rhsToken)
            guard distance.isFinite else { return 0 }
            return max(0, 1 - min(distance, Self.embeddingDistanceScale) / Self.embeddingDistanceScale)
        }
    }

    private func symmetricBestAverage(
        lhs: [String],
        rhs: [String],
        score: (String, String) -> Double
    ) -> Double {
        guard !lhs.isEmpty, !rhs.isEmpty else { return 0 }
        let lhsBest = lhs.map { lhsValue in rhs.map { score(lhsValue, $0) }.max() ?? 0 }
        let rhsBest = rhs.map { rhsValue in lhs.map { score($0, rhsValue) }.max() ?? 0 }
        return (average(lhsBest) + average(rhsBest)) / 2
    }

    private func average(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    private func toleranceScore(
        lhs: Double,
        rhs: Double,
        absoluteTolerance: Double,
        relativeTolerance: Double
    ) -> Double {
        let tolerance = max(absoluteTolerance, max(abs(lhs), abs(rhs)) * relativeTolerance)
        guard tolerance > 0 else { return lhs == rhs ? 1 : 0 }
        return max(0, 1 - abs(lhs - rhs) / tolerance)
    }
}
