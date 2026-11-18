import DaybookCore
import Foundation
import Observation
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

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

/// A message the app shows in an alert: a refused action or a failed write outside an editor.
struct Notice: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

/// Asks the view showing `key` to open its detail (after a search, or a debug staging).
struct DetailRequest: Equatable {
    let id = UUID()
    let key: EventKey
    var asksDelete = false
}

/// An event whose detail opens as a sheet over everything: a search result the filter hides.
struct DetachedDetail: Identifiable {
    let event: EventInfo
    var id: EventKey { event.key }
}

@MainActor
@Observable
final class AppModel {
    static let lastCalendarKey = "lastCalendarID"
    static let hiddenCalendarsKey = "hiddenCalendarIDs"
    static let viewModeKey = "viewMode"
    /// For overlap, a timed event lasts at least this long: blocks are never drawn shorter.
    static let minimumBlockDuration: TimeInterval = 30 * 60
    /// Months either side of the focused one that the month view scrolls through.
    static let monthRadius = 3

    let calendar: Calendar
    /// Today's local midnight. Rolls over at midnight and after a clock or time-zone change.
    private(set) var today: Date
    /// Screens a debug demo launch asks to open straight away, for screenshots.
    let stagedScreens: Set<String>
    /// Bumped by "Dnes", so the month scrolls back to today even when it is already on screen.
    private(set) var todayRequests = 0
    let store: CalendarStore
    let defaults: UserDefaults
    /// Categories: Daybook's own data, kept outside the calendar database.
    let categoryModel: CategoryModel
    /// Search across five years back and forward.
    let search: SearchModel
    private var watcher: Task<Void, Never>?
    private var categoryWatcher: Task<Void, Never>?
    private var clockObservers: [NSObjectProtocol] = []

    private(set) var access: CalendarAccess
    private(set) var calendars: [CalendarInfo] = []
    private(set) var filter: VisibilityFilter
    /// Day, week or month. Remembered per device.
    private(set) var mode: ViewMode
    /// Any instant inside the period on screen. In the month it follows the month that owns the viewport.
    private(set) var focusedDate: Date
    /// The period on screen: the day, the week, or the full weeks of the month on screen.
    private(set) var loadedInterval: DateInterval?
    /// Month view: the first and last month of the window of months that scrolls as one column.
    private(set) var monthWindow: (first: Date, last: Date)
    /// The month the window was last centred on by navigation; the month view opens on it.
    private(set) var windowCenter: Date
    /// Bumped whenever navigation re-centres the month, so the month view scrolls to `windowCenter`.
    private(set) var windowRevision = 0
    /// Month view: the weeks of the window.
    private(set) var weeks: [WeekLayout] = []
    /// Week and day views: the columns, their all-day lanes and each column's timed events.
    private(set) var gridDays: [Date] = []
    private(set) var allDaySegments: [SpanSegment] = []
    private(set) var placements: [[TimedPlacement]] = []
    /// Bumped by every calendar or category switch. Under Reduce Motion the views crossfade on it.
    private(set) var filterRevision = 0
    /// The event editor on screen, if any. Its form state lives in the editor model.
    var editor: EventEditorModel?
    /// The editor opened from the iPhone day sheet and is shown on top of it, not from the root.
    var editorInDaySheet = false
    /// The new-calendar or calendar-colour sheet on screen, if any.
    var calendarEditor: CalendarEditorModel?
    /// The detail a view should open by itself (a chosen search result, a debug staging).
    var detailRequest: DetailRequest?
    /// A detail shown as a sheet from the root, for an event no view on screen shows.
    var detachedDetail: DetachedDetail?
    /// An alert about a refused action or a failed write outside an editor.
    var notice: Notice?

    /// The day view on a narrow detail column hands its month navigator to the sidebar.
    var dayNavigatorInSidebar = false
    /// Demo mode freezes the clock so screenshots compare; otherwise `nil` and the real time is used.
    private let fixedNow: Date?

    /// Every event of every calendar in `cached.interval`, read off the main thread.
    private var cached: (interval: DateInterval, events: [EventInfo])?
    /// The database changed since the cache was read.
    private var cacheIsStale = true
    private var loading: Task<Void, Never>?
    private var loadingInterval: DateInterval?

