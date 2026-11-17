import DaybookCore
import SwiftUI

extension EnvironmentValues {
    /// True inside the iPhone day sheet: an editor opened from there is shown on top of the sheet.
    @Entry var isInDaySheet = false
}

extension View {
    /// Makes the view open `event`'s detail when clicked or tapped:
    /// a popover on Mac and iPad, a sheet on iPhone.
    func opensEventDetail(_ event: EventInfo) -> some View {
        modifier(EventDetailPresenter(event: event))
    }

    /// Opens `event`'s detail only when `enabled`; otherwise leaves the view as it is.
    @ViewBuilder func opensEventDetail(_ event: EventInfo, when enabled: Bool) -> some View {
        if enabled { opensEventDetail(event) } else { self }
    }
}

struct EventDetailPresenter: ViewModifier {
    @Environment(AppModel.self) private var model
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.isInDaySheet) private var isInDaySheet
    let event: EventInfo

    @State private var shows = false
    @State private var asksDelete = false

    private var compact: Bool { sizeClass == .compact }

    func body(content: Content) -> some View {
        content
            .contentShape(Rectangle())
            .onTapGesture { shows = true }
            .accessibilityAddTraits(.isButton)
            .accessibilityAction(named: "Otevřít podrobnosti") { shows = true }
            // Mac and iPad: categories straight from the event, without opening it.
            .contextMenu {
                Button("Otevřít podrobnosti", systemImage: "info.circle") { shows = true }
                EventCategoryMenu(event: event)
            }
            .popover(isPresented: Binding(get: { shows && !compact }, set: { shows = $0 })) {
                detail(.popover)
            }
            .sheet(isPresented: Binding(get: { shows && compact }, set: { shows = $0 })) {
                NavigationStack { detail(.sheet) }
                    .presentationDetents([.medium, .large])
                    .presentationBackground(Theme.ground)
            }
            .task {
                guard let staged = model.stagedDetail, staged.key == event.key else { return }
                model.stagedDetail = nil
                try? await Task.sleep(for: .milliseconds(800))
                asksDelete = staged.asksDelete
                shows = true
            }
    }

    private func detail(_ style: EventDetailView.Style) -> some View {
        EventDetailView(event: event, style: style,
                        onClose: { shows = false },
                        onEdit: edit,
                        asksDeleteAtStart: asksDelete)
            .environment(model)
            .environment(model.categoryModel)
    }

    /// Closes the detail, then opens the editor once the popover or sheet has gone,
    /// since one presentation cannot start while another is leaving.
    private func edit() {
        shows = false
        let inDaySheet = isInDaySheet
        Task {
            try? await Task.sleep(for: .milliseconds(450))
            model.beginEditing(event, inDaySheet: inDaySheet)
        }
    }
}
