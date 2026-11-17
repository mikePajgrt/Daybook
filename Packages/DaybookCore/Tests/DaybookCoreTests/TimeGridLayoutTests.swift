import Foundation
import Testing
@testable import DaybookCore

@Suite struct TimeGridLayoutTests {
    let cal = TestCalendar.prague()
    let day = TestCalendar.date(2026, 11, 17)

    func event(_ title: String, _ start: Date, _ end: Date, allDay: Bool = false) -> EventInfo {
        EventInfo(key: EventKey(externalID: title, occurrenceStart: start), calendarID: "work",
                  title: title, start: start, end: end, isAllDay: allDay)
    }

    func timed(_ title: String, _ h1: Int, _ m1: Int, _ h2: Int, _ m2: Int, day d: Int = 17) -> EventInfo {
        event(title, TestCalendar.date(2026, 11, d, h1, m1), TestCalendar.date(2026, 11, d, h2, m2))
    }

    func layout(_ events: [EventInfo], on date: Date? = nil, minimum: TimeInterval = 0) -> [String: TimedPlacement] {
        let placements = TimeGridLayout.layout(day: date ?? day, events: events, calendar: cal,
                                               minimumDuration: minimum)
        return Dictionary(uniqueKeysWithValues: placements.map { ($0.event.title, $0) })
    }

    @Test func aLoneEventTakesTheWholeColumn() {
        let p = layout([timed("A", 9, 0, 10, 0)])
        #expect(p["A"]?.column == 0 && p["A"]?.columnCount == 1)
        #expect(p["A"]?.startMinute == 540 && p["A"]?.endMinute == 600)
    }

    @Test func overlappingEventsSitSideBySide() {
        let p = layout([timed("A", 9, 0, 10, 0), timed("B", 9, 30, 10, 30)])
        #expect(p["A"]?.column == 0 && p["B"]?.column == 1)
        #expect(p["A"]?.columnCount == 2 && p["B"]?.columnCount == 2)
    }

    @Test func eventsThatOnlyTouchDoNotOverlap() {
        let p = layout([timed("A", 9, 0, 10, 0), timed("B", 10, 0, 11, 0)])
        #expect(p["A"]?.column == 0 && p["A"]?.columnCount == 1)
        #expect(p["B"]?.column == 0 && p["B"]?.columnCount == 1)
    }

    @Test func aTransitiveClusterSharesOneColumnCount() {
        let p = layout([timed("C", 10, 30, 12, 0), timed("A", 9, 0, 10, 0), timed("B", 9, 30, 11, 0)])
        #expect(p.values.allSatisfy { $0.columnCount == 2 })
        #expect(p["A"]?.column == 0 && p["B"]?.column == 1 && p["C"]?.column == 0)
    }

    @Test func threeMutualOverlapsTakeThreeColumns() {
        let p = layout([timed("A", 13, 0, 14, 30), timed("B", 13, 30, 15, 0), timed("C", 14, 0, 15, 0)])
        #expect(p["A"]?.column == 0 && p["B"]?.column == 1 && p["C"]?.column == 2)
        #expect(p.values.allSatisfy { $0.columnCount == 3 })
    }

    @Test func separateClustersKeepTheirOwnCounts() {
        let p = layout([timed("A", 9, 0, 10, 0), timed("B", 9, 0, 10, 0), timed("C", 14, 0, 15, 0)])
        #expect(p["A"]?.columnCount == 2 && p["B"]?.columnCount == 2)
        #expect(p["C"]?.columnCount == 1 && p["C"]?.column == 0)
    }

    @Test func longerEventTakesTheFirstColumnWhenStartsTie() {
        let placements = TimeGridLayout.layout(day: day, events: [timed("Short", 9, 0, 9, 30), timed("Long", 9, 0, 11, 0)],
                                               calendar: cal)
        #expect(placements.map(\.event.title) == ["Long", "Short"])
        #expect(placements.map(\.column) == [0, 1])
    }

    @Test func anEventCrossingMidnightIsClippedToEachDay() {
        let late = event("Noc", TestCalendar.date(2026, 11, 17, 22), TestCalendar.date(2026, 11, 18, 2))
        let first = try! #require(layout([late])["Noc"])
        #expect(first.startMinute == 1320 && first.endMinute == 1440)
        #expect(!first.continuesBefore && first.continuesAfter)
        let second = try! #require(layout([late], on: TestCalendar.date(2026, 11, 18))["Noc"])
        #expect(second.startMinute == 0 && second.endMinute == 120)
        #expect(second.continuesBefore && !second.continuesAfter)
    }

    @Test func eventsOfOtherDaysAreLeftOut() {
        #expect(layout([timed("Zítra", 9, 0, 10, 0, day: 18)]).isEmpty)
        #expect(layout([timed("Do půlnoci", 22, 0, 0, 0, day: 16).with(end: day)]).isEmpty)
    }

