#if DEBUG
import SwiftUI

private enum DiscTreatment: String, CaseIterable, Identifiable {
    case fitted = "Petal disc", bloom = "Flower", glass = "Glass", orbit = "Sweep", gauge = "Gauge"
    var id: String { rawValue }
}

/// Fictional data, isolated from the dashboard and HealthKit. The gauge counts workout sessions.
struct ActivityDiscStudy: View {
    @State private var treatment: DiscTreatment = ProcessInfo.processInfo.arguments.contains("--disc-gauge") ? .gauge : ProcessInfo.processInfo.arguments.contains("--disc-orbit") ? .orbit : ProcessInfo.processInfo.arguments.contains("--disc-bloom") ? .bloom : ProcessInfo.processInfo.arguments.contains("--disc-fitted") ? .fitted : .gauge
    @State private var target = ProcessInfo.processInfo.arguments.contains("--disc-single-target") ? 1 : ProcessInfo.processInfo.arguments.contains("--disc-laps") ? 2 : ProcessInfo.processInfo.arguments.contains("--disc-orbit") ? 5 : 4
    @State private var completed = ProcessInfo.processInfo.arguments.contains("--disc-extra") ? 6 : 2
    @State private var selected: Int?
    @State private var dark = ProcessInfo.processInfo.arguments.contains("--disc-dark")
    @State private var playing = false
    @State private var slow = false
    @State private var gaugeGlass = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.scenePhase) private var scenePhase

    private var transition: Animation? {
        guard !reduceMotion else { return nil }
        return treatment == .gauge ? .easeInOut(duration: slow ? 1.4 : 0.65) : .spring(response: slow ? 1.4 : 0.65, dampingFraction: 0.88)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    Picker("Treatment", selection: $treatment) {
                        ForEach(ProcessInfo.processInfo.arguments.contains("--disc-fitted") || ProcessInfo.processInfo.arguments.contains("--disc-bloom") ? DiscTreatment.allCases : [.orbit, .gauge]) { Text($0.rawValue).tag($0) }
                    }.pickerStyle(.segmented)

                    DayPetalDisc(target: target, completed: completed, treatment: treatment, selected: $selected, gaugeGlass: gaugeGlass)
                        .frame(height: 270)
                        .padding(.top, 14)

                    if treatment != .gauge {
                    VStack(spacing: 7) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text("\(min(completed, target))").font(.system(.largeTitle, design: .rounded, weight: .semibold))
                            Text("/ \(target) \(target == 1 ? "day" : "days")").font(.title3).foregroundStyle(.secondary)
                            if completed > target {
                                Text("+\(completed - target)").font(.headline).foregroundStyle(.primary)
                                    .padding(.horizontal, 10).padding(.vertical, 5)
                                    .background(Color(red: 0.96, green: 0.66, blue: 0.19).opacity(0.18), in: .capsule)
                                    .accessibilityLabel("\(completed - target) additional training days")
                            }
                        }.monospacedDigit().transaction { $0.animation = nil }
                        Text(detail).font(.subheadline).foregroundStyle(.secondary)
                            .multilineTextAlignment(.center).frame(minHeight: 24)
                    }.accessibilityIdentifier("discStatus")
                    }

                    let supportingLayout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8)) : AnyLayout(HStackLayout(spacing: 18))
                    supportingLayout {
                        if treatment == .gauge {
                            legend("1×", color: GaugeLapFill.color(0))
                            legend("2×", color: GaugeLapFill.color(1))
                            legend("3×", color: GaugeLapFill.color(2))
                        } else {
                            legend("Planned", color: .indigo.opacity(0.3))
                            legend("Logged", color: Color(red: 0.28, green: 0.32, blue: 0.94))
                            legend("Extra day", color: Color(red: 0.92, green: 0.63, blue: 0.16))
                        }
                    }.font(.caption)

                    let compactLayout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12)) : AnyLayout(HStackLayout(spacing: 12))
                    compactLayout {
                        DayPetalDisc(target: target, completed: completed, treatment: treatment, selected: .constant(nil), miniature: true)
                            .frame(width: 42, height: 42)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("This week").font(.caption).foregroundStyle(.secondary)
                            Text(treatment == .gauge ? "\(completed) \(completed == 1 ? "workout" : "workouts")" : "\(completed) / \(target) \(target == 1 ? "day" : "days")").font(.subheadline.bold())
                                .accessibilityIdentifier("discCompactCount")
                                .transaction { $0.animation = nil }
                        }
                        Spacer(minLength: 0)
                        Button(treatment == .gauge ? "Log workout" : "Log a day", systemImage: "plus") {
                            changeCompletion(treatment == .gauge ? completed + 1 : min(7, completed + 1))
                        }
                            .buttonStyle(.glassProminent).tint(.accentColor)
                            .disabled((treatment != .gauge && completed >= 7) || playing)
                            .accessibilityIdentifier("discAdd")
                    }.padding(14)
                        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 22))

                    VStack(spacing: 14) {
                        if treatment == .gauge {
                            Toggle("Glass material", isOn: $gaugeGlass)
                                .accessibilityIdentifier("gaugeGlass")
                        }
                        Stepper(treatment == .gauge ? "Workouts per week: \(target)" : "Weekly target: \(target)", value: $target, in: 1...(treatment == .gauge ? 21 : 7))
                            .accessibilityIdentifier("discTarget").disabled(playing)
                        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12)) : AnyLayout(HStackLayout(spacing: 12))
                        layout {
                            Button("Reset", systemImage: "arrow.counterclockwise") { playing = false; changeCompletion(0) }
                                .accessibilityIdentifier("discReset")
                            Spacer(minLength: 0)
                            Button(playing ? "Stop" : "Play states", systemImage: playing ? "stop.fill" : "play.fill") { playing.toggle() }
                                .accessibilityIdentifier("discPlay")
                            Toggle("Slow", isOn: $slow).fixedSize()
                        }.font(.subheadline).buttonStyle(.bordered).buttonBorderShape(.capsule)
                    }
                    if treatment == .orbit {
                        HStack(spacing: 32) {
                            VStack(spacing: 8) {
                                TraiIdentityMark(size: 64, animates: false)
                                Text("Trai identity")
                            }
                            VStack(spacing: 8) {
                                WorkoutOrbit(target: target, completed: completed, selected: .constant(nil), miniature: true)
                                    .frame(width: 64, height: 64).allowsHitTesting(false)
                                Text("Activity study")
                            }
                        }.font(.caption).foregroundStyle(.secondary)
                            .padding(.top, 12)
                    }
                    Text(treatment == .gauge ? "Each workout counts, including sessions on the same day." : "One shape is one training day. Tap to explore.")
                        .font(.caption).foregroundStyle(.secondary)
                }.padding(20)
            }
            .background {
                LinearGradient(colors: [Color.indigo.opacity(dark ? 0.08 : 0.035), Color(.systemGroupedBackground), Color(.systemGroupedBackground)], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
            }
            .navigationTitle("Activity studies").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dark.toggle() } label: { Image(systemName: dark ? "sun.max" : "moon") }
                        .accessibilityLabel("Switch appearance")
                }
            }
            .safeAreaInset(edge: .bottom) {
                Text("Native design study · sample workouts").font(.caption2).foregroundStyle(.secondary)
                    .padding(8).frame(maxWidth: .infinity).background(.bar)
            }
        }
        .preferredColorScheme(dark ? .dark : .light)
        .onChange(of: target) { selected = nil }
        .onChange(of: treatment) { selected = nil }
        .onChange(of: scenePhase) { if scenePhase != .active { playing = false } }
        .task(id: playing) {
            guard playing else { return }
            for value in 0...(treatment == .gauge ? max(8, target * 3 + 1) : min(7, target + 2)) {
                guard !Task.isCancelled else { return }
                changeCompletion(value)
                do { try await Task.sleep(for: .seconds(slow ? 2.1 : 1.25)) } catch { return }
            }
            playing = false
        }
        .task {
            if ProcessInfo.processInfo.arguments.contains("--disc-autoplay") {
                slow = true
                try? await Task.sleep(for: .seconds(2))
                guard !Task.isCancelled else { return }
                playing = true
            }
        }
    }

    private var detail: String {
        if let selected {
            guard selected < completed else { return "An open day in your week" }
            return ["Strength · 42 min", "Outdoor run · 28 min", "Strength · 36 min", "Mixed workout · 50 min"][selected % 4]
        }
        return completed >= target ? "Your planned days are complete" : "Your week, at your pace"
    }

    private func changeCompletion(_ count: Int) {
        withAnimation(transition) { completed = count; selected = nil }
    }

    private func legend(_ title: String, color: Color) -> some View {
        HStack(spacing: 5) { Circle().fill(color).frame(width: 6, height: 6); Text(title).foregroundStyle(.secondary) }
    }
}

