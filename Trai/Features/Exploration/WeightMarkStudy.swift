#if DEBUG
import SwiftUI

/// Sample-only exploration. No HealthKit or persistent writes.
struct WeightMarkStudy: View {
    @State private var treatment = 0
    @State private var dark = false
    @State private var hasSample = true
    @State private var showingEntry = false
    @State private var weight = 72.4
    @State private var draft = 72.4
    @State private var saved = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Picker("Mark", selection: $treatment) {
                        Text("Fold").tag(0)
                        Text("Imprint").tag(1)
                    }.pickerStyle(.segmented)

                    Button { openEntry() } label: {
                        VStack(spacing: 12) {
                            WeightStudyMark(treatment: treatment, compact: false)
                                .frame(width: 210, height: 190)
                                HStack(alignment: .firstTextBaseline, spacing: 5) {
                                Text(hasSample ? weight.formatted(.number.precision(.fractionLength(1))) : "—")
                                    .font(.system(size: 44, weight: .semibold, design: .rounded))
                                    .contentTransition(.numericText())
                                Text("kg").font(.title3).foregroundStyle(.secondary)
                            }.monospacedDigit()
                            Text(hasSample ? (saved ? "Just checked in" : "Today · 8:42 AM") : "Your first check-in")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }.frame(maxWidth: .infinity).padding(.vertical, 12)
                    }.buttonStyle(.plain).accessibilityIdentifier("weightMarkHero")
                        .accessibilityLabel(hasSample ? "Latest weight, \(weight.formatted()) kilograms. Log a check-in" : "Log your first weight check-in")

                    Button(hasSample ? "Check in" : "Log weight", systemImage: "plus", action: openEntry)
                        .font(.headline).buttonStyle(.glassProminent).tint(.accentColor)
                        .controlSize(.large).accessibilityIdentifier("weightMarkLog")

                    HStack(spacing: 12) {
                        WeightStudyMark(treatment: treatment, compact: true).frame(width: 48, height: 48)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Weight").font(.subheadline.weight(.semibold))
                            Text(hasSample ? "\(weight.formatted(.number.precision(.fractionLength(1)))) kg" : "Add a check-in")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button(action: openEntry) { Image(systemName: "plus").frame(width: 44, height: 44) }
                            .buttonStyle(.glass).tint(.primary).accessibilityLabel("Log weight from compact card")
                    }.padding(16).background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 24))

                    Toggle("Show sample measurement", isOn: $hasSample).font(.subheadline)
                        .accessibilityIdentifier("weightMarkSample")
                    Text("A check-in, not a score.").font(.caption).foregroundStyle(.secondary)
                }.padding(20)
            }
            .background {
                LinearGradient(colors: [Color.purple.opacity(dark ? 0.12 : 0.045), Color(.systemGroupedBackground)], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
            }
            .navigationTitle("Weight studies").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dark.toggle() } label: { Image(systemName: dark ? "sun.max" : "moon") }
                        .accessibilityLabel("Switch appearance")
                }
            }
            .safeAreaInset(edge: .bottom) {
                Text("Design study · sample data only").font(.caption2).foregroundStyle(.secondary)
                    .padding(8).frame(maxWidth: .infinity).background(.bar)
            }
            .sheet(isPresented: $showingEntry) {
                NavigationStack {
                    VStack(spacing: 24) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(draft.formatted(.number.precision(.fractionLength(1))))
                                .font(.system(size: 42, weight: .semibold, design: .rounded)).monospacedDigit()
                            Text("kg").foregroundStyle(.secondary)
                        }
                        Stepper("Weight", value: $draft, in: 30...250, step: 0.1)
                        Button("Save sample") {
                            withAnimation(reduceMotion ? nil : .smooth(duration: 0.4)) {
                                weight = draft; hasSample = true; saved = true
                            }
                            showingEntry = false
                        }.buttonStyle(.glassProminent).tint(.accentColor).controlSize(.large)
                    }.padding(24).navigationTitle("Check in").navigationBarTitleDisplayMode(.inline)
                        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { showingEntry = false } } }
                }.presentationDetents([.height(300)]).presentationDragIndicator(.visible)
            }
        }.preferredColorScheme(dark ? .dark : .light)
    }

    private func openEntry() { draft = weight; showingEntry = true }
}

