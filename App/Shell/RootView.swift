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
                month.toolbar {
                    ToolbarItem(placement: .navigation) {
                        Button("Kalendáře", systemImage: "sidebar.leading") { showsCalendars = true }
                    }
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
                month
            }
        }
    }

    /// The year must survive next to the toolbar buttons, so large text gets the short month name.
    /// Czech formats an abbreviated month with a year as the full name, so the two parts are joined here.
    private var monthTitle: String {
        guard dynamicTypeSize.isAccessibilitySize && sizeClass == .compact else {
            return model.month.formatted(.dateTime.month(.wide).year()).localizedCapitalized
        }
        let month = model.month.formatted(.dateTime.month(.abbreviated)).localizedCapitalized
        return "\(month) \(model.month.formatted(.dateTime.year()))"
    }

    private var month: some View {
        MonthView()
            .navigationTitle(monthTitle)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #else
            // The window title stays for the Window menu; the toolbar shows the month in the contract's type.
            .toolbar(removing: .title)
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    let name = model.month.formatted(.dateTime.month(.wide)).localizedCapitalized
                    let year = model.month.formatted(.dateTime.year())
                    Text("\(Text(name).fontWeight(.bold)) \(Text(year).fontWeight(.regular).foregroundStyle(Theme.secondaryInk))")
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
                    Button("Předchozí měsíc", systemImage: "chevron.left") { model.step(months: -1) }
                        .keyboardShortcut(.leftArrow, modifiers: .command)
                    Button("Dnes") { model.goToToday() }
                        .keyboardShortcut("t", modifiers: .command)
                    Button("Další měsíc", systemImage: "chevron.right") { model.step(months: 1) }
                        .keyboardShortcut(.rightArrow, modifiers: .command)
                }
            }
    }
}
