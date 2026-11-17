import DaybookCore
import SwiftUI

/// The access gate, and behind it the split view (Mac, iPad) or single column (iPhone).
struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.horizontalSizeClass) private var sizeClass
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
                    SidebarView()
                        .navigationTitle("Kalendáře")
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Hotovo") { showsCalendars = false }
                            }
                        }
                }
                .presentationDetents([.medium, .large])
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

    private var month: some View {
        MonthView()
            .navigationTitle(model.month.formatted(.dateTime.month(.wide).year()).localizedCapitalized)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
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
