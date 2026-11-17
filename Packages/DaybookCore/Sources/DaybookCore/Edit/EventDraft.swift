import Foundation

/// Something the editor must point out before a draft can be saved. An empty title is not one:
/// such an event is shown as "Bez názvu".
public enum DraftProblem: Hashable, Sendable {
    case endBeforeStart
    case recurrenceEndsBeforeStart
    case invalidURL
    case noCalendar
}

/// The editable fields of an event, as the editor holds them.
///
/// Timed drafts hold instants. All-day drafts hold days: `start` is the first day's midnight and
/// `end` the last day's midnight (inclusive), so a one-day event has `start == end`.
public struct EventDraft: Hashable, Sendable {
    public var title: String
    public var calendarID: String
    public var isAllDay: Bool
    public var start: Date
    public var end: Date
    /// The zone the times are shown and stored in; `nil` for all-day events.
    public var timeZoneID: String?
    public var recurrence: RecurrenceRule?
    public var alert: AlertOffset?
    public var location: String
    /// As typed; see `normalizedURL`.
    public var url: String
    public var notes: String

    public init(title: String = "", calendarID: String, isAllDay: Bool = false, start: Date, end: Date,
                timeZoneID: String? = nil, recurrence: RecurrenceRule? = nil, alert: AlertOffset? = nil,
                location: String = "", url: String = "", notes: String = "") {
        self.title = title
        self.calendarID = calendarID
        self.isAllDay = isAllDay
        self.start = start
        self.end = end
        self.timeZoneID = timeZoneID
        self.recurrence = recurrence
        self.alert = alert
        self.location = location
        self.url = url
        self.notes = notes
    }

    /// The fields of `event`, ready to edit.
    public init(event: EventInfo, calendar: Calendar) {
        let start: Date
        let end: Date
        if event.isAllDay {
            let days = MonthLayout.dayRange(of: event, calendar: calendar)
            start = days.lowerBound
            end = days.upperBound
        } else {
            start = event.start
            end = event.end
        }
        self.init(title: event.title, calendarID: event.calendarID, isAllDay: event.isAllDay,
                  start: start, end: end, timeZoneID: event.isAllDay ? nil : event.timeZoneID,
                  recurrence: event.recurrence, alert: event.alert,
                  location: event.location ?? "", url: event.url?.absoluteString ?? "", notes: event.notes ?? "")
    }

    // MARK: - Validation

    public func problems(calendar: Calendar) -> [DraftProblem] {
        var result: [DraftProblem] = []
        if calendarID.isEmpty { result.append(.noCalendar) }
        if isAllDay {
            if calendar.startOfDay(for: end) < calendar.startOfDay(for: start) { result.append(.endBeforeStart) }
        } else if end < start {
            result.append(.endBeforeStart)
        }
        if let last = recurrence?.end, calendar.startOfDay(for: last) < calendar.startOfDay(for: start) {
            result.append(.recurrenceEndsBeforeStart)
        }
        if !url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && normalizedURL == nil {
            result.append(.invalidURL)
        }
        return result
    }

