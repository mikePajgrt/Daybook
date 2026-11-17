import Foundation
import Testing
@testable import DaybookCore

@Suite struct CalendarDraftTests {
    let icloud = SourceInfo(id: "s1", title: "iCloud", kind: .icloud)

    @Test func nameAndSourceAreRequired() {
        #expect(CalendarDraft(title: "Výlety", color: Palette.calendarPresets[0], sourceID: "s1").problems.isEmpty)
        #expect(CalendarDraft(title: "  ", color: Palette.calendarPresets[0], sourceID: "s1").problems == [.emptyName])
        #expect(CalendarDraft(title: "Výlety", color: Palette.calendarPresets[0], sourceID: "").problems == [.noSource])
    }

    @Test func onlyICloudExchangeAndLocalSourcesOfferCreation() {
        #expect(icloud.offersCalendarCreation)
        #expect(SourceInfo(id: "s2", title: "Exchange", kind: .exchange).offersCalendarCreation)
        #expect(SourceInfo(id: "s3", title: "V zařízení", kind: .local).offersCalendarCreation)
        #expect(!SourceInfo(id: "s4", title: "Google", kind: .google).offersCalendarCreation)
        #expect(!SourceInfo(id: "s5", title: "Odběry", kind: .subscribed).offersCalendarCreation)
        #expect(!SourceInfo(id: "s6", title: "iCloud", kind: .icloud, allowsCalendars: false).offersCalendarCreation)
    }
}
