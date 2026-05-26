//
//  ReminderSettingsView.swift
//  Trai
//
//  Management view for reminder notification settings.
//

import SwiftUI
import SwiftData

struct ReminderSettingsView: View {
    @Bindable var profile: UserProfile
    @Environment(\.modelContext) private var modelContext

    @State private var notificationService: NotificationService?
    @State private var composerSeed: ReminderComposerSeed?
    @State private var customReminders: [CustomReminder] = []
    @State private var selectedHabitReminder: CustomReminder?
    @State private var reminderSaveErrorMessage: String?

    private var enabledMealIDs: Set<String> {
        Set(profile.enabledMealReminders.split(separator: ",").map(String.init))
    }

    private var hasAnyReminder: Bool {
        profile.mealRemindersEnabled && !enabledMealIDs.isEmpty
            || profile.workoutRemindersEnabled
            || profile.weightReminderEnabled
            || !customReminders.isEmpty
    }

    var body: some View {
        content
            .traiBackground()
            .navigationTitle("Reminders")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $composerSeed) { seed in
                reminderComposer(seed)
            }
            .navigationDestination(item: $selectedHabitReminder) { reminder in
                ReminderHabitView(reminder: reminder)
            }
            .alert("Reminder Not Updated", isPresented: Binding(
                get: { reminderSaveErrorMessage != nil },
                set: { if !$0 { reminderSaveErrorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(reminderSaveErrorMessage ?? "Please try again.")
            }
            .onAppear {
                if notificationService == nil {
                    notificationService = NotificationService()
                }
                Task {
                    await notificationService?.updateAuthorizationStatus()
                    await syncBuiltInReminderSchedules()
                }
                fetchCustomReminders()
            }
            .onChange(of: profile.mealRemindersEnabled) { _, _ in
                Task { await syncBuiltInReminderSchedules() }
            }
            .onChange(of: profile.enabledMealReminders) { _, _ in
                Task { await syncBuiltInReminderSchedules() }
            }
            .onChange(of: profile.workoutRemindersEnabled) { _, _ in
                Task { await syncBuiltInReminderSchedules() }
            }
            .onChange(of: profile.workoutReminderDays) { _, _ in
                Task { await syncBuiltInReminderSchedules() }
            }
            .onChange(of: profile.workoutReminderHour) { _, _ in
                Task { await syncBuiltInReminderSchedules() }
            }
            .onChange(of: profile.workoutReminderMinute) { _, _ in
                Task { await syncBuiltInReminderSchedules() }
            }
            .onChange(of: profile.weightReminderEnabled) { _, _ in
                Task { await syncBuiltInReminderSchedules() }
            }
            .onChange(of: profile.weightReminderWeekday) { _, _ in
                Task { await syncBuiltInReminderSchedules() }
            }
            .onChange(of: profile.weightReminderHour) { _, _ in
                Task { await syncBuiltInReminderSchedules() }
            }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let service = notificationService, !service.isAuthorized {
                    notificationPermissionCard(service)
                }

                createReminderCTA
                remindersCard
            }
            .padding()
        }
    }

    private func reminderComposer(_ seed: ReminderComposerSeed) -> some View {
        ReminderQuickSetupSheet(
            profile: profile,
            notificationService: notificationService,
            seed: seed,
            onSaved: {
                fetchCustomReminders()
                Task { await syncBuiltInReminderSchedules() }
            }
        )
    }

