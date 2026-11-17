import Foundation
import Testing
@testable import DaybookCore

@Suite struct CategoryAssignmentsTests {
    let meeting = UUID()
    let focus = UUID()
    let health = UUID()
    let monday = TestCalendar.date(2026, 11, 16, 8, 30)
    let nextMonday = TestCalendar.date(2026, 11, 23, 8, 30)

    var first: EventKey { EventKey(externalID: "series", occurrenceStart: monday) }
    var second: EventKey { EventKey(externalID: "series", occurrenceStart: nextMonday) }

    @Test func aSeriesAssignmentAppliesToEveryOccurrence() {
        var assignments = CategoryAssignments()
        assignments.assign(meeting, to: first, scope: .series)
        #expect(assignments.categoryIDs(for: first) == [meeting])
        #expect(assignments.categoryIDs(for: second) == [meeting])
    }

    @Test func anOccurrenceAssignmentAddsToTheSeries() {
        var assignments = CategoryAssignments()
        assignments.assign(meeting, to: first, scope: .series)
        assignments.assign(focus, to: first, scope: .occurrence)
        #expect(assignments.categoryIDs(for: first) == [meeting, focus])
        #expect(assignments.categoryIDs(for: second) == [meeting])
    }

    @Test func aSingleEventKeepsItsCategoriesWhenItMoves() {
        var assignments = CategoryAssignments()
        assignments.assign(health, to: EventKey(externalID: "dentist", occurrenceStart: monday), scope: .series)
        #expect(assignments.categoryIDs(for: EventKey(externalID: "dentist", occurrenceStart: nextMonday)) == [health])
    }

    @Test func assigningToTheSeriesDropsTheSameOccurrenceAssignments() {
        var assignments = CategoryAssignments()
        assignments.assign(focus, to: first, scope: .occurrence)
        assignments.assign(focus, to: second, scope: .series)
        #expect(assignments.all.count == 1)
        #expect(assignments.all.first?.scope == .series)
    }

    @Test func unassigningFromTheSeriesAlsoClearsItsOccurrences() {
        var assignments = CategoryAssignments()
        assignments.assign(meeting, to: first, scope: .series)
        assignments.assign(focus, to: first, scope: .occurrence)
        assignments.assign(focus, to: EventKey(externalID: "other", occurrenceStart: monday), scope: .series)
        assignments.unassign(focus, from: second, scope: .series)
        #expect(assignments.categoryIDs(for: first) == [meeting])
        #expect(assignments.categoryIDs(for: EventKey(externalID: "other", occurrenceStart: monday)) == [focus])
    }

    @Test func unassigningAnOccurrenceKeepsTheSeries() {
        var assignments = CategoryAssignments()
        assignments.assign(meeting, to: first, scope: .series)
        assignments.assign(focus, to: first, scope: .occurrence)
        assignments.unassign(meeting, from: first, scope: .occurrence)
        assignments.unassign(focus, from: first, scope: .occurrence)
        #expect(assignments.categoryIDs(for: first) == [meeting])
    }

    @Test func assigningTwiceKeepsOne() {
        var assignments = CategoryAssignments()
        let added = assignments.assign(meeting, to: first, scope: .series)
        let again = assignments.assign(meeting, to: second, scope: .series)
        let covered = assignments.assign(meeting, to: first, scope: .occurrence)
        #expect(added && !again && !covered)
        #expect(assignments.all.count == 1)
    }

    @Test func removingACategoryCountsAndKeepsTheOthers() {
        var assignments = CategoryAssignments()
        assignments.assign(meeting, to: first, scope: .series)
        assignments.assign(meeting, to: EventKey(externalID: "a", occurrenceStart: monday), scope: .series)
        assignments.assign(health, to: EventKey(externalID: "a", occurrenceStart: monday), scope: .series)
        #expect(assignments.count(of: meeting) == 2)
        let removed = assignments.remove(category: meeting)
        #expect(removed == 2)
        #expect(assignments.count(of: meeting) == 0)
        #expect(assignments.categoryIDs(for: EventKey(externalID: "a", occurrenceStart: monday)) == [health])
    }

    @Test func assignmentsOfMissingEventsAreKept() {
        let gone = CategoryAssignment(categoryID: meeting, externalID: "gone", occurrenceStart: nil)
        let assignments = CategoryAssignments([gone])
        #expect(assignments.all == [gone])
    }

    @Test func roundTripsThroughTheList() {
        var assignments = CategoryAssignments()
        assignments.assign(meeting, to: first, scope: .series)
        assignments.assign(focus, to: first, scope: .occurrence)
        #expect(CategoryAssignments(assignments.all) == assignments)
    }

    // MARK: Selection

    @Test func selectionReadsSeriesAndOccurrence() {
        var assignments = CategoryAssignments()
        assignments.assign(meeting, to: first, scope: .series)
        assignments.assign(focus, to: first, scope: .occurrence)
        let selection = CategorySelection(assignments: assignments, key: first)
        #expect(selection.series == [meeting])
        #expect(selection.occurrence == [focus])
        #expect(selection.isOn(meeting, scope: .series) && !selection.isOn(focus, scope: .series))
        #expect(selection.isOn(meeting, scope: .occurrence) && selection.isOn(focus, scope: .occurrence))
        #expect(selection.isInherited(meeting, scope: .occurrence))
        #expect(!selection.isInherited(meeting, scope: .series))
        #expect(selection.all == [meeting, focus])
    }

    @Test func togglingInOccurrenceScopeCannotRemoveASeriesCategory() {
        var selection = CategorySelection(series: [meeting], occurrence: [])
        selection.toggle(meeting, scope: .occurrence)
        #expect(selection.series == [meeting] && selection.occurrence.isEmpty)
        selection.toggle(focus, scope: .occurrence)
        #expect(selection.occurrence == [focus])
        selection.toggle(focus, scope: .occurrence)
        #expect(selection.occurrence.isEmpty)
    }

    @Test func togglingInSeriesScopeAbsorbsTheOccurrence() {
        var selection = CategorySelection(series: [], occurrence: [focus])
        selection.toggle(focus, scope: .series)
        #expect(selection.series == [focus] && selection.occurrence.isEmpty)
        selection.toggle(focus, scope: .series)
        #expect(selection.series.isEmpty && selection.occurrence.isEmpty)
    }

    @Test func changesListExactlyTheDifferences() {
        let old = CategorySelection(series: [meeting], occurrence: [focus])
        var new = old
        new.toggle(meeting, scope: .series)
        new.toggle(health, scope: .series)
        new.toggle(focus, scope: .occurrence)
        let changes = Set(new.changes(from: old))
        #expect(changes == [
            CategoryChange(categoryID: meeting, assigned: false, scope: .series),
            CategoryChange(categoryID: health, assigned: true, scope: .series),
            CategoryChange(categoryID: focus, assigned: false, scope: .occurrence)
        ])
        #expect(old.changes(from: old).isEmpty)
    }

    @Test func applyingChangesReachesTheSelection() {
        var assignments = CategoryAssignments()
        assignments.assign(meeting, to: first, scope: .series)
        let old = CategorySelection(assignments: assignments, key: first)
        var new = old
        new.toggle(focus, scope: .occurrence)
        new.toggle(meeting, scope: .series)
        for change in new.changes(from: old) { assignments.apply(change, to: first) }
        #expect(CategorySelection(assignments: assignments, key: first) == new)
    }
}
