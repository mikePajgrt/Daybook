// Prints the window number of the largest on-screen window owned by the named app, for `screencapture -l`.
// Usage: swift scripts/window-id.swift Daybook
import CoreGraphics

let owner = CommandLine.arguments.dropFirst().first ?? "Daybook"
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
    print(number)
} else {
    exit(1)
}
