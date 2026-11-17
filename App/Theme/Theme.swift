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
    /// Times and other secondary text.
    static let secondaryInk = ink.opacity(0.62)
    /// Text of days that belong to the neighbouring month. Holds 4.5:1 on the ground in both appearances.
    private static let outsideInk = Color.adaptive(light: RGBA(r: 0.357, g: 0.384, b: 0.471),
                                                   dark: RGBA(r: 0.561, g: 0.592, b: 0.678))

    static func outsideInk(_ contrast: ColorSchemeContrast) -> Color {
        contrast == .increased ? ink.opacity(0.85) : outsideInk
    }

    /// The dot that marks an event on its calendar's line.
    static let station = Color.adaptive(light: RGBA(r: 1, g: 1, b: 1), dark: porcelain)
    /// Hairlines between days and weeks.
    static let rule = ink.opacity(0.16)
    /// Fill of an event block in the week and day views: the calendar's colour mixed into the ground
    /// in OKLab, so ink stays legible and warm colours do not turn brown on midnight.
    static func blockFill(_ color: RGBA) -> Color {
        .adaptive(light: Palette.blockFill(color, on: porcelain), dark: Palette.blockFill(color, on: midnight))
    }
    /// Time and place inside an event block. Darker than `secondaryInk`, because the block's tint
    /// lowers contrast; holds 4.5:1 on a tinted block in both appearances.
    static let blockSecondaryInk = ink.opacity(0.8)
    /// Tint laid over weekend columns.
    static let weekend = Color.adaptive(light: RGBA(r: 0.055, g: 0.102, b: 0.227, a: 0.05),
                                        dark: RGBA(r: 0, g: 0, b: 0, a: 0.18))
}

extension Color {
    init(_ rgba: RGBA) {
        self.init(.sRGB, red: rgba.r, green: rgba.g, blue: rgba.b, opacity: rgba.a)
    }

    /// A colour that follows the system appearance.
    static func adaptive(light: RGBA, dark: RGBA) -> Color {
        #if canImport(UIKit)
        return Color(UIColor { traits in
            let c = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: c.r, green: c.g, blue: c.b, alpha: c.a)
        })
        #else
        return Color(NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            let c = isDark ? dark : light
            return NSColor(srgbRed: c.r, green: c.g, blue: c.b, alpha: c.a)
        })
        #endif
    }
}
