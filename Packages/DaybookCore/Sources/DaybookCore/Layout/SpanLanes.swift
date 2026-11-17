import Foundation

/// Lays all-day and multi-day events into lanes over a run of consecutive days.
/// Shared by the month's week rows and the all-day strip of the week and day views.
enum SpanLanes {
    /// `days` are consecutive midnights; each item carries the first and last day its event touches.
    /// Items that miss `days` entirely are skipped.
    static func segments(days: [Date], items: [(event: EventInfo, days: ClosedRange<Date>)]) -> [SpanSegment] {
        guard let firstDay = days.first, let lastDay = days.last else { return [] }
        // Earlier first, then longer, then by title, so lanes are stable and long events sit on top.
        let sorted = items
            .filter { $0.days.upperBound >= firstDay && $0.days.lowerBound <= lastDay }
            .sorted { a, b in
                if a.days.lowerBound != b.days.lowerBound { return a.days.lowerBound < b.days.lowerBound }
                if a.days.upperBound != b.days.upperBound { return a.days.upperBound > b.days.upperBound }
                return a.event.title < b.event.title
            }

        var lastColumnOfLane: [Int] = []
        var spans: [SpanSegment] = []
        for item in sorted {
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
        return spans
    }
}

extension SpanSegment {
    /// One-column pieces of this segment, for columns too narrow to rely on a single label at the start.
    public func splitByDay() -> [SpanSegment] {
        (startColumn...endColumn).map { column in
            SpanSegment(event: event, lane: lane, startColumn: column, endColumn: column,
                        continuesBefore: continuesBefore || column > startColumn,
                        continuesAfter: continuesAfter || column < endColumn)
        }
    }
}
