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

    public var id: EventKey { key }

    public init(key: EventKey, calendarID: String, title: String, start: Date, end: Date,
                isAllDay: Bool, location: String? = nil, notes: String? = nil) {
        self.key = key
        self.calendarID = calendarID
        self.title = title
        self.start = start
        self.end = end
        self.isAllDay = isAllDay
        self.location = location
        self.notes = notes
    }
}
