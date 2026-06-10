//
//  TraiLensView.swift
//  Trai
//
//  Scalable identity mark for Trai's visual system
//

import SwiftUI

/// Color palette options for Trai's lens
public enum TraiLensPalette: String, CaseIterable, Identifiable {
    case energy = "Energy"      // Red/orange - default for fitness
    case focus = "Focus"        // Blue/purple - calm concentration
    case vitality = "Vitality"  // Green/teal - health & wellness
    case warmth = "Warmth"      // Coral/peach - friendly & approachable

    public var id: String { rawValue }

    var colors: [Color] {
        switch self {
        case .energy:
            return [
                Color(red: 0.78, green: 0.12, blue: 0.10),
                TraiColors.ember,
                TraiColors.flame,
                Color(red: 1.00, green: 0.65, blue: 0.20),
                TraiColors.blaze,
                TraiColors.coral
            ]
        case .focus:
            return [
                Color(red: 0.32, green: 0.18, blue: 0.58),
                Color(red: 0.48, green: 0.22, blue: 0.68),
                Color(red: 0.22, green: 0.42, blue: 0.72),
                Color(red: 0.50, green: 0.35, blue: 0.84),
                Color(red: 0.58, green: 0.22, blue: 0.52),
                Color(red: 0.38, green: 0.34, blue: 0.74)
            ]
        case .vitality:
            return [
                Color(red: 0.14, green: 0.55, blue: 0.46),
                Color(red: 0.18, green: 0.65, blue: 0.55),
                Color(red: 0.25, green: 0.75, blue: 0.60),
                Color(red: 0.44, green: 0.80, blue: 0.46),
                Color(red: 0.35, green: 0.80, blue: 0.50),
                Color(red: 0.28, green: 0.70, blue: 0.58)
            ]
        case .warmth:
            return [
                Color(red: 0.90, green: 0.26, blue: 0.30),
                Color(red: 0.98, green: 0.52, blue: 0.35),
                Color(red: 0.95, green: 0.65, blue: 0.45),
                Color(red: 0.98, green: 0.60, blue: 0.40),
                Color(red: 0.90, green: 0.45, blue: 0.50),
                Color(red: 0.95, green: 0.42, blue: 0.34)
            ]
        }
    }

    var centerColor: Color {
        switch self {
        case .energy, .warmth:
            return Color(red: 0.88, green: 0.28, blue: 0.45)
        case .focus:
            return Color(red: 0.62, green: 0.25, blue: 0.68)
        case .vitality:
            return Color(red: 0.20, green: 0.72, blue: 0.56)
        }
    }
}

enum TraiIdentityNodeStyle: String, CaseIterable, Identifiable {
    case glossy = "Glossy"
    case clearTint = "Clear Tint"
    case clearTintInteractive = "Interactive"
    case solid = "Solid"

    var id: String { rawValue }

    var description: String {
        switch self {
        case .glossy:
            return "Glossy gradient nodes with stronger icon-like contrast."
        case .clearTint:
            return "Native clear tinted Liquid Glass nodes."
        case .clearTintInteractive:
            return "Native clear tinted Liquid Glass nodes with interactive response."
        case .solid:
            return "Flat solid nodes for compact static contexts."
        }
    }
}

enum TraiIdentityLensPlacement: String, CaseIterable, Identifiable {
    case none = "None"
    case behind = "Behind"
    case above = "Above"

    var id: String { rawValue }
}

private struct TraiIdentityNode: Identifiable {
    let id: Int
    let color: Color
    let phase: Double
    let ringIndex: Int?

    static func nodes(for palette: TraiLensPalette) -> [TraiIdentityNode] {
        let colors = palette.colors
        return [
            TraiIdentityNode(id: 0, color: palette.centerColor, phase: 0.00, ringIndex: nil),
            TraiIdentityNode(id: 1, color: colors[1], phase: 0.14, ringIndex: 0),
            TraiIdentityNode(id: 2, color: colors[2], phase: 0.28, ringIndex: 1),
            TraiIdentityNode(id: 3, color: colors[3], phase: 0.42, ringIndex: 2),
            TraiIdentityNode(id: 4, color: colors[4], phase: 0.56, ringIndex: 3),
            TraiIdentityNode(id: 5, color: colors[5], phase: 0.70, ringIndex: 4),
            TraiIdentityNode(id: 6, color: colors[0], phase: 0.84, ringIndex: 5)
        ]
    }
}

