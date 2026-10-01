#if DEBUG
import SwiftUI

/// Sample-only identity study. No HealthKit or persistence writes.
struct WeightRibbonStudy: View {
    @State private var dark = ProcessInfo.processInfo.arguments.contains("--ribbon-dark")
    @State private var showingLog = false
    @State private var weight = 72.4
    @State private var draft = 72.4
    @State private var logged = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack(spacing: 10) {
                        WeightRibbonMark().frame(width: 36, height: 30)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Weight").font(.subheadline.bold())
                            Text("Latest check-in").font(.caption2).foregroundStyle(.secondary)
                        }
                    }.padding(.horizontal, 15).padding(.vertical, 10)
                        .glassEffect(.regular, in: .capsule)
                    VStack(spacing: 8) {
                        WeightRibbonMark().frame(width: 230, height: 160).padding(.vertical, 12)
                        HStack(alignment: .firstTextBaseline, spacing: 5) {
                            Text(weight, format: .number.precision(.fractionLength(1)))
                                .font(.system(size: 44, weight: .semibold, design: .rounded))
                            Text("kg").font(.title3).foregroundStyle(.secondary)
                        }
                        Text(logged ? "Today’s check-in" : "Yesterday, 8:12 AM")
                            .font(.subheadline).foregroundStyle(.secondary)
                        Button { draft = weight; showingLog = true } label: {
                            Label("Log weight", systemImage: "plus").font(.headline).padding(.horizontal, 20).padding(.vertical, 6)
                        }.buttonStyle(.borderedProminent).buttonBorderShape(.capsule).tint(.accentColor).padding(.top, 12)
                    }.frame(maxWidth: .infinity)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("On your dashboard").font(.subheadline).foregroundStyle(.secondary)
                        HStack(spacing: 18) {
                            WeightRibbonMark().frame(width: 80, height: 64)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Weight").font(.subheadline).foregroundStyle(.secondary)
                                Text("\(weight.formatted(.number.precision(.fractionLength(1)))) kg")
                                    .font(.title2.bold()).fontDesign(.rounded)
                                Text(logged ? "Today" : "Yesterday").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                            Button { draft = weight; showingLog = true } label: {
                                Image(systemName: "plus").font(.headline).frame(width: 44, height: 44)
                                    .background(Color.accentColor.opacity(0.09), in: .circle)
                            }.tint(.accentColor).accessibilityLabel("Log weight from dashboard")
                        }.padding(18).background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 24))
                    }.padding(.top, 8)
                    Text("Sample data · visual exploration").font(.caption2).foregroundStyle(.secondary).frame(maxWidth: .infinity)
                }.padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Ribbon study").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dark.toggle() } label: { Image(systemName: dark ? "sun.max" : "moon") }
                        .accessibilityLabel("Switch appearance").accessibilityValue(dark ? "Dark" : "Light")
                }
            }
            .sheet(isPresented: $showingLog) {
                NavigationStack {
                    Form { Stepper(value: $draft, in: 30...250, step: 0.1) { Text("\(draft.formatted(.number.precision(.fractionLength(1)))) kg").font(.title2).monospacedDigit() } }
                        .navigationTitle("Log weight").navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { showingLog = false } }
                            ToolbarItem(placement: .confirmationAction) { Button("Save") { weight = draft; logged = true; showingLog = false }.tint(.accentColor) }
                        }
                }.presentationDetents([.medium])
            }
        }.preferredColorScheme(dark ? .dark : .light)
    }
}

/// Four broad ribbon faces with curved folds, shaded independently to reveal their depth.
private struct WeightRibbonMark: View {
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        GeometryReader { proxy in
            let scale = min(proxy.size.width / 240, proxy.size.height / 170)
            ZStack {
                // Back faces first; the brighter returns wrap over them at the bottom folds.
                RibbonFace(points: [18, 30, 48, 25, 87, 124, 65, 145])
                    .fill(LinearGradient(colors: [Color(red: 1, green: 0.53, blue: 0.46), Color(red: 0.72, green: 0.12, blue: 0.24)], startPoint: .topLeading, endPoint: .bottomTrailing))
                RibbonFace(points: [112, 37, 140, 28, 184, 125, 158, 145])
                    .fill(LinearGradient(colors: [Color(red: 0.96, green: 0.39, blue: 0.38), Color(red: 0.64, green: 0.09, blue: 0.24)], startPoint: .topLeading, endPoint: .bottomTrailing))
                returnFace(left: 58, right: 91, top: 38, end: 127)
                returnFace(left: 151, right: 184, top: 27, end: 222)
            }
            .frame(width: 240, height: 170)
            .shadow(color: Color(red: 0.67, green: 0.13, blue: 0.21).opacity(scheme == .dark ? 0.18 : 0.14), radius: 9, x: 0, y: 10)
            .scaleEffect(scale, anchor: .topLeading)
            .frame(width: 240 * scale, height: 170 * scale)
            .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
        }.accessibilityHidden(true)
    }

    private func returnFace(left: CGFloat, right: CGFloat, top: CGFloat, end: CGFloat) -> some View {
        let path = Path { p in
            p.move(to: CGPoint(x: left, y: 128))
            p.addQuadCurve(to: CGPoint(x: right, y: 141), control: CGPoint(x: left + 10, y: 163))
            p.addLine(to: CGPoint(x: end + 12, y: top + 9))
            p.addQuadCurve(to: CGPoint(x: end - 15, y: top - 1), control: CGPoint(x: end + 4, y: top - 10))
            p.addLine(to: CGPoint(x: left + 15, y: 128))
            p.addQuadCurve(to: CGPoint(x: left, y: 128), control: CGPoint(x: left + 6, y: 143))
            p.closeSubpath()
        }
        return path.fill(LinearGradient(stops: [
            .init(color: Color(red: 1, green: 0.74, blue: 0.57), location: 0),
            .init(color: Color(red: 1, green: 0.48, blue: 0.43), location: 0.38),
            .init(color: Color(red: 0.91, green: 0.23, blue: 0.34), location: 0.73),
            .init(color: Color(red: 1, green: 0.58, blue: 0.49), location: 1)
        ], startPoint: .topLeading, endPoint: .bottomTrailing))
        .overlay { path.stroke(.white.opacity(scheme == .dark ? 0.16 : 0.24), lineWidth: 0.7) }
    }
}

private struct RibbonFace: Shape {
    let points: [CGFloat]
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: points[0], y: points[1]))
        p.addQuadCurve(to: CGPoint(x: points[2], y: points[3]), control: CGPoint(x: (points[0] + points[2]) / 2, y: points[1] - 13))
        p.addLine(to: CGPoint(x: points[4], y: points[5]))
        p.addQuadCurve(to: CGPoint(x: points[6], y: points[7]), control: CGPoint(x: points[4], y: points[7] + 13))
        p.closeSubpath()
        return p
    }
}
#endif
