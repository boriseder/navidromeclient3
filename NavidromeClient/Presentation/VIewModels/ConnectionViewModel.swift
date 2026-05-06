//
//  ConnectionViewModel.swift
//  NavidromeClient
//
//  UPDATED: Swift 6 & iOS 17+ Modernization
//  - Migrated to @Observable
//  - Modern Concurrency (Task.sleep)
//

import Foundation
import Observation

@MainActor
@Observable
class ConnectionViewModel {
    var connectionStatusText: String = "Unknown"
    var isConnected: Bool = false
    var isTestingConnection: Bool = false
    
    // Test already-saved credentials (used in SettingsView)

    func testConnection(credentials: ServerCredentials?) async {
        guard let credentials = credentials else {
            isConnected = false
            connectionStatusText = "Not configured"
            return
        }
        
        isTestingConnection = true
        connectionStatusText = "Testing..."
        
        let service = ConnectionService(
            baseURL: credentials.baseURL,
            username: credentials.username,
            password: credentials.password
        )
        
        let result = await service.testConnection()
        
        switch result {
        case .success(let info):
            isConnected = true
            connectionStatusText = "Connected · \(info.type) \(info.serverVersion)"
        case .failure(let error):
            isConnected = false
            connectionStatusText = error.userMessage
        }
        
        isTestingConnection = false
    }
    
    // Test specific credentials before saving (used in ServerEditView)
    func testCredentials(baseURL: URL, username: String, password: String) async -> Bool {
        isTestingConnection = true
        connectionStatusText = "Testing..."
        
        let service = ConnectionService(
            baseURL: baseURL,
            username: username,
            password: password
        )
        
        let result = await service.testConnection()
        
        switch result {
        case .success(let info):
            isConnected = true
            connectionStatusText = "Connected · \(info.type) \(info.serverVersion)"
        case .failure(let error):
            isConnected = false
            connectionStatusText = error.userMessage
        }
        
        isTestingConnection = false
        return isConnected
    }
}
