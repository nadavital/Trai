#if DEBUG
import SwiftUI

/// Deliberately isolated from production navigation and persistent model data.
struct SymbolExplorationView: View {
    @State private var section = 0
    @State private var dark = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    Picker("Study", selection: $section) {
                        Text("Activity").tag(0)
                        Text("Weight").tag(1)
                    }.pickerStyle(.segmented)
                    if section == 0 { ActivityPetalStudy() }
                    else { WeightPebbleStudy() }
                }
                .padding(20)
            }
            .background {
                LinearGradient(colors: [Color.red.opacity(dark ? 0.13 : 0.07), Color(.systemBackground), Color(.systemBackground)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .ignoresSafeArea()
            }
            .navigationTitle("Symbol studio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dark.toggle() } label: { Image(systemName: dark ? "sun.max" : "moon") }
                        .accessibilityLabel("Switch appearance")
                }
            }
            .safeAreaInset(edge: .bottom) {
                Text("Design study · sample data")
                    .font(.caption2).foregroundStyle(.secondary)
                    .padding(8).frame(maxWidth: .infinity)
                    .background(.bar)
            }
        }
        .tint(.accentColor)
        .preferredColorScheme(dark ? .dark : .light)
    }
}

struct ActivityPetalStudy: View {
    @State private var target = 4
    @State private var completed = 2
    @State private var spread = true
    @State private var hasTarget = true
    @State private var selected: Int?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(spacing: 18) {
            Picker("Arrangement", selection: $spread) {
                Text("Open petals").tag(true)
                Text("Folded petals").tag(false)
            }.pickerStyle(.segmented)

            ActivityPetalSymbol(target: hasTarget ? target : nil, completed: completed, spread: spread, selected: $selected)
                .frame(height: 280)

            VStack(spacing: 5) {
                Text(hasTarget ? "\(completed) of \(target) days" : "\(completed) training days")
                    .font(.system(.title2, design: .rounded).bold()).monospacedDigit()
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
                    .frame(minHeight: 24)
            }
            .accessibilityIdentifier("activityStudyStatus")

            HStack(spacing: 14) {
                ActivityPetalSymbol(target: hasTarget ? target : nil, completed: completed, spread: spread, selected: .constant(nil), miniature: true)
                    .frame(width: 42, height: 42)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Activity").font(.caption).foregroundStyle(.secondary)
                    Text(hasTarget ? "\(completed) / \(target) days" : "\(completed) days").font(.subheadline.bold())
                }
                Spacer()
                Button("Add day", systemImage: "plus") {
                    withAnimation(reduceMotion ? nil : .spring(response: 0.65, dampingFraction: 0.7)) {
                        completed = min(7, completed + 1)
                        selected = nil
                    }
                }.buttonStyle(.glass).disabled(completed == 7)
                    .accessibilityIdentifier("studyAddDay")
            }.padding(14).background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 22))

            VStack(spacing: 16) {
                Stepper("Weekly target: \(target)", value: $target, in: 1...7)
                    .disabled(!hasTarget)
                    .accessibilityIdentifier("studyTarget")
                let controlsLayout = typeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12)) : AnyLayout(HStackLayout())
                controlsLayout {
                    Toggle("Use a target", isOn: $hasTarget)
                    Button("Reset") { completed = 0; selected = nil }
                        .buttonStyle(.bordered).accessibilityIdentifier("studyReset")
                }
            }.font(.subheadline)
            Text("One petal per planned day. Tap a colored petal to explore its workout.")
                .font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
        }
        .onChange(of: target) { selected = nil }
        .onChange(of: hasTarget) { selected = nil }
        .sensoryFeedback(.selection, trigger: selected)
    }

    private var detail: String {
        if let selected {
            if selected >= completed { return "A day to train when it suits you" }
            return selected.isMultiple(of: 2) ? "Strength · 42 min" : "Outdoor run · 28 min"
        }
        if hasTarget && completed > target { return "\(completed - target) additional \(completed - target == 1 ? "day" : "days") logged" }
        if hasTarget && completed == target { return "Your planned days are complete" }
        return "This week"
    }
}

