import DaybookCore
import Foundation
import Observation

/// Calendars of one account, as shown in the sidebar.
struct CalendarSection: Identifiable {
    let title: String
    let calendars: [CalendarInfo]
    var id: String { title }
}

/// A day the user picked, in a form `sheet(item:)` accepts.
struct SelectedDay: Identifiable {
    let date: Date
    var id: Date { date }
}

@MainActor
@Observable
final class AppModel {
    static let hiddenCalendarsKey = "hiddenCalendarIDs"

    let calendar: Calendar
    let today: Date
    private let store: CalendarStore
    private let defaults: UserDefaults
    private var watcher: Task<Void, Never>?

    private(set) var access: CalendarAccess
    private(set) var calendars: [CalendarInfo] = []
    private(set) var filter: VisibilityFilter
    /// Any instant inside the month on screen.
    private(set) var month: Date
    private(set) var weeks: [WeekLayout] = []

    init(store: CalendarStore, defaults: UserDefaults = .standard,
         calendar: Calendar = .current, now: Date = Date()) {
        self.store = store
        self.defaults = defaults
        self.calendar = calendar
        self.today = calendar.startOfDay(for: now)
        self.month = now
        self.access = store.access
        self.filter = VisibilityFilter(storedValue: defaults.stringArray(forKey: Self.hiddenCalendarsKey) ?? [])
    }

    /// Loads the first month and keeps reloading when the system database changes.
    func start() {
        reload()
        guard watcher == nil else { return }
        watcher = Task { [weak self] in
            guard let changes = self?.store.changes else { return }
            for await _ in changes { self?.reload() }
        }
    }

    func requestAccess() async {
        access = await store.requestAccess()
        reload()
    }

    func reload() {
        access = store.access
        calendars = access == .granted ? store.calendars() : []
        let days = MonthLayout.weeks(containing: month, calendar: calendar).flatMap { $0 }
        var events: [EventInfo] = []
        if access == .granted, let first = days.first, let last = days.last,
           let end = calendar.date(byAdding: .day, value: 1, to: last) {
            let visible = filter.visibleIDs(among: Set(calendars.map(\.id)))
            events = store.events(in: DateInterval(start: first, end: end), calendarIDs: visible)
        }
        weeks = MonthLayout.layout(month: month, events: events, calendar: calendar)
    }

    // MARK: - Calendars

    private static let kindOrder: [SourceKind] = [.icloud, .exchange, .google, .local, .subscribed, .other]

    var sections: [CalendarSection] {
        Dictionary(grouping: calendars, by: \.sourceTitle)
            .map { title, items in
                CalendarSection(title: title.isEmpty ? "Ostatní" : title,
                                calendars: items.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending })
            }
            .sorted { a, b in
                let ka = Self.kindOrder.firstIndex(of: a.calendars[0].sourceKind) ?? Self.kindOrder.count
                let kb = Self.kindOrder.firstIndex(of: b.calendars[0].sourceKind) ?? Self.kindOrder.count
                return (ka, a.title) < (kb, b.title)
            }
    }

    func calendarInfo(_ id: String) -> CalendarInfo? { calendars.first { $0.id == id } }

    func toggle(_ calendar: CalendarInfo) { updateFilter { $0.toggle(calendar.id) } }

    func showOnly(_ calendar: CalendarInfo) {
        let all = Set(calendars.map(\.id))
        updateFilter { $0.showOnly(calendar.id, among: all) }
    }

    func showAll() { updateFilter { $0.showAll() } }

    private func updateFilter(_ change: (inout VisibilityFilter) -> Void) {
        change(&filter)
        defaults.set(filter.storedValue, forKey: Self.hiddenCalendarsKey)
        reload()
    }

    // MARK: - Navigation

    func step(months: Int) {
        guard let start = calendar.dateInterval(of: .month, for: month)?.start,
              let moved = calendar.date(byAdding: .month, value: months, to: start) else { return }
        month = moved
        reload()
    }

    func goToToday() {
        month = today
        reload()
    }

    /// Everything planned on `day`, all-day and multi-day events first.
    func events(on day: Date) -> [EventInfo] {
        for week in weeks {
            guard let column = week.days.firstIndex(where: { $0.date == day }) else { continue }
            let spans = week.spans
                .filter { $0.startColumn <= column && column <= $0.endColumn }
                .sorted { $0.lane < $1.lane }
                .map(\.event)
            return spans + week.days[column].timed
        }
        return []
    }
}
