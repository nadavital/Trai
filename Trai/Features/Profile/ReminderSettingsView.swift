//
//  ReminderSettingsView.swift
//  Trai
//
//  Settings view for configuring meal, workout, and weight reminders.
//

import SwiftUI
import SwiftData

struct ReminderSettingsView: View {
    @Bindable var profile: UserProfile
    @Environment(\.modelContext) private var modelContext

    @State private var notificationService: NotificationService?
    @State private var showAddReminderSheet = false
    @State private var customReminders: [CustomReminder] = []

    var body: some View {
        Form {
            // Authorization section
            if let service = notificationService, !service.isAuthorized {
                Section {
                    Button {
                        Task {
                            _ = await service.requestAuthorization()
                        }
                    } label: {
                        Label("Enable Notifications", systemImage: "bell.badge")
                    }
                } footer: {
                    Text("Allow notifications to receive reminders.")
                }
            }

            // Meal Reminders
            Section("Meals") {
                Toggle("Meal Reminders", isOn: $profile.mealRemindersEnabled)

                if profile.mealRemindersEnabled {
                    ForEach(MealReminderTime.allMeals) { meal in
                        Toggle(meal.displayName, isOn: mealBinding(for: meal.id))
                    }
                }
            }

            // Workout Reminders
            Section("Workouts") {
                Toggle("Workout Reminders", isOn: $profile.workoutRemindersEnabled)

                if profile.workoutRemindersEnabled {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Reminder Days")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 8) {
                            ForEach(Array(zip([1, 2, 3, 4, 5, 6, 7], ["S", "M", "T", "W", "T", "F", "S"])), id: \.0) { day, label in
                                dayButton(day: day, label: label)
                            }
                        }
                    }

                    DatePicker(
                        "Reminder Time",
                        selection: workoutTimeBinding,
                        displayedComponents: .hourAndMinute
                    )
                }
            }

            // Weight Reminder
            Section("Weight Tracking") {
                Toggle("Weekly Weight Check", isOn: $profile.weightReminderEnabled)

                if profile.weightReminderEnabled {
                    Picker("Day", selection: $profile.weightReminderWeekday) {
                        Text("Sunday").tag(1)
                        Text("Monday").tag(2)
                        Text("Tuesday").tag(3)
                        Text("Wednesday").tag(4)
                        Text("Thursday").tag(5)
                        Text("Friday").tag(6)
                        Text("Saturday").tag(7)
                    }

                    DatePicker(
                        "Time",
                        selection: weightTimeBinding,
                        displayedComponents: .hourAndMinute
                    )
                }
            }

            // Custom Reminders
            Section {
                ForEach(customReminders) { reminder in
                    NavigationLink {
                        ReminderHabitView(reminder: reminder)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(reminder.title)
                                    .font(.body)
                                    .foregroundStyle(reminder.isEnabled ? .primary : .secondary)

                                HStack(spacing: 4) {
                                    Text(reminder.formattedTime)
                                    Text("•")
                                    Text(reminder.scheduleDescription)
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if !reminder.isEnabled {
                                Text("Off")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            deleteReminder(reminder)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }

                Button {
                    showAddReminderSheet = true
                } label: {
                    Label("Add Reminder", systemImage: "plus")
                }
            } header: {
                Text("Custom Reminders")
            } footer: {
                if customReminders.isEmpty {
                    Text("Create custom reminders for anything you want to track.")
                }
            }
        }
        .navigationTitle("Reminders")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAddReminderSheet) {
            CustomReminderSheet(notificationService: notificationService)
        }
        .onAppear {
            // Lazily create NotificationService on appear
            if notificationService == nil {
                notificationService = NotificationService()
            }
            Task {
                await notificationService?.updateAuthorizationStatus()
            }
            // Fetch custom reminders
            fetchCustomReminders()
        }
        .onChange(of: showAddReminderSheet) { _, isShowing in
            if !isShowing { fetchCustomReminders() }
        }
    }

    // MARK: - Bindings

    private func mealBinding(for mealId: String) -> Binding<Bool> {
        Binding(
            get: {
                profile.enabledMealReminders.contains(mealId)
            },
            set: { isEnabled in
                var meals = Set(profile.enabledMealReminders.split(separator: ",").map(String.init))
                if isEnabled {
                    meals.insert(mealId)
                } else {
                    meals.remove(mealId)
                }
                profile.enabledMealReminders = meals.sorted().joined(separator: ",")
            }
        )
    }

    private var workoutDays: Set<Int> {
        Set(profile.workoutReminderDays.split(separator: ",").compactMap { Int($0) })
    }

    private func dayButton(day: Int, label: String) -> some View {
        Button {
            var days = workoutDays
            if days.contains(day) {
                days.remove(day)
            } else {
                days.insert(day)
            }
            profile.workoutReminderDays = days.sorted().map(String.init).joined(separator: ",")
        } label: {
            Text(label)
                .font(.caption)
                .bold()
                .frame(width: 32, height: 32)
                .background(workoutDays.contains(day) ? Color.accentColor : Color(.tertiarySystemFill))
                .foregroundStyle(workoutDays.contains(day) ? .white : .primary)
                .clipShape(.circle)
        }
        .buttonStyle(.plain)
    }

    private var workoutTimeBinding: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(
                    from: DateComponents(hour: profile.workoutReminderHour, minute: profile.workoutReminderMinute)
                ) ?? Date()
            },
            set: { newDate in
                let components = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                profile.workoutReminderHour = components.hour ?? 17
                profile.workoutReminderMinute = components.minute ?? 0
            }
        )
    }

    private var weightTimeBinding: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(
                    from: DateComponents(hour: profile.weightReminderHour, minute: 0)
                ) ?? Date()
            },
            set: { newDate in
                let components = Calendar.current.dateComponents([.hour], from: newDate)
                profile.weightReminderHour = components.hour ?? 8
            }
        )
    }

    // MARK: - Actions

    private func fetchCustomReminders() {
        let descriptor = FetchDescriptor<CustomReminder>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        customReminders = (try? modelContext.fetch(descriptor)) ?? []
    }

    private func deleteReminder(_ reminder: CustomReminder) {
        Task {
            await notificationService?.cancelCustomReminder(id: reminder.id)
        }
        modelContext.delete(reminder)
        fetchCustomReminders()
        HapticManager.lightTap()
    }
}

#Preview {
    NavigationStack {
        ReminderSettingsView(profile: UserProfile())
    }
}
