import DaybookCore
import SwiftUI

/// An event's category symbols, drawn after its title where there is room.
/// Decorative for VoiceOver: the event's own label names its categories.
struct CategorySymbolsView: View {
    let categories: [Category]

    var body: some View {
        HStack(spacing: 2) {
            ForEach(categories) { category in
                // Filled where the symbol has a fill: outlines blur into blobs at event-row size.
                Image(systemName: category.symbol)
                    .symbolVariant(.fill)
            }
        }
        .foregroundStyle(Theme.secondaryInk)
        .fixedSize()
        .accessibilityHidden(true)
    }

    /// Symbol and name of each category as one wrapping line of text, for full-width rows.
    static func names(_ categories: [Category]) -> Text {
        categories.enumerated().reduce(Text(verbatim: "")) { text, item in
            let piece = Text("\(Image(systemName: item.element.symbol)) \(item.element.name)")
            return item.offset == 0 ? piece : Text("\(text)   \(piece)")
        }
    }
}

extension View {
    /// The title, followed by `categories`' symbols only when both fit whole on the line:
    /// symbols never take room from the title.
    func withCategorySymbols(_ categories: [Category], spacing: CGFloat = 4) -> some View {
        modifier(CategorySymbolsAfter(categories: categories, spacing: spacing))
    }
}

private struct CategorySymbolsAfter: ViewModifier {
    let categories: [Category]
    let spacing: CGFloat

    func body(content: Content) -> some View {
        if categories.isEmpty {
            content
        } else {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: spacing) {
                    content.fixedSize()
                    CategorySymbolsView(categories: categories)
                }
                content
            }
        }
    }
}
