import DaybookCore
import SwiftUI

/// A new calendar (name, colour, account), or a new colour for an existing one.
struct CalendarEditorView: View {
    @Environment(AppModel.self) private var model
    @Bindable var editor: CalendarEditorModel
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                switch editor.mode {
                case .new: newCalendarSections
                case .recolor(let calendar): recolorSections(calendar)
                }
            }
            .formStyle(.grouped)
            // Picker values and switches in the world's ink instead of system grey and green.
            .tint(Theme.controlInk)
            .scrollContentBackground(.hidden)
            .background(Theme.rail)
            .foregroundStyle(Theme.ink)
            .navigationTitle(editor.isNew ? "Nový kalendář" : "Barva kalendáře")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Zrušit", action: onClose)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(editor.isNew ? "Vytvořit" : "Uložit") {
                        if model.save(editor) { onClose() }
                    }
                    .disabled(!editor.canSave || (editor.isNew && editor.sources.isEmpty) || !editor.hasChanges)
                }
            }
        }
        .alert(editor.isNew ? "Kalendář se nepodařilo vytvořit" : "Barvu se nepodařilo změnit",
               isPresented: Binding(get: { editor.errorMessage != nil }, set: { if !$0 { editor.errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(editor.errorMessage ?? "")
        }
        #if os(macOS)
        .frame(minWidth: 420, idealWidth: 460, minHeight: 420)
        #endif
    }

    @ViewBuilder private var newCalendarSections: some View {
        Section("Název") {
            TextField("Název", text: $editor.title, prompt: Text("Například Výlety").foregroundStyle(Theme.secondaryInk))
        }
        .listRowBackground(Theme.ground)

        Section("Barva") {
            CalendarColorPicker(color: $editor.color)
        }
        .listRowBackground(Theme.ground)

        Section {
            if editor.sources.isEmpty {
                Text("V zařízení není účet, ve kterém by šel kalendář vytvořit. Přidejte iCloud nebo Exchange v Nastavení.")
                    .foregroundStyle(Theme.secondaryInk)
            } else {
                Picker("Účet", selection: $editor.sourceID) {
                    ForEach(editor.sources) { source in
                        Text(source.title).tag(source.id)
                    }
                }
            }
        } footer: {
            if editor.hasGoogle {
                Text("Kalendář pro účet Google založte na webu Googlu a zapněte ho pro synchronizaci. Pak se tu objeví sám.")
            }
        }
        .listRowBackground(Theme.ground)
    }

    @ViewBuilder private func recolorSections(_ calendar: CalendarInfo) -> some View {
        Section {
            LabeledContent("Kalendář") {
                Text(calendar.title)
            }
            LabeledContent("Účet") {
                Text(calendar.sourceTitle)
            }
        }
        .listRowBackground(Theme.ground)

        Section("Barva") {
            CalendarColorPicker(color: $editor.color)
        }
        .listRowBackground(Theme.ground)
    }
}
