//
//  ReminderQuickSetupSheet.swift
//  Trai
//
//  Shared chat-style composer for creating and editing reminders.
//

import SwiftUI
import SwiftData

enum ReminderPresetKind: Hashable {
    case breakfast
    case lunch
    case dinner
    case workout
    case weighIn
    case water
    case vitamins
    case stretch
    case mealPrep
    case sleepWindDown
}

struct ReminderComposerSeed: Identifiable {
    enum Kind {
        case blank
        case preset(ReminderPresetKind)
        case custom(CustomReminder)
    }

    let id = UUID()
    let kind: Kind

    static var blank: ReminderComposerSeed {
        ReminderComposerSeed(kind: .blank)
    }

    static func preset(_ kind: ReminderPresetKind) -> ReminderComposerSeed {
        ReminderComposerSeed(kind: .preset(kind))
    }

    static func custom(_ reminder: CustomReminder) -> ReminderComposerSeed {
        ReminderComposerSeed(kind: .custom(reminder))
    }
}

struct ReminderQuickSetupSheet: View {
    @Bindable var profile: UserProfile
    let notificationService: NotificationService?
    var seed: ReminderComposerSeed? = nil
    var onSaved: (() -> Void)?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(MonetizationService.self) private var monetizationService: MonetizationService?
    @Environment(ProUpsellCoordinator.self) private var proUpsellCoordinator: ProUpsellCoordinator?
    @FocusState private var isInputFocused: Bool

    @State private var aiService = AIService()
    @State private var promptText = ""
    @State private var draft: ReminderSetupDraft?
    @State private var editingCustomReminder: CustomReminder?
    @State private var messages: [ReminderComposerMessage] = [.assistant(Self.defaultIntroMessage)]
    @State private var saveErrorMessage: String?
    @State private var isGeneratingReminder = false
    @State private var hasStartedReminderChat = false
    @State private var suggestedReminder: SuggestedReminder?
    @State private var didApplySeed = false

    private let presetKinds: [ReminderPresetKind] = [
        .breakfast,
        .lunch,
        .dinner,
        .workout,
        .weighIn,
        .water,
        .vitamins,
        .stretch,
        .mealPrep,
        .sleepWindDown
    ]

    private var navigationTitle: String {
        editingCustomReminder == nil ? "Reminders" : "Edit Reminder"
    }

    private var canAccessReminderAI: Bool {
        monetizationService?.canAccessAIFeatures ?? true
    }

    private var initialIntroMessage: String {
        canAccessReminderAI ? Self.defaultIntroMessage : Self.manualIntroMessage
    }

    private static let defaultIntroMessage = "Tell Trai what you want to remember, or start from a preset. I’ll make a draft first so you can choose the exact day and time before anything is saved."
    private static let manualIntroMessage = "Choose a preset below and set the exact day and time before anything is saved."

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if canAccessReminderAI || editingCustomReminder != nil {
                            ForEach(messages) { message in
                                messageView(message)
                            }
                        }

                        if !canAccessReminderAI, editingCustomReminder == nil {
                            manualUpsellCard
                        } else if isGeneratingReminder {
                            ThinkingIndicator(activity: "Creating reminder...")
                                .id("generating")
                        }

                        if let suggestedReminder {
                            reminderSuggestionCard(suggestedReminder)
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                                .id("suggestedReminder")
                        }

                        if draft == nil, suggestedReminder == nil, !isGeneratingReminder, !hasStartedReminderChat {
                            presetSection
                        }

                        if let draft {
                            draftEditor(draft)
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                                .id("draft")
                        }

