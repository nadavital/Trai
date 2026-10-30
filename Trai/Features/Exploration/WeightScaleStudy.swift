#if DEBUG
import SwiftUI

/// Sample-only identity study. No HealthKit or persistence writes.
struct WeightScaleStudy: View {
    @State private var dark = ProcessInfo.processInfo.arguments.contains("--scale-dark")
    @State private var showingLog = false
    @State private var weight = 72.4
    @State private var draft = 72.4
    @State private var logged = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack(spacing: 10) {
                        WeightScaleMark(lit: logged, weight: weight).frame(width: 36, height: 30)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Weight").font(.subheadline.bold())
                            Text("\(weight.formatted(.number.precision(.fractionLength(1)))) kg").font(.caption2).foregroundStyle(.secondary)
                        }
                    }.padding(.horizontal, 15).padding(.vertical, 10)
                        .glassEffect(.regular, in: .capsule)
                    VStack(spacing: 8) {
                        WeightScaleMark(lit: logged, weight: weight).frame(width: 164, height: 154).padding(.vertical, 12)
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
                            WeightScaleMark(lit: logged, weight: weight).frame(width: 80, height: 64)
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
            .navigationTitle("Scale study").navigationBarTitleDisplayMode(.inline)
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

#endif
