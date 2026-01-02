//
//  ConnectionViewModel.swift
//  NavidromeClient
//
//  UPDATED: Swift 6 & iOS 17+ Modernization
//  - Migrated to @Observable
//

import Foundation
import Observation

@MainActor
@Observable
class ConnectionViewModel {
    var connectionStatusText: String = "Unknown"
    var isConnected: Bool = false
    var isTestingConnection: Bool = false
    
    // Dependencies injected usually via Environment or singleton access
    // Here we use NetworkMonitor singleton for status checks
    
    func testConnection() async {
        isTestingConnection = true
        connectionStatusText = "Testing..."
        
        // Simulate network delay or actual ping
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        if NetworkMonitor.shared.state.isFullyConnected {
            isConnected = true
            connectionStatusText = "Connected"
        } else {
            isConnected = false
            connectionStatusText = "Connection Failed"
        }
        
        isTestingConnection = false
    }
}