private struct ActivityPetalSymbol: View {
    let target: Int?
    let completed: Int
    let spread: Bool
    @Binding var selected: Int?
    var miniature = false
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var count: Int { target ?? max(1, completed) }

    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let width = size * (spread ? 0.29 : 0.25)
            let height = size * (spread ? 0.44 : 0.47)
            ZStack {
                ForEach(0..<count, id: \.self) { index in
                    let angle = Double(index) * 360 / Double(count)
                    let filled = index < completed
                    let color: Color = index.isMultiple(of: 2) ? .red : .cyan
                    Button {
                        withAnimation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.7)) { selected = selected == index ? nil : index }
                    } label: {
                        petal(color: color, filled: filled)
                            .frame(width: width, height: height)
                            .rotationEffect(.degrees(spread ? 0 : 24), anchor: .bottom)
                            .scaleEffect(selected == index ? 1.07 : 1, anchor: .bottom)
                    }
                    .buttonStyle(.plain)
                    .frame(width: width, height: height)
                    .offset(y: -size * (spread ? 0.225 : 0.19))
                    .rotationEffect(.degrees(angle))
                    .accessibilityLabel(filled ? "Day \(index + 1), \(index.isMultiple(of: 2) ? "strength" : "outdoor run")" : target == nil ? "No training recorded" : "Planned day \(index + 1)")
                    .accessibilityAddTraits(selected == index ? .isSelected : [])
                    .accessibilityIdentifier("studyPetal\(index)")
                }
                Circle().fill(Color(.systemBackground)).frame(width: size * 0.065)
                    .shadow(color: .black.opacity(0.04), radius: 3)
                    .allowsHitTesting(false)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .allowsHitTesting(!miniature)
        .accessibilityHidden(miniature)
        .animation(reduceMotion ? nil : .spring(response: 0.6, dampingFraction: 0.8), value: spread)
    }

    private func petal(color: Color, filled: Bool) -> some View {
        PetalShape()
            .fill(LinearGradient(colors: filled
                ? [color.opacity(0.52), color, color.mix(with: .purple, by: 0.17)]
                : [Color.secondary.opacity(scheme == .dark ? 0.26 : 0.19), Color.secondary.opacity(scheme == .dark ? 0.16 : 0.12)],
                                 startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay {
                PetalShape().stroke(LinearGradient(colors: filled ? [.white.opacity(0.62), color.opacity(0.18)] : [Color.secondary.opacity(0.42), Color.secondary.opacity(0.28)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: miniature ? 0.8 : 1)
            }
            .overlay(alignment: .topLeading) {
                Ellipse().fill(.white.opacity(filled ? 0.25 : 0)).blur(radius: miniature ? 1 : 5)
                    .padding(.horizontal, miniature ? 3 : 19).padding(.top, miniature ? 2 : 12).padding(.bottom, miniature ? 8 : 60)
            }
            .shadow(color: color.opacity(filled ? 0.17 : 0), radius: miniature ? 1 : 12, x: 0, y: miniature ? 1 : 7)
            .contentShape(PetalShape())
    }
}

private struct PetalShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width, h = rect.height
        p.move(to: CGPoint(x: w * 0.5, y: h))
        p.addCurve(to: CGPoint(x: w * 0.06, y: h * 0.33), control1: CGPoint(x: w * 0.12, y: h * 0.83), control2: CGPoint(x: -w * 0.02, y: h * 0.6))
        p.addCurve(to: CGPoint(x: w * 0.94, y: h * 0.33), control1: CGPoint(x: w * 0.14, y: h * 0.06), control2: CGPoint(x: w * 0.86, y: h * 0.06))
        p.addCurve(to: CGPoint(x: w * 0.5, y: h), control1: CGPoint(x: w * 1.02, y: h * 0.6), control2: CGPoint(x: w * 0.82, y: h * 0.87))
        p.closeSubpath()
        return p
    }
}
#endif
