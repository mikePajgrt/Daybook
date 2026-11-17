import Foundation

/// The three views. The raw value is what `UserDefaults` stores.
public enum ViewMode: String, CaseIterable, Sendable {
    case day, week, month
}

/// Which stretch of time a view shows, and how it moves. Only calendar arithmetic is used,
/// so days stay midnight to midnight across clock changes.
public enum Period {
    /// The interval the view in `mode` shows when it contains `date`.
    /// A month view shows the full weeks that cover the month.
    public static func interval(_ mode: ViewMode, containing date: Date, calendar: Calendar) -> DateInterval {
        switch mode {
        case .day:
            let start = calendar.startOfDay(for: date)
            let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86_400)
            return DateInterval(start: start, end: end)
        case .week:
            return calendar.dateInterval(of: .weekOfYear, for: date)
                ?? interval(.day, containing: date, calendar: calendar)
        case .month:
            let days = MonthLayout.weeks(containing: date, calendar: calendar).flatMap { $0 }
            guard let first = days.first, let last = days.last,
                  let end = calendar.date(byAdding: .day, value: 1, to: last)
            else { return interval(.day, containing: date, calendar: calendar) }
            return DateInterval(start: first, end: end)
        }
    }

    /// The start of the period `count` units of `mode` away from the one containing `date`.
    public static func step(_ mode: ViewMode, from date: Date, by count: Int, calendar: Calendar) -> Date {
        let start: Date
        let component: Calendar.Component
        switch mode {
        case .day:
            start = calendar.startOfDay(for: date)
            component = .day
        case .week:
            start = calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? calendar.startOfDay(for: date)
            component = .weekOfYear
        case .month:
            start = calendar.dateInterval(of: .month, for: date)?.start ?? calendar.startOfDay(for: date)
            component = .month
        }
        return calendar.date(byAdding: component, value: count, to: start) ?? start
    }

    /// The midnights that start each day inside `interval`.
    public static func days(in interval: DateInterval, calendar: Calendar) -> [Date] {
        var result: [Date] = []
        var day = calendar.startOfDay(for: interval.start)
        while day < interval.end {
            result.append(day)
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return result
    }
}
