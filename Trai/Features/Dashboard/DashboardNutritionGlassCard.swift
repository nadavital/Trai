//
//  DashboardNutritionGlassCard.swift
//  Trai
//

import SwiftUI

/// A compact, live-data nutrition summary for the dashboard.
struct DashboardNutritionGlassCard: View {
    let entries: [FoodEntry]
    let profile: UserProfile?
    var hasWorkoutToday = false
    var isSection = false
    var animates = true
    @State private var isOnscreen = false
    let onLogFood: () -> Void
    let onDetails: () -> Void

    @State private var motionStart = Date()
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var totals: NutritionTotals {
        NutritionTotals(entries: entries)
    }

    private var nutrients: [Nutrient] {
        let enabled = profile?.enabledMacros ?? [.protein, .carbs, .fat, .fiber]
        return [
            Nutrient(type: .protein, name: "Protein", value: totals.protein, target: validGoal(profile?.dailyProteinGoal), tint: .traiProtein),
            Nutrient(type: .carbs, name: "Carbs", value: totals.carbs, target: validGoal(profile?.dailyCarbsGoal), tint: .traiCarbs),
            Nutrient(type: .fat, name: "Fat", value: totals.fat, target: validGoal(profile?.dailyFatGoal), tint: .traiFat),
            Nutrient(type: .fiber, name: "Fiber", value: totals.fiber, target: validGoal(profile?.dailyFiberGoal), tint: .traiFiber, hasCompleteCoverage: totals.hasCompleteFiberCoverage),
            Nutrient(type: .sugar, name: "Sugar", value: totals.sugar, target: validGoal(profile?.dailySugarGoal), tint: MacroType.sugar.color, hasCompleteCoverage: totals.hasCompleteSugarCoverage)
        ].filter { enabled.contains($0.type) }
    }

    private var calorieTarget: Int? {
        validGoal(profile?.effectiveCalorieGoal(hasWorkoutToday: hasWorkoutToday))
    }

    private var usesExpandedLayout: Bool {
        dynamicTypeSize >= .accessibility1
    }

    var body: some View {
        VStack(alignment: .leading, spacing: TraiSpacing.md) {
            if isSection {
                calorieSection
                orbButton
                    .scaleEffect(1.45)
                    .frame(maxWidth: .infinity)
                    .frame(height: 280)
                nutrientRows
            } else if usesExpandedLayout {
                VStack(alignment: .leading, spacing: TraiSpacing.md) {
                    nutrientRows
                    orbButton
                        .frame(maxWidth: .infinity)
                }
            } else {
                HStack(alignment: .center, spacing: 16) {
                    nutrientRows
                    orbButton
                }
            }

            if !isSection { calorieSection }
        }
        .padding(isSection ? 4 : 20)
        .background {
            if !isSection {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
                    .shadow(color: .black.opacity(colorScheme == .dark ? 0.12 : 0.04), radius: 10, y: 3)
            }
        }
        .onScrollVisibilityChange(threshold: 0.1) { isOnscreen = $0 }
        .contentShape(.rect(cornerRadius: 28))
        .onTapGesture { if !isSection { onDetails() } }
        .accessibilityElement(children: .contain)
        .accessibilityAction(named: "Show nutrition details", onDetails)
        .animation(reduceMotion ? nil : .smooth(duration: 0.65), value: entries.map { "\($0.id)-\($0.calories)-\($0.proteinGrams)-\($0.carbsGrams)-\($0.fatGrams)-\($0.fiberGrams ?? -1)-\($0.sugarGrams ?? -1)" })
    }

    private var nutrientRows: some View {
        let layout = isSection && !usesExpandedLayout && nutrients.count <= 4
            ? AnyLayout(HStackLayout(alignment: .top, spacing: 12))
            : AnyLayout(VStackLayout(alignment: .leading, spacing: TraiSpacing.sm))
        return layout {
            ForEach(nutrients) { nutrient in
                VStack(alignment: .leading, spacing: 1) {
                    Text(nutrient.name)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(nutrient.ink(for: colorScheme))

                    Text(nutrient.valueText)
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                        .contentTransition(.numericText())
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(nutrient.name)
                .accessibilityValue(nutrient.accessibilityValue)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var orbButton: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20.0, paused: reduceMotion || scenePhase != .active || !animates || !isOnscreen)) { context in
            DashboardNutritionOrbCluster(
                nutrients: nutrients,
                showsLabels: isSection,
                time: reduceMotion ? 0 : context.date.timeIntervalSince(motionStart),
                onDetails: onDetails
            )
        }
        .frame(width: 172, height: 190)
    }

    private var calorieSection: some View {
        VStack(alignment: .leading, spacing: TraiSpacing.sm) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: TraiSpacing.sm) {
                    Text("Calories")
                        .font(.subheadline.weight(.semibold))
                    if !usesExpandedLayout { Spacer(minLength: TraiSpacing.xs) }
                    calorieValue
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Calories")
                        .font(.subheadline.weight(.semibold))
                    calorieValue
                }
            }

