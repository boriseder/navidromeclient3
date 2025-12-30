import Foundation

struct ServerCredentials: Codable, Sendable {
    let baseURL: URL
    let username: String
    let password: String
}
