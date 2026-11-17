import Foundation
import Testing
@testable import DaybookCore

@Suite struct CategoryFilterTests {
    let meeting = UUID()
    let health = UUID()
    var known: Set<UUID> { [meeting, health] }

    @Test func everythingIsVisibleByDefault() {
        let filter = CategoryFilter()
        #expect(filter.isVisible(categoryIDs: [], known: known))
        #expect(filter.isVisible(categoryIDs: [meeting], known: known))
        #expect(!filter.isFiltering)
    }

    @Test func aNewCategoryIsVisible() {
        var filter = CategoryFilter()
        filter.toggle(meeting)
        let added = UUID()
        #expect(filter.isVisible(categoryIDs: [added], known: known.union([added])))
        #expect(filter.isOn(added))
    }

    @Test func anEventShowsWhileOneOfItsCategoriesIsOn() {
        var filter = CategoryFilter()
        filter.toggle(meeting)
        #expect(!filter.isVisible(categoryIDs: [meeting], known: known))
        #expect(filter.isVisible(categoryIDs: [meeting, health], known: known))
        #expect(filter.isVisible(categoryIDs: [], known: known))
    }

    @Test func uncategorizedOffHidesOnlyEventsWithout() {
        var filter = CategoryFilter()
        filter.toggleUncategorized()
        #expect(!filter.isVisible(categoryIDs: [], known: known))
        #expect(filter.isVisible(categoryIDs: [health], known: known))
    }

    @Test func deletedCategoriesCountAsNone() {
        var filter = CategoryFilter()
        let deleted = UUID()
        #expect(filter.isVisible(categoryIDs: [deleted], known: known))
        filter.toggleUncategorized()
        #expect(!filter.isVisible(categoryIDs: [deleted], known: known))
    }

    @Test func showOnlyAndShowAll() {
        var filter = CategoryFilter()
        filter.showOnly(health, among: known)
        #expect(filter.isVisible(categoryIDs: [health], known: known))
        #expect(!filter.isVisible(categoryIDs: [meeting], known: known))
        #expect(!filter.isVisible(categoryIDs: [], known: known))
        filter.showOnlyUncategorized(among: known)
        #expect(filter.isVisible(categoryIDs: [], known: known))
        #expect(!filter.isVisible(categoryIDs: [health], known: known))
        filter.showAll()
        #expect(filter == CategoryFilter())
    }

    @Test func roundTripsThroughStoredValue() {
        var filter = CategoryFilter()
        filter.toggle(meeting)
        filter.toggleUncategorized()
        #expect(CategoryFilter(storedValue: filter.storedValue) == filter)
        #expect(CategoryFilter(storedValue: ["garbage"]) == CategoryFilter())
    }

    @Test func combinesWithTheCalendarFilter() {
        let start = TestCalendar.date(2026, 11, 17, 9)
        func event(_ id: String, _ calendarID: String) -> EventInfo {
            EventInfo(key: EventKey(externalID: id, occurrenceStart: start), calendarID: calendarID, title: id,
                      start: start, end: start.addingTimeInterval(3600), isAllDay: false)
        }
        var assignments = CategoryAssignments()
        assignments.assign(meeting, to: event("standup", "work").key, scope: .series)
        assignments.assign(health, to: event("dentist", "home").key, scope: .series)
        let events = [event("standup", "work"), event("dentist", "home"), event("lunch", "home"), event("call", "work")]
        var categories = CategoryFilter()
        categories.toggle(meeting)
        let calendars = VisibilityFilter(hiddenIDs: ["home"])
        let shown = calendars.visibleEvents(events, categories: categories, assignments: assignments, known: known)
        #expect(shown.map(\.title) == ["call"])
        let all = VisibilityFilter().visibleEvents(events, categories: CategoryFilter(), assignments: assignments, known: known)
        #expect(all.count == 4)
    }
}
