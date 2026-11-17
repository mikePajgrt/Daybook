import Foundation

/// Moving categories kept on the device into the synced store when sync is turned on.
/// Nothing the synced store already has is copied twice; moved categories go after its own, and a
/// category whose name the synced store already uses joins that one (its assignments follow).
public enum CategoryMerge {
    public struct Plan: Equatable, Sendable {
        public let categories: [Category]
        public let assignments: [CategoryAssignment]
    }

    public static func plan(local: [Category], localAssignments: [CategoryAssignment],
                            into existing: [Category], existingAssignments: [CategoryAssignment]) -> Plan {
        let existingIDs = Set(existing.map(\.id))
        var byName: [String: UUID] = [:]
        for category in existing { byName[CategoryName.key(category.name)] = category.id }
        var next = (existing.map(\.order).max() ?? -1) + 1
        var categories: [Category] = []
        var renamed: [UUID: UUID] = [:]
        for category in CategoryRules.sorted(local) where !existingIDs.contains(category.id) {
            if let same = byName[CategoryName.key(category.name)] {
                renamed[category.id] = same
                continue
            }
            var moved = category
            moved.order = next
            next += 1
            categories.append(moved)
            byName[CategoryName.key(category.name)] = category.id
        }
        var known = Set(existingAssignments)
        var assignments: [CategoryAssignment] = []
        for item in localAssignments {
            let mapped = CategoryAssignment(categoryID: renamed[item.categoryID] ?? item.categoryID,
                                            externalID: item.externalID, occurrenceStart: item.occurrenceStart)
            if known.insert(mapped).inserted { assignments.append(mapped) }
        }
        return Plan(categories: categories, assignments: assignments)
    }
}
