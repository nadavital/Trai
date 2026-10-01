#if DEBUG
import SwiftUI

/// Native visual study, deliberately isolated from persistence and notification scheduling.
struct RoutineRhythmStudy: View {
    private struct Habit: Identifiable {
        let id: String
        let name: String
        let symbol: String
        let frequency: String
        let days: Set<Int>
    }
    private struct Occurrence: Identifiable {
        let habit: Habit
        let day: Int
        var id: String { "\(habit.id)-\(day)" }
    }
    private let habits = [
        Habit(id: "weight", name: "Weight check-in", symbol: "scalemass", frequency: "Weekdays", days: [0, 1, 2, 3, 4]),
        Habit(id: "stretch", name: "Stretch", symbol: "figure.flexibility", frequency: "Every day", days: Set(0..<7)),
        Habit(id: "plan", name: "Plan meals", symbol: "list.bullet.rectangle", frequency: "Once a week · Sunday", days: [6])
    ]
    @State private var today = 3
    @State private var completed: Set<String> = ["stretch-3"]
    @State private var selected: Occurrence?
    @State private var weight = 72.4
    @State private var draftWeight = 72.4
    @State private var dark = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let ink = Color(red: 0.84, green: 0.29, blue: 0.30)
    private let dayNames = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    private var occurrences: [Occurrence] {
        (today..<(today + 4)).flatMap { day in
            habits.filter { $0.days.contains(day % 7) }.map { Occurrence(habit: $0, day: day) }
        }
    }
    private var dueToday: [Occurrence] { occurrences.filter { $0.day == today } }
    private var doneToday: Int { dueToday.filter { completed.contains($0.id) }.count }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        HStack(spacing: 9) {
                            HStack(spacing: 3) {
                                ForEach(Array(occurrences.prefix(5).enumerated()), id: \.element.id) { index, occurrence in
                                    StitchMark(done: completed.contains(occurrence.id), current: occurrence.day == today, color: ink)
                                        .frame(width: 5, height: 18)
                                        .rotationEffect(.degrees(18))
                                        .offset(y: sin(Double(index) * 0.9) * 4)
                                }
                            }.frame(width: 40, height: 28).accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Routine").font(.subheadline.weight(.semibold))
                                Text("\(doneToday) of \(dueToday.count) today").font(.caption2).foregroundStyle(.secondary)
                            }
                        }.padding(.horizontal, 15).padding(.vertical, 9)
                            .glassEffect(.regular, in: .capsule)
                        Spacer()
                        Button { dark.toggle() } label: {
                            Image(systemName: dark ? "sun.max" : "moon").frame(width: 44, height: 44).contentShape(.rect)
                        }.buttonStyle(.plain).foregroundStyle(.secondary).accessibilityLabel("Switch appearance")
                            .accessibilityValue(dark ? "Dark" : "Light")
                    }
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Your rhythm").font(.largeTitle.bold()).fontDesign(.rounded)
                        Text(doneToday == dueToday.count ? "Today’s check-ins are complete." : "\(dueToday.count - doneToday) \(dueToday.count - doneToday == 1 ? "check-in" : "check-ins") left today.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    rhythm
                    routineList
                    HStack {
                        Text("Preview day").font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Picker("Preview day", selection: $today) {
                            ForEach(3..<7, id: \.self) { Text(dayNames[$0]).tag($0) }
                        }.pickerStyle(.menu).tint(.secondary).accessibilityIdentifier("rhythmDay")
                    }.padding(.top, 6)
                }.padding(20)
            }
            .background {
                LinearGradient(colors: [ink.opacity(dark ? 0.075 : 0.035), Color(.systemGroupedBackground)], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
            }
            .navigationTitle("Rhythm study").navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                Text("Sample routines · no data saved").font(.caption2).foregroundStyle(.secondary)
                    .padding(8).frame(maxWidth: .infinity).background(.bar)
            }
            .sheet(item: $selected) { occurrence in
                NavigationStack {
                    ScrollView {
                    VStack(spacing: 22) {
                        Text(occurrence.habit.frequency).font(.subheadline).foregroundStyle(.secondary)
                        if occurrence.habit.id == "weight" {
                            Text("\(draftWeight.formatted(.number.precision(.fractionLength(1)))) kg")
                                .font(.system(size: 38, weight: .semibold, design: .rounded)).monospacedDigit()
                            Stepper("Weight", value: $draftWeight, in: 30...250, step: 0.1)
                                .disabled(occurrence.day != today)
                        }
                        if occurrence.day == today {
                            Button(completed.contains(occurrence.id) ? "Undo check-in" : "Save check-in") {
                                withAnimation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.8)) {
                                    if completed.contains(occurrence.id) { completed.remove(occurrence.id) }
                                    else {
                                        if occurrence.habit.id == "weight" { weight = draftWeight }
                                        completed.insert(occurrence.id)
                                    }
                                }
                                selected = nil
                            }.buttonStyle(.borderedProminent).tint(.accentColor).controlSize(.large).buttonBorderShape(.capsule)
                        } else {
                            Text("Next on \(dayNames[occurrence.day % 7])").font(.headline)
                        }
                    }.padding(24)
                    }.onAppear { draftWeight = weight }.navigationTitle(occurrence.habit.name).navigationBarTitleDisplayMode(.inline)
                        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { selected = nil } } }
                }.presentationDetents([.medium, .large]).presentationDragIndicator(.visible)
            }
        }.preferredColorScheme(dark ? .dark : .light)
    }

    private var rhythm: some View {
        VStack(spacing: 12) {
            GeometryReader { geometry in
                let count = occurrences.count
                let width = max(geometry.size.width, CGFloat(count) * 46)
                let step = width / CGFloat(max(1, count))
                ScrollView(.horizontal, showsIndicators: false) {
                ZStack(alignment: .topLeading) {
                ForEach(Array(occurrences.enumerated()), id: \.element.id) { index, occurrence in
                    let progress = Double(index) / Double(max(1, count - 1))
                    let y = 36 + sin(progress * .pi * 1.5) * 16
                    Button { selected = occurrence } label: {
                        StitchMark(done: completed.contains(occurrence.id), current: occurrence.day == today, color: ink)
                            .frame(width: 14, height: occurrence.day == today ? 44 : 35)
                            .rotationEffect(.degrees(18 + progress * 22))
                            .frame(width: max(44, step), height: 70).contentShape(.rect)
                    }.buttonStyle(.plain)
                        .position(x: step * (CGFloat(index) + 0.5), y: y)
                        .accessibilityLabel("\(occurrence.habit.name), \(occurrence.day == today ? "today" : dayNames[occurrence.day % 7]), \(completed.contains(occurrence.id) ? "done" : "scheduled")")
                        .accessibilityIdentifier("stitch-\(occurrence.id)")
                    if index == 0 || occurrences[index - 1].day != occurrence.day {
                        Text(occurrence.day == today ? "Today" : dayNames[occurrence.day % 7])
                            .font(.caption2).foregroundStyle(.secondary)
                            .position(x: step * (CGFloat(index) + CGFloat(occurrences.filter { $0.day == occurrence.day }.count) / 2), y: 91)
                    }
                }
                }.frame(width: width, height: 107)
                }
            }.frame(height: 107)
            HStack(spacing: 16) {
                Label("Checked in", systemImage: "capsule.fill").foregroundStyle(ink)
                Label("Upcoming", systemImage: "capsule").foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }.font(.caption2)
        }.padding(.vertical, 6)
    }

    private var routineList: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Today").font(.title3.bold()).fontDesign(.rounded)
            ForEach(dueToday) { occurrence in row(occurrence) }
            let later = habits.filter { !$0.days.contains(today % 7) }
            if !later.isEmpty {
                Text("Coming up").font(.title3.bold()).fontDesign(.rounded).padding(.top, 8)
                ForEach(later) { habit in
                    if let next = occurrences.first(where: { $0.habit.id == habit.id }) { row(next) }
                }
            }
        }
    }

    private func row(_ occurrence: Occurrence) -> some View {
        let done = completed.contains(occurrence.id)
        return Button {
            if occurrence.day == today && occurrence.habit.id != "weight" {
                withAnimation(reduceMotion ? nil : .smooth) {
                    if done { completed.remove(occurrence.id) } else { completed.insert(occurrence.id) }
                }
            } else { selected = occurrence }
        } label: {
            HStack(spacing: 14) {
                StitchMark(done: done, current: occurrence.day == today, color: ink).frame(width: 10, height: 32)
                VStack(alignment: .leading, spacing: 5) {
                    Text(occurrence.habit.name).font(.headline).foregroundStyle(.primary)
                    Text(occurrence.habit.frequency).font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 4)
                if done { Image(systemName: "checkmark").foregroundStyle(ink) }
                else if occurrence.day == today { Text(occurrence.habit.id == "weight" ? "Log" : "Done").font(.subheadline.weight(.semibold)).foregroundStyle(ink) }
                else { Text(dayNames[occurrence.day % 7]).font(.subheadline).foregroundStyle(.secondary) }
            }.padding(17).background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 22))
        }.buttonStyle(.plain).accessibilityIdentifier("rhythmRow-\(occurrence.habit.id)")
    }
}

private struct StitchMark: View {
    let done: Bool
    let current: Bool
    let color: Color
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        RoundedRectangle(cornerRadius: 5)
            .fill(done ? AnyShapeStyle(color.gradient) : AnyShapeStyle(Color.clear))
            .overlay {
                RoundedRectangle(cornerRadius: 5).strokeBorder(done ? color.opacity(0.25) : current ? color.opacity(0.85) : Color.primary.opacity(scheme == .dark ? 0.46 : 0.42), lineWidth: current ? 1.8 : 1.4)
            }
            .overlay(alignment: .leading) {
                if done { Capsule().fill(.white.opacity(0.24)).frame(width: 1).padding(.vertical, 5).padding(.leading, 2) }
            }
            .shadow(color: done ? color.opacity(0.18) : .clear, radius: 4, x: 0, y: 3)
    }
}
#endif
