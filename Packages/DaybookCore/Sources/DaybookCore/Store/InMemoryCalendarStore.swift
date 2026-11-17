import Foundation

/// A `CalendarStore` backed by arrays. Used by tests and by the app's demo mode.
///
/// Recurring events are kept as series and expanded into occurrences when read: an occurrence
/// changed or deleted on its own becomes an exception of its series, and "this and future events"
/// ends the series the day before and starts a new one, the way the system does.
public final class InMemoryCalendarStore: CalendarStore {
    public private(set) var access: CalendarAccess
    private var storedCalendars: [CalendarInfo]
    private var singles: [EventInfo] = []
    private var series: [EventSeries] = []
    private let storedSources: [SourceInfo]
    private let systemDefaultCalendarID: String?
    private let calendar: Calendar
    private var nextID = 1
    private let continuation: AsyncStream<Void>.Continuation
    public let changes: AsyncStream<Void>

    /// Events with a `recurrence` are taken as the first occurrence of a series.
    public init(calendars: [CalendarInfo], events: [EventInfo], access: CalendarAccess = .granted,
                sources: [SourceInfo] = [], defaultCalendarID: String? = nil, calendar: Calendar = .current) {
        self.storedCalendars = calendars
        self.access = access
        self.storedSources = sources
        self.systemDefaultCalendarID = defaultCalendarID
        self.calendar = calendar
        let (stream, continuation) = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
        self.changes = stream
        self.continuation = continuation
        store(events)
    }

    private func store(_ events: [EventInfo]) {
        singles = events.filter { !$0.isRecurring }
        series = events.filter(\.isRecurring).map { EventSeries(template: $0) }
    }

    public func requestAccess() async -> CalendarAccess {
        if access == .notDetermined { access = .granted }
        return access
    }

    public func calendars() -> [CalendarInfo] { storedCalendars }

    public func events(in interval: DateInterval, calendarIDs: Set<String>) -> [EventInfo] {
        Self.read(interval, singles: singles, series: series, calendars: storedCalendars, calendar: calendar)
            .filter { calendarIDs.contains($0.calendarID) }
    }

    /// A copy of what the store holds now, readable from any thread.
    public func reader() -> EventReader {
        let singles = singles, series = series, calendars = storedCalendars, calendar = calendar
        return { interval in
            Self.read(interval, singles: singles, series: series, calendars: calendars, calendar: calendar)
        }
    }

    private static func read(_ interval: DateInterval, singles: [EventInfo], series: [EventSeries],
                             calendars: [CalendarInfo], calendar: Calendar) -> [EventInfo] {
        let readOnly = Set(calendars.filter(\.isReadOnly).map(\.id))
        let known = Set(calendars.map(\.id))
        let fromSingles = singles.filter {
            $0.start < interval.end && $0.end > interval.start
        }
        let fromSeries = series.flatMap { $0.occurrences(in: interval, calendar: calendar) }
        return (fromSingles + fromSeries)
            .filter { known.contains($0.calendarID) }
            .map { event in
                var event = event
                event.isEditable = !readOnly.contains(event.calendarID)
                return event
            }
            .sorted { ($0.start, $0.title) < ($1.start, $1.title) }
    }

    public func replaceEvents(_ events: [EventInfo]) {
        store(events)
        continuation.yield()
    }

    public func replaceCalendars(_ calendars: [CalendarInfo]) {
        storedCalendars = calendars
        continuation.yield()
    }

    // MARK: - Writing

    public func sources() -> [SourceInfo] { storedSources }

    public func defaultCalendarID() -> String? { systemDefaultCalendarID }

    @discardableResult
    public func createEvent(_ draft: EventDraft) throws -> EventInfo {
        try check(draft)
        let event = draft.makeEvent(key: EventKey(externalID: newID("event"), occurrenceStart: draftStart(draft)),
                                    calendar: calendar)
        insert(event)
        continuation.yield()
        return event
    }

