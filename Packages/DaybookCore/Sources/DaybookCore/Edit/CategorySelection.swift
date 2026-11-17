import Foundation

/// One assignment to add or remove.
public struct CategoryChange: Hashable, Sendable {
    public let categoryID: UUID
    public let assigned: Bool
    public let scope: CategoryScope

    public init(categoryID: UUID, assigned: Bool, scope: CategoryScope) {
        self.categoryID = categoryID
        self.assigned = assigned
        self.scope = scope
    }
}

/// The categories of one event as an editor or the detail toggles them: the series' set and
/// the occurrence's own set. In occurrence scope a series category is inherited and stays on.
public struct CategorySelection: Equatable, Sendable {
    public private(set) var series: Set<UUID>
    public private(set) var occurrence: Set<UUID>

    public init(series: Set<UUID> = [], occurrence: Set<UUID> = []) {
        self.series = series
        self.occurrence = occurrence.subtracting(series)
    }

    public init(assignments: CategoryAssignments, key: EventKey) {
        self.init(series: assignments.seriesCategoryIDs(of: key.externalID),
                  occurrence: assignments.occurrenceCategoryIDs(of: key))
    }

    /// Everything the event carries.
    public var all: Set<UUID> { series.union(occurrence) }

    public func isOn(_ id: UUID, scope: CategoryScope) -> Bool {
        scope == .series ? series.contains(id) : all.contains(id)
    }

    /// On because of the series, so it cannot be switched off for one occurrence.
    public func isInherited(_ id: UUID, scope: CategoryScope) -> Bool {
        scope == .occurrence && series.contains(id)
    }

    public mutating func toggle(_ id: UUID, scope: CategoryScope) {
        switch scope {
        case .series:
            if series.contains(id) {
                series.remove(id)
            } else {
                series.insert(id)
            }
            occurrence.remove(id)
        case .occurrence:
            guard !series.contains(id) else { return }
            if occurrence.contains(id) { occurrence.remove(id) } else { occurrence.insert(id) }
        }
    }

    /// The assignments that turn `old` into this selection.
    public func changes(from old: CategorySelection) -> [CategoryChange] {
        var result: [CategoryChange] = []
        for id in series.subtracting(old.series) { result.append(CategoryChange(categoryID: id, assigned: true, scope: .series)) }
        for id in old.series.subtracting(series) { result.append(CategoryChange(categoryID: id, assigned: false, scope: .series)) }
        // Occurrence assignments a series change already removed need no change of their own.
        let oldOccurrence = old.occurrence.subtracting(series)
        for id in occurrence.subtracting(oldOccurrence) { result.append(CategoryChange(categoryID: id, assigned: true, scope: .occurrence)) }
        for id in oldOccurrence.subtracting(occurrence) where !old.series.subtracting(series).contains(id) {
            result.append(CategoryChange(categoryID: id, assigned: false, scope: .occurrence))
        }
        return result.sorted { ($0.categoryID.uuidString, $0.assigned ? 1 : 0) < ($1.categoryID.uuidString, $1.assigned ? 1 : 0) }
    }
}
