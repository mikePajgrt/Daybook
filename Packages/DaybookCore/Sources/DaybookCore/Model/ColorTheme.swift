import Foundation

extension RGBA {
    /// `0xRRGGBB`, opaque unless `alpha` says otherwise.
    public init(hex: UInt32, alpha: Double = 1) {
        self.init(r: Double((hex >> 16) & 0xff) / 255, g: Double((hex >> 8) & 0xff) / 255,
                  b: Double(hex & 0xff) / 255, a: alpha)
    }

    /// "#rrggbb", for tests and the design record.
    public var hexString: String {
        func byte(_ v: Double) -> Int { Int((min(max(v, 0), 1) * 255).rounded()) }
        return String(format: "#%02x%02x%02x", byte(r), byte(g), byte(b))
    }

    /// WCAG contrast ratio against `other`, both taken as opaque.
    public func contrast(with other: RGBA) -> Double { Palette.contrast(self, other) }

    /// This colour with its own opacity composited over an opaque `background`, as the screen shows it.
    public func composited(over background: RGBA) -> RGBA { Palette.over(self, opacity: a, on: background) }
}

/// One appearance of a colour theme: the surfaces, the ink and what is derived from the ink. Calendar
/// colours are not part of it; they are user data, drawn through `line(_:increased:)` on this ground.
///
/// There is deliberately no accent. Hue on a calendar surface means "this calendar" (DESIGN.md, The Line
/// Is the Only Colour Rule), so a theme brings its character through the ground, the rail, the ink and
/// the ink of controls (`controlInk`), which may lean toward the theme's hue but stays deep (light) or
/// pale (dark) enough to read as ink, never as a line.
public struct ThemePalette: Hashable, Sendable {
    /// The surface the calendar is drawn on.
    public let ground: RGBA
    /// The sidebar and list-sheet backdrop, one step deeper than the ground.
    public let rail: RGBA
    /// Text, the interchange circle that marks today, selection rings.
    public let ink: RGBA
    /// The fill of a station dot.
    public let station: RGBA
    /// Text of days in the neighbouring month: opaque, 4.5:1 on the ground.
    public let outsideInk: RGBA
    /// Tint of menus, form controls and bordered buttons.
    public let controlInk: RGBA
    /// A switch's "on" track: the white knob holds 3:1 on it.
    public let switchOn: RGBA
    /// The veil over Saturday and Sunday (carries its own opacity).
    public let weekend: RGBA
    /// Opacity of the ink for secondary text (times, captions), normal and under Increased Contrast.
    public let secondaryOpacity: Double
    public let secondaryOpacityIncreased: Double

    /// Hairlines: ink at 16%, 32% under Increased Contrast, in every theme.
    public static let ruleOpacity = 0.16
    public static let ruleOpacityIncreased = 0.32
    /// Time and place inside an event block: ink at 80%, 90% under Increased Contrast.
    public static let blockSecondaryOpacity = 0.8
    public static let blockSecondaryOpacityIncreased = 0.9
    /// The neighbouring month's text under Increased Contrast: ink at 85%.
    public static let outsideOpacityIncreased = 0.85

    public init(ground: RGBA, rail: RGBA, ink: RGBA, station: RGBA, outsideInk: RGBA, controlInk: RGBA? = nil,
                switchOn: RGBA, weekend: RGBA, secondaryOpacity: Double = 0.62, secondaryOpacityIncreased: Double = 0.8) {
        self.ground = ground
        self.rail = rail
        self.ink = ink
        self.station = station
        self.outsideInk = outsideInk
        self.controlInk = controlInk ?? ink
        self.switchOn = switchOn
        self.weekend = weekend
        self.secondaryOpacity = secondaryOpacity
        self.secondaryOpacityIncreased = secondaryOpacityIncreased
    }

    /// Whether this is a dark appearance (the ground is darker than the ink).
    public var isDark: Bool { Palette.luminance(ground) < Palette.luminance(ink) }

    public func secondaryInk(increased: Bool) -> RGBA {
        ink.withAlpha(increased ? secondaryOpacityIncreased : secondaryOpacity)
    }

