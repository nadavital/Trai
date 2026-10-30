#if DEBUG
import SwiftUI

/// Isolated visual study. These fixed samples never read or write health data.
struct WeightPebbleStudy: View {
    private enum Arrangement: String, CaseIterable, Identifiable {
        case gathered = "Gathered", fanned = "Fanned"
        var id: String { rawValue }
    }

    private struct Sample: Identifiable {
        let id: Int
        let day: String
        let value: Double
    }

    private static let samples = [
        Sample(id: 0, day: "September 19", value: 80.4),
        Sample(id: 1, day: "September 21", value: 80.1),
        Sample(id: 2, day: "September 23", value: 80.3),
        Sample(id: 3, day: "September 25", value: 80.2)
    ]
    @State private var arrangement: Arrangement = .gathered
    @State private var sampleCount = 4
    @State private var selectedID = 3
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var typeSize

    private var samples: [Sample] { Array(Self.samples.suffix(sampleCount)) }
    private var selected: Sample? { samples.first { $0.id == selectedID } ?? samples.last }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Picker("Arrangement", selection: $arrangement) {
                ForEach(Arrangement.allCases) { value in Text(value.rawValue).tag(value) }
            }
            .pickerStyle(.segmented)
            Picker("Sample count", selection: $sampleCount) {
                Text("Empty").tag(0)
                Text("One").tag(1)
                Text("Four").tag(4)
            }
            .pickerStyle(.segmented)

            pebbleField(compact: false)
                .frame(height: 250)

            measurement
                .frame(maxWidth: .infinity, alignment: .center)

