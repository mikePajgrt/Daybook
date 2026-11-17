import DaybookCore
import SwiftUI

/// Calendars grouped by account. One click or tap switches a calendar on or off.
struct SidebarView: View {
    @Environment(AppModel.self) private var model

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
                Section(section.title) {
                    ForEach(section.calendars) { calendar in
                        CalendarToggleRow(calendar: calendar, isOn: model.filter.isVisible(calendar.id)) {
                            model.toggle(calendar)
                        }
                        .contextMenu {
                            Button("Zobrazit jen tento") { model.showOnly(calendar) }
                            Button("Zobrazit všechny") { model.showAll() }
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.rail)
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

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: isOn ? "checkmark.square.fill" : "square")
                    .foregroundStyle(Color(calendar.color))
                    .imageScale(.large)
                VStack(alignment: .leading, spacing: 1) {
                    Text(calendar.title)
                        .foregroundStyle(isOn ? Theme.ink : Theme.secondaryInk)
                        .lineLimit(1)
                    if calendar.isShared {
                        Text("sdílený")
                            .font(.caption)
                            .foregroundStyle(Theme.secondaryInk)
                    }
                }
                Spacer(minLength: 8)
                if calendar.isReadOnly {
                    Image(systemName: "lock.fill")
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryInk)
                        .accessibilityLabel("jen pro čtení")
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityValue(isOn ? "zapnutý" : "vypnutý")
        .accessibilityAddTraits(.isToggle)
    }
}
