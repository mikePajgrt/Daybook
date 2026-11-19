import Foundation
import Testing
@testable import DaybookCore

@Suite struct PassedTests {
    let calendar = TestCalendar.prague()

    private func event(_ start: Date, _ end: Date, allDay: Bool = false) -> EventInfo {
        EventInfo(key: EventKey(externalID: "e", occurrenceStart: start), calendarID: "c", title: "",
                  start: start, end: end, isAllDay: allDay)
    }

    private func date(_ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
        TestCalendar.date(2026, 11, day, hour, minute, in: calendar)
    }

    @Test func timedEventPassesAtItsEnd() {
        let meeting = event(date(17, 9), date(17, 10))
        #expect(!meeting.hasPassed(at: date(17, 8, 59), calendar: calendar))
        #expect(!meeting.hasPassed(at: date(17, 9, 30), calendar: calendar))
        #expect(meeting.hasPassed(at: date(17, 10), calendar: calendar))
        #expect(meeting.hasPassed(at: date(18, 0), calendar: calendar))
    }

    @Test func zeroLengthEventPassesAtItsStart() {
        let reminder = event(date(17, 10), date(17, 10))
        #expect(!reminder.hasPassed(at: date(17, 9, 59), calendar: calendar))
        #expect(reminder.hasPassed(at: date(17, 10), calendar: calendar))
    }

    @Test func eventCrossingMidnightIsInProgressUntilItsEnd() {
        let night = event(date(16, 22), date(17, 2))
        #expect(!night.hasPassed(at: date(17, 1), calendar: calendar))
        #expect(night.hasPassed(at: date(17, 2), calendar: calendar))
    }

    /// EventKit ends an all-day event a second before the next midnight.
    @Test func allDayEventPassesWhenItsLastDayIsOver() {
        let trip = event(date(15), date(17).addingTimeInterval(-1), allDay: true)
        #expect(!trip.hasPassed(at: date(16, 23, 59), calendar: calendar))
        #expect(trip.hasPassed(at: date(17, 0), calendar: calendar))
    }

    @Test func allDayEventIsNotPassedOnItsOwnDay() {
        let today = event(date(17), date(18).addingTimeInterval(-1), allDay: true)
        #expect(!today.hasPassed(at: date(17, 23, 59), calendar: calendar))
        #expect(today.hasPassed(at: date(18, 0), calendar: calendar))
    }

    /// An all-day event stored with an exclusive end (the next midnight) has the same last day.
    @Test func allDayEventWithExclusiveEndHasTheSameLastDay() {
        let day = event(date(17), date(18), allDay: true)
        #expect(!day.hasPassed(at: date(17, 12), calendar: calendar))
        #expect(day.hasPassed(at: date(18, 0), calendar: calendar))
    }

    @Test func passedBlockTextHoldsOnEveryFill() {
        let colors = Palette.calendarPresets + DemoData.calendars.map(\.color)
        for theme in ColorTheme.allCases {
            for dark in [false, true] {
                let p = theme.palette(dark: dark)
                for color in colors {
                    for increased in [false, true] {
                        let fill = p.passedBlockFill(color, increased: increased)
                        let text = p.blockSecondaryInk(increased: increased).composited(over: fill)
                        #expect(text.contrast(with: fill) >= 4.5, "\(theme) \(dark): \(color.hexString)")
                    }
                }
            }
        }
    }

    @Test func passedBlockFillStaysInItsHueAtHalfTheFloor() {
        for color in Palette.calendarPresets {
            for ground in [Palette.midnight, Palette.porcelain] {
                let fill = Palette.passedBlockFill(color, on: ground)
                #expect(Palette.chroma(fill) >= Palette.passedBlockFillChromaFloor - 0.003)
                let difference = abs(Palette.hue(fill) - Palette.hue(color))
                #expect(min(difference, 360 - difference) < 4)
                // Closer to the ground than the normal fill.
                #expect(Palette.contrast(fill, ground) < Palette.contrast(Palette.blockFill(color, on: ground), ground) + 0.001)
            }
        }
    }

    @Test func passedSpanLineIsOpaqueAndKeepsFullStrengthUnderIncreasedContrast() {
        for theme in ColorTheme.allCases {
            for dark in [false, true] {
                let p = theme.palette(dark: dark)
                for color in Palette.calendarPresets {
                    let passed = p.passedSpanLine(color)
                    #expect(passed.a == 1)
                    #expect(passed.contrast(with: p.ground) < p.line(color).contrast(with: p.ground))
                    #expect(p.passedSpanLine(color, increased: true) == p.line(color, increased: true))
                }
            }
        }
    }
}
