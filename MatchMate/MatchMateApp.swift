import SwiftUI

@main
struct MatchMateApp: App {
    private let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            MatchListView(
                viewModel: MatchListViewModel(
                    repository: MatchRepository(
                        apiClient: APIClient(),
                        persistenceController: persistenceController,
                        networkMonitor: NetworkMonitor()
                    )
                )
            )
        }
    }
}
