import DaybookCore
import SwiftUI

/// Access is granted but the system has no calendars: where to add an account, and a calendar on the
/// device where one can be made.
struct NoCalendarsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ContentUnavailableView {
            Label("Žádné kalendáře", systemImage: "calendar.badge.plus")
        } description: {
            Text(NoCalendarsView.whereToAdd)
        } actions: {
            if model.store.sources().contains(where: \.offersCalendarCreation) {
                Button("Nový kalendář", systemImage: "plus") { model.beginNewCalendar() }
                    .buttonStyle(.bordered)
                    .tint(Theme.ink)
            }
        }
        .foregroundStyle(Theme.ink)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.ground)
    }

    /// Where the system keeps calendar accounts, on this platform.
    static var whereToAdd: LocalizedStringKey {
        #if os(macOS)
        "Přidejte účet iCloud, Exchange nebo Google v Nastavení systému v části Internetové účty. Jeho kalendáře se tu pak objeví samy."
        #else
        "Přidejte účet iCloud, Exchange nebo Google v Nastavení v části Aplikace, Kalendář, Účty kalendáře. Jeho kalendáře se tu pak objeví samy."
        #endif
    }
}
