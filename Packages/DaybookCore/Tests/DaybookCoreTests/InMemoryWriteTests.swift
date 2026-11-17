import Foundation
import Testing
@testable import DaybookCore

/// Shared fixtures for write tests: a writable and a read-only calendar, three sources.
enum WriteFixture {
    static let cal = TestCalendar.prague()

    static func d(_ y: Int, _ m: Int, _ day: Int, _ h: Int = 0, _ min: Int = 0) -> Date {
        TestCalendar.date(y, m, day, h, min, in: cal)
    }

    static let calendars = [
        CalendarInfo(id: "work", title: "Práce", color: RGBA(r: 0, g: 0, b: 1), sourceTitle: "Exchange", sourceKind: .exchange),
        CalendarInfo(id: "home", title: "Osobní", color: RGBA(r: 1, g: 0, b: 0), sourceTitle: "iCloud", sourceKind: .icloud),
        CalendarInfo(id: "holidays", title: "Svátky", color: RGBA(r: 0.5, g: 0.5, b: 0.5), sourceTitle: "iCloud",
                     sourceKind: .subscribed, isReadOnly: true)
    ]

    static let sources = [
        SourceInfo(id: "src-icloud", title: "iCloud", kind: .icloud),
        SourceInfo(id: "src-exchange", title: "Exchange", kind: .exchange),
        SourceInfo(id: "src-google", title: "Google", kind: .google)
    ]

    static func store(events: [EventInfo] = []) -> InMemoryCalendarStore {
        InMemoryCalendarStore(calendars: calendars, events: events, sources: sources,
                              defaultCalendarID: "work", calendar: cal)
    }

    static let all: Set<String> = ["work", "home", "holidays"]

    static func november(_ store: InMemoryCalendarStore) -> [EventInfo] {
        store.events(in: DateInterval(start: d(2026, 11, 1), end: d(2026, 12, 1)), calendarIDs: all)
    }

    static func draft(_ title: String, calendarID: String = "work", day: Int = 17, hour: Int = 10) -> EventDraft {
        EventDraft(title: title, calendarID: calendarID, start: d(2026, 11, day, hour), end: d(2026, 11, day, hour + 1),
                   timeZoneID: "Europe/Prague")
    }
}

@Suite struct InMemoryWriteTests {
    typealias F = WriteFixture

    @Test func createdEventIsFoundInItsInterval() throws {
        let store = F.store()
        let created = try store.createEvent(F.draft("Návrh API"))
        #expect(created.title == "Návrh API" && created.start == F.d(2026, 11, 17, 10))
        #expect(F.november(store).map(\.title) == ["Návrh API"])
        #expect(F.november(store).first?.key == created.key)
    }

    @Test func createdAllDayEventEndsBeforeTheNextMidnight() throws {
        let store = F.store()
        var draft = F.draft("Lisabon", calendarID: "home")
        draft.setAllDay(true, calendar: F.cal)
        draft.end = F.d(2026, 11, 19)
        let created = try store.createEvent(draft)
        #expect(created.isAllDay && created.start == F.d(2026, 11, 17))
        #expect(created.end == F.d(2026, 11, 20).addingTimeInterval(-1))
    }

    @Test func createIsRefusedForReadOnlyMissingCalendarsAndInvalidDrafts() {
        let store = F.store()
        #expect(throws: CalendarStoreError.calendarReadOnly) { try store.createEvent(F.draft("x", calendarID: "holidays")) }
        #expect(throws: CalendarStoreError.calendarNotFound) { try store.createEvent(F.draft("x", calendarID: "gone")) }
        var bad = F.draft("x")
        bad.end = F.d(2026, 11, 17, 9)
        #expect(throws: CalendarStoreError.invalidDraft([.endBeforeStart])) { try store.createEvent(bad) }
        #expect(F.november(store).isEmpty)
    }

    @Test func updateChangesFieldsAndCalendar() throws {
        let store = F.store()
        let created = try store.createEvent(F.draft("Návrh"))
        var draft = EventDraft(event: created, calendar: F.cal)
        draft.title = "Návrh API"
        draft.calendarID = "home"
        draft.setStart(F.d(2026, 11, 18, 14), calendar: F.cal)
        try store.updateEvent(created, with: draft, span: .thisEvent)
        let found = F.november(store)
        #expect(found.count == 1)
        #expect(found[0].title == "Návrh API" && found[0].calendarID == "home")
        #expect(found[0].start == F.d(2026, 11, 18, 14) && found[0].end == F.d(2026, 11, 18, 15))
        #expect(found[0].key.externalID == created.key.externalID)
    }

