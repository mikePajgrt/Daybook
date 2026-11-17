// Prints the window number of the largest on-screen window owned by the named app, for `screencapture -l`.
// With --bounds, prints that window's frame as x,y,w,h instead, for `screencapture -R`: a region capture
// also shows the window's popovers and sheets, which are separate windows on top of it.
// Usage: swift scripts/window-id.swift Daybook [--bounds]
import CoreGraphics

let owner = CommandLine.arguments.dropFirst().first ?? "Daybook"
let wantsBounds = CommandLine.arguments.contains("--bounds")
let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
    as? [[String: Any]] ?? []
let candidates = windows.filter {
    ($0[kCGWindowOwnerName as String] as? String) == owner && ($0[kCGWindowLayer as String] as? Int) == 0
}
func area(_ window: [String: Any]) -> Double {
    let bounds = window[kCGWindowBounds as String] as? [String: Double] ?? [:]
    return (bounds["Width"] ?? 0) * (bounds["Height"] ?? 0)
}
if let best = candidates.max(by: { area($0) < area($1) }), let number = best[kCGWindowNumber as String] as? Int {
    if wantsBounds {
        let b = best[kCGWindowBounds as String] as? [String: Double] ?? [:]
        print("\(Int(b["X"] ?? 0)),\(Int(b["Y"] ?? 0)),\(Int(b["Width"] ?? 0)),\(Int(b["Height"] ?? 0))")
    } else {
        print(number)
    }
} else {
    exit(1)
}
