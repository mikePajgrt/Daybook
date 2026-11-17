import DaybookCore
import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

enum Theme {
    private static let midnight = Palette.midnight
    private static let porcelain = Palette.porcelain

    /// The surface the month is drawn on.
    static let ground = Color.adaptive(light: porcelain, dark: midnight)
    /// The sidebar, one step deeper than the ground.
    static let rail = Color.adaptive(light: RGBA(r: 0.918, g: 0.902, b: 0.867),
                                     dark: RGBA(r: 0.039, g: 0.078, b: 0.188))
    /// Text, and the fill of the interchange circle that marks today.
    static let ink = Color.adaptive(light: midnight, dark: porcelain)
    /// Times and other secondary text: ink at 62%, 80% under Increased Contrast.
    static let secondaryInk = inkAt(0.62, increased: 0.8)
    /// Text of days that belong to the neighbouring month. Holds 4.5:1 on the ground in both appearances.
    private static let outsideInk = Color.adaptive(light: RGBA(r: 0.357, g: 0.384, b: 0.471),
                                                   dark: RGBA(r: 0.561, g: 0.592, b: 0.678))

    static func outsideInk(_ contrast: ColorSchemeContrast) -> Color {
        contrast == .increased ? ink.opacity(0.85) : outsideInk
    }

    /// The dot that marks an event on its calendar's line.
    static let station = Color.adaptive(light: RGBA(r: 1, g: 1, b: 1), dark: porcelain)
    /// Hairlines between days and weeks: ink at 16%, 32% under Increased Contrast.
    static let rule = inkAt(0.16, increased: 0.32)
    /// Fill of an event block in the week and day views: the calendar's line colour mixed into the ground
    /// in OKLab, so ink stays legible and warm colours do not turn brown on midnight.
    static func blockFill(_ color: RGBA) -> Color {
        .adaptive { dark, increased in
            let ground = dark ? midnight : porcelain
            return Palette.blockFill(Palette.lineColor(color, on: ground, minimumContrast: lineContrast(increased)), on: ground)
        }
    }
    /// Time and place inside an event block. Darker than `secondaryInk`, because the block's tint
    /// lowers contrast; holds 4.5:1 on a tinted block in both appearances.
    static let blockSecondaryInk = inkAt(0.8, increased: 0.9)
    /// Tint laid over weekend columns.
    static let weekend = Color.adaptive(light: RGBA(r: 0.055, g: 0.102, b: 0.227, a: 0.05),
                                        dark: RGBA(r: 0, g: 0, b: 0, a: 0.18))

    /// Drawn when an event's calendar cannot be resolved.
    static let fallbackLine = RGBA(r: 0.56, g: 0.56, b: 0.58)

    /// A calendar's colour as a line on the ground: lightness adjusted, hue kept, until it holds 3:1
    /// (4.5:1 under Increased Contrast) in the appearance on screen. Colours that already hold stay as chosen.
    static func line(_ color: RGBA) -> Color {
        .adaptive { dark, increased in
            Palette.lineColor(color, on: dark ? midnight : porcelain, minimumContrast: lineContrast(increased))
        }
    }

    /// The line colour as plain components, for drawing outside SwiftUI (menu swatches).
    static func lineRGBA(_ color: RGBA, dark: Bool) -> RGBA {
        Palette.lineColor(color, on: dark ? midnight : porcelain)
    }

    private static func lineContrast(_ increased: Bool) -> Double { increased ? 4.5 : Palette.lineContrast }

    private static func inkAt(_ opacity: Double, increased: Double) -> Color {
        .adaptive { dark, high in
            let ink = dark ? porcelain : midnight
            return RGBA(r: ink.r, g: ink.g, b: ink.b, a: high ? increased : opacity)
        }
    }
}

/// The world's motion: the platform's own, and nothing that moves under Reduce Motion.
enum Motion {
    /// Re-laying-out after a calendar or category is switched on or off: the system's default spring,
    /// which the rows close up with. Under Reduce Motion the content crossfades instead (see `crossfadeID`).
    static func filterChange(reduceMotion: Bool) -> Animation {
        reduceMotion ? .default : .spring
    }

    /// Whether the system asks for less motion right now, for code outside a view.
    @MainActor static var reduceMotion: Bool {
        #if canImport(UIKit)
        UIAccessibility.isReduceMotionEnabled
        #else
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        #endif
    }
}

extension Color {
    init(_ rgba: RGBA) {
        self.init(.sRGB, red: rgba.r, green: rgba.g, blue: rgba.b, opacity: rgba.a)
    }

    /// A colour that follows the system appearance.
    static func adaptive(light: RGBA, dark: RGBA) -> Color {
        adaptive { isDark, _ in isDark ? dark : light }
    }

    /// A colour that follows the system appearance and Increased Contrast.
    static func adaptive(_ resolve: @escaping @Sendable (_ dark: Bool, _ increasedContrast: Bool) -> RGBA) -> Color {
        #if canImport(UIKit)
        return Color(UIColor { traits in
            let c = resolve(traits.userInterfaceStyle == .dark, traits.accessibilityContrast == .high)
            return UIColor(red: c.r, green: c.g, blue: c.b, alpha: c.a)
        })
        #else
        return Color(NSColor(name: nil) { appearance in
            let match = appearance.bestMatch(from: [.darkAqua, .aqua, .accessibilityHighContrastDarkAqua,
                                                    .accessibilityHighContrastAqua])
            let isDark = match == .darkAqua || match == .accessibilityHighContrastDarkAqua
            let high = match == .accessibilityHighContrastAqua || match == .accessibilityHighContrastDarkAqua
            let c = resolve(isDark, high)
            return NSColor(srgbRed: c.r, green: c.g, blue: c.b, alpha: c.a)
        })
        #endif
    }
}
