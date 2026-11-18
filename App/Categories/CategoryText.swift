import DaybookCore
import Foundation

/// Czech wording for categories, in one place so the sidebar, the sheets and VoiceOver agree.
enum CategoryText {
    static var uncategorized: String { String(localized: "Bez kategorie") }

    /// Accessible names of the offered symbols.
    private static var symbolNames: [String: String] {
        [
            "person.2": String(localized: "Lidé"),
            "brain.head.profile": String(localized: "Hlava"),
            "figure.and.child.holdinghands": String(localized: "Rodič s dítětem"),
            "airplane": String(localized: "Letadlo"),
            "heart": String(localized: "Srdce"),
            "briefcase": String(localized: "Aktovka"),
            "house": String(localized: "Dům"),
            "book": String(localized: "Kniha"),
            "graduationcap": String(localized: "Promoční čepice"),
            "dumbbell": String(localized: "Činka"),
            "fork.knife": String(localized: "Příbor"),
            "cart": String(localized: "Nákupní vozík"),
            "car": String(localized: "Auto"),
            "phone": String(localized: "Telefon"),
            "envelope": String(localized: "Obálka"),
            "laptopcomputer": String(localized: "Notebook"),
            "music.note": String(localized: "Nota"),
            "gift": String(localized: "Dárek"),
            "star": String(localized: "Hvězda"),
            "flag": String(localized: "Vlajka"),
            "leaf": String(localized: "List"),
            "pawprint": String(localized: "Tlapka"),
            "stethoscope": String(localized: "Stetoskop"),
            "banknote": String(localized: "Bankovka"),
            "hammer": String(localized: "Kladivo"),
            "paintbrush": String(localized: "Štětec"),
            "camera": String(localized: "Fotoaparát"),
            "gamecontroller": String(localized: "Herní ovladač"),
            "sun.max": String(localized: "Slunce"),
            "tag": String(localized: "Štítek")
        ]
    }

    static func symbolName(_ symbol: String) -> String { symbolNames[symbol] ?? String(localized: "Symbol") }

    /// One plain sentence for where categories are kept.
    static func sync(_ state: CategorySyncState) -> String {
        switch state {
        case .localOnly: String(localized: "Kategorie se ukládají jen v tomto zařízení.")
        case .syncing: String(localized: "Kategorie se synchronizují přes iCloud mezi vašimi zařízeními.")
        case .iCloudUnavailable: String(localized: "iCloud teď není dostupný. Kategorie se ukládají v tomto zařízení a synchronizují se, až bude.")
        case .notSaved: String(localized: "Kategorie se nedaří uložit. Změny vydrží jen do zavření aplikace.")
        }
    }

    static func syncSymbol(_ state: CategorySyncState) -> String {
        switch state {
        case .localOnly: "internaldrive"
        case .syncing: "icloud"
        case .iCloudUnavailable: "icloud.slash"
        case .notSaved: "exclamationmark.triangle"
        }
    }

    /// For the delete confirmation. The count is of assignments: a whole series counts once, as one
    /// event does, so the sentence names both.
    static func deleteMessage(_ count: Int) -> String {
        count == 0 ? String(localized: "Kategorie zatím není u žádné události. Události samotné zůstanou v kalendáři.")
            : String(localized: "Kategorie je přiřazená k \(count) událostem a sériím. Odebere se z nich, události samotné zůstanou v kalendáři.")
    }

    /// For VoiceOver: "kategorie Porady a Děti".
    static func spoken(_ categories: [Category]) -> String? {
        guard !categories.isEmpty else { return nil }
        let names = categories.map(\.name).formatted(.list(type: .and))
        return String(localized: "kategorie \(names)")
    }

    static func problem(_ problem: CategoryNameProblem) -> String {
        switch problem {
        case .empty: String(localized: "Zadejte název kategorie.")
        case .duplicate: String(localized: "Kategorie s tímto názvem už existuje. Zvolte jiný název.")
        }
    }

    static func message(for error: Error) -> String {
        guard let error = error as? CategoryStoreError else { return error.localizedDescription }
        switch error {
        case .categoryNotFound: return String(localized: "Kategorie už neexistuje. Nejspíš ji mezitím smazalo jiné zařízení.")
        case .invalidName(let problems): return problems.map(problem).joined(separator: " ")
        case .invalidSymbol: return String(localized: "Vyberte symbol kategorie.")
        case .system(let text): return text
        }
    }
}
