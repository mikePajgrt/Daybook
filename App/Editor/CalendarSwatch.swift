import DaybookCore
import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// A calendar's colour as a dot that keeps its colour inside system menus and pickers,
/// which otherwise draw images as monochrome templates.
enum CalendarSwatch {
    /// Clear space drawn after the dot: menus and pickers set the name almost against the icon.
    static let trailingGap: CGFloat = 6

    static func image(_ color: RGBA, diameter: CGFloat = 12) -> Image {
        #if canImport(UIKit)
        let size = CGSize(width: diameter + trailingGap, height: diameter)
        let drawn = UIGraphicsImageRenderer(size: size).image { context in
            UIColor(red: color.r, green: color.g, blue: color.b, alpha: color.a).setFill()
            context.cgContext.fillEllipse(in: CGRect(x: 0, y: 0, width: diameter, height: diameter))
        }
        return Image(uiImage: drawn.withRenderingMode(.alwaysOriginal))
        #else
        let drawn = NSImage(size: NSSize(width: diameter + trailingGap, height: diameter), flipped: false) { _ in
            NSColor(srgbRed: color.r, green: color.g, blue: color.b, alpha: color.a).setFill()
            NSBezierPath(ovalIn: NSRect(x: 0, y: 0, width: diameter, height: diameter)).fill()
            return true
        }
        drawn.isTemplate = false
        return Image(nsImage: drawn)
        #endif
    }
}

/// A calendar as a picker row: its colour and its name, so colour is never the only cue.
struct CalendarLabel: View {
    let calendar: CalendarInfo
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Label {
            Text(calendar.title)
        } icon: {
            // Drawn as an image, so the line colour for the appearance on screen is chosen here.
            CalendarSwatch.image(Theme.lineRGBA(calendar.color, dark: colorScheme == .dark))
        }
    }
}
