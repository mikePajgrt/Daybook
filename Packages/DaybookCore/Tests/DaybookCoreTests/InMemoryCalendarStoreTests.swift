import Foundation
import Testing
@testable import DaybookCore

@Suite struct InMemoryCalendarStoreTests {
    let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    func event(_ id: String, cal: String, from: TimeInterval, to: TimeInterval) -> EventInfo {
        EventInfo(key: EventKey(externalID: id, occurrenceStart: t0.addingTimeInterval(from)),
                  calendarID: cal, title: id,
                  start: t0.addingTimeInterval(from), end: t0.addingTimeInterval(to), isAllDay: false)
    }

    func makeStore() -> InMemoryCalendarStore {
        let work = CalendarInfo(id: "work", title: "Práce", color: RGBA(r: 0, g: 0, b: 1),
                                sourceTitle: "Exchange", sourceKind: .exchange)
        let home = CalendarInfo(id: "home", title: "Osobní", color: RGBA(r: 1, g: 0, b: 0),
                                sourceTitle: "iCloud", sourceKind: .icloud)
        return InMemoryCalendarStore(calendars: [work, home], events: [
            event("before", cal: "work", from: -7200, to: -3600),
            event("overlapsStart", cal: "work", from: -600, to: 600),
            event("inside", cal: "home", from: 1000, to: 2000),
            event("after", cal: "work", from: 7200, to: 9000)
        ])
    }

    @Test func returnsEventsOverlappingTheInterval() {
        let store = makeStore()
        let found = store.events(in: DateInterval(start: t0, duration: 3600),
                                 calendarIDs: ["work", "home"])
        #expect(found.map(\.title) == ["overlapsStart", "inside"])
    }

    @Test func returnsOnlyRequestedCalendars() {
        let store = makeStore()
        let found = store.events(in: DateInterval(start: t0, duration: 3600), calendarIDs: ["home"])
        #expect(found.map(\.title) == ["inside"])
    }

    @Test func eventEndingExactlyAtIntervalStartIsExcluded() {
        let store = makeStore()
        let found = store.events(in: DateInterval(start: t0.addingTimeInterval(-3600), duration: 60),
                                 calendarIDs: ["work"])
        #expect(found.isEmpty)
    }

    @Test func accessStartsGrantedAndCanBeConfigured() async {
        #expect(makeStore().access == .granted)
        let locked = InMemoryCalendarStore(calendars: [], events: [], access: .notDetermined)
        #expect(locked.access == .notDetermined)
        #expect(await locked.requestAccess() == .granted)
        #expect(locked.access == .granted)
    }

    @Test func replacingEventsEmitsAChange() async {
        let store = makeStore()
        var iterator = store.changes.makeAsyncIterator()
        store.replaceEvents([])
        let signal: Void? = await iterator.next()
        #expect(signal != nil)
        #expect(store.events(in: DateInterval(start: t0, duration: 3600), calendarIDs: ["work", "home"]).isEmpty)
    }
}
