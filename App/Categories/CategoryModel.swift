import DaybookCore
import Foundation
import Observation

/// Category state: the list, the assignments, the filter, where categories are kept, and the open
/// category editor. Owned by `AppModel`, which re-lays-out its views when `onChange` fires.
@MainActor
@Observable
final class CategoryModel {
    static let filterKey = "categoryFilter"

    let store: CategoryStore
    private let defaults: UserDefaults

    private(set) var categories: [Category] = []
    private(set) var assignments = CategoryAssignments()
    /// Switched-off categories and "Bez kategorie". Remembered per device.
    private(set) var filter: CategoryFilter
    private(set) var syncState: CategorySyncState
    /// The create or edit sheet on screen, if any.
    var editor: CategoryEditorModel?
    /// The category whose deletion is being confirmed.
    var pendingDelete: Category?

    /// Called after anything that changes which events show or what they carry.
    @ObservationIgnored var onChange: (() -> Void)?
    /// Called with a refused write that has no form to show it in.
    @ObservationIgnored var onNotice: ((Notice) -> Void)?

    init(store: CategoryStore, defaults: UserDefaults) {
        self.store = store
        self.defaults = defaults
        self.filter = CategoryFilter(storedValue: defaults.stringArray(forKey: Self.filterKey) ?? [])
        self.syncState = store.syncState
        reload()
    }

    /// Reads the store. Only values that changed are assigned.
    func reload() {
        let newCategories = store.categories()
        if newCategories != categories { categories = newCategories }
        let newAssignments = store.assignments()
        if newAssignments != assignments { assignments = newAssignments }
        if store.syncState != syncState { syncState = store.syncState }
    }

    var knownIDs: Set<UUID> { Set(categories.map(\.id)) }

    /// An event's categories in sidebar order. Deleted or not-yet-synced categories are left out.
    func categories(for key: EventKey) -> [Category] {
        let ids = assignments.categoryIDs(for: key)
        guard !ids.isEmpty else { return [] }
        return categories.filter { ids.contains($0.id) }
    }

    func selection(for key: EventKey) -> CategorySelection {
        CategorySelection(assignments: assignments, key: key)
    }

    /// How many events lose `category` when it is deleted (a series counts once).
    func eventCount(of category: Category) -> Int { assignments.count(of: category.id) }

    // MARK: Filter

    func toggle(_ category: Category) { updateFilter { $0.toggle(category.id) } }
    func toggleUncategorized() { updateFilter { $0.toggleUncategorized() } }
    func showOnly(_ category: Category) { updateFilter { $0.showOnly(category.id, among: knownIDs) } }
    func showOnlyUncategorized() { updateFilter { $0.showOnlyUncategorized(among: knownIDs) } }
    func showAll() { updateFilter { $0.showAll() } }

    private func updateFilter(_ change: (inout CategoryFilter) -> Void) {
        change(&filter)
        defaults.set(filter.storedValue, forKey: Self.filterKey)
        onChange?()
    }

    // MARK: Managing

    func beginNew() {
        editor = CategoryEditorModel(mode: .new, others: categories)
    }

    func beginEditing(_ category: Category, focus: CategoryEditorModel.Focus = .name) {
        editor = CategoryEditorModel(mode: .edit(category), others: categories, focus: focus)
    }

    /// Creates or changes the category. On failure the text goes into the sheet, which stays open.
    @discardableResult
    func save(_ editor: CategoryEditorModel) -> Bool {
        do {
            switch editor.mode {
            case .new:
                try store.createCategory(name: editor.name, symbol: editor.symbol)
            case .edit(let category):
                if CategoryName.normalized(editor.name) != category.name {
                    try store.renameCategory(category.id, to: editor.name)
                }
                if editor.symbol != category.symbol { try store.setSymbol(editor.symbol, ofCategory: category.id) }
            }
            changed()
            return true
        } catch {
            editor.errorMessage = CategoryText.message(for: error)
            return false
        }
    }

    func delete(_ category: Category) {
        perform { try store.deleteCategory(category.id) }
    }

    /// Drag to reorder in the sidebar.
    func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        var ids = categories.map(\.id)
        ids.move(fromOffsets: source, toOffset: destination)
        perform { try store.reorderCategories(ids) }
    }

    // MARK: Assigning

    /// Switches one category on or off for an event, from a menu or the detail.
    func set(_ category: Category, on: Bool, for key: EventKey, scope: CategoryScope) {
        perform {
            if on {
                try store.assign(category.id, to: key, scope: scope)
            } else {
                try store.unassign(category.id, from: key, scope: scope)
            }
        }
    }

    /// Writes what an editor changed. Returns the error text, or `nil` when it worked.
    func apply(_ selection: CategorySelection, from old: CategorySelection, to key: EventKey) -> String? {
        do {
            for change in selection.changes(from: old) {
                if change.assigned {
                    try store.assign(change.categoryID, to: key, scope: change.scope)
                } else {
                    try store.unassign(change.categoryID, from: key, scope: change.scope)
                }
            }
            changed()
            return nil
        } catch {
            changed()
            return CategoryText.message(for: error)
        }
    }

    private func perform(_ write: () throws -> Void) {
        do {
            try write()
        } catch {
            onNotice?(Notice(title: String(localized: "Kategorii se nepodařilo změnit"), message: CategoryText.message(for: error)))
        }
        changed()
    }

    private func changed() {
        reload()
        onChange?()
    }
}
