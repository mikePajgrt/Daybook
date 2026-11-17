import Foundation

/// Which categories the user switched off, and whether events without a category show.
/// Everything is on by default, so a new category never hides anything.
/// An event shows when at least one of its categories is on, or when it has none and
/// "Bez kategorie" is on. Categories that no longer exist count as none.
public struct CategoryFilter: Equatable, Sendable {
    public private(set) var hiddenIDs: Set<UUID>
    public private(set) var showsUncategorized: Bool

    static let uncategorizedToken = "uncategorized-off"

    public init(hiddenIDs: Set<UUID> = [], showsUncategorized: Bool = true) {
        self.hiddenIDs = hiddenIDs
        self.showsUncategorized = showsUncategorized
    }

    /// Restores a filter from what `storedValue` produced. Unreadable entries are ignored.
    public init(storedValue: [String]) {
        hiddenIDs = Set(storedValue.compactMap(UUID.init(uuidString:)))
        showsUncategorized = !storedValue.contains(Self.uncategorizedToken)
    }

    /// A property-list friendly form for `UserDefaults`.
    public var storedValue: [String] {
        hiddenIDs.map(\.uuidString).sorted() + (showsUncategorized ? [] : [Self.uncategorizedToken])
    }

    /// Whether anything is switched off.
    public var isFiltering: Bool { !hiddenIDs.isEmpty || !showsUncategorized }

    public func isOn(_ id: UUID) -> Bool { !hiddenIDs.contains(id) }

    public func isVisible(categoryIDs: Set<UUID>, known: Set<UUID>) -> Bool {
        let present = categoryIDs.intersection(known)
        if present.isEmpty { return showsUncategorized }
        return !present.isSubset(of: hiddenIDs)
    }

    public mutating func toggle(_ id: UUID) {
        if hiddenIDs.contains(id) { hiddenIDs.remove(id) } else { hiddenIDs.insert(id) }
    }

    public mutating func toggleUncategorized() { showsUncategorized.toggle() }

    /// Only this category: every other one and "Bez kategorie" off.
    public mutating func showOnly(_ id: UUID, among all: Set<UUID>) {
        hiddenIDs = all.subtracting([id])
        showsUncategorized = false
    }

    /// Only events without a category.
    public mutating func showOnlyUncategorized(among all: Set<UUID>) {
        hiddenIDs = all
        showsUncategorized = true
    }

    public mutating func showAll() {
        hiddenIDs = []
        showsUncategorized = true
    }
}

extension VisibilityFilter {
    /// The events whose calendar is on and whose categories pass `categories`.
    public func visibleEvents(_ events: [EventInfo], categories: CategoryFilter,
                              assignments: CategoryAssignments, known: Set<UUID>) -> [EventInfo] {
        events.filter { event in
            isVisible(event.calendarID)
                && (!categories.isFiltering
                    || categories.isVisible(categoryIDs: assignments.categoryIDs(for: event.key), known: known))
        }
    }
}
