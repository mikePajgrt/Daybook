import DaybookCore
import SwiftUI

/// The sidebar's "Kategorie" section: each category with its symbol and a checkbox, then
/// "Bez kategorie"; together they are the category filter. Then "Nová kategorie" and where
/// categories are kept. Categories carry no colour: the checkbox is ink, the symbol tells them apart.
struct CategorySidebarSection: View {
    @Environment(CategoryModel.self) private var categories
    var rowBackground: Color?

    var body: some View {
        Section {
            ForEach(categories.categories) { category in
                FilterToggleRow(title: category.name, symbol: category.symbol,
                                isOn: categories.filter.isOn(category.id)) {
                    categories.toggle(category)
                }
                .contextMenu {
                    Button("Přejmenovat…", systemImage: "pencil") { categories.beginEditing(category, focus: .name) }
                    Button("Změnit symbol…", systemImage: "square.grid.2x2") { categories.beginEditing(category, focus: .symbol) }
                    Divider()
                    Button("Zobrazit jen tuto") { categories.showOnly(category) }
                    Button("Zobrazit všechny") { categories.showAll() }
                    Divider()
                    Button("Smazat kategorii…", systemImage: "trash", role: .destructive) { categories.pendingDelete = category }
                }
                .listRowBackground(rowBackground)
            }
            .onMove { categories.move(fromOffsets: $0, toOffset: $1) }

            FilterToggleRow(title: CategoryText.uncategorized, symbol: "tag.slash",
                            isOn: categories.filter.showsUncategorized) {
                categories.toggleUncategorized()
            }
            .contextMenu {
                Button("Zobrazit jen události bez kategorie") { categories.showOnlyUncategorized() }
                Button("Zobrazit všechny") { categories.showAll() }
            }
            .listRowBackground(rowBackground)

            Button("Nová kategorie", systemImage: "plus") { categories.beginNew() }
                .foregroundStyle(Theme.ink)
                .listRowBackground(rowBackground)
        } header: {
            Text("Kategorie")
                .foregroundStyle(Theme.secondaryInk)
        } footer: {
            Label(CategoryText.sync(categories.syncState), systemImage: CategoryText.syncSymbol(categories.syncState))
                .font(.caption)
                .foregroundStyle(Theme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// A filter row for a category or "Bez kategorie": checkbox in ink, symbol, name.
private struct FilterToggleRow: View {
    let title: String
    let symbol: String
    let isOn: Bool
    let action: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Button(action: action) {
            HStack(alignment: large ? .firstTextBaseline : .center, spacing: 10) {
                Image(systemName: isOn ? "checkmark.square.fill" : "square")
                    .foregroundStyle(isOn ? Theme.ink : Theme.secondaryInk)
                    .imageScale(.large)
                Image(systemName: symbol)
                    .foregroundStyle(isOn ? Theme.ink : Theme.secondaryInk)
                    .frame(minWidth: 22)
                    .accessibilityHidden(true)
                Text(title)
                    .foregroundStyle(isOn ? Theme.ink : Theme.secondaryInk)
                    // At accessibility sizes the name wraps between words instead of losing letters.
                    .lineLimit(large ? nil : 1)
                    .fixedSize(horizontal: false, vertical: large)
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityValue(isOn ? "zapnutá" : "vypnutá")
        .accessibilityAddTraits(.isToggle)
    }

    private var large: Bool { dynamicTypeSize.isAccessibilitySize }
}

extension View {
    /// The confirmation before a category is deleted: names it and says how many events lose it.
    func categoryDeleteConfirmation(_ categories: CategoryModel) -> some View {
        let pending = categories.pendingDelete
        return confirmationDialog("Smazat kategorii „\(pending?.name ?? "")“?",
                                  isPresented: Binding(get: { categories.pendingDelete != nil },
                                                       set: { if !$0 { categories.pendingDelete = nil } }),
                                  titleVisibility: .visible, presenting: pending) { category in
            Button("Smazat kategorii", role: .destructive) { categories.delete(category) }
            Button("Ponechat", role: .cancel) {}
        } message: { category in
            Text(CategoryText.deleteMessage(categories.eventCount(of: category)))
        }
    }
}
