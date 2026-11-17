import DaybookCore
import Foundation
import SwiftData

/// The app's `Category` is DaybookCore's, not the Objective-C runtime's type of the same name.
typealias Category = DaybookCore.Category

// SwiftData models for categories. They follow CloudKit's rules so the same models sync:
// no unique constraints, every attribute defaulted or optional, no relationships.

@Model
final class CategoryRecord {
    /// The category's id; duplicates that a sync may produce are merged when read.
    var identifier: UUID = UUID()
    var name: String = ""
    var symbol: String = CategorySymbols.fallback
    var order: Int = 0

    init(_ category: Category) {
        identifier = category.id
        name = category.name
        symbol = category.symbol
        order = category.order
    }

    var value: Category { Category(id: identifier, name: name, symbol: symbol, order: order) }
}

@Model
final class CategoryAssignmentRecord {
    var categoryID: UUID = UUID()
    /// EventKit's `calendarItemExternalIdentifier`, stable across devices.
    var externalID: String = ""
    /// `nil` for the whole series; otherwise the one occurrence's start.
    var occurrenceStart: Date? = nil

    init(_ assignment: CategoryAssignment) {
        categoryID = assignment.categoryID
        externalID = assignment.externalID
        occurrenceStart = assignment.occurrenceStart
    }

    var value: CategoryAssignment {
        CategoryAssignment(categoryID: categoryID, externalID: externalID, occurrenceStart: occurrenceStart)
    }
}
