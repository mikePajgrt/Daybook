import Foundation
import Testing
@testable import DaybookCore

@Suite struct MonthLayoutTests {
    let cal = TestCalendar.prague()
    let november = TestCalendar.date(2026, 11, 17)

    func timed(_ title: String, _ day: Int, _ hour: Int, minutes: Int = 60, month: Int = 11) -> EventInfo {
        let start = TestCalendar.date(2026, month, day, hour)
        return EventInfo(key: EventKey(externalID: title, occurrenceStart: start), calendarID: "work",
                         title: title, start: start, end: start.addingTimeInterval(Double(minutes) * 60),
                         isAllDay: false)
    }

    /// All-day events come from the system as 00:00 on the first day to 23:59:59 on the last.
    func allDay(_ title: String, from: Int, to: Int) -> EventInfo {
        let start = TestCalendar.date(2026, 11, from)
        let end = TestCalendar.date(2026, 11, to, 23, 59).addingTimeInterval(59)
        return EventInfo(key: EventKey(externalID: title, occurrenceStart: start), calendarID: "work",
                         title: title, start: start, end: end, isAllDay: true)
    }

    @Test func timedEventsLandInTheirDaySortedByStart() {
        let weeks = MonthLayout.layout(month: november, events: [timed("B", 10, 14), timed("A", 10, 9)],
                                       calendar: cal)
        #expect(weeks.count == 6)
        #expect(weeks[2].days[1].date == TestCalendar.date(2026, 11, 10))
        #expect(weeks[2].days[1].timed.map(\.title) == ["A", "B"])
        #expect(weeks[2].spans.isEmpty)
    }

    @Test func eventsWithTheSameStartSortByTitle() {
        let weeks = MonthLayout.layout(month: november, events: [timed("Retro", 10, 9), timed("Demo", 10, 9)],
                                       calendar: cal)
        #expect(weeks[2].days[1].timed.map(\.title) == ["Demo", "Retro"])
    }

    @Test func daysOutsideTheMonthAreFlagged() {
        let weeks = MonthLayout.layout(month: november, events: [], calendar: cal)
        #expect(weeks[0].days[0].isInMonth == false)   // 26 October
        #expect(weeks[0].days[6].isInMonth == true)    // 1 November
        #expect(weeks[5].days[0].isInMonth == true)    // 30 November
        #expect(weeks[5].days[1].isInMonth == false)   // 1 December
    }

    @Test func eventsInAdjacentMonthDaysAreStillShown() {
        let weeks = MonthLayout.layout(month: november, events: [timed("Říjen", 27, 10, month: 10)],
                                       calendar: cal)
        #expect(weeks[0].days[1].timed.map(\.title) == ["Říjen"])
    }

    @Test func singleAllDayEventIsASpanOfOneColumn() {
        let weeks = MonthLayout.layout(month: november, events: [allDay("Svátek", from: 17, to: 17)],
                                       calendar: cal)
        let span = try! #require(weeks[3].spans.first)
        #expect(weeks[3].spans.count == 1)
        #expect(span.startColumn == 1 && span.endColumn == 1 && span.lane == 0)
        #expect(!span.continuesBefore && !span.continuesAfter)
        #expect(weeks[3].days[1].timed.isEmpty)
    }

    @Test func multiDayEventIsSplitAtTheWeekBoundary() {
        let start = TestCalendar.date(2026, 11, 26, 10)
        let trip = EventInfo(key: EventKey(externalID: "trip", occurrenceStart: start), calendarID: "home",
                             title: "Lisabon", start: start, end: TestCalendar.date(2026, 11, 30, 18),
                             isAllDay: false)
        let weeks = MonthLayout.layout(month: november, events: [trip], calendar: cal)

        let first = try! #require(weeks[4].spans.first)
        #expect(first.startColumn == 3 && first.endColumn == 6)
        #expect(!first.continuesBefore && first.continuesAfter)

        let second = try! #require(weeks[5].spans.first)
        #expect(second.startColumn == 0 && second.endColumn == 0)
        #expect(second.continuesBefore && !second.continuesAfter)

        #expect(weeks.flatMap { $0.days }.allSatisfy { $0.timed.isEmpty })
    }

    @Test func overlappingSpansTakeSeparateLanesAndFreeLanesAreReused() {
        let weeks = MonthLayout.layout(month: november, events: [
            allDay("C", from: 7, to: 8), allDay("B", from: 4, to: 5), allDay("A", from: 2, to: 6)
        ], calendar: cal)
        let byTitle = Dictionary(uniqueKeysWithValues: weeks[1].spans.map { ($0.event.title, $0) })
        #expect(byTitle["A"]?.lane == 0)
        #expect(byTitle["B"]?.lane == 1)
        #expect(byTitle["C"]?.lane == 0)
        #expect(weeks[1].laneCount == 2)
    }

    @Test func timedEventEndingAtMidnightStaysInItsDay() {
        let weeks = MonthLayout.layout(month: november, events: [timed("Pozdě", 10, 22, minutes: 120)],
                                       calendar: cal)
        #expect(weeks[2].spans.isEmpty)
        #expect(weeks[2].days[1].timed.map(\.title) == ["Pozdě"])
        #expect(weeks[2].days[2].timed.isEmpty)
    }

    @Test func rowCountIsLanesPlusFullestDay() {
        let weeks = MonthLayout.layout(month: november, events: [
            allDay("A", from: 2, to: 6), allDay("B", from: 4, to: 5),
            timed("x", 3, 9), timed("y", 3, 10), timed("z", 3, 11), timed("w", 5, 9)
        ], calendar: cal)
        #expect(weeks[1].rowCount == 5)
        #expect(weeks[0].rowCount == 0)
    }

    @Test func eventsFarFromTheMonthAreIgnored() {
        let weeks = MonthLayout.layout(month: november, events: [timed("Leden", 15, 9, month: 1)],
                                       calendar: cal)
        #expect(weeks.allSatisfy { $0.spans.isEmpty && $0.rowCount == 0 })
    }
}
