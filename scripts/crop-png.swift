// Crops a PNG to a rectangle given in pixels from its top-left corner.
// Usage: swift scripts/crop-png.swift IN OUT X Y WIDTH HEIGHT
import AppKit

let arguments = CommandLine.arguments
guard arguments.count == 7, let image = NSImage(contentsOfFile: arguments[1]),
      let x = Int(arguments[3]), let y = Int(arguments[4]), let width = Int(arguments[5]), let height = Int(arguments[6])
else {
    print("usage: crop-png.swift IN OUT X Y WIDTH HEIGHT")
    exit(1)
}
var rect = CGRect(origin: .zero, size: image.size)
guard let full = image.cgImage(forProposedRect: &rect, context: nil, hints: nil),
      let cropped = full.cropping(to: CGRect(x: x, y: y, width: width, height: height)),
      let data = NSBitmapImageRep(cgImage: cropped).representation(using: .png, properties: [:])
else {
    print("could not crop \(arguments[1])")
    exit(1)
}
try data.write(to: URL(fileURLWithPath: arguments[2]))
