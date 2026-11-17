import DaybookCore
import Foundation
import OSLog
import SwiftData

/// Opens the category storage. Sync is on only when the build names a CloudKit container
/// (Info.plist `DaybookCloudKitContainer`, from the build setting `DAYBOOK_CLOUDKIT_CONTAINER`,
/// empty by default). The synced and the device-only store are separate files: when the synced one
/// opens, whatever the device-only one holds is moved into it, so nothing made before sync is lost.
/// If the synced store does not open, the device-only one is used and the sync line says so.
enum CategoryContainer {
    static let infoKey = "DaybookCloudKitContainer"
    private static let log = Logger(subsystem: "app.daybook.Daybook", category: "categories")

    static var schema: Schema { Schema([CategoryRecord.self, CategoryAssignmentRecord.self]) }

    /// The CloudKit container this build syncs with, or `nil` for device-only storage.
    static func cloudContainerID(in bundle: Bundle = .main) -> String? {
        guard let value = bundle.object(forInfoDictionaryKey: infoKey) as? String else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        // An unexpanded "$(…)" means the build setting is missing.
        guard !trimmed.isEmpty, !trimmed.hasPrefix("$(") else { return nil }
        return trimmed
    }

    /// The store the app uses: synced, device-only, or (when nothing can be opened) memory.
    static func makeStore(cloudContainerID: String? = cloudContainerID()) -> CategoryStore {
        if let cloudContainerID {
            do {
                let container = try ModelContainer(for: schema, configurations: cloudConfiguration(cloudContainerID))
                moveDeviceOnlyCategories(into: container)
                return SwiftDataCategoryStore(container: container, cloudContainerID: cloudContainerID)
            } catch {
                log.error("The synced category store did not open: \(error.localizedDescription, privacy: .public)")
            }
        }
        do {
            let container = try ModelContainer(for: schema, configurations: localConfiguration())
            return SwiftDataCategoryStore(container: container, cloudContainerID: nil,
                                          state: cloudContainerID == nil ? .localOnly : .iCloudUnavailable)
        } catch {
            log.error("The category store did not open: \(error.localizedDescription, privacy: .public)")
            return InMemoryCategoryStore(syncState: .notSaved)
        }
    }

    // MARK: Configurations

    private static var directory: URL {
        let url = URL.applicationSupportDirectory.appending(path: "Daybook", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private static var localURL: URL { directory.appending(path: "Categories-local.store") }

    private static func localConfiguration() -> ModelConfiguration {
        // `.none` explicitly: with iCloud entitlements SwiftData would otherwise sync this store too.
        ModelConfiguration("Categories-local", schema: schema, url: localURL, cloudKitDatabase: .none)
    }

    private static func cloudConfiguration(_ id: String) -> ModelConfiguration {
        ModelConfiguration("Categories-cloud", schema: schema, url: directory.appending(path: "Categories-cloud.store"),
                           cloudKitDatabase: .private(id))
    }

    // MARK: Moving device-only data in

    /// Moves every category and assignment of the device-only store into `container` and empties
    /// the device-only store.
    private static func moveDeviceOnlyCategories(into container: ModelContainer) {
        guard FileManager.default.fileExists(atPath: localURL.path(percentEncoded: false)),
              let local = try? ModelContainer(for: schema, configurations: localConfiguration()) else { return }
        do {
            let moved = try moveCategories(from: local, into: container)
            if moved.categories > 0 || moved.assignments > 0 {
                log.info("Moved \(moved.categories) categories and \(moved.assignments) assignments into the synced store")
            }
        } catch {
            log.error("Moving device-only categories failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Moves everything `source` holds into `target` and then empties `source`. Same ids and same
    /// assignments are not copied twice; a category whose name the target already has joins it
    /// (see `CategoryMerge`). The source is emptied only after the target saved. Returns what was inserted.
    @discardableResult
    static func moveCategories(from source: ModelContainer, into target: ModelContainer) throws -> (categories: Int, assignments: Int) {
        let from = ModelContext(source)
        let into = ModelContext(target)
        let localCategories = try from.fetch(FetchDescriptor<CategoryRecord>())
        let localAssignments = try from.fetch(FetchDescriptor<CategoryAssignmentRecord>())
        guard !localCategories.isEmpty || !localAssignments.isEmpty else { return (0, 0) }
        let plan = CategoryMerge.plan(
            local: localCategories.map(\.value), localAssignments: localAssignments.map(\.value),
            into: try into.fetch(FetchDescriptor<CategoryRecord>()).map(\.value),
            existingAssignments: try into.fetch(FetchDescriptor<CategoryAssignmentRecord>()).map(\.value))
        plan.categories.forEach { into.insert(CategoryRecord($0)) }
        plan.assignments.forEach { into.insert(CategoryAssignmentRecord($0)) }
        try into.save()
        // Only after the synced store has them.
        localCategories.forEach { from.delete($0) }
        localAssignments.forEach { from.delete($0) }
        try from.save()
        return (plan.categories.count, plan.assignments.count)
    }
}
