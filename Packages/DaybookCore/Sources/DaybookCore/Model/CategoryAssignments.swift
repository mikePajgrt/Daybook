import Foundation

/// Which categories events carry. A series assignment (no occurrence start) applies to every
/// occurrence of the series and to a single event wherever it moves; an occurrence assignment
/// applies to that occurrence only and adds to the series' categories.
/// Assignments of events that no longer exist stay: the event may come back after a sync.
public struct CategoryAssignments: Equatable, Sendable {
    private var series: [String: Set<UUID>] = [:]
    private var occurrences: [EventKey: Set<UUID>] = [:]

    public init() {}

    public init(_ list: [CategoryAssignment]) {
        for item in list {
            if let start = item.occurrenceStart {
                occurrences[EventKey(externalID: item.externalID, occurrenceStart: start), default: []].insert(item.categoryID)
            } else {
                series[item.externalID, default: []].insert(item.categoryID)
            }
        }
        // An occurrence assignment that the series already covers adds nothing.
        for (key, ids) in occurrences {
            let remaining = ids.subtracting(series[key.externalID] ?? [])
            occurrences[key] = remaining.isEmpty ? nil : remaining
        }
    }

    /// Every assignment, in a stable order.
    public var all: [CategoryAssignment] {
        let fromSeries = series.flatMap { id, categories in
            categories.map { CategoryAssignment(categoryID: $0, externalID: id, occurrenceStart: nil) }
        }
        let fromOccurrences = occurrences.flatMap { key, categories in
            categories.map { CategoryAssignment(categoryID: $0, externalID: key.externalID, occurrenceStart: key.occurrenceStart) }
        }
        return (fromSeries + fromOccurrences).sorted {
            ($0.externalID, $0.occurrenceStart ?? .distantPast, $0.categoryID.uuidString)
                < ($1.externalID, $1.occurrenceStart ?? .distantPast, $1.categoryID.uuidString)
        }
    }

    public var isEmpty: Bool { series.isEmpty && occurrences.isEmpty }

    /// The categories of one event (one occurrence): its series' plus its own.
    public func categoryIDs(for key: EventKey) -> Set<UUID> {
        (series[key.externalID] ?? []).union(occurrences[key] ?? [])
    }

    public func seriesCategoryIDs(of externalID: String) -> Set<UUID> { series[externalID] ?? [] }

    public func occurrenceCategoryIDs(of key: EventKey) -> Set<UUID> { occurrences[key] ?? [] }

    /// How many assignments a category has; a series counts once.
    public func count(of categoryID: UUID) -> Int {
        series.values.filter { $0.contains(categoryID) }.count
            + occurrences.values.filter { $0.contains(categoryID) }.count
    }

    /// Adds a category. Returns whether anything changed.
    @discardableResult
    public mutating func assign(_ categoryID: UUID, to key: EventKey, scope: CategoryScope) -> Bool {
        switch scope {
        case .series:
            var changed = series[key.externalID, default: []].insert(categoryID).inserted
            for occurrence in occurrences.keys where occurrence.externalID == key.externalID {
                if occurrences[occurrence]?.remove(categoryID) != nil { changed = true }
                if occurrences[occurrence]?.isEmpty == true { occurrences[occurrence] = nil }
            }
            return changed
        case .occurrence:
            guard series[key.externalID]?.contains(categoryID) != true else { return false }
            return occurrences[key, default: []].insert(categoryID).inserted
        }
    }

    /// Removes a category. From the series it goes from every occurrence too; from one occurrence
    /// only that occurrence's own assignment goes (a series category stays). Returns whether anything changed.
    @discardableResult
    public mutating func unassign(_ categoryID: UUID, from key: EventKey, scope: CategoryScope) -> Bool {
        var changed = false
        switch scope {
        case .series:
            if series[key.externalID]?.remove(categoryID) != nil { changed = true }
            if series[key.externalID]?.isEmpty == true { series[key.externalID] = nil }
            for occurrence in occurrences.keys where occurrence.externalID == key.externalID {
                if occurrences[occurrence]?.remove(categoryID) != nil { changed = true }
                if occurrences[occurrence]?.isEmpty == true { occurrences[occurrence] = nil }
            }
        case .occurrence:
            if occurrences[key]?.remove(categoryID) != nil { changed = true }
            if occurrences[key]?.isEmpty == true { occurrences[key] = nil }
        }
        return changed
    }

    /// Applies one change from a `CategorySelection`.
    @discardableResult
    public mutating func apply(_ change: CategoryChange, to key: EventKey) -> Bool {
        change.assigned ? assign(change.categoryID, to: key, scope: change.scope)
                        : unassign(change.categoryID, from: key, scope: change.scope)
    }

    /// Removes every assignment of a category. Returns how many went.
    @discardableResult
    public mutating func remove(category categoryID: UUID) -> Int {
        let count = count(of: categoryID)
        for id in series.keys {
            series[id]?.remove(categoryID)
            if series[id]?.isEmpty == true { series[id] = nil }
        }
        for key in occurrences.keys {
            occurrences[key]?.remove(categoryID)
            if occurrences[key]?.isEmpty == true { occurrences[key] = nil }
        }
        return count
    }
}
