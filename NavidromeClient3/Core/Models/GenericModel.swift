//
//  GenericModel.swift
//  NavidromeClient3
//
//  Swift 6: Full Concurrency Support
//

import Foundation

// MARK: - Generic Subsonic Response Wrapper
nonisolated struct SubsonicResponse<T: Codable & Sendable>: Codable, Sendable {
    let subsonicResponse: T
    
    private enum CodingKeys: String, CodingKey {
        case subsonicResponse = "subsonic-response"
    }
}

nonisolated struct PingInfo: Codable, Sendable {
    let status: String
    let version: String
    let type: String
    let serverVersion: String?
    let openSubsonic: Bool?
}

// MARK: - Error Response
nonisolated struct SubsonicErrorDetail: Codable, Sendable {
    let code: Int
    let message: String
}

nonisolated struct SubsonicResponseContent: Codable, Sendable {
    let status: String
    let version: String?
    let error: SubsonicErrorDetail?
}

// MARK: - Empty Response
nonisolated struct EmptyResponse: Codable, Sendable {
    nonisolated init() {}
    nonisolated init(from decoder: Decoder) throws {}
    nonisolated func encode(to encoder: Encoder) throws {}
}
