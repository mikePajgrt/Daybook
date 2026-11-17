import Foundation

/// A `CalendarStore` backed by arrays. Used by tests and by the app's demo mode.
public final class InMemoryCalendarStore: CalendarStore {
    public private(set) var access: CalendarAccess
    private var storedCalendars: [CalendarInfo]
    private var storedEvents: [EventInfo]
    private let continuation: AsyncStream<Void>.Continuation
    public let changes: AsyncStream<Void>

    public init(calendars: [CalendarInfo], events: [EventInfo], access: CalendarAccess = .granted) {
        self.storedCalendars = calendars
        self.storedEvents = events
        self.access = access
        let (stream, continuation) = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
        self.changes = stream
        self.continuation = continuation
    }

    public func requestAccess() async -> CalendarAccess {
        if access == .notDetermined { access = .granted }
        return access
    }

    public func calendars() -> [CalendarInfo] { storedCalendars }

    public func events(in interval: DateInterval, calendarIDs: Set<String>) -> [EventInfo] {
        storedEvents
            .filter { calendarIDs.contains($0.calendarID) && $0.start < interval.end && $0.end > interval.start }
            .sorted { ($0.start, $0.title) < ($1.start, $1.title) }
    }

    public func replaceEvents(_ events: [EventInfo]) {
        storedEvents = events
        continuation.yield()
    }

    public func replaceCalendars(_ calendars: [CalendarInfo]) {
        storedCalendars = calendars
        continuation.yield()
    }
}
