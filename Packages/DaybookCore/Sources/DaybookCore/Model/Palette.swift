import Foundation

/// The world's grounds and the colour arithmetic the app needs: WCAG contrast and mixing in OKLab,
/// so a calendar colour thinned toward the ground keeps its lightness relation instead of going muddy.
public enum Palette {
    /// The dark ground.
    public static let midnight = RGBA(r: 0.055, g: 0.102, b: 0.227)
    /// The light ground.
    public static let porcelain = RGBA(r: 0.957, g: 0.945, b: 0.918)

    /// How much of the calendar's colour an event block's fill carries.
    public static let blockFillAmount = 0.22

    /// Fill of an event block in the week and day views: `color` mixed into `ground` in OKLab.
    public static func blockFill(_ color: RGBA, on ground: RGBA) -> RGBA {
        mix(ground, color, amount: blockFillAmount)
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
