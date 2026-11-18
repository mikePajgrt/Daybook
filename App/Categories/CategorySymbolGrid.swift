import DaybookCore
import SwiftUI

/// The symbol picker: a grid of the offered symbols, the chosen one filled with ink.
/// Every cell is a 44 pt target with a Czech accessible name.
struct CategorySymbolGrid: View {
    @Binding var selection: String
    let choices: [String]

    @ScaledMetric(relativeTo: .title3) private var cell: CGFloat = 44
    @State private var width: CGFloat = 0
    private static let spacing: CGFloat = 6

    /// The widest column count whose rows the symbols fill exactly, so no row ends with a few orphans;
    /// when no such count of three or more fits, as many columns as fit.
    static func columnCount(items: Int, width: CGFloat, cell: CGFloat, spacing: CGFloat) -> Int {
        let fitting = max(1, Int((width + spacing) / (cell + spacing)))
        if let even = (3...max(3, fitting)).reversed().first(where: { $0 <= fitting && items % $0 == 0 }) { return even }
        return fitting
    }

    var body: some View {
        let count = width > 0 ? Self.columnCount(items: choices.count, width: width, cell: cell, spacing: Self.spacing) : 6
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Self.spacing), count: count),
                  spacing: Self.spacing) {
            ForEach(choices, id: \.self) { symbol in
                let selected = symbol == selection
                Button { selection = symbol } label: {
                    Image(systemName: symbol)
                        .font(.title3)
                        .foregroundStyle(selected ? Theme.ground : Theme.ink)
                        .frame(maxWidth: .infinity, minHeight: cell)
                        .background {
                            if selected { RoundedRectangle(cornerRadius: 8).fill(Theme.ink) }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(CategoryText.symbolName(symbol))
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(.vertical, 4)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
    }
}
