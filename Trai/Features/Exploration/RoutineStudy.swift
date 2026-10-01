#if DEBUG
import SwiftUI

/// An isolated, sample-only dashboard section. Does not schedule notifications or write health data.
struct RoutineStudy: View {
    @State private var section = 1
    @State private var dark = false
    @State private var weight = 72.4
    @State private var draftWeight = 72.4
    @State private var checkedDays: Set<Int> = [0]
    @State private var scheduledDays: Set<Int> = [0, 3]
    @State private var sheet: Destination?
    @State private var reminderTime = Calendar.current.date(from: DateComponents(year: 2026, month: 9, day: 24, hour: 18))!
    @State private var reminderDraft: ReminderDraft?
    @State private var reminders = [StudyReminder(title: "Pack your gym bag", hour: 18), StudyReminder(title: "Plan tomorrow’s meals", hour: 19, minute: 30)]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    private let weekdays = ["M", "T", "W", "T", "F", "S", "S"]
    private let fullDays = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
    private let accent = Color(red: 0.68, green: 0.40, blue: 0.68)
    private enum Destination: String, Identifiable { case weight, schedule, history; var id: String { rawValue } }
    private struct ReminderDraft: Identifiable {
        let id = UUID()
        var reminderID: UUID?
        var title: String
        var time: Date
    }
    private struct StudyReminder: Identifiable {
        let id = UUID()
        var title: String
        var date: Date
        var time: String { date.formatted(date: .omitted, time: .shortened) }
        init(title: String, hour: Int, minute: Int = 0) {
            self.title = title
            self.date = Calendar.current.date(from: DateComponents(year: 2026, month: 9, day: 24, hour: hour, minute: minute))!
        }
        init(title: String, date: Date) { self.title = title; self.date = date }
        var done = false
        var snoozed = false
    }
    private var weekComplete: Bool { !scheduledDays.isEmpty && scheduledDays.isSubset(of: checkedDays) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    sectionPill("Today", icon: "sun.max.fill", index: 0)
                    sectionPill("Routine", icon: weekComplete && reminders.allSatisfy({ $0.done || $0.snoozed }) ? "checkmark.circle.fill" : "calendar", index: 1)
                    Spacer(minLength: 0)
                    Button { dark.toggle() } label: {
                        Image(systemName: dark ? "sun.max" : "moon").frame(width: 44, height: 44).contentShape(.rect)
                    }.buttonStyle(.plain).foregroundStyle(.secondary)
                        .accessibilityLabel("Switch appearance").accessibilityValue(dark ? "Dark" : "Light")
                }.padding(.horizontal, 20).padding(.bottom, 12)
                TabView(selection: $section) {
                    todayPreview.tag(0)
                    routinePage.tag(1)
                }.tabViewStyle(.page(indexDisplayMode: .never))
            }
            .background {
                LinearGradient(colors: [accent.opacity(dark ? 0.13 : 0.075), Color(.systemGroupedBackground), Color(.systemGroupedBackground)], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
            }
            .navigationTitle("Dashboard study").navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                Text("Prototype · sample week · no data saved").font(.caption2).foregroundStyle(.secondary)
                    .padding(8).frame(maxWidth: .infinity).background(.bar)
            }
            .sheet(item: $sheet) { destination in
                NavigationStack {
                    sheetContent(destination)
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { sheet = nil } } }
                }.presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(item: $reminderDraft) { draft in
                NavigationStack {
                    RoutineReminderEditor(title: draft.title, time: draft.time, editing: draft.reminderID != nil) { title, time in
                        if let id = draft.reminderID, let index = reminders.firstIndex(where: { $0.id == id }) {
                            reminders[index].title = title
                            reminders[index].date = time
                        } else { reminders.append(StudyReminder(title: title, date: time)) }
                    }
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { reminderDraft = nil } } }
                }.presentationDetents([.medium, .large]).presentationDragIndicator(.visible)
            }
        }.preferredColorScheme(dark ? .dark : .light)
    }

    private func sectionPill(_ title: String, icon: String, index: Int) -> some View {
        Button { withAnimation(reduceMotion ? nil : .smooth) { section = index } } label: {
            Label(title, systemImage: icon).font(.subheadline.weight(.semibold))
                .padding(.horizontal, 15).padding(.vertical, 12)
        }.buttonStyle(.plain).foregroundStyle(section == index ? Color.primary : Color.secondary)
            .glassEffect(.regular.tint(section == index ? accent.opacity(0.16) : .clear).interactive(), in: .capsule)
            .accessibilityAddTraits(section == index ? .isSelected : [])
            .accessibilityIdentifier("routineSection\(index)")
    }

    private var routinePage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your routine").font(.largeTitle.bold()).fontDesign(.rounded)
                    Text("Thursday, September 24").font(.subheadline).foregroundStyle(.secondary)
                }
                weightCard
                remindersSection
            }.padding(20)
        }
    }

    private var weightCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Weight check-in").font(.headline)
                Spacer()
                Button { sheet = .history } label: { Image(systemName: "clock.arrow.circlepath").frame(width: 44, height: 44) }
                    .foregroundStyle(.secondary).accessibilityLabel("Weight history")
            }
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(weight.formatted(.number.precision(.fractionLength(1)))).font(.system(size: 38, weight: .semibold, design: .rounded)).monospacedDigit()
                Text("kg").font(.title3).foregroundStyle(.secondary)
                Spacer()
                Text(checkedDays.contains(3) ? "Today" : "Monday").font(.subheadline).foregroundStyle(.secondary)
            }
            Button { sheet = .schedule } label: {
                VStack(spacing: 10) {
                    HStack {
                        Text("This week").font(.caption)
                        Spacer()
                        Label("Edit", systemImage: "pencil").font(.caption)
                    }.foregroundStyle(.secondary)
                    weekCalendar
                }
            }.buttonStyle(.plain).accessibilityLabel("Edit check-in schedule")
            let footerLayout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12)) : AnyLayout(HStackLayout(spacing: 12))
            footerLayout {
                Text(weekComplete ? "Your week is covered" : scheduledDays.contains(3) ? "Check-in scheduled today" : "Your own schedule")
                    .font(.subheadline).foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Button(checkedDays.contains(3) ? "Update" : "Check in", systemImage: "plus") {
                    draftWeight = weight; sheet = .weight
                }.font(.subheadline.weight(.semibold)).buttonStyle(.borderedProminent).tint(.accentColor)
                    .controlSize(.large).buttonBorderShape(.capsule).accessibilityIdentifier("routineCheckIn")
            }
        }.padding(18).background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 26))
    }

    private var weekCalendar: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: typeSize.isAccessibilitySize ? 4 : 7)
        return LazyVGrid(columns: columns, spacing: 12) {
            ForEach(0..<7, id: \.self) { day in
                VStack(spacing: 8) {
                    Text(weekdays[day]).font(.caption).foregroundStyle(.secondary)
                    ZStack {
                        RoundedRectangle(cornerRadius: 12).fill(checkedDays.contains(day) ? accent : accent.opacity(0.055))
                        RoundedRectangle(cornerRadius: 12).strokeBorder(scheduledDays.contains(day) && !checkedDays.contains(day) ? accent.opacity(0.7) : .clear, style: StrokeStyle(lineWidth: 1.4, dash: [3, 3]))
                        if checkedDays.contains(day) {
                            Image(systemName: "checkmark").font(.subheadline.bold()).foregroundStyle(.white)
                        } else { Text("\(21 + day)").font(.subheadline.weight(day == 3 ? .bold : .regular)).foregroundStyle(day == 3 ? .primary : .secondary) }
                    }.frame(height: 42)
                    Circle().fill(day == 3 ? accent : .clear).frame(width: 4, height: 4)
                }.accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(fullDays[day]), \(checkedDays.contains(day) ? "checked in" : scheduledDays.contains(day) ? "scheduled" : "no check-in scheduled")\(day == 3 ? ", today" : "")")
            }
        }
    }

    private var remindersSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Reminders").font(.title3.bold()).fontDesign(.rounded)
                Spacer()
                Button { reminderDraft = ReminderDraft(title: "", time: reminderTime) } label: { Image(systemName: "plus").frame(width: 44, height: 44) }
                    .foregroundStyle(.primary).accessibilityLabel("Add reminder")
            }
            ForEach($reminders) { $reminder in
                HStack(spacing: 12) {
                    Button { reminder.done.toggle() } label: {
                        Image(systemName: reminder.done ? "checkmark.circle.fill" : "circle")
                            .font(.title2).foregroundStyle(reminder.done ? accent : Color.secondary)
                            .frame(width: 44, height: 44)
                    }.accessibilityLabel(reminder.done ? "Undo \(reminder.title)" : "Complete \(reminder.title)")
                    VStack(alignment: .leading, spacing: 4) {
                        Text(reminder.title).font(.subheadline.weight(.medium)).strikethrough(reminder.done)
                        Text(reminder.done ? "Done" : reminder.snoozed ? "Tomorrow · \(reminder.time)" : "Today · \(reminder.time)")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                    Menu {
                        Button(reminder.snoozed ? "Move to today" : "Snooze until tomorrow", systemImage: "clock") { reminder.snoozed.toggle() }
                        Button("Edit", systemImage: "pencil") {
                            reminderDraft = ReminderDraft(reminderID: reminder.id, title: reminder.title, time: reminder.date)
                        }
                    } label: { Image(systemName: "ellipsis").frame(width: 44, height: 44).foregroundStyle(.secondary) }
                        .tint(.secondary).accessibilityLabel("Options for \(reminder.title)")
                }.padding(10).background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 20))
            }
        }
    }

    private var todayPreview: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Today").font(.largeTitle.bold()).fontDesign(.rounded)
                Text("Weight card placement preview").font(.subheadline).foregroundStyle(.secondary)
                HStack(spacing: 14) {
                    VStack(spacing: 4) {
                        Text("THU").font(.caption2.bold()).foregroundStyle(accent)
                        Text("24").font(.title2.bold()).fontDesign(.rounded)
                        Image(systemName: checkedDays.contains(3) ? "checkmark.circle.fill" : "circle.dashed").foregroundStyle(accent)
                    }.frame(width: 58, height: 78).background(accent.opacity(0.09), in: .rect(cornerRadius: 16))
                    Button { sheet = .history } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Weight").font(.headline)
                            Text("\(weight.formatted(.number.precision(.fractionLength(1)))) kg").font(.title3.weight(.semibold)).monospacedDigit()
                            Text(checkedDays.contains(3) ? "Checked in today" : "Last check-in Monday").font(.caption).foregroundStyle(.secondary)
                        }
                    }.buttonStyle(.plain)
                    Spacer(minLength: 0)
                    Button { draftWeight = weight; sheet = .weight } label: { Image(systemName: "plus").frame(width: 44, height: 44) }
                        .buttonStyle(.glass).tint(.primary).accessibilityLabel("Quick weight check-in")
                }.padding(16).background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 24))
                Button { withAnimation(reduceMotion ? nil : .smooth) { section = 1 } } label: {
                    HStack { Label("Your routine", systemImage: "calendar"); Spacer(); Image(systemName: "chevron.right") }
                }.font(.subheadline).foregroundStyle(.secondary)
            }.padding(20)
        }
    }

    @ViewBuilder private func sheetContent(_ destination: Destination) -> some View {
        switch destination {
        case .weight:
            ScrollView {
            VStack(spacing: 24) {
                HStack(alignment: .firstTextBaseline) {
                    Text(draftWeight.formatted(.number.precision(.fractionLength(1)))).font(.system(size: 42, weight: .semibold, design: .rounded)).monospacedDigit()
                    Text("kg").foregroundStyle(.secondary)
                }
                Stepper("Weight", value: $draftWeight, in: 30...250, step: 0.1)
                Button("Save check-in") {
                    withAnimation(reduceMotion ? nil : .smooth) { weight = draftWeight; checkedDays.insert(3) }
                    sheet = nil
                }.buttonStyle(.borderedProminent).tint(.accentColor).controlSize(.large).buttonBorderShape(.capsule)
            }.padding(24)
            }.navigationTitle("Weight check-in")
        case .schedule:
            List {
                Section { ForEach(0..<7, id: \.self) { day in
                    Button {
                        if scheduledDays.contains(day) { scheduledDays.remove(day) } else { scheduledDays.insert(day) }
                    } label: {
                        HStack { Text(fullDays[day]); Spacer(); if scheduledDays.contains(day) { Image(systemName: "checkmark").foregroundStyle(accent) } }.foregroundStyle(.primary)
                    }.accessibilityAddTraits(scheduledDays.contains(day) ? .isSelected : [])
                } } footer: { Text("Choose the days that suit you. Check-ins are always available.") }
            }.navigationTitle("Your schedule")
        case .history:
            List {
                Section("Latest") { LabeledContent(checkedDays.contains(3) ? "Thursday, Sep 24" : "Monday, Sep 21", value: "\(weight.formatted()) kg") }
                Section("Previous check-ins") {
                    if checkedDays.contains(3) { LabeledContent("Monday, Sep 21", value: "72.4 kg") }
                    LabeledContent("Thursday, Sep 17", value: "72.6 kg")
                    LabeledContent("Monday, Sep 14", value: "72.5 kg")
                }
            }.navigationTitle("Weight history")

        }
    }
}
private struct RoutineReminderEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State var title: String
    @State var time: Date
    let editing: Bool
    let save: (String, Date) -> Void

    var body: some View {
        Form {
            TextField("Reminder", text: $title)
            DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute)
        }
        .navigationTitle(editing ? "Edit reminder" : "Add reminder")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save reminder") {
                    save(title.trimmingCharacters(in: .whitespacesAndNewlines), time)
                    dismiss()
                }.disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .tint(.accentColor)
            }
        }
    }
}
#endif
