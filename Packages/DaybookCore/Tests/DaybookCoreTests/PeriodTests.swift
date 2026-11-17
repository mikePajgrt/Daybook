import Foundation
import Testing
@testable import DaybookCore

@Suite struct PeriodTests {
    let cal = TestCalendar.prague()

    func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0) -> Date { TestCalendar.date(y, m, d, h) }

    @Test func dayIntervalIsMidnightToMidnight() {
        let day = Period.interval(.day, containing: date(2026, 11, 17, 10), calendar: cal)
        #expect(day.start == date(2026, 11, 17))
        #expect(day.duration == 24 * 3600)
    }

    @Test func dayIntervalOnTheAutumnClockChangeIs25Hours() {
        let day = Period.interval(.day, containing: date(2026, 10, 25, 12), calendar: cal)
        #expect(day.start == date(2026, 10, 25))
        #expect(day.end == date(2026, 10, 26))
        #expect(day.duration == 25 * 3600)
    }

    @Test func weekFollowsTheFirstWeekday() {
        let monday = Period.interval(.week, containing: date(2026, 11, 17, 10), calendar: cal)
        #expect(monday.start == date(2026, 11, 16))
        #expect(monday.end == date(2026, 11, 23))
        let sundayCal = TestCalendar.prague(firstWeekday: 1)
        let sunday = Period.interval(.week, containing: date(2026, 11, 17, 10), calendar: sundayCal)
        #expect(sunday.start == date(2026, 11, 15))
    }

    @Test func weekAcrossTheClockChangeHasSevenMidnights() {
        let week = Period.interval(.week, containing: date(2026, 10, 21), calendar: cal)
        #expect(week.duration == 7 * 24 * 3600 + 3600)
        let days = Period.days(in: week, calendar: cal)
        #expect(days.count == 7)
        #expect(days.first == date(2026, 10, 19))
        #expect(days.last == date(2026, 10, 25))
        #expect(days.allSatisfy { cal.startOfDay(for: $0) == $0 })
    }

    @Test func monthIntervalCoversItsFullWeeks() {
        let month = Period.interval(.month, containing: date(2026, 11, 17), calendar: cal)
        #expect(month.start == date(2026, 10, 26))
        #expect(month.end == date(2026, 12, 7))
    }

    @Test func steppingDaysCrossesTheClockChanges() {
        #expect(Period.step(.day, from: date(2026, 10, 24, 15), by: 1, calendar: cal) == date(2026, 10, 25))
        #expect(Period.step(.day, from: date(2026, 10, 24, 15), by: 2, calendar: cal) == date(2026, 10, 26))
        #expect(Period.step(.day, from: date(2026, 3, 29, 12), by: -1, calendar: cal) == date(2026, 3, 28))
        #expect(Period.step(.day, from: date(2026, 3, 28, 12), by: 1, calendar: cal) == date(2026, 3, 29))
    }

    @Test func steppingWeeksLandsOnTheWeekStart() {
        #expect(Period.step(.week, from: date(2026, 10, 21, 9), by: 1, calendar: cal) == date(2026, 10, 26))
        #expect(Period.step(.week, from: date(2026, 11, 17), by: -1, calendar: cal) == date(2026, 11, 9))
    }

    @Test func steppingMonthsLandsOnTheFirstOfTheMonth() {
        #expect(Period.step(.month, from: date(2026, 1, 31), by: 1, calendar: cal) == date(2026, 2, 1))
        #expect(Period.step(.month, from: date(2026, 1, 15), by: -1, calendar: cal) == date(2025, 12, 1))
    }

    @Test func viewModeRoundTripsThroughItsStoredValue() {
        #expect(ViewMode(rawValue: "week") == .week)
        #expect(ViewMode.allCases.map(\.rawValue) == ["day", "week", "month"])
    }
}
