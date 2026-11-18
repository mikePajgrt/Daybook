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
///   -demo-rail-collapsed     iPad and Mac: the rail hidden, the calendar full width
///   -demo-scrolled-end       the month scrolled to the end of its window of seven months
///   -demo-editor-allday      the editor for a new event with "Celý den" on
///   -demo-occurrence-categories  the series' occurrence on the 16th, its categories page on "Jen tato událost"
///   -demo-detail-attendees   the detail of "Návrh API" scrolled to its attendees
///   -demo-delete-single      the detail of "Návrh API" asking whether to delete it (not recurring)
///   -demo-discard            the editor on the series' occurrence with a changed title, Cancel tapped
///   -demo-invite             iOS: the editor on the series' occurrence, "Pozvat účastníky" tapped
///                            (demo events are not in the system calendar, so its alert follows)
///   -demo-save-failure       the editor on "Návrh API" saved after the event was deleted elsewhere
///   -demo-category-error     "Cestování" deleted elsewhere, then deleted here: the store refuses
///   -demo-search-query <q>   search open with that query (instead of "ockovani")
///   -demo-search-hidden      search with "Hledat i ve vypnutých" on
///   -demo-search-past        search results scrolled to the first past day
enum DemoStaging {
    static let names = ["detail", "detail-readonly", "delete", "editor-new", "editor-edit",
                        "new-calendar", "calendar-color", "categories", "category-editor", "category-delete",
                        "editor-categories", "detail-categories", "search", "search-empty", "search-none",
                        "scrolled", "rail-collapsed", "scrolled-end", "editor-allday", "occurrence-categories",
                        "detail-attendees", "delete-single", "discard", "invite", "save-failure",
                        "category-error", "search-hidden", "search-past"]

    /// The value after `flag` among the launch arguments, e.g. `-demo-search-query retro`.
    static func value(after flag: String, in arguments: [String] = ProcessInfo.processInfo.arguments) -> String? {
        guard let index = arguments.lastIndex(of: flag), index + 1 < arguments.count else { return nil }
        return arguments[index + 1]
    }

    /// The detailed event, "Návrh API", on the demo day.
    static func detailedKey(today: Date, calendar: Calendar) -> EventKey? {
        calendar.date(bySettingHour: 13, minute: 0, second: 0, of: today)
            .map { EventKey(externalID: DemoData.detailedEventID, occurrenceStart: $0) }
    }

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
        if !screens.isDisjoint(with: ["detail", "detail-attendees"]), let key = detailedKey(today: today, calendar: calendar) {
            return (key, false)
        }
        if screens.contains("delete-single"), let key = detailedKey(today: today, calendar: calendar) {
            return (key, true)
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
                                               "calendar-color", "search", "search-empty", "search-none",
                                               "editor-allday", "occurrence-categories", "discard", "invite",
                                               "save-failure"]) else {
            return
        }
        try? await Task.sleep(for: .milliseconds(900))
        if stagedScreens.contains("search") { search.query = DemoStaging.value(after: "-demo-search-query") ?? "ockovani" }
        if stagedScreens.contains("search-none") { search.query = "kokos" }
        if stagedScreens.contains("search-hidden") { search.includesHidden = true }
        if !stagedScreens.isDisjoint(with: ["search", "search-empty", "search-none"]) { search.wantsFocus = true }
        if stagedScreens.contains("editor-new") { beginNewEvent() }
        if stagedScreens.contains("editor-allday") {
            beginNewEvent()
            editor?.isAllDay = true
        }
        if !stagedScreens.isDisjoint(with: ["editor-edit", "editor-categories", "occurrence-categories", "discard", "invite"]),
           let key = DemoStaging.seriesKey(today: today, calendar: calendar), let event = demoEvent(key) {
            beginEditing(event)
            if stagedScreens.contains("occurrence-categories") { editor?.categoryScope = .occurrence }
        }
        if stagedScreens.contains("save-failure"), let key = DemoStaging.detailedKey(today: today, calendar: calendar),
           let event = demoEvent(key) {
            // The real path: the title changes in the editor while another device deletes the event, then Save.
            beginEditing(event)
            try? await Task.sleep(for: .milliseconds(900))
            editor?.draft.title = "Návrh API a stránkování"
            try? store.deleteEvent(event, span: .thisEvent)
            if let editor { _ = save(editor) }
        }
        if stagedScreens.contains("new-calendar") { beginNewCalendar() }
        if stagedScreens.contains("calendar-color"), let personal = calendarInfo("demo-home") {
            beginRecoloring(personal)
        }
    }

    /// The demo store's event with `key`, read from its day.
    private func demoEvent(_ key: EventKey) -> EventInfo? {
        let day = DateInterval(start: calendar.startOfDay(for: key.occurrenceStart), duration: 86_400)
        return store.events(in: day, calendarIDs: Set(calendars.map(\.id))).first { $0.key == key }
    }

    /// Opens the staged category sheet or question once the sidebar is on screen.
    func stageCategoryScreens() async {
        guard !stagedScreens.isDisjoint(with: ["category-editor", "category-delete", "category-error"]) else { return }
        try? await Task.sleep(for: .milliseconds(900))
        let all = categoryModel.categories
        if stagedScreens.contains("category-editor"), let children = all.first(where: { $0.id == DemoData.childrenCategoryID }) {
            categoryModel.beginEditing(children)
        }
        if stagedScreens.contains("category-delete"), let meetings = all.first(where: { $0.id == DemoData.meetingsCategoryID }) {
            categoryModel.pendingDelete = meetings
        }
        if stagedScreens.contains("category-error"), let travel = all.first(where: { $0.name == "Cestování" }) {
            // The real path: another device deletes the category, then this one deletes it too.
            try? categoryModel.store.deleteCategory(travel.id)
            categoryModel.delete(travel)
        }
    }
}
#endif
