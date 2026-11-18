import DaybookCore
import SwiftUI

/// Calendars grouped by account, then categories. One click or tap switches either on or off.
struct SidebarView: View {
    @Environment(AppModel.self) private var model
    @Environment(CategoryModel.self) private var categories
    /// Row fill when the list is shown as an inset list (the iPhone sheet); `nil` keeps the sidebar style.
    var rowBackground: ThemeColor? = nil

    var body: some View {
        ScrollViewReader { reader in
            list
                .task {
                    #if DEBUG
                    if model.stagedScreens.contains("categories") {
                        try? await Task.sleep(for: .milliseconds(500))
                        reader.scrollTo(Self.categoriesID, anchor: .top)
                    }
                    await model.stageCategoryScreens()
                    #endif
                }
        }
    }

    static let categoriesID = "categories"

    private var list: some View {
        @Bindable var categories = categories
        return List {
            #if os(macOS)
            // The split view's navigation title does not render above a Mac sidebar.
            Text("Daybook")
                .font(.title3.weight(.bold))
                .foregroundStyle(Theme.ink)
                .accessibilityAddTraits(.isHeader)
            #endif
            // The day view's month navigator, when the day column has no room for it beside the day.
            // It sits in the list and scrolls with it, so the calendars and categories keep the rail.
            if model.mode == .day && model.dayNavigatorInSidebar {
                Section {
                    MonthNavigatorView()
                        .listRowBackground(rowBackground)
                }
            }
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
                Button { model.beginNewCalendar() } label: { AddRowLabel(title: "Nový kalendář") }
                    .buttonStyle(.plain)
                    .foregroundStyle(Theme.ink)
                    .listRowBackground(rowBackground)
            }
            if !model.calendars.isEmpty {
                CategorySidebarSection(rowBackground: rowBackground)
                    .id(Self.categoriesID)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.rail)
        // Shown from the sidebar, so on iPhone it rises over the calendars sheet it was opened from.
        .sheet(item: Binding(get: { model.calendarEditor }, set: { model.calendarEditor = $0 })) { editor in
            CalendarEditorView(editor: editor) { model.calendarEditor = nil }
                .presentationBackground(Theme.rail)
        }
        .sheet(item: $categories.editor) { editor in
            CategoryEditorView(editor: editor) { categories.editor = nil }
                .environment(categories)
                .presentationBackground(Theme.rail)
        }

        .overlay {
            if model.calendars.isEmpty {
                ContentUnavailableView("Žádné kalendáře", systemImage: "calendar.badge.exclamationmark",
                                       description: Text(NoCalendarsView.whereToAdd))
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
                    .foregroundStyle(Theme.line(calendar.color))
                    .imageScale(.large)
                VStack(alignment: .leading, spacing: 1) {
                    // At accessibility sizes the name wraps between words instead of losing letters.
                    Group {
                        if large {
                            WholeWordText(calendar.title)
                        } else {
                            Text(calendar.title).lineLimit(1)
                        }
                    }
                    .foregroundStyle(isOn ? Theme.ink : Theme.secondaryInk)
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
        .accessibilityValue(isOn ? Text("zapnutý") : Text("vypnutý"))
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
            // On the same line as the category menu buttons below.
            .frame(width: large ? nil : FilterRowMetrics.lockWidth)
            .accessibilityLabel("jen pro čtení")
    }
}
