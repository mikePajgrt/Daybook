import SwiftUI

/// Text that wraps between words and never inside one (The No Broken Words Rule). It takes the width
/// it is offered; when its longest word is wider than that, the face condenses before anything breaks.
/// The longest word is measured in the inherited font, regular and condensed.
struct WholeWordText: View {
    let text: String

    @State private var available: CGFloat = 0
    @State private var longestWord: CGFloat = 0

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .fontWidth(condenses ? .condensed : .standard)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { available = $0 }
            .background { probe }
    }

    private var condenses: Bool { available > 0 && longestWord > available }

    /// One word per line: the stack is as wide as the widest word.
    private var probe: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(text.split(whereSeparator: \.isWhitespace).enumerated()), id: \.offset) { _, word in
                Text(String(word))
            }
        }
        .fixedSize()
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { longestWord = $0 }
        .hidden()
        .accessibilityHidden(true)
    }
}
