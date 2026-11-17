import DaybookCore
import SwiftUI

/// Category toggles for an event's context menu. For an occurrence of a recurring event,
/// one submenu for the whole series and one for this occurrence only.
struct EventCategoryMenu: View {
    @Environment(CategoryModel.self) private var categories
    let event: EventInfo

    var body: some View {
        if categories.categories.isEmpty {
            Button("Kategorie: zatím žádné", systemImage: "tag") {}
                .disabled(true)
        } else if event.isRecurring {
            Menu("Kategorie celé série", systemImage: "tag") { toggles(.series) }
            Menu("Kategorie jen této události", systemImage: "tag") { toggles(.occurrence) }
        } else {
            Menu("Kategorie", systemImage: "tag") { toggles(.series) }
        }
    }

    @ViewBuilder private func toggles(_ scope: CategoryScope) -> some View {
        let selection = categories.selection(for: event.key)
        ForEach(categories.categories) { category in
            Toggle(isOn: Binding(get: { selection.isOn(category.id, scope: scope) },
                                 set: { categories.set(category, on: $0, for: event.key, scope: scope) })) {
                Label(category.name, systemImage: category.symbol)
            }
            .disabled(selection.isInherited(category.id, scope: scope))
        }
    }
}
