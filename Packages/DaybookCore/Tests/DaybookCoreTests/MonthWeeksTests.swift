import Foundation
import Testing
@testable import DaybookCore

@Suite struct MonthWeeksTests {
    @Test func november2026MondayFirstHasSixWeeks() {
        let cal = TestCalendar.prague()
        let weeks = MonthLayout.weeks(containing: TestCalendar.date(2026, 11, 17), calendar: cal)
        #expect(weeks.count == 6)
        #expect(weeks.allSatisfy { $0.count == 7 })
        #expect(weeks.first?.first == TestCalendar.date(2026, 10, 26))
        #expect(weeks.last?.last == TestCalendar.date(2026, 12, 6))
    }

    @Test func november2026SundayFirstHasFiveWeeks() {
        let cal = TestCalendar.prague(firstWeekday: 1)
        let weeks = MonthLayout.weeks(containing: TestCalendar.date(2026, 11, 17, in: cal), calendar: cal)
        #expect(weeks.count == 5)
        #expect(weeks.first?.first == TestCalendar.date(2026, 11, 1, in: cal))
        #expect(weeks.last?.last == TestCalendar.date(2026, 12, 5, in: cal))
    }

    @Test func february2027FitsExactlyFourWeeks() {
        let cal = TestCalendar.prague()
        let weeks = MonthLayout.weeks(containing: TestCalendar.date(2027, 2, 10), calendar: cal)
        #expect(weeks.count == 4)
        #expect(weeks.first?.first == TestCalendar.date(2027, 2, 1))
        #expect(weeks.last?.last == TestCalendar.date(2027, 2, 28))
    }

    @Test func daysStayAtMidnightAcrossDaylightSavingChange() {
        let cal = TestCalendar.prague()
        let days = MonthLayout.weeks(containing: TestCalendar.date(2026, 3, 15), calendar: cal).flatMap { $0 }
        #expect(days.count == 42)
        #expect(Set(days).count == 42)
        #expect(days.allSatisfy { cal.startOfDay(for: $0) == $0 })
        #expect(days.contains(TestCalendar.date(2026, 3, 29)))
        #expect(days.contains(TestCalendar.date(2026, 3, 30)))
    }
}