            CalorieGlassBar(
                value: totals.calories,
                target: calorieTarget,
                reduceTransparency: reduceTransparency
            )
            .frame(height: 28)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("dashboardNutritionCalories")
        .accessibilityLabel("Calories")
        .accessibilityValue(calorieAccessibilityValue)
    }

    private var calorieValue: some View {
        Group {
            if let target = calorieTarget {
                let overage = totals.calories - target
                Text("\(totals.calories.formatted()) / \(target.formatted())")
                    + Text(overage > 0 ? "  +\(overage.formatted()) kcal" : " kcal")
                        .foregroundStyle(overage > 0 ? overTargetColor : .secondary)
            } else {
                Text("\(totals.calories.formatted()) kcal · Target not set")
            }
        }
        .font(.footnote)
        .monospacedDigit()
        .foregroundStyle(.secondary)
        .contentTransition(.numericText())
    }

    private var overTargetColor: Color {
        colorScheme == .dark ? .pink : Color(red: 0.65, green: 0.08, blue: 0.19)
    }

    private var calorieAccessibilityValue: String {
        guard let calorieTarget else {
            return "\(totals.calories) kilocalories, target not set"
        }
        let overage = totals.calories - calorieTarget
        return "\(totals.calories) of \(calorieTarget) kilocalories" + (overage > 0 ? ", \(overage) over target" : "")
    }

    private func validGoal(_ value: Int?) -> Int? {
        guard let value, value > 0 else { return nil }
        return value
    }
}

private struct NutritionTotals {
    let calories: Int
    let protein: Double
    let carbs: Double
    let fat: Double
    let fiber: Double
    let sugar: Double
    let hasCompleteSugarCoverage: Bool
    let hasCompleteFiberCoverage: Bool

    init(entries: [FoodEntry]) {
        calories = entries.reduce(0) { $0 + $1.calories }
        protein = entries.reduce(0) { $0 + $1.proteinGrams }
        carbs = entries.reduce(0) { $0 + $1.carbsGrams }
        fat = entries.reduce(0) { $0 + $1.fatGrams }
        fiber = entries.reduce(0) { $0 + ($1.fiberGrams ?? 0) }
        sugar = entries.reduce(0) { $0 + ($1.sugarGrams ?? 0) }
        hasCompleteSugarCoverage = entries.allSatisfy { $0.sugarGrams != nil }
        hasCompleteFiberCoverage = entries.allSatisfy { $0.fiberGrams != nil }
    }
}

private struct Nutrient: Identifiable {
    let type: MacroType
    let name: String
    let value: Double
    let target: Int?
    let tint: Color
    var hasCompleteCoverage = true

    var id: MacroType { type }

    var progress: Double? {
        guard hasCompleteCoverage, let target else { return nil }
        let fraction = max(0, min(1, value / Double(target)))
        // The native lens magnifies the empty upper area. Compensate the liquid
        // height so a small positive intake remains visible; exact amounts live
        // in the adjacent labels. Zero must still look empty.
        if fraction == 0 || fraction == 1 { return fraction }
        return 0.26 + fraction * 0.52
    }

    var isOverTarget: Bool {
        guard let target else { return false }
        return value > Double(target)
    }

    var valueText: String {
        if !hasCompleteCoverage {
            if let target { return "≥\(formatted(value)) / \(target.formatted()) g · Partial" }
            return "≥\(formatted(value)) g · Partial, target not set"
        }
        if let target {
            return "\(formatted(value)) / \(target.formatted()) g"
        } else {
            return "\(formatted(value)) g · Target not set"
        }
    }

    var accessibilityValue: String {
        if !hasCompleteCoverage {
            if let target { return "at least \(formatted(value)) grams, target \(target) grams, some entries have no \(name.lowercased()) value" }
            return "at least \(formatted(value)) grams, some entries have no \(name.lowercased()) value, target not set"
        }
        if let target {
            return "\(formatted(value)) grams, target \(target) grams" + (isOverTarget ? ", over target" : "")
        } else {
            return "\(formatted(value)) grams, target not set"
        }
    }

    var accessibilityValueWithName: String {
        "\(name), \(accessibilityValue)"
    }

    func ink(for scheme: ColorScheme) -> Color {
        if scheme == .dark {
            return tint.mix(with: .white, by: 0.42)
        }
        return tint.mix(with: .black, by: 0.62)
    }

    private func formatted(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(value.rounded() == value ? 0 : 1)))
    }
}

private struct DashboardNutritionOrbCluster: View {
    let nutrients: [Nutrient]
    var showsLabels = false
    @Environment(\.colorScheme) private var scheme
    let time: TimeInterval
    let onDetails: () -> Void

