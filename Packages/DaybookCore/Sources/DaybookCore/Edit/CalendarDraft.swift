import Foundation

/// An account calendars live in, as the new-calendar form offers it.
public struct SourceInfo: Identifiable, Hashable, Sendable {
    /// The system's source identifier. Local to one device.
    public let id: String
    public var title: String
    public var kind: SourceKind
    /// Whether the system lets calendars be added to this source.
    public var allowsCalendars: Bool

    public init(id: String, title: String, kind: SourceKind, allowsCalendars: Bool = true) {
        self.id = id
        self.title = title
        self.kind = kind
        self.allowsCalendars = allowsCalendars
    }

    /// iCloud, Exchange and local sources can hold a new calendar. Google calendars are created at Google;
    /// subscriptions are read-only.
    public var offersCalendarCreation: Bool {
        allowsCalendars && [.icloud, .exchange, .local].contains(kind)
    }
}

public enum CalendarDraftProblem: Hashable, Sendable {
    case emptyName
    case noSource
}

/// The fields of a new calendar.
public struct CalendarDraft: Hashable, Sendable {
    public var title: String
    public var color: RGBA
    public var sourceID: String

    public init(title: String, color: RGBA, sourceID: String) {
        self.title = title
        self.color = color
        self.sourceID = sourceID
    }

    public var problems: [CalendarDraftProblem] {
        var result: [CalendarDraftProblem] = []
        if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { result.append(.emptyName) }
        if sourceID.isEmpty { result.append(.noSource) }
        return result
    }
}
