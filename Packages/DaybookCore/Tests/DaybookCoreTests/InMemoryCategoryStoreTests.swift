import Foundation
import Testing
@testable import DaybookCore

@Suite struct InMemoryCategoryStoreTests {
    let key = EventKey(externalID: "standup", occurrenceStart: TestCalendar.date(2026, 11, 17, 9))

    @Test func createAppendsWithATrimmedName() throws {
        let store = InMemoryCategoryStore()
        let first = try store.createCategory(name: " Porady ", symbol: "person.2")
        let second = try store.createCategory(name: "Zdraví", symbol: "heart")
        #expect(first.name == "Porady")
        #expect(store.categories().map(\.name) == ["Porady", "Zdraví"])
        #expect(second.order > first.order)
    }

    @Test func invalidNamesAndSymbolsThrow() throws {
        let store = InMemoryCategoryStore()
        try store.createCategory(name: "Porady", symbol: "person.2")
        #expect(throws: CategoryStoreError.invalidName([.duplicate])) { try store.createCategory(name: "porady", symbol: "tag") }
        #expect(throws: CategoryStoreError.invalidName([.empty])) { try store.createCategory(name: " ", symbol: "tag") }
        #expect(throws: CategoryStoreError.invalidSymbol) { try store.createCategory(name: "Děti", symbol: "") }
    }

    @Test func renameAndChangeSymbol() throws {
        let store = InMemoryCategoryStore()
        let made = try store.createCategory(name: "Porady", symbol: "person.2")
        try store.renameCategory(made.id, to: "Schůzky")
        try store.setSymbol("phone", ofCategory: made.id)
        #expect(store.categories().first?.name == "Schůzky")
        #expect(store.categories().first?.symbol == "phone")
        try store.renameCategory(made.id, to: "SCHŮZKY")
        #expect(throws: CategoryStoreError.categoryNotFound) { try store.renameCategory(UUID(), to: "X") }
    }

    @Test func reorderPutsTheListedFirstAndKeepsTheRest() throws {
        let store = InMemoryCategoryStore()
        let a = try store.createCategory(name: "A", symbol: "tag")
        let b = try store.createCategory(name: "B", symbol: "tag")
        let c = try store.createCategory(name: "C", symbol: "tag")
        try store.reorderCategories([c.id, a.id])
        #expect(store.categories().map(\.id) == [c.id, a.id, b.id])
    }

    @Test func deleteRemovesItsAssignments() throws {
        let store = InMemoryCategoryStore()
        let meeting = try store.createCategory(name: "Porady", symbol: "person.2")
        let health = try store.createCategory(name: "Zdraví", symbol: "heart")
        try store.assign(meeting.id, to: key, scope: .series)
        try store.assign(health.id, to: key, scope: .occurrence)
        try store.deleteCategory(meeting.id)
        #expect(store.categories().map(\.id) == [health.id])
        #expect(store.assignments().categoryIDs(for: key) == [health.id])
        #expect(throws: CategoryStoreError.categoryNotFound) { try store.deleteCategory(meeting.id) }
    }

    @Test func assigningAnUnknownCategoryThrows() {
        let store = InMemoryCategoryStore()
        #expect(throws: CategoryStoreError.categoryNotFound) { try store.assign(UUID(), to: key, scope: .series) }
    }

    @Test func unassignRemoves() throws {
        let store = InMemoryCategoryStore()
        let meeting = try store.createCategory(name: "Porady", symbol: "person.2")
        try store.assign(meeting.id, to: key, scope: .series)
        try store.unassign(meeting.id, from: key, scope: .series)
        #expect(store.assignments().isEmpty)
    }

    @Test func everyWriteEmitsOneChange() throws {
        let store = InMemoryCategoryStore()
        let made = try store.createCategory(name: "Porady", symbol: "person.2")
        #expect(store.emittedChanges == 1)
        try store.renameCategory(made.id, to: "Schůzky")
        try store.setSymbol("phone", ofCategory: made.id)
        try store.reorderCategories([made.id])
        try store.assign(made.id, to: key, scope: .series)
        try store.unassign(made.id, from: key, scope: .series)
        try store.deleteCategory(made.id)
        #expect(store.emittedChanges == 7)
        _ = try? store.createCategory(name: "", symbol: "tag")
        #expect(store.emittedChanges == 7)
    }

    @Test func syncStateIsSettable() {
        let store = InMemoryCategoryStore(syncState: .iCloudUnavailable)
        #expect(store.syncState == .iCloudUnavailable)
        #expect(InMemoryCategoryStore().syncState == .localOnly)
    }
}