struct TraiIdentityMark: View {
    let size: CGFloat
    var state: TraiLensState = .idle
    var palette: TraiLensPalette = .energy
    var nodeStyle: TraiIdentityNodeStyle = .glossy
    var lensPlacement: TraiIdentityLensPlacement = .behind
    var showsNodeShadow = true
    var showsOuterLens = true
    var animates = true

    private var effectiveNodeStyle: TraiIdentityNodeStyle {
        size < 44 ? .solid : nodeStyle
    }

    private var effectiveLensPlacement: TraiIdentityLensPlacement {
        size < 56 ? .none : lensPlacement
    }

    private var effectiveShowsNodeShadow: Bool {
        showsNodeShadow && size >= 44
    }

    private var effectiveAnimates: Bool {
        animates && size >= 32
    }

    private var nodeSize: CGFloat {
        size * 0.245
    }

    private var horizontalOrbitRadius: CGFloat {
        size * 0.315
    }

    private var verticalOrbitRadius: CGFloat {
        horizontalOrbitRadius * 0.88
    }

    private var shouldDrawOuterLens: Bool {
        showsOuterLens && effectiveLensPlacement != .none
    }

    var body: some View {
        Group {
            if effectiveAnimates {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                    markContent(time: timeline.date.timeIntervalSinceReferenceDate)
                }
            } else {
                markContent(time: 0)
            }
        }
        .frame(width: size, height: size)
    }

    private func markContent(time: TimeInterval) -> some View {
        ZStack {
            if shouldDrawOuterLens && effectiveLensPlacement == .behind {
                outerLens(time: time)
            }

            ForEach(TraiIdentityNode.nodes(for: palette)) { node in
                let scale = nodeScale(node, time: time)
                let position = nodePosition(node, time: time)
                let brightness = nodeBrightness(node, time: time)

                nodeCircle(node, time: time, brightness: brightness)
                    .frame(width: nodeSize, height: nodeSize)
                    .scaleEffect(scale)
                    .position(position)
            }

            if shouldDrawOuterLens && effectiveLensPlacement == .above {
                outerLens(time: time)
            }
        }
        .frame(width: size, height: size)
        .scaleEffect(markScale(time: time))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Trai lens")
    }

    private func outerLens(time: TimeInterval) -> some View {
        Circle()
            .fill(.clear)
            .glassEffect(.clear, in: .circle)
            .scaleEffect(effectiveAnimates ? 1.0 + 0.012 * sin(time * 0.9) : 1.0)
    }

    @ViewBuilder
    private func nodeCircle(_ node: TraiIdentityNode, time: TimeInterval, brightness: Double) -> some View {
        switch effectiveNodeStyle {
        case .glossy:
            Circle()
                .fill(glossyNodeFill(for: node))
                .brightness(brightness)
                .overlay {
                    Circle()
                        .stroke(.white.opacity(size < 40 ? 0.20 : 0.30), lineWidth: max(1, size * 0.012))
                }
                .shadow(
                    color: effectiveShowsNodeShadow ? node.color.opacity(nodeGlowOpacity(node, time: time)) : .clear,
                    radius: effectiveShowsNodeShadow ? nodeGlowRadius(node, time: time) : 0,
                    y: size * 0.012
                )
        case .clearTint:
            Circle()
                .fill(.clear)
                .glassEffect(.clear.tint(node.color), in: .circle)
                .shadow(
                    color: effectiveShowsNodeShadow ? node.color.opacity(nodeGlowOpacity(node, time: time) * 0.78) : .clear,
                    radius: effectiveShowsNodeShadow ? nodeGlowRadius(node, time: time) * 0.72 : 0,
                    y: size * 0.01
                )
        case .clearTintInteractive:
            Circle()
                .fill(.clear)
                .glassEffect(.clear.tint(node.color).interactive(), in: .circle)
                .shadow(
                    color: effectiveShowsNodeShadow ? node.color.opacity(nodeGlowOpacity(node, time: time) * 0.78) : .clear,
                    radius: effectiveShowsNodeShadow ? nodeGlowRadius(node, time: time) * 0.72 : 0,
                    y: size * 0.01
                )
        case .solid:
            Circle()
                .fill(node.color)
                .brightness(brightness)
                .shadow(
                    color: effectiveShowsNodeShadow ? node.color.opacity(nodeGlowOpacity(node, time: time) * 0.65) : .clear,
                    radius: effectiveShowsNodeShadow ? nodeGlowRadius(node, time: time) * 0.65 : 0,
                    y: size * 0.01
                )
        }
    }

    private func glossyNodeFill(for node: TraiIdentityNode) -> some ShapeStyle {
        RadialGradient(
            colors: [
                .white.opacity(size < 40 ? 0.18 : 0.30),
                node.color.opacity(0.96),
                node.color
            ],
            center: .topLeading,
            startRadius: 0,
            endRadius: nodeSize * 0.72
        )
    }

    private func nodePosition(_ node: TraiIdentityNode, time: TimeInterval) -> CGPoint {
        let center = CGPoint(x: size / 2, y: size / 2)
        guard let ringIndex = node.ringIndex else {
            return center
        }

        let angle = baseAngle(for: ringIndex) + rotationAngle(time: time)
        let offset = radialOffset(node, time: time)
        let xRadius = horizontalOrbitRadius + offset
        let yRadius = verticalOrbitRadius + offset * 0.88
        let wobble = tangentialOffset(node, time: time)
        let radial = CGVector(dx: cos(angle), dy: sin(angle))
        let tangent = CGVector(dx: -sin(angle), dy: cos(angle))

        return CGPoint(
            x: center.x + radial.dx * xRadius + tangent.dx * wobble,
            y: center.y + radial.dy * yRadius + tangent.dy * wobble
        )
    }

    private func baseAngle(for ringIndex: Int) -> CGFloat {
        -.pi * 2 / 3 + CGFloat(ringIndex) * (.pi / 3)
    }

    private func rotationAngle(time: TimeInterval) -> CGFloat {
        guard effectiveAnimates else { return 0 }

        switch state {
        case .idle:
            return CGFloat(sin(time * 0.42)) * 0.035
        case .listening:
            return CGFloat(sin(time * 0.85)) * 0.055
        case .thinking:
            return CGFloat(time * 0.72)
        case .answering:
            return CGFloat(sin(time * 1.4)) * 0.075
        }
    }

    private func radialOffset(_ node: TraiIdentityNode, time: TimeInterval) -> CGFloat {
        guard effectiveAnimates, node.ringIndex != nil else { return 0 }

        switch state {
        case .idle:
            return size * 0.010 * CGFloat(sin(time * 1.2 + node.phase * .pi * 2))
        case .listening:
            return -size * 0.045 * pulse(time: time, phase: node.phase, speed: 2.4)
        case .thinking:
            return size * 0.020 * pulse(time: time, phase: node.phase, speed: 5.2)
        case .answering:
            return size * 0.038 * pulse(time: time, phase: node.phase + 0.32, speed: 3.3)
        }
    }

    private func tangentialOffset(_ node: TraiIdentityNode, time: TimeInterval) -> CGFloat {
        guard effectiveAnimates, node.ringIndex != nil else { return 0 }

        switch state {
        case .thinking:
            return size * 0.020 * CGFloat(sin(time * 4.4 + node.phase * .pi * 2))
        case .answering:
            return size * 0.010 * CGFloat(sin(time * 2.6 + node.phase * .pi * 2))
        default:
            return 0
        }
    }

    private func markScale(time: TimeInterval) -> CGFloat {
        guard effectiveAnimates else { return 1.0 }

        switch state {
        case .idle:
            return 1.0 + 0.018 * sin(time * 1.2)
        case .listening:
            return 1.0 + 0.012 * sin(time * 1.8)
        case .thinking:
            return 1.0 + 0.010 * sin(time * 2.8)
        case .answering:
            return 1.0 + 0.014 * sin(time * 2.0)
        }
    }

    private func nodeScale(_ node: TraiIdentityNode, time: TimeInterval) -> CGFloat {
        guard effectiveAnimates else { return 1.0 }

        switch state {
        case .idle:
            return 1.0 + 0.025 * sin(time * 1.35 + node.phase * .pi * 2)
        case .listening:
            return node.id == 0
            ? 1.10 + 0.035 * sin(time * 2.6)
            : 0.98 + 0.035 * sin(time * 1.8 + node.phase * .pi * 2)
        case .thinking:
            let wave = pulse(time: time, phase: node.phase, speed: 5.2)
            return node.id == 0 ? 1.05 : 0.96 + 0.16 * wave
        case .answering:
            let centerPulse = 1.10 + 0.06 * pulse(time: time, phase: 0, speed: 3.4)
            let outerPulse = 1.0 + 0.05 * pulse(time: time, phase: 1 - node.phase, speed: 3.4)
            return node.id == 0 ? centerPulse : outerPulse
        }
    }

    private func nodeBrightness(_ node: TraiIdentityNode, time: TimeInterval) -> Double {
        guard effectiveAnimates else { return 0 }

        switch state {
        case .thinking:
            return node.id == 0 ? 0.02 : 0.10 * pulse(time: time, phase: node.phase, speed: 5.2)
        default:
            return 0
        }
    }

    private func nodeGlowOpacity(_ node: TraiIdentityNode, time: TimeInterval) -> Double {
        switch state {
        case .thinking:
            return node.id == 0 ? 0.32 : 0.26 + 0.24 * pulse(time: time, phase: node.phase, speed: 5.2)
        case .answering:
            return node.id == 0 ? 0.56 : 0.30
        default:
            return 0.30
        }
    }

    private func nodeGlowRadius(_ node: TraiIdentityNode, time: TimeInterval) -> CGFloat {
        let base = max(2, size * 0.04)
        switch state {
        case .thinking:
            return base + size * 0.045 * pulse(time: time, phase: node.phase, speed: 5.2)
        case .answering where node.id == 0:
            return base + size * 0.08 * pulse(time: time, phase: 0, speed: 3.4)
        default:
            return base
        }
    }

    private func pulse(time: TimeInterval, phase: Double, speed: Double) -> CGFloat {
        max(0, CGFloat(sin(time * speed + phase * .pi * 2)))
    }
}

