import Foundation

public enum RecurrenceFrequency: String, CaseIterable, Sendable, Codable {
    case daily, weekly, monthly, yearly
}

/// How an event repeats. Covers what the editor offers: a frequency, an interval and an optional end.
/// A system rule with more detail (given weekdays, a count) is read as its frequency and interval.
public struct RecurrenceRule: Hashable, Sendable, Codable {
    public var frequency: RecurrenceFrequency
    /// Every `interval` units of `frequency`; at least 1.
    public var interval: Int
    /// The last day an occurrence may start (any time on that day counts). `nil` repeats forever.
    public var end: Date?

    public init(frequency: RecurrenceFrequency, interval: Int = 1, end: Date? = nil) {
        self.frequency = frequency
        self.interval = max(1, interval)
        self.end = end
    }
}

/// An alert before the event starts.
public struct AlertOffset: Hashable, Sendable, Codable {
    /// Minutes before the start; 0 is at the start.
    public var minutesBefore: Int

    public init(minutesBefore: Int) {
        self.minutesBefore = max(0, minutesBefore)
    }

    /// What the editor offers: at the start, 5, 15 and 30 minutes, an hour and a day before.
    public static let presets: [AlertOffset] = [0, 5, 15, 30, 60, 1440].map(AlertOffset.init(minutesBefore:))
}

public enum AttendeeStatus: String, Sendable, Codable, CaseIterable {
    case pending, accepted, declined, tentative, unknown
}

/// Someone invited to an event, for reading only: invitations are not sent through public API.
public struct Attendee: Hashable, Sendable, Codable {
    public var name: String?
    public var email: String?
    public var status: AttendeeStatus
    public var isOrganizer: Bool
    public var isCurrentUser: Bool

    public init(name: String?, email: String?, status: AttendeeStatus,
                isOrganizer: Bool = false, isCurrentUser: Bool = false) {
        self.name = name
        self.email = email
        self.status = status
        self.isOrganizer = isOrganizer
        self.isCurrentUser = isCurrentUser
    }

    /// The name, else the e-mail address, else empty.
    public var displayName: String {
        if let name, !name.trimmingCharacters(in: .whitespaces).isEmpty { return name }
        return email ?? ""
    }
}
