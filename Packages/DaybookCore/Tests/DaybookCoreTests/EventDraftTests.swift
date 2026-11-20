import Foundation
import Testing
@testable import DaybookCore

@Suite struct EventDraftTests {
    let cal = TestCalendar.prague()

    func d(_ y: Int, _ m: Int, _ day: Int, _ h: Int = 0, _ min: Int = 0) -> Date {
        TestCalendar.date(y, m, day, h, min, in: cal)
    }

    func timedDraft() -> EventDraft {
        EventDraft(calendarID: "work", start: d(2026, 11, 17, 10), end: d(2026, 11, 17, 11),
                   timeZoneID: "Europe/Prague")
    }

    // MARK: From an event

    @Test func draftFromTimedEventCopiesEveryField() {
        let event = EventInfo(key: EventKey(externalID: "e", occurrenceStart: d(2026, 11, 17, 10)),
                              calendarID: "work", title: "Návrh API",
                              start: d(2026, 11, 17, 10), end: d(2026, 11, 17, 11, 30), isAllDay: false,
                              location: "Vltava", notes: "Agenda", url: URL(string: "https://example.com/a"),
                              recurrence: RecurrenceRule(frequency: .weekly), alert: AlertOffset(minutesBefore: 15),
                              timeZoneID: "Europe/Prague")
        let draft = EventDraft(event: event, calendar: cal)
        #expect(draft.title == "Návrh API")
        #expect(draft.calendarID == "work")
        #expect(!draft.isAllDay)
        #expect(draft.start == event.start && draft.end == event.end)
        #expect(draft.location == "Vltava" && draft.notes == "Agenda" && draft.url == "https://example.com/a")
        #expect(draft.recurrence == RecurrenceRule(frequency: .weekly))
        #expect(draft.alert == AlertOffset(minutesBefore: 15))
        #expect(draft.timeZoneID == "Europe/Prague")
    }

    @Test func draftFromAllDayEventHoldsFirstAndLastDay() {
        let event = EventInfo(key: EventKey(externalID: "e", occurrenceStart: d(2026, 11, 17)),
                              calendarID: "home", title: "Lisabon",
                              start: d(2026, 11, 17), end: d(2026, 11, 20).addingTimeInterval(-1), isAllDay: true)
        let draft = EventDraft(event: event, calendar: cal)
        #expect(draft.isAllDay)
        #expect(draft.start == d(2026, 11, 17))
        #expect(draft.end == d(2026, 11, 19))
    }

    // MARK: Validation

    @Test func emptyTitleIsAllowed() {
        #expect(timedDraft().problems(calendar: cal).isEmpty)
    }

    @Test func endBeforeStartIsAProblem() {
        var draft = timedDraft()
        draft.end = d(2026, 11, 17, 9)
        #expect(draft.problems(calendar: cal) == [.endBeforeStart])
        draft.end = draft.start
        #expect(draft.problems(calendar: cal).isEmpty)
    }

    @Test func oneDayAllDayDraftIsValid() {
        let draft = EventDraft(calendarID: "work", isAllDay: true, start: d(2026, 11, 17), end: d(2026, 11, 17))
        #expect(draft.problems(calendar: cal).isEmpty)
        var earlier = draft
        earlier.end = d(2026, 11, 16)
        #expect(earlier.problems(calendar: cal) == [.endBeforeStart])
    }

    @Test func recurrenceMayNotEndBeforeTheStart() {
        var draft = timedDraft()
        draft.recurrence = RecurrenceRule(frequency: .daily, end: d(2026, 11, 16))
        #expect(draft.problems(calendar: cal) == [.recurrenceEndsBeforeStart])
        draft.recurrence = RecurrenceRule(frequency: .daily, end: d(2026, 11, 17))
        #expect(draft.problems(calendar: cal).isEmpty)
    }

    @Test func urlsAreNormalizedOrRejected() {
        var draft = timedDraft()
        draft.url = "example.com"
        #expect(draft.normalizedURL == URL(string: "https://example.com"))
        #expect(draft.problems(calendar: cal).isEmpty)
        draft.url = "exa mple"
        #expect(draft.problems(calendar: cal) == [.invalidURL])
        draft.url = "  "
        #expect(draft.normalizedURL == nil)
        #expect(draft.problems(calendar: cal).isEmpty)
    }