    @Test func allDayAndLongEventsGoToTheStripNotTheGrid() {
        let holiday = event("Svátek", day, TestCalendar.date(2026, 11, 17, 23, 59).addingTimeInterval(59), allDay: true)
        let trip = event("Cesta", TestCalendar.date(2026, 11, 16, 10), TestCalendar.date(2026, 11, 18, 10))
        let meeting = timed("Porada", 9, 0, 10, 0)
        #expect(!TimeGridLayout.isGridEvent(holiday) && !TimeGridLayout.isGridEvent(trip))
        #expect(TimeGridLayout.isGridEvent(meeting))
        #expect(layout([holiday, trip, meeting]).keys.sorted() == ["Porada"])

        let week = Period.days(in: Period.interval(.week, containing: day, calendar: cal), calendar: cal)
        let segments = TimeGridLayout.allDaySegments(days: week, events: [holiday, trip, meeting], calendar: cal)
        let byTitle = Dictionary(uniqueKeysWithValues: segments.map { ($0.event.title, $0) })
        #expect(segments.count == 2)
        #expect(byTitle["Cesta"]?.startColumn == 0 && byTitle["Cesta"]?.endColumn == 2 && byTitle["Cesta"]?.lane == 0)
        #expect(byTitle["Svátek"]?.startColumn == 1 && byTitle["Svátek"]?.lane == 1)
    }

    @Test func aSpanStartingBeforeTheRangeContinuesBefore() {
        let trip = event("Cesta", TestCalendar.date(2026, 11, 14), TestCalendar.date(2026, 11, 17), allDay: true)
        let segments = TimeGridLayout.allDaySegments(days: [TestCalendar.date(2026, 11, 16)], events: [trip], calendar: cal)
        #expect(segments.count == 1)
        #expect(segments[0].continuesBefore && !segments[0].continuesAfter)
    }

    @Test func aMinimumDurationMakesBackToBackShortEventsOverlap() {
        let p = layout([timed("A", 9, 0, 9, 5), timed("B", 9, 5, 9, 10)], minimum: 30 * 60)
        #expect(p["A"]?.columnCount == 2 && p["B"]?.column == 1)
        #expect(p["A"]?.endMinute == 545)
    }

    @Test func minutesFollowTheWallClockOnTheClockChange() {
        let changeDay = TestCalendar.date(2026, 10, 25)
        let early = event("Ráno", TestCalendar.date(2026, 10, 25, 3), TestCalendar.date(2026, 10, 25, 4))
        let p = layout([early], on: changeDay)
        #expect(p["Ráno"]?.startMinute == 180 && p["Ráno"]?.endMinute == 240)
    }

    @Test func splitByDayGivesOnePiecePerColumn() {
        let trip = event("Cesta", TestCalendar.date(2026, 11, 16), TestCalendar.date(2026, 11, 19), allDay: true)
        let week = Period.days(in: Period.interval(.week, containing: day, calendar: cal), calendar: cal)
        let span = try! #require(TimeGridLayout.allDaySegments(days: week, events: [trip], calendar: cal).first)
        let pieces = span.splitByDay()
        #expect(pieces.map(\.startColumn) == [0, 1, 2])
        #expect(pieces.allSatisfy { $0.startColumn == $0.endColumn })
        #expect(!pieces[0].continuesBefore && pieces[0].continuesAfter)
        #expect(pieces[1].continuesBefore && pieces[1].continuesAfter)
        #expect(pieces[2].continuesBefore && !pieces[2].continuesAfter)
    }
}

private extension EventInfo {
    func with(end: Date) -> EventInfo {
        var copy = self
        copy.end = end
        return copy
    }
}

@Suite struct TimeGridSlotTests {
    @Test func slotsSnapDownToTheHalfHourWithinTheDay() {
        let cal = TestCalendar.prague()
        let day = TestCalendar.date(2026, 11, 17)
        func slot(_ minute: Double) -> Date { TimeGridLayout.slotStart(day: day, minute: minute, calendar: cal) }
        #expect(slot(645.5) == TestCalendar.date(2026, 11, 17, 10, 30))
        #expect(slot(0) == day)
        #expect(slot(-5) == day)
        #expect(slot(1439) == TestCalendar.date(2026, 11, 17, 23, 30))
        #expect(slot(1500) == TestCalendar.date(2026, 11, 17, 23, 30))
    }

    @Test func slotsUseWallClockOnTheClockChange() {
        let cal = TestCalendar.prague()
        let day = TestCalendar.date(2026, 10, 25)
        let slot = TimeGridLayout.slotStart(day: day, minute: 180, calendar: cal)
        #expect(cal.component(.hour, from: slot) == 3 && cal.component(.minute, from: slot) == 0)
        #expect(cal.isDate(slot, inSameDayAs: day))
    }
}