                        Color.clear
                            .frame(height: 8)
                            .id("bottom")
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 18)
                    .padding(.bottom, 10)
                }
                .scrollDismissesKeyboard(.interactively)
                .safeAreaInset(edge: .bottom) {
                    if canAccessReminderAI, editingCustomReminder == nil {
                        SimpleChatInputBar(
                            text: $promptText,
                            placeholder: "Remind me to stretch at 9pm",
                            isLoading: isGeneratingReminder,
                            onSend: submitReminderPrompt,
                            isFocused: $isInputFocused
                        )
                    }
                }
                .background(alignment: .bottom) {
                    if canAccessReminderAI, editingCustomReminder == nil {
                        TraiChatInputBackdrop()
                    }
                }
                .onChange(of: messages.count) { _, _ in scrollToBottom(proxy) }
                .onChange(of: draft) { _, _ in scrollToBottom(proxy) }
                .onChange(of: suggestedReminder != nil) { _, _ in scrollToBottom(proxy) }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark") {
                        dismiss()
                    }
                    .labelStyle(.iconOnly)
                }
            }
            .animation(.snappy(duration: 0.22), value: draft)
            .alert("Reminder Not Saved", isPresented: Binding(
                get: { saveErrorMessage != nil },
                set: { if !$0 { saveErrorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(saveErrorMessage ?? "Please try again.")
            }
            .onAppear(perform: applySeedIfNeeded)
        }
        .traiSheetBranding()
        .proUpsellPresenter()
    }

    @ViewBuilder
    private func messageView(_ message: ReminderComposerMessage) -> some View {
        switch message.kind {
        case .assistant:
            TraiAssistantTextMessage(text: message.text)
        case .user:
            HStack {
                Spacer(minLength: 42)
                TraiUserTextBubble(text: message.text)
            }
        }
    }

    private var presetSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if canAccessReminderAI {
                TraiAssistantTextMessage(
                    text: "Presets",
                    font: .subheadline.weight(.semibold)
                )
            } else {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Presets")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)

                    Text(Self.manualIntroMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 10),
                    GridItem(.flexible(), spacing: 10)
                ],
                spacing: 10
            ) {
                ForEach(presetKinds, id: \.self) { kind in
                    presetCard(ReminderQuickPreset(kind: kind))
                }
            }
        }
    }

    private func presetCard(_ preset: ReminderQuickPreset) -> some View {
        Button {
            startDraft(from: preset)
        } label: {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: preset.iconName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 30, height: 30)
                    .background(Color.accentColor.opacity(0.12), in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(preset.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(preset.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 66, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var manualUpsellCard: some View {
        ProUpsellInlineCard(
            source: .reminders,
            systemImage: "bell.badge.fill",
            actionTitle: "Unlock Trai Pro",
            showsShadow: false
        ) {
            proUpsellCoordinator?.present(source: .reminders)
        }
    }

    private func reminderSuggestionCard(_ suggestion: SuggestedReminder) -> some View {
        ReminderDraftCard(
            suggestion: suggestion,
            onEdit: { editSuggestedReminder(suggestion) },
            onConfirm: { saveSuggestedReminder(suggestion) },
            onDismiss: { suggestedReminder = nil }
        )
    }

    private func draftEditor(_ draft: ReminderSetupDraft) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: draft.iconName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 32, height: 32)
                    .background(Color.accentColor.opacity(0.12), in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(editingCustomReminder == nil ? "Review reminder" : "Edit reminder")
                        .font(.headline)
                    Text("Choose the title, time, and repeat days before Trai saves it.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            TextField("Title", text: draftTitleBinding)
                .textInputAutocapitalization(.sentences)
                .padding(12)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            if draft.kind.isCustom {
                TextField("Note", text: draftBodyBinding, axis: .vertical)
                    .textInputAutocapitalization(.sentences)
                    .lineLimit(2...4)
                    .padding(12)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            DatePicker(
                "Time",
                selection: draftTimeBinding,
                displayedComponents: .hourAndMinute
            )

            if draft.kind.allowsRepeatDayEditing {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Repeat")
                        .font(.subheadline.weight(.semibold))
                    dayButtons
                    Text(repeatDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 10) {
                Button {
                    cancelDraft()
                } label: {
                    Text("Cancel")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.traiSecondary(fullWidth: true))

                Button {
                    saveDraft()
                } label: {
                    Label(saveButtonTitle, systemImage: "checkmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.traiPrimary(fullWidth: true))
                .disabled(draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(14)
        .traiCard(cornerRadius: 16)
    }

    private var dayButtons: some View {
        HStack(spacing: 8) {
            ForEach(Array(zip([1, 2, 3, 4, 5, 6, 7], ["S", "M", "T", "W", "T", "F", "S"])), id: \.0) { day, label in
                Button {
                    guard var draft else { return }
                    if draft.kind.usesSingleRepeatDay {
                        draft.repeatDays = [day]
                    } else if draft.repeatDays.contains(day) {
                        draft.repeatDays.remove(day)
                    } else {
                        draft.repeatDays.insert(day)
                    }
                    self.draft = draft
                    HapticManager.lightTap()
                } label: {
                    Text(label)
                        .font(.caption.weight(.bold))
                        .frame(width: 34, height: 34)
                        .background((draft?.repeatDays.contains(day) == true) ? Color.accentColor : Color(.tertiarySystemFill))
                        .foregroundStyle((draft?.repeatDays.contains(day) == true) ? .white : .primary)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var draftTitleBinding: Binding<String> {
        Binding(
            get: { draft?.title ?? "" },
            set: { newValue in
                guard var draft else { return }
                draft.title = newValue
                self.draft = draft
            }
        )
    }

    private var draftBodyBinding: Binding<String> {
        Binding(
            get: { draft?.body ?? "" },
            set: { newValue in
                guard var draft else { return }
                draft.body = newValue
                self.draft = draft
            }
        )
    }

    private var draftTimeBinding: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(
                    from: DateComponents(hour: draft?.hour ?? 9, minute: draft?.minute ?? 0)
                ) ?? Date()
            },
            set: { newDate in
                let components = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                guard var draft else { return }
                draft.hour = components.hour ?? draft.hour
                draft.minute = roundedMinute(components.minute ?? draft.minute)
                self.draft = draft
            }
        )
    }

    private var repeatDescription: String {
        guard let draft else { return "" }
        if draft.repeatDays.isEmpty || draft.repeatDays.count == 7 {
            return "Every day"
        }
        if draft.repeatDays == Set([2, 3, 4, 5, 6]) {
            return "Weekdays"
        }
        if draft.repeatDays == Set([1, 7]) {
            return "Weekends"
        }
        let dayNames = ["", "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        return draft.repeatDays.sorted().compactMap { dayNames[safe: $0] }.joined(separator: ", ")
    }

    private var saveButtonTitle: String {
        editingCustomReminder == nil ? "Save" : "Update"
    }

    private func applySeedIfNeeded() {
        guard !didApplySeed else { return }
        didApplySeed = true

        guard let seed else {
            messages = [.assistant(initialIntroMessage)]
            return
        }
        switch seed.kind {
        case .blank:
            messages = [.assistant(initialIntroMessage)]
            break
        case .preset(let kind):
            let preset = ReminderQuickPreset(kind: kind)
            messages = [.assistant(canAccessReminderAI ? Self.defaultIntroMessage : Self.manualIntroMessage)]
            startDraft(from: preset, appendingMessage: false)
        case .custom(let reminder):
            editingCustomReminder = reminder
            draft = ReminderSetupDraft(reminder: reminder)
            messages = [
                .assistant("Adjust the title, time, or repeat days, then save the changes.")
            ]
        }
    }

    private func startDraft(from preset: ReminderQuickPreset, appendingMessage: Bool = false) {
        editingCustomReminder = nil
        suggestedReminder = nil
        draft = ReminderSetupDraft(preset: preset, profile: profile)
        if appendingMessage {
            messages.append(.assistant("I started a \(preset.title.lowercased()) draft. Pick the time and repeat days before saving."))
        }
        HapticManager.lightTap()
    }

    private func submitReminderPrompt() {
        submitReminderPrompt(promptText)
    }

    private func submitReminderPrompt(_ prompt: String, appendingUserMessage: Bool = true) {
        let trimmed = promptText.trimmingCharacters(in: .whitespacesAndNewlines)
        let promptTrimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let outgoingText = promptTrimmed.isEmpty ? trimmed : promptTrimmed
        guard !outgoingText.isEmpty, !isGeneratingReminder else { return }

        guard canAccessReminderAI else {
            proUpsellCoordinator?.present(source: .chat)
            return
        }

        if appendingUserMessage {
            messages.append(.user(outgoingText))
        }
        editingCustomReminder = nil
        draft = nil
        suggestedReminder = nil
        hasStartedReminderChat = true
        promptText = ""
        HapticManager.lightTap()

        Task {
            await generateReminderSuggestion(from: outgoingText)
        }
    }

    private func generateReminderSuggestion(from userText: String) async {
        isGeneratingReminder = true
        defer { isGeneratingReminder = false }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEEE, MMMM d, yyyy 'at' h:mm a"

        let previousMessages = Array(messages.dropLast(
            messages.last?.kind.isUser == true && messages.last?.text == userText ? 1 : 0
        ))

        let historyString = previousMessages.suffix(8)
            .map { ($0.kind.isUser ? "User" : "Trai") + ": " + $0.text }
            .joined(separator: "\n")

        let reminderContext = """
        The user is creating a reminder inside Trai's reminder setup sheet.
        Only help with reminders.
        Infer a reasonable clock time from natural time language when the user's intent gives enough signal; the user can edit it before saving.
        If the request has a clear title and either an explicit or reasonably inferable time, call create_reminder so the app can show a confirmation card.
        Do not require an explicit repeat cadence; leave repeat_days empty for an everyday reminder unless the user names specific days.
        Ask one concise follow-up question only when there is not enough signal to choose a reasonable time.
        Do not say the reminder has been saved; the app will ask for confirmation first.
        """

        let context = AIService.ChatFunctionContext(
            profile: profile,
            todaysFoodEntries: [],
            currentDateTime: dateFormatter.string(from: Date()),
            conversationHistory: historyString,
            memoriesContext: "",
            coachContext: reminderContext
        )

        let conversation = previousMessages.suffix(8).map {
            ChatMessage(content: $0.text, isFromUser: $0.kind.isUser)
        }

        do {
            let result = try await aiService.chatWithFunctions(
                message: userText,
                imageData: nil,
                context: context,
                conversationHistory: conversation,
                modelContext: modelContext
            )

            if let suggestion = result.suggestedReminder {
                suggestedReminder = suggestion
                messages.append(.assistant("I drafted this reminder. Review it before saving."))
            } else {
                let response = result.message.trimmingCharacters(in: .whitespacesAndNewlines)
                messages.append(.assistant(response.isEmpty ? "What time should I use for that reminder?" : response))
            }
        } catch {
            messages.append(.assistant(error.aiUserFacingMessage(fallback: "I couldn’t draft that reminder right now. You can still use the manual presets below.")))
            HapticManager.error()
        }
    }

    private func cancelDraft() {
        draft = nil
        editingCustomReminder = nil
        suggestedReminder = nil
        promptText = ""
        hasStartedReminderChat = false
        messages = [.assistant(initialIntroMessage)]
    }

    private func saveDraft() {
        guard let draft else { return }
        switch draft.kind {
        case .meal(let mealID):
            saveMealReminder(mealID: mealID, draft: draft)
        case .workout:
            saveWorkoutReminder(draft)
        case .weighIn:
            saveWeightReminder(draft)
        case .custom:
            saveCustomReminder(draft)
        }
    }

    private func saveMealReminder(mealID: String, draft: ReminderSetupDraft) {
        var enabledMeals = Set(profile.enabledMealReminders.split(separator: ",").map(String.init))
        enabledMeals.remove(mealID)
        profile.enabledMealReminders = enabledMeals.sorted().joined(separator: ",")
        if enabledMeals.isEmpty {
            profile.mealRemindersEnabled = false
        }

        let body: String
        switch mealID {
        case MealReminderTime.breakfast.id:
            body = "Log breakfast in Trai."
        case MealReminderTime.lunch.id:
            body = "Log lunch in Trai."
        case MealReminderTime.dinner.id:
            body = "Log dinner in Trai."
        default:
            body = "Log this meal in Trai."
        }

        let customDraft = ReminderSetupDraft(
            kind: .custom,
            title: draft.title,
            body: draft.body.isEmpty ? body : draft.body,
            iconName: draft.iconName,
            hour: draft.hour,
            minute: draft.minute,
            repeatDays: draft.repeatDays
        )
        saveCustomReminder(customDraft, shouldSyncBuiltIns: true)
    }

    private func saveWorkoutReminder(_ draft: ReminderSetupDraft) {
        profile.workoutRemindersEnabled = true
        profile.workoutReminderHour = draft.hour
        profile.workoutReminderMinute = draft.minute
        let days = draft.repeatDays.isEmpty ? defaultWorkoutDays() : draft.repeatDays.sorted().map(String.init).joined(separator: ",")
        profile.workoutReminderDays = days
        saveProfileAndScheduleBuiltIns()
    }

    private func saveWeightReminder(_ draft: ReminderSetupDraft) {
        profile.weightReminderEnabled = true
        profile.weightReminderHour = draft.hour
        profile.weightReminderWeekday = draft.repeatDays.sorted().first ?? profile.weightReminderWeekday
        saveProfileAndScheduleBuiltIns()
    }

    private func saveCustomReminder(_ draft: ReminderSetupDraft, shouldSyncBuiltIns: Bool = false) {
        let reminder: CustomReminder
        if let editingCustomReminder {
            reminder = editingCustomReminder
            reminder.title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
            reminder.body = draft.body.trimmingCharacters(in: .whitespacesAndNewlines)
            reminder.hour = draft.hour
            reminder.minute = draft.minute
            reminder.repeatDays = draft.repeatDays.sorted().map(String.init).joined(separator: ",")
            reminder.isEnabled = true
        } else {
            reminder = CustomReminder(
                title: draft.title.trimmingCharacters(in: .whitespacesAndNewlines),
                body: draft.body.trimmingCharacters(in: .whitespacesAndNewlines),
                hour: draft.hour,
                minute: draft.minute,
                repeatDays: draft.repeatDays.sorted().map(String.init).joined(separator: ","),
                isEnabled: true
            )
            modelContext.insert(reminder)
        }

        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            saveErrorMessage = "We couldn’t save this reminder. Please try again."
            HapticManager.error()
            return
        }

        completeSuccessfulSave(message: editingCustomReminder == nil ? "Saved. You can add another reminder here whenever you want." : "Updated.")

        Task {
            await ensureNotificationAuthorization()
            await notificationService?.scheduleCustomReminder(reminder)
            if shouldSyncBuiltIns {
                await syncBuiltInReminderSchedules()
            }
        }
    }

    private func saveSuggestedReminder(_ suggestion: SuggestedReminder) {
        let reminder = CustomReminder(
            title: suggestion.title.trimmingCharacters(in: .whitespacesAndNewlines),
            body: suggestion.body.trimmingCharacters(in: .whitespacesAndNewlines),
            hour: suggestion.hour,
            minute: suggestion.minute,
            repeatDays: suggestion.repeatDays,
            isEnabled: true
        )
        modelContext.insert(reminder)

        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            saveErrorMessage = "We couldn’t save this reminder. Please try again."
            HapticManager.error()
            return
        }

        suggestedReminder = nil
        completeSuccessfulSave(message: "Saved. You can add another reminder here whenever you want.")

        Task {
            await ensureNotificationAuthorization()
            await notificationService?.scheduleCustomReminder(reminder)
        }
    }

    private func editSuggestedReminder(_ suggestion: SuggestedReminder) {
        suggestedReminder = nil
        editingCustomReminder = nil
        draft = ReminderSetupDraft(suggestion: suggestion)
        HapticManager.lightTap()
    }

    private func saveProfileAndScheduleBuiltIns() {
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            saveErrorMessage = "We couldn’t save this reminder. Please try again."
            HapticManager.error()
            return
        }

        completeSuccessfulSave(message: editingCustomReminder == nil ? "Saved. You can add another reminder here whenever you want." : "Updated.")

        Task {
            await ensureNotificationAuthorization()
            await syncBuiltInReminderSchedules()
        }
    }

    private func completeSuccessfulSave(message: String) {
        HapticManager.lightTap()
        draft = nil
        editingCustomReminder = nil
        messages.append(.assistant(message))
        onSaved?()
    }

    private func defaultWorkoutDays() -> String {
        let daysPerWeek = profile.workoutPlan?.daysPerWeek ?? profile.preferredWorkoutDays
        switch daysPerWeek {
        case 1:
            return "2"
        case 2:
            return "2,5"
        case 4:
            return "2,3,5,6"
        case 5...:
            return "2,3,4,5,6"
        default:
            return "2,4,6"
        }
    }

    private func roundedMinute(_ minute: Int) -> Int {
        ((minute + 2) / 5) * 5 % 60
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(80))
            withAnimation(.easeOut(duration: 0.22)) {
                proxy.scrollTo("bottom", anchor: .bottom)
            }
        }
    }

    @MainActor
    private func ensureNotificationAuthorization() async {
        guard let notificationService else { return }
        await notificationService.updateAuthorizationStatus()
        if !notificationService.isAuthorized {
            _ = await notificationService.requestAuthorization()
        }
    }

    @MainActor
    private func syncBuiltInReminderSchedules() async {
        guard let notificationService else { return }
        let completedTodayReminderIDs = fetchCompletedReminderIDsForToday()
        await notificationService.updateAuthorizationStatus()
        guard notificationService.isAuthorized else {
            await notificationService.cancelNotifications(category: .mealReminder)
            await notificationService.cancelNotifications(category: .workoutReminder)
            await notificationService.cancelNotifications(category: .weightReminder)
            return
        }

        if profile.mealRemindersEnabled {
            let enabledMeals = Set(profile.enabledMealReminders.split(separator: ",").map(String.init))
            let mealTimes = MealReminderTime.allMeals.filter { enabledMeals.contains($0.id) }
            await notificationService.scheduleMealReminders(
                times: mealTimes,
                skippingTodayReminderIDs: completedTodayReminderIDs
            )
        } else {
            await notificationService.cancelNotifications(category: .mealReminder)
        }

        if profile.workoutRemindersEnabled {
            let workoutDays = Set(profile.workoutReminderDays.split(separator: ",").compactMap { Int($0) })
            await notificationService.scheduleWorkoutReminders(
                days: workoutDays.sorted(),
                hour: profile.workoutReminderHour,
                minute: profile.workoutReminderMinute,
                skippingTodayReminderIDs: completedTodayReminderIDs
            )
        } else {
            await notificationService.cancelNotifications(category: .workoutReminder)
        }

        if profile.weightReminderEnabled {
            await notificationService.scheduleWeightReminder(
                weekday: profile.weightReminderWeekday,
                hour: profile.weightReminderHour,
                minute: 0,
                skippingTodayReminderIDs: completedTodayReminderIDs
            )
        } else {
            await notificationService.cancelNotifications(category: .weightReminder)
        }
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
}

private struct ReminderComposerMessage: Identifiable, Equatable {
    enum Kind {
        case assistant
        case user

        var isUser: Bool {
            if case .user = self { return true }
            return false
        }
    }

    let id = UUID()
    let kind: Kind
    let text: String

    static func assistant(_ text: String) -> ReminderComposerMessage {
        ReminderComposerMessage(kind: .assistant, text: text)
    }

    static func user(_ text: String) -> ReminderComposerMessage {
        ReminderComposerMessage(kind: .user, text: text)
    }
}

private struct ReminderSetupDraft: Equatable {
    enum Kind: Equatable {
        case meal(String)
        case workout
        case weighIn
        case custom

        var isCustom: Bool {
            if case .custom = self { return true }
            return false
        }

        var allowsRepeatDayEditing: Bool {
            true
        }

        var usesSingleRepeatDay: Bool {
            if case .weighIn = self { return true }
            return false
        }
    }

    var kind: Kind
    var title: String
    var body: String
    var iconName: String
    var hour: Int
    var minute: Int
    var repeatDays: Set<Int>

    init(preset: ReminderQuickPreset, profile: UserProfile) {
        switch preset.kind {
        case .breakfast:
            kind = .meal(MealReminderTime.breakfast.id)
        case .lunch:
            kind = .meal(MealReminderTime.lunch.id)
        case .dinner:
            kind = .meal(MealReminderTime.dinner.id)
        case .workout:
            kind = .workout
        case .weighIn:
            kind = .weighIn
        case .water, .vitamins, .stretch, .mealPrep, .sleepWindDown:
            kind = .custom
        }
        title = preset.title
        body = preset.body
        iconName = preset.iconName
        hour = preset.hour(profile: profile)
        minute = preset.minute
        repeatDays = preset.repeatDays(profile: profile)
    }

    init(reminder: CustomReminder) {
        kind = .custom
        title = reminder.title
        body = reminder.body
        iconName = "bell.badge"
        hour = reminder.hour
        minute = reminder.minute
        repeatDays = reminder.repeatDaysSet
    }

    init(suggestion: SuggestedReminder) {
        kind = .custom
        title = suggestion.title
        body = suggestion.body
        iconName = "bell.badge"
        hour = suggestion.hour
        minute = suggestion.minute
        repeatDays = Set(suggestion.repeatDays.split(separator: ",").compactMap { Int($0) })
    }

    init(kind: Kind, title: String, body: String, iconName: String, hour: Int, minute: Int, repeatDays: Set<Int>) {
        self.kind = kind
        self.title = title
        self.body = body
        self.iconName = iconName
        self.hour = hour
        self.minute = minute
        self.repeatDays = repeatDays
    }
}

private struct ReminderQuickPreset {
    let kind: ReminderPresetKind

    var title: String {
        switch kind {
        case .breakfast: "Breakfast"
        case .lunch: "Lunch"
        case .dinner: "Dinner"
        case .workout: "Workout days"
        case .weighIn: "Weekly weigh-in"
        case .water: "Drink water"
        case .vitamins: "Take vitamins"
        case .stretch: "Stretch"
        case .mealPrep: "Meal prep"
        case .sleepWindDown: "Sleep wind-down"
        }
    }

    var subtitle: String {
        switch kind {
        case .breakfast: "Meal logging"
        case .lunch: "Meal logging"
        case .dinner: "Meal logging"
        case .workout: "Use your plan rhythm"
        case .weighIn: "One morning weekly"
        case .water: "Daily hydration"
        case .vitamins: "Daily routine"
        case .stretch: "Evening reset"
        case .mealPrep: "Weekly planning"
        case .sleepWindDown: "Night routine"
        }
    }

    var iconName: String {
        switch kind {
        case .breakfast, .lunch, .dinner: "fork.knife"
        case .workout: "figure.strengthtraining.traditional"
        case .weighIn: "scalemass.fill"
        case .water: "drop.fill"
        case .vitamins: "pills.fill"
        case .stretch: "figure.flexibility"
        case .mealPrep: "calendar.badge.clock"
        case .sleepWindDown: "moon.fill"
        }
    }

    var body: String {
        switch kind {
        case .water: "Take a quick water break."
        case .vitamins: "A small routine anchor for the day."
        case .stretch: "A short reset is enough."
        case .mealPrep: "Plan meals before the week gets busy."
        case .sleepWindDown: "Start winding down for the night."
        default: ""
        }
    }

    func hour(profile: UserProfile) -> Int {
        switch kind {
        case .breakfast: MealReminderTime.breakfast.hour
        case .lunch: MealReminderTime.lunch.hour
        case .dinner: MealReminderTime.dinner.hour
        case .workout: profile.workoutReminderHour
        case .weighIn: profile.weightReminderHour
        case .water: 10
        case .vitamins: 8
        case .stretch: 21
        case .mealPrep: 17
        case .sleepWindDown: 22
        }
    }

    var minute: Int {
        switch kind {
        case .breakfast: MealReminderTime.breakfast.minute
        case .lunch: MealReminderTime.lunch.minute
        case .dinner: MealReminderTime.dinner.minute
        default: 0
        }
    }

    func repeatDays(profile: UserProfile) -> Set<Int> {
        switch kind {
        case .workout:
            return Set(profile.workoutReminderDays.split(separator: ",").compactMap { Int($0) })
        case .weighIn:
            return [profile.weightReminderWeekday]
        case .mealPrep:
            return [1]
        default:
            return []
        }
    }

}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

#Preview {
    ReminderQuickSetupSheet(
        profile: UserProfile(),
        notificationService: nil,
        seed: .blank
    )
    .modelContainer(for: [UserProfile.self, CustomReminder.self], inMemory: true)
}
