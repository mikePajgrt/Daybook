import DaybookCore
import SwiftUI
#if os(macOS)
import AppKit
#endif

/// Menu commands, with their shortcuts shown in the menus (and offered to a hardware keyboard on iPad):
/// ⌘N new event (replacing New Window), ⌘F search, ⌘1 day, ⌘2 week, ⌘3 month, ⌘T today,
/// ⌘← and ⌘→ the previous and next period.
struct ViewCommands: Commands {
    let model: AppModel

    private var granted: Bool { model.access == .granted }

    var body: some Commands {
        #if os(macOS)
        // The standard About panel, with the build's number and commit in the version's parentheses
        // ("0.1.0 (20261118.1045, 1d21270)"), as Settings shows it.
        CommandGroup(replacing: .appInfo) {
            Button("O aplikaci Daybook") {
                NSApp.orderFrontStandardAboutPanel(options: [
                    .applicationVersion: AppVersion.detail(info: Bundle.main.infoDictionary ?? [:])
                ])
                NSApp.activate()
            }
        }
        #endif
        CommandGroup(replacing: .newItem) {
            Button("Nová událost") { model.beginNewEvent() }
                .keyboardShortcut("n", modifiers: .command)
                .disabled(!granted)
        }
        CommandGroup(after: .textEditing) {
            Button("Hledat události") { model.search.wantsFocus = true }
                .keyboardShortcut("f", modifiers: .command)
                .disabled(!granted)
        }
        CommandGroup(before: .toolbar) {
            Button("Den") { model.setMode(.day) }
                .keyboardShortcut("1", modifiers: .command)
            Button("Týden") { model.setMode(.week) }
                .keyboardShortcut("2", modifiers: .command)
            Button("Měsíc") { model.setMode(.month) }
                .keyboardShortcut("3", modifiers: .command)
            Divider()
        }
        CommandMenu("Přejít") {
            Button("Dnes") { model.goToToday() }
                .keyboardShortcut("t", modifiers: .command)
            Button(previous) { model.step(by: -1) }
                .keyboardShortcut(.leftArrow, modifiers: .command)
            Button(next) { model.step(by: 1) }
                .keyboardShortcut(.rightArrow, modifiers: .command)
        }
    }

    private var previous: LocalizedStringKey {
        switch model.mode {
        case .day: "Předchozí den"
        case .week: "Předchozí týden"
        case .month: "Předchozí měsíc"
        }
    }

    private var next: LocalizedStringKey {
        switch model.mode {
        case .day: "Další den"
        case .week: "Další týden"
        case .month: "Další měsíc"
        }
    }
}
