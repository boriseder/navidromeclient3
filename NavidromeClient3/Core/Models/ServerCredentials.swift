//
//  ServerCredentials.swift
//  NavidromeClient
//
//  Swift 6: Full Concurrency Support
//

struct ServerCredentials: Codable, Sendable {
    let baseURL: URL
    let username: String
    let password: String
}
