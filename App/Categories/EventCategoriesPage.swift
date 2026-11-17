import DaybookCore
import SwiftUI

/// The event editor's categories page: which categories the event carries, and for an occurrence
/// of a recurring event whether they apply to the whole series or to this event only.
/// The choice is saved with the event.
struct EventCategoriesPage: View {
    @Environment(CategoryModel.self) private var categories
    @Bindable var editor: EventEditorModel

    var body: some View {
        Form {
            if categories.categories.isEmpty {
                Section {
                    Text("Zatím nemáte žádné kategorie. Založíte je v postranním panelu volbou Nová kategorie.")
                        .foregroundStyle(Theme.secondaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .listRowBackground(Theme.ground)
            } else {
                Section {
                    CategoryChecklist(categories: categories.categories,
                                      isRecurring: editor.offersOccurrenceCategories,
                                      scope: $editor.categoryScope,
                                      selection: $editor.categorySelection)
                } footer: {
                    VStack(alignment: .leading, spacing: 6) {
                        if let text = CategoryChecklist.explanation(isRecurring: editor.offersOccurrenceCategories,
                                                                    scope: editor.categoryScope) {
                            Text(text)
                        }
                        Text("Kategorie jsou jen vaše: do události se nezapisují a ostatní účastníci je neuvidí.")
                    }
                }
                .listRowBackground(Theme.ground)
            }
        }
        .formStyle(.grouped)
        .tint(Theme.ink)
        .scrollContentBackground(.hidden)
        .background(Theme.rail)
        .foregroundStyle(Theme.ink)
        .navigationTitle("Kategorie")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}