    /// The URL as typed, with `https://` added when no scheme was given. `nil` when empty or not a URL.
    public var normalizedURL: URL? {
        let text = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !text.contains(where: \.isWhitespace) else { return nil }
        let hasScheme = text.contains("://") || text.lowercased().hasPrefix("mailto:") || text.lowercased().hasPrefix("tel:")
        guard let url = URL(string: hasScheme ? text : "https://" + text), url.scheme != nil else { return nil }
        if let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" {
            guard let host = url.host, host.contains(".") || host == "localhost" else { return nil }
        }
        return url
    }

    // MARK: - Changes

    /// Moves the start and keeps the length: the same number of seconds for timed events,
    /// the same number of days for all-day events.
    public mutating func setStart(_ newStart: Date, calendar: Calendar) {
        if isAllDay {
            let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: start),
                                               to: calendar.startOfDay(for: end)).day ?? 0
            start = calendar.startOfDay(for: newStart)
            end = calendar.date(byAdding: .day, value: max(0, days), to: start) ?? start
        } else {
            let length = max(0, end.timeIntervalSince(start))
            start = newStart
            end = newStart.addingTimeInterval(length)
        }
    }

    /// All-day on: the days the times touched. Off: 9:00 to 10:00 on the first day.
    public mutating func setAllDay(_ allDay: Bool, calendar: Calendar) {
        guard allDay != isAllDay else { return }
        isAllDay = allDay
        if allDay {
            let first = calendar.startOfDay(for: start)
            var lastInstant = end
            if end > start, calendar.startOfDay(for: end) == end { lastInstant = end.addingTimeInterval(-1) }
            start = first
            end = max(first, calendar.startOfDay(for: lastInstant))
            timeZoneID = nil
        } else {
            let day = calendar.startOfDay(for: start)
            start = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: day) ?? day
            end = start.addingTimeInterval(3600)
            timeZoneID = calendar.timeZone.identifier
        }
    }

    /// Shows the same wall-clock times in another zone, so the instants move.
    public mutating func changeTimeZone(to identifier: String, calendar: Calendar) {
        guard !isAllDay, let newZone = TimeZone(identifier: identifier) else { return }
        var old = calendar
        old.timeZone = timeZoneID.flatMap(TimeZone.init(identifier:)) ?? calendar.timeZone
        var new = calendar
        new.timeZone = newZone
        let parts: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second]
        if let s = new.date(from: old.dateComponents(parts, from: start)),
           let e = new.date(from: old.dateComponents(parts, from: end)) {
            start = s
            end = e
        }
        timeZoneID = identifier
    }

    /// Which spans a save may apply to. Empty for a single event (no question). When the recurrence
    /// itself changed, only "this and future events": a rule cannot change for one occurrence.
    public func spanChoices(original: EventInfo) -> [EditSpan] {
        guard original.isRecurring else { return [] }
        return recurrence == original.recurrence ? [.thisEvent, .futureEvents] : [.futureEvents]
    }

    // MARK: - Defaults

    /// A new event on `day`, starting at the next full hour after `now`, one hour long.
    /// When the next full hour is already tomorrow, it starts at 23:00 so it stays on `day`.
    public static func newEvent(on day: Date, now: Date, calendarID: String, calendar: Calendar) -> EventDraft {
        let nextHour = calendar.dateInterval(of: .hour, for: now)?.end ?? now.addingTimeInterval(3600)
        let hour = calendar.isDate(nextHour, inSameDayAs: now) ? calendar.component(.hour, from: nextHour) : 23
        let midnight = calendar.startOfDay(for: day)
        let start = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: midnight) ?? midnight
        return newEvent(at: start, calendarID: calendarID, calendar: calendar)
    }

    /// A new one-hour event starting at `start`.
    public static func newEvent(at start: Date, calendarID: String, calendar: Calendar) -> EventDraft {
        EventDraft(calendarID: calendarID, start: start, end: start.addingTimeInterval(3600),
                   timeZoneID: calendar.timeZone.identifier)
    }

    /// The calendar a new event goes to: the last one used on this device, else the system default,
    /// else the first writable one. `nil` when nothing is writable.
    public static func preferredCalendarID(writable: [CalendarInfo], lastUsed: String?,
                                           systemDefault: String?) -> String? {
        let ids = Set(writable.map(\.id))
        if let lastUsed, ids.contains(lastUsed) { return lastUsed }
        if let systemDefault, ids.contains(systemDefault) { return systemDefault }
        return writable.first?.id
    }

    // MARK: - Result

    /// The event this draft describes. All-day events run from the first midnight to one second
    /// before the midnight after the last day, as the system stores them.
    public func makeEvent(key: EventKey, calendar: Calendar, attendees: [Attendee] = [],
                          isEditable: Bool = true) -> EventInfo {
        var eventStart = start
        var eventEnd = end
        if isAllDay {
            eventStart = calendar.startOfDay(for: start)
            let lastDay = calendar.startOfDay(for: max(start, end))
            eventEnd = (calendar.date(byAdding: .day, value: 1, to: lastDay) ?? lastDay).addingTimeInterval(-1)
        }
        func text(_ value: String) -> String? {
            value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : value
        }
        return EventInfo(key: key, calendarID: calendarID, title: title, start: eventStart, end: eventEnd,
                         isAllDay: isAllDay, location: text(location), notes: text(notes), url: normalizedURL,
                         recurrence: recurrence, attendees: attendees, alert: alert,
                         timeZoneID: isAllDay ? nil : timeZoneID, isEditable: isEditable)
    }
}
