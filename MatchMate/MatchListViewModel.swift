import Combine
import Foundation

@MainActor
final class MatchListViewModel: ObservableObject {
    @Published private(set) var profiles: [MatchProfile] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    @Published private(set) var isOnline = true

    private let repository: MatchRepository
    private var cancellables = Set<AnyCancellable>()

    init(repository: MatchRepository) {
        self.repository = repository

        repository.connectivity
            .receive(on: DispatchQueue.main)
            .assign(to: &$isOnline)

        repository.syncCompleted
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.refreshFromCache()
            }
            .store(in: &cancellables)
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            profiles = try await repository.loadProfiles()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func setDecision(_ decision: MatchDecision, for profile: MatchProfile) {
        do {
            profiles = try repository.updateDecision(profileID: profile.id, decision: decision)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func refreshFromCache() {
        do {
            profiles = try repository.cachedProfiles()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
