import DaybookCore
import SwiftUI
#if os(macOS)
import AppKit
#endif

@main
struct DaybookApp: App {
    @State private var model: AppModel
    /// Debug demo only: forces one appearance so screenshots do not touch the system setting.
    private let demoColorScheme: ColorScheme?
    /// Debug demo only: the window size the direction contract's first viewport describes.
    private let demoWindowSize: CGSize?

    init() {
        #if DEBUG
        DemoStaging.forceLocale(ProcessInfo.processInfo.arguments)
        #endif
        let calendar = Calendar.current
        #if DEBUG
        // Debug builds only: synthetic data on a fixed date, with optional staged states for screenshots.
        //   -demo-off        one calendar switched off
        //   -demo-day        the day list open on today (narrow columns)
        //   -demo-calendars  the calendars sheet open (compact width)
        //   -demo-denied     calendar access refused
        //   -demo-week, -demo-day-view  open the week or day view (the month otherwise)
        //   -demo-light, -demo-dark  force that appearance
        //   -demo-detail, -demo-detail-readonly, -demo-delete, -demo-editor-new, -demo-editor-edit,
        //   -demo-new-calendar, -demo-calendar-color  editing states (see DemoStaging)
        //   -demo-category-off       the category Porady switched off
        //   -demo-uncategorized-off  "Bez kategorie" switched off
        //   -demo-icloud-unavailable the sync line's iCloud-unavailable state
        //   -demo-categories, -demo-category-editor, -demo-category-delete, -demo-editor-categories,
        //   -demo-detail-categories  category states (see DemoStaging)
        // On the Mac the demo window opens at 1440 x 900.
        //   -demo-first-run          access not asked yet (the first-run screen)
        //   -demo-no-accounts        access granted, but the system has no calendars
        //   -demo-search, -demo-search-empty, -demo-search-none  search states (see DemoStaging)
        //   -demo-scrolled           the month scrolled across its end into the next month
        //   -demo-locale <id>        the app in another language, e.g. -demo-locale en
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-demo") {
            let now = calendar.date(from: DateComponents(year: 2026, month: 11, day: 17, hour: 10)) ?? Date()
            let defaults = UserDefaults(suiteName: "app.daybook.demo") ?? .standard
            defaults.set(arguments.contains("-demo-off") ? ["demo-work"] : [], forKey: AppModel.hiddenCalendarsKey)
            var categoryFilter = CategoryFilter()
            if arguments.contains("-demo-category-off") { categoryFilter.toggle(DemoData.meetingsCategoryID) }
            if arguments.contains("-demo-uncategorized-off") { categoryFilter.toggleUncategorized() }
            defaults.set(categoryFilter.storedValue, forKey: CategoryModel.filterKey)
            let mode: ViewMode = arguments.contains("-demo-week") ? .week
                : arguments.contains("-demo-day-view") ? .day : .month
            defaults.set(mode.rawValue, forKey: AppModel.viewModeKey)
            let access: CalendarAccess = arguments.contains("-demo-denied") ? .denied
                : arguments.contains("-demo-first-run") ? .notDetermined : .granted
            let store = arguments.contains("-demo-no-accounts")
                ? InMemoryCalendarStore(calendars: [], events: [], access: access, calendar: calendar)
                : DemoData.store(month: now, calendar: calendar, access: access)
            var staged: Set<String> = []
            if arguments.contains("-demo-day") { staged.insert("day") }
            if arguments.contains("-demo-calendars") { staged.insert("calendars") }
            staged.formUnion(DemoStaging.screens(in: arguments))
            defaults.removeObject(forKey: AppModel.lastCalendarKey)
            // Demo categories live in memory only, never in the on-disk store.
            let categoryStore = DemoData.categoryStore(
                month: now, calendar: calendar,
                syncState: arguments.contains("-demo-icloud-unavailable") ? .iCloudUnavailable : .localOnly)
            let model = AppModel(store: store, categoryStore: categoryStore, defaults: defaults, calendar: calendar,
                                 now: now, clockIsFixed: true, stagedScreens: staged)
            model.detailRequest = DemoStaging.detail(for: staged, today: model.today, calendar: calendar)
                .map { DetailRequest(key: $0.key, asksDelete: $0.asksDelete) }
            _model = State(initialValue: model)
            demoColorScheme = arguments.contains("-demo-light") ? .light
                : arguments.contains("-demo-dark") ? .dark : nil
            demoWindowSize = CGSize(width: 1440, height: 900)
            return
        }
        #endif
        _model = State(initialValue: AppModel(store: EventKitCalendarStore(), categoryStore: CategoryContainer.makeStore(),
                                              calendar: calendar))
        demoColorScheme = nil
        demoWindowSize = nil
    }

    var body: some Scene {
        #if os(macOS)
        WindowGroup { content }
            .defaultSize(width: 1280, height: 860)
            .commands { ViewCommands(model: model) }
        #else
        WindowGroup { content }
            .commands { ViewCommands(model: model) }
        #endif
    }

    private var content: some View {
        RootView()
            .environment(model)
            .environment(model.categoryModel)
            .preferredColorScheme(demoColorScheme)
            #if DEBUG && os(macOS)
            .background { if let demoWindowSize { DemoWindowFrame(size: demoWindowSize) } }
            #endif
            .task { model.start() }
    }
}

#if DEBUG && os(macOS)
/// Debug demo only: puts the window at a fixed size, whatever size was restored, so Mac captures compare.
private struct DemoWindowFrame: NSViewRepresentable {
    let size: CGSize

    func makeNSView(context: Context) -> NSView { Sizer(size: size) }
    func updateNSView(_ nsView: NSView, context: Context) {}

    final class Sizer: NSView {
        let size: CGSize

        init(size: CGSize) {
            self.size = size
            super.init(frame: .zero)
        }

        required init?(coder: NSCoder) { nil }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let window else { return }
            let size = size
            DispatchQueue.main.async {
                window.setFrame(NSRect(origin: window.frame.origin, size: size), display: true)
                window.center()
            }
        }
    }
}
#endif
