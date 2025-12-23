import Foundation

struct ServerCredentials: Codable {
    let baseURL: URL
    let username: String
    let password: String
}
