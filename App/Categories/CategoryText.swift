import DaybookCore
import Foundation

/// Czech wording for categories, in one place so the sidebar, the sheets and VoiceOver agree.
enum CategoryText {
    static let uncategorized = "Bez kategorie"

    /// Accessible names of the offered symbols.
    private static let symbolNames: [String: String] = [
        "person.2": "Lidé", "brain.head.profile": "Hlava", "figure.and.child.holdinghands": "Rodič s dítětem",
        "airplane": "Letadlo", "heart": "Srdce", "briefcase": "Aktovka", "house": "Dům", "book": "Kniha",
        "graduationcap": "Promoční čepice", "dumbbell": "Činka", "fork.knife": "Příbor", "cart": "Nákupní vozík",
        "car": "Auto", "phone": "Telefon", "envelope": "Obálka", "laptopcomputer": "Notebook",
        "music.note": "Nota", "gift": "Dárek", "star": "Hvězda", "flag": "Vlajka", "leaf": "List",
        "pawprint": "Tlapka", "stethoscope": "Stetoskop", "banknote": "Bankovka", "hammer": "Kladivo",
        "paintbrush": "Štětec", "camera": "Fotoaparát", "gamecontroller": "Herní ovladač",
        "sun.max": "Slunce", "tag": "Štítek"
    ]

    static func symbolName(_ symbol: String) -> String { symbolNames[symbol] ?? "Symbol" }

    /// One plain sentence for where categories are kept.
    static func sync(_ state: CategorySyncState) -> String {
        switch state {
        case .localOnly: "Kategorie se ukládají jen v tomto zařízení."
        case .syncing: "Kategorie se synchronizují přes iCloud mezi vašimi zařízeními."
        case .iCloudUnavailable: "iCloud teď není dostupný. Kategorie se ukládají v tomto zařízení a synchronizují se, až bude."
        case .notSaved: "Kategorie se nedaří uložit. Změny vydrží jen do zavření aplikace."
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

    /// "Kategorii ztratí 3 události." for the delete confirmation.
    static func deleteMessage(_ count: Int) -> String {
        let events = count == 0 ? "Kategorie zatím není u žádné události."
            : "Kategorii ztratí \(EventText.plural(count, one: "1 událost", few: "\(count) události", many: "\(count) událostí"))."
        return "\(events) Události samotné zůstanou v kalendáři."
    }

    /// For VoiceOver: "kategorie Porady a Děti".
    static func spoken(_ categories: [Category]) -> String? {
        guard !categories.isEmpty else { return nil }
        let names = categories.map(\.name)
        let joined = names.count == 1 ? names[0]
            : names.dropLast().joined(separator: ", ") + " a " + (names.last ?? "")
        return "\(names.count == 1 ? "kategorie" : "kategorie") \(joined)"
    }

    static func problem(_ problem: CategoryNameProblem) -> String {
        switch problem {
        case .empty: "Zadejte název kategorie."
        case .duplicate: "Kategorie s tímto názvem už existuje. Zvolte jiný název."
        }
    }

    static func message(for error: Error) -> String {
        guard let error = error as? CategoryStoreError else { return error.localizedDescription }
        switch error {
        case .categoryNotFound: return "Kategorie už neexistuje. Nejspíš ji mezitím smazalo jiné zařízení."
        case .invalidName(let problems): return problems.map(problem).joined(separator: " ")
        case .invalidSymbol: return "Vyberte symbol kategorie."
        case .system(let text): return text
        }
    }
}
