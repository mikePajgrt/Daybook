import DaybookCore
import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

extension EnvironmentValues {
    /// The colour theme chosen in Settings; every `Theme` colour resolves against it.
    @Entry var colorTheme: ColorTheme = .default
}

/// A colour of the world: resolved from the environment's theme, appearance and Increased Contrast, so a
/// change of any of them redraws every view, sheet and window that shows it.
struct ThemeColor: ShapeStyle {
    let rgba: @Sendable (_ palette: ThemePalette, _ increasedContrast: Bool) -> RGBA

    init(_ rgba: @escaping @Sendable (_ palette: ThemePalette, _ increasedContrast: Bool) -> RGBA) {
        self.rgba = rgba
    }

    func resolve(in environment: EnvironmentValues) -> Color {
        Color(components(in: environment))
    }

    /// The colour as plain components in `environment`, for drawing outside SwiftUI and for `Color` APIs.
    func components(in environment: EnvironmentValues) -> RGBA {
        rgba(environment.themePalette, environment.colorSchemeContrast == .increased)
    }

    /// This colour at a further opacity.
    func opacity(_ opacity: Double) -> ThemeColor {
        let rgba = rgba
        return ThemeColor { palette, increased in
            let c = rgba(palette, increased)
            return RGBA(r: c.r, g: c.g, b: c.b, a: c.a * opacity)
        }
    }
}

/// As a view, like `Color`: for list row backgrounds and other places that take a view.
extension ThemeColor: View {
    var body: some View { Rectangle().fill(self) }
}

extension EnvironmentValues {
    /// The palette on screen: the chosen theme in the current appearance.
    var themePalette: ThemePalette { colorTheme.palette(dark: colorScheme == .dark) }
}

/// The world's colours. Each is a `ThemeColor`, taken from the theme chosen in Settings (`ColorTheme`,
/// DaybookCore) in the appearance on screen; the default theme draws exactly the original world.
enum Theme {
    /// The surface the month is drawn on.
    static let ground = ThemeColor { p, _ in p.ground }
    /// The sidebar, one step deeper than the ground.
    static let rail = ThemeColor { p, _ in p.rail }
    /// Text, and the fill of the interchange circle that marks today.
    static let ink = ThemeColor { p, _ in p.ink }
    /// Tint of menus, form controls and bordered buttons: the ink, leaning toward the theme's hue in
    /// themes that have one, never a line colour.
    static let controlInk = ThemeColor { p, _ in p.controlInk }
    /// Times and other secondary text: ink at 62% (more in some light themes), 80% under Increased Contrast.
    static let secondaryInk = ThemeColor { p, increased in p.secondaryInk(increased: increased) }

    /// Text of days that belong to the neighbouring month. Holds 4.5:1 on the ground; ink at 85% under
    /// Increased Contrast.
    static func outsideInk(_ contrast: ColorSchemeContrast) -> ThemeColor {
        ThemeColor { p, increased in p.outsideInk(increased: increased) }
    }

    /// The dot that marks an event on its calendar's line.
    static let station = ThemeColor { p, _ in p.station }
    /// Hairlines between days and weeks: ink at 16%, 32% under Increased Contrast.
    static let rule = ThemeColor { p, increased in p.rule(increased: increased) }
    /// Fill of an event block in the week and day views: the calendar's line colour mixed into the ground
    /// in OKLab, so ink stays legible and warm colours do not turn brown on a dark ground.
    static func blockFill(_ color: RGBA) -> ThemeColor {
        ThemeColor { p, increased in p.blockFill(color, increased: increased) }
    }
    /// Time and place inside an event block. Darker than `secondaryInk`, because the block's tint
    /// lowers contrast; holds 4.5:1 on a tinted block in every theme and appearance.
    static let blockSecondaryInk = ThemeColor { p, increased in p.blockSecondaryInk(increased: increased) }
    /// Tint laid over weekend columns.
    static let weekend = ThemeColor { p, _ in p.weekend }

    /// Drawn when an event's calendar cannot be resolved.
    static let fallbackLine = RGBA(r: 0.56, g: 0.56, b: 0.58)

    /// A calendar's colour as a line on the ground: lightness adjusted, hue kept, until it holds 3:1
    /// (4.5:1 under Increased Contrast) on the ground on screen. Colours that already hold stay as chosen.
    static func line(_ color: RGBA) -> ThemeColor {
        ThemeColor { p, increased in p.line(color, increased: increased) }
    }

    /// A switch's "on" track: the white knob holds 3:1 on it in every theme. In the default theme's dark
    /// appearance ink thinned to 55% over midnight, mixed opaque: porcelain itself would leave the knob at 1.13:1.
    static let switchOn = ThemeColor { p, _ in p.switchOn }

    /// The line colour as plain components, for drawing outside SwiftUI (menu swatches).
    static func lineRGBA(_ color: RGBA, palette: ThemePalette) -> RGBA {
        palette.line(color)
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
}

extension View {
    /// Every switch in the app: the world's ink, with a dark-appearance track the knob stays visible on.
    func switchTint() -> some View { themeTint(Theme.switchOn) }

    /// Tints controls with a theme colour, resolved to a plain `Color` first: bar buttons and other
    /// controls the system draws itself ignore a custom shape style and fall back to white.
    func themeTint(_ color: ThemeColor) -> some View { modifier(ThemeTint(color: color, foreground: false)) }

    /// A foreground style for a whole screen, resolved to a plain `Color` so its bar buttons take it too.
    func themeForeground(_ color: ThemeColor) -> some View { modifier(ThemeTint(color: color, foreground: true)) }

    /// A bar's background in a theme colour, resolved to a plain `Color` for the system's own bars.
    func themeToolbarBackground(_ color: ThemeColor, for bars: ToolbarPlacement) -> some View {
        modifier(ThemeToolbarBackground(color: color, bars: bars))
    }
}

private struct ThemeToolbarBackground: ViewModifier {
    let color: ThemeColor
    let bars: ToolbarPlacement
    @Environment(\.colorTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        content.toolbarBackground(Color(color.rgba(theme.palette(dark: colorScheme == .dark), contrast == .increased)),
                                  for: bars)
    }
}

private struct ThemeTint: ViewModifier {
    let color: ThemeColor
    let foreground: Bool
    @Environment(\.colorTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        let resolved = Color(color.rgba(theme.palette(dark: colorScheme == .dark), contrast == .increased))
        if foreground {
            content.foregroundStyle(resolved)
        } else {
            content.tint(resolved)
        }
    }
}
