import DaybookCore
import SwiftUI

/// The access gate, and behind it the split view (Mac, iPad) or single column (iPhone).
struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var showsCalendars = false
    @State private var calendarsDetent: PresentationDetent = .medium
    /// Width of the detail column (regular width), to pick a period title that fits beside the controls.
    @State private var detailWidth: CGFloat = 0
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
                    .toolbar {
                        ToolbarItem(placement: .navigation) {
                            Button("Kalendáře a kategorie", systemImage: "sidebar.leading") { showsCalendars = true }
                        }
                        navigationGroup
                        #if os(iOS)
                        // The top bar already holds the calendars, the title and back / Today / forward.
                        ToolbarItem(placement: .bottomBar) { modePicker }
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
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Hotovo") { showsCalendars = false }
                            }
                        }
                }
                .presentationDetents([.medium, .large], selection: $calendarsDetent)
                .presentationBackground(Theme.rail)
            }
            .onAppear {
                if model.stagedScreens.contains("calendars") { showsCalendars = true }
                if model.stagedScreens.contains("categories") {
                    calendarsDetent = .large
                    showsCalendars = true
                }
            }
            .modifier(SearchFocus(focused: $searchFocused))
        } else {
            NavigationSplitView {
                SidebarView()
                    .navigationTitle("Daybook")
                    .navigationSplitViewColumnWidth(min: 220, ideal: 248, max: 320)
            } detail: {
                current
                    .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { detailWidth = $0 }
                    .searchable(text: $search.query, isPresented: $search.isPresented, placement: .toolbar,
                                prompt: Text("Hledat události"))
                    .searchFocused($searchFocused)
                    // Back / Today / forward, the switcher, search, and the new event at the far right.
                    .toolbar {
                        navigationGroup
                        ToolbarItem(placement: .primaryAction) { modePicker }
                        DefaultToolbarItem(kind: .search, placement: .primaryAction)
                        ToolbarItem(placement: .primaryAction) { newEventButton(iconOnly: newEventIsIconOnly) }
                    }
            }
            .modifier(SearchFocus(focused: $searchFocused))
        }
    }

    /// The calendar, or the search results while a search is open.
    @ViewBuilder private var main: some View {
        if model.search.isPresented || model.search.hasQuery {
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

    /// The far-right primary action. Icon-only where the bar is tight; the label stays for VoiceOver.
    private func newEventButton(iconOnly: Bool) -> some View {
        Button { model.beginNewEvent() } label: {
            Label("Událost", systemImage: "plus")
                .labelStyle(NewEventLabelStyle(iconOnly: iconOnly))
        }
        .accessibilityLabel(Text("Nová událost"))
        .help(Text("Nová událost (⌘N)"))
    }

    /// iPad portrait and narrow windows: the switcher and search leave no room for the word.
    private var newEventIsIconOnly: Bool {
        #if os(iOS)
        detailWidth < 900
        #else
        false
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

    private var modePicker: some View {
        Picker("Zobrazení", selection: Binding(get: { model.mode }, set: { model.setMode($0) })) {
            Text("Den").tag(ViewMode.day)
            Text("Týden").tag(ViewMode.week)
            Text("Měsíc").tag(ViewMode.month)
        }
        .modifier(ModePickerStyle(asMenu: modePickerIsMenu))
        .fixedSize()
    }

    /// iPad with the sidebar beside a narrow detail: the segmented switcher would push the period title
    /// out of the bar, so it becomes the system's pull-down menu showing the current view.
    private var modePickerIsMenu: Bool {
        #if os(iOS)
        sizeClass != .compact && detailWidth > 0 && detailWidth < 760
        #else
        false
        #endif
    }

    private func title(short: Bool, numeric: Bool, abbreviatedWeekday: Bool = false) -> PeriodTitle {
        PeriodTitle(mode: model.mode, date: model.focusedDate, interval: model.loadedInterval,
                    calendar: model.calendar, short: short, numeric: numeric,
                    abbreviatedWeekday: abbreviatedWeekday)
    }

    /// The iPhone gets short titles; at accessibility sizes months become numbers so the title survives
    /// next to the toolbar buttons. The iPad toolbar also holds the switcher, so its weekday is abbreviated.
    private var navigationTitleText: String {
        if model.search.isPresented || model.search.hasQuery { return String(localized: "Hledání") }
        let compact = sizeClass == .compact
        #if os(iOS)
        if !compact { return regularTitle }
        #endif
        return title(short: compact, numeric: compact && dynamicTypeSize.isAccessibilitySize,
                     abbreviatedWeekday: true).joined
    }

    #if os(iOS)
    /// iPad: the longest form that fits beside the toolbar's controls ("16.–22. listopadu 2026"),
    /// else months as numbers with the year ("16.–22. 11. 2026"), else without the year.
    /// The bar truncates its title instead of offering a width, so the forms are measured here.
    private var regularTitle: String {
        let long = title(short: false, numeric: false, abbreviatedWeekday: true).joined
        let numeric = title(short: false, numeric: true, abbreviatedWeekday: true)
        let year = model.focusedDate.formatted(.dateTime.year())
        let numericWithYear = model.mode == .month ? numeric.joined : "\(numeric.name) \(year)"
        let room = detailWidth - trailingControlsWidth
        // The bar's title grows a little at accessibility sizes.
        let font = UIFont.systemFont(ofSize: dynamicTypeSize.isAccessibilitySize ? 21 : 17, weight: .semibold)
        for candidate in [long, numericWithYear] {
            let width = (candidate as NSString).size(withAttributes: [.font: font]).width
            if width <= room { return candidate }
        }
        return numeric.joined
    }

    /// What the iPad toolbar's trailing controls (back, Today, forward, switcher, search, new event) and
    /// the bar's margins take from the detail column's width, measured on iPadOS 26.
    private var trailingControlsWidth: CGFloat { modePickerIsMenu ? 470 : newEventIsIconOnly ? 600 : 680 }
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
                        if model.search.isPresented || model.search.hasQuery {
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

private struct ModePickerStyle: ViewModifier {
    let asMenu: Bool

    func body(content: Content) -> some View {
        if asMenu {
            content.pickerStyle(.menu).tint(Theme.ink)
        } else {
            content.pickerStyle(.segmented)
        }
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
