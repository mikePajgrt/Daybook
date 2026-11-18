#if DEBUG
import CoreData
import Foundation
import OSLog
import SwiftData

/// Debug only, Development builds only: `-init-cloudkit-schema` creates the category store's record types (CD_CategoryRecord,
/// CD_CategoryAssignmentRecord, every field) in the CloudKit Development environment, then quits.
/// Apple's documented route for SwiftData: the same models as an NSManagedObjectModel, a Core Data
/// CloudKit container on a throwaway store, `initializeCloudKitSchema()`. That call writes placeholder
/// records with every field set and deletes them again, so no real category is created, and the app's
/// own stores are never opened. Afterwards deploy the schema to Production in the CloudKit console.
enum CloudKitSchemaInitializer {
    static let argument = "-init-cloudkit-schema"
    private static let log = Logger(subsystem: "app.trim.daybook", category: "categories")

    /// Runs and exits the process when the argument is present; returns otherwise.
    static func runIfRequested(_ arguments: [String] = ProcessInfo.processInfo.arguments) {
        guard arguments.contains(argument) else { return }
        do {
            let container = try run()
            report("CloudKit schema initialized in the Development environment of \(container).")
            exit(0)
        } catch {
            report("CloudKit schema initialization failed: \(error)", failed: true)
            exit(1)
        }
    }

    private static func run() throws -> String {
        guard let containerID = CategoryContainer.cloudContainerID() else {
            throw Failure("this build names no CloudKit container (DAYBOOK_CLOUDKIT_CONTAINER is empty)")
        }
        // The schema is made in Development and deployed to Production in the CloudKit console.
        guard CategoryContainer.cloudEnvironment() == "Development" else {
            throw Failure("this build is signed for the Production environment; initialize the schema with a "
                          + "Development build (scripts/build-mac-icloud.sh development)")
        }
        guard let model = NSManagedObjectModel.makeManagedObjectModel(for: [CategoryRecord.self,
                                                                             CategoryAssignmentRecord.self]) else {
            throw Failure("the SwiftData models did not convert to a Core Data model")
        }
        // A throwaway store in a temporary folder, never the app's Categories-cloud.store.
        let folder = FileManager.default.temporaryDirectory
            .appending(path: "DaybookSchema-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let description = NSPersistentStoreDescription(url: folder.appending(path: "Schema.store"))
        description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: containerID)
        description.shouldAddStoreAsynchronously = false

        let container = NSPersistentCloudKitContainer(name: "DaybookSchema", managedObjectModel: model)
        container.persistentStoreDescriptions = [description]
        var loadError: Error?
        container.loadPersistentStores { _, error in loadError = error }
        if let loadError { throw loadError }
        report("Store loaded for \(containerID); initializing the schema…")
        try container.initializeCloudKitSchema(options: [])
        return containerID
    }

    private static func report(_ message: String, failed: Bool = false) {
        if failed {
            log.error("\(message, privacy: .public)")
            FileHandle.standardError.write(Data((message + "\n").utf8))
        } else {
            log.info("\(message, privacy: .public)")
            print(message)
        }
    }

    private struct Failure: LocalizedError, CustomStringConvertible {
        let description: String
        init(_ description: String) { self.description = description }
        var errorDescription: String? { description }
    }
}
#endif
