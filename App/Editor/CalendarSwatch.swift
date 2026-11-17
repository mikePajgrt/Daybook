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
    static func image(_ color: RGBA, diameter: CGFloat = 12) -> Image {
        #if canImport(UIKit)
        let size = CGSize(width: diameter, height: diameter)
        let drawn = UIGraphicsImageRenderer(size: size).image { context in
            UIColor(red: color.r, green: color.g, blue: color.b, alpha: color.a).setFill()
            context.cgContext.fillEllipse(in: CGRect(origin: .zero, size: size))
        }
        return Image(uiImage: drawn.withRenderingMode(.alwaysOriginal))
        #else
        let drawn = NSImage(size: NSSize(width: diameter, height: diameter), flipped: false) { rect in
            NSColor(srgbRed: color.r, green: color.g, blue: color.b, alpha: color.a).setFill()
            NSBezierPath(ovalIn: rect).fill()
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

    var body: some View {
        Label {
            Text(calendar.title)
        } icon: {
            CalendarSwatch.image(calendar.color)
        }
    }
}