    /// Any instant inside the month on screen (the month view's name for the focused date).
    var month: Date { focusedDate }

    init(store: CalendarStore, categoryStore: CategoryStore, defaults: UserDefaults = .standard,
         calendar: Calendar = .current, now: Date = Date(), clockIsFixed: Bool = false,
         stagedScreens: Set<String> = []) {
        self.stagedScreens = stagedScreens
        self.store = store
        self.defaults = defaults
        self.calendar = calendar
        self.today = calendar.startOfDay(for: now)
        self.focusedDate = now
        self.windowCenter = now
        self.monthWindow = MonthLayout.window(around: now, radius: Self.monthRadius, calendar: calendar)
        self.fixedNow = clockIsFixed ? now : nil
        self.mode = defaults.string(forKey: Self.viewModeKey).flatMap(ViewMode.init(rawValue:)) ?? .month
        self.access = store.access
        self.filter = VisibilityFilter(storedValue: defaults.stringArray(forKey: Self.hiddenCalendarsKey) ?? [])
        self.categoryModel = CategoryModel(store: categoryStore, defaults: defaults)
        self.search = SearchModel()
        search.app = self
        categoryModel.onChange = { [weak self] in self?.filterChanged() }
        categoryModel.onNotice = { [weak self] in self?.notice = $0 }
    }

    /// Set once `start()` ran: before it, an empty calendar list only means nothing was read yet.
    private(set) var didStart = false

    /// Lays out the first period at once, loads its events, and keeps up with the database and the clock.
    func start() {
        reload()
        didStart = true
        watchClock()
        guard watcher == nil else { return }
        watcher = Task { [weak self] in
            guard let changes = self?.store.changes else { return }
            for await _ in changes {
                self?.reload()
                self?.search.databaseChanged()
            }
        }
        categoryWatcher = Task { [weak self] in
            guard let changes = self?.categoryModel.store.changes else { return }
            for await _ in changes {
                self?.categoryModel.reload()
                self?.refresh()
                self?.search.filterChanged()
            }
        }
    }

    func requestAccess() async {
        access = await store.requestAccess()
        reload()
    }

    // MARK: - Loading

    /// The database may have changed: lays out what is cached at once, then reads again off the main thread.
    func reload() {
        cacheIsStale = true
        refresh()
    }

    /// Lays out the period on screen from the cache, synchronously, so switches and navigation draw at once.
    /// Reads off the main thread when the cache does not cover what is needed or is stale; the grid is drawn
    /// meanwhile and the events fill in.
    func refresh() {
        update(\.access, to: store.access)
        update(\.calendars, to: access == .granted ? store.calendars() : [])
        let period = Period.interval(mode, containing: focusedDate, calendar: calendar)
        update(\.loadedInterval, to: period)
        let needed = mode == .month ? MonthLayout.interval(of: monthWindow, calendar: calendar) : period
        layout()
        guard access == .granted else { return }
        let covered = cached.map { $0.interval.start <= needed.start && needed.end <= $0.interval.end } ?? false
        if !covered || cacheIsStale {
            // Read the whole window around the focused month, so stepping within it needs no new read.
            let around = MonthLayout.interval(of: MonthLayout.window(around: focusedDate, radius: Self.monthRadius,
                                                                     calendar: calendar), calendar: calendar)
            let interval = DateInterval(start: min(around.start, needed.start), end: max(around.end, needed.end))
            load(interval)
        }
    }

    private func load(_ interval: DateInterval) {
        if loading != nil, loadingInterval == interval, !cacheIsStale { return }
        loading?.cancel()
        loadingInterval = interval
        cacheIsStale = false
        let read = store.reader()
        loading = Task { [weak self] in
            let events = await Task.detached(priority: .userInitiated) { read(interval) }.value
            guard !Task.isCancelled, let self else { return }
            self.cached = (interval, events)
            self.loading = nil
            self.loadingInterval = nil
            self.layout()
        }
    }

