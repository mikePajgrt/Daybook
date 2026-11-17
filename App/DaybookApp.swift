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
        let calendar = Calendar.current
        #if DEBUG
        // Debug builds only: synthetic data on a fixed date, with optional staged states for screenshots.
        //   -demo-off        one calendar switched off
        //   -demo-day        the day list open on today (narrow columns)
        //   -demo-calendars  the calendars sheet open (compact width)
        //   -demo-denied     calendar access refused
        //   -demo-week, -demo-day-view  open the week or day view (the month otherwise)
        //   -demo-light, -demo-dark  force that appearance
        // On the Mac the demo window opens at 1440 x 900.
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-demo") {
            let now = calendar.date(from: DateComponents(year: 2026, month: 11, day: 17, hour: 10)) ?? Date()
            let defaults = UserDefaults(suiteName: "app.daybook.demo") ?? .standard
            defaults.set(arguments.contains("-demo-off") ? ["demo-work"] : [], forKey: AppModel.hiddenCalendarsKey)
            let mode: ViewMode = arguments.contains("-demo-week") ? .week
                : arguments.contains("-demo-day-view") ? .day : .month
            defaults.set(mode.rawValue, forKey: AppModel.viewModeKey)
            let store = InMemoryCalendarStore(calendars: DemoData.calendars,
                                              events: DemoData.events(month: now, calendar: calendar),
                                              access: arguments.contains("-demo-denied") ? .denied : .granted)
            var staged: Set<String> = []
            if arguments.contains("-demo-day") { staged.insert("day") }
            if arguments.contains("-demo-calendars") { staged.insert("calendars") }
            _model = State(initialValue: AppModel(store: store, defaults: defaults, calendar: calendar,
                                                  now: now, clockIsFixed: true, stagedScreens: staged))
            demoColorScheme = arguments.contains("-demo-light") ? .light
                : arguments.contains("-demo-dark") ? .dark : nil
            demoWindowSize = CGSize(width: 1440, height: 900)
            return
        }
        #endif
        _model = State(initialValue: AppModel(store: EventKitCalendarStore(), calendar: calendar))
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
