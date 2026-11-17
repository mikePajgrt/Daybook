import Foundation
import Testing
@testable import DaybookCore

@Suite struct SplitSeriesTests {
    typealias F = WriteFixture
    let meetings = UUID()
    let focus = UUID()
    let travel = UUID()

    @Test func seriesCategoriesAndLaterOccurrenceCategoriesCarryOver() {
        let split = F.d(2026, 11, 16, 8, 30)
        let assignments = CategoryAssignments([
            CategoryAssignment(categoryID: meetings, externalID: "old", occurrenceStart: nil),
            CategoryAssignment(categoryID: focus, externalID: "old", occurrenceStart: F.d(2026, 11, 9, 8, 30)),
            CategoryAssignment(categoryID: travel, externalID: "old", occurrenceStart: F.d(2026, 11, 23, 8, 30)),
            CategoryAssignment(categoryID: travel, externalID: "other", occurrenceStart: nil)
        ])
        let carried = assignments.carriedOver(from: "old", to: "new", splitAt: split)
        #expect(Set(carried) == [
            CategoryAssignment(categoryID: meetings, externalID: "new", occurrenceStart: nil),
            CategoryAssignment(categoryID: travel, externalID: "new", occurrenceStart: F.d(2026, 11, 23, 8, 30))
        ])
        #expect(assignments.carriedOver(from: "old", to: "old", splitAt: split).isEmpty)
        #expect(assignments.carriedOver(from: "none", to: "new", splitAt: split).isEmpty)
    }

    @Test func storeCopiesTheCategoriesToTheNewSeries() throws {
        let category = Category(id: meetings, name: "Porady", symbol: "person.2", order: 0)
        let store = InMemoryCategoryStore(categories: [category],
                                          assignments: [CategoryAssignment(categoryID: meetings, externalID: "old", occurrenceStart: nil)])
        try store.carryOver(from: "old", to: "new", splitAt: F.d(2026, 11, 16))
        #expect(store.assignments().categoryIDs(for: EventKey(externalID: "new", occurrenceStart: F.d(2026, 11, 23))) == [meetings])
        // The old series keeps its own, for its occurrences before the split.
        #expect(store.assignments().categoryIDs(for: EventKey(externalID: "old", occurrenceStart: F.d(2026, 11, 2))) == [meetings])
    }

    @Test func calendarStoreReportsTheNewSeriesAfterASplit() throws {
        let store = F.store()
        var draft = EventDraft(title: "Plán", calendarID: "work", start: F.d(2026, 11, 2, 8, 30),
                               end: F.d(2026, 11, 2, 9), timeZoneID: "Europe/Prague")
        draft.recurrence = RecurrenceRule(frequency: .weekly)
        let first = try store.createEvent(draft)
        let third = try #require(F.november(store).first { F.cal.component(.day, from: $0.start) == 16 })

        var renamed = EventDraft(event: third, calendar: F.cal)
        renamed.title = "Nový plán"
        let key = try store.updateEvent(third, with: renamed, span: .futureEvents)
        #expect(key.externalID != first.key.externalID)
        #expect(F.november(store).first { $0.key == key }?.title == "Nový plán")

        let fourth = try #require(F.november(store).first { F.cal.component(.day, from: $0.start) == 23 })
        var once = EventDraft(event: fourth, calendar: F.cal)
        once.title = "Jen jednou"
        #expect(try store.updateEvent(fourth, with: once, span: .thisEvent) == fourth.key)
    }

    @Test func readerReturnsWhatTheStoreHoldsWhenItWasMade() throws {
        let store = F.store()
        _ = try store.createEvent(F.draft("Běh", calendarID: "home", day: 3, hour: 7))
        let read = store.reader()
        let november = DateInterval(start: F.d(2026, 11, 1), end: F.d(2026, 12, 1))
        #expect(read(november) == store.events(in: november, calendarIDs: F.all))
        _ = try store.createEvent(F.draft("Plavání", calendarID: "home", day: 4, hour: 7))
        #expect(read(november).count == 1)
        #expect(store.reader()(november).count == 2)
    }
}
