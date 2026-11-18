import DaybookCore
import SwiftUI

/// Settings: the appearance (system, light, dark) and the colour theme. The Mac shows it in its Settings
/// window (app menu, Settings…, ⌘,); iPhone pushes it in the calendars sheet, iPad opens it from the rail.
struct SettingsView: View {
    @AppStorage(AppearanceSettings.themeKey, store: AppearanceSettings.store) private var theme = ColorTheme.default
    @AppStorage(AppearanceSettings.appearanceKey, store: AppearanceSettings.store)
    private var appearance = AppearanceChoice.system

    var body: some View {
        Form {
            Section {
                Picker("Vzhled", selection: $appearance) {
                    Text("Podle systému").tag(AppearanceChoice.system)
                    Text("Světlý").tag(AppearanceChoice.light)
                    Text("Tmavý").tag(AppearanceChoice.dark)
                }
                .listRowBackground(Theme.ground)
            }
            Section {
                Picker("Barevné schéma", selection: $theme) {
                    ForEach(ColorTheme.allCases) { theme in
                        ThemeRow(theme: theme).tag(theme)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
                .listRowBackground(Theme.ground)
            } header: {
                Text("Barevné schéma")
            } footer: {
                Text("Kalendáře si nechávají své barvy. Na každém pozadí se upraví jen jejich jas, aby čáry zůstaly čitelné.")
            }
        }
        .formStyle(.grouped)
        .tint(Theme.controlInk)
        .scrollContentBackground(.hidden)
        .background(Theme.rail)
        .foregroundStyle(Theme.ink)
    }
}

/// A theme in the picker: its swatch and its name. VoiceOver reads the name; the swatch is decoration.
private struct ThemeRow: View {
    let theme: ColorTheme

    var body: some View {
        HStack(spacing: 12) {
            ThemeSwatch(theme: theme)
            ThemeName(theme: theme)
                .foregroundStyle(Theme.ink)
        }
        .frame(minHeight: 44)
        .contentShape(Rectangle())
    }
}

/// The theme's name: proper nouns as they are, the default's translated.
struct ThemeName: View {
    let theme: ColorTheme

    var body: some View {
        if let name = theme.properName {
            Text(verbatim: name)
        } else {
            Text("Noční schéma")
        }
    }
}

/// A small picture of a theme in the appearance on screen: the rail with three calendar rows, the ground
/// with today's interchange circle and three lines with their stations, framed by the theme's rule.
struct ThemeSwatch: View {
    let theme: ColorTheme
    @Environment(\.colorScheme) private var colorScheme
    @ScaledMetric(relativeTo: .body) private var height: CGFloat = 36

    var body: some View {
        let p = theme.palette(dark: colorScheme == .dark)
        let lines = [Palette.calendarPresets[0], Palette.calendarPresets[3], Palette.calendarPresets[5]].map { p.line($0) }
        Canvas { context, size in
            let w = size.width, h = size.height
            let railWidth = (w * 0.3).rounded()
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(p.ground)))
            context.fill(Path(CGRect(x: 0, y: 0, width: railWidth, height: h)), with: .color(Color(p.rail)))
            // Rail: a coloured checkbox and a name per calendar.
            let row = h / 4
            for (index, line) in lines.enumerated() {
                let y = row * (CGFloat(index) + 0.75)
                let box = CGRect(x: 3, y: y - 2, width: 4, height: 4)
                context.fill(Path(box), with: .color(Color(line)))
                context.fill(Path(CGRect(x: 9, y: y - 1, width: railWidth - 12, height: 2)),
                             with: .color(Color(p.secondaryInk(increased: false))))
            }
            // Ground: today's circle, then the lines running down with a station each.
            let todayRadius = h * 0.11
            let today = CGPoint(x: railWidth + 4 + todayRadius, y: 4 + todayRadius)
            context.fill(Path(ellipseIn: CGRect(x: today.x - todayRadius, y: today.y - todayRadius,
                                                width: todayRadius * 2, height: todayRadius * 2)),
                         with: .color(Color(p.ink)))
            let top = today.y + todayRadius + 3
            let span = w - railWidth - 8
            for (index, line) in lines.enumerated() {
                let x = railWidth + 6 + span * CGFloat(index) / 3
                context.fill(Path(CGRect(x: x - 1, y: top, width: 2, height: h - top)), with: .color(Color(line)))
                let stationY = top + (h - top) * [0.35, 0.6, 0.25][index]
                let station = Path(ellipseIn: CGRect(x: x - 2.5, y: stationY - 2.5, width: 5, height: 5))
                context.fill(station, with: .color(Color(p.station)))
                context.stroke(station, with: .color(Color(line)), lineWidth: 1)
                context.fill(Path(CGRect(x: x + 5, y: stationY - 1, width: span / 3 - 9, height: 2)),
                             with: .color(Color(p.ink)))
            }
        }
        .frame(width: height * 1.75, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(Theme.rule, lineWidth: 1)
        }
        .accessibilityHidden(true)
    }
}
