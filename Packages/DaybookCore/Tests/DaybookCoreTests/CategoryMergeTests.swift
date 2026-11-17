import Foundation
import Testing
@testable import DaybookCore

@Suite struct CategoryMergeTests {
    @Test func movesWhatTheSyncedStoreLacks() {
        let shared = Category(name: "Porady", symbol: "person.2", order: 0)
        let localOnly = Category(name: "Zdraví", symbol: "heart", order: 1)
        let cloudOnly = Category(name: "Děti", symbol: "figure.and.child.holdinghands", order: 0)
        let a = CategoryAssignment(categoryID: shared.id, externalID: "a", occurrenceStart: nil)
        let b = CategoryAssignment(categoryID: localOnly.id, externalID: "b", occurrenceStart: Date(timeIntervalSince1970: 0))
        let plan = CategoryMerge.plan(local: [shared, localOnly], localAssignments: [a, b],
                                      into: [cloudOnly, shared], existingAssignments: [a])
        #expect(plan.categories == [localOnly])
        #expect(plan.assignments == [b])
    }

    @Test func movedCategoriesGoAfterTheSyncedOnes() {
        let cloud = Category(name: "Porady", symbol: "person.2", order: 4)
        let local = Category(name: "Zdraví", symbol: "heart", order: 0)
        let plan = CategoryMerge.plan(local: [local], localAssignments: [], into: [cloud], existingAssignments: [])
        #expect(plan.categories.first?.order == 5)
    }

    @Test func aSameNamedCategoryJoinsTheSyncedOne() {
        let cloud = Category(name: "Porady", symbol: "person.2", order: 0)
        let local = Category(name: "porady", symbol: "phone", order: 0)
        let assignment = CategoryAssignment(categoryID: local.id, externalID: "a", occurrenceStart: nil)
        let plan = CategoryMerge.plan(local: [local], localAssignments: [assignment], into: [cloud], existingAssignments: [])
        #expect(plan.categories.isEmpty)
        #expect(plan.assignments == [CategoryAssignment(categoryID: cloud.id, externalID: "a", occurrenceStart: nil)])
    }

    @Test func nothingToMove() {
        let plan = CategoryMerge.plan(local: [], localAssignments: [], into: [], existingAssignments: [])
        #expect(plan.categories.isEmpty && plan.assignments.isEmpty)
    }
}
