import Foundation

enum MatchDecision: String, Codable {
    case pending
    case accepted
    case declined

    var title: String {
        switch self {
        case .pending:
            return "Pending"
        case .accepted:
            return "Member Accepted"
        case .declined:
            return "Member Declined"
        }
    }
}

struct MatchProfile: Identifiable, Equatable {
    let id: Int
    var name: String
    var age: Int
    var address: String
    var email: String
    var phone: String
    var imageURL: URL?
    var decision: MatchDecision
    var isSynced: Bool
}

struct APIUser: Decodable {
    struct Address: Decodable {
        let city: String
        let zipcode: String
    }

    let id: Int
    let name: String
    let email: String
    let phone: String
    let address: Address
}
