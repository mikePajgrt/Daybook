import DaybookCore
import Foundation
import Observation

/// The form state of the new-category or edit-category sheet.
@MainActor
@Observable
final class CategoryEditorModel: Identifiable {
    enum Mode {
        case new
        case edit(Category)
    }

    /// What the sheet was opened for: "Přejmenovat…" puts the cursor in the name,
    /// "Změnit symbol…" leaves the name alone.
    enum Focus { case name, symbol }

    let id = UUID()
    let mode: Mode
    let focus: Focus
    /// The other categories, for the unique-name rule.
    private let others: [Category]
    var name: String
    var symbol: String
    var errorMessage: String?

    init(mode: Mode, others: [Category], focus: Focus = .name) {
        self.mode = mode
        self.others = others
        self.focus = focus
        switch mode {
        case .new:
            name = ""
            symbol = CategorySymbols.offered.first { symbol in !others.contains { $0.symbol == symbol } }
                ?? CategorySymbols.fallback
        case .edit(let category):
            name = category.name
            symbol = category.symbol
        }
    }

    var isNew: Bool {
        if case .new = mode { return true }
        return false
    }

    private var editedID: UUID? {
        if case .edit(let category) = mode { return category.id }
        return nil
    }

    var problems: [CategoryNameProblem] { CategoryName.problems(name, among: others, excluding: editedID) }

    var hasChanges: Bool {
        switch mode {
        case .new: return true
        case .edit(let category): return CategoryName.normalized(name) != category.name || symbol != category.symbol
        }
    }

    var canSave: Bool { problems.isEmpty && hasChanges }

    /// Symbols offered: the curated set, plus the category's own when it came from elsewhere.
    var symbolChoices: [String] {
        CategorySymbols.offered.contains(symbol) ? CategorySymbols.offered : [symbol] + CategorySymbols.offered
    }
}
