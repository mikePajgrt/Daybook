import DaybookCore
import SwiftUI

/// Search results grouped by day, upcoming days first, then past ones; every match is listed.
/// Above them, the switch that includes calendars and categories turned off in the sidebar.
struct SearchResultsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var search = model.search
        List {
            if search.filterHidesSomething || search.includesHidden {
                Section {
                    Toggle("Hledat i ve vypnutých", isOn: $search.includesHidden)
                        .tint(Theme.ink)
                        .listRowBackground(Theme.ground)
                } footer: {
                    Text("Zahrne kalendáře a kategorie, které máte v postranním panelu vypnuté.")
                }
            }
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
                    dayHeader(day.day)
                }
            }
        }
        .scrollContentBackground(.hidden)
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
                if !search.includesHidden && search.filterHidesSomething {
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
