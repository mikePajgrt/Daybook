import DaybookCore
import SwiftUI

/// The access gate, and behind it the split view (Mac, iPad) or single column (iPhone).
struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var showsCalendars = false
    @State private var calendarsDetent: PresentationDetent = .medium
    /// Width of the detail column, to pick a period title that fits beside the controls.
    @State private var detailWidth: CGFloat = 0
    #if os(iOS)
    /// iPad: what the bar really has, measured, to choose the widest title and switcher that fit.
    @State private var bar = RegularBarMetrics()
    #endif
    /// Regular width: whether the rail shows. The filter chip opens it.
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @FocusState private var searchFocused: Bool

    var body: some View {
        if model.access == .granted {
            shell
                .sheet(item: Binding(get: { model.editorInDaySheet ? nil : model.editor },
                                     set: { model.editor = $0 })) { editor in
                    EventEditorView(editor: editor) { model.editor = nil }
                        .presentationBackground(Theme.rail)
                        // iPad: a page-sized sheet shows more of the form without scrolling.
                        .presentationSizing(.page)
                }
                // A search result that no view on screen shows (its calendar or category is switched off).
                .sheet(item: Binding(get: { model.detachedDetail }, set: { model.detachedDetail = $0 })) { item in
                    NavigationStack {
                        EventDetailView(event: item.event, style: .sheet,
                                        onClose: { model.detachedDetail = nil },
                                        onEdit: {
                                            model.detachedDetail = nil
                                            Task {
                                                try? await Task.sleep(for: .milliseconds(450))
                                                model.beginEditing(item.event)
                                            }
                                        })
                    }
                    .presentationDetents([.medium, .large])
                    .presentationBackground(Theme.ground)
                }
                .alert(model.notice?.title ?? "", isPresented: Binding(get: { model.notice != nil },
                                                                       set: { if !$0 { model.notice = nil } })) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text(model.notice?.message ?? "")
                }
                #if DEBUG
                .task { await model.stageDemoScreens() }
                #endif
        } else {
            AccessView(access: model.access) {
                Task { await model.requestAccess() }
            }
        }
    }

    @ViewBuilder private var shell: some View {
        @Bindable var search = model.search
        if sizeClass == .compact {
            NavigationStack {
                current
                    .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { detailWidth = $0 }
                    .toolbar {
                        ToolbarItem(placement: .navigation) {
                            // While a filter hides something the button changes to the filter symbol, so the
                            // month never looks complete when it is not; it opens the list that holds the switches.
                            Button { showsCalendars = true } label: {
                                Label("Kalendáře a kategorie",
                                      systemImage: model.hiddenNames.isEmpty ? "sidebar.leading"
                                                                             : "line.3.horizontal.decrease.circle.fill")
                            }
                            .accessibilityLabel(Text("Kalendáře a kategorie"))
                            .accessibilityValue(hiddenSummarySpoken.map(Text.init) ?? Text(verbatim: ""))
                        }
                        navigationGroup
                        #if os(iOS)
                        // The top bar already holds the calendars, the title and back / Today / forward.
                        ToolbarItem(placement: .bottomBar) { modePicker(asMenu: false) }
                        ToolbarSpacer(.flexible, placement: .bottomBar)
                        DefaultToolbarItem(kind: .search, placement: .bottomBar)
                        ToolbarItem(placement: .bottomBar) { newEventButton(iconOnly: true) }
                        #endif
                    }
            }
            .searchable(text: $search.query, isPresented: $search.isPresented, prompt: Text("Hledat události"))
            .searchFocused($searchFocused)
            .sheet(isPresented: $showsCalendars) {
                NavigationStack {
                    SidebarView(rowBackground: Theme.ground)
                        .navigationTitle("Kalendáře a kategorie")
                        #if os(iOS)
                        // An opaque bar: with the soft scroll edge, large rows blurred through the title.
                        .toolbarBackground(Theme.ground, for: .navigationBar)
                        .toolbarBackgroundVisibility(dynamicTypeSize.isAccessibilitySize ? .visible : .automatic,
                                                     for: .navigationBar)
                        #endif
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Hotovo") { showsCalendars = false }
                            }
                        }
                }
                .presentationDetents([.medium, .large], selection: $calendarsDetent)
                .presentationBackground(Theme.rail)
            }
            #if DEBUG
            .onAppear {
                if model.stagedScreens.contains("calendars") { showsCalendars = true }
                if model.stagedScreens.contains("categories") {
                    calendarsDetent = .large
                    showsCalendars = true
                }
            }
            #endif
            .modifier(SearchFocus(focused: $searchFocused))
        } else {
            NavigationSplitView(columnVisibility: $columnVisibility) {
                SidebarView()
                    .navigationTitle("Daybook")
                    .navigationSplitViewColumnWidth(min: 220, ideal: 248, max: 320)
                    #if os(iOS)
                    // An opaque bar at accessibility sizes, as on the sheets: large rows would blur
                    // through "Daybook" under the soft scroll edge.
                    .toolbarBackground(Theme.rail, for: .navigationBar)
                    .toolbarBackgroundVisibility(dynamicTypeSize.isAccessibilitySize ? .visible : .automatic,
                                                 for: .navigationBar)
                    .toolbar {
                        // With the rail on screen, what the filters hide is said at its top, beside the
                        // switches; the detail bar keeps its room for the period and the controls.
                        if !model.hiddenNames.isEmpty {
                            ToolbarItem(placement: .topBarLeading) { railFilterStatus }
                                .sharedBackgroundVisibility(.hidden)
                        }
                    }
                    #endif
            } detail: {
                current
                    .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { detailWidth = $0 }
                    #if os(iOS)
                    .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { bar.detail = $0 }
                    .background {
                        RegularBarProbes(titles: regularTitles, modeName: modeName, hiddenCount: model.hiddenNames.count) {
                            bar.texts[$0] = $1
                        }
                    }
                    #endif
                    .searchable(text: $search.query, isPresented: $search.isPresented, placement: .toolbar,
                                prompt: Text("Hledat události"))
                    .searchFocused($searchFocused)
                    #if os(iOS)
                    // The bar's own title gives way to anything beside it; this one stays.
                    .toolbar(removing: .title)
                    #endif
                    // Back / Today / forward, the switcher, search, and the new event at the far right.
                    // While search results are shown, the period controls would do nothing, so they go.
                    .toolbar {
                        #if os(iOS)
                        let choice = regularBar
                        // One leading item: a second glass button beside the title would cost the bar the
                        // room it needs for the switcher and the plus.
                        ToolbarItem(placement: .topBarLeading) {
                            HStack(spacing: RegularBarLayout.indicatorSpacing) {
                                BarTitleText(text: isSearching ? String(localized: "Hledání") : choice.title)
                                    .foregroundStyle(Theme.ink)
                                    .accessibilityAddTraits(.isHeader)
                                if choice.indicator != .none {
                                    filterIndicator(choice.indicator)
                                }
                            }
                            // A fresh item for each form, so the bar sizes it anew.
                            .id(choice)
                        }
                        .sharedBackgroundVisibility(.hidden)
                        if !isSearching {
                            navigationGroup
                            ToolbarItem(placement: .primaryAction) {
                                modePicker(asMenu: choice.pickerIsMenu, indicator: choice.menuIndicator)
                            }
                        }
                        DefaultToolbarItem(kind: .search, placement: .primaryAction)
                        ToolbarItem(placement: .primaryAction) { newEventButton(iconOnly: !choice.newEventWord) }
                        #else
                        if !model.hiddenNames.isEmpty {
                            ToolbarItem(placement: .navigation) { filterChip }
                        }
                        if !isSearching {
                            navigationGroup
                            ToolbarItem(placement: .primaryAction) { modePicker(asMenu: false) }
                        }
                        DefaultToolbarItem(kind: .search, placement: .primaryAction)
                        ToolbarItem(placement: .primaryAction) { newEventButton(iconOnly: false) }
                        #endif
                    }
            }
            #if os(iOS)
            // The bar's items change size with the text; measure them again.
            .onChange(of: dynamicTypeSize) { bar = RegularBarMetrics() }
            #endif
            #if DEBUG
            .task {
                if model.stagedScreens.contains("rail-collapsed") {
                    try? await Task.sleep(for: .milliseconds(300))
                    columnVisibility = .detailOnly
                }
            }
            #endif
            .modifier(SearchFocus(focused: $searchFocused))
        }
    }

    /// Search results are on screen instead of the calendar.
    private var isSearching: Bool { model.search.isPresented || model.search.hasQuery }

    /// The calendar, or the search results while a search is open.
    @ViewBuilder private var main: some View {
        if isSearching {
            SearchResultsView()
                .transition(.opacity)
        } else if model.didStart && model.calendars.isEmpty {
            NoCalendarsView()
        } else {
            currentView
        }
    }

    /// The view for the current mode, crossfading when the mode changes (the system's default timing).
    private var currentView: some View {
        ZStack {
            switch model.mode {
            case .month: MonthView().transition(.opacity)
            case .week: WeekView().transition(.opacity)
            case .day: DayView().transition(.opacity)
            }
        }
        .animation(.default, value: model.mode)
    }

    /// Mac: "Skryto: Porady", or "Skryto: 3" when several things are hidden. Opens the rail with the switches.
    private var filterChip: some View {
        let hidden = model.hiddenNames
        let text = hidden.count == 1 ? String(localized: "Skryto: \(hidden[0])")
                                     : String(localized: "Skryto: \(hidden.count)")
        return Button {
            withAnimation { columnVisibility = .all }
        } label: {
            // An explicit stack: a toolbar would draw a Label as its icon alone.
            HStack(spacing: 4) {
                Image(systemName: "line.3.horizontal.decrease.circle.fill")
                Text(text)
            }
        }
        .accessibilityLabel(Text(hiddenSummarySpoken ?? text))
        .help(Text(hiddenSummarySpoken ?? text))
    }

    #if os(iOS)
    /// iPad: the filter symbol beside the title, with the count when the bar has room. It says what is
    /// hidden to VoiceOver and the pointer, and opens the rail with the switches.
    private func filterIndicator(_ form: RegularBarChoice.Indicator) -> some View {
        // A tappable label rather than a bar button: the bar gives a button a wider slot than the
        // symbol needs, and that slot would push the switcher into the overflow menu.
        FilterIndicatorLabel(count: form == .symbol ? nil : model.hiddenNames.count, labelled: form == .labelled)
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, RegularBarLayout.indicatorInset)
            .contentShape(Rectangle().inset(by: -10))
            .onTapGesture(perform: showRail)
            .hoverEffect(.highlight)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(hiddenSummarySpoken ?? ""))
            .accessibilityHint(Text("Otevře kalendáře a kategorie"))
            .accessibilityAddTraits(.isButton)
            .accessibilityAction(.default, showRail)
            .help(Text(hiddenSummarySpoken ?? ""))
    }

    /// iPad, rail on screen: the filter symbol and how many things are hidden, at the rail's top.
    private var railFilterStatus: some View {
        FilterIndicatorLabel(count: model.hiddenNames.count)
            .foregroundStyle(Theme.ink)
            .dynamicTypeSize(...BarTitleText.largestSize)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(hiddenSummarySpoken ?? ""))
            .help(Text(hiddenSummarySpoken ?? ""))
    }

    private func showRail() {
        withAnimation { columnVisibility = .all }
    }
    #endif

    /// "Skryté: Práce, Porady a Bez kategorie", for VoiceOver and the pointer's help.
    private var hiddenSummarySpoken: String? {
        let hidden = model.hiddenNames
        guard !hidden.isEmpty else { return nil }
        return String(localized: "Skryté: \(hidden.formatted(.list(type: .and)))")
    }

    /// The far-right primary action. Icon-only where the bar is tight; the label stays for VoiceOver.
    @ViewBuilder private func newEventButton(iconOnly: Bool) -> some View {
        #if os(iOS)
        // iOS bars draw the plus alone, as a plain bar button.
        Button("Nová událost", systemImage: "plus") { model.beginNewEvent() }
            .help(Text("Nová událost (⌘N)"))
        #else
        Button { model.beginNewEvent() } label: {
            Label("Událost", systemImage: "plus")
                .labelStyle(NewEventLabelStyle(iconOnly: iconOnly))
        }
        .accessibilityLabel(Text("Nová událost"))
        .help(Text("Nová událost (⌘N)"))
        #endif
    }

    private var navigationGroup: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Button(previousLabel, systemImage: "chevron.left") { model.step(by: -1) }
                .help(Text(previousLabel))
            Button("Dnes") { model.goToToday() }
                .help(Text("Dnes (⌘T)"))
            Button(nextLabel, systemImage: "chevron.right") { model.step(by: 1) }
                .help(Text(nextLabel))
        }
    }

    /// Day / Week / Month. Segmented; on an iPad bar too narrow for it, the system's pull-down menu
    /// showing the current view.
    @ViewBuilder private func modePicker(asMenu: Bool, indicator: Bool = true) -> some View {
        let picker = Picker("Zobrazení", selection: Binding(get: { model.mode }, set: { model.setMode($0) })) {
            Text("Den").tag(ViewMode.day)
            Text("Týden").tag(ViewMode.week)
            Text("Měsíc").tag(ViewMode.month)
        }
        if asMenu {
            // A bar button titled with the current view: the bar sizes it to its title, where a menu-style
            // picker would keep a wide slot with empty space beside the name.
            Menu {
                picker.pickerStyle(.inline)
            } label: {
                ModeMenuTitle(name: modeName, indicator: indicator)
            }
            .accessibilityLabel(Text("Zobrazení"))
            .accessibilityValue(Text(modeName))
        } else {
            picker.pickerStyle(.segmented).fixedSize()
        }
    }

    private var modeName: LocalizedStringKey {
        switch model.mode {
        case .day: "Den"
        case .week: "Týden"
        case .month: "Měsíc"
        }
    }

    private func title(short: Bool, numeric: Bool, abbreviatedWeekday: Bool = false) -> PeriodTitle {
        PeriodTitle(mode: model.mode, date: model.focusedDate, interval: model.loadedInterval,
                    calendar: model.calendar, short: short, numeric: numeric,
                    abbreviatedWeekday: abbreviatedWeekday)
    }

    /// The iPhone gets short titles; at accessibility sizes months become numbers so the title survives
    /// next to the toolbar buttons. The iPad toolbar also holds the switcher, so its weekday is abbreviated.
    private var navigationTitleText: String {
        if isSearching { return String(localized: "Hledání") }
        let compact = sizeClass == .compact
        #if os(iOS)
        // iPad: the bar shows its own title item; this names the window.
        if !compact { return regularTitles.first ?? "" }
        if !dynamicTypeSize.isAccessibilitySize { return compactTitle }
        #endif
        return title(short: compact, numeric: compact && dynamicTypeSize.isAccessibilitySize,
                     abbreviatedWeekday: true).joined
    }

    #if os(iOS)
    /// iPad title forms: "Úterý 17. listopadu 2026", "Út 17. listopadu 2026", "Út 17. 11. 2026",
    /// "Út 17. 11.", "17. 11."; for a week, the full range down to "16.–22. 11."; "Listopad 2026",
    /// "Lis 2026", "11/2026". The bar shows the longest that fits (`regularBar`).
    private var regularTitles: [String] {
        let full = title(short: false, numeric: false).joined
        let weekday = title(short: false, numeric: false, abbreviatedWeekday: true).joined
        let numeric = title(short: false, numeric: true, abbreviatedWeekday: true)
        let year = model.focusedDate.formatted(.dateTime.year())
        var forms = [full, weekday]
        switch model.mode {
        case .month:
            forms += [numeric.joined, model.focusedDate.formatted(.dateTime.month(.defaultDigits).year())]
        case .week:
            // "16.–22. 11.", "16 – 22 Nov": the shortest the formatter writes.
            let start = model.loadedInterval?.start ?? model.focusedDate
            let last = model.loadedInterval.flatMap { model.calendar.date(byAdding: .day, value: -1, to: $0.end) } ?? start
            forms += ["\(numeric.name) \(year)", numeric.name,
                      (start..<max(last, start)).formatted(.interval.day().month(.abbreviated))]
        case .day:
            forms += ["\(numeric.name) \(year)", numeric.name,
                      model.focusedDate.formatted(.dateTime.day().month(.defaultDigits))]
        }
        var result: [String] = []
        for form in forms where !result.contains(form) { result.append(form) }
        return result
    }

    /// The widest title, switcher, filter indicator and new-event button that fit in the bar together.
    /// The filter symbol joins the title only while the rail is hidden; otherwise the rail says it.
    private var regularBar: RegularBarChoice {
        RegularBarLayout.choose(titles: regularTitles,
                                filtering: !model.hiddenNames.isEmpty && columnVisibility == .detailOnly,
                                railHidden: columnVisibility == .detailOnly, metrics: bar)
    }

    /// iPhone: the short title ("Út 17. listopadu", "Tue 17 November") when it fits between the calendars
    /// button and back / Today / forward, else months as numbers. Languages differ in length, so it is measured.
    private var compactTitle: String {
        let short = title(short: true, numeric: false, abbreviatedWeekday: true).joined
        let font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        let room = detailWidth - Self.compactControlsWidth
        if detailWidth == 0 || (short as NSString).size(withAttributes: [.font: font]).width <= room { return short }
        return title(short: true, numeric: true, abbreviatedWeekday: true).joined
    }

    /// The calendars button, back / Today / forward and the bar's margins on an iPhone, measured on iOS 26.
    private static let compactControlsWidth: CGFloat = 270

    #endif

    private var previousLabel: LocalizedStringKey {
        switch model.mode {
        case .day: "Předchozí den"
        case .week: "Předchozí týden"
        case .month: "Předchozí měsíc"
        }
    }

    private var nextLabel: LocalizedStringKey {
        switch model.mode {
        case .day: "Další den"
        case .week: "Další týden"
        case .month: "Další měsíc"
        }
    }

    private var current: some View {
        main
            .animation(.default, value: model.search.isPresented || model.search.hasQuery)
            .navigationTitle(navigationTitleText)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #else
            // The window title stays for the Window menu; the toolbar shows the period in the contract's type.
            .toolbar(removing: .title)
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    let parts = title(short: false, numeric: false)
                    Group {
                        if isSearching {
                            Text("Hledání").fontWeight(.bold)
                        } else if let year = parts.year {
                            Text("\(Text(parts.name).fontWeight(.bold)) \(Text(year).fontWeight(.regular).foregroundStyle(Theme.secondaryInk))")
                        } else {
                            Text(parts.name).fontWeight(.bold)
                        }
                    }
                    .font(.system(size: 22))
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, 4)
                    .accessibilityAddTraits(.isHeader)
                }
                .sharedBackgroundVisibility(.hidden)
            }
            .toolbarBackground(Theme.ground, for: .windowToolbar)
            .toolbarBackgroundVisibility(.visible, for: .windowToolbar)
            #endif
    }
}

/// "Událost" with its plus, or the plus alone where the bar is tight.
private struct NewEventLabelStyle: LabelStyle {
    let iconOnly: Bool

    func makeBody(configuration: Configuration) -> some View {
        if iconOnly {
            configuration.icon
        } else {
            HStack(spacing: 4) {
                configuration.icon
                configuration.title
            }
        }
    }
}

/// ⌘F and debug staging put the cursor in the search field.
private struct SearchFocus: ViewModifier {
    @Environment(AppModel.self) private var model
    var focused: FocusState<Bool>.Binding

    func body(content: Content) -> some View {
        content
            .onChange(of: model.search.wantsFocus) {
                guard model.search.wantsFocus else { return }
                model.search.isPresented = true
                focused.wrappedValue = true
                model.search.wantsFocus = false
            }
    }
}
