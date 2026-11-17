import DaybookCore
import SwiftUI

/// Shown until the app may read calendars: before the system prompt, and after a refusal.
struct AccessView: View {
    let access: CalendarAccess
    let request: () -> Void
    @Environment(\.openURL) private var openURL

    private var settingsURL: URL? {
        #if os(iOS)
        URL(string: UIApplication.openSettingsURLString)
        #else
        URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars")
        #endif
    }

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar")
                .font(.system(size: 44, weight: .semibold))
                .accessibilityHidden(true)
            Text(access == .denied ? "Daybook nemá přístup ke kalendářům"
                                   : "Všechno, co máte v plánu, na jedné obrazovce")
                .font(.title2.bold())
                .multilineTextAlignment(.center)
            Text(access == .denied
                 ? "Povolte ho v Nastavení v části Soukromí a zabezpečení, Kalendáře. Pak se sem vraťte."
                 : "Daybook zobrazí události ze všech kalendářů, které máte v zařízení: iCloud, Exchange i Google. Potřebuje k nim přístup.")
                .foregroundStyle(Theme.secondaryInk)
                .multilineTextAlignment(.center)
            if access == .denied {
                Button("Otevřít Nastavení") {
                    if let settingsURL { openURL(settingsURL) }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            } else {
                Button("Povolit přístup ke kalendářům", action: request)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
            }
        }
        .frame(maxWidth: 440)
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .foregroundStyle(Theme.ink)
        .background(Theme.ground)
    }
}
