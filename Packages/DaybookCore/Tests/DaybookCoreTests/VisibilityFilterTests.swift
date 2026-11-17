import Foundation
import Testing
@testable import DaybookCore

@Suite struct VisibilityFilterTests {
    let all: Set<String> = ["work", "home", "family"]

    @Test func everythingIsVisibleByDefault() {
        let filter = VisibilityFilter()
        #expect(filter.visibleIDs(among: all) == all)
        #expect(filter.isVisible("work"))
    }

    @Test func toggleHidesThenShows() {
        var filter = VisibilityFilter()
        filter.toggle("home")
        #expect(!filter.isVisible("home"))
        #expect(filter.visibleIDs(among: all) == ["work", "family"])
        filter.toggle("home")
        #expect(filter.isVisible("home"))
    }

    @Test func showOnlyHidesEveryOtherCalendar() {
        var filter = VisibilityFilter()
        filter.showOnly("family", among: all)
        #expect(filter.visibleIDs(among: all) == ["family"])
    }

    @Test func showAllClearsHidden() {
        var filter = VisibilityFilter(hiddenIDs: ["work", "home"])
        filter.showAll()
        #expect(filter.visibleIDs(among: all) == all)
    }

    @Test func hiddenIDsOfDeletedCalendarsDoNotLeakIntoVisible() {
        let filter = VisibilityFilter(hiddenIDs: ["gone"])
        #expect(filter.visibleIDs(among: all) == all)
    }

    @Test func roundTripsThroughStoredArray() {
        let filter = VisibilityFilter(hiddenIDs: ["work", "home"])
        let restored = VisibilityFilter(storedValue: filter.storedValue)
        #expect(restored == filter)
        #expect(filter.storedValue == ["home", "work"])
    }
}
