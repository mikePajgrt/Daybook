import DaybookCore
import SwiftUI

/// Search results grouped by day, upcoming days first, then past ones; every match is listed.
/// Above them, the switch that includes calendars and categories turned off in the sidebar.
struct SearchResultsView: View {
    @Environment(AppModel.self) private var model
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    #endif

    var body: some View {
        @Bindable var search = model.search
        ScrollViewReader { reader in
            List {
                // When nothing was found, the empty state offers the same switch as its one action.
                if (search.filterHidesSomething || search.includesHidden) && !offersSearchInHidden {
                    Section {
                        Toggle("Hledat i ve vypnutých", isOn: $search.includesHidden)
                            .switchTint()
                            .listRowBackground(Theme.ground)
                    } footer: {
                        Text("Zahrne i kalendáře a kategorie, které máte vypnuté.")
                    }
                }
                let firstPast = search.results.first { $0.day < model.today }?.day
                ForEach(search.results) { day in
                    Section {
                        ForEach(day.events) { event in
                            Button { choose(event) } label: {
                                SearchResultRow(event: event, query: search.resultQuery)
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(Theme.ground)
                        }
                    } header: {
                        // Past days follow the upcoming ones under their own label.
                        if day.day == firstPast {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Dříve")
                                    .font(.headline)
                                    .foregroundStyle(Theme.ink)
                                    .accessibilityAddTraits(.isHeader)
                                dayHeader(day.day)
                            }
                            .padding(.top, 12)
                        } else {
                            dayHeader(day.day)
                        }
                    }
                    .id(day.day)
                }
            }
            #if DEBUG
            // Debug staging: the first day before today mid-screen, below the last upcoming one.
            .onChange(of: search.results) {
                guard model.stagedScreens.contains("search-past"),
                      let past = search.results.first(where: { $0.day < model.today }) else { return }
                Task {
                    try? await Task.sleep(for: .milliseconds(400))
                    withAnimation { reader.scrollTo(past.day, anchor: .center) }
                }
            }
            #endif
        }
        .scrollContentBackground(.hidden)
        .scrollEdgeEffectStyle(.hard, for: .top)
        #if os(iOS)
        // iPhone: while searching there is no bar above the results, so they would pass under the status
        // bar's text. An opaque band of the list's ground fills the status bar's height instead.
        .overlay(alignment: .top) {
            if sizeClass == .compact {
                Color.clear.frame(height: 0)
                    .background(Theme.rail.ignoresSafeArea(edges: .top))
                    .allowsHitTesting(false)
            }
        }
        #endif
        .background(Theme.rail)
        .overlay { emptyState }
        .foregroundStyle(Theme.ink)
    }

    private func dayHeader(_ day: Date) -> some View {
        let isToday = day == model.today
        return HStack(spacing: 6) {
            Text(day.formatted(.dateTime.weekday(.wide).day().month(.wide).year()).localizedCapitalizedFirst)
            if isToday {
                Text("Dnes").fontWeight(.semibold)
            }
        }
        .font(.subheadline)
        .foregroundStyle(Theme.secondaryInk)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    @ViewBuilder private var emptyState: some View {
        let search = model.search
        if !search.hasQuery {
            ContentUnavailableView {
                Label("Hledejte v událostech", systemImage: "magnifyingglass")
            } description: {
                Text("Napište slovo z názvu, místa, poznámky nebo jméno účastníka. Hledá se pět let zpět i dopředu.")
            }
        } else if search.phase == .done && search.results.isEmpty {
            ContentUnavailableView {
                Label("Nic nenalezeno", systemImage: "magnifyingglass")
            } description: {
                if search.includesHidden || !search.filterHidesSomething {
                    Text("Žádná událost neobsahuje „\(search.resultQuery)“. Zkuste jiné slovo.")
                } else {
                    Text("V zapnutých kalendářích a kategoriích žádná událost neobsahuje „\(search.resultQuery)“.")
                }
            } actions: {
                if offersSearchInHidden {
                    Button("Hledat i ve vypnutých") { model.search.includesHidden = true }
                        .buttonStyle(.bordered)
                        .tint(Theme.ink)
                }
            }
        } else if search.phase == .searching && search.results.isEmpty {
            // Reading years of events takes a moment the first time; the field never waits for it.
            ProgressView {
                Text("Hledám…")
            }
            .tint(Theme.ink)
        }
    }

    /// No results while switched-off calendars or categories are left out: the empty state's button
    /// takes over from the switch above the results.
    private var offersSearchInHidden: Bool {
        let search = model.search
        return search.hasQuery && search.phase == .done && search.results.isEmpty
            && !search.includesHidden && search.filterHidesSomething
    }

    private func choose(_ event: EventInfo) {
        model.search.dismiss()
        model.open(event)
    }
}

extension String {
    /// The first letter in upper case, the rest as it is ("úterý 17. listopadu" to "Úterý 17. listopadu").
    var localizedCapitalizedFirst: String {
        guard let first else { return self }
        return String(first).localizedUppercase + dropFirst()
    }
}
