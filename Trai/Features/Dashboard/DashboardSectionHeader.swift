import SwiftUI

enum DashboardSection: Int, CaseIterable, Identifiable {
    case today, nutrition, activity, weight
    var id: Int { rawValue }
    var title: String {
        switch self { case .today: "Today"; case .nutrition: "Nutrition"; case .activity: "Activity"; case .weight: "Weight" }
    }
}

/// The miniature previews are deliberately ordinary fills, not nested glass lenses.
struct DashboardSectionHeader: View {
    @Binding var selection: DashboardSection
    let calories: Int
    let macroProgress: [Double]
    let trainingDays: [TrainingRhythmDay]
    let weeklyTrainingTarget: Int?
    let weightLabel: String
    let onAccount: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .caption) private var scale = 1.0

    var body: some View {
        HStack(spacing: 0) {
            Button(action: onAccount) {
                Image(systemName: "person.crop.circle")
                    .font(.system(size: 24))
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .tint(.primary)
            .accessibilityLabel("Account and settings")
            .accessibilityIdentifier("dashboardAccount")
            .frame(minWidth: 44, minHeight: 44)
            .padding(.leading, 16)
            .padding(.trailing, 8)
            if typeSize.isAccessibilitySize {
                sectionMenu
            } else {
                sectionChips
            }
        }
    }

    private var sectionMenu: some View {
        Menu {
            ForEach(DashboardSection.allCases) { section in
                Button(section.title) { selection = section }
                    .accessibilityIdentifier("dashboardSection\(section.title)")
            }
        } label: {
            HStack {
                Text(selection.title).font(.headline)
                Spacer(minLength: 8)
                Image(systemName: "chevron.down")
                    .font(.system(size: 16, weight: .semibold))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: 44)
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .padding(.trailing, 16)
        .accessibilityIdentifier("dashboardSectionMenu")
    }

    private var sectionChips: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                GlassEffectContainer(spacing: 6) {
                    HStack(spacing: 7) {
                        ForEach(DashboardSection.allCases) { section in
                            Button {
                                withAnimation(reduceMotion ? nil : .smooth(duration: 0.3)) { selection = section }
                            } label: {
                                HStack(spacing: 6) {
                                    preview(section).frame(width: 28, height: 34)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(section.title).font(.system(size: 11 * scale, weight: .medium)).foregroundStyle(.secondary)
                                        Text(value(section)).font(.system(size: 12 * scale, weight: .semibold))
                                            .lineLimit(1).minimumScaleFactor(0.85)
                                    }
                                }
                                .foregroundStyle(.primary)
                                .padding(.horizontal, 9)
                                .frame(width: 112 * scale, height: 54 * scale)
                                .glassEffect(.regular.tint(selection == section ? Color.red.opacity(0.16) : .clear).interactive(), in: .rect(cornerRadius: 16))
                            }
                            .buttonStyle(.plain).id(section)
                            .accessibilityIdentifier("dashboardSection\(section.title)")
                            .accessibilityLabel(section.title)
                            .accessibilityValue(value(section))
                            .accessibilityAddTraits(selection == section ? [.isSelected] : [])
                        }
                    }.padding(.vertical, 8)
                }
            }.scrollIndicators(.hidden)
                .contentMargins(.horizontal, 16, for: .scrollContent)
                .onChange(of: selection) { _, next in
                    withAnimation(reduceMotion ? nil : .smooth(duration: 0.3)) { proxy.scrollTo(next, anchor: .center) }
                }
        }
    }

    private func value(_ section: DashboardSection) -> String {
        let workoutCount = trainingDays.reduce(0) { $0 + $1.count }
        return switch section {
        case .today: "Overview"
        case .nutrition: "\(calories.formatted()) kcal"
        case .activity: "\(trainingDays.contains(where: \.isPartial) ? "≥" : "")\(workoutCount) \(workoutCount == 1 ? "workout" : "workouts")"
        case .weight: weightLabel
        }
    }

    @ViewBuilder private func preview(_ section: DashboardSection) -> some View {
        switch section {
        case .today: Image(systemName: "circle.hexagongrid.fill").font(.title2).foregroundStyle(Color.accentColor.gradient)
        case .nutrition:
            ZStack {
                orb(0, color: .red, size: 22).offset(x: -6, y: -5)
                orb(1, color: .cyan, size: 18).offset(x: 7)
                orb(2, color: .purple, size: 16).offset(y: 9)
            }.accessibilityHidden(true)
        case .activity:
            WorkoutGauge(target: weeklyTrainingTarget, completed: trainingDays.reduce(0) { $0 + $1.count }, miniature: true, glass: false)
                .accessibilityHidden(true)
        case .weight:
            WeightScaleMark(lit: false, weight: 0)
                .accessibilityHidden(true)
        }
    }

    private func orb(_ index: Int, color: Color, size: CGFloat) -> some View {
        ZStack(alignment: .bottom) {
            Circle().fill(color.opacity(0.13))
            Rectangle().fill(color.gradient).frame(height: size * min(1, max(0, macroProgress.indices.contains(index) ? macroProgress[index] : 0)))
        }.frame(width: size, height: size).clipShape(.circle)
            .overlay { Circle().fill(RadialGradient(colors: [.white.opacity(0.35), .clear], center: .topLeading, startRadius: 0, endRadius: size)) }
    }
}
