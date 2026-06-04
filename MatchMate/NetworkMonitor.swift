import Combine
import Network

final class NetworkMonitor {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "MatchMate.NetworkMonitor")

    let isOnline = CurrentValueSubject<Bool, Never>(true)

    init() {
        monitor.pathUpdateHandler = { [isOnline] path in
            isOnline.send(path.status == .satisfied)
        }
        monitor.start(queue: queue)
    }
}
