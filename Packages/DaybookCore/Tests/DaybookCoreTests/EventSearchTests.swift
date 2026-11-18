import Foundation
import Testing
@testable import DaybookCore

@Suite struct EventSearchTests {
    let cal = TestCalendar.prague()

    private func event(_ id: String, _ title: String, day: Int, month: Int = 11, hour: Int = 9,
                       location: String? = nil, notes: String? = nil, attendees: [Attendee] = []) -> EventInfo {
        let start = TestCalendar.date(2026, month, day, hour)
        return EventInfo(key: EventKey(externalID: id, occurrenceStart: start), calendarID: "c", title: title,
                         start: start, end: start.addingTimeInterval(3600), isAllDay: false,
                         location: location, notes: notes, attendees: attendees)
    }

    private func matches(_ event: EventInfo, _ query: String) -> Bool {
        EventSearch.matches(event, terms: EventSearch.terms(query))
    }

    @Test func ignoresCaseAndDiacritics() {
        let item = event("a", "Schůzka týmu", day: 17)
        #expect(matches(item, "schuzka"))
        #expect(matches(item, "SCHŮZKA"))
        #expect(matches(item, "tymu"))
        #expect(!matches(item, "porada"))
    }

    @Test func searchesLocationNotesAndAttendees() {
        let people = [Attendee(name: "Petra Svobodová", email: "petra@example.com", status: .accepted),
                      Attendee(name: nil, email: "design@firma.cz", status: .pending)]
        let item = event("a", "Návrh", day: 17, location: "Zasedačka Vltava", notes: "Rozhodnout o stránkování",
                         attendees: people)
        #expect(matches(item, "VLTAVA"))
        #expect(matches(item, "strankovani"))
        #expect(matches(item, "svobodova"))
        #expect(matches(item, "design@firma"))
        #expect(matches(item, "petra@example.com"))
    }

    @Test func everyWordMustMatchInSomeField() {
        let item = event("a", "Návrh API", day: 17, location: "Vltava")
        #expect(matches(item, "api vltava"))
        #expect(matches(item, "  vltava   navrh "))
        #expect(!matches(item, "api sázava"))
    }

    @Test func emptyQueryFindsNothing() {
        let items = [event("a", "Návrh", day: 17)]
        #expect(EventSearch.terms("").isEmpty)
        #expect(EventSearch.terms("   \n ").isEmpty)
        #expect(EventSearch.results(items, query: "  ", today: TestCalendar.date(2026, 11, 17), calendar: cal).isEmpty)
        #expect(!matches(items[0], ""))
    }

    @Test func upcomingDaysFirstThenPastDaysMostRecentFirst() {
        let items = [event("past-far", "Porada", day: 2), event("future-far", "Porada", day: 28),
                     event("today-late", "Porada", day: 17, hour: 15), event("today-early", "Porada", day: 17, hour: 8),
                     event("past-near", "Porada", day: 16), event("future-near", "Porada", day: 18),
                     event("other", "Oběd", day: 18)]
        let days = EventSearch.results(items, query: "porada", today: TestCalendar.date(2026, 11, 17, 12), calendar: cal)
        #expect(days.map { cal.component(.day, from: $0.day) } == [17, 18, 28, 16, 2])
        #expect(days[0].events.map(\.key.externalID) == ["today-early", "today-late"])
        #expect(days.flatMap(\.events).count == 6)
    }

    @Test func eventReadTwiceIsKeptOnce() {
        let item = event("a", "Porada", day: 17)
        let days = EventSearch.results([item, item], query: "porada", today: TestCalendar.date(2026, 11, 17), calendar: cal)
        #expect(days.flatMap(\.events).count == 1)
    }

    @Test func highlightsCoverTheOriginalCharacters() {
        let title = "Schůzka týmu"
        let ranges = EventSearch.highlights(in: title, query: "schuz tym")
        #expect(ranges.map { String(title[$0]) } == ["Schůz", "tým"])
        #expect(EventSearch.highlights(in: title, query: "").isEmpty)
        #expect(EventSearch.highlights(in: "Porada porada", query: "porada").count == 2)
    }

    @Test func tenYearRangeSplitsIntoChunksOfAtMostFourYears() throws {
        let today = TestCalendar.date(2026, 11, 17, 10)
        let range = EventSearch.range(around: today, calendar: cal)
        #expect(range.start == TestCalendar.date(2021, 11, 17))
        #expect(range.end == TestCalendar.date(2031, 11, 18))
        let chunks = EventSearch.chunks(of: range, maxYears: 4, calendar: cal)
        #expect(chunks.count == 3)
        #expect(chunks.first?.start == range.start)
        #expect(chunks.last?.end == range.end)
        for (a, b) in zip(chunks, chunks.dropFirst()) { #expect(a.end == b.start) }
        for chunk in chunks {
            let limit = try #require(cal.date(byAdding: .year, value: 4, to: chunk.start))
            #expect(chunk.end <= limit)
            // Chunk edges stay at local midnight whatever the clock did in between.
            #expect(cal.startOfDay(for: chunk.start) == chunk.start)
            #expect(cal.startOfDay(for: chunk.end) == chunk.end)
        }
    }

    @Test func shortRangeIsOneChunk() {
        let range = DateInterval(start: TestCalendar.date(2026, 3, 1), end: TestCalendar.date(2026, 11, 1))
        #expect(EventSearch.chunks(of: range, maxYears: 4, calendar: cal) == [range])
    }

    @Test func snippetSaysWhyAResultMatched() {
        let notes = "Projít návrh endpointů pro synchronizaci kategorií a rozhodnout o stránkování."
        let people = [Attendee(name: "Petra Svobodová", email: "petra@example.com", status: .accepted)]
        let item = event("a", "Návrh API", day: 17, location: "Zasedačka Vltava", notes: notes, attendees: people)
        // The title shows the match: nothing to add.
        #expect(EventSearch.snippet(for: item, query: "navrh") == nil)
        #expect(EventSearch.snippet(for: item, query: "vltava") == nil)
        // A note: a few whole words before the match, marked as cut.
        #expect(EventSearch.snippet(for: item, query: "strankovani")
                == .init(field: .notes, text: "…a rozhodnout o stránkování."))
        // Near the start of the note: the whole line.
        #expect(EventSearch.snippet(for: item, query: "endpointu")
                == .init(field: .notes, text: notes))
        // An attendee: the name or the address that matched.
        #expect(EventSearch.snippet(for: item, query: "svobodova") == .init(field: .attendee, text: "Petra Svobodová"))
        #expect(EventSearch.snippet(for: item, query: "petra@") == .init(field: .attendee, text: "petra@example.com"))
    }
}
