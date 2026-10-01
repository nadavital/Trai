import SwiftUI

/// A partial speedometer track, counting completed workout sessions against a weekly workout goal.
struct WorkoutGauge: View {
    let target: Int?
    let completed: Int
    let miniature: Bool
    let glass: Bool
    var showsCount = true
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            ZStack {
                GaugeLapFill(value: target.map { Double(completed) / Double(max(1, $0)) } ?? 0, glass: glass && !miniature && !reduceTransparency)
                if !miniature && showsCount {
                    VStack(spacing: 5) {
                        HStack(alignment: .firstTextBaseline, spacing: 5) {
                            Text("\(completed)").font(.system(size: 43, weight: .semibold, design: .rounded))
                            if let target { Text("/ \(target)").font(.title3).foregroundStyle(.secondary) }
                        }.monospacedDigit().transaction { $0.animation = nil }
                        Text("workouts\nthis week").font(.caption).foregroundStyle(.secondary)
                            .multilineTextAlignment(.center).frame(maxWidth: 110)
                    }
                    .offset(y: side * 0.05)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(completed) workouts completed this week, weekly goal \(target.map(String.init) ?? "not set")")
                    .accessibilityIdentifier("gaugeStatus")
                }
            }.frame(width: side, height: side)
        }
    }
}

/// Keep native glass geometry fixed. Animate the reveal masks, not glass insertion/removal.
struct GaugeLapFill: View, Animatable {
    var value: Double
    let glass: Bool
    @Environment(\.colorScheme) private var scheme
    var animatableData: Double { get { value } set { value = newValue } }

    static func color(_ lap: Int) -> Color {
        let palette: [Color] = [
            Color(red: 0.22, green: 0.40, blue: 0.98),
            Color(red: 0.98, green: 0.72, blue: 0.27),
            Color(red: 0.10, green: 0.72, blue: 0.59),
            Color(red: 0.91, green: 0.36, blue: 0.52),
            Color(red: 0.40, green: 0.32, blue: 0.82),
            Color(red: 0.16, green: 0.65, blue: 0.86),
            Color(red: 0.93, green: 0.47, blue: 0.20)
        ]
        return palette[min(palette.count - 1, max(0, lap))]
    }

    var body: some View {
        // The count keeps growing; material settles on the seventh palette color.
        let amount = min(7, max(0, value))
        // Exact multiples keep the just-completed lap fully visible.
        let lap = max(0, Int(ceil(amount)) - 1)
        let fraction = min(1, max(0, amount - Double(lap)))
        let previous = lap == 0 ? Color.gray.opacity(scheme == .dark ? 0.38 : 0.25) : Self.color(lap - 1).opacity(0.72)
        let current = Self.color(lap).opacity(0.72)
        ZStack {
            surface(tint: previous)
                .mask(GaugeSweepMask(start: fraction, end: 1))
            surface(tint: current)
                .mask(GaugeSweepMask(start: 0, end: fraction))
            if value > 1 {
                GaugeBonusShimmer()
                    .clipShape(GaugeGlassBand(start: 0, end: 1))
                    .mask(GaugeSweepMask(start: 0, end: min(1, value - 1)))
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        // The parent interpolates `value`; each frame is a complete complementary pair.
        .transaction { $0.animation = nil }
    }

    @ViewBuilder private func surface(tint: Color) -> some View {
        if glass {
            Color.clear
                .glassEffect(.regular.tint(tint), in: GaugeGlassBand(start: 0, end: 1))
                .compositingGroup()
        } else {
            GaugeGlassBand(start: 0, end: 1)
                .fill(tint)
        }
    }
}

/// Small fixed glints breathe independently; no particles spill outside the earned band.
private struct GaugeBonusShimmer: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        GeometryReader { geometry in
            // Compact marks remain still and simple at dashboard scale.
            if min(geometry.size.width, geometry.size.height) > 80 {
                TimelineView(.animation(minimumInterval: 1.0 / 24, paused: reduceMotion || scenePhase != .active)) { timeline in
                    let time = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
                    Canvas { context, size in
                        let side = min(size.width, size.height)
                        for index in 0..<26 {
                            let position = (Double(index) + 0.4) / 26
                            let angle = (150 + position * 240) * Double.pi / 180
                            let offset = sin(Double(index) * 2.399) * side * 0.034
                            let radius = side * 0.39 + offset
                            let point = CGPoint(x: size.width / 2 + cos(angle) * radius,
                                                y: size.height / 2 + sin(angle) * radius)
                            let pulse = (sin(time * 1.5 + Double(index) * 2.399) + 1) / 2
                            let opacity = reduceMotion ? 0.34 : 0.12 + pow(pulse, 3) * 0.66
                            let dot = index % 5 == 0 ? 1.25 : 0.7
                            context.fill(Path(ellipseIn: CGRect(x: point.x - dot, y: point.y - dot,
                                                                width: dot * 2, height: dot * 2)),
                                         with: .color(.white.opacity(opacity)))
                            if index % 5 == 0 {
                                let length = 2.0 + pulse * 1.8
                                var star = Path()
                                star.move(to: CGPoint(x: point.x - length, y: point.y))
                                star.addLine(to: CGPoint(x: point.x + length, y: point.y))
                                star.move(to: CGPoint(x: point.x, y: point.y - length))
                                star.addLine(to: CGPoint(x: point.x, y: point.y + length))
                                context.stroke(star, with: .color(.white.opacity(opacity * 0.6)), lineWidth: 0.65)
                            }
                        }
                    }
                }
            }
        }
    }
}

