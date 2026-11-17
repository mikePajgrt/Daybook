import Foundation

/// A fixed calendar so tests do not depend on the machine's locale or time zone.
enum TestCalendar {
    static func prague(firstWeekday: Int = 2) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Prague")!
        calendar.firstWeekday = firstWeekday
        return calendar
    }

    static func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0,
                     in calendar: Calendar = prague()) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }
}
