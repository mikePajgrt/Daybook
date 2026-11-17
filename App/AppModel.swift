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
    static let viewModeKey = "viewMode"
    /// For overlap, a timed event lasts at least this long: blocks are never drawn shorter.
    static let minimumBlockDuration: TimeInterval = 30 * 60

    let calendar: Calendar
    let today: Date
    /// Screens a debug demo launch asks to open straight away, for screenshots.
    let stagedScreens: Set<String>
    /// Bumped by "Dnes", so the month scrolls back to today even when it is already on screen.
    private(set) var todayRequests = 0
    private let store: CalendarStore
    private let defaults: UserDefaults
    private var watcher: Task<Void, Never>?

    private(set) var access: CalendarAccess
    private(set) var calendars: [CalendarInfo] = []
    private(set) var filter: VisibilityFilter
    /// Day, week or month. Remembered per device.
    private(set) var mode: ViewMode
    /// Any instant inside the period on screen.
    private(set) var focusedDate: Date
    /// The interval whose events are loaded: exactly what the current view shows.
    private(set) var loadedInterval: DateInterval?
    /// Month view: the weeks of the month.
    private(set) var weeks: [WeekLayout] = []
    /// Week and day views: the columns, their all-day lanes and each column's timed events.
    private(set) var gridDays: [Date] = []
    private(set) var allDaySegments: [SpanSegment] = []
    private(set) var placements: [[TimedPlacement]] = []
    /// The day view on a narrow detail column hands its month navigator to the sidebar.
    var dayNavigatorInSidebar = false
    /// Demo mode freezes the clock so screenshots compare; otherwise `nil` and the real time is used.
    private let fixedNow: Date?

    /// Any instant inside the month on screen (the month view's name for the focused date).
    var month: Date { focusedDate }

    init(store: CalendarStore, defaults: UserDefaults = .standard,
         calendar: Calendar = .current, now: Date = Date(), clockIsFixed: Bool = false,
         stagedScreens: Set<String> = []) {
        self.stagedScreens = stagedScreens
        self.store = store
        self.defaults = defaults
        self.calendar = calendar
        self.today = calendar.startOfDay(for: now)
        self.focusedDate = now
        self.fixedNow = clockIsFixed ? now : nil
        self.mode = defaults.string(forKey: Self.viewModeKey).flatMap(ViewMode.init(rawValue:)) ?? .month
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
        let interval = Period.interval(mode, containing: focusedDate, calendar: calendar)
        loadedInterval = interval
        var events: [EventInfo] = []
        if access == .granted {
            let visible = filter.visibleIDs(among: Set(calendars.map(\.id)))
            events = store.events(in: interval, calendarIDs: visible)
        }
        if mode == .month {
            weeks = MonthLayout.layout(month: focusedDate, events: events, calendar: calendar)
            gridDays = []
            allDaySegments = []
            placements = []
        } else {
            weeks = []
            gridDays = Period.days(in: interval, calendar: calendar)
            allDaySegments = TimeGridLayout.allDaySegments(days: gridDays, events: events, calendar: calendar)
            placements = gridDays.map {
                TimeGridLayout.layout(day: $0, events: events, calendar: calendar,
                                      minimumDuration: Self.minimumBlockDuration)
            }
        }
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

    func step(by count: Int) {
        focusedDate = Period.step(mode, from: focusedDate, by: count, calendar: calendar)
        reload()
    }

    func goToToday() {
        focusedDate = today
        todayRequests += 1
        reload()
    }

    /// Switches the view. When today is in the period on screen, the new view shows today.
    func setMode(_ newMode: ViewMode) {
        guard newMode != mode else { return }
        if let loadedInterval, loadedInterval.start <= today, today < loadedInterval.end {
            focusedDate = today
        }
        mode = newMode
        defaults.set(newMode.rawValue, forKey: Self.viewModeKey)
        reload()
    }

    /// Opens the day view on `day`.
    func show(day: Date) {
        focusedDate = calendar.startOfDay(for: day)
        mode = .day
        defaults.set(ViewMode.day.rawValue, forKey: Self.viewModeKey)
        reload()
    }

    /// The current instant: frozen in demo mode, `clock` otherwise.
    func now(_ clock: Date) -> Date { fixedNow ?? clock }

    /// Changes whenever a view should scroll back to its opening position (today's week, the current hour).
    var scrollKey: String {
        let start = loadedInterval?.start ?? focusedDate
        return "\(mode.rawValue)-\(start.timeIntervalSinceReferenceDate)-\(todayRequests)"
    }

    /// Everything planned on `day`, all-day and multi-day events first. Covers the days on screen.
    func events(on day: Date) -> [EventInfo] {
        if let column = gridDays.firstIndex(of: day) {
            let spans = allDaySegments
                .filter { $0.startColumn <= column && column <= $0.endColumn }
                .sorted { $0.lane < $1.lane }
                .map(\.event)
            let timed = column < placements.count ? placements[column].map(\.event) : []
            return spans + timed.sorted { ($0.start, $0.title) < ($1.start, $1.title) }
        }
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
