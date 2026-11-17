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
                        .frame(minWidth: 24)
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
                .frame(minHeight: 32)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.ink)
            .disabled(inherited)
            .accessibilityAddTraits(on ? .isSelected : [])
            .accessibilityHint(inherited ? "Přiřazeno celé sérii. Odeberte ho volbou Celá série." : "")
        }
    }

    /// What the choice means, under the list.
    static func explanation(isRecurring: Bool, scope: CategoryScope) -> String? {
        guard isRecurring else { return nil }
        return scope == .series
            ? "Kategorie platí pro všechny výskyty této opakované události."
            : "Kategorie se přidají jen k této události. Kategorie celé série tu zůstávají."
    }
}