/// The animated liquid lens for Trai.
public struct TraiLensView: View {
    let size: CGFloat
    let state: TraiLensState
    let palette: TraiLensPalette
    let breathes: Bool

    public init(
        size: CGFloat = 120,
        state: TraiLensState = .idle,
        palette: TraiLensPalette = .energy,
        breathes: Bool = true
    ) {
        self.size = size
        self.state = state
        self.palette = palette
        self.breathes = breathes
    }

    public var body: some View {
        TraiIdentityMark(
            size: size,
            state: state,
            palette: palette,
            nodeStyle: size < 44 ? .solid : .glossy,
            lensPlacement: size >= 56 ? .behind : .none,
            showsNodeShadow: size >= 44,
            showsOuterLens: size >= 56,
            animates: breathes
        )
    }
}

// MARK: - Static Icon Version

/// Static version of Trai's mark for small contexts (buttons, chips, avatars).
public struct TraiLensIcon: View {
    let size: CGFloat
    let palette: TraiLensPalette

    public init(size: CGFloat, palette: TraiLensPalette = .energy) {
        self.size = size
        self.palette = palette
    }

    public var body: some View {
        TraiIdentityMark(
            size: size,
            state: .idle,
            palette: palette,
            nodeStyle: .solid,
            lensPlacement: .none,
            showsNodeShadow: false,
            showsOuterLens: false,
            animates: false
        )
    }
}

