import DaybookCore
import Foundation
#if os(iOS)
import EventKit
#endif

/// Writes, and opening the editors. Every write reloads at once; the store's change stream reloads
/// again, but `reload()` assigns only what changed, so the second pass draws nothing.
extension AppModel {
    // MARK: Calendars that take events

    /// Calendars new events can go to, in the sidebar's order.
    var writableCalendars: [CalendarInfo] {
        sections.flatMap(\.calendars).filter { !$0.isReadOnly }
    }

    /// The day a new event goes to: the day on screen in the day view; today when the week or month
    /// on screen holds it; otherwise the first day on screen.
    var focusedDay: Date {
        if mode == .day { return calendar.startOfDay(for: focusedDate) }
        if let loadedInterval {
            if loadedInterval.start <= today && today < loadedInterval.end { return today }
            if mode == .month, let monthStart = calendar.dateInterval(of: .month, for: focusedDate)?.start {
                return monthStart
            }
            return calendar.startOfDay(for: loadedInterval.start)
        }
        return today
    }

    private var preferredCalendarID: String? {
        EventDraft.preferredCalendarID(writable: writableCalendars,
                                       lastUsed: defaults.string(forKey: Self.lastCalendarKey),
                                       systemDefault: store.defaultCalendarID())
    }

    // MARK: Opening the editor

    /// A new event on the focused day at the next full hour.
    func beginNewEvent() { beginNewEvent(onDay: focusedDay) }

    /// A new event on `day` at the next full hour.
    func beginNewEvent(onDay day: Date) {
        guard let calendarID = preferredCalendarID else { return explainNoWritableCalendar() }
        editorInDaySheet = false
        let draft = EventDraft.newEvent(on: day, now: now(Date()), calendarID: calendarID,
                                        calendar: calendar)
        editor = EventEditorModel(draft: draft, original: nil, calendar: calendar)
    }

    /// A new one-hour event at `start` (a time-grid slot).
    func beginNewEvent(at start: Date) {
        guard let calendarID = preferredCalendarID else { return explainNoWritableCalendar() }
        editorInDaySheet = false
        editor = EventEditorModel(draft: EventDraft.newEvent(at: start, calendarID: calendarID, calendar: calendar),
                                  original: nil, calendar: calendar)
    }

    func beginEditing(_ event: EventInfo, inDaySheet: Bool = false) {
        guard event.isEditable else { return }
        editorInDaySheet = inDaySheet
        editor = EventEditorModel(draft: EventDraft(event: event, calendar: calendar), original: event,
                                  calendar: calendar, categories: categoryModel.selection(for: event.key))
    }

    private func explainNoWritableCalendar() {
        notice = Notice(title: String(localized: "Událost není kam uložit"),
                        message: String(localized: "Všechny kalendáře v zařízení jsou jen pro čtení. Založte si kalendář volbou Nový kalendář, nebo přidejte účet v Nastavení."))
    }

    // MARK: Event writes

    /// Saves the editor's draft. Returns the saved event, or `nil` after putting the error text
    /// into the editor, which keeps its data.
    @discardableResult
    func save(_ editor: EventEditorModel, span: EditSpan = .thisEvent) -> EventInfo? {
        do {
            let saved: EventInfo
            if let original = editor.original, !editor.draftChanged {
                // Only the categories changed: the event itself is not written.
                saved = original
            } else if let original = editor.original {
                let updated = try store.updateEvent(original, with: editor.draft, span: span)
                let start = editor.draft.isAllDay ? calendar.startOfDay(for: editor.draft.start) : editor.draft.start
                let key: EventKey
                if updated.externalID != original.key.externalID {
                    // "This and future events" split the series: the new series keeps the old one's categories.
                    key = updated
                    do {
                        try categoryModel.store.carryOver(from: original.key.externalID, to: updated.externalID,
                                                          splitAt: original.key.occurrenceStart)
                        categoryModel.reload()
                    } catch {
                        notice = Notice(title: String(localized: "Kategorie se nepřenesly"),
                                        message: String(localized: "Událost se uložila, ale nová část opakování nemá kategorie původní série. \(CategoryText.message(for: error))"))
                    }
                } else {
                    key = original.isRecurring && editor.draft.recurrence == original.recurrence
                        ? original.key : EventKey(externalID: original.key.externalID, occurrenceStart: start)
                }
                saved = editor.draft.makeEvent(key: key, calendar: calendar, attendees: original.attendees)
            } else {
                saved = try store.createEvent(editor.draft)
            }
            defaults.set(editor.draft.calendarID, forKey: Self.lastCalendarKey)
            editor.didSave(as: saved)
            if editor.categoriesChanged {
                // Categories are Daybook's own data, written after the event so a new event has its key.
                if let problem = categoryModel.apply(editor.categorySelection, from: editor.savedCategorySelection,
                                                     to: saved.key) {
                    editor.errorMessage = String(localized: "Událost se uložila, ale kategorie ne. \(problem)")
                    reload()
                    return nil
                }
                editor.didSaveCategories()
            }
            reload()
            return saved
        } catch {
            editor.errorMessage = EventText.saveMessage(for: error)
            return nil
        }
    }

    /// Deletes an event. Returns the error text when it failed, `nil` when it worked.
    func deleteReportingError(_ event: EventInfo, span: EditSpan) -> String? {
        do {
            try store.deleteEvent(event, span: span)
            reload()
            return nil
        } catch {
            return EventText.message(for: error)
        }
    }

    // MARK: Calendars

    func beginNewCalendar() {
        let all = store.sources()
        calendarEditor = CalendarEditorModel(mode: .new, sources: all.filter(\.offersCalendarCreation),
                                             hasGoogle: all.contains { $0.kind == .google })
    }

    func beginRecoloring(_ calendarInfo: CalendarInfo) {
        calendarEditor = CalendarEditorModel(mode: .recolor(calendarInfo), sources: [], hasGoogle: false)
    }

    /// Creates the calendar or applies the colour. Returns whether it worked; on failure the error
    /// text goes into the sheet, which stays open.
    @discardableResult
    func save(_ editor: CalendarEditorModel) -> Bool {
        do {
            switch editor.mode {
            case .new: try store.createCalendar(editor.draft)
            case .recolor(let calendarInfo): try store.setColor(editor.color, ofCalendar: calendarInfo.id)
            }
            reload()
            return true
        } catch {
            editor.errorMessage = EventText.message(for: error)
            return false
        }
    }

    // MARK: System invitation editor

    /// Whether the system event editor can be opened: only over the real calendar database on iOS.
    var canOpenSystemEditor: Bool {
        #if os(iOS)
        return store is EventKitCalendarStore
        #else
        return false
        #endif
    }

    #if os(iOS)
    /// The store and the system event behind `event`, for `EKEventEditViewController`.
    func systemEditorContext(for event: EventInfo) -> (store: EKEventStore, event: EKEvent)? {
        guard let system = store as? EventKitCalendarStore, let ekEvent = system.systemEvent(for: event) else {
            return nil
        }
        return (system.eventStore, ekEvent)
    }
    #endif
}
