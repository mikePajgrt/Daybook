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
        tintedFill(color, on: ground, amount: blockFillAmount, chromaFloor: blockFillChromaFloor)
    }

    /// How much of the calendar's colour the block of an event that has passed carries: half the normal fill.
    public static let passedBlockFillAmount = blockFillAmount / 2
    /// The chroma floor of a passed block's fill: half the normal floor.
    public static let passedBlockFillChromaFloor = blockFillChromaFloor / 2

    /// Fill of the block of an event that has passed: the same rule as `blockFill` at half the mix and
    /// half the chroma floor, so the block steps back toward the ground but stays in its calendar's hue.
    public static func passedBlockFill(_ color: RGBA, on ground: RGBA) -> RGBA {
        tintedFill(color, on: ground, amount: passedBlockFillAmount, chromaFloor: passedBlockFillChromaFloor)
    }

    /// How far a span line that has wholly passed is mixed toward the ground.
    public static let passedLineAmount = 0.5

    /// A span line of an event that has wholly passed: the (adjusted) line mixed halfway into the ground
    /// in OKLab. Opaque, so rules and weekend veils under it never show through.
    public static func passedLine(_ color: RGBA, on ground: RGBA) -> RGBA {
        mix(ground, color, amount: passedLineAmount)
    }

    private static func tintedFill(_ color: RGBA, on ground: RGBA, amount: Double, chromaFloor: Double) -> RGBA {
        let mixed = mix(ground, color, amount: amount)
        let line = oklab(color)
        let lineChroma = hypot(line.1, line.2)
        guard lineChroma >= achromaticBelow else { return mixed }
        let lab = oklab(mixed)
        let chroma = max(hypot(lab.1, lab.2), chromaFloor)
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

    // MARK: - Lines

    /// Contrast a calendar line keeps against the ground it is drawn on (WCAG 1.4.11, non-text).
    public static let lineContrast = 3.0

    /// A calendar's colour as a line on `ground`: unchanged when it already holds `minimumContrast`
    /// against the ground, otherwise darkened (light ground) or lightened (dark ground) in OKLab
    /// lightness just far enough. Hue is kept; chroma is reduced only where the lighter or darker
    /// colour would leave the sRGB gamut. Opacity is kept.
    public static func lineColor(_ color: RGBA, on ground: RGBA, minimumContrast: Double = lineContrast) -> RGBA {
        let opaque = RGBA(r: color.r, g: color.g, b: color.b)
        guard contrast(opaque, ground) < minimumContrast else { return color }
        let lab = oklab(opaque)
        let darken = luminance(ground) > 0.18
        // Binary search between the colour's own lightness and black or white, for the smallest step that holds.
        var near = lab.0
        var far = darken ? 0.0 : 1.0
        var best = inGamut(lightness: far, a: lab.1, b: lab.2)
        for _ in 0..<40 {
            let middle = (near + far) / 2
            let candidate = inGamut(lightness: middle, a: lab.1, b: lab.2)
            if contrast(candidate, ground) >= minimumContrast {
                best = candidate
                far = middle
            } else {
                near = middle
            }
        }
        return RGBA(r: best.r, g: best.g, b: best.b, a: color.a)
    }

    /// The colour at OKLab lightness `l` in the hue of (`a`, `b`), with as much of that chroma as sRGB holds.
    private static func inGamut(lightness l: Double, a: Double, b: Double) -> RGBA {
        func fits(_ scale: Double) -> Bool {
            let c = linearRGB(fromOklab: (l, a * scale, b * scale))
            let tolerance = 1e-6
            return [c.0, c.1, c.2].allSatisfy { $0 >= -tolerance && $0 <= 1 + tolerance }
        }
        var scale = 1.0
        if !fits(1) {
            var low = 0.0, high = 1.0
            for _ in 0..<30 {
                let middle = (low + high) / 2
                if fits(middle) { low = middle } else { high = middle }
            }
            scale = low
        }
        return rgb(fromOklab: (l, a * scale, b * scale))
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

    private static func linearRGB(fromOklab lab: (Double, Double, Double)) -> (Double, Double, Double) {
        let l = pow(lab.0 + 0.3963377774 * lab.1 + 0.2158037573 * lab.2, 3)
        let m = pow(lab.0 - 0.1055613458 * lab.1 - 0.0638541728 * lab.2, 3)
        let s = pow(lab.0 - 0.0894841775 * lab.1 - 1.2914855480 * lab.2, 3)
        return (4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
                -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
                -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s)
    }

    private static func rgb(fromOklab lab: (Double, Double, Double)) -> RGBA {
        let c = linearRGB(fromOklab: lab)
        return RGBA(r: gamma(c.0), g: gamma(c.1), b: gamma(c.2))
    }
}
