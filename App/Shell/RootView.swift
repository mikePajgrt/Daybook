import DaybookCore
import SwiftUI

/// The access gate, and behind it the split view (Mac, iPad) or single column (iPhone).
struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var showsCalendars = false

    var body: some View {
        if model.access == .granted {
            shell
        } else {
            AccessView(access: model.access) {
                Task { await model.requestAccess() }
            }
        }
    }

    @ViewBuilder private var shell: some View {
        if sizeClass == .compact {
            NavigationStack {
                current.toolbar {
                    ToolbarItem(placement: .navigation) {
                        Button("Kalendáře", systemImage: "sidebar.leading") { showsCalendars = true }
                    }
                    #if os(iOS)
                    // The top bar already holds the calendars, the title and back / Today / forward.
                    ToolbarItem(placement: .bottomBar) { modePicker }
                    #endif
                }
            }
            .sheet(isPresented: $showsCalendars) {
                NavigationStack {
                    SidebarView(rowBackground: Theme.ground)
                        .navigationTitle("Kalendáře")
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Hotovo") { showsCalendars = false }
                            }
                        }
                }
                .presentationDetents([.medium, .large])
                .presentationBackground(Theme.rail)
            }
            .onAppear {
                if model.stagedScreens.contains("calendars") { showsCalendars = true }
            }
        } else {
            NavigationSplitView {
                SidebarView()
                    .navigationTitle("Daybook")
                    .navigationSplitViewColumnWidth(min: 220, ideal: 248, max: 320)
            } detail: {
                current.toolbar {
                    ToolbarItem(placement: .primaryAction) { modePicker }
                }
            }
        }
    }

    /// The view for the current mode, crossfading when the mode changes.
    private var currentView: some View {
        ZStack {
            switch model.mode {
            case .month: MonthView().transition(.opacity)
            case .week: WeekView().transition(.opacity)
            case .day: DayView().transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: model.mode)
    }

    private var modePicker: some View {
        Picker("Zobrazení", selection: Binding(get: { model.mode }, set: { model.setMode($0) })) {
            Text("Den").tag(ViewMode.day)
            Text("Týden").tag(ViewMode.week)
            Text("Měsíc").tag(ViewMode.month)
        }
        .pickerStyle(.segmented)
        .fixedSize()
    }

    private func title(short: Bool, numeric: Bool, abbreviatedWeekday: Bool = false) -> PeriodTitle {
        PeriodTitle(mode: model.mode, date: model.focusedDate, interval: model.loadedInterval,
                    calendar: model.calendar, short: short, numeric: numeric,
                    abbreviatedWeekday: abbreviatedWeekday)
    }

    /// The iPhone gets short titles; at accessibility sizes months become numbers so the title survives
    /// next to the toolbar buttons. The iPad toolbar also holds the switcher, so its weekday is abbreviated.
    private var navigationTitleText: String {
        let compact = sizeClass == .compact
        return title(short: compact, numeric: compact && dynamicTypeSize.isAccessibilitySize,
                     abbreviatedWeekday: true).joined
    }

    private var unitName: String {
        switch model.mode {
        case .day: "den"
        case .week: "týden"
        case .month: "měsíc"
        }
    }

    private var current: some View {
        currentView
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
                        if let year = parts.year {
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
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button("Předchozí \(unitName)", systemImage: "chevron.left") { model.step(by: -1) }
                        .keyboardShortcut(.leftArrow, modifiers: .command)
                    Button("Dnes") { model.goToToday() }
                        .keyboardShortcut("t", modifiers: .command)
                    Button("Další \(unitName)", systemImage: "chevron.right") { model.step(by: 1) }
                        .keyboardShortcut(.rightArrow, modifiers: .command)
                }
            }
    }
}
