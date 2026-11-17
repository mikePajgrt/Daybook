import CloudKit
import CoreData
import DaybookCore
import Foundation
import SwiftData

/// `CategoryStore` over SwiftData. Used from the main thread only, like the calendar store.
/// Validation and the assignment rules come from DaybookCore; this class only reads and writes records.
final class SwiftDataCategoryStore: CategoryStore {
    private let context: ModelContext
    private let cloudContainerID: String?
    private(set) var syncState: CategorySyncState
    let changes: AsyncStream<Void>
    private let continuation: AsyncStream<Void>.Continuation
    private var observers: [NSObjectProtocol] = []

    /// `cloudContainerID` is set when the container syncs; its account status then decides the state.
    init(container: ModelContainer, cloudContainerID: String?, state: CategorySyncState = .syncing) {
        context = ModelContext(container)
        context.autosaveEnabled = false
        self.cloudContainerID = cloudContainerID
        syncState = cloudContainerID == nil ? state : .syncing
        let (stream, continuation) = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
        changes = stream
        self.continuation = continuation
        guard cloudContainerID != nil else { return }
        let center = NotificationCenter.default
        // Changes imported from the user's other devices.
        observers.append(center.addObserver(forName: .NSPersistentStoreRemoteChange, object: nil, queue: .main) { [weak self] _ in
            self?.continuation.yield()
        })
        observers.append(center.addObserver(forName: .CKAccountChanged, object: nil, queue: .main) { [weak self] _ in
            self?.refreshAccountStatus()
        })
        refreshAccountStatus()
    }

    deinit { observers.forEach(NotificationCenter.default.removeObserver) }

    /// Signed in and allowed: syncing. Anything else: kept on the device until iCloud is back.
    private func refreshAccountStatus() {
        guard let cloudContainerID else { return }
        CKContainer(identifier: cloudContainerID).accountStatus { [weak self] status, _ in
            DispatchQueue.main.async {
                guard let self else { return }
                let state: CategorySyncState = status == .available ? .syncing : .iCloudUnavailable
                if state != self.syncState {
                    self.syncState = state
                    self.continuation.yield()
                }
            }
        }
    }

    // MARK: Reading

    private func categoryRecords() -> [CategoryRecord] {
        (try? context.fetch(FetchDescriptor<CategoryRecord>())) ?? []
    }

    private func assignmentRecords() -> [CategoryAssignmentRecord] {
        (try? context.fetch(FetchDescriptor<CategoryAssignmentRecord>())) ?? []
    }

    func categories() -> [Category] {
        // A sync race can leave two records with one id: the first wins.
        var seen = Set<UUID>()
        let unique = categoryRecords().map(\.value).filter { seen.insert($0.id).inserted }
        return CategoryRules.sorted(unique)
    }

    func assignments() -> CategoryAssignments {
        CategoryAssignments(assignmentRecords().map(\.value))
    }

    // MARK: Categories

    @discardableResult
    func createCategory(name: String, symbol: String) throws -> Category {
        let existing = categories()
        try CategoryRules.checkName(name, among: existing)
        try CategoryRules.checkSymbol(symbol)
        let category = Category(name: CategoryName.normalized(name), symbol: symbol,
                                order: (existing.map(\.order).max() ?? -1) + 1)
        context.insert(CategoryRecord(category))
        try save()
        return category
    }

    func renameCategory(_ id: UUID, to name: String) throws {
        let records = try records(of: id)
        try CategoryRules.checkName(name, among: categories(), excluding: id)
        records.forEach { $0.name = CategoryName.normalized(name) }
        try save()
    }

    func setSymbol(_ symbol: String, ofCategory id: UUID) throws {
        let records = try records(of: id)
        try CategoryRules.checkSymbol(symbol)
        records.forEach { $0.symbol = symbol }
        try save()
    }

    func reorderCategories(_ ids: [UUID]) throws {
        let orders = CategoryRules.reordered(categories(), first: ids)
        for record in categoryRecords() {
            if let order = orders[record.identifier], record.order != order { record.order = order }
        }
        try save()
    }

    func deleteCategory(_ id: UUID) throws {
        let records = try records(of: id)
        records.forEach { context.delete($0) }
        assignmentRecords().filter { $0.categoryID == id }.forEach { context.delete($0) }
        try save()
    }

    // MARK: Assignments

    func assign(_ categoryID: UUID, to key: EventKey, scope: CategoryScope) throws {
        _ = try records(of: categoryID)
        try changeAssignments { $0.assign(categoryID, to: key, scope: scope) }
    }

    func unassign(_ categoryID: UUID, from key: EventKey, scope: CategoryScope) throws {
        try changeAssignments { $0.unassign(categoryID, from: key, scope: scope) }
    }

    /// Applies the core rules to the current assignments, then writes only the difference.
    private func changeAssignments(_ change: (inout CategoryAssignments) -> Void) throws {
        let records = assignmentRecords()
        let before = CategoryAssignments(records.map(\.value))
        var after = before
        change(&after)
        let wanted = Set(after.all)
        var kept = Set<CategoryAssignment>()
        for record in records {
            // Records that are no longer wanted, and duplicates of kept ones, go.
            if wanted.contains(record.value) && kept.insert(record.value).inserted { continue }
            context.delete(record)
        }
        for assignment in wanted.subtracting(kept) { context.insert(CategoryAssignmentRecord(assignment)) }
        try save()
    }

    // MARK: Helpers

    private func records(of id: UUID) throws -> [CategoryRecord] {
        let found = categoryRecords().filter { $0.identifier == id }
        guard !found.isEmpty else { throw CategoryStoreError.categoryNotFound }
        return found
    }

    private func save() throws {
        do {
            try context.save()
        } catch {
            context.rollback()
            throw CategoryStoreError.system(error.localizedDescription)
        }
        continuation.yield()
    }
}
