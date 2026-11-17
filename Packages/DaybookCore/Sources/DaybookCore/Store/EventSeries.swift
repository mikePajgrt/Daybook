import Foundation

/// A recurring event as the in-memory store keeps it: the first occurrence as a template, its rule,
/// and the occurrences that were changed or deleted on their own.
struct EventSeries: Sendable {
    enum Exception: Sendable {
        case changed(EventInfo)
        case deleted
    }

    /// The first occurrence; its `recurrence` is the series' rule.
    var template: EventInfo
    /// Keyed by the original start of the occurrence.
    var exceptions: [Date: Exception] = [:]

    var id: String { template.key.externalID }
    var rule: RecurrenceRule { template.recurrence ?? RecurrenceRule(frequency: .daily) }

    /// Upper bound on occurrences walked, so a malformed rule cannot loop forever.
    private static let limit = 20_000

    /// The original starts of every occurrence before `end`, in order.
    func occurrenceStarts(before end: Date, calendar: Calendar) -> [Date] {
        let component: Calendar.Component
        switch rule.frequency {
        case .daily: component = .day
        case .weekly: component = .weekOfYear
        case .monthly: component = .month
        case .yearly: component = .year
        }
        let lastDay = rule.end.map { calendar.startOfDay(for: $0) }
        var result: [Date] = []
        for n in 0..<Self.limit {
            // Always from the template, so a 31st clamps per month instead of drifting.
            guard let start = calendar.date(byAdding: component, value: n * rule.interval, to: template.start),
                  start < end else { break }
            if let lastDay, calendar.startOfDay(for: start) > lastDay { break }
            result.append(start)
        }
        return result
    }

    func isOccurrence(_ start: Date, calendar: Calendar) -> Bool {
        occurrenceStarts(before: start.addingTimeInterval(1), calendar: calendar).last == start
    }

    /// The occurrence that originally starts at `start`, as generated from the template.
    func generated(at start: Date, calendar: Calendar) -> EventInfo {
        var event = template.with(key: EventKey(externalID: id, occurrenceStart: start))
        event.start = start
        if template.isAllDay {
            let days = MonthLayout.dayRange(of: template, calendar: calendar)
            let count = calendar.dateComponents([.day], from: days.lowerBound, to: days.upperBound).day ?? 0
            let lastDay = calendar.date(byAdding: .day, value: count, to: calendar.startOfDay(for: start)) ?? start
            event.end = (calendar.date(byAdding: .day, value: 1, to: lastDay) ?? lastDay).addingTimeInterval(-1)
        } else {
            event.end = start.addingTimeInterval(template.end.timeIntervalSince(template.start))
        }
        return event
    }

    /// Occurrences overlapping `interval`, changed ones as changed, deleted ones left out.
    func occurrences(in interval: DateInterval, calendar: Calendar) -> [EventInfo] {
        // A changed occurrence may have moved; walk a little past the interval to catch it.
        let reach = interval.end.addingTimeInterval(366 * 86_400)
        return occurrenceStarts(before: reach, calendar: calendar).compactMap { start -> EventInfo? in
            let event: EventInfo
            switch exceptions[start] {
            case .deleted: return nil
            case .changed(let changed): event = changed
            case nil:
                guard start < interval.end else { return nil }
                event = generated(at: start, calendar: calendar)
            }
            let overlaps = event.start < interval.end && event.end > interval.start
            let instant = event.start == event.end && interval.contains(event.start)
            return overlaps || instant ? event : nil
        }
    }

    /// Ends the series on the day before `start`, dropping exceptions from `start` on.
    mutating func truncate(before start: Date, calendar: Calendar) {
        let dayBefore = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: start)) ?? start
        template.recurrence = RecurrenceRule(frequency: rule.frequency, interval: rule.interval, end: dayBefore)
        exceptions = exceptions.filter { $0.key < start }
    }
}
