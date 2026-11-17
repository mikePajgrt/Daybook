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
        let monthInterval = calendar.dateInterval(of: .month, for: month)
        let ranged = events.map { (event: $0, days: dayRange(of: $0, calendar: calendar)) }
        return weeks(containing: month, calendar: calendar).map { days in
            week(days: days, monthInterval: monthInterval, events: ranged)
        }
    }

    /// First and last day an event touches. An event ending exactly at midnight
    /// does not touch the day that starts at that midnight.
    static func dayRange(of event: EventInfo, calendar: Calendar) -> ClosedRange<Date> {
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

        // Earlier first, then longer, then by title, so lanes are stable and long events sit on top.
        spanning.sort { a, b in
            if a.days.lowerBound != b.days.lowerBound { return a.days.lowerBound < b.days.lowerBound }
            if a.days.upperBound != b.days.upperBound { return a.days.upperBound > b.days.upperBound }
            return a.event.title < b.event.title
        }

        var lastColumnOfLane: [Int] = []
        var spans: [SpanSegment] = []
        for item in spanning {
            let startColumn = days.firstIndex(of: max(item.days.lowerBound, firstDay)) ?? 0
            let endColumn = days.firstIndex(of: min(item.days.upperBound, lastDay)) ?? days.count - 1
            let lane = lastColumnOfLane.firstIndex { $0 < startColumn } ?? lastColumnOfLane.count
            if lane == lastColumnOfLane.count {
                lastColumnOfLane.append(endColumn)
            } else {
                lastColumnOfLane[lane] = endColumn
            }
            spans.append(SpanSegment(event: item.event, lane: lane,
                                     startColumn: startColumn, endColumn: endColumn,
                                     continuesBefore: item.days.lowerBound < firstDay,
                                     continuesAfter: item.days.upperBound > lastDay))
        }

        let dayLayouts = days.enumerated().map { index, date in
            DayLayout(date: date,
                      // DateInterval.contains includes the end instant, which is the next month's first midnight.
                      isInMonth: monthInterval.map { date >= $0.start && date < $0.end } ?? true,
                      timed: timed[index].sorted { ($0.start, $0.title) < ($1.start, $1.title) })
        }
        return WeekLayout(days: dayLayouts, spans: spans)
    }
}
