import DaybookCore
import SwiftUI

/// Menu commands, with their shortcuts shown in the menus (and offered to a hardware keyboard on iPad):
/// ⌘N new event (replacing New Window), ⌘F search, ⌘1 day, ⌘2 week, ⌘3 month, ⌘T today,
/// ⌘← and ⌘→ the previous and next period.
struct ViewCommands: Commands {
    let model: AppModel

    private var granted: Bool { model.access == .granted }

    var body: some Commands {
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
