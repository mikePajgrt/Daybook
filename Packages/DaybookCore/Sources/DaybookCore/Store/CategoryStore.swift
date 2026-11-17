import Foundation

/// Where categories are kept, in words the sidebar can say.
public enum CategorySyncState: Hashable, Sendable {
    /// This build has no iCloud container: categories stay on this device.
    case localOnly
    /// Categories sync through the user's private iCloud database.
    case syncing
    /// Sync is configured but iCloud is signed out, restricted or the synced store failed to open:
    /// categories are kept on this device for now.
    case iCloudUnavailable
    /// Not even local storage opened: changes last until the app quits.
    case notSaved
}

/// Why a category write was refused.
public enum CategoryStoreError: Error, Equatable, Sendable {
    case categoryNotFound
    case invalidName([CategoryNameProblem])
    case invalidSymbol
    case system(String)
}

/// Daybook's own categories and their assignments to events.
/// Implementations are used from the main actor only.
public protocol CategoryStore: AnyObject {
    var syncState: CategorySyncState { get }

    /// All categories, by order then name.
    func categories() -> [Category]

    /// Every assignment, including those of events that no longer exist.
    func assignments() -> CategoryAssignments

    @discardableResult func createCategory(name: String, symbol: String) throws -> Category
    func renameCategory(_ id: UUID, to name: String) throws
    func setSymbol(_ symbol: String, ofCategory id: UUID) throws
    /// Puts the listed categories first, in that order; the rest keep their order after them.
    func reorderCategories(_ ids: [UUID]) throws
    /// Deletes a category and every assignment of it.
    func deleteCategory(_ id: UUID) throws

    func assign(_ categoryID: UUID, to key: EventKey, scope: CategoryScope) throws
    func unassign(_ categoryID: UUID, from key: EventKey, scope: CategoryScope) throws

    /// Emits after every change, the app's own and (for a synced store) those from other devices.
    var changes: AsyncStream<Void> { get }
}

extension CategoryStore {
    /// The categories of one event, in sidebar order.
    public func categories(for key: EventKey) -> [Category] {
        let ids = assignments().categoryIDs(for: key)
        return categories().filter { ids.contains($0.id) }
    }
}

/// Validation and ordering every store shares.
public enum CategoryRules {
    public static func sorted(_ categories: [Category]) -> [Category] {
        categories.sorted { ($0.order, $0.name, $0.id.uuidString) < ($1.order, $1.name, $1.id.uuidString) }
    }

    public static func checkName(_ name: String, among existing: [Category], excluding: UUID? = nil) throws {
        let problems = CategoryName.problems(name, among: existing, excluding: excluding)
        guard problems.isEmpty else { throw CategoryStoreError.invalidName(problems) }
    }

    public static func checkSymbol(_ symbol: String) throws {
        guard !symbol.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw CategoryStoreError.invalidSymbol
        }
    }

    /// New orders for `categories` with `ids` first.
    public static func reordered(_ categories: [Category], first ids: [UUID]) -> [UUID: Int] {
        let current = sorted(categories)
        let listed = ids.filter { id in current.contains { $0.id == id } }
        let rest = current.map(\.id).filter { !listed.contains($0) }
        var result: [UUID: Int] = [:]
        for (index, id) in (listed + rest).enumerated() { result[id] = index }
        return result
    }
}
