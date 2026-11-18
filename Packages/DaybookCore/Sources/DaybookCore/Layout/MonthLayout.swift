import Foundation

/// One day cell of the month grid.
public struct DayLayout: Hashable, Sendable {
    public let date: Date
    public let isInMonth: Bool
    /// Single-day timed events, sorted by start then title. Never truncated.
    public let timed: [EventInfo]
}

/// The part of an all-day or multi-day event that falls into one week.
public struct SpanSegment: Hashable, Sendable, Identifiable {
    public let event: EventInfo
    /// Vertical slot within the week, 0 at the top.
    public let lane: Int
    public let startColumn: Int
    /// Inclusive.
    public let endColumn: Int
    public let continuesBefore: Bool
    public let continuesAfter: Bool

    public var id: EventKey { event.key }
}

public struct WeekLayout: Hashable, Sendable, Identifiable {
    public let days: [DayLayout]
    public let spans: [SpanSegment]

    public var id: Date { days[0].date }
    public var laneCount: Int { (spans.map(\.lane).max() ?? -1) + 1 }
    /// Event rows the week needs so that its fullest day shows everything.
    public var rowCount: Int { laneCount + (days.map(\.timed.count).max() ?? 0) }
}

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

    /// Places `events` into the weeks of the month containing `month`.
    public static func layout(month: Date, events: [EventInfo], calendar: Calendar) -> [WeekLayout] {
        layout(weeks: weeks(containing: month, calendar: calendar), month: month, events: events, calendar: calendar)
    }

    /// Places `events` into `weeks`. Days of the month containing `month` are marked as in the month.
    public static func layout(weeks: [[Date]], month: Date, events: [EventInfo], calendar: Calendar) -> [WeekLayout] {
        let monthInterval = calendar.dateInterval(of: .month, for: month)
        let ranged = events.map { (event: $0, days: dayRange(of: $0, calendar: calendar)) }
        return weeks.map { days in
            week(days: days, monthInterval: monthInterval, events: ranged)
        }
    }

    // MARK: - A run of months

    /// The weeks covering every month from the one containing `first` to the one containing `last`,
    /// as one continuous column: a week shared by two months appears once.
    public static func weeks(fromMonth first: Date, throughMonth last: Date, calendar: Calendar) -> [[Date]] {
        guard let start = calendar.dateInterval(of: .month, for: first)?.start,
              let end = calendar.dateInterval(of: .month, for: last)?.start else { return [] }
        var result: [[Date]] = []
        var month = start
        while month <= end {
            for week in weeks(containing: month, calendar: calendar) where week.first.map({ day in
                result.last.map { day > $0[0] } ?? true
            }) ?? false {
                result.append(week)
            }
            guard let next = calendar.date(byAdding: .month, value: 1, to: month) else { break }
            month = next
        }
        return result
    }

    /// The first day of the month a week mostly belongs to: the month of its middle day.
    public static func owner(of week: [Date], calendar: Calendar) -> Date? {
        guard !week.isEmpty else { return nil }
        return calendar.dateInterval(of: .month, for: week[week.count / 2])?.start
    }

    /// The first day of the week the month view opens on for the month containing `month`.
    /// Today's week when that month is today's month, so what is ahead is on screen; otherwise the month's
    /// first week. Weeks start on `calendar.firstWeekday`.
    public static func openingWeek(month: Date, today: Date, calendar: Calendar) -> Date? {
        let weeks = weeks(containing: month, calendar: calendar)
        guard let first = weeks.first?.first else { return nil }
        guard calendar.isDate(month, equalTo: today, toGranularity: .month) else { return first }
        let day = calendar.startOfDay(for: today)
        return weeks.first { $0.contains(day) }?.first ?? first
    }

    /// The first days of the first and last month of a window of `radius` months either side of `date`'s month.
    public static func window(around date: Date, radius: Int, calendar: Calendar) -> (first: Date, last: Date) {
        let month = calendar.dateInterval(of: .month, for: date)?.start ?? calendar.startOfDay(for: date)
        let first = calendar.date(byAdding: .month, value: -radius, to: month) ?? month
        let last = calendar.date(byAdding: .month, value: radius, to: month) ?? month
        return (first, last)
    }

    /// From the first day of the window's first week to the day after its last week.
    public static func interval(of window: (first: Date, last: Date), calendar: Calendar) -> DateInterval {
        let days = weeks(fromMonth: window.first, throughMonth: window.last, calendar: calendar).flatMap { $0 }
        guard let start = days.first, let last = days.last,
              let end = calendar.date(byAdding: .day, value: 1, to: last) else {
            return DateInterval(start: window.first, duration: 0)
        }
        return DateInterval(start: start, end: end)
    }

    /// First and last day an event touches. An event ending exactly at midnight
    /// does not touch the day that starts at that midnight.
    public static func dayRange(of event: EventInfo, calendar: Calendar) -> ClosedRange<Date> {
        let first = calendar.startOfDay(for: event.start)
        var lastInstant = event.end
        if event.end > event.start, calendar.startOfDay(for: event.end) == event.end {
            lastInstant = event.end.addingTimeInterval(-1)
        }
        return first...max(first, calendar.startOfDay(for: lastInstant))
    }

    private static func week(days: [Date], monthInterval: DateInterval?,
                             events: [(event: EventInfo, days: ClosedRange<Date>)]) -> WeekLayout {
        let firstDay = days[0]
        let lastDay = days[days.count - 1]
        var timed: [[EventInfo]] = Array(repeating: [], count: days.count)
        var spanning: [(event: EventInfo, days: ClosedRange<Date>)] = []

        for item in events {
            guard item.days.upperBound >= firstDay, item.days.lowerBound <= lastDay else { continue }
            if item.event.isAllDay || item.days.lowerBound != item.days.upperBound {
                spanning.append(item)
            } else if let column = days.firstIndex(of: item.days.lowerBound) {
                timed[column].append(item.event)
            }
        }

        let spans = SpanLanes.segments(days: days, items: spanning)

        let dayLayouts = days.enumerated().map { index, date in
            DayLayout(date: date,
                      // DateInterval.contains includes the end instant, which is the next month's first midnight.
                      isInMonth: monthInterval.map { date >= $0.start && date < $0.end } ?? true,
                      timed: timed[index].sorted { ($0.start, $0.title) < ($1.start, $1.title) })
        }
        return WeekLayout(days: dayLayouts, spans: spans)
    }
}
