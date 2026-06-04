import CoreData
import Foundation

final class PersistenceController {
    static let shared = PersistenceController()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "MatchMate")

        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }

        container.loadPersistentStores { _, error in
            if let error {
                assertionFailure("Core Data store failed to load: \(error.localizedDescription)")
            }
        }

        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        container.viewContext.automaticallyMergesChangesFromParent = true
    }

    func save(context: NSManagedObjectContext? = nil) throws {
        let context = context ?? container.viewContext
        guard context.hasChanges else { return }
        try context.save()
    }
}

@objc(MatchProfileEntity)
final class MatchProfileEntity: NSManagedObject {
    @NSManaged var id: Int64
    @NSManaged var name: String?
    @NSManaged var age: Int16
    @NSManaged var address: String?
    @NSManaged var email: String?
    @NSManaged var phone: String?
    @NSManaged var imageURL: URL?
    @NSManaged var statusRaw: String?
    @NSManaged var isSynced: Bool
    @NSManaged var lastUpdated: Date?
}

extension MatchProfileEntity {
    @nonobjc
    static func fetchRequest() -> NSFetchRequest<MatchProfileEntity> {
        NSFetchRequest<MatchProfileEntity>(entityName: "MatchProfileEntity")
    }

    var profile: MatchProfile {
        MatchProfile(
            id: Int(id),
            name: name ?? "Unknown Member",
            age: Int(age),
            address: address ?? "Location unavailable",
            email: email ?? "",
            phone: phone ?? "",
            imageURL: imageURL,
            decision: MatchDecision(rawValue: statusRaw ?? MatchDecision.pending.rawValue) ?? .pending,
            isSynced: isSynced
        )
    }
}
