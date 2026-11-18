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
            if categories.syncState == .notSaved {
                CategoryNotSavedNotice()
                    .listRowBackground(rowBackground)
            }
            ForEach(categories.categories) { category in
                // A tap on the row switches the filter; the trailing button offers the same management
                // as the context menu, so it is findable without a long press or a secondary click.
                FilterToggleRow(title: category.name, symbol: category.symbol,
                                isOn: categories.filter.isOn(category.id), hasMenu: true) {
                    categories.toggle(category)
                } menu: {
                    Menu {
                        manageItems(category)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundStyle(Theme.secondaryInk)
                            .frame(width: 44, height: 44)
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
                            isOn: categories.filter.showsUncategorized, hasMenu: false) {
                categories.toggleUncategorized()
            } menu: {
                EmptyView()
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
            // Not being saved is said at the top of the section instead.
            if categories.syncState != .notSaved {
                Label(CategoryText.sync(categories.syncState), systemImage: CategoryText.syncSymbol(categories.syncState))
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
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
/// the title and not under the plus, and it wraps only between words.
struct AddRowLabel: View {
    let title: LocalizedStringResource
    @ScaledMetric(relativeTo: .body) private var iconWidth: CGFloat = 24

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: "plus")
                .frame(width: iconWidth)
                .accessibilityHidden(true)
            WholeWordText(String(localized: title))
        }
        .contentShape(Rectangle())
    }
}

/// A filter row for a category or "Bez kategorie": checkbox in ink, symbol, the name in its own column,
/// and the row's menu button. One layout and one type width for every row; a name wraps only between
/// words, and condenses only when a single word is wider than its column. At accessibility sizes the menu button joins the
/// checkbox's line and the name goes below it with the row's whole width.
private struct FilterToggleRow<MenuButton: View>: View {
    let title: String
    let symbol: String
    let isOn: Bool
    /// Whether the row has a menu button; rows without one keep the same columns.
    let hasMenu: Bool
    let action: () -> Void
    @ViewBuilder let menu: () -> MenuButton

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// One column for every symbol, so names share a left edge whatever the symbol's width.
    @ScaledMetric(relativeTo: .body) private var symbolWidth: CGFloat = 22
    /// The menu button reaches this far into the row's trailing inset, so its 44 pt target costs the
    /// name less of the rail's width: at 248 pt the column then holds "Soustředěná" at standard width.
    private let menuOverhang: CGFloat = 26

    var body: some View {
        Button(action: action) {
            Group {
                if large {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            checkbox
                            symbolImage
                        }
                        .frame(minHeight: 44, alignment: .leading)
                        name
                    }
                } else {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        checkbox
                        symbolImage.frame(width: symbolWidth)
                        name
                        if hasMenu { Color.clear.frame(width: 44 - menuOverhang, height: 1) }
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
        // Over the button rather than inside it, so each keeps its own tap.
        .overlay(alignment: large ? .topTrailing : .trailing) {
            menu().offset(x: menuOverhang)
        }
    }

    private var checkbox: some View {
        Image(systemName: isOn ? "checkmark.square.fill" : "square")
            .foregroundStyle(isOn ? Theme.ink : Theme.secondaryInk)
            .imageScale(.large)
    }

    private var name: some View {
        WholeWordText(title)
            .foregroundStyle(isOn ? Theme.ink : Theme.secondaryInk)
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
