import DaybookCore
import SwiftUI

/// Everything about one event, read-only, with Edit and Delete for events the user may change.
/// The same view fills the popover on Mac and iPad and the sheet on iPhone.
struct EventDetailView: View {
    enum Style { case popover, sheet }

    @Environment(AppModel.self) private var model
    @Environment(CategoryModel.self) private var categories
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    #endif
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
    /// The category checklist is open below the event's categories.
    @State private var editsCategories = false
    @State private var categoryScope: CategoryScope = .series

    private var calendarInfo: CalendarInfo? { model.calendarInfo(event.calendarID) }
    private var title: String { EventRowView.title(of: event) }

    var body: some View {
        Group {
            switch style {
            case .popover:
                VStack(spacing: 0) {
                    ScrollViewReader { reader in
                        ScrollView { content.padding(16) }
                            .task { await stageAttendees(reader) }
                    }
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
                ScrollViewReader { reader in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            content
                            // Editing is in the bar; deleting stays at the end, away from the reading.
                            if event.isEditable {
                                deleteButton
                                    .controlSize(.large)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .id(Self.deleteID)
                            }
                        }
                        .padding(20)
                    }
                    .task {
                        await stageAttendees(reader)
                        // Opened asking to delete: the button the question hangs on comes into view first.
                        if asksDeleteAtStart { withAnimation { reader.scrollTo(Self.deleteID, anchor: .bottom) } }
                    }
                }
                .background(Theme.ground)
                .navigationTitle("Událost")
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                // An opaque bar on the sheet's ground, as the other sheets have: no text blurs behind it.
                .toolbarBackground(Theme.ground, for: .navigationBar)
                .toolbarBackgroundVisibility(.visible, for: .navigationBar)
                #endif
                .toolbar {
                    if event.isEditable {
                        ToolbarItem(placement: .primaryAction) {
                            Button("Upravit", action: onEdit)
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Hotovo", action: onClose)
                    }
                }
            }
        }
        .foregroundStyle(Theme.ink)
        .alert("Událost se nepodařilo smazat", isPresented: Binding(get: { deleteError != nil },
                                                                    set: { if !$0 { deleteError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(deleteError ?? "")
        }
        .alert(EventText.inviteUnavailableTitle, isPresented: $inviteUnavailable) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(EventText.inviteUnavailableMessage(isDemo: !model.canOpenSystemEditor))
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

    /// Debug staging: scrolls to the attendees, as a reader would.
    private func stageAttendees(_ reader: ScrollViewProxy) async {
        #if DEBUG
        guard model.stagedScreens.contains("detail-attendees") else { return }
        try? await Task.sleep(for: .milliseconds(900))
        withAnimation { reader.scrollTo(Self.attendeesID, anchor: .top) }
        #endif
    }

    private static let attendeesID = "attendees"
    private static let deleteID = "delete"

    private var deleteTitle: String {
        event.isRecurring ? String(localized: "Smazat opakovanou událost „\(title)“?")
                          : String(localized: "Smazat událost „\(title)“?")
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

            categorySection

            if let location = event.location, !location.isEmpty {
                detailRow("mappin.and.ellipse", label: String(localized: "Místo")) { Text(location) }
            }
            if let url = event.url {
                detailRow("link", label: String(localized: "Odkaz")) {
                    // Invitations carry other people's URLs: only web and mail links open.
                    if EventLink.isOpenable(url) {
                        Link(url.absoluteString, destination: url)
                            .lineLimit(2)
                            .tint(Theme.controlInk)
                            .underline()
                    } else {
                        Text(url.absoluteString)
                            .lineLimit(2)
                            .textSelection(.enabled)
                    }
                }
            }
            if event.alert != nil {
                detailRow("bell", label: String(localized: "Upozornění")) { Text(EventText.alert(event.alert)) }
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
                    Text("Kalendář „\(calendarInfo?.title ?? "")“ je jen pro čtení. Událost tu nejde upravit ani smazat, kategorie ano.")
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
            StationMark(color: Theme.line(calendarInfo?.color ?? Theme.fallbackLine))
                .frame(height: 22)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 0) {
                Text(calendarInfo?.title ?? String(localized: "Neznámý kalendář"))
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

    /// The event's categories (symbol and name), and the checklist to change them. Categories are
    /// Daybook's own data, so they can be changed on read-only calendars too.
    private var categorySection: some View {
        let assigned = categories.categories(for: event.key)
        return VStack(alignment: .leading, spacing: 8) {
            Text("Kategorie").font(.caption.weight(.semibold)).foregroundStyle(Theme.secondaryInk)
            if assigned.isEmpty {
                Text("Žádné").foregroundStyle(Theme.secondaryInk)
            } else {
                ForEach(assigned) { category in
                    Label(category.name, systemImage: category.symbol)
                }
            }
            if categories.categories.isEmpty {
                Text(whereToCreateCategories)
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                DisclosureGroup(isExpanded: $editsCategories) {
                    VStack(alignment: .leading, spacing: 6) {
                        CategoryChecklist(categories: categories.categories, isRecurring: event.isRecurring,
                                          scope: $categoryScope,
                                          selection: Binding(get: { categories.selection(for: event.key) },
                                                             set: { new in
                                                                 let old = categories.selection(for: event.key)
                                                                 if let problem = categories.apply(new, from: old, to: event.key) {
                                                                     model.notice = Notice(title: String(localized: "Kategorie se nepodařilo změnit"),
                                                                                           message: problem)
                                                                 }
                                                             }))
                        if let text = CategoryChecklist.explanation(isRecurring: event.isRecurring, scope: categoryScope) {
                            Text(text)
                                .font(.caption)
                                .foregroundStyle(Theme.secondaryInk)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.top, 6)
                } label: {
                    Text(assigned.isEmpty ? "Přiřadit kategorie" : "Upravit kategorie")
                        .foregroundStyle(Theme.ink)
                }
                .tint(Theme.controlInk)
            }
        }
        .onAppear {
            #if DEBUG
            if model.stagedScreens.contains("detail-categories") { editsCategories = true }
            #endif
        }
    }

    /// Where "Nová kategorie" is: the iPhone has no sidebar, only the list that rises from the bar.
    private var whereToCreateCategories: LocalizedStringKey {
        #if os(iOS)
        if sizeClass == .compact { return "Kategorie založíte v seznamu Kalendáře a kategorie volbou Nová kategorie." }
        #endif
        return "Kategorie založíte v postranním panelu volbou Nová kategorie."
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
                    .id(Self.attendeesID)
                ForEach(Array(event.attendees.enumerated()), id: \.offset) { _, person in
                    AttendeeRow(attendee: person)
                }
                #if os(iOS)
                if event.isEditable {
                    Button("Pozvat účastníky", systemImage: "person.badge.plus", action: openInvite)
                        .buttonStyle(.bordered)
                        .tint(Theme.controlInk)
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
                .tint(Theme.controlInk)
                .keyboardShortcut("e", modifiers: .command)
            Spacer()
            deleteButton
        }
        .controlSize(style == .popover ? .regular : .large)
    }

    /// The dialog hangs on the button, so it emerges from the control that asked.
    private var deleteButton: some View {
        Button("Smazat událost", systemImage: "trash", role: .destructive) { asksDelete = true }
            .buttonStyle(.bordered)
            // The view's ink would otherwise override the destructive colour.
            .foregroundStyle(.red)
            .tint(.red)
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
                Text(attendee.displayName.isEmpty ? String(localized: "Bez jména") : attendee.displayName)
                Text(attendee.isOrganizer ? String(localized: "Organizátor · \(EventText.status(attendee.status))")
                                          : EventText.status(attendee.status))
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryInk)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
