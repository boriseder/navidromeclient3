import Foundation

// MARK: - Generic Subsonic Response Wrapper
struct SubsonicResponse<T: Codable & Sendable>: Codable, Sendable {
    let subsonicResponse: T
    
    private enum CodingKeys: String, CodingKey {
        case subsonicResponse = "subsonic-response"
    }
}

// FIX: Added Sendable conformance explicitly
struct PingInfo: Codable, Sendable {
    let status: String
    let version: String
    let type: String
    let serverVersion: String
    let openSubsonic: Bool
}

// MARK: - Error Response
struct SubsonicErrorDetail: Codable, Sendable {
    let code: Int
    let message: String
}

struct SubsonicResponseContent: Codable, Sendable {
    let status: String
    let version: String?
    let error: SubsonicErrorDetail?
}

struct EmptyResponse: Codable, Sendable {}
