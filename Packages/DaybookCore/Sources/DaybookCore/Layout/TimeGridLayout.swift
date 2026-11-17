import Foundation

/// Where one timed event sits in one day's column of the time grid.
public struct TimedPlacement: Hashable, Sendable, Identifiable {
    public let event: EventInfo
    /// Wall-clock minutes since the day's midnight, clipped to the day: 0...1440.
    public let startMinute: Int
    public let endMinute: Int
    /// Side-by-side slot inside the event's overlap cluster, 0 on the left.
    public let column: Int
    /// Number of slots the cluster needs. Every event of a cluster has the same count.
    public let columnCount: Int
    /// The event started on an earlier day.
    public let continuesBefore: Bool
    /// The event ends on a later day.
    public let continuesAfter: Bool

    public var id: EventKey { event.key }
}

public enum TimeGridLayout {
    /// Timed events shorter than a day are drawn in the grid. All-day events and longer
    /// timed events go to the all-day strip, where they read as one line across their days.
    public static func isGridEvent(_ event: EventInfo) -> Bool {
        !event.isAllDay && event.end.timeIntervalSince(event.start) < 24 * 3600
    }

    /// Places the grid events that touch `day` into side-by-side columns.
    /// Events that only touch end-to-start do not overlap. For overlap, an event lasts at least
    /// `minimumDuration`, so short events drawn at a minimum height never cover each other.
    public static func layout(day: Date, events: [EventInfo], calendar: Calendar,
                              minimumDuration: TimeInterval = 0) -> [TimedPlacement] {
        let dayStart = calendar.startOfDay(for: day)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return [] }

        struct Item {
            let event: EventInfo
            let start: Date
            let end: Date
            /// End used for overlap: at least `minimumDuration` after the start.
            let reach: Date
        }
        let items = events
            .filter(isGridEvent)
            .compactMap { event -> Item? in
                let start = max(event.start, dayStart)
                let end = min(event.end, dayEnd)
                // A zero-length event belongs to the day its instant falls in.
                let touches = end > start || (event.start == event.end && event.start >= dayStart && event.start < dayEnd)
                guard touches else { return nil }
                return Item(event: event, start: start, end: end,
                            reach: max(end, start.addingTimeInterval(minimumDuration)))
            }
            .sorted { a, b in
                if a.start != b.start { return a.start < b.start }
                if a.end != b.end { return a.end > b.end }
                return a.event.title < b.event.title
            }

        var result: [TimedPlacement] = []
        var cluster: [(item: Item, column: Int)] = []
        var columnEnds: [Date] = []
        var clusterReach = Date.distantPast

        func closeCluster() {
            let count = columnEnds.count
            for (item, column) in cluster {
                result.append(TimedPlacement(
                    event: item.event,
                    startMinute: minutes(of: item.start, dayStart: dayStart, dayEnd: dayEnd, calendar: calendar),
                    endMinute: minutes(of: item.end, dayStart: dayStart, dayEnd: dayEnd, calendar: calendar),
                    column: column, columnCount: count,
                    continuesBefore: item.event.start < dayStart,
                    continuesAfter: item.event.end > dayEnd))
            }
            cluster = []
            columnEnds = []
        }

        for item in items {
            if !cluster.isEmpty && item.start >= clusterReach { closeCluster() }
            let column = columnEnds.firstIndex { $0 <= item.start } ?? columnEnds.count
            if column == columnEnds.count { columnEnds.append(item.reach) } else { columnEnds[column] = item.reach }
            clusterReach = cluster.isEmpty ? item.reach : max(clusterReach, item.reach)
            cluster.append((item, column))
        }
        closeCluster()
        return result
    }

    /// Lanes for the events of `days` that do not belong in the grid. `days` are consecutive midnights.
    public static func allDaySegments(days: [Date], events: [EventInfo], calendar: Calendar) -> [SpanSegment] {
        let items = events
            .filter { !isGridEvent($0) }
            .map { (event: $0, days: MonthLayout.dayRange(of: $0, calendar: calendar)) }
        return SpanLanes.segments(days: days, items: items)
    }

    /// Wall-clock minutes of `date` within the day, so a clock change does not shift the hour rules.
    static func minutes(of date: Date, dayStart: Date, dayEnd: Date, calendar: Calendar) -> Int {
        if date >= dayEnd { return 24 * 60 }
        if date <= dayStart { return 0 }
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    }
}
