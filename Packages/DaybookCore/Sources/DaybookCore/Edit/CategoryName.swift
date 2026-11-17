import Foundation

public enum CategoryNameProblem: Hashable, Sendable {
    case empty
    /// Another category has the same name, ignoring case and diacritics.
    case duplicate
}

/// Rules for category names.
public enum CategoryName {
    public static func normalized(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The comparison key: trimmed, case and diacritics folded.
    static func key(_ name: String) -> String {
        normalized(name).folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }

    /// Problems of `name` among `existing`; the category being renamed is `excluding`.
    public static func problems(_ name: String, among existing: [Category], excluding: UUID? = nil) -> [CategoryNameProblem] {
        let key = key(name)
        if key.isEmpty { return [.empty] }
        if existing.contains(where: { $0.id != excluding && Self.key($0.name) == key }) { return [.duplicate] }
        return []
    }
}
