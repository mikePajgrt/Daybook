import CoreGraphics
import DaybookCore
import EventKit
import Foundation

/// `CalendarStore` over the system calendar database.
///
/// A thin translation between EventKit and the package's value types. It cannot be unit-tested
/// (EventKit is never called from automated tests); the logic it relies on, such as draft validation
/// and the defaults, lives in `DaybookCore` and is tested there.
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

    // MARK: - Writing

    func sources() -> [SourceInfo] {
        guard access == .granted else { return [] }
        return store.sources.map { source in
            SourceInfo(id: source.sourceIdentifier, title: source.title, kind: Self.kind(of: source),
                       allowsCalendars: source.sourceType != .subscribed && source.sourceType != .birthdays)
        }
    }

    func defaultCalendarID() -> String? {
        guard access == .granted else { return nil }
        return store.defaultCalendarForNewEvents?.calendarIdentifier
    }

    @discardableResult
    func createEvent(_ draft: EventDraft) throws -> EventInfo {
        try check(draft)
        let event = EKEvent(eventStore: store)
        try apply(draft, to: event, original: nil)
        try perform { try store.save(event, span: .thisEvent, commit: true) }
        return Self.info(for: event)
    }

    func updateEvent(_ event: EventInfo, with draft: EventDraft, span: EditSpan) throws {
        try check(draft)
        guard let target = systemEvent(for: event) else { throw CalendarStoreError.eventNotFound }
        guard target.calendar?.allowsContentModifications ?? false else { throw CalendarStoreError.calendarReadOnly }
        try apply(draft, to: target, original: event)
        // A rule cannot change for one occurrence; EventKit applies it from the occurrence onward.
        let effective: EditSpan = draft.recurrence == event.recurrence ? span : .futureEvents
        try perform { try store.save(target, span: Self.ekSpan(effective), commit: true) }
    }

    func deleteEvent(_ event: EventInfo, span: EditSpan) throws {
        guard let target = systemEvent(for: event) else { throw CalendarStoreError.eventNotFound }
        guard target.calendar?.allowsContentModifications ?? false else { throw CalendarStoreError.calendarReadOnly }
        try perform { try store.remove(target, span: Self.ekSpan(span), commit: true) }
    }

    @discardableResult
    func createCalendar(_ draft: CalendarDraft) throws -> CalendarInfo {
        let problems = draft.problems
        guard problems.isEmpty else { throw CalendarStoreError.invalidCalendar(problems) }
        guard let source = store.sources.first(where: { $0.sourceIdentifier == draft.sourceID }) else {
            throw CalendarStoreError.sourceNotFound
        }
        let offered = SourceInfo(id: source.sourceIdentifier, title: source.title, kind: Self.kind(of: source))
        guard offered.offersCalendarCreation else { throw CalendarStoreError.sourceDoesNotAllowCalendars }
        let calendar = EKCalendar(for: .event, eventStore: store)
        calendar.title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        calendar.cgColor = Self.cgColor(draft.color)
        calendar.source = source
        try perform { try store.saveCalendar(calendar, commit: true) }
        return Self.info(for: calendar)
    }

    func setColor(_ color: RGBA, ofCalendar id: String) throws {
        guard let calendar = store.calendar(withIdentifier: id) else { throw CalendarStoreError.calendarNotFound }
        calendar.cgColor = Self.cgColor(color)
        try perform { try store.saveCalendar(calendar, commit: true) }
    }

    // MARK: - System editor

    /// The store the system event editor needs.
    var eventStore: EKEventStore { store }

    /// The EventKit occurrence behind `info`: matched by external identifier and occurrence date
    /// among the events of its calendar around its displayed times.
    func systemEvent(for info: EventInfo) -> EKEvent? {
        guard access == .granted, let calendar = store.calendar(withIdentifier: info.calendarID) else { return nil }
        let predicate = store.predicateForEvents(withStart: info.start.addingTimeInterval(-1),
                                                 end: info.end.addingTimeInterval(1), calendars: [calendar])
        return store.events(matching: predicate).first {
            Self.externalID(of: $0) == info.key.externalID
                && ($0.occurrenceDate ?? $0.startDate) == info.key.occurrenceStart
        }
    }

    // MARK: - Translation to EventKit

    private func check(_ draft: EventDraft) throws {
        let problems = draft.problems(calendar: .current)
        guard problems.isEmpty else { throw CalendarStoreError.invalidDraft(problems) }
        guard let calendar = store.calendar(withIdentifier: draft.calendarID) else {
            throw CalendarStoreError.calendarNotFound
        }
        guard calendar.allowsContentModifications else { throw CalendarStoreError.calendarReadOnly }
    }

    /// Copies the draft onto `event`. Recurrence and alarms are touched only when they changed,
    /// so a richer system rule or further alarms survive an unrelated edit.
    private func apply(_ draft: EventDraft, to event: EKEvent, original: EventInfo?) throws {
        let made = draft.makeEvent(key: EventKey(externalID: "", occurrenceStart: draft.start), calendar: .current)
        event.calendar = store.calendar(withIdentifier: draft.calendarID)
        event.title = made.title
        event.isAllDay = made.isAllDay
        event.timeZone = made.timeZoneID.flatMap(TimeZone.init(identifier:))
        event.startDate = made.start
        event.endDate = made.end
        event.location = made.location
        event.notes = made.notes
        event.url = made.url
        if original == nil || made.recurrence != original?.recurrence {
            event.recurrenceRules = made.recurrence.map { [Self.ekRule($0)] }
        }
        if original == nil || made.alert != original?.alert {
            event.alarms = made.alert.map { [EKAlarm(relativeOffset: -Double($0.minutesBefore) * 60)] }
        }
    }

    private func perform(_ write: () throws -> Void) throws {
        do {
            try write()
        } catch let error as CalendarStoreError {
            throw error
        } catch {
            throw CalendarStoreError.system(error.localizedDescription)
        }
    }

    private static func ekSpan(_ span: EditSpan) -> EKSpan {
        span == .thisEvent ? .thisEvent : .futureEvents
    }

    private static func ekRule(_ rule: RecurrenceRule) -> EKRecurrenceRule {
        let frequency: EKRecurrenceFrequency
        switch rule.frequency {
        case .daily: frequency = .daily
        case .weekly: frequency = .weekly
        case .monthly: frequency = .monthly
        case .yearly: frequency = .yearly
        }
        // The rule's end is a day; any start on that day counts, so end at its last instant.
        let end = rule.end.map { day -> EKRecurrenceEnd in
            let cal = Calendar.current
            let next = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: day)) ?? day
            return EKRecurrenceEnd(end: next.addingTimeInterval(-1))
        }
        return EKRecurrenceRule(recurrenceWith: frequency, interval: rule.interval, end: end)
    }

    private static func cgColor(_ c: RGBA) -> CGColor {
        CGColor(srgbRed: c.r, green: c.g, blue: c.b, alpha: c.a)
    }

    // MARK: - Translation from EventKit

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
        return kind(of: source)
    }

    private static func kind(of source: EKSource) -> SourceKind {
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

    private static func externalID(of event: EKEvent) -> String {
        event.calendarItemExternalIdentifier ?? event.eventIdentifier ?? ""
    }

    private static func info(for event: EKEvent) -> EventInfo {
        let start = event.startDate ?? Date()
        let externalID = externalID(of: event)
        return EventInfo(key: EventKey(externalID: externalID.isEmpty ? UUID().uuidString : externalID,
                                       occurrenceStart: event.occurrenceDate ?? start),
                         calendarID: event.calendar?.calendarIdentifier ?? "",
                         title: event.title ?? "",
                         start: start,
                         end: event.endDate ?? start,
                         isAllDay: event.isAllDay,
                         location: event.location,
                         notes: event.notes,
                         url: event.url,
                         recurrence: event.recurrenceRules?.first.map(recurrence(of:)),
                         attendees: (event.attendees ?? []).map { attendee(of: $0, organizer: event.organizer) },
                         alert: event.alarms?.first { $0.absoluteDate == nil && $0.relativeOffset <= 0 }
                             .map { AlertOffset(minutesBefore: Int((-$0.relativeOffset / 60).rounded())) },
                         timeZoneID: event.isAllDay ? nil : event.timeZone?.identifier,
                         isEditable: event.calendar?.allowsContentModifications ?? false)
    }

    private static func recurrence(of rule: EKRecurrenceRule) -> RecurrenceRule {
        let frequency: RecurrenceFrequency
        switch rule.frequency {
        case .daily: frequency = .daily
        case .weekly: frequency = .weekly
        case .monthly: frequency = .monthly
        case .yearly: frequency = .yearly
        @unknown default: frequency = .daily
        }
        return RecurrenceRule(frequency: frequency, interval: rule.interval,
                              end: rule.recurrenceEnd?.endDate.map { Calendar.current.startOfDay(for: $0) })
    }

    private static func attendee(of participant: EKParticipant, organizer: EKParticipant?) -> Attendee {
        let address = participant.url.absoluteString
        let email = address.lowercased().hasPrefix("mailto:") ? String(address.dropFirst("mailto:".count)) : nil
        let status: AttendeeStatus
        switch participant.participantStatus {
        case .accepted: status = .accepted
        case .declined: status = .declined
        case .tentative: status = .tentative
        case .pending: status = .pending
        default: status = .unknown
        }
        return Attendee(name: participant.name, email: email, status: status,
                        isOrganizer: participant.participantRole == .chair || participant.url == organizer?.url,
                        isCurrentUser: participant.isCurrentUser)
    }
}
