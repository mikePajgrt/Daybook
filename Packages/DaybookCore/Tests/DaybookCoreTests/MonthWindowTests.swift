import Foundation
import Testing
@testable import DaybookCore

@Suite struct MonthWindowTests {
    let cal = TestCalendar.prague()

    @Test func weeksOfSeveralMonthsAreContinuousWithoutRepeats() throws {
        let weeks = MonthLayout.weeks(fromMonth: TestCalendar.date(2026, 10, 5), throughMonth: TestCalendar.date(2026, 12, 20),
                                      calendar: cal)
        // 28 Sep ... 3 Jan: October's first week to December's last.
        #expect(weeks.first?.first == TestCalendar.date(2026, 9, 28))
        #expect(weeks.last?.last == TestCalendar.date(2027, 1, 3))
        #expect(Set(weeks.map { $0[0] }).count == weeks.count)
        for (a, b) in zip(weeks, weeks.dropFirst()) {
            #expect(cal.date(byAdding: .day, value: 1, to: try #require(a.last)) == b.first)
        }
    }

    @Test func weeksAcrossTheAutumnClockChangeStayAtMidnight() {
        let weeks = MonthLayout.weeks(fromMonth: TestCalendar.date(2026, 10, 1), throughMonth: TestCalendar.date(2026, 10, 1),
                                      calendar: cal)
        let days = weeks.flatMap { $0 }
        #expect(days.allSatisfy { cal.startOfDay(for: $0) == $0 })
        #expect(days.contains(TestCalendar.date(2026, 10, 25)))
        #expect(days.contains(TestCalendar.date(2026, 10, 26)))
    }

    @Test func aWeekBelongsToTheMonthOfItsMiddleDay() {
        // 26 Oct to 1 Nov: Thursday 29 Oct.
        let week = (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: TestCalendar.date(2026, 10, 26)) }
        #expect(MonthLayout.owner(of: week, calendar: cal) == TestCalendar.date(2026, 10, 1))
        let next = (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: TestCalendar.date(2026, 11, 30)) }
        #expect(MonthLayout.owner(of: next, calendar: cal) == TestCalendar.date(2026, 12, 1))
    }

    @Test func windowRunsThreeMonthsEitherSide() {
        let window = MonthLayout.window(around: TestCalendar.date(2026, 11, 17, 10), radius: 3, calendar: cal)
        #expect(window.first == TestCalendar.date(2026, 8, 1))
        #expect(window.last == TestCalendar.date(2027, 2, 1))
        let interval = MonthLayout.interval(of: window, calendar: cal)
        #expect(interval.start == TestCalendar.date(2026, 7, 27))
        #expect(interval.end == TestCalendar.date(2027, 3, 1))
    }

    @Test func layoutOfAWindowPlacesEventsAndMarksTheFocusedMonth() {
        let start = TestCalendar.date(2026, 12, 2, 9)
        let event = EventInfo(key: EventKey(externalID: "x", occurrenceStart: start), calendarID: "c", title: "Porada",
                              start: start, end: start.addingTimeInterval(3600), isAllDay: false)
        let weeks = MonthLayout.weeks(fromMonth: TestCalendar.date(2026, 11, 1), throughMonth: TestCalendar.date(2026, 12, 1),
                                      calendar: cal)
        let layout = MonthLayout.layout(weeks: weeks, month: TestCalendar.date(2026, 11, 17), events: [event], calendar: cal)
        #expect(layout.count == weeks.count)
        let day = layout.flatMap(\.days).first { $0.date == TestCalendar.date(2026, 12, 2) }
        #expect(day?.timed.map(\.title) == ["Porada"])
        #expect(day?.isInMonth == false)
        #expect(layout.flatMap(\.days).first { $0.date == TestCalendar.date(2026, 11, 2) }?.isInMonth == true)
    }

    @Test func singleMonthLayoutIsUnchanged() {
        let month = TestCalendar.date(2026, 11, 17)
        let one = MonthLayout.layout(month: month, events: [], calendar: cal)
        let run = MonthLayout.layout(weeks: MonthLayout.weeks(containing: month, calendar: cal), month: month,
                                     events: [], calendar: cal)
        #expect(one == run)
    }

    @Test func todaysMonthOpensOnTodaysWeek() {
        // Tuesday 17 November 2026: its week starts on Monday the 16th.
        #expect(MonthLayout.openingWeek(month: TestCalendar.date(2026, 11, 1), today: TestCalendar.date(2026, 11, 17, 10),
                                        calendar: cal) == TestCalendar.date(2026, 11, 16))
    }

    @Test func anotherMonthOpensOnItsFirstWeek() {
        // December's first week starts on Monday 30 November.
        #expect(MonthLayout.openingWeek(month: TestCalendar.date(2026, 12, 10), today: TestCalendar.date(2026, 11, 17),
                                        calendar: cal) == TestCalendar.date(2026, 11, 30))
        #expect(MonthLayout.openingWeek(month: TestCalendar.date(2026, 10, 10), today: TestCalendar.date(2026, 11, 17),
                                        calendar: cal) == TestCalendar.date(2026, 9, 28))
    }

    @Test func todayInTheMonthsLastWeekOpensThere() {
        // Monday 30 November is in November's last week, which it starts.
        #expect(MonthLayout.openingWeek(month: TestCalendar.date(2026, 11, 1), today: TestCalendar.date(2026, 11, 30),
                                        calendar: cal) == TestCalendar.date(2026, 11, 30))
        // The same day seen from December (its first week) is not December's today: its first week opens.
        #expect(MonthLayout.openingWeek(month: TestCalendar.date(2026, 12, 1), today: TestCalendar.date(2026, 11, 30),
                                        calendar: cal) == TestCalendar.date(2026, 11, 30))
    }

    @Test func weeksFollowTheLocalesFirstWeekday() {
        // Weeks starting on Sunday: 17 November's week starts on Sunday the 15th.
        let sunday = TestCalendar.prague(firstWeekday: 1)
        #expect(MonthLayout.openingWeek(month: TestCalendar.date(2026, 11, 20), today: TestCalendar.date(2026, 11, 17),
                                        calendar: sunday) == TestCalendar.date(2026, 11, 15))
        // Sunday 22 November opens its own week in a Sunday-first locale, the week of the 16th in a Monday-first one.
        #expect(MonthLayout.openingWeek(month: TestCalendar.date(2026, 11, 1), today: TestCalendar.date(2026, 11, 22),
                                        calendar: sunday) == TestCalendar.date(2026, 11, 22))
        #expect(MonthLayout.openingWeek(month: TestCalendar.date(2026, 11, 1), today: TestCalendar.date(2026, 11, 22),
                                        calendar: cal) == TestCalendar.date(2026, 11, 16))
    }
}
