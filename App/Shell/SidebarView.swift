import DaybookCore
import SwiftUI

/// Calendars grouped by account. One click or tap switches a calendar on or off.
struct SidebarView: View {
    @Environment(AppModel.self) private var model
    /// Row fill when the list is shown as an inset list (the iPhone sheet); `nil` keeps the sidebar style.
    var rowBackground: Color? = nil

    var body: some View {
        List {
            #if os(macOS)
            // The split view's navigation title does not render above a Mac sidebar.
            Text("Daybook")
                .font(.title3.weight(.bold))
                .foregroundStyle(Theme.ink)
                .accessibilityAddTraits(.isHeader)
            #endif
            ForEach(model.sections) { section in
                Section {
                    ForEach(section.calendars) { calendar in
                        CalendarToggleRow(calendar: calendar, isOn: model.filter.isVisible(calendar.id)) {
                            model.toggle(calendar)
                        }
                        .contextMenu {
                            Button("Zobrazit jen tento") { model.showOnly(calendar) }
                            Button("Zobrazit všechny") { model.showAll() }
                            Divider()
                            Button("Změnit barvu…", systemImage: "paintpalette") { model.beginRecoloring(calendar) }
                        }
                        .listRowBackground(rowBackground)
                    }
                } header: {
                    Text(section.title)
                        .foregroundStyle(Theme.secondaryInk)
                }
            }
            Section {
                Button("Nový kalendář", systemImage: "plus") { model.beginNewCalendar() }
                    .foregroundStyle(Theme.ink)
                    .listRowBackground(rowBackground)
            }
        }
        .scrollContentBackground(.hidden)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            // The day view's month navigator, when the day column has no room for it beside the day.
            if model.mode == .day && model.dayNavigatorInSidebar {
                MonthNavigatorView()
                    .padding(12)
                    .background(Theme.rail)
                    .overlay(alignment: .top) { Rectangle().fill(Theme.rule).frame(height: 1) }
            }
        }
        .background(Theme.rail)
        // Shown from the sidebar, so on iPhone it rises over the calendars sheet it was opened from.
        .sheet(item: Binding(get: { model.calendarEditor }, set: { model.calendarEditor = $0 })) { editor in
            CalendarEditorView(editor: editor) { model.calendarEditor = nil }
                .presentationBackground(Theme.rail)
        }
        .overlay {
            if model.calendars.isEmpty {
                ContentUnavailableView("Žádné kalendáře",
                                       systemImage: "calendar.badge.exclamationmark",
                                       description: Text("Přidejte účet iCloud, Exchange nebo Google v systémovém Nastavení."))
            }
        }
    }
}

private struct CalendarToggleRow: View {
    let calendar: CalendarInfo
    let isOn: Bool
    let action: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Button(action: action) {
            HStack(alignment: large ? .firstTextBaseline : .center, spacing: 10) {
                Image(systemName: isOn ? "checkmark.square.fill" : "square")
                    .foregroundStyle(Color(calendar.color))
                    .imageScale(.large)
                VStack(alignment: .leading, spacing: 1) {
                    Text(calendar.title)
                        .foregroundStyle(isOn ? Theme.ink : Theme.secondaryInk)
                        // At accessibility sizes the name wraps between words instead of losing letters.
                        .lineLimit(large ? nil : 1)
                        .fixedSize(horizontal: false, vertical: large)
                    if large {
                        // The caption and the lock go under the name, so the name keeps the row's width.
                        if calendar.isShared || calendar.isReadOnly {
                            HStack(spacing: 6) {
                                if calendar.isShared { sharedCaption }
                                if calendar.isReadOnly { lock }
                            }
                        }
                    } else if calendar.isShared {
                        sharedCaption
                    }
                }
                Spacer(minLength: 8)
                if !large && calendar.isReadOnly { lock }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityValue(isOn ? "zapnutý" : "vypnutý")
        .accessibilityAddTraits(.isToggle)
    }

    private var large: Bool { dynamicTypeSize.isAccessibilitySize }

    private var sharedCaption: some View {
        Text("sdílený")
            .font(.caption)
            .foregroundStyle(Theme.secondaryInk)
            .fixedSize()
    }

    private var lock: some View {
        Image(systemName: "lock.fill")
            .font(.caption)
            .foregroundStyle(Theme.secondaryInk)
            .accessibilityLabel("jen pro čtení")
    }
}
