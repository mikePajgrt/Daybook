import Foundation

/// The app's version as Settings and the Mac About panel show it: "0.1.0 (20261118.1045, 1d21270)",
/// or "0.1.0 (1)" for a development build, which carries no commit.
public enum AppVersion {
    /// Info.plist key with the short commit hash (`DAYBOOK_COMMIT`; set by the release scripts and the
    /// "Stamp build number" build phase).
    public static let commitKey = "DaybookCommit"

    /// What follows the version in parentheses: the build number and, when known, the commit.
    public static func detail(info: [String: Any]) -> String {
        let build = string(info["CFBundleVersion"])
        let commit = string(info[commitKey])
        return [build, commit].filter { !$0.isEmpty }.joined(separator: ", ")
    }

    /// The version and its detail, e.g. "0.1.0 (1)".
    public static func text(info: [String: Any]) -> String {
        let version = string(info["CFBundleShortVersionString"])
        let detail = detail(info: info)
        if detail.isEmpty { return version }
        return version.isEmpty ? detail : "\(version) (\(detail))"
    }

    private static func string(_ value: Any?) -> String {
        let text = (value as? String)?.trimmingCharacters(in: .whitespaces) ?? ""
        // An unexpanded "$(…)" means the build setting was missing.
        return text.hasPrefix("$(") ? "" : text
    }
}