    /// The events of the period on screen, after the calendar and category filters.
    private func visibleEvents(in interval: DateInterval) -> [EventInfo] {
        guard access == .granted, let cached else { return [] }
        let inside = cached.events.filter {
            ($0.start < interval.end && $0.end > interval.start) || ($0.start == $0.end && interval.contains($0.start))
        }
        // Categories filter before any layout, so rows close up and grids re-lay-out.
        return filter.visibleEvents(inside, categories: categoryModel.filter, assignments: categoryModel.assignments,
                                    known: categoryModel.knownIDs)
    }

    /// Whether `event` passes the calendar and category filters.
    func isVisible(_ event: EventInfo) -> Bool {
        filter.isVisible(event.calendarID)
            && (!categoryModel.filter.isFiltering
                || categoryModel.filter.isVisible(categoryIDs: categoryModel.assignments.categoryIDs(for: event.key),
                                                  known: categoryModel.knownIDs))
    }

    /// Only values that changed are assigned, so a layout that finds nothing new redraws nothing.
    private func layout() {
        if mode == .month {
            let weeksOfWindow = MonthLayout.weeks(fromMonth: monthWindow.first, throughMonth: monthWindow.last,
                                                  calendar: calendar)
            let interval = MonthLayout.interval(of: monthWindow, calendar: calendar)
            update(\.weeks, to: MonthLayout.layout(weeks: weeksOfWindow, month: windowCenter,
                                                   events: visibleEvents(in: interval), calendar: calendar))
            update(\.gridDays, to: [])
            update(\.allDaySegments, to: [])
            update(\.placements, to: [])
        } else {
            let interval = loadedInterval ?? Period.interval(mode, containing: focusedDate, calendar: calendar)
            let events = visibleEvents(in: interval)
            let days = Period.days(in: interval, calendar: calendar)
            update(\.weeks, to: [])
            update(\.gridDays, to: days)
            update(\.allDaySegments, to: TimeGridLayout.allDaySegments(days: days, events: events, calendar: calendar))
            update(\.placements, to: days.map {
                TimeGridLayout.layout(day: $0, events: events, calendar: calendar,
                                      minimumDuration: Self.minimumBlockDuration)
            })
        }
    }

    private func update<Value: Equatable>(_ path: ReferenceWritableKeyPath<AppModel, Value>, to value: Value) {
        if self[keyPath: path] != value { self[keyPath: path] = value }
    }

    // MARK: - Clock

