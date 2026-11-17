import Foundation

/// A category: Daybook's own label for events, stored outside the calendar database.
/// It carries a symbol, never a colour: colour belongs to calendars.
public struct Category: Identifiable, Hashable, Sendable, Codable {
    public let id: UUID
    public var name: String
    /// An SF Symbol name.
    public var symbol: String
    /// Position in the sidebar, ascending.
    public var order: Int

    public init(id: UUID = UUID(), name: String, symbol: String, order: Int) {
        self.id = id
        self.name = name
        self.symbol = symbol
        self.order = order
    }
}

/// What an assignment covers: the whole series (or a single event, wherever it moves), or one occurrence.
public enum CategoryScope: Hashable, Sendable, Codable {
    case series
    case occurrence
}

/// One category on one event. Without an occurrence start it covers the whole series.
public struct CategoryAssignment: Hashable, Sendable, Codable {
    public let categoryID: UUID
    public let externalID: String
    /// `nil` for the whole series; otherwise the start of the one occurrence.
    public let occurrenceStart: Date?

    public init(categoryID: UUID, externalID: String, occurrenceStart: Date?) {
        self.categoryID = categoryID
        self.externalID = externalID
        self.occurrenceStart = occurrenceStart
    }

    public var scope: CategoryScope { occurrenceStart == nil ? .series : .occurrence }
}