private struct WeightStudyMark: View {
    let treatment: Int
    let compact: Bool
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    private let mauve = Color(red: 0.66, green: 0.38, blue: 0.73)
    private let peach = Color(red: 0.96, green: 0.64, blue: 0.53)

    var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            ZStack {
                if treatment == 0 {
                    piece(FoldRibbon(back: true), tint: mauve.opacity(0.82))
                    piece(FoldRibbon(back: false), tint: peach.opacity(0.86))
                } else {
                    piece(ImprintPlate(back: true), tint: mauve.opacity(0.55))
                    piece(ImprintPlate(back: false), tint: peach.opacity(0.76))
                    VStack(spacing: side * 0.075) {
                        Capsule().fill(.white.opacity(0.85)).frame(width: side * 0.29, height: side * 0.045)
                        Capsule().fill(.white.opacity(0.55)).frame(width: side * 0.18, height: side * 0.035)
                    }.rotationEffect(.degrees(8)).offset(x: side * 0.07)
                }
            }.frame(width: side, height: side).frame(maxWidth: .infinity, maxHeight: .infinity)
        }.id(treatment).accessibilityHidden(true)
    }

    @ViewBuilder private func piece<S: Shape>(_ shape: S, tint: Color, width: CGFloat? = nil, height: CGFloat? = nil) -> some View {
        if compact || reduceTransparency {
            shape.fill(tint.gradient).frame(width: width, height: height)
        } else {
            Color.clear.frame(width: width, height: height).glassEffect(.regular.tint(tint), in: shape)
        }
    }
}

private struct ImprintPlate: Shape {
    let back: Bool
    func path(in rect: CGRect) -> Path {
        let side = min(rect.width, rect.height)
        let box = CGRect(x: -side * 0.355, y: -side * 0.385, width: side * 0.71, height: side * 0.77)
        let plate = Path(roundedRect: box, cornerRadius: side * 0.23)
        let transform = CGAffineTransform(translationX: rect.midX + side * (back ? -0.06 : 0.07),
                                         y: rect.midY + side * (back ? 0.04 : -0.025))
            .rotated(by: (back ? -12 : 8) * .pi / 180)
        return plate.applying(transform)
    }
}

/// Two broad curved folds, with an open silhouette that remains legible at 48 points.
private struct FoldRibbon: Shape {
    let back: Bool
    func path(in rect: CGRect) -> Path {
        var path = Path()
        if back {
            path.move(to: CGPoint(x: 0.34, y: 0.14))
            path.addCurve(to: CGPoint(x: 0.80, y: 0.67), control1: CGPoint(x: 0.72, y: 0.04), control2: CGPoint(x: 0.92, y: 0.37))
            path.addQuadCurve(to: CGPoint(x: 0.57, y: 0.88), control: CGPoint(x: 0.75, y: 0.88))
            path.addLine(to: CGPoint(x: 0.45, y: 0.68))
            path.addCurve(to: CGPoint(x: 0.34, y: 0.14), control1: CGPoint(x: 0.72, y: 0.62), control2: CGPoint(x: 0.60, y: 0.29))
        } else {
            path.move(to: CGPoint(x: 0.34, y: 0.14))
            path.addCurve(to: CGPoint(x: 0.30, y: 0.69), control1: CGPoint(x: 0.10, y: 0.28), control2: CGPoint(x: 0.10, y: 0.58))
            path.addQuadCurve(to: CGPoint(x: 0.57, y: 0.88), control: CGPoint(x: 0.39, y: 0.82))
            path.addLine(to: CGPoint(x: 0.68, y: 0.66))
            path.addCurve(to: CGPoint(x: 0.34, y: 0.14), control1: CGPoint(x: 0.37, y: 0.66), control2: CGPoint(x: 0.29, y: 0.44))
        }
        path.closeSubpath()
        return path.applying(CGAffineTransform(scaleX: rect.width, y: rect.height).translatedBy(x: rect.minX, y: rect.minY))
    }
}
#endif
