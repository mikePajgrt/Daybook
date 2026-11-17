import Foundation

/// The world's grounds and the colour arithmetic the app needs: WCAG contrast and mixing in OKLab,
/// so a calendar colour thinned toward the ground keeps its lightness relation instead of going muddy.
public enum Palette {
    /// The dark ground.
    public static let midnight = RGBA(r: 0.055, g: 0.102, b: 0.227)
    /// The light ground.
    public static let porcelain = RGBA(r: 0.957, g: 0.945, b: 0.918)

    /// Calendar colours the colour picker offers first: red, orange, amber, green, teal, blue, violet, pink.
    /// Each keeps 3:1 against both grounds, so a line drawn in it reads in both appearances.
    public static let calendarPresets: [RGBA] = [
        RGBA(r: 0.93, g: 0.27, b: 0.27),
        RGBA(r: 0.86, g: 0.40, b: 0.05),
        RGBA(r: 0.72, g: 0.50, b: 0.00),
        RGBA(r: 0.12, g: 0.60, b: 0.35),
        RGBA(r: 0.00, g: 0.60, b: 0.62),
        RGBA(r: 0.23, g: 0.51, b: 1.00),
        RGBA(r: 0.66, g: 0.36, b: 0.93),
        RGBA(r: 0.91, g: 0.30, b: 0.60)
    ]

    /// How much of the calendar's colour an event block's fill carries.
    public static let blockFillAmount = 0.22

    /// Every chromatic calendar's block fill has at least this OKLab chroma, in the calendar's own hue.
    public static let blockFillChromaFloor = 0.045
    /// Calendar colours with less OKLab chroma than this are greys: their fill is the plain mix.
    public static let achromaticBelow = 0.04

    /// Fill of an event block in the week and day views: `color` mixed into `ground` in OKLab, then
    /// turned to the calendar's own hue with at least `blockFillChromaFloor` of chroma. A plain mix
    /// lets a blue ground cancel a warm colour (amber became grey on midnight); this keeps one rule
    /// for every calendar: lightness from the mix, hue from the line.
    public static func blockFill(_ color: RGBA, on ground: RGBA) -> RGBA {
        let mixed = mix(ground, color, amount: blockFillAmount)
        let line = oklab(color)
        let lineChroma = hypot(line.1, line.2)
        guard lineChroma >= achromaticBelow else { return mixed }
        let lab = oklab(mixed)
        let chroma = max(hypot(lab.1, lab.2), blockFillChromaFloor)
        return rgb(fromOklab: (lab.0, line.1 / lineChroma * chroma, line.2 / lineChroma * chroma))
    }

    /// OKLab chroma of a colour.
    public static func chroma(_ c: RGBA) -> Double {
        let lab = oklab(c)
        return hypot(lab.1, lab.2)
    }

    /// OKLab hue angle of a colour, 0 to 360 degrees.
    public static func hue(_ c: RGBA) -> Double {
        let lab = oklab(c)
        let degrees = atan2(lab.2, lab.1) * 180 / .pi
        return degrees < 0 ? degrees + 360 : degrees
    }

    /// `color` at `opacity` composited over an opaque `background`, in sRGB as the screen does.
    public static func over(_ color: RGBA, opacity: Double, on background: RGBA) -> RGBA {
        RGBA(r: color.r * opacity + background.r * (1 - opacity),
             g: color.g * opacity + background.g * (1 - opacity),
             b: color.b * opacity + background.b * (1 - opacity))
    }

    /// WCAG relative luminance.
    public static func luminance(_ c: RGBA) -> Double {
        0.2126 * linear(c.r) + 0.7152 * linear(c.g) + 0.0722 * linear(c.b)
    }

    /// WCAG contrast ratio, 1 to 21.
    public static func contrast(_ a: RGBA, _ b: RGBA) -> Double {
        let la = luminance(a), lb = luminance(b)
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    /// `amount` of the way from `a` to `b`, interpolated in OKLab. Opaque result.
    public static func mix(_ a: RGBA, _ b: RGBA, amount: Double) -> RGBA {
        let p = oklab(a), q = oklab(b)
        let t = min(max(amount, 0), 1)
        return rgb(fromOklab: (p.0 + (q.0 - p.0) * t, p.1 + (q.1 - p.1) * t, p.2 + (q.2 - p.2) * t))
    }

    // MARK: - Conversions

    private static func linear(_ c: Double) -> Double {
        c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
    }

    private static func gamma(_ c: Double) -> Double {
        let v = min(max(c, 0), 1)
        return v <= 0.0031308 ? 12.92 * v : 1.055 * pow(v, 1 / 2.4) - 0.055
    }

    private static func oklab(_ c: RGBA) -> (Double, Double, Double) {
        let r = linear(c.r), g = linear(c.g), b = linear(c.b)
        let l = cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b)
        let m = cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b)
        let s = cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b)
        return (0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
                1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
                0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s)
    }

    private static func rgb(fromOklab lab: (Double, Double, Double)) -> RGBA {
        let l = pow(lab.0 + 0.3963377774 * lab.1 + 0.2158037573 * lab.2, 3)
        let m = pow(lab.0 - 0.1055613458 * lab.1 - 0.0638541728 * lab.2, 3)
        let s = pow(lab.0 - 0.0894841775 * lab.1 - 1.2914855480 * lab.2, 3)
        return RGBA(r: gamma(4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s),
                    g: gamma(-1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s),
                    b: gamma(-0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s))
    }
}
