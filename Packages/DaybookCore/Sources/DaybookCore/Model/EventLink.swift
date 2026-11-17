import Foundation

/// Event URLs arrive from other people's invitations, so they are untrusted.
/// Only web and mail links may be opened; any other scheme is shown as text.
public enum EventLink {
    private static let openableSchemes: Set<String> = ["http", "https", "mailto"]

    /// True for http, https and mailto URLs, compared case-insensitively.
    public static func isOpenable(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased() else { return false }
        return openableSchemes.contains(scheme)
    }
}