private struct DayPetalDisc: View {
    let target: Int
    let completed: Int
    let treatment: DiscTreatment
    @Binding var selected: Int?
    var miniature = false
    var gaugeGlass = true
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height) * (miniature ? 1 : 0.93)
            ZStack {
                if treatment == .gauge {
                    WorkoutGauge(target: target, completed: completed, miniature: miniature, glass: gaugeGlass)
                        .frame(width: side, height: side)
                } else if treatment == .orbit {
                    WorkoutOrbit(target: target, completed: completed, selected: $selected, miniature: miniature)
                        .frame(width: side, height: side)
                } else if treatment == .bloom {
                    WorkoutFlower(target: target, completed: completed, selected: $selected, miniature: miniature)
                        .frame(width: side, height: side)
                } else {
                    ForEach(0..<target, id: \.self) { index in
                        petalButton(index: index, side: side, frame: geometry.frame(in: .global))
                    }
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .allowsHitTesting(!miniature).accessibilityHidden(miniature)
        .sensoryFeedback(.selection, trigger: selected)
    }

    private func petalButton(index: Int, side: CGFloat, frame: CGRect) -> some View {
        let angle = -Double.pi / 2 + (Double(index) + 0.5) * 2 * Double.pi / Double(target)
        let activationPoint = CGPoint(x: frame.midX + side * 0.28 * cos(angle), y: frame.midY + side * 0.28 * sin(angle))
                    let shape = DiscPetal(index: index, count: target, scalloped: treatment == .bloom)
                    let filled = index < completed
                    return Button {
                        withAnimation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.8)) { selected = selected == index ? nil : index }
                    } label: {
                        material(shape: shape, color: color(index), filled: filled)
                            .overlay {
                                shape.stroke((filled ? color(index) : Color.primary).opacity(selected == index ? 0.45 : 0), lineWidth: miniature ? 0.5 : 1.5)
                            }
                    }
                    .buttonStyle(.plain)
                    .frame(width: side, height: side)
                    .contentShape(shape)
                    .scaleEffect(selected == index ? 1.045 : 1)
                    .offset(y: selected == index ? -3 : 0)
                    .zIndex(selected == index ? 1 : 0)
                    .accessibilityLabel(filled ? "Day \(index + 1), \(kind(index))" : "Planned day \(index + 1)")
                    .accessibilityValue(filled ? "Logged" : "Open")
                    .accessibilityAddTraits(selected == index ? .isSelected : [])
                    .accessibilityIdentifier("discPetal\(index)")
