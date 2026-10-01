import SwiftUI

struct TrainingRhythmDay: Identifiable {
    let date: Date
    let strength: Int
    let movement: Int
    let names: [String]
    var isPartial = false
    var id: Date { date }
    var count: Int { strength + movement }
}

/// The plan defines the number of training days; the calendar is supporting history.
struct TrainingRhythmVisual: View {
    let days: [TrainingRhythmDay]
    var weeklyTarget: Int? = nil
    var compact = false
    @State private var selectedDay: Date?
    @Environment(\.dynamicTypeSize) private var typeSize

    private var selected: TrainingRhythmDay? {
        days.first { $0.date == selectedDay } ?? days.last(where: { $0.count > 0 })
            ?? days.first(where: { Calendar.current.isDateInToday($0.date) })
            ?? days.last(where: { $0.date <= Date() })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("This week").font(.subheadline).foregroundStyle(.secondary)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(days.contains(where: \.isPartial) ? "≥" : "")\(completedDays.count)")
                        .font(compact ? .title.bold() : .largeTitle.bold()).monospacedDigit()
                    Text(validTarget.map { "of \($0) training days" } ?? "training days")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
            }
            if let target = validTarget {
                HStack(spacing: 8) {
                    ForEach(0..<target, id: \.self) { index in
                        targetTile(index: index)
                    }
                    Spacer(minLength: 0)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Weekly training goal")
                .accessibilityValue("\(days.contains(where: \.isPartial) ? "At least " : "")\(completedDays.count) of \(target) days logged")
                if completedDays.count > target {
                    Text("\(completedDays.count - target) additional \(completedDays.count - target == 1 ? "day" : "days") logged")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            if !compact || validTarget == nil {
                ScrollView(.horizontal) { rhythmRow }.scrollIndicators(.hidden)
                    .accessibilityElement(children: compact ? .ignore : .contain)
                    .accessibilityLabel("Recorded workouts this week")
                    .accessibilityValue(compact ? "\(completedDays.count) days with logged workouts" : "")
            }
            if !compact, let selected {
                VStack(alignment: .leading, spacing: 4) {
                    Text(selected.date, format: .dateTime.weekday(.wide).month(.abbreviated).day())
                        .font(.subheadline.weight(.semibold))
                    Text(dayDescription(selected))
                        .font(.subheadline).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("activityRhythmSelection")
            }
        }
        .sensoryFeedback(.selection, trigger: selectedDay)
    }

    private func dayDescription(_ day: TrainingRhythmDay) -> String {
        if !day.names.isEmpty { return day.names.joined(separator: " · ") }
        if day.date > Calendar.current.startOfDay(for: Date()) { return "Upcoming" }
        return day.isPartial ? "See Workouts for earlier history" : "No workouts logged"
    }

    private var completedDays: [TrainingRhythmDay] { days.filter { $0.count > 0 } }
    private var validTarget: Int? { weeklyTarget.flatMap { (1...7).contains($0) ? $0 : nil } }

    private func targetTile(index: Int) -> some View {
        let day = completedDays.indices.contains(index) ? completedDays[index] : nil
        let tint: Color = day.map(color) ?? .accentColor
        return ZStack {
            RoundedRectangle(cornerRadius: 18)
                .fill(day == nil ? Color.secondary.opacity(0.06) : tint.opacity(0.14))
            if let day {
                RoundedRectangle(cornerRadius: 14)
                    .fill(tint.gradient)
                    .padding(4)
                Image(systemName: day.strength > 0 ? "dumbbell.fill" : "figure.run")
                    .font(.system(size: 16, weight: .semibold)).foregroundStyle(.white)
            } else {
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(.secondary.opacity(0.25), style: StrokeStyle(lineWidth: 1, dash: [3, 4]))
                    .padding(4)
                Circle().fill(.tertiary).frame(width: 5, height: 5)
            }
        }
        .frame(maxWidth: compact ? 48 : 52)
        .frame(height: compact ? 52 : 66)
    }

    private var rhythmRow: some View {
        HStack(spacing: compact ? 7 : 9) {
            ForEach(days) { day in
                Group {
                    if compact {
                        dayTile(day)
                    } else {
                        Button { selectedDay = day.date } label: { dayTile(day) }
                            .buttonStyle(.plain)
                            .accessibilityLabel(day.date.formatted(.dateTime.weekday(.wide).month().day()))
                            .accessibilityValue(dayDescription(day))
                            .accessibilityAddTraits(selected?.id == day.id ? .isSelected : [])
                            .accessibilityIdentifier("activityRhythmDay-\(day.date.timeIntervalSince1970)")
                    }
                }
            }
        }.padding(.vertical, 6)
    }

    private func dayTile(_ day: TrainingRhythmDay) -> some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(day.count == 0 ? Color.secondary.opacity(0.07) : color(day).opacity(0.16))
                if day.count > 0 {
                    RoundedRectangle(cornerRadius: 15)
                        .fill(LinearGradient(colors: [color(day).opacity(0.65), color(day)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .padding(4)
                        .shadow(color: color(day).opacity(0.25), radius: 6, y: 4)
                    VStack(spacing: 4) {
                        Image(systemName: day.strength > 0 ? "dumbbell.fill" : "figure.run")
                            .font(.caption.weight(.bold))
                        if !compact { Text(day.count.formatted()).font(.caption.bold()) }
                    }
                    .foregroundStyle(.white)
                } else {
                    Circle().fill(.tertiary).frame(width: 5, height: 5)
                }
            }
            .frame(width: compact ? 34 : 38, height: compact ? 48 : 72)
            .overlay(alignment: .bottom) {
                if !compact, selected?.id == day.id {
                    Capsule().fill(color(day)).frame(width: 16, height: 3).offset(y: 5)
                }
            }
            Text(day.date, format: .dateTime.weekday(.narrow))
                .font(.caption2.weight(.medium)).foregroundStyle(.secondary)
        }
        .frame(minWidth: compact ? 38 : 44, minHeight: 44)
        .contentShape(.rect)
    }

    private func color(_ day: TrainingRhythmDay) -> Color {
        day.strength > 0 ? .accentColor : .cyan
    }
}

struct WeightJourneySample: Identifiable {
    let id: UUID
    let date: Date
    let value: Double
}

/// A neutral check-in object. Its shape is decorative; only the display represents data.
/// Changes in weight are intentionally left to the history destination.
struct WeightJourneyVisual: View {
    let samples: [WeightJourneySample]
    let unit: String
    var compact = false
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var typeSize

    private var latest: WeightJourneySample? {
        samples.max { $0.date < $1.date }
    }

    var body: some View {
        let horizontal = compact && !typeSize.isAccessibilitySize
        let layout = horizontal
            ? AnyLayout(HStackLayout(alignment: .center, spacing: 18))
            : AnyLayout(VStackLayout(alignment: .center, spacing: 16))
        layout {
            WeightScaleMark(lit: latest != nil, weight: latest?.value ?? 0)
                .frame(width: compact ? 86 : 164, height: compact ? 80 : 154)
            VStack(alignment: horizontal ? .leading : .center, spacing: 5) {
                if let latest {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(latest.value, format: .number.precision(.fractionLength(1)))
                            .font(compact ? .title.bold() : .largeTitle.bold())
                            .fontDesign(.rounded).monospacedDigit()
                        Text(unit).font(.subheadline).foregroundStyle(.secondary)
                    }
                    Text(latest.date, format: .dateTime.month(.abbreviated).day().year())
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    Text("No measurements yet").font(.headline)
                    Text("Your first check-in starts here").font(.caption).foregroundStyle(.secondary)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: horizontal ? .leading : .center)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Latest weight check-in")
        .accessibilityValue(latest.map {
            "\($0.value.formatted(.number.precision(.fractionLength(1)))) \(unit), \($0.date.formatted(date: .abbreviated, time: .omitted))"
        } ?? "No measurements yet")
    }
}
