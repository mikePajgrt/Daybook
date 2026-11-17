import Foundation

/// A `CategoryStore` in memory. Used by tests and by the app's demo mode.
public final class InMemoryCategoryStore: CategoryStore {
    public var syncState: CategorySyncState
    private var stored: [Category]
    private var index: CategoryAssignments
    private let continuation: AsyncStream<Void>.Continuation
    public let changes: AsyncStream<Void>
    /// How many changes were emitted, for tests.
    public private(set) var emittedChanges = 0

    public init(categories: [Category] = [], assignments: [CategoryAssignment] = [],
                syncState: CategorySyncState = .localOnly) {
        self.stored = categories
        self.index = CategoryAssignments(assignments)
        self.syncState = syncState
        let (stream, continuation) = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
        self.changes = stream
        self.continuation = continuation
    }

    public func categories() -> [Category] { CategoryRules.sorted(stored) }

    public func assignments() -> CategoryAssignments { index }

    @discardableResult
    public func createCategory(name: String, symbol: String) throws -> Category {
        try CategoryRules.checkName(name, among: stored)
        try CategoryRules.checkSymbol(symbol)
        let category = Category(name: CategoryName.normalized(name), symbol: symbol,
                                order: (stored.map(\.order).max() ?? -1) + 1)
        stored.append(category)
        emit()
        return category
    }

    public func renameCategory(_ id: UUID, to name: String) throws {
        let position = try position(of: id)
        try CategoryRules.checkName(name, among: stored, excluding: id)
        stored[position].name = CategoryName.normalized(name)
        emit()
    }

    public func setSymbol(_ symbol: String, ofCategory id: UUID) throws {
        let position = try position(of: id)
        try CategoryRules.checkSymbol(symbol)
        stored[position].symbol = symbol
        emit()
    }

    public func reorderCategories(_ ids: [UUID]) throws {
        let orders = CategoryRules.reordered(stored, first: ids)
        for position in stored.indices { stored[position].order = orders[stored[position].id] ?? stored[position].order }
        emit()
    }

    public func deleteCategory(_ id: UUID) throws {
        let position = try position(of: id)
        stored.remove(at: position)
        index.remove(category: id)
        emit()
    }

    public func assign(_ categoryID: UUID, to key: EventKey, scope: CategoryScope) throws {
        _ = try position(of: categoryID)
        index.assign(categoryID, to: key, scope: scope)
        emit()
    }

    public func unassign(_ categoryID: UUID, from key: EventKey, scope: CategoryScope) throws {
        index.unassign(categoryID, from: key, scope: scope)
        emit()
    }

    private func position(of id: UUID) throws -> Int {
        guard let position = stored.firstIndex(where: { $0.id == id }) else { throw CategoryStoreError.categoryNotFound }
        return position
    }

    private func emit() {
        emittedChanges += 1
        continuation.yield()
    }
}
