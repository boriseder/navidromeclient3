//
//  ServerCredentials.swift
//  NavidromeClient3
//
//  Swift 6: Added Equatable conformance for .onChange support
//

import Foundation

struct ServerCredentials: Codable, Sendable, Equatable {
    let baseURL: URL
    let username: String
    let password: String
}
