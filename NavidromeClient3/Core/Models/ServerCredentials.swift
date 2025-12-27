//
//  ServerCredentials.swift
//  NavidromeClient3
//
//  Swift 6: Credentials Model
//

import Foundation

struct ServerCredentials: Codable, Sendable {
    let baseURL: URL
    let username: String
    let password: String // Stored securely, this model might be used for transport or config
}
