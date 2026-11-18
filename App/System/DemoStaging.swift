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
///   -demo-categories       iPhone: the calendars sheet, full height, scrolled to the categories
///   -demo-category-editor  the sheet editing the category "Děti"
///   -demo-category-delete  the question before deleting the category "Porady"
///   -demo-editor-categories  the event editor on the series' occurrence, its categories page open
///   -demo-detail-categories  the detail of the read-only "Odstávka DB", categories open for editing
///   -demo-search           search open with "ockovani" (finds "Očkování Ema", past and future)
///   -demo-search-empty     search open, nothing typed
///   -demo-search-none      search for a word nothing contains (with -demo-category-off the toggle shows)
///   -demo-scrolled         the month scrolled so December owns the viewport
enum DemoStaging {
    static let names = ["detail", "detail-readonly", "delete", "editor-new", "editor-edit",
                        "new-calendar", "calendar-color", "categories", "category-editor", "category-delete",
                        "editor-categories", "detail-categories", "search", "search-empty", "search-none",
                        "scrolled"]

    /// `-demo-locale <id>`: runs the app in that language and region for captures. The languages go into
    /// the arguments domain, which is never written to disk, before anything has read them.
    static func forceLocale(_ arguments: [String]) {
        guard let index = arguments.lastIndex(of: "-demo-locale"), index + 1 < arguments.count else { return }
        let id = arguments[index + 1]
        let defaults = UserDefaults.standard
        var domain = defaults.volatileDomain(forName: UserDefaults.argumentDomain)
        domain["AppleLanguages"] = [id]
        // A language alone leaves the region to the device; captures pin it so weeks start on Monday.
        domain["AppleLocale"] = ["en": "en_GB", "cs": "cs_CZ"][id] ?? id
        defaults.setVolatileDomain(domain, forName: UserDefaults.argumentDomain)
    }

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
        if screens.contains("detail-categories"),
           let start = calendar.date(bySettingHour: 14, minute: 0, second: 0, of: today) {
            return (EventKey(externalID: DemoData.readOnlyCategorizedEventID, occurrenceStart: start), false)
        }
        return nil
    }
}

extension AppModel {
    /// Opens the staged editors once the app is on screen.
    func stageDemoScreens() async {
        guard !stagedScreens.isDisjoint(with: ["editor-new", "editor-edit", "editor-categories", "new-calendar",
                                               "calendar-color", "search", "search-empty", "search-none"]) else {
            return
        }
        try? await Task.sleep(for: .milliseconds(900))
        if stagedScreens.contains("search") { search.query = "ockovani" }
        if stagedScreens.contains("search-none") { search.query = "kokos" }
        if !stagedScreens.isDisjoint(with: ["search", "search-empty", "search-none"]) { search.wantsFocus = true }
        if stagedScreens.contains("editor-new") { beginNewEvent() }
        if !stagedScreens.isDisjoint(with: ["editor-edit", "editor-categories"]), let key = DemoStaging.seriesKey(today: today, calendar: calendar) {
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

    /// Opens the staged category sheet or question once the sidebar is on screen.
    func stageCategoryScreens() async {
        guard !stagedScreens.isDisjoint(with: ["category-editor", "category-delete"]) else { return }
        try? await Task.sleep(for: .milliseconds(900))
        let all = categoryModel.categories
        if stagedScreens.contains("category-editor"), let children = all.first(where: { $0.id == DemoData.childrenCategoryID }) {
            categoryModel.beginEditing(children)
        }
        if stagedScreens.contains("category-delete"), let meetings = all.first(where: { $0.id == DemoData.meetingsCategoryID }) {
            categoryModel.pendingDelete = meetings
        }
    }
}
#endif
