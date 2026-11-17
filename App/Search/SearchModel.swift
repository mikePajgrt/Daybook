import DaybookCore
import Foundation
import Observation

/// Search state: the query, whether switched-off calendars and categories count, and the results.
/// Five years back and five forward are read once per session, chunk by chunk, off the main thread;
/// typing is debounced and a newer query cancels an older one, so typing never waits for a read.
@MainActor
@Observable
final class SearchModel {
    enum Phase: Equatable {
        /// No words typed yet.
        case idle
        /// Reading or matching; results from an earlier query may still be on screen.
        case searching
        case done
    }

    /// Owner, for the store, the filters and the clock.
    @ObservationIgnored weak var app: AppModel?

    var query = "" {
        didSet { if query != oldValue { schedule(debounce: true) } }
    }
    /// "Hledat i ve vypnutých": include calendars and categories that are switched off.
    var includesHidden = false {
        didSet { if includesHidden != oldValue { schedule(debounce: false) } }
    }
    /// Whether the search field is active (it shows the results instead of the calendar).
    var isPresented = false
    /// Debug staging and ⌘F: put the cursor in the field.
    var wantsFocus = false

    private(set) var results: [SearchDay] = []
    private(set) var phase: Phase = .idle
    /// The query the results belong to, for emphasising matches.
    private(set) var resultQuery = ""
    /// Whether switched-off calendars or categories hide anything right now, so the toggle matters.
    var filterHidesSomething: Bool {
        guard let app else { return false }
        return !app.filter.hiddenIDs.isEmpty || app.categoryModel.filter.isFiltering
    }

    /// Every event of every calendar in the search range, read once per session.
    @ObservationIgnored private var corpus: [EventInfo]?
    @ObservationIgnored private var corpusTask: Task<[EventInfo], Never>?
    @ObservationIgnored private var searchTask: Task<Void, Never>?

    /// How long typing must pause before a search starts.
    static let debounce: Duration = .milliseconds(250)

    var hasQuery: Bool { !EventSearch.terms(query).isEmpty }

    // MARK: Changes from outside

    /// The calendar database changed: read again before the next match.
    func databaseChanged() {
        corpus = nil
        corpusTask?.cancel()
        corpusTask = nil
        if hasQuery { schedule(debounce: false) }
    }

    /// Filters or today changed: match again against what is read.
    func filterChanged() {
        if hasQuery { schedule(debounce: false) }
    }

    // MARK: Searching

    private func schedule(debounce: Bool) {
        searchTask?.cancel()
        guard hasQuery else {
            results = []
            resultQuery = ""
            phase = .idle
            return
        }
        phase = .searching
        let query = query
        searchTask = Task { [weak self] in
            if debounce { try? await Task.sleep(for: Self.debounce) }
            guard !Task.isCancelled, let self else { return }
            let events = await self.loadCorpus()
            guard !Task.isCancelled, let app = self.app else { return }
            let candidates = self.includesHidden ? events
                : app.filter.visibleEvents(events, categories: app.categoryModel.filter,
                                           assignments: app.categoryModel.assignments, known: app.categoryModel.knownIDs)
            let known = Set(app.calendars.map(\.id))
            let today = app.today
            let calendar = app.calendar
            let found = await Task.detached(priority: .userInitiated) {
                EventSearch.results(candidates.filter { known.contains($0.calendarID) }, query: query,
                                    today: today, calendar: calendar)
            }.value
            guard !Task.isCancelled else { return }
            self.results = found
            self.resultQuery = query
            self.phase = .done
        }
    }

    /// The events of the search range, read in chunks EventKit accepts, off the main thread.
    private func loadCorpus() async -> [EventInfo] {
        if let corpus { return corpus }
        if corpusTask == nil, let app {
            let read = app.store.reader()
            let chunks = EventSearch.chunks(of: EventSearch.range(around: app.today, calendar: app.calendar),
                                            maxYears: 4, calendar: app.calendar)
            corpusTask = Task.detached(priority: .userInitiated) {
                var all: [EventInfo] = []
                for chunk in chunks {
                    if Task.isCancelled { break }
                    all += read(chunk)
                }
                return all
            }
        }
        guard let task = corpusTask else { return [] }
        let events = await task.value
        if !task.isCancelled, corpusTask == task {
            corpus = events
        }
        return events
    }

    /// Clears the query and leaves the search.
    func dismiss() {
        isPresented = false
        query = ""
    }
}
