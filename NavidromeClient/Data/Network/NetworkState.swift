//
//  NetworkState.swift
//  NavidromeClient
//
//  Created by Boris Eder on 30.09.25.
//
//  REFACTORED: Clear semantic naming
//  - hasInternet: Device has internet connectivity
//  - isServerReachable: Navidrome server responds to requests
//  - isFullyConnected: BOTH internet AND server available
//

import Foundation

struct NetworkState: Equatable {
    let hasInternet: Bool           // Device has internet connection
    let isServerReachable: Bool     // Navidrome server responds
    let isConfigured: Bool          // App has been configured with credentials
    let manualOfflineMode: Bool     // User explicitly chose offline mode
    
    /// True only when BOTH internet AND server are available
    var isFullyConnected: Bool {
        hasInternet && isServerReachable
    }
    
    var contentLoadingStrategy: ContentLoadingStrategy {
        // Priority 1: User's explicit choice
        if manualOfflineMode {
            return .offlineOnly(reason: .userChoice)
        }
        
        // Priority 2: Configuration required
        if !isConfigured {
            return .setupRequired
        }
        
        // Priority 3: Server reachability (if we have internet)
        // This check must come BEFORE the general internet check
        if hasInternet && !isServerReachable {
            return .offlineOnly(reason: .serverUnreachable)
        }
        
        // Priority 4: Internet connectivity
        if !hasInternet {
            return .offlineOnly(reason: .noNetwork)
        }
        
        // All conditions met: online!
        return .online
    }
    
    var debugDescription: String {
        """
        NetworkState:
        - Has Internet: \(hasInternet)
        - Server Reachable: \(isServerReachable)
        - Fully Connected: \(isFullyConnected)
        - Configured: \(isConfigured)
        - Manual Offline: \(manualOfflineMode)
        → Strategy: \(contentLoadingStrategy.displayName)
        """
    }
}
