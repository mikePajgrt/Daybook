import SwiftUI

/// A small month beside the day view. Picking a day shows that day.
struct MonthNavigatorView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        DatePicker("Den", selection: Binding(get: { model.focusedDate }, set: { model.show(day: $0) }),
                   displayedComponents: .date)
            .datePickerStyle(.graphical)
            .labelsHidden()
            .environment(\.calendar, model.calendar)
            .padding(12)
            .frame(width: 320)
            .frame(maxHeight: .infinity, alignment: .top)
            .background(Theme.rail)
    }
}
