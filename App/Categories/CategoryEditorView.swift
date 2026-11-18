import DaybookCore
import SwiftUI

/// Creates a category or changes its name and symbol. Says where categories are kept.
struct CategoryEditorView: View {
    @Environment(CategoryModel.self) private var categories
    @Bindable var editor: CategoryEditorModel
    let onClose: () -> Void

    @FocusState private var nameFocused: Bool
    /// The question before deleting the category being edited.
    @State private var asksDelete = false

    var body: some View {
        NavigationStack {
            Form {
                if categories.syncState == .notSaved {
                    Section { CategoryNotSavedNotice() }
                        .listRowBackground(Theme.ground)
                }
                Section {
                    TextField("Název", text: $editor.name,
                              prompt: Text("Například Sport").foregroundStyle(Theme.secondaryInk))
                        .focused($nameFocused)
                        .submitLabel(.done)
                } header: {
                    Text("Název")
                } footer: {
                    if editor.problems.contains(.duplicate) {
                        Label(CategoryText.problem(.duplicate), systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                    }
                }
                .listRowBackground(Theme.ground)

                Section {
                    CategorySymbolGrid(selection: $editor.symbol, choices: editor.symbolChoices)
                } header: {
                    Text("Symbol")
                } footer: {
                    Text("Kategorie se rozlišují symbolem, ne barvou. Barvu mají kalendáře.")
                }
                .listRowBackground(Theme.ground)

                Section {
                    // Not being saved is said at the top instead.
                    if categories.syncState != .notSaved {
                        Label(CategoryText.sync(categories.syncState), systemImage: CategoryText.syncSymbol(categories.syncState))
                            .foregroundStyle(Theme.ink)
                    }
                } header: {
                    Text("Ukládání")
                } footer: {
                    Text("Kategorie vidíte jen vy. Do událostí se nezapisují, ostatní účastníci ani jiné aplikace je neuvidí.")
                }
                .listRowBackground(Theme.ground)

                if case .edit(let category) = editor.mode {
                    Section {
                        Button("Smazat kategorii…", systemImage: "trash", role: .destructive) { asksDelete = true }
                            .foregroundStyle(.red)
                            // The question hangs on the button that asked.
                            .confirmationDialog(Text("Smazat kategorii „\(category.name)“?"), isPresented: $asksDelete,
                                                titleVisibility: .visible) {
                                Button("Smazat kategorii", role: .destructive) {
                                    categories.delete(category)
                                    onClose()
                                }
                                Button("Ponechat", role: .cancel) {}
                            } message: {
                                Text(CategoryText.deleteMessage(categories.eventCount(of: category)))
                            }
                    }
                    .listRowBackground(Theme.ground)
                }
            }
            .formStyle(.grouped)
            .themeTint(Theme.controlInk)
            .scrollContentBackground(.hidden)
            .background(Theme.rail)
            .themeForeground(Theme.ink)
            .navigationTitle(editor.isNew ? "Nová kategorie" : "Upravit kategorii")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Zrušit", action: onClose)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(editor.isNew ? "Vytvořit" : "Uložit") {
                        if categories.save(editor) { onClose() }
                    }
                    .disabled(!editor.canSave)
                }
            }
        }
        .alert(editor.isNew ? "Kategorii se nepodařilo vytvořit" : "Kategorii se nepodařilo změnit",
               isPresented: Binding(get: { editor.errorMessage != nil }, set: { if !$0 { editor.errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(editor.errorMessage ?? "")
        }
        .onAppear { if editor.isNew || editor.focus == .name { nameFocused = editor.isNew } }
        #if os(macOS)
        .frame(minWidth: 420, idealWidth: 460, minHeight: 520)
        #endif
    }
}
