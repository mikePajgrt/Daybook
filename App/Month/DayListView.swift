import DaybookCore
import SwiftUI

/// Everything planned on one day, in full. Presented from the month on compact widths.
struct DayListView: View {
    @Environment(AppModel.self) private var model
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
                    Capsule()
                        .fill(Color(info?.color ?? RGBA(r: 0.56, g: 0.56, b: 0.58)))
                        .frame(width: 4)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(EventRowView.title(of: event))
                            .font(.body)
                            .foregroundStyle(Theme.ink)
                        Text([when(event), info?.title].compactMap { $0 }.joined(separator: " · "))
                            .font(.subheadline)
                            .foregroundStyle(Theme.secondaryInk)
                    }
                }
                .accessibilityElement(children: .combine)
                .listRowBackground(Theme.ground)
            }
        }
        // The world's colours instead of system grey: rows on the ground, set in the deeper rail.
        .scrollContentBackground(.hidden)
        .background(Theme.rail)
        .navigationTitle(day.formatted(.dateTime.weekday(.wide).day().month(.wide)))
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
        if event.isAllDay { return "Celý den" }
        if model.calendar.isDate(event.start, inSameDayAs: event.end) {
            let start = event.start.formatted(date: .omitted, time: .shortened)
            let end = event.end.formatted(date: .omitted, time: .shortened)
            return "\(start) – \(end)"
        }
        let start = event.start.formatted(date: .abbreviated, time: .shortened)
        let end = event.end.formatted(date: .abbreviated, time: .shortened)
        return "\(start) – \(end)"
    }
}
