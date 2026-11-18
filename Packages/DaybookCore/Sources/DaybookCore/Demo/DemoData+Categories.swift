// Demo data exists in debug builds only: release builds carry no synthetic calendars.
#if DEBUG
import Foundation

/// Demo categories and their assignments. Synthetic, deterministic.
extension DemoData {
    public static let categories: [Category] = [
        Category(id: uuid("00000000-0000-4000-8000-000000000001"), name: "Porady", symbol: "person.2", order: 0),
        Category(id: uuid("00000000-0000-4000-8000-000000000002"), name: "Soustředěná práce",
                 symbol: "scope", order: 1),
        Category(id: uuid("00000000-0000-4000-8000-000000000003"), name: "Děti",
                 symbol: "figure.and.child.holdinghands", order: 2),
        Category(id: uuid("00000000-0000-4000-8000-000000000004"), name: "Cestování", symbol: "airplane", order: 3),
        Category(id: uuid("00000000-0000-4000-8000-000000000005"), name: "Zdraví", symbol: "heart", order: 4)
    ]

    public static var meetingsCategoryID: UUID { categories[0].id }
    public static var focusCategoryID: UUID { categories[1].id }
    public static var childrenCategoryID: UUID { categories[2].id }

    /// A read-only calendar's event that carries a category (on the month's 17th).
    public static let readOnlyCategorizedEventID = "demo-outage"

    private static func uuid(_ text: String) -> UUID { UUID(uuidString: text) ?? UUID() }

    /// Which categories events of a title carry, on the whole event (series scope).
    private static let byTitle: [(title: String, category: Int)] = [
        ("Standup platformy", 0), ("1:1 s Tomášem", 0), ("Sprint planning", 0), ("Retro", 0),
        ("Design review", 0), ("Review roadmapy Q1", 0), ("All-hands", 0), ("Call s dodavatelem", 0),
        ("Architektura sync", 1), ("Rozpočet 2027", 1),
        ("Ema: plavání", 2), ("Kuba: florbal", 2), ("Kino s dětmi", 2), ("Třídní schůzky", 2),
        ("Očkování Ema", 2), ("Hlídání Emy", 2),
        ("Lisabon", 3), ("WebExpo", 3),
        ("Běh Stromovka", 4), ("Zubař", 4), ("Fyzio", 4), ("Očkování Ema", 4), ("Squash", 4)
    ]

    /// Assignments for the demo month: by title, "Návrh API" with two categories, the weekly series
    /// with Porady on the whole series and Soustředěná práce on its third occurrence only, and a
    /// read-only event with a category. Events not listed have none.
    public static func categoryAssignments(month: Date, calendar: Calendar) -> [CategoryAssignment] {
        var result: [CategoryAssignment] = []
        func add(_ category: Int, _ externalID: String, at start: Date? = nil) {
            result.append(CategoryAssignment(categoryID: categories[category].id, externalID: externalID,
                                             occurrenceStart: start))
        }
        for event in events(month: month, radius: monthRadius, calendar: calendar) {
            for pick in byTitle where pick.title == event.title { add(pick.category, event.key.externalID) }
        }
        add(0, detailedEventID)
        add(1, detailedEventID)
        add(1, readOnlyCategorizedEventID)
        add(0, seriesID)
        if let monthStart = calendar.dateInterval(of: .month, for: month)?.start {
            let mondays = (0..<31).compactMap { calendar.date(byAdding: .day, value: $0, to: monthStart) }
                .filter { calendar.component(.weekday, from: $0) == 2 }
            if mondays.count > 2, let start = calendar.date(bySettingHour: 8, minute: 30, second: 0, of: mondays[2]) {
                add(1, seriesID, at: start)
            }
        }
        return result
    }

    public static func categoryStore(month: Date, calendar: Calendar,
                                     syncState: CategorySyncState = .localOnly) -> InMemoryCategoryStore {
        InMemoryCategoryStore(categories: categories, assignments: categoryAssignments(month: month, calendar: calendar),
                              syncState: syncState)
    }
}
#endif