// MARK: - Monochrome Symbol Version

/// Monochrome Trai symbol for small or high-contrast contexts.
public struct TraiLensSymbolIcon: View {
    public enum Variant {
        case nodes
        case enclosed
        case enclosedFilled

        var systemName: String {
            switch self {
            case .nodes:
                return "circle.hexagongrid.fill"
            case .enclosed:
                return "circle.hexagongrid.circle"
            case .enclosedFilled:
                return "circle.hexagongrid.circle.fill"
            }
        }
    }

    let size: CGFloat
    let variant: Variant
    let color: Color
    let weight: Font.Weight

    public init(
        size: CGFloat,
        variant: Variant = .nodes,
        color: Color = .primary,
        weight: Font.Weight = .bold
    ) {
        self.size = size
        self.variant = variant
        self.color = color
        self.weight = weight
    }

    public var body: some View {
        Image(systemName: variant.systemName)
            .font(.system(size: size, weight: weight))
            .symbolRenderingMode(.monochrome)
            .foregroundStyle(color)
    }
}

// MARK: - Preview

#Preview("Trai Identity Mark") {
    ScrollView {
        VStack(spacing: 40) {
            TraiLensView(size: 150, state: .thinking, palette: .energy)

            HStack(spacing: 30) {
                ForEach(TraiLensPalette.allCases) { palette in
                    VStack {
                        TraiLensView(size: 80, state: .idle, palette: palette, breathes: false)
                        Text(palette.rawValue)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            HStack(spacing: 20) {
                VStack {
                    TraiLensIcon(size: 32, palette: .energy)
                    Text("Button")
                        .font(.caption2)
                }
                VStack {
                    TraiLensIcon(size: 24, palette: .energy)
                    Text("Glyph")
                        .font(.caption2)
                }
            }
        }
        .padding(40)
    }
}
