import Foundation
import Testing
@testable import DaybookCore

@Suite struct DemoDataTests {
    let cal = TestCalendar.prague()
    let november = TestCalendar.date(2026, 11, 17)

    @Test func calendarsCoverEveryAccountKindTheProductPromises() {
        let kinds = Set(DemoData.calendars.map(\.sourceKind))
        #expect(kinds.isSuperset(of: [.icloud, .exchange, .google]))
        #expect(DemoData.calendars.contains { $0.sourceKind == .google && $0.isShared })
        #expect(Set(DemoData.calendars.map(\.id)).count == DemoData.calendars.count)
    }

    @Test func eventsReferenceKnownCalendarsAndHavePositiveLength() {
        let ids = Set(DemoData.calendars.map(\.id))
        let events = DemoData.events(month: november, calendar: cal)
        #expect(!events.isEmpty)
        #expect(events.allSatisfy { ids.contains($0.calendarID) && $0.end > $0.start })
        #expect(Set(events.map(\.key)).count == events.count)
    }

    @Test func generationIsDeterministic() {
        #expect(DemoData.events(month: november, calendar: cal) == DemoData.events(month: november, calendar: cal))
    }

    @Test func monthIsDenseEnoughToExerciseTheLayout() {
        let weeks = MonthLayout.layout(month: november,
                                       events: DemoData.events(month: november, calendar: cal), calendar: cal)
        #expect(weeks.contains { !$0.spans.isEmpty })
        #expect(weeks.contains { $0.spans.contains { $0.continuesAfter } } ||
                weeks.contains { $0.laneCount >= 1 })
        #expect((weeks.map(\.rowCount).max() ?? 0) >= 7)
        let weekdaysInMonth = weeks.flatMap(\.days).filter { $0.isInMonth && !cal.isDateInWeekend($0.date) }
        #expect(weekdaysInMonth.allSatisfy { !$0.timed.isEmpty })
    }

    @Test func todayHasAnOverlapClusterOfThree() {
        let events = DemoData.events(month: november, calendar: cal)
        let placements = TimeGridLayout.layout(day: november, events: events, calendar: cal)
        let cluster = placements.filter { $0.columnCount == 3 }
        #expect(cluster.count == 3)
        #expect(Set(cluster.map(\.column)) == [0, 1, 2])
        #expect(cluster.contains { $0.event.location != nil })
    }

    @Test func anEventCrossesMidnightInTheWeekOfToday() {
        let events = DemoData.events(month: november, calendar: cal)
        let next = TimeGridLayout.layout(day: TestCalendar.date(2026, 11, 20), events: events, calendar: cal)
        #expect(next.contains { $0.continuesBefore })
    }

    @Test func theWeekOfTodayNeedsTwoAllDayLanes() {
        let events = DemoData.events(month: november, calendar: cal)
        let week = Period.days(in: Period.interval(.week, containing: november, calendar: cal), calendar: cal)
        let segments = TimeGridLayout.allDaySegments(days: week, events: events, calendar: cal)
        #expect(Set(segments.map(\.lane)) == [0, 1])
    }

    @Test func theDesignReviewEventCarriesEveryDetail() throws {
        let event = try #require(DemoData.events(month: november, calendar: cal).first { $0.key.externalID == "demo-api" })
        #expect(event.url != nil && event.notes != nil && event.location != nil)
        #expect(event.alert == AlertOffset(minutesBefore: 15))
        #expect(event.attendees.count == 4)
        #expect(Set(event.attendees.map(\.status)).isSuperset(of: [.accepted, .declined, .tentative, .pending]))
        #expect(event.attendees.contains { $0.isOrganizer })
    }

    @Test func aWeeklySeriesRunsThroughTheMonth() {
        let store = DemoData.store(month: november, calendar: cal)
        let interval = DateInterval(start: TestCalendar.date(2026, 11, 1), end: TestCalendar.date(2026, 12, 1))
        let plan = store.events(in: interval, calendarIDs: Set(DemoData.calendars.map(\.id)))
            .filter { $0.key.externalID == DemoData.seriesID }
        #expect(plan.map { cal.component(.day, from: $0.start) } == [2, 9, 16, 23, 30])
        #expect(plan.allSatisfy { $0.isRecurring && $0.title == "Týdenní plán" && !$0.attendees.isEmpty })
    }

    @Test func theStoreOffersSourcesAndADefaultCalendar() {
        let store = DemoData.store(month: november, calendar: cal)
        #expect(Set(store.sources().map(\.kind)) == [.icloud, .exchange, .google])
        #expect(store.defaultCalendarID() == "demo-work")
    }

    @Test func readOnlyDemoCalendarsGiveReadOnlyEvents() {
        let store = DemoData.store(month: november, calendar: cal)
        let interval = DateInterval(start: TestCalendar.date(2026, 11, 17), end: TestCalendar.date(2026, 11, 18))
        let holiday = store.events(in: interval, calendarIDs: ["demo-holidays"])
        #expect(!holiday.isEmpty && holiday.allSatisfy { !$0.isEditable })
    }
}
