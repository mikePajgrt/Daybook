import Foundation
import Testing
@testable import DaybookCore

@Suite struct ColorThemeTests {
    /// Every theme in both appearances, named for failure messages.
    static let palettes: [(name: String, palette: ThemePalette)] = ColorTheme.allCases.flatMap { theme in
        [false, true].map { dark in ("\(theme.rawValue) \(dark ? "dark" : "light")", theme.palette(dark: dark)) }
    }

    @Test func storedNamesStayTheSame() {
        // Persisted in UserDefaults: renaming a case would silently reset the user's choice.
        #expect(ColorTheme.allCases.map(\.rawValue) == ["nocturne", "boss", "kiss", "slate", "graphite"])
        #expect(AppearanceChoice.allCases.map(\.rawValue) == ["system", "light", "dark"])
        #expect(ColorTheme.default == .nocturne)
    }

    @Test func hexRoundTrips() {
        #expect(RGBA(hex: 0x0e1a3a).hexString == "#0e1a3a")
        #expect(RGBA(hex: 0xf4f1ea).hexString == "#f4f1ea")
        #expect(Palette.midnight.hexString == "#0e1a3a")
    }

    /// The default theme is the world as it was: the same grounds, rail, ink and derived colours.
    @Test func defaultThemeKeepsTheOriginalColours() {
        let dark = ColorTheme.nocturne.palette(dark: true)
        let light = ColorTheme.nocturne.palette(dark: false)
        #expect(dark.ground == Palette.midnight && light.ground == Palette.porcelain)
        #expect(dark.ink == Palette.porcelain && light.ink == Palette.midnight)
        #expect(dark.rail == RGBA(r: 0.039, g: 0.078, b: 0.188) && light.rail == RGBA(r: 0.918, g: 0.902, b: 0.867))
        #expect(dark.controlInk == dark.ink && light.controlInk == light.ink)
        #expect(dark.switchOn == RGBA(r: 0.551, g: 0.566, b: 0.607) && light.switchOn == Palette.midnight)
        #expect(dark.secondaryOpacity == 0.62 && dark.secondaryOpacityIncreased == 0.8)
        #expect(light.station == RGBA(r: 1, g: 1, b: 1) && dark.station == Palette.porcelain)
        #expect(dark.isDark && !light.isDark)
    }

    @Test func textHoldsContrastOnGroundAndRail() {
        for (name, p) in Self.palettes {
            for surface in [p.ground, p.rail] {
                #expect(p.ink.contrast(with: surface) >= 7, "\(name): ink \(p.ink.contrast(with: surface))")
                #expect(p.controlInk.contrast(with: surface) >= 4.5, "\(name): control ink")
                for increased in [false, true] {
                    let secondary = p.secondaryInk(increased: increased).composited(over: surface)
                    // 4.495: the default's light rail sits at 4.5 rounded, unchanged since before themes.
                    #expect(secondary.contrast(with: surface) >= 4.495,
                            "\(name) increased \(increased): secondary \(secondary.contrast(with: surface))")
                }
            }
            for increased in [false, true] {
                let outside = p.outsideInk(increased: increased).composited(over: p.ground)
                #expect(outside.contrast(with: p.ground) >= 4.5, "\(name): outside ink")
            }
        }
    }

    @Test func rulesAndTheRailStepAreVisible() {
        for (name, p) in Self.palettes {
            let rule = p.rule(increased: false).composited(over: p.ground)
            let strong = p.rule(increased: true).composited(over: p.ground)
            #expect(rule.contrast(with: p.ground) >= 1.3, "\(name): rule \(rule.contrast(with: p.ground))")
            #expect(strong.contrast(with: p.ground) >= 1.7, "\(name): increased rule")
            // One step deeper than the ground in both appearances, and a visible one.
            #expect(Palette.luminance(p.rail) < Palette.luminance(p.ground), "\(name): rail not deeper")
            #expect(p.rail.contrast(with: p.ground) >= 1.05, "\(name): rail step \(p.rail.contrast(with: p.ground))")
            let weekend = p.weekend.composited(over: p.ground)
            #expect(weekend.contrast(with: p.ground) >= 1.03, "\(name): weekend tint")
        }
    }

    @Test func switchKnobReadsOnTheTrack() {
        for (name, p) in Self.palettes {
            #expect(RGBA(r: 1, g: 1, b: 1).contrast(with: p.switchOn) >= 3, "\(name): knob on switch")
        }
    }

    @Test func everyPresetLineReadsOnEveryGround() {
        for (name, p) in Self.palettes {
            for color in Palette.calendarPresets {
                #expect(p.line(color).contrast(with: p.ground) >= 2.995, "\(name): \(color.hexString)")
                #expect(p.line(color, increased: true).contrast(with: p.ground) >= 4.495,
                        "\(name) increased: \(color.hexString)")
            }
        }
    }

    @Test func blockTextHoldsOnEveryFill() {
        let colors = Palette.calendarPresets + DemoData.calendars.map(\.color)
        for (name, p) in Self.palettes {
            for color in colors {
                for increased in [false, true] {
                    let fill = p.blockFill(color, increased: increased)
                    #expect(p.ink.contrast(with: fill) >= 4.5, "\(name): title on \(color.hexString)")
                    let secondary = p.blockSecondaryInk(increased: increased).composited(over: fill)
                    #expect(secondary.contrast(with: fill) >= 4.5, "\(name): time on \(color.hexString)")
                }
            }
        }
    }
}
