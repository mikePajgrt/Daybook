import DaybookCore
import SwiftUI

/// Everything about one event, read-only, with Edit and Delete for events the user may change.
/// The same view fills the popover on Mac and iPad and the sheet on iPhone.
struct EventDetailView: View {
    enum Style { case popover, sheet }

    @Environment(AppModel.self) private var model
    let event: EventInfo
    let style: Style
    /// Closes the popover or sheet.
    let onClose: () -> Void
    /// Closes the detail and opens the editor.
    let onEdit: () -> Void
    /// Debug staging: open with the delete question already asked.
    var asksDeleteAtStart = false

    @State private var asksDelete = false
    @State private var deleteError: String?
    #if os(iOS)
    @State private var invite: InviteRequest?
    #endif
    @State private var inviteUnavailable = false

    private var calendarInfo: CalendarInfo? { model.calendarInfo(event.calendarID) }
    private var title: String { EventRowView.title(of: event) }

    var body: some View {
        Group {
            switch style {
            case .popover:
                VStack(spacing: 0) {
                    ScrollView { content.padding(16) }
                    if event.isEditable {
                        Rectangle().fill(Theme.rule).frame(height: 1)
                        actions.padding(12)
                    }
                }
                .frame(width: 360)
                .frame(maxHeight: 560)
                .fixedSize(horizontal: false, vertical: true)
                .background(Theme.ground)
            case .sheet:
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        content
                        if event.isEditable { actions }
                    }
                    .padding(20)
                }
                .background(Theme.ground)
                .navigationTitle("Událost")
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Hotovo", action: onClose)
                    }
                }
            }
        }
        .foregroundStyle(Theme.ink)
        .confirmationDialog(deleteTitle, isPresented: $asksDelete, titleVisibility: .visible) {
            if event.isRecurring {
                Button("Smazat jen tuto událost", role: .destructive) { delete(.thisEvent) }
                Button("Smazat tuto a všechny budoucí", role: .destructive) { delete(.futureEvents) }
            } else {
                Button("Smazat událost", role: .destructive) { delete(.thisEvent) }
            }
            Button("Ponechat", role: .cancel) {}
        } message: {
            Text(event.isRecurring ? "Událost se opakuje. Vyberte, které výskyty smazat."
                                   : "Událost zmizí ze všech zařízení, která tento kalendář používají.")
        }
        .alert("Událost se nepodařilo smazat", isPresented: Binding(get: { deleteError != nil },
                                                                    set: { if !$0 { deleteError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(deleteError ?? "")
        }
        .alert("Pozvánky tu teď otevřít nejde", isPresented: $inviteUnavailable) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Systémový editor pozvánek pracuje jen s kalendáři v zařízení. V ukázkovém režimu se neotevře.")
        }
        #if os(iOS)
        .sheet(item: $invite) { request in
            SystemEventEditor(store: request.store, event: request.event) { invite = nil }
                .ignoresSafeArea()
        }
        #endif
        .task {
            if asksDeleteAtStart {
                try? await Task.sleep(for: .milliseconds(600))
                asksDelete = true
            }
        }
    }

    private var deleteTitle: String {
        event.isRecurring ? "Smazat opakovanou událost „\(title)“?" : "Smazat událost „\(title)“?"
    }

    // MARK: Content

    private var content: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(event.title.isEmpty ? Theme.secondaryInk : Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                Text(EventText.when(event, calendar: model.calendar))
                    .font(.subheadline)
                    .monospacedDigit()
                if let zone = EventText.zoneNote(event, calendar: model.calendar) {
                    Text(zone).font(.subheadline).foregroundStyle(Theme.secondaryInk)
                }
                if let rule = event.recurrence {
                    Label(EventText.recurrence(rule), systemImage: "repeat")
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondaryInk)
                }
            }

            calendarRow

            if let location = event.location, !location.isEmpty {
                detailRow("mappin.and.ellipse", label: "Místo") { Text(location) }
            }
            if let url = event.url {
                detailRow("link", label: "Odkaz") {
                    // Invitations carry other people's URLs: only web and mail links open.
                    if EventLink.isOpenable(url) {
                        Link(url.absoluteString, destination: url)
                            .lineLimit(2)
                            .tint(Theme.ink)
                            .underline()
                    } else {
                        Text(url.absoluteString)
                            .lineLimit(2)
                            .textSelection(.enabled)
                    }
                }
            }
            if event.alert != nil {
                detailRow("bell", label: "Upozornění") { Text(EventText.alert(event.alert)) }
            }

            attendees

            if let notes = event.notes, !notes.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Poznámka").font(.caption.weight(.semibold)).foregroundStyle(Theme.secondaryInk)
                    Text(notes).fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
                }
            }

            if !event.isEditable {
                Label {
                    Text("Kalendář „\(calendarInfo?.title ?? "")“ je jen pro čtení. Událost tu nejde upravit ani smazat.")
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "lock.fill")
                }
                .font(.subheadline)
                .foregroundStyle(Theme.secondaryInk)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var calendarRow: some View {
        HStack(spacing: 10) {
            Capsule()
                .fill(Color(calendarInfo?.color ?? RGBA(r: 0.56, g: 0.56, b: 0.58)))
                .frame(width: 4, height: 22)
            VStack(alignment: .leading, spacing: 0) {
                Text(calendarInfo?.title ?? "Neznámý kalendář")
                if let source = calendarInfo?.sourceTitle, !source.isEmpty {
                    Text(source).font(.caption).foregroundStyle(Theme.secondaryInk)
                }
            }
            if calendarInfo?.isReadOnly == true {
                Image(systemName: "lock.fill")
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryInk)
                    .accessibilityLabel("jen pro čtení")
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Kalendář \(calendarInfo?.title ?? "")")
    }

    private func detailRow<Value: View>(_ symbol: String, label: String,
                                        @ViewBuilder value: () -> Value) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: symbol)
                .foregroundStyle(Theme.secondaryInk)
                .frame(width: 20)
                .accessibilityLabel(label)
            value().frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder private var attendees: some View {
        if !event.attendees.isEmpty || (event.isEditable && model.canOpenSystemEditor) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Účastníci").font(.caption.weight(.semibold)).foregroundStyle(Theme.secondaryInk)
                ForEach(Array(event.attendees.enumerated()), id: \.offset) { _, person in
                    AttendeeRow(attendee: person)
                }
                #if os(iOS)
                if event.isEditable {
                    Button("Pozvat účastníky", systemImage: "person.badge.plus", action: openInvite)
                        .buttonStyle(.bordered)
                        .tint(Theme.ink)
                }
                #else
                Text("Pozvánky se posílají z aplikace Kalendář nebo z Outlooku.")
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
                #endif
            }
        }
    }

    private var actions: some View {
        HStack(spacing: 12) {
            Button("Upravit", systemImage: "pencil", action: onEdit)
                .buttonStyle(.bordered)
                .tint(Theme.ink)
                .keyboardShortcut("e", modifiers: .command)
            Spacer()
            Button("Smazat událost", systemImage: "trash", role: .destructive) { asksDelete = true }
                .buttonStyle(.bordered)
        }
        .controlSize(style == .popover ? .regular : .large)
    }

    // MARK: Actions

    private func delete(_ span: EditSpan) {
        if let error = model.deleteReportingError(event, span: span) {
            deleteError = error
        } else {
            onClose()
        }
    }

    private func openInvite() {
        #if os(iOS)
        guard model.canOpenSystemEditor, let context = model.systemEditorContext(for: event) else {
            inviteUnavailable = true
            return
        }
        invite = InviteRequest(store: context.store, event: context.event)
        #endif
    }
}

/// One invitee: whether they answered, their name, and the organizer mark.
struct AttendeeRow: View {
    let attendee: Attendee

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: EventText.statusSymbol(attendee.status))
                .foregroundStyle(Theme.secondaryInk)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 0) {
                Text(attendee.displayName.isEmpty ? "Bez jména" : attendee.displayName)
                Text(attendee.isOrganizer ? "Organizátor · \(EventText.status(attendee.status))"
                                          : EventText.status(attendee.status))
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryInk)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
