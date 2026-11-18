import DaybookCore
import SwiftUI

/// Everything planned on one day, in full. Presented from the month on compact widths.
struct DayListView: View {
    @Environment(AppModel.self) private var model
    @Environment(CategoryModel.self) private var categoryModel
    @Environment(\.dismiss) private var dismiss
    let day: Date

    var body: some View {
        let events = model.events(on: day)
        List {
            if events.isEmpty {
                Text("Na tento den není nic naplánováno.")
                    .foregroundStyle(Theme.secondaryInk)
                    .listRowBackground(Theme.ground)
            }
            ForEach(events) { event in
                let info = model.calendarInfo(event.calendarID)
                HStack(spacing: 12) {
                    // The same mark as everywhere: a piece of the calendar's line with the event's station.
                    StationMark(color: Theme.line(info?.color ?? Theme.fallbackLine))
                        .padding(.vertical, 2)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(EventRowView.title(of: event))
                            .font(.body)
                            .foregroundStyle(Theme.ink)
                        Text([when(event), info?.title].compactMap { $0 }.joined(separator: " · "))
                            .font(.subheadline)
                            .foregroundStyle(Theme.secondaryInk)
                        let categories = categoryModel.categories(for: event.key)
                        if !categories.isEmpty {
                            CategorySymbolsView.names(categories)
                                .font(.subheadline)
                                .foregroundStyle(Theme.secondaryInk)
                        }
                    }
                }
                .accessibilityElement(children: .combine)
                .opensEventDetail(event)
                .listRowBackground(Theme.ground)
            }
        }
        .environment(\.isInDaySheet, true)
        // An editor opened from this sheet's events rises over it; the root cannot present while it is up.
        .sheet(item: Binding(get: { model.editorInDaySheet ? model.editor : nil },
                             set: { model.editor = $0 })) { editor in
            EventEditorView(editor: editor) { model.editor = nil }
                .presentationBackground(Theme.rail)
                // iPad: a page-sized sheet shows more of the form without scrolling.
                .presentationSizing(.page)
        }
        // The world's colours instead of system grey: rows on the ground, set in the deeper rail.
        .scrollContentBackground(.hidden)
        .background(Theme.rail)
        // Capitalised as every other date heading: "Úterý 17. listopadu".
        .navigationTitle(day.formatted(.dateTime.weekday(.wide).day().month(.wide)).localizedCapitalizedFirst)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Hotovo") { dismiss() }
            }
        }
    }

    private func when(_ event: EventInfo) -> String {
        if event.isAllDay { return String(localized: "Celý den") }
        return TimeText.span(event, calendar: model.calendar, dateStyle: .dateTime.day().month(.abbreviated))
    }
}
