import Foundation

public enum CalendarAccess: Sendable, Equatable {
    case notDetermined, granted, denied
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
    func events(in interval: DateInterval, calendarIDs: Set<String>) -> [EventInfo]

    /// Emits whenever calendars or events changed outside the app's own reads.
    var changes: AsyncStream<Void> { get }
}