    @Test func missingCalendarIsAProblem() {
        var draft = timedDraft()
        draft.calendarID = ""
        #expect(draft.problems(calendar: cal) == [.noCalendar])
    }

    // MARK: Changes

    @Test func movingTheStartKeepsTheDuration() {
        var draft = timedDraft()
        draft.setStart(d(2026, 11, 17, 12), calendar: cal)
        #expect(draft.end == d(2026, 11, 17, 13))
    }

    @Test func movingAnAllDayStartKeepsTheDays() {
        var draft = EventDraft(calendarID: "work", isAllDay: true, start: d(2026, 11, 17), end: d(2026, 11, 19))
        draft.setStart(d(2026, 11, 18), calendar: cal)
        #expect(draft.end == d(2026, 11, 20))
    }

    @Test func allDaySwitchesLandOnWholeDaysAndBack() {
        var draft = timedDraft()
        draft.setAllDay(true, calendar: cal)
        #expect(draft.isAllDay && draft.start == d(2026, 11, 17) && draft.end == d(2026, 11, 17))
        #expect(draft.timeZoneID == nil)
        draft.setAllDay(false, calendar: cal)
        #expect(!draft.isAllDay && draft.start == d(2026, 11, 17, 9) && draft.end == d(2026, 11, 17, 10))
        #expect(draft.timeZoneID == "Europe/Prague")
    }

    @Test func changingTheTimeZoneKeepsTheWallClock() {
        var draft = timedDraft()
        draft.changeTimeZone(to: "America/New_York", calendar: cal)
        #expect(draft.timeZoneID == "America/New_York")
        #expect(draft.start == d(2026, 11, 17, 16))
        #expect(draft.end == d(2026, 11, 17, 17))
    }

    // MARK: Span choices

    @Test func spanChoicesDependOnTheSeries() {
        let single = EventInfo(key: EventKey(externalID: "e", occurrenceStart: d(2026, 11, 17, 10)),
                               calendarID: "work", title: "", start: d(2026, 11, 17, 10),
                               end: d(2026, 11, 17, 11), isAllDay: false)
        var recurring = single
        recurring.recurrence = RecurrenceRule(frequency: .weekly)
        let draft = EventDraft(event: recurring, calendar: cal)
        #expect(EventDraft(event: single, calendar: cal).spanChoices(original: single).isEmpty)
        #expect(draft.spanChoices(original: recurring) == [.thisEvent, .futureEvents])
        var changed = draft
        changed.recurrence = RecurrenceRule(frequency: .daily)
        #expect(changed.spanChoices(original: recurring) == [.futureEvents])
    }

    // MARK: Defaults

    @Test func newEventStartsAtTheNextFullHour() {
        let a = EventDraft.newEvent(on: d(2026, 11, 17), now: d(2026, 11, 17, 10, 20), calendarID: "work", calendar: cal)
        #expect(a.start == d(2026, 11, 17, 11) && a.end == d(2026, 11, 17, 12))
        #expect(!a.isAllDay && a.title.isEmpty && a.calendarID == "work")
        #expect(a.timeZoneID == "Europe/Prague")
        let b = EventDraft.newEvent(on: d(2026, 11, 17), now: d(2026, 11, 17, 10), calendarID: "work", calendar: cal)
        #expect(b.start == d(2026, 11, 17, 11))
    }

    @Test func newEventOnAnotherDayUsesThatDay() {
        let draft = EventDraft.newEvent(on: d(2026, 11, 20, 15), now: d(2026, 11, 17, 10, 20),
                                        calendarID: "work", calendar: cal)
        #expect(draft.start == d(2026, 11, 20, 11))
    }

    @Test func newEventLateInTheEveningStaysOnItsDay() {
        let draft = EventDraft.newEvent(on: d(2026, 11, 17), now: d(2026, 11, 17, 23, 30),
                                        calendarID: "work", calendar: cal)
        #expect(draft.start == d(2026, 11, 17, 23))
        #expect(draft.end.timeIntervalSince(draft.start) == 3600)
    }

