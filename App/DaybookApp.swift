import DaybookCore
import SwiftUI

@main
struct DaybookApp: App {
    @State private var model: AppModel

    init() {
        let calendar = Calendar.current
        if ProcessInfo.processInfo.arguments.contains("-demo") {
            let now = calendar.date(from: DateComponents(year: 2026, month: 11, day: 17, hour: 10)) ?? Date()
            _model = State(initialValue: AppModel(store: DemoData.store(month: now, calendar: calendar),
                                                  defaults: UserDefaults(suiteName: "app.daybook.demo") ?? .standard,
                                                  calendar: calendar, now: now))
        } else {
            _model = State(initialValue: AppModel(store: EventKitCalendarStore(), calendar: calendar))
        }
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
        Text("Daybook: \(model.weeks.count) týdnů, \(model.calendars.count) kalendářů")
            .foregroundStyle(Theme.ink)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.ground)
            .task { model.start() }
    }
}