    private func notificationPermissionCard(_ service: NotificationService) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "bell.badge")
                    .font(.headline)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 36, height: 36)
                    .background(Color.accentColor.opacity(0.12), in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text("Notifications are off")
                        .font(.subheadline.weight(.semibold))
                    Text("Allow notifications before reminders can reach you.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Button {
                Task {
                    let granted = await service.requestAuthorization()
                    if granted {
                        await syncBuiltInReminderSchedules()
                    }
                }
            } label: {
                Label("Enable Notifications", systemImage: "bell.badge")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.traiPrimary(fullWidth: true))
        }
        .padding(16)
        .traiCard(cornerRadius: 18)
    }

    private var createReminderCTA: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.accentColor, Color.accentColor.opacity(0.72)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    Image(systemName: "bell.badge.fill")
                        .font(.title3)
                        .foregroundStyle(.white)
                }
                .frame(width: 52, height: 52)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Create a reminder")
                        .font(.traiHeadline(17))
                        .foregroundStyle(.primary)

                    Text("Tell Trai what to remember or start from a preset.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            Button("Create Reminder", systemImage: "plus", action: { composerSeed = .blank })
                .buttonStyle(.traiPrimary(fullWidth: true))
        }
        .padding(16)
        .traiCard(cornerRadius: 20, contentPadding: 0)
    }

    private var remindersCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !hasAnyReminder {
                VStack(alignment: .leading, spacing: 4) {
                    Text("No reminders yet")
                        .font(.subheadline.weight(.semibold))
                    Text("Create one above when you want Trai to help you stay consistent.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
            } else {
                VStack(spacing: 0) {
                    if profile.mealRemindersEnabled {
                        ForEach(MealReminderTime.allMeals.filter { enabledMealIDs.contains($0.id) }) { meal in
                            builtInReminderRow(
                                title: meal.displayName,
                                subtitle: "\(formatTime(hour: meal.hour, minute: meal.minute)) · Meal logging",
                                iconName: "fork.knife",
                                isOn: mealBinding(for: meal.id),
                                seed: .preset(presetKind(for: meal.id))
                            )
                        }
                    }

                    if profile.workoutRemindersEnabled {
                        builtInReminderRow(
                            title: "Workout days",
                            subtitle: "\(formatTime(hour: profile.workoutReminderHour, minute: profile.workoutReminderMinute)) · \(workoutDaysDescription)",
                            iconName: "figure.strengthtraining.traditional",
                            isOn: $profile.workoutRemindersEnabled,
                            seed: .preset(.workout)
                        )
                    }

                    if profile.weightReminderEnabled {
                        builtInReminderRow(
                            title: "Weekly weigh-in",
                            subtitle: "\(formatTime(hour: profile.weightReminderHour, minute: 0)) · \(weekdayName(profile.weightReminderWeekday))",
                            iconName: "scalemass.fill",
                            isOn: $profile.weightReminderEnabled,
                            seed: .preset(.weighIn)
                        )
                    }

                    ForEach(customReminders) { reminder in
                        customReminderRow(reminder)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
            }
        }
        .traiCard(cornerRadius: 18)
    }

    private func builtInReminderRow(
        title: String,
        subtitle: String,
        iconName: String,
        isOn: Binding<Bool>,
        seed: ReminderComposerSeed
    ) -> some View {
        HStack(spacing: 12) {
            Button {
                composerSeed = seed
            } label: {
                reminderLabel(title: title, subtitle: subtitle, iconName: iconName, isEnabled: isOn.wrappedValue)
            }
            .buttonStyle(.plain)

            Toggle("", isOn: isOn)
                .labelsHidden()
        }
        .padding(.vertical, 10)
    }

    private func customReminderRow(_ reminder: CustomReminder) -> some View {
        HStack(spacing: 12) {
            Button {
                composerSeed = .custom(reminder)
            } label: {
                reminderLabel(
                    title: reminder.title,
                    subtitle: "\(reminder.formattedTime) · \(reminder.scheduleDescription)",
                    iconName: "bell.badge",
                    isEnabled: reminder.isEnabled
                )
            }
            .buttonStyle(.plain)

            Toggle("", isOn: Binding(
                get: { reminder.isEnabled },
                set: { updateCustomReminder(reminder, isEnabled: $0) }
            ))
            .labelsHidden()

            Menu {
                Button {
                    selectedHabitReminder = reminder
                } label: {
                    Label("History", systemImage: "chart.bar.xaxis")
                }

                Button {
                    composerSeed = .custom(reminder)
                } label: {
                    Label("Edit", systemImage: "pencil")
                }

                Button(role: .destructive) {
                    deleteReminder(reminder)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Reminder actions")
        }
        .padding(.vertical, 10)
    }

    private func reminderLabel(title: String, subtitle: String, iconName: String, isEnabled: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isEnabled ? Color.accentColor : .secondary)
                .frame(width: 34, height: 34)
                .background((isEnabled ? Color.accentColor : Color.secondary).opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isEnabled ? .primary : .secondary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .contentShape(Rectangle())
    }

    private var workoutDaysDescription: String {
        let days = Set(profile.workoutReminderDays.split(separator: ",").compactMap { Int($0) })
        return repeatDescription(days)
    }

    private func mealBinding(for mealId: String) -> Binding<Bool> {
        Binding(
            get: {
                profile.mealRemindersEnabled && enabledMealIDs.contains(mealId)
            },
            set: { isEnabled in
                var meals = enabledMealIDs
                if isEnabled {
                    meals.insert(mealId)
                } else {
                    meals.remove(mealId)
                }
                profile.enabledMealReminders = meals.sorted().joined(separator: ",")
                profile.mealRemindersEnabled = !meals.isEmpty
            }
        )
    }

    private func presetKind(for mealId: String) -> ReminderPresetKind {
        switch mealId {
        case MealReminderTime.breakfast.id:
            return .breakfast
        case MealReminderTime.lunch.id:
            return .lunch
        default:
            return .dinner
        }
    }

    private func weekdayName(_ weekday: Int) -> String {
        let days = ["", "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        return days[safe: weekday] ?? "Weekly"
    }

    private func repeatDescription(_ days: Set<Int>) -> String {
        if days.isEmpty || days.count == 7 {
            return "Every day"
        }
        if days == Set([2, 3, 4, 5, 6]) {
            return "Weekdays"
        }
        if days == Set([1, 7]) {
            return "Weekends"
        }
        let shortDays = ["", "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        return days.sorted().compactMap { shortDays[safe: $0] }.joined(separator: ", ")
    }

    private func formatTime(hour: Int, minute: Int) -> String {
        let components = DateComponents(hour: hour, minute: minute)
        guard let date = Calendar.current.date(from: components) else {
            return "\(hour):\(String(format: "%02d", minute))"
        }
        return date.formatted(date: .omitted, time: .shortened)
    }

    private func updateCustomReminder(_ reminder: CustomReminder, isEnabled: Bool) {
        reminder.isEnabled = isEnabled
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            reminderSaveErrorMessage = "We couldn’t update this reminder. Please try again."
            HapticManager.error()
            return
        }

        Task {
            if isEnabled {
                await notificationService?.scheduleCustomReminder(reminder)
            } else {
                await notificationService?.cancelCustomReminder(id: reminder.id)
            }
        }
    }

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
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            reminderSaveErrorMessage = "We couldn’t delete this reminder. Please try again."
            HapticManager.error()
            fetchCustomReminders()
            return
        }
        if selectedHabitReminder?.id == reminder.id {
            selectedHabitReminder = nil
        }
        fetchCustomReminders()
        HapticManager.lightTap()
    }

    private func fetchCompletedReminderIDsForToday() -> Set<UUID> {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        let descriptor = FetchDescriptor<ReminderCompletion>(
            predicate: #Predicate { completion in
                completion.completedAt >= startOfDay
            }
        )
        let completions = (try? modelContext.fetch(descriptor)) ?? []
        return Set(completions.map(\.reminderId))
    }

    @MainActor
    private func syncBuiltInReminderSchedules() async {
        guard let service = notificationService else { return }
        let completedTodayReminderIDs = fetchCompletedReminderIDsForToday()
        await service.updateAuthorizationStatus()
        guard service.isAuthorized else {
            await service.cancelNotifications(category: .mealReminder)
            await service.cancelNotifications(category: .workoutReminder)
            await service.cancelNotifications(category: .weightReminder)
            return
        }

        if profile.mealRemindersEnabled {
            let mealTimes = MealReminderTime.allMeals.filter { enabledMealIDs.contains($0.id) }
            await service.scheduleMealReminders(
                times: mealTimes,
                skippingTodayReminderIDs: completedTodayReminderIDs
            )
        } else {
            await service.cancelNotifications(category: .mealReminder)
        }

        if profile.workoutRemindersEnabled {
            let workoutDays = Set(profile.workoutReminderDays.split(separator: ",").compactMap { Int($0) })
            await service.scheduleWorkoutReminders(
                days: workoutDays.sorted(),
                hour: profile.workoutReminderHour,
                minute: profile.workoutReminderMinute,
                skippingTodayReminderIDs: completedTodayReminderIDs
            )
        } else {
            await service.cancelNotifications(category: .workoutReminder)
        }

        if profile.weightReminderEnabled {
            await service.scheduleWeightReminder(
                weekday: profile.weightReminderWeekday,
                hour: profile.weightReminderHour,
                minute: 0,
                skippingTodayReminderIDs: completedTodayReminderIDs
            )
        } else {
            await service.cancelNotifications(category: .weightReminder)
        }
    }

}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

#Preview {
    NavigationStack {
        ReminderSettingsView(profile: UserProfile())
    }
    .modelContainer(for: [UserProfile.self, CustomReminder.self], inMemory: true)
}
