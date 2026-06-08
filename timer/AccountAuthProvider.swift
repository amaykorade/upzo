import Foundation

enum AccountAuthProvider: String, Codable, CaseIterable {
    case none
    case apple
    case google

    var displayName: String {
        switch self {
        case .none: "Not signed in"
        case .apple: "Apple"
        case .google: "Google"
        }
    }
}
