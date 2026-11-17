import DaybookCore
import SwiftUI

@main
struct DaybookApp: App {
    @State private var model: AppModel

    init() {
        let calendar = Calendar.current
        #if DEBUG
        // Debug builds only: synthetic data on a fixed date, with optional staged states for screenshots.
        //   -demo-off        one calendar switched off
        //   -demo-day        the day list open on today (narrow columns)
        //   -demo-calendars  the calendars sheet open (compact width)
        //   -demo-denied     calendar access refused
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-demo") {
            let now = calendar.date(from: DateComponents(year: 2026, month: 11, day: 17, hour: 10)) ?? Date()
            let defaults = UserDefaults(suiteName: "app.daybook.demo") ?? .standard
            defaults.set(arguments.contains("-demo-off") ? ["demo-work"] : [], forKey: AppModel.hiddenCalendarsKey)
            let store = InMemoryCalendarStore(calendars: DemoData.calendars,
                                              events: DemoData.events(month: now, calendar: calendar),
                                              access: arguments.contains("-demo-denied") ? .denied : .granted)
            var staged: Set<String> = []
            if arguments.contains("-demo-day") { staged.insert("day") }
            if arguments.contains("-demo-calendars") { staged.insert("calendars") }
            _model = State(initialValue: AppModel(store: store, defaults: defaults, calendar: calendar,
                                                  now: now, stagedScreens: staged))
            return
        }
        #endif
        _model = State(initialValue: AppModel(store: EventKitCalendarStore(), calendar: calendar))
    }

    var body: some Scene {
        #if os(macOS)
        WindowGroup { content }
            .defaultSize(width: 1280, height: 860)
        #else
        WindowGroup { content }
        #endif
    }

    private var content: some View {
        RootView()
            .environment(model)
            .task { model.start() }
    }
}
