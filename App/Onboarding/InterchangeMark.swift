import SwiftUI

/// Daybook's mark, drawn as the app icon is (scripts/make-app-icon.swift): three calendar lines with
/// their stations meeting at the interchange circle, on the midnight tile. The same in both
/// appearances, as an app icon is.
struct InterchangeMark: View {
    var body: some View {
        Canvas { context, size in
            let unit = size.width / 1024
            func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * unit, y: y * unit) }
            func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> Color { Color(red: r, green: g, blue: b) }
            let midnight = color(0.055, 0.102, 0.227)
            let porcelain = color(0.957, 0.945, 0.918)
            let red = color(0.93, 0.27, 0.27)
            let blue = color(0.23, 0.51, 1.00)
            let green = color(0.12, 0.60, 0.35)

            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(midnight))
            func line(_ points: [CGPoint], _ c: Color) {
                var path = Path()
                path.addLines(points)
                context.stroke(path, with: .color(c), style: StrokeStyle(lineWidth: 72 * unit, lineCap: .butt, lineJoin: .round))
            }
            line([point(-60, 470), point(1084, 470)], green)
            line([point(430, -60), point(430, 1084)], red)
            line([point(-60, -20), point(760, 800), point(1084, 800)], blue)

            func circle(_ center: CGPoint, _ radius: CGFloat) -> Path {
                Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
            }
            for (center, c) in [(point(160, 470), green), (point(780, 470), green), (point(430, 170), red),
                                (point(430, 820), red), (point(940, 800), blue)] {
                context.fill(circle(center, 46 * unit), with: .color(porcelain))
                context.stroke(circle(center, 37 * unit), with: .color(c), lineWidth: 18 * unit)
            }
            let interchange = point(430, 470)
            context.fill(circle(interchange, 134 * unit), with: .color(midnight))
            context.fill(circle(interchange, 112 * unit), with: .color(porcelain))
        }
        .aspectRatio(1, contentMode: .fit)
        // The platform's icon shape: a continuous corner of about 22% of the side.
        .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
        // A hairline keeps the tile's edge where the ground is midnight too.
        .overlay { RoundedRectangle(cornerRadius: 17, style: .continuous).strokeBorder(Theme.rule, lineWidth: 1) }
        .accessibilityHidden(true)
    }
}
