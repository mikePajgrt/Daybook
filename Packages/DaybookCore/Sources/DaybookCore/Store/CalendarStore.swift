import Foundation

public enum CalendarAccess: Sendable, Equatable {
    case notDetermined, granted, denied
}

/// Which occurrences of a recurring event a change or deletion applies to.
public enum EditSpan: Hashable, Sendable {
    /// Only the occurrence the user picked.
    case thisEvent
    /// The occurrence the user picked and every later one.
    case futureEvents
}

/// Why a write was refused. `system` carries the text the system or the account gave.
public enum CalendarStoreError: Error, Equatable, Sendable {
    case eventNotFound
    case calendarNotFound
    case calendarReadOnly
    case sourceNotFound
    case sourceDoesNotAllowCalendars
    case invalidDraft([DraftProblem])
    case invalidCalendar([CalendarDraftProblem])
    case system(String)
}

/// Everything the app needs from the system calendar database.
/// Implementations are used from the main actor only.
public protocol CalendarStore: AnyObject {
    var access: CalendarAccess { get }

    /// Asks the user for access if it has not been decided yet. Returns the resulting state.
    func requestAccess() async -> CalendarAccess

    /// All calendars the user has, switched on or not.
    func calendars() -> [CalendarInfo]

    /// Events that overlap `interval` and belong to one of `calendarIDs`, sorted by start then title.
    /// Recurring events come as their occurrences.
    func events(in interval: DateInterval, calendarIDs: Set<String>) -> [EventInfo]

    /// Emits whenever calendars or events changed, including after the app's own writes.
    var changes: AsyncStream<Void> { get }

    // MARK: Writing

    /// The accounts calendars live in.
    func sources() -> [SourceInfo]

    /// The calendar the system uses for new events, if any.
    func defaultCalendarID() -> String?

    /// Saves a new event (a series when the draft recurs) and returns it (its first occurrence).
    @discardableResult func createEvent(_ draft: EventDraft) throws -> EventInfo

    /// Applies `draft` to `event`. `span` matters only for occurrences of a recurring event.
    func updateEvent(_ event: EventInfo, with draft: EventDraft, span: EditSpan) throws

    /// Deletes `event`. `span` matters only for occurrences of a recurring event.
    func deleteEvent(_ event: EventInfo, span: EditSpan) throws

    /// Creates a calendar in the draft's source.
    @discardableResult func createCalendar(_ draft: CalendarDraft) throws -> CalendarInfo

    /// Changes a calendar's colour.
    func setColor(_ color: RGBA, ofCalendar id: String) throws
}
