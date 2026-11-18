import DaybookCore
import SwiftUI

/// The categories of one event as checkmark rows, with the "Celá série" / "Jen tato událost" choice
/// for an occurrence of a recurring event. A series category shows as on and fixed in
/// "Jen tato událost". Shared by the editor's categories page and the detail.
struct CategoryChecklist: View {
    let categories: [Category]
    let isRecurring: Bool
    @Binding var scope: CategoryScope
    @Binding var selection: CategorySelection

    /// One column for every symbol, so names share a left edge.
    @ScaledMetric(relativeTo: .body) private var symbolWidth: CGFloat = 26

    var body: some View {
        if isRecurring {
            Picker("Přiřadit", selection: $scope) {
                Text("Celá série").tag(CategoryScope.series)
                Text("Jen tato událost").tag(CategoryScope.occurrence)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .accessibilityLabel("Přiřadit kategorie")
        }
        ForEach(categories) { category in
            let on = selection.isOn(category.id, scope: scope)
            let inherited = selection.isInherited(category.id, scope: scope)
            Button { selection.toggle(category.id, scope: scope) } label: {
                HStack(spacing: 10) {
                    Image(systemName: category.symbol)
                        .frame(width: symbolWidth)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(category.name)
                            .fixedSize(horizontal: false, vertical: true)
                        if inherited {
                            Text("z celé série")
                                .font(.caption)
                                .foregroundStyle(Theme.secondaryInk)
                        }
                    }
                    Spacer(minLength: 8)
                    Image(systemName: on ? "checkmark.circle.fill" : "circle")
                        .imageScale(.large)
                        .foregroundStyle(on ? Theme.ink : Theme.secondaryInk)
                        .accessibilityHidden(true)
                }
                .frame(minHeight: Self.minimumRowHeight)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.ink)
            .disabled(inherited)
            .accessibilityAddTraits(on ? .isSelected : [])
            .accessibilityHint(inherited ? Text("Přiřazeno celé sérii. Odeberte ho volbou Celá série.") : Text(verbatim: ""))
        }
    }

    /// Touch screens get 44 pt rows; the Mac keeps them compact.
    #if os(iOS)
    private static let minimumRowHeight: CGFloat = 44
    #else
    private static let minimumRowHeight: CGFloat = 32
    #endif

    /// What the choice means, under the list.
    static func explanation(isRecurring: Bool, scope: CategoryScope) -> String? {
        guard isRecurring else { return nil }
        return scope == .series
            ? String(localized: "Kategorie platí pro všechny výskyty této opakované události.")
            : String(localized: "Kategorie se přidají jen k této události. Kategorie celé série tu zůstávají.")
    }
}
