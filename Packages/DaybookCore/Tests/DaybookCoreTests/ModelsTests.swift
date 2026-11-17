import Foundation
import Testing
@testable import DaybookCore

@Suite struct ModelsTests {
    @Test func eventIdentityIsItsKey() {
        let start = Date(timeIntervalSince1970: 1_000_000)
        let key = EventKey(externalID: "abc", occurrenceStart: start)
        let event = EventInfo(key: key, calendarID: "work", title: "Standup",
                              start: start, end: start.addingTimeInterval(1800), isAllDay: false)
        #expect(event.id == key)
        #expect(event.location == nil)
        #expect(event.notes == nil)
    }

    @Test func occurrencesOfOneSeriesHaveDifferentKeys() {
        let first = EventKey(externalID: "series", occurrenceStart: Date(timeIntervalSince1970: 0))
        let second = EventKey(externalID: "series", occurrenceStart: Date(timeIntervalSince1970: 86_400))
        #expect(first != second)
    }

    @Test func calendarCarriesSourceAndFlags() {
        let cal = CalendarInfo(id: "c1", title: "Tým produkt", color: RGBA(r: 1, g: 0.7, b: 0),
                               sourceTitle: "Google", sourceKind: .google,
                               isReadOnly: true, isShared: true)
        #expect(cal.color.a == 1)
        #expect(cal.sourceKind == .google)
        #expect(cal.isReadOnly && cal.isShared)
    }

    @Test func eventRecursOnlyWithARule() {
        let start = Date(timeIntervalSince1970: 1_000_000)
        var event = EventInfo(key: EventKey(externalID: "e", occurrenceStart: start), calendarID: "work",
                              title: "", start: start, end: start, isAllDay: false)
        #expect(!event.isRecurring)
        #expect(event.isEditable)
        #expect(event.attendees.isEmpty && event.url == nil && event.alert == nil && event.timeZoneID == nil)
        event.recurrence = RecurrenceRule(frequency: .weekly)
        #expect(event.isRecurring)
    }

    @Test func alertPresetsAreInOrder() {
        #expect(AlertOffset.presets.map(\.minutesBefore) == [0, 5, 15, 30, 60, 1440])
    }

    @Test func recurrenceIntervalIsAtLeastOne() {
        #expect(RecurrenceRule(frequency: .daily, interval: 0).interval == 1)
        #expect(RecurrenceRule(frequency: .daily, interval: 3).interval == 3)
    }

    @Test func attendeeNameFallsBackToEmail() {
        #expect(Attendee(name: "Petra", email: "p@example.com", status: .accepted).displayName == "Petra")
        #expect(Attendee(name: nil, email: "p@example.com", status: .pending).displayName == "p@example.com")
        #expect(Attendee(name: " ", email: nil, status: .unknown).displayName == "")
    }
}
