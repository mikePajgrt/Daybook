import Foundation
import Testing
@testable import DaybookCore

@Suite struct LineColorTests {
    let grounds = [Palette.porcelain, Palette.midnight]

    @Test func presetsAreReturnedUnchanged() {
        for preset in Palette.calendarPresets {
            for ground in grounds {
                #expect(Palette.lineColor(preset, on: ground) == preset)
            }
        }
    }

    @Test func paleHolidayColourReachesThreeToOneOnPorcelainKeepingItsHue() {
        let pale = RGBA(r: 0.73, g: 0.75, b: 0.83)
        #expect(Palette.contrast(pale, Palette.porcelain) < 3)
        let line = Palette.lineColor(pale, on: Palette.porcelain)
        #expect(Palette.contrast(line, Palette.porcelain) >= 3)
        #expect(Palette.contrast(line, Palette.porcelain) < 3.3)
        #expect(abs(Palette.hue(line) - Palette.hue(pale)) < 2)
        // On midnight it already reads, so it stays as the user chose it.
        #expect(Palette.lineColor(pale, on: Palette.midnight) == pale)
    }

    @Test func darkColourIsLightenedOnMidnight() {
        let navy = RGBA(r: 0.10, g: 0.15, b: 0.40)
        let line = Palette.lineColor(navy, on: Palette.midnight)
        #expect(Palette.contrast(line, Palette.midnight) >= 3)
        #expect(abs(Palette.hue(line) - Palette.hue(navy)) < 2)
    }

    @Test func higherTargetIsMet() {
        for preset in Palette.calendarPresets {
            for ground in grounds {
                let line = Palette.lineColor(preset, on: ground, minimumContrast: 4.5)
                #expect(Palette.contrast(line, ground) >= 4.5)
            }
        }
    }

    @Test func greysStayGrey() {
        let grey = RGBA(r: 0.8, g: 0.8, b: 0.8)
        let line = Palette.lineColor(grey, on: Palette.porcelain)
        #expect(Palette.chroma(line) < 0.01)
        #expect(Palette.contrast(line, Palette.porcelain) >= 3)
    }

    @Test func opacityIsKept() {
        let pale = RGBA(r: 0.73, g: 0.75, b: 0.83, a: 0.5)
        #expect(Palette.lineColor(pale, on: Palette.porcelain).a == 0.5)
    }
}
