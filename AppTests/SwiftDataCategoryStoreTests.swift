import DaybookCore
import Foundation
import SwiftData
import Testing

/// `SwiftDataCategoryStore` and the move from device-only into synced storage, on in-memory containers.
/// CloudKit is not involved: these containers have no CloudKit database.
@MainActor
@Suite struct SwiftDataCategoryStoreTests {
    private static func container() throws -> ModelContainer {
        try ModelContainer(for: CategoryContainer.schema,
                           configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
    }

    private func store(_ container: ModelContainer? = nil) throws -> SwiftDataCategoryStore {
        SwiftDataCategoryStore(container: try container ?? Self.container(), cloudContainerID: nil, state: .localOnly)
    }

    private let monday = Date(timeIntervalSince1970: 1_794_900_000)

    @Test func startsEmptyAndDeviceOnly() throws {
        let store = try store()
        #expect(store.categories().isEmpty)
        #expect(store.assignments().isEmpty)
        #expect(store.syncState == .localOnly)
    }

    @Test func createAppendsTrimmedAndRejectsBadNames() throws {
        let store = try store()
        let first = try store.createCategory(name: "  Porady ", symbol: "person.2")
        let second = try store.createCategory(name: "Děti", symbol: "figure.and.child.holdinghands")
        #expect(first.name == "Porady")
        #expect(store.categories().map(\.name) == ["Porady", "Děti"])
        #expect(second.order > first.order)
        #expect(throws: CategoryStoreError.invalidName([.duplicate])) { try store.createCategory(name: "PORADY", symbol: "tag") }
        #expect(throws: CategoryStoreError.invalidName([.empty])) { try store.createCategory(name: "  ", symbol: "tag") }
        #expect(throws: CategoryStoreError.invalidSymbol) { try store.createCategory(name: "Sport", symbol: " ") }
        #expect(store.categories().count == 2)
    }

    @Test func renameAndSymbolChange() throws {
        let store = try store()
        let category = try store.createCategory(name: "Porady", symbol: "person.2")
        _ = try store.createCategory(name: "Zdraví", symbol: "heart")
        try store.renameCategory(category.id, to: "Schůzky")
        try store.setSymbol("briefcase", ofCategory: category.id)
        let found = try #require(store.categories().first { $0.id == category.id })
        #expect(found.name == "Schůzky" && found.symbol == "briefcase")
        #expect(throws: CategoryStoreError.invalidName([.duplicate])) { try store.renameCategory(category.id, to: "zdravi") }
        #expect(throws: CategoryStoreError.categoryNotFound) { try store.renameCategory(UUID(), to: "Nic") }
    }

    @Test func reorderPutsTheListedFirst() throws {
        let store = try store()
        let a = try store.createCategory(name: "A", symbol: "tag")
        let b = try store.createCategory(name: "B", symbol: "tag")
        let c = try store.createCategory(name: "C", symbol: "tag")
        try store.reorderCategories([c.id, a.id])
        #expect(store.categories().map(\.id) == [c.id, a.id, b.id])
    }

    @Test func seriesAndOccurrenceAssignmentsAndLookup() throws {
        let store = try store()
        let meetings = try store.createCategory(name: "Porady", symbol: "person.2")
        let focus = try store.createCategory(name: "Soustředění", symbol: "scope")
        let week = 7 * 86_400.0
        let first = EventKey(externalID: "series", occurrenceStart: monday)
        let second = EventKey(externalID: "series", occurrenceStart: monday.addingTimeInterval(week))
        try store.assign(meetings.id, to: first, scope: .series)
        try store.assign(focus.id, to: second, scope: .occurrence)
        #expect(store.assignments().categoryIDs(for: first) == [meetings.id])
        #expect(store.assignments().categoryIDs(for: second) == [meetings.id, focus.id])
        #expect(store.categories(for: second).map(\.name) == ["Porady", "Soustředění"])
        // Assigning to the series absorbs the occurrence's own assignment of the same category.
        try store.assign(focus.id, to: first, scope: .series)
        #expect(store.assignments().all.filter { $0.scope == .occurrence }.isEmpty)
        try store.unassign(focus.id, from: second, scope: .series)
        #expect(store.assignments().categoryIDs(for: second) == [meetings.id])
        #expect(throws: CategoryStoreError.categoryNotFound) { try store.assign(UUID(), to: first, scope: .series) }
    }

    @Test func deleteRemovesTheCategoryAndItsAssignments() throws {
        let store = try store()
        let meetings = try store.createCategory(name: "Porady", symbol: "person.2")
        let health = try store.createCategory(name: "Zdraví", symbol: "heart")
        let key = EventKey(externalID: "e", occurrenceStart: monday)
        try store.assign(meetings.id, to: key, scope: .series)
        try store.assign(health.id, to: key, scope: .series)
        try store.deleteCategory(meetings.id)
        #expect(store.categories().map(\.name) == ["Zdraví"])
        #expect(store.assignments().categoryIDs(for: key) == [health.id])
        #expect(throws: CategoryStoreError.categoryNotFound) { try store.deleteCategory(meetings.id) }
    }

    @Test func dataSurvivesANewContextOnTheSameContainer() throws {
        let container = try Self.container()
        let first = try store(container)
        let category = try first.createCategory(name: "Porady", symbol: "person.2")
        try first.assign(category.id, to: EventKey(externalID: "e", occurrenceStart: monday), scope: .series)
        let second = try store(container)
        #expect(second.categories().map(\.name) == ["Porady"])
        #expect(second.assignments().all.count == 1)
    }

    @Test func duplicateRecordsFromASyncRaceReadAsOne() throws {
        let container = try Self.container()
        let context = ModelContext(container)
        let category = Category(name: "Porady", symbol: "person.2", order: 0)
        context.insert(CategoryRecord(category))
        context.insert(CategoryRecord(category))
        let assignment = CategoryAssignment(categoryID: category.id, externalID: "e", occurrenceStart: nil)
        context.insert(CategoryAssignmentRecord(assignment))
        context.insert(CategoryAssignmentRecord(assignment))
        try context.save()
        let store = try store(container)
        #expect(store.categories().count == 1)
        #expect(store.assignments().all == [assignment])
        // A rename reaches both copies; an assignment change writes away the duplicate.
        try store.renameCategory(category.id, to: "Schůzky")
        #expect(try ModelContext(container).fetch(FetchDescriptor<CategoryRecord>()).allSatisfy { $0.name == "Schůzky" })
        try store.assign(category.id, to: EventKey(externalID: "f", occurrenceStart: monday), scope: .series)
        #expect(try ModelContext(container).fetch(FetchDescriptor<CategoryAssignmentRecord>()).count == 2)
    }

    @Test func everyWriteEmitsAChange() async throws {
        let store = try store()
        var iterator = store.changes.makeAsyncIterator()
        let category = try store.createCategory(name: "Porady", symbol: "person.2")
        #expect(await iterator.next() != nil)
        try store.assign(category.id, to: EventKey(externalID: "e", occurrenceStart: monday), scope: .series)
        #expect(await iterator.next() != nil)
        try store.deleteCategory(category.id)
        #expect(await iterator.next() != nil)
    }

    @Test func deviceOnlyDataMovesIntoTheSyncedStore() throws {
        let local = try Self.container()
        let synced = try Self.container()
        let localStore = try store(local)
        let syncedStore = try store(synced)
        let meetings = try localStore.createCategory(name: "Porady", symbol: "person.2")
        let travel = try localStore.createCategory(name: "Cestování", symbol: "airplane")
        let existing = try syncedStore.createCategory(name: "porady", symbol: "briefcase")
        let key = EventKey(externalID: "e", occurrenceStart: monday)
        try localStore.assign(meetings.id, to: key, scope: .series)
        try localStore.assign(travel.id, to: key, scope: .occurrence)

        let moved = try CategoryContainer.moveCategories(from: local, into: synced)

        #expect(moved.categories == 1)
        #expect(moved.assignments == 2)
        let after = try store(synced)
        // "Porady" joins the synced store's "porady"; "Cestování" moves in after it.
        #expect(after.categories().map(\.name) == ["porady", "Cestování"])
        #expect(after.assignments().categoryIDs(for: key) == [existing.id, travel.id])
        let emptied = try store(local)
        #expect(emptied.categories().isEmpty && emptied.assignments().isEmpty)
        // Moving again finds nothing to move.
        #expect(try CategoryContainer.moveCategories(from: local, into: synced) == (0, 0))
    }
}
