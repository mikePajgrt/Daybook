import Foundation

public enum MonthLayout {
    /// The full weeks that cover the month containing `month`.
    /// Every date is the start of a day in `calendar`; weeks start on `calendar.firstWeekday`.
    public static func weeks(containing month: Date, calendar: Calendar) -> [[Date]] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: month),
              var weekStart = calendar.dateInterval(of: .weekOfYear, for: monthInterval.start)?.start
        else { return [] }

        var result: [[Date]] = []
        while weekStart < monthInterval.end {
            result.append((0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: weekStart) })
            guard let next = calendar.date(byAdding: .day, value: 7, to: weekStart) else { break }
            weekStart = next
        }
        return result
    }
}
