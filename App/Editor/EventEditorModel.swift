import DaybookCore
import Foundation
import Observation

/// The form state of one open event editor. `AppModel` performs the save; this only holds
/// what the user typed and what the form must ask or show.
@MainActor
@Observable
final class EventEditorModel: Identifiable {
    let id = UUID()
    let calendar: Calendar
    /// The event being edited; `nil` for a new event. Replaced after an intermediate save
    /// (before the system invitation editor opens), so a second save updates instead of duplicating.
    private(set) var original: EventInfo?
    /// The draft as it was when the editor opened or last saved, to tell whether anything changed.
    private(set) var savedDraft: EventDraft
    var draft: EventDraft
    /// The text of a failed save, shown in an alert while the form keeps its data.
    var errorMessage: String?
    /// The event's categories as the form has them, and as they were when it opened or last saved.
    var categorySelection: CategorySelection
    private(set) var savedCategorySelection: CategorySelection
    /// For an occurrence of a recurring event: whether category changes apply to the whole series.
    var categoryScope: CategoryScope = .series

    init(draft: EventDraft, original: EventInfo?, calendar: Calendar,
         categories: CategorySelection = CategorySelection()) {
        self.draft = draft
        self.savedDraft = draft
        self.original = original
        self.calendar = calendar
        self.categorySelection = categories
        self.savedCategorySelection = categories
    }

    var isNew: Bool { original == nil }
    /// Whether the event itself changed (categories are stored apart from it).
    var draftChanged: Bool { draft != savedDraft }
    var categoriesChanged: Bool { categorySelection != savedCategorySelection }
    var hasChanges: Bool { draftChanged || categoriesChanged }
    /// Only an occurrence of an existing recurring event offers "Jen tato událost".
    var offersOccurrenceCategories: Bool { original?.isRecurring == true }
    var problems: [DraftProblem] { draft.problems(calendar: calendar) }

    /// The spans the save must ask about; empty when there is nothing to ask.
    var spanChoices: [EditSpan] {
        // A change of categories alone does not touch the event, so it asks nothing.
        guard let original, draftChanged else { return [] }
        return draft.spanChoices(original: original)
    }

    /// The calendar the dates are shown in: the draft's zone, the device's otherwise.
    var displayCalendar: Calendar {
        var shown = calendar
        if let id = draft.timeZoneID, let zone = TimeZone(identifier: id) { shown.timeZone = zone }
        return shown
    }

    /// Start, moving the end with it so the length stays.
    var start: Date {
        get { draft.start }
        set { draft.setStart(newValue, calendar: displayCalendar) }
    }

    var isAllDay: Bool {
        get { draft.isAllDay }
        set { draft.setAllDay(newValue, calendar: calendar) }
    }

    var timeZoneID: String {
        get { draft.timeZoneID ?? calendar.timeZone.identifier }
        set { draft.changeTimeZone(to: newValue, calendar: calendar) }
    }

    /// The zones offered: the device's, the event's, and common ones.
    var timeZoneChoices: [String] {
        let common = ["Europe/Prague", "Europe/London", "Europe/Lisbon", "Europe/Berlin", "Europe/Helsinki",
                      "Europe/Moscow", "Asia/Dubai", "Asia/Kolkata", "Asia/Singapore", "Asia/Shanghai",
                      "Asia/Tokyo", "Australia/Sydney", "Pacific/Auckland", "America/Sao_Paulo",
                      "America/New_York", "America/Chicago", "America/Denver", "America/Los_Angeles", "UTC"]
        var result = [calendar.timeZone.identifier]
        if let id = draft.timeZoneID { result.append(id) }
        for id in common where !result.contains(id) { result.append(id) }
        return result
    }

    /// Recorded after a save that keeps the editor open.
    func didSave(as event: EventInfo) {
        original = event
        savedDraft = draft
    }

    /// Recorded after the categories were written.
    func didSaveCategories() {
        savedCategorySelection = categorySelection
    }
}
