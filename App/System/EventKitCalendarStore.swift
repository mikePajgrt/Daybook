import CoreGraphics
import DaybookCore
import EventKit
import Foundation

/// `CalendarStore` over the system calendar database.
final class EventKitCalendarStore: CalendarStore {
    private let store = EKEventStore()
    private let continuation: AsyncStream<Void>.Continuation
    private var observer: NSObjectProtocol?
    let changes: AsyncStream<Void>

    init() {
        let (stream, continuation) = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
        self.changes = stream
        self.continuation = continuation
        observer = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged, object: store, queue: .main
        ) { _ in continuation.yield() }
    }

    deinit {
        if let observer { NotificationCenter.default.removeObserver(observer) }
    }

    var access: CalendarAccess {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess: return .granted
        case .notDetermined: return .notDetermined
        default: return .denied
        }
    }

    func requestAccess() async -> CalendarAccess {
        guard access == .notDetermined else { return access }
        _ = try? await store.requestFullAccessToEvents()
        return access
    }

    func calendars() -> [CalendarInfo] {
        guard access == .granted else { return [] }
        return store.calendars(for: .event).map(Self.info(for:))
    }

    func events(in interval: DateInterval, calendarIDs: Set<String>) -> [EventInfo] {
        guard access == .granted else { return [] }
        let wanted = store.calendars(for: .event).filter { calendarIDs.contains($0.calendarIdentifier) }
        guard !wanted.isEmpty else { return [] }
        let predicate = store.predicateForEvents(withStart: interval.start, end: interval.end, calendars: wanted)
        return store.events(matching: predicate)
            .map(Self.info(for:))
            .sorted { ($0.start, $0.title) < ($1.start, $1.title) }
    }

    // MARK: - Translation

    private static func info(for calendar: EKCalendar) -> CalendarInfo {
        let kind = kind(of: calendar)
        let readOnly = !calendar.allowsContentModifications
        return CalendarInfo(id: calendar.calendarIdentifier,
                            title: calendar.title,
                            color: rgba(calendar.cgColor),
                            sourceTitle: calendar.source?.title ?? "",
                            sourceKind: kind,
                            isReadOnly: readOnly,
                            isShared: kind == .google && readOnly)
    }

    private static func kind(of calendar: EKCalendar) -> SourceKind {
        if calendar.type == .subscription { return .subscribed }
        guard let source = calendar.source else { return .other }
        let title = source.title.lowercased()
        switch source.sourceType {
        case .local: return .local
        case .exchange: return .exchange
        case .mobileMe: return .icloud
        case .subscribed: return .subscribed
        case .calDAV:
            if title.contains("icloud") { return .icloud }
            if title.contains("google") || title.contains("gmail") { return .google }
            return .other
        default: return .other
        }
    }

    private static func rgba(_ color: CGColor?) -> RGBA {
        guard let color,
              let space = CGColorSpace(name: CGColorSpace.sRGB),
              let converted = color.converted(to: space, intent: .defaultIntent, options: nil),
              let c = converted.components, c.count >= 3
        else { return RGBA(r: 0.56, g: 0.56, b: 0.58) }
        return RGBA(r: Double(c[0]), g: Double(c[1]), b: Double(c[2]), a: c.count > 3 ? Double(c[3]) : 1)
    }

    private static func info(for event: EKEvent) -> EventInfo {
        let start = event.startDate ?? Date()
        let externalID = event.calendarItemExternalIdentifier ?? event.eventIdentifier ?? UUID().uuidString
        return EventInfo(key: EventKey(externalID: externalID, occurrenceStart: event.occurrenceDate ?? start),
                         calendarID: event.calendar?.calendarIdentifier ?? "",
                         title: event.title ?? "",
                         start: start,
                         end: event.endDate ?? start,
                         isAllDay: event.isAllDay,
                         location: event.location,
                         notes: event.notes)
    }
}