    var body: some View {
        ZStack {
            ForEach(nutrients) { nutrient in
                let layout = OrbLayout.layout(for: nutrient.type)
                Button(action: onDetails) {
                    NutritionGlassOrb(
                        tint: nutrient.tint,
                        level: nutrient.progress,
                        overTarget: nutrient.isOverTarget,
                        time: time + layout.phase
                    )
                    .frame(width: layout.size, height: layout.size)
                    .overlay {
                        if showsLabels {
                            Text(nutrient.name).font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundStyle(nutrient.ink(for: (nutrient.progress ?? 0) >= 0.5 ? .light : scheme))
                                .allowsHitTesting(false)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(nutrient.name)
                .accessibilityValue(nutrient.accessibilityValue)
                .accessibilityHint("Show nutrition details")
                .accessibilityIdentifier(nutrient.type == .protein ? "dashboardNutritionDetails" : "nutritionOrb-\(nutrient.name)")
                .offset(
                    x: layout.x + sin((time + layout.phase) * 0.24) * 1.5,
                    y: layout.y + cos((time + layout.phase) * 0.20) * 1.5
                )
            }
        }
    }
}

private struct OrbLayout {
    let size: CGFloat
    let x: CGFloat
    let y: CGFloat
    let phase: Double

    static func layout(for type: MacroType) -> OrbLayout {
        switch type {
        case .protein: OrbLayout(size: 86, x: -40, y: -42, phase: 0)
        case .carbs: OrbLayout(size: 70, x: 45, y: -14, phase: 2)
        case .fiber: OrbLayout(size: 59, x: 42, y: 61, phase: 4)
        case .fat: OrbLayout(size: 61, x: -33, y: 46, phase: 6)
        case .sugar: OrbLayout(size: 44, x: -5, y: 7, phase: 8)
        }
    }
}

private struct NutritionGlassOrb: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    let tint: Color
    let level: Double?
    let overTarget: Bool
    let time: TimeInterval

    private var displayTint: Color {
        overTarget ? tint.mix(with: .black, by: 0.34) : tint
    }

    var body: some View {
        let outline = NutritionOrbOutline(time: time)

        ZStack {
            outline.fill(displayTint.opacity(reduceTransparency ? 0.18 : 0.06))

            if let level {
                GeometryReader { geometry in
                    ZStack {
                        outline.fill(
                            LinearGradient(
                                colors: [displayTint.opacity(0.68), displayTint],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        if !reduceTransparency {
                            outline.fill(.white).colorEffect(ShaderLibrary.traiNutritionCurrent(
                                .float2(Float(geometry.size.width), Float(geometry.size.height)),
                                .color(displayTint),
                                .float(Float(time)),
                                .float(Float(level))
                            ))
                        }
                    }
                    .mask(NutritionFillSurface(level: level, phase: time * 1.2))
                }
            }

            if reduceTransparency {
                outline.stroke(displayTint.opacity(0.65), lineWidth: 1)
            } else {
                Color.clear.glassEffect(.clear.interactive(), in: outline)
                outline.stroke(displayTint.opacity(0.18), lineWidth: 0.75)
            }
        }
    }
}

private struct NutritionFillSurface: Shape {
    let level: Double
    let phase: Double

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.maxY))
        for index in 0...40 {
            let fraction = Double(index) / 40
            let wave = sin(fraction * .pi * 2 + phase)
            path.addLine(to: CGPoint(x: fraction * rect.width, y: rect.height * (1 - level) + wave))
        }
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct NutritionOrbOutline: Shape {
    let time: TimeInterval

    func path(in rect: CGRect) -> Path {
        var path = Path()
        for index in 0...64 {
            let angle = Double(index) / 64 * .pi * 2
            let ripple = 1 + 0.008 * sin(angle * 3 + time * 0.72) + 0.003 * cos(angle * 2 - time * 0.55)
            let point = CGPoint(
                x: rect.midX + cos(angle) * rect.width * 0.46 * ripple,
                y: rect.midY + sin(angle) * rect.height * 0.46 * ripple
            )
            index == 0 ? path.move(to: point) : path.addLine(to: point)
        }
        path.closeSubpath()
        return path
    }
}

struct CalorieGlassBar: View {
    let value: Int
    let target: Int?
    let reduceTransparency: Bool

    private var progress: Double {
        guard let target, target > 0 else { return 0 }
        return max(0, min(1, Double(value) / Double(target)))
    }

    private var fillColors: [Color] {
        let excess = target.map { max(0, Double(value) / Double($0) - 1) } ?? 0
        let darkness = min(0.42, excess * 1.8)
        return [
            Color.traiProtein.mix(with: .black, by: darkness),
            Color(red: 1.0, green: 0.53, blue: 0.36).mix(with: .black, by: darkness)
        ]
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.traiProtein.opacity(reduceTransparency ? 0.12 : 0.05))

                Capsule()
                    .fill(LinearGradient(colors: fillColors, startPoint: .leading, endPoint: .trailing))
                    .frame(width: geometry.size.width * progress)

                if !reduceTransparency {
                    Color.clear.glassEffect(.clear, in: .capsule)
                    Capsule().strokeBorder(Color.traiProtein.opacity(0.14), lineWidth: 0.75)
                }
            }
        }
    }
}

private extension Color {
    static let traiProtein = Color(red: 0.98, green: 0.25, blue: 0.30)
    static let traiCarbs = Color(red: 0.00, green: 0.73, blue: 0.79)
    static let traiFat = Color(red: 0.61, green: 0.35, blue: 0.97)
    static let traiFiber = Color(red: 0.23, green: 0.66, blue: 0.34)
}