    @discardableResult
    public func updateEvent(_ event: EventInfo, with draft: EventDraft, span: EditSpan) throws -> EventKey {
        try check(draft)
        let id = event.key.externalID
        var key = EventKey(externalID: id, occurrenceStart: draftStart(draft))
        if let index = singles.firstIndex(where: { $0.key.externalID == id }) {
            try checkWritable(singles[index].calendarID)
            let old = singles.remove(at: index)
            insert(made(draft, id: id, attendees: old.attendees))
        } else if let index = series.firstIndex(where: { $0.id == id }) {
            var item = series[index]
            try checkWritable(item.template.calendarID)
            let occurrence = event.key.occurrenceStart
            guard item.isOccurrence(occurrence, calendar: calendar) else { throw CalendarStoreError.eventNotFound }
            // A rule cannot change for one occurrence: that always applies from it onward.
            let effective: EditSpan = draft.recurrence == item.template.recurrence ? span : .futureEvents
            switch effective {
            case .thisEvent:
                var changed = draft.makeEvent(key: event.key, calendar: calendar, attendees: item.template.attendees)
                changed.recurrence = item.template.recurrence
                item.exceptions[occurrence] = .changed(changed)
                series[index] = item
                key = event.key
            case .futureEvents:
                if occurrence == item.template.start {
                    series.remove(at: index)
                    let replacement = made(draft, id: id, attendees: item.template.attendees)
                    if replacement.isRecurring {
                        // Exceptions stay attached only while the occurrences keep their starts.
                        var kept = EventSeries(template: replacement)
                        if replacement.start == item.template.start && replacement.recurrence == item.template.recurrence {
                            kept.exceptions = item.exceptions
                        }
                        series.append(kept)
                    } else {
                        singles.append(replacement)
                    }
                } else {
                    item.truncate(before: occurrence, calendar: calendar)
                    series[index] = item
                    let split = made(draft, id: newID("event"), attendees: item.template.attendees)
                    insert(split)
                    key = split.key
                }
            }
        } else {
            throw CalendarStoreError.eventNotFound
        }
        continuation.yield()
        return key
    }

    public func deleteEvent(_ event: EventInfo, span: EditSpan) throws {
        let id = event.key.externalID
        if let index = singles.firstIndex(where: { $0.key.externalID == id }) {
            try checkWritable(singles[index].calendarID)
            singles.remove(at: index)
        } else if let index = series.firstIndex(where: { $0.id == id }) {
            var item = series[index]
            try checkWritable(item.template.calendarID)
            let occurrence = event.key.occurrenceStart
            guard item.isOccurrence(occurrence, calendar: calendar) else { throw CalendarStoreError.eventNotFound }
            switch span {
            case .thisEvent:
                item.exceptions[occurrence] = .deleted
                series[index] = item
            case .futureEvents:
                if occurrence == item.template.start {
                    series.remove(at: index)
                } else {
                    item.truncate(before: occurrence, calendar: calendar)
                    series[index] = item
                }
            }
        } else {
            throw CalendarStoreError.eventNotFound
        }
        continuation.yield()
    }

    @discardableResult
    public func createCalendar(_ draft: CalendarDraft) throws -> CalendarInfo {
        let problems = draft.problems
        guard problems.isEmpty else { throw CalendarStoreError.invalidCalendar(problems) }
        guard let source = storedSources.first(where: { $0.id == draft.sourceID }) else {
            throw CalendarStoreError.sourceNotFound
        }
        guard source.offersCalendarCreation else { throw CalendarStoreError.sourceDoesNotAllowCalendars }
        let created = CalendarInfo(id: newID("calendar"),
                                   title: draft.title.trimmingCharacters(in: .whitespacesAndNewlines),
                                   color: draft.color, sourceTitle: source.title, sourceKind: source.kind)
        storedCalendars.append(created)
        continuation.yield()
        return created
    }

    public func setColor(_ color: RGBA, ofCalendar id: String) throws {
        guard let index = storedCalendars.firstIndex(where: { $0.id == id }) else {
            throw CalendarStoreError.calendarNotFound
        }
        // Models an account that refuses changes to calendars it does not let the user write.
        guard !storedCalendars[index].isReadOnly else { throw CalendarStoreError.calendarReadOnly }
        storedCalendars[index].color = color
        continuation.yield()
    }

    // MARK: - Helpers

    private func newID(_ kind: String) -> String {
        defer { nextID += 1 }
        return "memory-\(kind)-\(nextID)"
    }

    private func check(_ draft: EventDraft) throws {
        let problems = draft.problems(calendar: calendar)
        guard problems.isEmpty else { throw CalendarStoreError.invalidDraft(problems) }
        try checkWritable(draft.calendarID)
    }

    private func checkWritable(_ calendarID: String) throws {
        guard let target = storedCalendars.first(where: { $0.id == calendarID }) else {
            throw CalendarStoreError.calendarNotFound
        }
        guard !target.isReadOnly else { throw CalendarStoreError.calendarReadOnly }
    }

    private func draftStart(_ draft: EventDraft) -> Date {
        draft.isAllDay ? calendar.startOfDay(for: draft.start) : draft.start
    }

    private func made(_ draft: EventDraft, id: String, attendees: [Attendee]) -> EventInfo {
        draft.makeEvent(key: EventKey(externalID: id, occurrenceStart: draftStart(draft)),
                        calendar: calendar, attendees: attendees)
    }

    private func insert(_ event: EventInfo) {
        if event.isRecurring {
            series.append(EventSeries(template: event))
        } else {
            singles.append(event)
        }
    }
}