            Divider().padding(.vertical, 4)
            let layout = typeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
                : AnyLayout(HStackLayout(spacing: 16))
            layout {
                pebbleField(compact: true)
                    .frame(width: 104, height: 68)
                    .allowsHitTesting(false).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(selected == nil ? "No check-ins" : "Your check-ins")
                        .font(.headline)
                    Text(selected?.day ?? "A place for your measurements")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            Text("Each pebble is a check-in. Shape, size and color do not represent weight or progress.")
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .animation(reduceMotion ? nil : .spring(response: 0.55, dampingFraction: 0.78), value: arrangement)
        .animation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.8), value: sampleCount)
        .sensoryFeedback(.selection, trigger: selectedID)
        .onChange(of: sampleCount) { _, _ in selectedID = samples.last?.id ?? 3 }
    }

    @ViewBuilder private var measurement: some View {
        if let selected {
            VStack(spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(selected.value, format: .number.precision(.fractionLength(1)))
                        .font(.system(.largeTitle, design: .rounded, weight: .semibold))
                        .monospacedDigit().contentTransition(.numericText())
                    Text("kg").font(.subheadline).foregroundStyle(.secondary)
                }
                Text(selected.day).font(.subheadline).foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("weightPebbleMeasurement")
        } else {
            Text("No check-ins yet").font(.headline).foregroundStyle(.secondary)
        }
    }

    private func pebbleField(compact: Bool) -> some View {
        GeometryReader { geometry in
            ZStack {
                if samples.isEmpty {
                    WeightStudyPebbleShape()
                        .strokeBorderPlaceholder
                        .frame(width: compact ? 64 : 122, height: compact ? 58 : 108)
                        .rotationEffect(.degrees(-12))
                        .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                        .accessibilityHidden(true)
                }
                ForEach(samples) { sample in
                    let position = location(sample.id, compact: compact, size: geometry.size)
                    Button {
                        withAnimation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.72)) {
                            selectedID = sample.id
                        }
                    } label: {
                        pebble(sample.id, selected: selected?.id == sample.id)
                            .frame(width: compact ? 44 : 128, height: compact ? 39 : 112)
                            .rotationEffect(.degrees(rotation(sample.id)))
                            .scaleEffect(selected?.id == sample.id ? 1.06 : 1)
                    }
                    .buttonStyle(.plain)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(.rect)
                    .position(position)
                    .zIndex(selected?.id == sample.id ? 10 : Double(sample.id))
                    .accessibilityLabel("Check-in, \(sample.day)")
                    .accessibilityValue("\(sample.value.formatted(.number.precision(.fractionLength(1)))) kilograms")
                    .accessibilityAddTraits(selected?.id == sample.id ? .isSelected : [])
                    .accessibilityIdentifier("weightPebble-\(compact ? "compact" : "large")-\(sample.id)")
                }
            }
        }
    }

    private func pebble(_ index: Int, selected: Bool) -> some View {
        let palettes: [[Color]] = [
            [Color(red: 0.58, green: 0.96, blue: 0.86), .teal],
            [Color(red: 0.59, green: 0.91, blue: 1), .cyan],
            [Color(red: 0.85, green: 0.78, blue: 1), Color(red: 0.52, green: 0.43, blue: 0.83)],
            [Color(red: 0.48, green: 0.94, blue: 0.90), Color(red: 0.06, green: 0.62, blue: 0.68)]
        ]
        let colors = palettes[index % palettes.count]
        return WeightStudyPebbleShape()
            .fill(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay {
                WeightStudyPebbleShape()
                    .fill(RadialGradient(colors: [.white.opacity(colorScheme == .dark ? 0.45 : 0.7), .clear], center: .init(x: 0.27, y: 0.16), startRadius: 0, endRadius: 60))
            }
            .overlay {
                WeightStudyPebbleShape()
                    .stroke(.white.opacity(selected ? 0.65 : 0.20), lineWidth: selected ? 2 : 1)
            }
            .shadow(color: colors[1].opacity(colorScheme == .dark ? 0.20 : 0.24), radius: selected ? 14 : 7, x: 0, y: selected ? 10 : 5)
            .offset(y: selected ? -3 : 0)
    }

    private func location(_ index: Int, compact: Bool, size: CGSize) -> CGPoint {
        guard sampleCount > 1 else { return CGPoint(x: size.width / 2, y: size.height / 2) }
        let offsets: [(CGFloat, CGFloat)] = arrangement == .gathered
            ? [(-0.24, -0.18), (0.18, -0.24), (-0.16, 0.20), (0.23, 0.16)]
            : [(-0.29, 0.16), (-0.11, -0.13), (0.12, -0.20), (0.29, 0.09)]
        let offset = offsets[index]
        return CGPoint(x: size.width * (0.5 + offset.0), y: size.height * (0.5 + offset.1))
    }

    private func rotation(_ index: Int) -> Double { [-19, 13, 24, -8][index] }
}

private struct WeightStudyPebbleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width, h = rect.height
        p.move(to: CGPoint(x: w * 0.42, y: h * 0.02))
        p.addCurve(to: CGPoint(x: w * 0.98, y: h * 0.49), control1: CGPoint(x: w * 0.77, y: -h * 0.04), control2: CGPoint(x: w * 1.04, y: h * 0.20))
        p.addCurve(to: CGPoint(x: w * 0.57, y: h * 0.98), control1: CGPoint(x: w * 0.98, y: h * 0.78), control2: CGPoint(x: w * 0.84, y: h * 1.02))
        p.addCurve(to: CGPoint(x: w * 0.02, y: h * 0.59), control1: CGPoint(x: w * 0.24, y: h * 0.99), control2: CGPoint(x: -w * 0.04, y: h * 0.91))
        p.addCurve(to: CGPoint(x: w * 0.42, y: h * 0.02), control1: CGPoint(x: -w * 0.03, y: h * 0.28), control2: CGPoint(x: w * 0.15, y: h * 0.07))
        p.closeSubpath()
        return p.offsetBy(dx: rect.minX, dy: rect.minY)
    }

    var strokeBorderPlaceholder: some View {
        self.fill(Color.teal.opacity(0.06))
            .overlay { self.stroke(Color.teal.opacity(0.3), style: StrokeStyle(lineWidth: 1.5, dash: [4, 6])) }
    }
}
#endif
