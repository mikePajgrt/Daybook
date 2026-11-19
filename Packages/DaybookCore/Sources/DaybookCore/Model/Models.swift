import Foundation

/// A colour as plain components, so the package needs no UI framework.
public struct RGBA: Hashable, Sendable, Codable {
    public var r: Double
    public var g: Double
    public var b: Double
    public var a: Double

    public init(r: Double, g: Double, b: Double, a: Double = 1) {
        self.r = r
        self.g = g
        self.b = b
        self.a = a
    }
}

/// Which kind of account a calendar comes from.
public enum SourceKind: String, Sendable, Codable, CaseIterable {
    case icloud, exchange, google, local, subscribed, other
}

public struct CalendarInfo: Identifiable, Hashable, Sendable {
    /// The system's calendar identifier. Local to one device.
    public let id: String
    public var title: String
    public var color: RGBA
    public var sourceTitle: String
    public var sourceKind: SourceKind
    public var isReadOnly: Bool
    public var isShared: Bool

    public init(id: String, title: String, color: RGBA, sourceTitle: String,
                sourceKind: SourceKind, isReadOnly: Bool = false, isShared: Bool = false) {
        self.id = id
        self.title = title
        self.color = color
        self.sourceTitle = sourceTitle
        self.sourceKind = sourceKind
        self.isReadOnly = isReadOnly
        self.isShared = isShared
    }
}

/// Identifies one occurrence of an event in a way that is stable across devices.
public struct EventKey: Hashable, Sendable, Codable {
    public let externalID: String
    public let occurrenceStart: Date

    public init(externalID: String, occurrenceStart: Date) {
        self.externalID = externalID
        self.occurrenceStart = occurrenceStart
    }
}

public struct EventInfo: Identifiable, Hashable, Sendable {
    public let key: EventKey
    public var calendarID: String
    public var title: String
    public var start: Date
    public var end: Date
    public var isAllDay: Bool
    public var location: String?
    public var notes: String?
    public var url: URL?
    /// The series' rule, also on each of its occurrences. `nil` for a single event.
    public var recurrence: RecurrenceRule?
    public var attendees: [Attendee]
    /// The first alert; further alerts are not edited by Daybook.
    public var alert: AlertOffset?
    /// The event's time zone; `nil` for all-day and floating events.
    public var timeZoneID: String?
    /// False when the event's calendar is read-only.
    public var isEditable: Bool

    public var id: EventKey { key }

    public var isRecurring: Bool { recurrence != nil }

    public init(key: EventKey, calendarID: String, title: String, start: Date, end: Date,
                isAllDay: Bool, location: String? = nil, notes: String? = nil, url: URL? = nil,
                recurrence: RecurrenceRule? = nil, attendees: [Attendee] = [], alert: AlertOffset? = nil,
                timeZoneID: String? = nil, isEditable: Bool = true) {
        self.key = key
        self.calendarID = calendarID
        self.title = title
        self.start = start
        self.end = end
        self.isAllDay = isAllDay
        self.location = location
        self.notes = notes
        self.url = url
        self.recurrence = recurrence
        self.attendees = attendees
        self.alert = alert
        self.timeZoneID = timeZoneID
        self.isEditable = isEditable
    }

    /// The same event under another key (a moved single event, an occurrence of a series).
    public func with(key: EventKey) -> EventInfo {
        EventInfo(key: key, calendarID: calendarID, title: title, start: start, end: end, isAllDay: isAllDay,
                  location: location, notes: notes, url: url, recurrence: recurrence, attendees: attendees,
                  alert: alert, timeZoneID: timeZoneID, isEditable: isEditable)
    }
}

extension EventInfo {
    /// Whether the event is over at `now`: a station the train has already passed. A timed event has
    /// passed once its end is at or before `now` (a zero-length one once its start is); an all-day event
    /// once its last day (see `MonthLayout.dayRange`) is before the day of `now`. An event in progress
    /// has not passed.
    public func hasPassed(at now: Date, calendar: Calendar) -> Bool {
        if isAllDay {
            return MonthLayout.dayRange(of: self, calendar: calendar).upperBound < calendar.startOfDay(for: now)
        }
        return max(start, end) <= now
    }
}
