// Draws Daybook's app icon with CoreGraphics and writes App/Assets.xcassets/AppIcon.appiconset.
// The icon is the world's own diagram: the midnight ground, three calendar lines in preset colours
// with white station dots, meeting at a porcelain interchange circle. No downloaded or third-party art.
// iOS gets one full-bleed 1024 px square (the system masks it); macOS gets the rounded tile drawn in,
// at every size the asset catalog asks for.
// Usage (from the repo root): swift scripts/make-app-icon.swift
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct RGB { let r, g, b: CGFloat }
let midnight = RGB(r: 0.055, g: 0.102, b: 0.227)
let porcelain = RGB(r: 0.957, g: 0.945, b: 0.918)
// Three of the line presets (DESIGN.md): red, blue, green.
let red = RGB(r: 0.93, g: 0.27, b: 0.27)
let blue = RGB(r: 0.23, g: 0.51, b: 1.00)
let green = RGB(r: 0.12, g: 0.60, b: 0.35)

func color(_ c: RGB) -> CGColor { CGColor(srgbRed: c.r, green: c.g, blue: c.b, alpha: 1) }

/// The diagram on a 1024-unit square, y pointing down.
func drawDiagram(_ ctx: CGContext) {
    ctx.setFillColor(color(midnight))
    ctx.fill(CGRect(x: 0, y: 0, width: 1024, height: 1024))
    ctx.setLineCap(.butt)
    ctx.setLineJoin(.round)
    ctx.setLineWidth(72)
    let interchange = CGPoint(x: 430, y: 470)

    func line(_ points: [CGPoint], _ c: RGB) {
        ctx.setStrokeColor(color(c))
        ctx.beginPath()
        ctx.addLines(between: points)
        ctx.strokePath()
    }
    // Green runs across, red runs down, blue cuts through at 45 degrees and turns flat:
    // three lines through one interchange, the way a busy day crosses calendars.
    line([CGPoint(x: -60, y: 470), CGPoint(x: 1084, y: 470)], green)
    line([CGPoint(x: 430, y: -60), CGPoint(x: 430, y: 1084)], red)
    line([CGPoint(x: -60, y: -20), CGPoint(x: 760, y: 800), CGPoint(x: 1084, y: 800)], blue)

    func station(_ p: CGPoint, _ c: RGB) {
        let r: CGFloat = 46
        ctx.setFillColor(color(porcelain))
        ctx.fillEllipse(in: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2))
        ctx.setStrokeColor(color(c))
        ctx.setLineWidth(18)
        ctx.strokeEllipse(in: CGRect(x: p.x - r + 9, y: p.y - r + 9, width: r * 2 - 18, height: r * 2 - 18))
    }
    station(CGPoint(x: 160, y: 470), green)
    station(CGPoint(x: 780, y: 470), green)
    station(CGPoint(x: 430, y: 170), red)
    station(CGPoint(x: 430, y: 820), red)
    station(CGPoint(x: 940, y: 800), blue)

    // The interchange: a porcelain circle ringed in the ground, as today is drawn.
    let r: CGFloat = 112
    ctx.setFillColor(color(midnight))
    ctx.fillEllipse(in: CGRect(x: interchange.x - r - 22, y: interchange.y - r - 22, width: (r + 22) * 2, height: (r + 22) * 2))
    ctx.setFillColor(color(porcelain))
    ctx.fillEllipse(in: CGRect(x: interchange.x - r, y: interchange.y - r, width: r * 2, height: r * 2))
}

func render(pixels: Int, macTile: Bool) -> CGImage {
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    let ctx = CGContext(data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                        bitmapInfo: macTile ? CGImageAlphaInfo.premultipliedLast.rawValue
                                            : CGImageAlphaInfo.noneSkipLast.rawValue)!
    ctx.interpolationQuality = .high
    let scale = CGFloat(pixels) / 1024
    // Flip to y-down units of a 1024 square.
    ctx.translateBy(x: 0, y: CGFloat(pixels))
    ctx.scaleBy(x: scale, y: -scale)
    if macTile {
        // macOS: the tile sits on the 1024 grid at 824 units with a continuous-corner radius of about 185.
        let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
        ctx.addPath(CGPath(roundedRect: tile, cornerWidth: 185, cornerHeight: 185, transform: nil))
        ctx.clip()
        ctx.translateBy(x: 100, y: 100)
        ctx.scaleBy(x: 824.0 / 1024, y: 824.0 / 1024)
    }
    drawDiagram(ctx)
    return ctx.makeImage()!
}

func write(_ image: CGImage, to url: URL) {
    let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { fatalError("could not write \(url.path)") }
}

let folder = URL(fileURLWithPath: "App/Assets.xcassets/AppIcon.appiconset", isDirectory: true)
try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
var images: [[String: String]] = []

write(render(pixels: 1024, macTile: false), to: folder.appendingPathComponent("icon-ios-1024.png"))
images.append(["filename": "icon-ios-1024.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"])

for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = "icon-mac-\(points)@\(scale)x.png"
        write(render(pixels: points * scale, macTile: true), to: folder.appendingPathComponent(name))
        images.append(["filename": name, "idiom": "mac", "scale": "\(scale)x", "size": "\(points)x\(points)"])
    }
}

let contents: [String: Any] = ["images": images, "info": ["author": "xcode", "version": 1]]
let json = try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
try json.write(to: folder.appendingPathComponent("Contents.json"))
let catalog: [String: Any] = ["info": ["author": "xcode", "version": 1]]
try JSONSerialization.data(withJSONObject: catalog, options: [.prettyPrinted])
    .write(to: URL(fileURLWithPath: "App/Assets.xcassets/Contents.json"))
print("wrote \(images.count) icons to \(folder.path)")
