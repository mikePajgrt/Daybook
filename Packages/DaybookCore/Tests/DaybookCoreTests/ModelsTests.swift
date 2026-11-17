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
}