    public func rule(increased: Bool) -> RGBA {
        ink.withAlpha(increased ? Self.ruleOpacityIncreased : Self.ruleOpacity)
    }

    public func blockSecondaryInk(increased: Bool) -> RGBA {
        ink.withAlpha(increased ? Self.blockSecondaryOpacityIncreased : Self.blockSecondaryOpacity)
    }

    public func outsideInk(increased: Bool) -> RGBA {
        increased ? ink.withAlpha(Self.outsideOpacityIncreased) : outsideInk
    }

    /// The contrast a calendar line keeps on this ground: 3:1, 4.5:1 under Increased Contrast.
    public static func lineContrast(increased: Bool) -> Double { increased ? 4.5 : Palette.lineContrast }

    /// A calendar's colour as a line on this ground (see `Palette.lineColor`).
    public func line(_ color: RGBA, increased: Bool = false) -> RGBA {
        Palette.lineColor(color, on: ground, minimumContrast: Self.lineContrast(increased: increased))
    }

    /// The fill of an event block: the adjusted line mixed into this ground (see `Palette.blockFill`).
    public func blockFill(_ color: RGBA, increased: Bool = false) -> RGBA {
        Palette.blockFill(line(color, increased: increased), on: ground)
    }

    /// The fill of the block of an event that has passed (see `Palette.passedBlockFill`).
    public func passedBlockFill(_ color: RGBA, increased: Bool = false) -> RGBA {
        Palette.passedBlockFill(line(color, increased: increased), on: ground)
    }

    /// A span line of an event that has wholly passed: the adjusted line mixed halfway into this ground.
    /// Under Increased Contrast the line keeps its full strength; only its title steps back.
    public func passedSpanLine(_ color: RGBA, increased: Bool = false) -> RGBA {
        increased ? line(color, increased: true) : Palette.passedLine(line(color), on: ground)
    }
}

extension RGBA {
    func withAlpha(_ alpha: Double) -> RGBA { RGBA(r: r, g: g, b: b, a: alpha) }
}

/// The colour themes offered in Settings. Each has a light and a dark palette, so the system appearance
/// (or the user's own choice of one) keeps working in every theme.
public enum ColorTheme: String, CaseIterable, Identifiable, Sendable {
    /// The midnight transit diagram the app was designed in. The default.
    case nocturne
    /// Petrol and teal, after the BOSS web app.
    case boss
    /// Neutral greys by day, deep navy by night, after the KISS web app.
    case kiss
    /// Blue-grey, after Kastl's Slate.
    case slate
    /// Neutral graphite, after Kastl's Graphite.
    case graphite

    public static let `default` = ColorTheme.nocturne

    public var id: String { rawValue }

    /// The name shown in Settings for the themes named after something (proper nouns, not translated);
    /// `nil` for the default, whose name the app translates.
    public var properName: String? {
        switch self {
        case .nocturne: nil
        case .boss: "BOSS"
        case .kiss: "KISS"
        case .slate: "Slate"
        case .graphite: "Graphite"
        }
    }

    public func palette(dark: Bool) -> ThemePalette {
        dark ? darkPalette : lightPalette
    }