/// Reveal whole glass surfaces, including their optical edges and shadows.
private struct GaugeSweepMask: Shape {
    let start: Double
    let end: Double

    func path(in rect: CGRect) -> Path {
        guard end > start else { return Path() }
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = max(rect.width, rect.height) * 2
        let a = start == 0 ? 120 : 150 + 240 * start
        let b = end == 1 ? 420 : 150 + 240 * end
        var path = Path()
        path.move(to: center)
        path.addLine(to: CGPoint(x: center.x + radius * cos(a * .pi / 180), y: center.y + radius * sin(a * .pi / 180)))
        path.addArc(center: center, radius: radius, startAngle: .degrees(a), endAngle: .degrees(b), clockwise: false)
        path.closeSubpath()
        return path
    }
}

/// Complementary arc masks meet without a gap; only the outer ends are capped.
private struct GaugeGlassBand: Shape {
    var start: Double
    var end: Double
    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(start, end) }
        set { start = newValue.first; end = newValue.second }
    }

    func path(in rect: CGRect) -> Path {
        guard end > start else { return Path() }
        let side = min(rect.width, rect.height)
        let radius = side * 0.39
        let width = side * 0.115
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let a = (150 + 240 * start) * Double.pi / 180
        let b = (150 + 240 * end) * Double.pi / 180
        func point(_ r: Double, _ angle: Double) -> CGPoint {
            CGPoint(x: center.x + r * cos(angle), y: center.y + r * sin(angle))
        }
        var band = Path()
        band.move(to: point(radius + width / 2, a))
        band.addArc(center: center, radius: radius + width / 2, startAngle: .radians(a), endAngle: .radians(b), clockwise: false)
        if end == 1 {
            band.addArc(center: point(radius, b), radius: width / 2, startAngle: .radians(b), endAngle: .radians(b + .pi), clockwise: false)
        } else {
            band.addLine(to: point(radius - width / 2, b))
        }
        band.addArc(center: center, radius: radius - width / 2, startAngle: .radians(b), endAngle: .radians(a), clockwise: true)
        if start == 0 {
            band.addArc(center: point(radius, a), radius: width / 2, startAngle: .radians(a + .pi), endAngle: .radians(a + 2 * .pi), clockwise: false)
        } else {
            band.addLine(to: point(radius + width / 2, a))
        }
        band.closeSubpath()
        return band
    }
}
