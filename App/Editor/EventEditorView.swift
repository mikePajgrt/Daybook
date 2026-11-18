import DaybookCore
import SwiftUI

/// The event editor: a native form on the world's colours (rows on the ground, set in the rail).
/// A failed save shows the error and keeps every field; Cancel with changes asks first.
struct EventEditorView: View {
    @Environment(AppModel.self) private var model
    @Environment(CategoryModel.self) private var categoryModel
    @Bindable var editor: EventEditorModel
    /// Closes the sheet.
    let onClose: () -> Void

    @State private var asksDiscard = false
    @State private var asksSpan = false
    /// Saving was started by "Pozvat účastníky": open the system editor after it.
    @State private var invitesAfterSave = false
    #if os(iOS)
    @State private var invite: InviteRequest?
    #endif
    @State private var inviteUnavailable = false
    /// Pages pushed inside the editor (the categories page).
    @State private var path: [EditorPage] = []

    enum EditorPage: Hashable { case categories }

    private var problems: [DraftProblem] { editor.problems }

    var body: some View {
        NavigationStack(path: $path) {
            form
                .navigationDestination(for: EditorPage.self) { _ in
                    EventCategoriesPage(editor: editor)
                }
                .navigationTitle(editor.isNew ? "Nová událost" : "Upravit událost")
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Zrušit", action: cancel)
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(editor.isNew ? "Přidat" : "Uložit") { startSave(inviting: false) }
                            .disabled(!problems.isEmpty || (!editor.isNew && !editor.hasChanges))
                    }
                }
        }
        .interactiveDismissDisabled(editor.hasChanges)
        .confirmationDialog("Zahodit změny?", isPresented: $asksDiscard, titleVisibility: .visible) {
            Button("Zahodit změny", role: .destructive, action: onClose)
            Button("Pokračovat v úpravách", role: .cancel) {}
        } message: {
            Text(editor.isNew ? "Nová událost se neuloží." : "Úpravy této události se neuloží.")
        }
        .confirmationDialog("Uložit změny opakované události", isPresented: $asksSpan, titleVisibility: .visible) {
            if editor.spanChoices.contains(.thisEvent) {
                Button("Uložit jen pro tuto událost") { save(span: .thisEvent) }
            }
            Button("Uložit pro tuto a všechny budoucí") { save(span: .futureEvents) }
            Button("Pokračovat v úpravách", role: .cancel) { invitesAfterSave = false }
        } message: {
            Text(editor.spanChoices.contains(.thisEvent)
                 ? "Událost se opakuje. Vyberte, kterých výskytů se změny týkají."
                 : "Změněné opakování platí od této události dál.")
        }
        .alert("Událost se nepodařilo uložit",
               isPresented: Binding(get: { editor.errorMessage != nil }, set: { if !$0 { editor.errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(editor.errorMessage ?? "")
        }
        .alert(EventText.inviteUnavailableTitle, isPresented: $inviteUnavailable) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(EventText.inviteUnavailableMessage(isDemo: !model.canOpenSystemEditor))
        }
        #if os(iOS)
        .sheet(item: $invite) { request in
            SystemEventEditor(store: request.store, event: request.event) {
                invite = nil
                model.reload()
                onClose()
            }
            .ignoresSafeArea()
        }
        #endif
        .task {
            #if DEBUG
            if !model.stagedScreens.isDisjoint(with: ["editor-categories", "occurrence-categories"]) {
                try? await Task.sleep(for: .milliseconds(700))
                path = [.categories]
            }
            if model.stagedScreens.contains("discard") {
                try? await Task.sleep(for: .milliseconds(700))
                editor.draft.title += " a priority"
                cancel()
            }
            if model.stagedScreens.contains("invite") {
                try? await Task.sleep(for: .milliseconds(700))
                startSave(inviting: true)
            }
            #endif
        }
        #if os(macOS)
        .frame(minWidth: 460, idealWidth: 500, minHeight: 560, idealHeight: 680)
        #endif
    }

    // MARK: Form

    private var form: some View {
        Form {
            Section {
                TextField("Název", text: $editor.draft.title, prompt: Text("Bez názvu").foregroundStyle(Theme.secondaryInk))
                    .font(.title3.weight(.semibold))
                TextField("Místo", text: $editor.draft.location, prompt: Text("Místo").foregroundStyle(Theme.secondaryInk))
            }
            .listRowBackground(Theme.ground)

            Section {
                Picker("Kalendář", selection: $editor.draft.calendarID) {
                    ForEach(writableCalendars) { calendar in
                        CalendarLabel(calendar: calendar).tag(calendar.id)
                    }
                }
                NavigationLink(value: EditorPage.categories) {
                    LabeledContent("Kategorie") {
                        Text(categorySummary)
                            .foregroundStyle(Theme.ink)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
            .listRowBackground(Theme.ground)

            Section {
                Toggle("Celý den", isOn: $editor.isAllDay)
                    .switchTint()
                DatePicker("Začátek", selection: $editor.start, displayedComponents: dateComponents)
                DatePicker("Konec", selection: $editor.draft.end, in: editor.draft.start...,
                           displayedComponents: dateComponents)
                if !editor.isAllDay {
                    Picker("Časové pásmo", selection: $editor.timeZoneID) {
                        ForEach(editor.timeZoneChoices, id: \.self) { id in
                            Text(TimeZone(identifier: id).map(EventText.zoneName) ?? id).tag(id)
                        }
                    }
                }
            } footer: {
                problemText(.endBeforeStart)
            }
            .environment(\.timeZone, editor.displayCalendar.timeZone)
            .environment(\.calendar, editor.displayCalendar)
            .listRowBackground(Theme.ground)

            Section {
                Picker("Opakování", selection: recurrenceFrequency) {
                    Text("Nikdy").tag(RecurrenceFrequency?.none)
                    ForEach(RecurrenceFrequency.allCases, id: \.self) { frequency in
                        Text(EventText.every(frequency, interval: interval(for: frequency)))
                            .tag(RecurrenceFrequency?.some(frequency))
                    }
                }
                if editor.draft.recurrence != nil {
                    Toggle("Konec opakování", isOn: recurrenceHasEnd)
                        .switchTint()
                    if let end = editor.draft.recurrence?.end {
                        DatePicker("Opakovat do", selection: Binding(get: { end }, set: { setRecurrenceEnd($0) }),
                                   in: model.calendar.startOfDay(for: editor.draft.start)...,
                                   displayedComponents: .date)
                    }
                }
                Picker("Upozornění", selection: $editor.draft.alert) {
                    Text("Žádné").tag(AlertOffset?.none)
                    ForEach(alertChoices, id: \.self) { offset in
                        Text(EventText.alert(offset)).tag(AlertOffset?.some(offset))
                    }
                }
            } footer: {
                problemText(.recurrenceEndsBeforeStart)
            }
            .listRowBackground(Theme.ground)

            Section {
                TextField("URL", text: $editor.draft.url, prompt: Text("Odkaz, třeba example.com").foregroundStyle(Theme.secondaryInk))
                    #if os(iOS)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    #endif
                    .autocorrectionDisabled()
                TextField("Poznámka", text: $editor.draft.notes, prompt: Text("Poznámka").foregroundStyle(Theme.secondaryInk), axis: .vertical)
                    .lineLimit(3...8)
            } footer: {
                problemText(.invalidURL)
            }
            .listRowBackground(Theme.ground)

            attendeeSection
        }
        .formStyle(.grouped)
        // Picker values and switches in the world's ink instead of system grey and green.
        .themeTint(Theme.controlInk)
        .scrollContentBackground(.hidden)
        .background(Theme.rail)
        .themeForeground(Theme.ink)
    }

    @ViewBuilder private var attendeeSection: some View {
        let attendees = editor.original?.attendees ?? []
        Section {
            ForEach(Array(attendees.enumerated()), id: \.offset) { _, person in
                AttendeeRow(attendee: person)
            }
            #if os(iOS)
            Button("Pozvat účastníky", systemImage: "person.badge.plus") { startSave(inviting: true) }
                .disabled(!problems.isEmpty)
            #endif
        } header: {
            Text("Účastníci")
        } footer: {
            #if os(iOS)
            Text("Událost se nejdřív uloží, pak se otevře systémový editor, ve kterém pozvete lidi.")
            #else
            Text("Pozvánky se posílají z aplikace Kalendář nebo z Outlooku.")
            #endif
        }
        .listRowBackground(Theme.ground)
    }

    @ViewBuilder private func problemText(_ problem: DraftProblem) -> some View {
        if problems.contains(problem) {
            Label(EventText.problem(problem), systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
        }
    }

    // MARK: Choices

    /// "Porady, Soustředěná práce", or "Žádné".
    private var categorySummary: String {
        let ids = editor.categorySelection.all
        let names = categoryModel.categories.filter { ids.contains($0.id) }.map(\.name)
        return names.isEmpty ? String(localized: "Žádné") : names.formatted(.list(type: .and))
    }

    private var dateComponents: DatePickerComponents {
        editor.isAllDay ? .date : [.date, .hourAndMinute]
    }

    /// Writable calendars; the event's own calendar stays listed even if it is no longer writable,
    /// so the picker never shows an empty selection.
    private var writableCalendars: [CalendarInfo] {
        var result = model.writableCalendars
        if !result.contains(where: { $0.id == editor.draft.calendarID }),
           let current = model.calendarInfo(editor.draft.calendarID) {
            result.insert(current, at: 0)
        }
        return result
    }

    private var alertChoices: [AlertOffset] {
        var result = AlertOffset.presets
        if let current = editor.draft.alert, !result.contains(current) { result.append(current) }
        return result.sorted { $0.minutesBefore < $1.minutesBefore }
    }

    /// The interval a frequency is offered with: the event's own when it already repeats that often.
    private func interval(for frequency: RecurrenceFrequency) -> Int {
        editor.draft.recurrence?.frequency == frequency ? editor.draft.recurrence?.interval ?? 1 : 1
    }

    private var recurrenceFrequency: Binding<RecurrenceFrequency?> {
        Binding(get: { editor.draft.recurrence?.frequency }, set: { frequency in
            guard let frequency else { editor.draft.recurrence = nil; return }
            editor.draft.recurrence = RecurrenceRule(frequency: frequency, interval: interval(for: frequency),
                                                     end: editor.draft.recurrence?.end)
        })
    }

    private var recurrenceHasEnd: Binding<Bool> {
        Binding(get: { editor.draft.recurrence?.end != nil }, set: { on in
            guard var rule = editor.draft.recurrence else { return }
            rule.end = on ? model.calendar.date(byAdding: .month, value: 1, to: model.calendar.startOfDay(for: editor.draft.start)) : nil
            editor.draft.recurrence = rule
        })
    }

    private func setRecurrenceEnd(_ date: Date) {
        guard var rule = editor.draft.recurrence else { return }
        rule.end = model.calendar.startOfDay(for: date)
        editor.draft.recurrence = rule
    }

    // MARK: Actions

    private func cancel() {
        if editor.hasChanges { asksDiscard = true } else { onClose() }
    }

    private func startSave(inviting: Bool) {
        invitesAfterSave = inviting
        #if os(iOS)
        if inviting && !model.canOpenSystemEditor {
            inviteUnavailable = true
            invitesAfterSave = false
            return
        }
        #endif
        if inviting && !editor.isNew && !editor.hasChanges {
            openInvite(for: editor.original)
            return
        }
        if editor.spanChoices.isEmpty {
            save(span: .thisEvent)
        } else {
            asksSpan = true
        }
    }

    private func save(span: EditSpan) {
        guard let saved = model.save(editor, span: span) else {
            invitesAfterSave = false
            return
        }
        if invitesAfterSave {
            invitesAfterSave = false
            openInvite(for: saved)
        } else {
            onClose()
        }
    }

    private func openInvite(for event: EventInfo?) {
        #if os(iOS)
        guard let event, let context = model.systemEditorContext(for: event) else {
            inviteUnavailable = true
            return
        }
        invite = InviteRequest(store: context.store, event: context.event)
        #endif
    }
}