    private var lightPalette: ThemePalette {
        switch self {
        case .nocturne:
            // Exactly the values the app had before themes.
            ThemePalette(ground: Palette.porcelain, rail: RGBA(r: 0.918, g: 0.902, b: 0.867), ink: Palette.midnight,
                         station: RGBA(r: 1, g: 1, b: 1), outsideInk: RGBA(r: 0.357, g: 0.384, b: 0.471),
                         switchOn: Palette.midnight, weekend: Palette.midnight.withAlpha(0.05))
        case .boss:
            ThemePalette(ground: RGBA(hex: 0xf5f8f9), rail: RGBA(hex: 0xe6eef1), ink: RGBA(hex: 0x0f2e38),
                         station: RGBA(hex: 0xffffff), outsideInk: RGBA(hex: 0x5b7178), controlInk: RGBA(hex: 0x0f4c5c),
                         switchOn: RGBA(hex: 0x0f4c5c), weekend: RGBA(hex: 0x0f2e38, alpha: 0.05), secondaryOpacity: 0.68)
        case .kiss:
            ThemePalette(ground: RGBA(hex: 0xf4f4f4), rail: RGBA(hex: 0xe6edf0), ink: RGBA(hex: 0x0a0a0a),
                         station: RGBA(hex: 0xffffff), outsideInk: RGBA(hex: 0x6c6c6c), controlInk: RGBA(hex: 0x1d6a87),
                         switchOn: RGBA(hex: 0x1d6a87), weekend: RGBA(hex: 0x0a0a0a, alpha: 0.05))
        case .slate:
            ThemePalette(ground: RGBA(hex: 0xeef1f3), rail: RGBA(hex: 0xe0e6ea), ink: RGBA(hex: 0x1f2f38),
                         station: RGBA(hex: 0xffffff), outsideInk: RGBA(hex: 0x5f6b72),
                         switchOn: RGBA(hex: 0x1f2f38), weekend: RGBA(hex: 0x1f2f38, alpha: 0.05), secondaryOpacity: 0.7)
        case .graphite:
            ThemePalette(ground: RGBA(hex: 0xf2f2f4), rail: RGBA(hex: 0xe4e4e8), ink: RGBA(hex: 0x2a2a31),
                         station: RGBA(hex: 0xffffff), outsideInk: RGBA(hex: 0x6a6a6f),
                         switchOn: RGBA(hex: 0x2a2a31), weekend: RGBA(hex: 0x2a2a31, alpha: 0.05), secondaryOpacity: 0.7)
        }
    }

    private var darkPalette: ThemePalette {
        let black = RGBA(r: 0, g: 0, b: 0, a: 0.18)
        switch self {
        case .nocturne:
            return ThemePalette(ground: Palette.midnight, rail: RGBA(r: 0.039, g: 0.078, b: 0.188), ink: Palette.porcelain,
                                station: Palette.porcelain, outsideInk: RGBA(r: 0.561, g: 0.592, b: 0.678),
                                switchOn: RGBA(r: 0.551, g: 0.566, b: 0.607), weekend: black)
        case .boss:
            return ThemePalette(ground: RGBA(hex: 0x12262e), rail: RGBA(hex: 0x0c1c22), ink: RGBA(hex: 0xe8f1f3),
                                station: RGBA(hex: 0xe8f1f3), outsideInk: RGBA(hex: 0x839296),
                                controlInk: RGBA(hex: 0xb4e3dc), switchOn: RGBA(hex: 0x739796), weekend: black)
        case .kiss:
            return ThemePalette(ground: RGBA(hex: 0x151d2d), rail: RGBA(hex: 0x070e21), ink: RGBA(hex: 0xedf2f8),
                                station: RGBA(hex: 0xedf2f8), outsideInk: RGBA(hex: 0x838a95),
                                controlInk: RGBA(hex: 0xa3dcf2), switchOn: RGBA(hex: 0x7097ab), weekend: black)
        case .slate:
            return ThemePalette(ground: RGBA(hex: 0x2d414d), rail: RGBA(hex: 0x273743), ink: RGBA(hex: 0xf8f8f8),
                                station: RGBA(hex: 0xf8f8f8), outsideInk: RGBA(hex: 0xa7afb4),
                                switchOn: RGBA(hex: 0x88939a), weekend: black)
        case .graphite:
            return ThemePalette(ground: RGBA(hex: 0x42424c), rail: RGBA(hex: 0x31313a), ink: RGBA(hex: 0xf8f8f8),
                                station: RGBA(hex: 0xf8f8f8), outsideInk: RGBA(hex: 0xb5b5b8),
                                switchOn: RGBA(hex: 0x909096), weekend: black)
        }
    }
}

/// Light, dark, or whatever the system is set to.
public enum AppearanceChoice: String, CaseIterable, Identifiable, Sendable {
    case system, light, dark

    public var id: String { rawValue }
}
