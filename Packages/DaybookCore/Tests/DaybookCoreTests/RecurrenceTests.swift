import Foundation
import Testing
@testable import DaybookCore

@Suite struct RecurrenceTests {
    typealias F = WriteFixture

    /// "Plán" every Monday at 8:30 from 2 Nov 2026.
    func weekly(end: Date? = nil) throws -> (InMemoryCalendarStore, EventInfo) {
        let store = F.store()
        var draft = EventDraft(title: "Plán", calendarID: "work", start: F.d(2026, 11, 2, 8, 30),
                               end: F.d(2026, 11, 2, 9), timeZoneID: "Europe/Prague")
        draft.recurrence = RecurrenceRule(frequency: .weekly, end: end)
        let first = try store.createEvent(draft)
        return (store, first)
    }

    func occurrence(_ store: InMemoryCalendarStore, day: Int) -> EventInfo? {
        F.november(store).first { F.cal.component(.day, from: $0.start) == day }
    }

    @Test func weeklySeriesHasOneOccurrenceAWeek() throws {
        let (store, first) = try weekly()
        let found = F.november(store)
        #expect(found.map { F.cal.component(.day, from: $0.start) } == [2, 9, 16, 23, 30])
        #expect(found.allSatisfy { $0.key.externalID == first.key.externalID && $0.isRecurring })
        #expect(Set(found.map(\.key.occurrenceStart)).count == 5)
        #expect(found[2].start == F.d(2026, 11, 16, 8, 30) && found[2].end == F.d(2026, 11, 16, 9))
    }

    @Test func seriesStopsAfterItsEndDay() throws {
        let (store, _) = try weekly(end: F.d(2026, 11, 16))
        #expect(F.november(store).map { F.cal.component(.day, from: $0.start) } == [2, 9, 16])
    }

    @Test func monthlySeriesFromThe31stLandsOnShortMonthsLastDay() throws {
        let store = F.store()
        var draft = EventDraft(title: "Uzávěrka", calendarID: "work", start: F.d(2026, 1, 31, 9),
                               end: F.d(2026, 1, 31, 10), timeZoneID: "Europe/Prague")
        draft.recurrence = RecurrenceRule(frequency: .monthly)
        _ = try store.createEvent(draft)
        let found = store.events(in: DateInterval(start: F.d(2026, 1, 1), end: F.d(2026, 5, 1)), calendarIDs: F.all)
        #expect(found.map { F.cal.component(.day, from: $0.start) } == [31, 28, 31, 30])
    }

    @Test func onlyThisEventChangesOneOccurrence() throws {
        let (store, _) = try weekly()
        let third = try #require(occurrence(store, day: 16))
        var draft = EventDraft(event: third, calendar: F.cal)
        draft.title = "Plán s klientem"
        draft.setStart(F.d(2026, 11, 16, 10), calendar: F.cal)
        try store.updateEvent(third, with: draft, span: .thisEvent)
        let found = F.november(store)
        #expect(found.map(\.title) == ["Plán", "Plán", "Plán s klientem", "Plán", "Plán"])
        #expect(found[2].start == F.d(2026, 11, 16, 10) && found[2].key == third.key && found[2].isRecurring)
    }

    @Test func onlyThisEventDeletesOneOccurrence() throws {
        let (store, _) = try weekly()
        try store.deleteEvent(try #require(occurrence(store, day: 16)), span: .thisEvent)
        #expect(F.november(store).map { F.cal.component(.day, from: $0.start) } == [2, 9, 23, 30])
    }

    @Test func thisAndFutureFromALaterOccurrenceSplitsTheSeries() throws {
        let (store, first) = try weekly()
        let third = try #require(occurrence(store, day: 16))
        var draft = EventDraft(event: third, calendar: F.cal)
        draft.title = "Nový plán"
        try store.updateEvent(third, with: draft, span: .futureEvents)
        let found = F.november(store)
        #expect(found.map(\.title) == ["Plán", "Plán", "Nový plán", "Nový plán", "Nový plán"])
        #expect(found[0].key.externalID == first.key.externalID)
        #expect(found[2].key.externalID != first.key.externalID)
        #expect(found.allSatisfy { $0.isRecurring })
    }

    @Test func deletingThisAndFutureFromALaterOccurrenceKeepsTheEarlierOnes() throws {
        let (store, _) = try weekly()
        try store.deleteEvent(try #require(occurrence(store, day: 16)), span: .futureEvents)
        #expect(F.november(store).map { F.cal.component(.day, from: $0.start) } == [2, 9])
        #expect(store.events(in: DateInterval(start: F.d(2026, 12, 1), end: F.d(2027, 1, 1)), calendarIDs: F.all).isEmpty)
    }

    @Test func thisAndFutureFromTheFirstOccurrenceChangesTheWholeSeries() throws {
        let (store, first) = try weekly()
        var draft = EventDraft(event: first, calendar: F.cal)
        draft.title = "Týdenní plán"
        try store.updateEvent(first, with: draft, span: .futureEvents)
        #expect(F.november(store).map(\.title) == Array(repeating: "Týdenní plán", count: 5))
        try store.deleteEvent(try #require(occurrence(store, day: 2)), span: .futureEvents)
        #expect(F.november(store).isEmpty)
    }

    @Test func changingTheRuleOfOneOccurrenceAppliesToTheFuture() throws {
        let (store, _) = try weekly()
        let fourth = try #require(occurrence(store, day: 23))
        var draft = EventDraft(event: fourth, calendar: F.cal)
        draft.recurrence = RecurrenceRule(frequency: .daily, end: F.d(2026, 11, 25))
        try store.updateEvent(fourth, with: draft, span: .thisEvent)
        #expect(F.november(store).map { F.cal.component(.day, from: $0.start) } == [2, 9, 16, 23, 24, 25])
    }

    @Test func aSingleEventCanBecomeASeriesAndBack() throws {
        let store = F.store()
        let single = try store.createEvent(F.draft("Běh", calendarID: "home", day: 3, hour: 7))
        var draft = EventDraft(event: single, calendar: F.cal)
        draft.recurrence = RecurrenceRule(frequency: .weekly)
        try store.updateEvent(single, with: draft, span: .thisEvent)
        #expect(F.november(store).map { F.cal.component(.day, from: $0.start) } == [3, 10, 17, 24])
        let first = try #require(occurrence(store, day: 3))
        var back = EventDraft(event: first, calendar: F.cal)
        back.recurrence = nil
        try store.updateEvent(first, with: back, span: .futureEvents)
        let found = F.november(store)
        #expect(found.count == 1 && !found[0].isRecurring && found[0].key.externalID == single.key.externalID)
    }

    @Test func seriesInTheInitialEventsAreExpanded() {
        var template = F.draft("Plán").makeEvent(key: EventKey(externalID: "s", occurrenceStart: F.d(2026, 11, 2, 8)),
                                                 calendar: F.cal)
        template.start = F.d(2026, 11, 2, 8)
        template.end = F.d(2026, 11, 2, 9)
        template.recurrence = RecurrenceRule(frequency: .weekly)
        let store = F.store(events: [template])
        #expect(F.november(store).count == 5)
    }
}
