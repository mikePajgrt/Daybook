import Foundation
import Testing
@testable import DaybookCore

@Suite struct PaletteTests {
    let amber = RGBA(r: 1.0, g: 0.69, b: 0.0)

    @Test func contrastOfInkOnGroundIsHigh() {
        #expect(Palette.contrast(Palette.porcelain, Palette.midnight) > 12)
        #expect(abs(Palette.contrast(RGBA(r: 1, g: 1, b: 1), RGBA(r: 0, g: 0, b: 0)) - 21) < 0.01)
    }

    @Test func mixingEndsAtItsInputs() {
        let start = Palette.mix(Palette.midnight, amber, amount: 0)
        let end = Palette.mix(Palette.midnight, amber, amount: 1)
        #expect(abs(start.r - Palette.midnight.r) < 0.002 && abs(start.b - Palette.midnight.b) < 0.002)
        #expect(abs(end.r - amber.r) < 0.002 && abs(end.g - amber.g) < 0.002)
    }

    /// On midnight a plain 22% mix cancels amber's hue against the blue ground and leaves grey.
    /// Every chromatic calendar's fill keeps its own hue at the same chroma floor instead.
    @Test func everyChromaticFillKeepsItsHueAtTheChromaFloor() {
        let colors = Palette.calendarPresets + DemoData.calendars.map(\.color) + [amber]
        for color in colors where Palette.chroma(color) >= Palette.achromaticBelow {
            for ground in [Palette.midnight, Palette.porcelain] {
                let fill = Palette.blockFill(color, on: ground)
                #expect(Palette.chroma(fill) >= Palette.blockFillChromaFloor - 0.003)
                let difference = abs(Palette.hue(fill) - Palette.hue(color))
                #expect(min(difference, 360 - difference) < 4)
            }
        }
    }

    @Test func amberOnMidnightIsBronzeNotGrey() {
        let fill = Palette.blockFill(amber, on: Palette.midnight)
        #expect(fill.r > fill.b + 0.04)
    }

    @Test func greyCalendarsKeepAPlainMix() {
        let grey = RGBA(r: 0.56, g: 0.56, b: 0.58)
        let fill = Palette.blockFill(grey, on: Palette.porcelain)
        let plain = Palette.mix(Palette.porcelain, grey, amount: Palette.blockFillAmount)
        #expect(abs(fill.r - plain.r) < 0.002 && abs(fill.g - plain.g) < 0.002 && abs(fill.b - plain.b) < 0.002)
    }

    @Test func blockTextKeepsContrastOnEveryDemoCalendar() {
        for color in DemoData.calendars.map(\.color) + Palette.calendarPresets + [amber] {
            let dark = Palette.blockFill(color, on: Palette.midnight)
            let light = Palette.blockFill(color, on: Palette.porcelain)
            #expect(Palette.contrast(Palette.porcelain, dark) >= 7)
            #expect(Palette.contrast(Palette.midnight, light) >= 7)
            // Time and place are ink at 80%: composite it over the fill and check 4.5:1.
            let darkSecondary = Palette.over(Palette.porcelain, opacity: 0.8, on: dark)
            let lightSecondary = Palette.over(Palette.midnight, opacity: 0.8, on: light)
            #expect(Palette.contrast(darkSecondary, dark) >= 4.5)
            #expect(Palette.contrast(lightSecondary, light) >= 4.5)
        }
    }

    @Test func presetCalendarColoursReadOnBothGrounds() {
        #expect(Palette.calendarPresets.count == 8)
        for color in Palette.calendarPresets {
            #expect(Palette.contrast(color, Palette.midnight) >= 3)
            #expect(Palette.contrast(color, Palette.porcelain) >= 3)
        }
    }
}
