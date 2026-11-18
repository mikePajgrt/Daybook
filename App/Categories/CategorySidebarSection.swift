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
                // A tap on the row switches the filter; the trailing button offers the same management
                // as the context menu, so it is findable without a long press or a secondary click.
                HStack(spacing: 4) {
                    FilterToggleRow(title: category.name, symbol: category.symbol,
                                    isOn: categories.filter.isOn(category.id)) {
                        categories.toggle(category)
                    }
                    Menu {
                        manageItems(category)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundStyle(Theme.secondaryInk)
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .menuStyle(.button)
                    .buttonStyle(.borderless)
                    .menuIndicator(.hidden)
                    .fixedSize()
                    .accessibilityLabel(Text("Upravit kategorii \(category.name)"))
                }
                .contextMenu { manageItems(category) }
                // The question hangs on the row it is about.
                .categoryDeleteConfirmation(categories, for: category)
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

            Button { categories.beginNew() } label: { AddRowLabel(title: "Nová kategorie") }
                .buttonStyle(.plain)
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

extension CategorySidebarSection {
    /// Rename, symbol, show only, show all, delete: on the row's menu button and its context menu.
    @ViewBuilder func manageItems(_ category: Category) -> some View {
        Button("Přejmenovat…", systemImage: "pencil") { categories.beginEditing(category, focus: .name) }
        Button("Změnit symbol…", systemImage: "square.grid.2x2") { categories.beginEditing(category, focus: .symbol) }
        Divider()
        Button("Zobrazit jen tuto") { categories.showOnly(category) }
        Button("Zobrazit všechny") { categories.showAll() }
        Divider()
        Button("Smazat kategorii…", systemImage: "trash", role: .destructive) { categories.pendingDelete = category }
    }
}

/// "+ Nový kalendář", "+ Nová kategorie": the title has its own column, so a wrapped line starts under
/// the title and not under the plus.
struct AddRowLabel: View {
    let title: LocalizedStringKey
    @ScaledMetric(relativeTo: .body) private var iconWidth: CGFloat = 26

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: "plus")
                .frame(width: iconWidth)
                .accessibilityHidden(true)
            Text(title)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
    }
}

/// A filter row for a category or "Bez kategorie": checkbox in ink, symbol, name.
/// At accessibility sizes the name moves under the checkbox and symbol, so it has the row's whole
/// width and wraps only between words.
private struct FilterToggleRow: View {
    let title: String
    let symbol: String
    let isOn: Bool
    let action: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// One column for every symbol, so names share a left edge whatever the symbol's width.
    @ScaledMetric(relativeTo: .body) private var symbolWidth: CGFloat = 26

    var body: some View {
        Button(action: action) {
            Group {
                if large {
                    // Checkbox and symbol on one line, the name below with the row's whole width.
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 10) {
                            checkbox
                            symbolImage
                        }
                        name
                    }
                } else {
                    // One line when the name fits whole; otherwise the name goes under the checkbox and
                    // symbol with the row's width, so a long word is never broken (a narrow rail beside
                    // the row's menu button).
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 10) {
                            checkbox
                            symbolImage.frame(width: symbolWidth)
                            name.lineLimit(1).fixedSize()
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 10) {
                                checkbox
                                symbolImage.frame(width: symbolWidth)
                            }
                            name
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityValue(isOn ? Text("zapnutá") : Text("vypnutá"))
        .accessibilityAddTraits(.isToggle)
    }

    private var checkbox: some View {
        Image(systemName: isOn ? "checkmark.square.fill" : "square")
            .foregroundStyle(isOn ? Theme.ink : Theme.secondaryInk)
            .imageScale(.large)
    }

    private var name: some View {
        Text(title)
            .foregroundStyle(isOn ? Theme.ink : Theme.secondaryInk)
            // Long names take a second line, between words, rather than losing letters.
            .lineLimit(large ? nil : 2)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var symbolImage: some View {
        Image(systemName: symbol)
            .foregroundStyle(isOn ? Theme.ink : Theme.secondaryInk)
            .accessibilityHidden(true)
    }

    private var large: Bool { dynamicTypeSize.isAccessibilitySize }
}

extension View {
    /// The confirmation before `category` is deleted: names it and says how many events lose it.
    func categoryDeleteConfirmation(_ categories: CategoryModel, for category: Category) -> some View {
        confirmationDialog("Smazat kategorii „\(category.name)“?",
                           isPresented: Binding(get: { categories.pendingDelete?.id == category.id },
                                                set: { if !$0 { categories.pendingDelete = nil } }),
                           titleVisibility: .visible) {
            Button("Smazat kategorii", role: .destructive) { categories.delete(category) }
            Button("Ponechat", role: .cancel) {}
        } message: {
            Text(CategoryText.deleteMessage(categories.eventCount(of: category)))
        }
    }
}