    /// Today follows the clock: at midnight, after a clock or time-zone change, and on return to the app.
    private func watchClock() {
        guard fixedNow == nil, clockObservers.isEmpty else { return }
        var names: [Notification.Name] = [.NSCalendarDayChanged, .NSSystemClockDidChange, .NSSystemTimeZoneDidChange]
        #if canImport(UIKit)
        names += [UIApplication.significantTimeChangeNotification, UIApplication.didBecomeActiveNotification]
        #else
        names += [NSApplication.didBecomeActiveNotification]
        #endif
        clockObservers = names.map { name in
            NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.clockChanged() }
            }
        }
    }

    func clockChanged() {
        guard fixedNow == nil else { return }
        let newToday = calendar.startOfDay(for: Date())
        guard newToday != today else { return }
        today = newToday
        search.filterChanged()
        refresh()
    }

    // MARK: - Calendars

    private static let kindOrder: [SourceKind] = [.icloud, .exchange, .google, .local, .subscribed, .other]

    var sections: [CalendarSection] {
        Dictionary(grouping: calendars, by: \.sourceTitle)
            .map { title, items in
                CalendarSection(title: title.isEmpty ? String(localized: "Ostatní") : title,
                                calendars: items.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending })
            }
            .sorted { a, b in
                let ka = Self.kindOrder.firstIndex(of: a.calendars[0].sourceKind) ?? Self.kindOrder.count
                let kb = Self.kindOrder.firstIndex(of: b.calendars[0].sourceKind) ?? Self.kindOrder.count
                return (ka, a.title) < (kb, b.title)
            }
    }

    func calendarInfo(_ id: String) -> CalendarInfo? { calendars.first { $0.id == id } }

    /// The calendar's colour, or the fallback grey when it cannot be resolved.
    func color(of calendarID: String) -> RGBA { calendarInfo(calendarID)?.color ?? Theme.fallbackLine }

    /// What the filters hide right now, in sidebar order: switched-off calendars, then categories,
    /// then "Bez kategorie". Empty when everything is shown.
    var hiddenNames: [String] {
        let calendarNames = sections.flatMap(\.calendars).filter { !filter.isVisible($0.id) }.map(\.title)
        let categoryNames = categoryModel.categories.filter { !categoryModel.filter.isOn($0.id) }.map(\.name)
        let uncategorized = categoryModel.filter.showsUncategorized ? [] : [CategoryText.uncategorized]
        return calendarNames + categoryNames + uncategorized
    }

    func toggle(_ calendar: CalendarInfo) { updateFilter { $0.toggle(calendar.id) } }

    func showOnly(_ calendar: CalendarInfo) {
        let all = Set(calendars.map(\.id))
        updateFilter { $0.showOnly(calendar.id, among: all) }
    }

    func showAll() { updateFilter { $0.showAll() } }

    private func updateFilter(_ change: (inout VisibilityFilter) -> Void) {
        change(&filter)
        defaults.set(filter.storedValue, forKey: Self.hiddenCalendarsKey)
        filterChanged()
    }

    /// A calendar or category was switched: its lines leave every day at once and the rows close up,
    /// with the system's default spring (a crossfade under Reduce Motion).
    private func filterChanged() {
        withAnimation(Motion.filterChange(reduceMotion: Motion.reduceMotion)) {
            filterRevision += 1
            refresh()
        }
        search.filterChanged()
    }

    // MARK: - Navigation

    func step(by count: Int) {
        focusedDate = Period.step(mode, from: focusedDate, by: count, calendar: calendar)
        recentre()
    }

    func goToToday() {
        focusedDate = fixedNow ?? Date()
        todayRequests += 1
        recentre()
    }

    /// Switches the view. When today is in the period on screen, the new view shows today.
    func setMode(_ newMode: ViewMode) {
        guard newMode != mode else { return }
        if let loadedInterval, loadedInterval.start <= today, today < loadedInterval.end {
            focusedDate = fixedNow ?? today
        }
        mode = newMode
        defaults.set(newMode.rawValue, forKey: Self.viewModeKey)
        recentre()
    }

    /// Opens the day view on `day`.
    func show(day: Date) {
        focusedDate = calendar.startOfDay(for: day)
        mode = .day
        defaults.set(ViewMode.day.rawValue, forKey: Self.viewModeKey)
        recentre()
    }

    /// Navigation: the month window is centred on the focused month again and the view scrolls there.
    private func recentre() {
        monthWindow = MonthLayout.window(around: focusedDate, radius: Self.monthRadius, calendar: calendar)
        windowCenter = focusedDate
        windowRevision += 1
        refresh()
    }

    /// The month view scrolled: the month owning most of the viewport becomes the period on screen
    /// (title, dimming, Today, back and forward), without moving the window under the user's finger.
    func scrolled(toMonth monthStart: Date) {
        guard mode == .month,
              calendar.dateInterval(of: .month, for: focusedDate)?.start != monthStart else { return }
        focusedDate = monthStart
        update(\.loadedInterval, to: Period.interval(.month, containing: monthStart, calendar: calendar))
    }

    /// The current instant: frozen in demo mode, `clock` otherwise.
    func now(_ clock: Date) -> Date { fixedNow ?? clock }

    /// Changes whenever a view should scroll back to its opening position (today's week, the current hour).
    var scrollKey: String {
        let start = mode == .month ? windowCenter : (loadedInterval?.start ?? focusedDate)
        return "\(mode.rawValue)-\(start.timeIntervalSinceReferenceDate)-\(todayRequests)-\(windowRevision)"
    }

    // MARK: - Search results

    /// Shows the event's day and opens its detail there; an event the filter hides opens as a sheet.
    func open(_ event: EventInfo) {
        show(day: event.start)
        if isVisible(event) {
            detailRequest = DetailRequest(key: event.key)
        } else {
            detachedDetail = DetachedDetail(event: event)
        }
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
