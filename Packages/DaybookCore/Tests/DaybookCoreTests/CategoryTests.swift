import Foundation
import Testing
@testable import DaybookCore

@Suite struct CategoryTests {
    let porady = Category(id: UUID(), name: "Porady", symbol: "person.2", order: 0)
    let zdravi = Category(id: UUID(), name: "Zdraví", symbol: "heart", order: 1)

    @Test func blankNamesAreEmpty() {
        #expect(CategoryName.problems("", among: []) == [.empty])
        #expect(CategoryName.problems("  \n ", among: []) == [.empty])
    }

    @Test func namesAreUniqueIgnoringCaseSpacesAndDiacritics() {
        #expect(CategoryName.problems("porady", among: [porady, zdravi]) == [.duplicate])
        #expect(CategoryName.problems(" PORADY ", among: [porady, zdravi]) == [.duplicate])
        #expect(CategoryName.problems("Zdravi", among: [porady, zdravi]) == [.duplicate])
        #expect(CategoryName.problems("Děti", among: [porady, zdravi]).isEmpty)
    }

    @Test func renamingToItsOwnNameIsFine() {
        #expect(CategoryName.problems("PORADY", among: [porady, zdravi], excluding: porady.id).isEmpty)
        #expect(CategoryName.problems("zdravi", among: [porady, zdravi], excluding: porady.id) == [.duplicate])
    }

    @Test func normalizedNameIsTrimmed() {
        #expect(CategoryName.normalized("  Porady \n") == "Porady")
    }

    @Test func offeredSymbolsAreUniqueAndNamed() {
        let offered = CategorySymbols.offered
        #expect(offered.count >= 20)
        #expect(Set(offered).count == offered.count)
        #expect(offered.allSatisfy { !$0.isEmpty })
        #expect(offered.contains(CategorySymbols.fallback))
    }

    @Test func assignmentScopeFollowsTheOccurrence() {
        let series = CategoryAssignment(categoryID: porady.id, externalID: "x", occurrenceStart: nil)
        let one = CategoryAssignment(categoryID: porady.id, externalID: "x", occurrenceStart: Date(timeIntervalSince1970: 0))
        #expect(series.scope == .series)
        #expect(one.scope == .occurrence)
    }
}
