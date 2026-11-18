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
        // Centred, button under the text, when it all fits. At large text sizes the text scrolls inside
        // the safe area and the button stays pinned above the bottom edge on the ground.
        ViewThatFits(in: .vertical) {
            VStack(spacing: 16) {
                message
                action
            }
            .frame(maxWidth: 440)
            .padding(32)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            ScrollView {
                message
                    .frame(maxWidth: 440)
                    .padding([.horizontal, .top], 32)
                    .padding(.bottom, 16)
                    .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                action
                    .padding(.horizontal, 32)
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity)
                    .background(Theme.ground)
                    .overlay(alignment: .top) { Rectangle().fill(Theme.rule).frame(height: 1) }
            }
        }
        .foregroundStyle(Theme.ink)
        .background(Theme.ground)
    }

    private var message: some View {
        VStack(spacing: 16) {
            InterchangeMark()
                .frame(width: min(markSize, 120), height: min(markSize, 120))
                .padding(.bottom, 8)
            Text(access == .denied ? "Daybook nemá přístup ke kalendářům"
                                   : "Všechno, co máte v plánu, na jedné obrazovce")
                .font(.title2.bold())
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text(access == .denied ? Self.deniedText : Self.introText)
                .foregroundStyle(Theme.secondaryInk)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var action: some View {
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

    private static let introText: LocalizedStringKey = "Daybook ukazuje události ze všech kalendářů ve vašem zařízení, z iCloudu, Exchange i Googlu, a v měsíci nikdy žádnou neschová. Aby je mohl zobrazit a upravovat, potřebuje přístup ke kalendářům. Události zůstávají ve vašich účtech."

    #if os(macOS)
    private static let deniedText: LocalizedStringKey = "Povolte ho v Nastavení systému v části Soukromí a zabezpečení, Kalendáře. Pak se sem vraťte."
    #else
    private static let deniedText: LocalizedStringKey = "Povolte ho v Nastavení v části Aplikace, Daybook, Kalendáře. Pak se sem vraťte."
    #endif
}