    @Test func updateOfAnUnknownEventIsRefused() {
        let store = F.store()
        let ghost = F.draft("x").makeEvent(key: EventKey(externalID: "ghost", occurrenceStart: F.d(2026, 11, 17, 10)),
                                           calendar: F.cal)
        #expect(throws: CalendarStoreError.eventNotFound) { try store.updateEvent(ghost, with: F.draft("y"), span: .thisEvent) }
        #expect(throws: CalendarStoreError.eventNotFound) { try store.deleteEvent(ghost, span: .thisEvent) }
    }

    @Test func eventsInReadOnlyCalendarsAreNotEditable() throws {
        let holiday = F.draft("Svátek", calendarID: "holidays")
            .makeEvent(key: EventKey(externalID: "h", occurrenceStart: F.d(2026, 11, 17, 10)), calendar: F.cal)
        let store = F.store(events: [holiday])
        let found = F.november(store)
        #expect(found.count == 1 && !found[0].isEditable)
        #expect(throws: CalendarStoreError.calendarReadOnly) { try store.deleteEvent(found[0], span: .thisEvent) }
        #expect(throws: CalendarStoreError.calendarReadOnly) {
            try store.updateEvent(found[0], with: F.draft("x"), span: .thisEvent)
        }
    }

    @Test func deleteRemovesTheEvent() throws {
        let store = F.store()
        let a = try store.createEvent(F.draft("A"))
        _ = try store.createEvent(F.draft("B", hour: 12))
        try store.deleteEvent(a, span: .thisEvent)
        #expect(F.november(store).map(\.title) == ["B"])
    }

    @Test func eachWriteEmitsOneChange() async throws {
        let store = F.store()
        var iterator = store.changes.makeAsyncIterator()
        let created = try store.createEvent(F.draft("A"))
        #expect(await iterator.next() != nil)
        try store.deleteEvent(created, span: .thisEvent)
        #expect(await iterator.next() != nil)
        try store.setColor(RGBA(r: 0, g: 1, b: 0), ofCalendar: "work")
        #expect(await iterator.next() != nil)
    }

    @Test func calendarsAreCreatedOnlyWhereSourcesAllowIt() throws {
        let store = F.store()
        let created = try store.createCalendar(CalendarDraft(title: " Výlety ", color: Palette.calendarPresets[3],
                                                             sourceID: "src-icloud"))
        #expect(created.title == "Výlety" && created.sourceKind == .icloud && created.sourceTitle == "iCloud")
        #expect(!created.isReadOnly)
        #expect(store.calendars().contains { $0.id == created.id })
        #expect(throws: CalendarStoreError.sourceDoesNotAllowCalendars) {
            try store.createCalendar(CalendarDraft(title: "G", color: Palette.calendarPresets[0], sourceID: "src-google"))
        }
        #expect(throws: CalendarStoreError.sourceNotFound) {
            try store.createCalendar(CalendarDraft(title: "G", color: Palette.calendarPresets[0], sourceID: "nope"))
        }
        #expect(throws: CalendarStoreError.invalidCalendar([.emptyName])) {
            try store.createCalendar(CalendarDraft(title: "", color: Palette.calendarPresets[0], sourceID: "src-icloud"))
        }
    }

    @Test func colourChangesOnWritableCalendarsOnly() throws {
        let store = F.store()
        try store.setColor(Palette.calendarPresets[1], ofCalendar: "home")
        #expect(store.calendars().first { $0.id == "home" }?.color == Palette.calendarPresets[1])
        #expect(throws: CalendarStoreError.calendarReadOnly) { try store.setColor(Palette.calendarPresets[1], ofCalendar: "holidays") }
        #expect(throws: CalendarStoreError.calendarNotFound) { try store.setColor(Palette.calendarPresets[1], ofCalendar: "gone") }
    }

    @Test func sourcesAndDefaultCalendarAreReported() {
        let store = F.store()
        #expect(store.sources().map(\.id) == ["src-icloud", "src-exchange", "src-google"])
        #expect(store.defaultCalendarID() == "work")
    }
}
