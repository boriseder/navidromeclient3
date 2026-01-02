//
//  NetworkState.swift
//  NavidromeClient
//
//  UPDATED: Swift 6 Compliance
//  - Mutable vars for NetworkMonitor
//

import Foundation

struct NetworkState: Equatable, Sendable {
    enum ConnectionType: String, Sendable {
        case wifi, cellular, other, none
        
        var displayName: String {
            switch self {
            case .wifi: return "WiFi"
            case .cellular: return "Cellular"
            case .other: return "Other"
            case .none: return "None"
            }
        }
    }
    
    enum Reachability: String, Sendable {
        case reachable, unreachable, unknown
    }
    
    // Mutable properties (Must be var so NetworkMonitor can update them)
    var isConnected: Bool
    var isConfigured: Bool
    var connectionType: ConnectionType
    var serverReachability: Reachability
    var contentLoadingStrategy: ContentLoadingStrategy
    
    static let initial = NetworkState(
        isConnected: false,
        isConfigured: false,
        connectionType: .none,
        serverReachability: .unknown,
        contentLoadingStrategy: .setupRequired
    )
    
    // Helper
    var isFullyConnected: Bool {
        return isConnected && serverReachability == .reachable
    }
}
