import DaybookCore
import SwiftUI

/// Menu commands: ⌘N new event (replacing New Window), ⌘1 day, ⌘2 week, ⌘3 month.
/// Today and stepping live on the toolbar buttons, which carry their own shortcuts.
struct ViewCommands: Commands {
    let model: AppModel

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("Nová událost") { model.beginNewEvent() }
                .keyboardShortcut("n", modifiers: .command)
                .disabled(model.access != .granted)
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
    }
}
