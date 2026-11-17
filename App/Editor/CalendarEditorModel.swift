import DaybookCore
import Foundation
import Observation

/// The form state of the new-calendar sheet, or of changing one calendar's colour.
@MainActor
@Observable
final class CalendarEditorModel: Identifiable {
    enum Mode {
        case new
        case recolor(CalendarInfo)
    }

    let id = UUID()
    let mode: Mode
    /// The accounts a calendar can be created in (new calendar only).
    let sources: [SourceInfo]
    /// A Google account is present: say that its calendars are created at Google.
    let hasGoogle: Bool
    var title: String
    var color: RGBA
    var sourceID: String
    var errorMessage: String?

    init(mode: Mode, sources: [SourceInfo], hasGoogle: Bool) {
        self.mode = mode
        self.sources = sources
        self.hasGoogle = hasGoogle
        switch mode {
        case .new:
            title = ""
            color = Palette.calendarPresets[5]
        case .recolor(let calendar):
            title = calendar.title
            color = calendar.color
        }
        sourceID = sources.first?.id ?? ""
    }

    var isNew: Bool {
        if case .new = mode { return true }
        return false
    }

    var draft: CalendarDraft { CalendarDraft(title: title, color: color, sourceID: sourceID) }

    var canSave: Bool { isNew ? draft.problems.isEmpty : true }

    /// A new calendar always has something to create; a recolour only once the colour changed.
    var hasChanges: Bool {
        switch mode {
        case .new: return true
        case .recolor(let calendar): return color != calendar.color
        }
    }
}
