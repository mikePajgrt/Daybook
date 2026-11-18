import DaybookCore
import SwiftUI

/// Shown until the app may read calendars: before the system prompt, and after a refusal.
/// Says what Daybook does and why it needs the calendars; once access is granted the month follows.
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

    @ScaledMetric(relativeTo: .title2) private var markSize: CGFloat = 76

    var body: some View {
        // Centred when it fits; at large text sizes it scrolls from the top, inside the safe area,
        // with the gate's margin below the button.
        GeometryReader { proxy in
            ScrollView {
                content
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: proxy.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .foregroundStyle(Theme.ink)
        .background(Theme.ground)
    }

    private var content: some View {
        VStack(spacing: 16) {
            InterchangeMark()
                .frame(width: min(markSize, 120), height: min(markSize, 120))
                .padding(.bottom, 8)
            Text(access == .denied ? "Daybook nemá přístup ke kalendářům"
                                   : "Všechno, co máte v plánu, na jedné obrazovce")
                .font(.title2.bold())
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            Text(access == .denied ? Self.deniedText : Self.introText)
                .foregroundStyle(Theme.secondaryInk)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Group {
                if access == .denied {
                    Button("Otevřít Nastavení") {
                        if let settingsURL { openURL(settingsURL) }
                    }
                } else {
                    Button("Povolit přístup ke kalendářům", action: request)
                }
            }
            // The world's ink, not system blue: a blue control would read like a calendar line.
            .buttonStyle(.borderedProminent)
            .tint(Theme.ink)
            .foregroundStyle(Theme.ground)
            .controlSize(.large)
        }
        .frame(maxWidth: 440)
        .padding(32)
    }

    private static let introText: LocalizedStringKey = "Daybook ukazuje události ze všech kalendářů ve vašem zařízení, z iCloudu, Exchange i Googlu, a v měsíci nikdy žádnou neschová. Aby je mohl zobrazit a upravovat, potřebuje přístup ke kalendářům. Události zůstávají ve vašich účtech."

    #if os(macOS)
    private static let deniedText: LocalizedStringKey = "Povolte ho v Nastavení systému v části Soukromí a zabezpečení, Kalendáře. Pak se sem vraťte."
    #else
    private static let deniedText: LocalizedStringKey = "Povolte ho v Nastavení v části Aplikace, Daybook, Kalendáře. Pak se sem vraťte."
    #endif
}
