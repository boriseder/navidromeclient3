//
//  NetworkState.swift
//  NavidromeClient
//
//  UPDATED: Swift 6 Compliance
//  - FIXED: Initial state now uses .initializing instead of .setupRequired
//

import Foundation

struct AppNetworkState: Equatable, Sendable {
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
    
    // FIXED: Use .initializing during startup instead of .setupRequired
    static let initial = AppNetworkState(
        isConnected: false,
        isConfigured: false,
        connectionType: .none,
        serverReachability: .unknown,
        contentLoadingStrategy: .initializing
    )
    
    // Helper
    var isFullyConnected: Bool {
        return isConnected && serverReachability == .reachable
    }
}