.accessibilityActivationPoint(activationPoint)
    }

    private func color(_ index: Int) -> Color {
        Color(red: 0.28, green: 0.32, blue: 0.94)
    }
    private func kind(_ index: Int) -> String {
        switch index % 4 { case 1: "Cardio"; case 3: "Mixed"; default: "Strength" }
    }

    @ViewBuilder private func material(shape: DiscPetal, color: Color, filled: Bool) -> some View {
        let empty = scheme == .dark ? Color(white: 0.18) : Color(white: 0.87)
        let edge = contrast == .increased ? 0.55 : 0.22
        if treatment == .glass && !miniature {
            shape.fill(empty.opacity(0.28))
                .overlay {
                    shape.fill(LinearGradient(colors: [color.opacity(0.8), color], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .opacity(filled ? 1 : 0)
                }
                .glassEffect(.regular.interactive(), in: shape)
                .overlay { shape.stroke(.primary.opacity(edge), lineWidth: 0.65) }
        } else {
            shape.fill(LinearGradient(colors: [empty.mix(with: .white, by: 0.22), empty], startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay {
                    shape.fill(LinearGradient(stops: [
                        .init(color: color.mix(with: .white, by: 0.38), location: 0),
                        .init(color: color, location: 0.5),
                        .init(color: color.mix(with: .black, by: scheme == .dark ? 0.08 : 0.16), location: 1)
                    ], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .opacity(filled ? 1 : 0)
                }
                .overlay {
                    shape.fill(RadialGradient(colors: [.white.opacity(scheme == .dark ? 0.18 : 0.34), .clear], center: .init(x: 0.28, y: 0.18), startRadius: 0, endRadius: miniature ? 25 : 180))
                }
                .overlay {
                    shape.stroke(LinearGradient(colors: [.white.opacity(0.75), .white.opacity(0.06), .black.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: miniature ? 0.5 : 1.2)
                }
                .overlay { shape.stroke(.primary.opacity(filled ? 0 : edge), lineWidth: miniature ? 0.45 : 0.65) }
                .shadow(color: .black.opacity(scheme == .dark ? 0.24 : 0.09), radius: miniature ? 1 : 6, x: 0, y: miniature ? 1 : 5)
        }
    }
}

/// Wide, rounded sectors share one disc footprint. No hub or independent teardrops.
private struct DiscPetal: Shape {
    let index: Int
    let count: Int
    let scalloped: Bool

    func path(in rect: CGRect) -> Path {
        if count == 1 { return Path(ellipseIn: rect.insetBy(dx: 2, dy: 2)) }
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2 - 2
        let sweep = 2 * Double.pi / Double(count)
        let gap = 0.022
        let start = -Double.pi / 2 + Double(index) * sweep + gap
        let end = start + sweep - 2 * gap
        let rounding = min(0.12, sweep * 0.1)
        func point(_ r: Double, _ a: Double) -> CGPoint {
            CGPoint(x: center.x + radius * r * cos(a), y: center.y + radius * r * sin(a))
        }
        if scalloped {
            // A continuous polar contour avoids visible shoulders between separate curves.
            func outer(_ t: Double) -> CGPoint {
                point(0.74 + 0.26 * pow(sin(.pi * t), 2), start + (end - start) * t)
            }
            var petal = Path()
            petal.move(to: point(0.065, start))
            petal.addLine(to: point(0.52, start))
            petal.addQuadCurve(to: outer(0.08), control: point(0.74, start))
            for step in 1...96 {
                petal.addLine(to: outer(0.08 + 0.84 * Double(step) / 96))
            }
            petal.addQuadCurve(to: point(0.52, end), control: point(0.74, end))
            petal.addLine(to: point(0.065, end))
            petal.addQuadCurve(to: point(0.065, start), control: center)
            petal.closeSubpath()
            return petal
        }
        var path = Path()
        path.move(to: point(0.065, start))
        path.addLine(to: point(0.88, start))
        path.addQuadCurve(to: point(1, start + rounding), control: point(1, start))
        path.addArc(center: center, radius: radius, startAngle: .radians(start + rounding), endAngle: .radians(end - rounding), clockwise: false)
        path.addQuadCurve(to: point(0.88, end), control: point(1, end))
        path.addLine(to: point(0.065, end))
        path.addQuadCurve(to: point(0.065, start), control: center)
        path.closeSubpath()
        return path
    }
}

/// Broad overlapping petals; bonus days form a smaller foreground layer.
private struct WorkoutFlower: View {
    let target: Int
    let completed: Int
    @Binding var selected: Int?
    let miniature: Bool
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let activity = Color(red: 0.28, green: 0.32, blue: 0.94)
    private let bonus = Color(red: 0.94, green: 0.73, blue: 0.34)

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(0..<target, id: \.self) { index in
                    petal(index, frame: geometry.frame(in: .global))
                }
                ForEach(0..<max(0, completed - target), id: \.self) { index in
                    bonusPetal(index, frame: geometry.frame(in: .global))
                }
            }
        }
    }

    private func bonusAngle(_ index: Int) -> Double {
        // Reserve stable slots inside the gaps, never directly behind a planned petal.
        let gapOrder = Array(0..<target)
        let gap = gapOrder[index % target]
        let depth = index / target
        let capacity = max(1, 7 - target)
        let positionsInGap = max(1, (capacity - 1 - (index % target)) / target + 1)
        return (Double(gap) + Double(depth + 1) / Double(positionsInGap + 1)) * 360 / Double(target) + 45
    }

    private func bonusPetal(_ index: Int, frame: CGRect) -> some View {
        let angle = bonusAngle(index)
        let shape = FlowerPetal(width: petalWidth * 0.44, reach: 0.36, angle: angle, tapered: true)
        let radians = (angle - 90) * .pi / 180
        let point = CGPoint(x: frame.midX + frame.width * 0.25 * cos(radians), y: frame.midY + frame.height * 0.25 * sin(radians))
        return Button {
            withAnimation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.8)) {
                selected = selected == target + index ? nil : target + index
            }
        } label: {
            shape.fill(LinearGradient(colors: [bonus.mix(with: .white, by: 0.35), bonus, bonus.mix(with: .brown, by: 0.12)], startPoint: .top, endPoint: .bottom))
                .overlay { shape.stroke(.white.opacity(0.22), lineWidth: miniature ? 0.3 : 0.6) }
                .overlay { shape.stroke(bonus.mix(with: .black, by: 0.25).opacity(selected == target + index ? 0.8 : 0), lineWidth: 2) }
                .shadow(color: .black.opacity(0.16), radius: miniature ? 1 : 3, y: 2)
        }
        .buttonStyle(.plain)
        .contentShape(shape)
        .scaleEffect(selected == target + index ? 1.035 : 1)
        .transition(reduceMotion ? .opacity : .scale(scale: 0.7).combined(with: .opacity))
        .accessibilityLabel("Additional training day \(index + 1)")
        .accessibilityAddTraits(selected == target + index ? .isSelected : [])
        .accessibilityIdentifier("discBonus\(index)")
        .accessibilityActivationPoint(point)
    }

    private var petalWidth: Double { target <= 3 ? 0.46 : target == 4 ? 0.43 : target == 5 ? 0.36 : 0.30 }

    private func petal(_ index: Int, frame: CGRect) -> some View {
        let logged = index < completed
        let angle = Double(index) * 360 / Double(target) + 45
        let shape = FlowerPetal(width: petalWidth, reach: 0.43, angle: angle)
        let tint = logged ? activity : activity.mix(with: scheme == .dark ? .black : .white, by: scheme == .dark ? 0.62 : 0.86)
        let radians = (angle - 90) * .pi / 180
        let point = CGPoint(x: frame.midX + frame.width * 0.25 * cos(radians), y: frame.midY + frame.height * 0.25 * sin(radians))
        return Button {
            withAnimation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.8)) {
                selected = selected == index ? nil : index
            }
        } label: {
            shape.fill(LinearGradient(stops: [
                .init(color: tint.mix(with: .white, by: logged ? 0.38 : 0.09), location: 0),
                .init(color: tint, location: 0.5),
                .init(color: tint.mix(with: .black, by: logged ? 0.18 : 0.03), location: 1)
            ], startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay {
                shape.stroke(LinearGradient(colors: [.white.opacity(0.28), activity.opacity(logged ? 0.08 : 0.22)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: miniature ? 0.5 : 1)
            }
            .overlay { shape.stroke(activity.opacity(selected == index ? 0.7 : 0), lineWidth: 2) }
            .shadow(color: .black.opacity(scheme == .dark ? 0.25 : 0.10), radius: miniature ? 0.7 : 3, y: miniature ? 0.5 : 2)
        }
        .buttonStyle(.plain)
        .contentShape(shape)
        .scaleEffect(selected == index ? 1.035 : 1)
        .accessibilityLabel("\(logged ? "Logged" : "Planned") training day \(index + 1)")
        .accessibilityValue(logged ? "Logged" : "Open")
        .accessibilityAddTraits(selected == index ? .isSelected : [])
        .accessibilityIdentifier("discPetal\(index)")
        .accessibilityActivationPoint(point)
    }
}

private struct GaugeArc: Shape {
    var progress: Double
    var start: Double = 0
    var animatableData: Double { get { progress } set { progress = newValue } }

    func path(in rect: CGRect) -> Path {
        guard progress > start else { return Path() }
        let side = min(rect.width, rect.height)
        var path = Path()
        path.addArc(center: CGPoint(x: rect.midX, y: rect.midY), radius: side * 0.39,
                    startAngle: .degrees(150 + 240 * start),
                    endAngle: .degrees(150 + 240 * min(1, progress)), clockwise: false)
        return path.strokedPath(StrokeStyle(lineWidth: side * 0.115, lineCap: .round))
    }
}

/// An open orbit of softly lit lenses. Each lens remains a discrete training day.
private struct WorkoutOrbit: View {
    let target: Int
    let completed: Int
    @Binding var selected: Int?
    let miniature: Bool
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        GeometryReader { geometry in
            if miniature || reduceMotion || scenePhase != .active {
                content(geometry: geometry, time: 0)
            } else {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                    content(geometry: geometry, time: timeline.date.timeIntervalSinceReferenceDate)
                }
            }
        }
        .accessibilityHidden(miniature)
        .allowsHitTesting(!miniature)
    }

    private func content(geometry: GeometryProxy, time: Double) -> some View {
        let side = min(geometry.size.width, geometry.size.height)
        return ZStack {
            ForEach(0..<target, id: \.self) { index in
                lens(index: index, extra: false, side: side, frame: geometry.frame(in: .global), time: time)
            }
            ForEach(0..<max(0, completed - target), id: \.self) { index in
                lens(index: index, extra: true, side: side, frame: geometry.frame(in: .global), time: time)
                    .transition(reduceMotion ? .opacity : .scale(scale: 0.86).combined(with: .opacity))
            }
        }.frame(width: geometry.size.width, height: geometry.size.height)
    }

    private func lens(index: Int, extra: Bool, side: CGFloat, frame: CGRect, time: Double) -> some View {
        let identity = extra ? target + index : index
        let active = extra || index < completed
        let count = max(target, completed)
        let span = min(260.0, Double(max(0, count - 1)) * 52)
        let angle = count == 1 ? -90 : -90 - span / 2 + Double(identity) * span / Double(count - 1)
        let radians = angle * .pi / 180
        let radius = count == 1 ? 0 : side * 0.30
        let width = side * 0.30
        let height = width * 0.52
        let phase = Double(identity) * 1.17
        let motion = miniature || reduceMotion || scenePhase != .active ? 0 : sin(time * 0.75 + phase)
        let color = extra ? Color(red: 0.98, green: 0.74, blue: 0.32) : Color(red: 0.27, green: 0.38 + Double(index % 3) * 0.035, blue: 0.98)
        let point = CGPoint(x: frame.midX + radius * cos(radians), y: frame.midY + radius * sin(radians))
        return Button {
            withAnimation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.8)) {
                selected = selected == identity ? nil : identity
            }
        } label: {
            OrbitLens(color: color, active: active, miniature: miniature)
                .overlay { ActivitySweepPetal().stroke(color.opacity(selected == identity ? 0.85 : 0), lineWidth: 1.5) }
                .frame(width: width, height: height)
                .rotation3DEffect(.degrees(20 + motion * 9), axis: (x: 1, y: 0.3, z: 0), perspective: 0.35)
                .rotationEffect(.degrees(angle + 38 + motion * 3))
                .scaleEffect(selected == identity ? 1.06 : 1)
        }
        .buttonStyle(.plain)
        .frame(minWidth: miniature ? 0 : 44, minHeight: miniature ? 0 : 44)
        .contentShape(.rect)
        .offset(x: radius * cos(radians), y: radius * sin(radians))
        .accessibilityLabel(extra ? "Additional training day \(index + 1)" : "Training day \(index + 1)")
        .accessibilityValue(active ? "Logged" : "Planned")
        .accessibilityIdentifier(extra ? "discBonus\(index)" : "discPetal\(index)")
        .accessibilityAddTraits(selected == identity ? .isSelected : [])
        .accessibilityActivationPoint(point)
    }
}

