import Foundation

/// Remembers which calendars the user switched off. Everything else is visible,
/// so a calendar that appears later is shown without any action.
public struct VisibilityFilter: Equatable, Sendable {
    public private(set) var hiddenIDs: Set<String>

    public init(hiddenIDs: Set<String> = []) {
        self.hiddenIDs = hiddenIDs
    }

    /// Restores a filter from what `storedValue` produced.
    public init(storedValue: [String]) {
        self.hiddenIDs = Set(storedValue)
    }

    /// A stable, property-list friendly form for `UserDefaults`.
    public var storedValue: [String] { hiddenIDs.sorted() }

    public func isVisible(_ id: String) -> Bool { !hiddenIDs.contains(id) }

    public func visibleIDs(among all: Set<String>) -> Set<String> { all.subtracting(hiddenIDs) }

    public mutating func toggle(_ id: String) {
        if hiddenIDs.contains(id) { hiddenIDs.remove(id) } else { hiddenIDs.insert(id) }
    }

    public mutating func showOnly(_ id: String, among all: Set<String>) {
        hiddenIDs = all.subtracting([id])
    }

    public mutating func showAll() { hiddenIDs = [] }
}
