import DaybookCore
import SwiftUI

/// Where the colour theme and the appearance are kept. UserDefaults: the choice belongs to this device,
/// like the system's own appearance setting, and is not synced.
enum AppearanceSettings {
    static let themeKey = "colorTheme"
    static let appearanceKey = "appearance"
    /// The app's defaults; in the debug demo its own suite, so captures never change the user's choice.
    /// Set once in `DaybookApp.init`, before any view reads it.
    nonisolated(unsafe) static var store: UserDefaults = .standard
}

extension AppearanceChoice {
    /// The scheme to force, or `nil` to follow the system.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

/// Applies the stored theme and appearance to a window or scene. Every window and the Settings scene
/// read the same stored values, so a change shows everywhere at once.
struct ThemedRoot: ViewModifier {
    @AppStorage(AppearanceSettings.themeKey, store: AppearanceSettings.store) private var theme = ColorTheme.default
    @AppStorage(AppearanceSettings.appearanceKey, store: AppearanceSettings.store)
    private var appearance = AppearanceChoice.system
    /// Debug demo only: `-demo-light` / `-demo-dark` win over the stored appearance.
    var forcedScheme: ColorScheme?

    func body(content: Content) -> some View {
        content
            .environment(\.colorTheme, theme)
            .preferredColorScheme(forcedScheme ?? appearance.colorScheme)
    }
}