    @Test func newEventOnTheAutumnClockChangeLastsOneHour() {
        // 25 Oct 2026: clocks go back from 03:00 to 02:00.
        let draft = EventDraft.newEvent(on: d(2026, 10, 25), now: d(2026, 10, 25, 1, 30),
                                        calendarID: "work", calendar: cal)
        #expect(cal.component(.hour, from: draft.start) == 2)
        #expect(cal.isDate(draft.start, inSameDayAs: d(2026, 10, 25)))
        #expect(draft.end.timeIntervalSince(draft.start) == 3600)
    }

    @Test func newEventOnTheSpringClockChangeIsARealInstant() {
        // 29 Mar 2026: clocks go forward from 02:00 to 03:00; 02:00 does not exist.
        let draft = EventDraft.newEvent(on: d(2026, 3, 29), now: d(2026, 3, 29, 1, 10),
                                        calendarID: "work", calendar: cal)
        #expect(cal.component(.hour, from: draft.start) == 3)
        #expect(cal.isDate(draft.start, inSameDayAs: d(2026, 3, 29)))
        #expect(draft.end.timeIntervalSince(draft.start) == 3600)
    }

    @Test func newEventAtASlotLastsOneHour() {
        let draft = EventDraft.newEvent(at: d(2026, 11, 17, 14, 30), calendarID: "home", calendar: cal)
        #expect(draft.start == d(2026, 11, 17, 14, 30) && draft.end == d(2026, 11, 17, 15, 30))
    }

    @Test func newAllDayEventCoversThatDayAlone() {
        // Any time of the clicked day gives the same draft: the whole day, no time zone.
        let draft = EventDraft.newAllDayEvent(on: d(2026, 11, 21, 15, 40), calendarID: "home", calendar: cal)
        #expect(draft.isAllDay && draft.start == d(2026, 11, 21) && draft.end == d(2026, 11, 21))
        #expect(draft.timeZoneID == nil && draft.title.isEmpty && draft.calendarID == "home")
        #expect(draft.problems(calendar: cal).isEmpty)
    }

    @Test func newAllDayEventOnTheAutumnClockChangeStaysOnItsDay() {
        let draft = EventDraft.newAllDayEvent(on: d(2026, 10, 25), calendarID: "home", calendar: cal)
        #expect(draft.start == d(2026, 10, 25) && draft.end == d(2026, 10, 25))
    }

    @Test func preferredCalendarFallsBackInOrder() {
        func c(_ id: String, readOnly: Bool = false) -> CalendarInfo {
            CalendarInfo(id: id, title: id, color: RGBA(r: 0, g: 0, b: 0), sourceTitle: "", sourceKind: .icloud,
                         isReadOnly: readOnly)
        }
        let writable = [c("a"), c("b"), c("c")]
        #expect(EventDraft.preferredCalendarID(writable: writable, lastUsed: "b", systemDefault: "c") == "b")
        #expect(EventDraft.preferredCalendarID(writable: writable, lastUsed: "gone", systemDefault: "c") == "c")
        #expect(EventDraft.preferredCalendarID(writable: writable, lastUsed: nil, systemDefault: "gone") == "a")
        #expect(EventDraft.preferredCalendarID(writable: [], lastUsed: "b", systemDefault: "c") == nil)
    }

    // MARK: Making the event

    @Test func allDayDraftBecomesAnEventEndingBeforeMidnight() {
        let draft = EventDraft(title: "Lisabon", calendarID: "home", isAllDay: true,
                               start: d(2026, 11, 17), end: d(2026, 11, 19), location: "", notes: "")
        let event = draft.makeEvent(key: EventKey(externalID: "x", occurrenceStart: d(2026, 11, 17)), calendar: cal)
        #expect(event.start == d(2026, 11, 17))
        #expect(event.end == d(2026, 11, 20).addingTimeInterval(-1))
        #expect(event.location == nil && event.notes == nil && event.url == nil)
    }
}
