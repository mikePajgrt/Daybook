import DaybookCore
import SwiftUI

/// The symbol picker: a grid of the offered symbols, the chosen one filled with ink.
/// Every cell is a 44 pt target with a Czech accessible name.
struct CategorySymbolGrid: View {
    @Binding var selection: String
    let choices: [String]

    @ScaledMetric(relativeTo: .title3) private var cell: CGFloat = 44

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: cell, maximum: cell * 1.5), spacing: 6)], spacing: 6) {
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
    }
}
