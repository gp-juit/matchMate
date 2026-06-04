import Combine
@preconcurrency import CoreData
import Foundation

final class MatchRepository {
    private let apiClient: APIClient
    private let persistenceController: PersistenceController
    private let networkMonitor: NetworkMonitor
    private var cancellables = Set<AnyCancellable>()
    private let syncCompletedSubject = PassthroughSubject<Void, Never>()

    var connectivity: AnyPublisher<Bool, Never> {
        networkMonitor.isOnline
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    var syncCompleted: AnyPublisher<Void, Never> {
        syncCompletedSubject.eraseToAnyPublisher()
    }

    init(apiClient: APIClient, persistenceController: PersistenceController, networkMonitor: NetworkMonitor) {
        self.apiClient = apiClient
        self.persistenceController = persistenceController
        self.networkMonitor = networkMonitor

        networkMonitor.isOnline
            .removeDuplicates()
            .filter { $0 }
            .sink { [weak self] _ in
                Task { await self?.syncPendingDecisions() }
            }
            .store(in: &cancellables)
    }

    @MainActor
    func loadProfiles() async throws -> [MatchProfile] {
        let cached = try fetchCachedProfiles()
        guard networkMonitor.isOnline.value else {
            return cached
        }

        do {
            let users = try await apiClient.fetchUsers()
            try upsert(users: users)
            await syncPendingDecisions()
            return try fetchCachedProfiles()
        } catch {
            if cached.isEmpty {
                throw error
            }
            return cached
        }
    }

    @MainActor
    func updateDecision(profileID: Int, decision: MatchDecision) throws -> [MatchProfile] {
        let context = persistenceController.container.viewContext
        let entity = try findEntity(id: profileID, in: context)
        entity.statusRaw = decision.rawValue
        entity.isSynced = false
        entity.lastUpdated = Date()
        try persistenceController.save(context: context)

        if networkMonitor.isOnline.value {
            Task { await syncPendingDecisions() }
        }

        return try fetchCachedProfiles()
    }

    @MainActor
    func cachedProfiles() throws -> [MatchProfile] {
        try fetchCachedProfiles()
    }

    @MainActor
    private func fetchCachedProfiles() throws -> [MatchProfile] {
        let request = MatchProfileEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \MatchProfileEntity.id, ascending: true)]
        return try persistenceController.container.viewContext.fetch(request).map(\.profile)
    }

    @MainActor
    private func upsert(users: [APIUser]) throws {
        let context = persistenceController.container.viewContext

        for user in users {
            let entity = try findOrCreateEntity(id: user.id, in: context)
            let existingDecision = entity.statusRaw ?? MatchDecision.pending.rawValue
            let existingSynced = entity.isSynced

            entity.name = user.name
            entity.age = Self.derivedAge(for: user.id)
            entity.address = "\(user.address.city), \(user.address.zipcode)"
            entity.email = user.email
            entity.phone = user.phone
            entity.imageURL = URL(string: "https://i.pravatar.cc/300?img=\(user.id + 20)")
            entity.statusRaw = existingDecision
            entity.isSynced = existingDecision == MatchDecision.pending.rawValue ? true : existingSynced
            entity.lastUpdated = entity.lastUpdated ?? Date()
        }

        try persistenceController.save(context: context)
    }

    private func syncPendingDecisions() async {
        do {
            let context = persistenceController.container.viewContext
            let pending: [MatchProfileEntity] = try await context.perform {
                let request = MatchProfileEntity.fetchRequest()
                request.predicate = NSPredicate(format: "isSynced == NO")
                return try context.fetch(request)
            }

            var didSyncAnyDecision = false
            for entity in pending {
                let profileID = Int(entity.id)
                let decision = MatchDecision(rawValue: entity.statusRaw ?? "") ?? .pending
                guard decision != .pending else { continue }

                try await apiClient.syncDecision(profileID: profileID, decision: decision)
                try await context.perform {
                    let request = MatchProfileEntity.fetchRequest()
                    request.predicate = NSPredicate(format: "id == %d", profileID)
                    request.fetchLimit = 1
                    guard let updatedEntity = try context.fetch(request).first else { return }
                    updatedEntity.isSynced = true
                    updatedEntity.lastUpdated = Date()
                    try context.save()
                }
                didSyncAnyDecision = true
            }

            if didSyncAnyDecision {
                syncCompletedSubject.send()
            }
        } catch {
            // Failed sync attempts stay marked unsynced and are retried when connectivity changes.
        }
    }

    private func findOrCreateEntity(id: Int, in context: NSManagedObjectContext) throws -> MatchProfileEntity {
        if let existing = try fetchEntity(id: id, in: context) {
            return existing
        }

        let entity = MatchProfileEntity(context: context)
        entity.id = Int64(id)
        entity.statusRaw = MatchDecision.pending.rawValue
        entity.isSynced = true
        return entity
    }

    private func findEntity(id: Int, in context: NSManagedObjectContext) throws -> MatchProfileEntity {
        if let entity = try fetchEntity(id: id, in: context) {
            return entity
        }

        throw CocoaError(.managedObjectValidation)
    }

    private func fetchEntity(id: Int, in context: NSManagedObjectContext) throws -> MatchProfileEntity? {
        let request = MatchProfileEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %d", id)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    private static func derivedAge(for id: Int) -> Int16 {
        Int16(27 + ((id * 7) % 28))
    }
}
