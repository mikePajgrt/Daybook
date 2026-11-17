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

    /// A thin sRGB tint turns amber into brown on midnight (red well above blue);
    /// the perceptual mix stays close to neutral instead.
    @Test func amberBlockFillOnMidnightIsNotBrown() {
        let fill = Palette.blockFill(amber, on: Palette.midnight)
        #expect(fill.r - fill.b < 0.05)
    }

    @Test func blockTextKeepsContrastOnEveryDemoCalendar() {
        for calendar in DemoData.calendars {
            let dark = Palette.blockFill(calendar.color, on: Palette.midnight)
            let light = Palette.blockFill(calendar.color, on: Palette.porcelain)
            #expect(Palette.contrast(Palette.porcelain, dark) >= 7)
            #expect(Palette.contrast(Palette.midnight, light) >= 7)
        }
    }
}
