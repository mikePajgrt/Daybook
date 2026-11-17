#if DEBUG
import DaybookCore
import Foundation

/// Debug demo only: opens the editing screens by themselves, so screenshots can show them.
///
///   -demo-detail           the detail of "Návrh API" (17th)
///   -demo-detail-readonly  the detail of the public holiday (read-only calendar)
///   -demo-delete           the detail of the weekly series on the 16th, asking what to delete
///   -demo-editor-new       the editor for a new event
///   -demo-editor-edit      the editor for the weekly series' occurrence on the 16th
///   -demo-new-calendar     the new-calendar sheet (iPhone: with -demo-calendars)
///   -demo-calendar-color   the colour sheet for "Osobní"
enum DemoStaging {
    static let names = ["detail", "detail-readonly", "delete", "editor-new", "editor-edit",
                        "new-calendar", "calendar-color"]

    /// The staged screen names among the launch arguments.
    static func screens(in arguments: [String]) -> Set<String> {
        Set(names.filter { arguments.contains("-demo-\($0)") })
    }

    /// The occurrence of the weekly series on the Monday of the demo week (the 16th).
    static func seriesKey(today: Date, calendar: Calendar) -> EventKey? {
        guard let week = calendar.dateInterval(of: .weekOfYear, for: today),
              let start = calendar.date(bySettingHour: 8, minute: 30, second: 0, of: week.start) else { return nil }
        return EventKey(externalID: DemoData.seriesID, occurrenceStart: start)
    }

    /// Which event's detail opens by itself, and whether it asks to delete.
    static func detail(for screens: Set<String>, today: Date, calendar: Calendar) -> (key: EventKey, asksDelete: Bool)? {
        if screens.contains("detail"),
           let start = calendar.date(bySettingHour: 13, minute: 0, second: 0, of: today) {
            return (EventKey(externalID: DemoData.detailedEventID, occurrenceStart: start), false)
        }
        if screens.contains("detail-readonly") {
            return (EventKey(externalID: "demo-holiday", occurrenceStart: calendar.startOfDay(for: today)), false)
        }
        if screens.contains("delete"), let key = seriesKey(today: today, calendar: calendar) {
            return (key, true)
        }
        return nil
    }
}

extension AppModel {
    /// Opens the staged editors once the app is on screen.
    func stageDemoScreens() async {
        guard !stagedScreens.isDisjoint(with: ["editor-new", "editor-edit", "new-calendar", "calendar-color"]) else {
            return
        }
        try? await Task.sleep(for: .milliseconds(900))
        if stagedScreens.contains("editor-new") { beginNewEvent() }
        if stagedScreens.contains("editor-edit"), let key = DemoStaging.seriesKey(today: today, calendar: calendar) {
            let day = DateInterval(start: calendar.startOfDay(for: key.occurrenceStart), duration: 86_400)
            if let event = store.events(in: day, calendarIDs: Set(calendars.map(\.id))).first(where: { $0.key == key }) {
                beginEditing(event)
            }
        }
        if stagedScreens.contains("new-calendar") { beginNewCalendar() }
        if stagedScreens.contains("calendar-color"), let personal = calendarInfo("demo-home") {
            beginRecoloring(personal)
        }
    }
}
#endif
