import Foundation

enum APIError: LocalizedError {
    case invalidResponse
    case serverError(Int)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "The server returned an invalid response."
        case .serverError(let statusCode):
            return "The server returned status code \(statusCode)."
        }
    }
}

final class APIClient {
    private let baseURL = URL(string: "https://jsonplaceholder.typicode.com")!
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchUsers() async throws -> [APIUser] {
        let url = baseURL.appending(path: "users")
        let (data, response) = try await session.data(from: url)
        try validate(response)
        return try JSONDecoder().decode([APIUser].self, from: data)
    }

    func syncDecision(profileID: Int, decision: MatchDecision) async throws {
        let url = baseURL.appending(path: "users/\(profileID)")
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["decision": decision.rawValue])

        let (_, response) = try await session.data(for: request)
        try validate(response)
    }

    private func validate(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw APIError.serverError(httpResponse.statusCode)
        }
    }
}