private struct OrbitLens: View {
    let color: Color
    let active: Bool
    let miniature: Bool
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        GeometryReader { geometry in
            let base = active ? color : color.mix(with: scheme == .dark ? Color(white: 0.12) : .white, by: 0.86)
            ActivitySweepPetal()
                .fill(LinearGradient(stops: [
                    .init(color: base.mix(with: .white, by: active ? 0.40 : 0.10), location: 0),
                    .init(color: base, location: 0.46),
                    .init(color: base.mix(with: .black, by: active ? 0.24 : 0.08), location: 0.87),
                    .init(color: base.mix(with: .white, by: 0.12), location: 1)
                ], startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay {
                    ActivitySweepPetal().fill(RadialGradient(colors: [.white.opacity(active ? 0.50 : 0.20), .clear], center: .init(x: 0.34, y: 0.20), startRadius: 0, endRadius: geometry.size.width * 0.65))
                }
                .overlay {
                    ActivitySweepPetal().stroke(LinearGradient(stops: [
                        .init(color: .white.opacity(0.65), location: 0),
                        .init(color: .white.opacity(0.02), location: 0.38),
                        .init(color: base.mix(with: .black, by: 0.28).opacity(0.5), location: 0.70),
                        .init(color: .white.opacity(0.35), location: 1)
                    ], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: miniature ? 0.3 : 1.1)
                }
                .background {
                    ActivitySweepPetal().fill(base.mix(with: .black, by: 0.25))
                        .offset(y: miniature ? 0.4 : 1.7)
                }
                .shadow(color: base.opacity(active ? 0.17 : 0.06), radius: miniature ? 0.7 : 3, y: miniature ? 0.5 : 2)
        }
    }
}

/// A gently bent, blunt-ended petal, distinct from a spherical node or perfect oval.
private struct ActivitySweepPetal: Shape {
    func path(in rect: CGRect) -> Path {
        func p(_ x: Double, _ y: Double) -> CGPoint {
            CGPoint(x: rect.minX + rect.width * x, y: rect.minY + rect.height * y)
        }
        var path = Path()
        path.move(to: p(0.02, 0.58))
        path.addCurve(to: p(0.78, 0.10), control1: p(-0.01, 0.18), control2: p(0.47, -0.08))
        path.addCurve(to: p(0.98, 0.45), control1: p(0.94, 0.16), control2: p(1.01, 0.29))
        path.addCurve(to: p(0.24, 0.92), control1: p(0.98, 0.81), control2: p(0.50, 1.02))
        path.addCurve(to: p(0.02, 0.58), control1: p(0.10, 0.89), control2: p(0.03, 0.76))
        path.closeSubpath()
        return path
    }
}

private struct FlowerPetal: Shape {
    let width: Double
    let reach: Double
    let angle: Double
    var tapered = false

    func path(in rect: CGRect) -> Path {
        let side = min(rect.width, rect.height)
        let cx = rect.midX
        let cy = rect.midY
        let w = side * width / 2
        let length = side * reach
        var path = Path()
        path.move(to: CGPoint(x: cx, y: cy + side * (tapered ? 0.005 : 0.02)))
        path.addCurve(to: CGPoint(x: cx - w, y: cy - length * 0.52),
                      control1: CGPoint(x: cx - w * (tapered ? 0.18 : 0.40), y: cy + side * (tapered ? 0.005 : 0.02)),
                      control2: CGPoint(x: cx - w * 1.04, y: cy - length * 0.12))
        path.addCurve(to: CGPoint(x: cx, y: cy - length),
                      control1: CGPoint(x: cx - w, y: cy - length * 0.86),
                      control2: CGPoint(x: cx - w * 0.55, y: cy - length))
        path.addCurve(to: CGPoint(x: cx + w, y: cy - length * 0.52),
                      control1: CGPoint(x: cx + w * 0.55, y: cy - length),
                      control2: CGPoint(x: cx + w, y: cy - length * 0.86))
        path.addCurve(to: CGPoint(x: cx, y: cy + side * (tapered ? 0.005 : 0.02)),
                      control1: CGPoint(x: cx + w * 1.04, y: cy - length * 0.12),
                      control2: CGPoint(x: cx + w * (tapered ? 0.18 : 0.40), y: cy + side * (tapered ? 0.005 : 0.02)))
        path.closeSubpath()
        return path.applying(CGAffineTransform(translationX: cx, y: cy)
            .rotated(by: angle * .pi / 180).translatedBy(x: -cx, y: -cy))
    }
}
#endif
