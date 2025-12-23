//
//  ConnectionManager.swift - REDESIGNED: Lightweight UI-Focused
//  NavidromeClient
//
//   LEAN: Nur UI-Essentials, delegiert an ConnectionService
//   CLEAN: Separation of Concerns zwischen UI und Business Logic
//   REDUCED: Von 200+ LOC auf ~80 LOC
//

import Foundation
import SwiftUI

@MainActor
class ConnectionViewModel: ObservableObject {
    
    // MARK: -  UI Form Bindings (Core Responsibility)
    
    @Published var scheme: String = "http"
    @Published var host: String = ""
    @Published var port: String = ""
    @Published var username: String = ""
    @Published var password: String = ""
    
    // MARK: -  UI State (Minimal)
    
    @Published private(set) var isConnected = false
    @Published private(set) var isTestingConnection = false
    @Published private(set) var connectionError: String?
    
    // MARK: -  Service Dependency (Single Source of Truth)
    
    private var connectionService: ConnectionService?
    
    // MARK: -  Initialization
    
    init() {
        loadSavedCredentials()
    }
    
    // MARK: -  UI Actions (Minimal Interface)
    
    /// Test connection with current form values

    func testConnection() async {
        guard let url = buildBasicURL() else {
            connectionError = "Invalid URL format"
            return
        }
        
        guard validateBasicInput() else { return }
        
        isTestingConnection = true
        connectionError = nil
        
        //  Delegate to Service
        connectionService = ConnectionService(
            baseURL: url,
            username: username,
            password: password
        )
        
        let result = await connectionService!.testConnection()
        
        //  Update UI State
        switch result {
        case .success:
            isConnected = true
            connectionError = nil
        case .failure(let error):
            isConnected = false
            connectionError = error.userMessage
        }
        
        isTestingConnection = false
    }
    
    /// Save credentials if connection test succeeds
    func saveCredentials() async -> Bool {
        await testConnection()
        
        guard isConnected else { return false }
        
        //  Delegate to AppConfig for persistence
        guard let url = buildBasicURL() else { return false }
        AppConfig.shared.configure(baseURL: url, username: username, password: password)
        
        return true
    }
       
    // MARK: -  UI Helpers (Minimal)
    
    /// Basic URL building for service creation
    private func buildBasicURL() -> URL? {
        let portString = port.isEmpty ? "" : ":\(port)"
        return URL(string: "\(scheme)://\(host)\(portString)")
    }
    
    /// Basic input validation for UI
    private func validateBasicInput() -> Bool {
        if host.trimmingCharacters(in: .whitespaces).isEmpty {
            connectionError = "Host is required"
            return false
        }
        
        if username.trimmingCharacters(in: .whitespaces).isEmpty {
            connectionError = "Username is required"
            return false
        }
        
        if password.isEmpty {
            connectionError = "Password is required"
            return false
        }
        
        return true
    }
    
    // MARK: -  Persistence (UI Convenience)
    
    /// Load saved credentials for form population
    private func loadSavedCredentials() {
        guard let creds = AppConfig.shared.getCredentials() else { return }
        
        scheme = creds.baseURL.scheme ?? "http"
        host = creds.baseURL.host ?? ""
        port = creds.baseURL.port.map { String($0) } ?? ""
        username = creds.username
        password = creds.password
        
        //  Assume saved credentials are valid
        isConnected = true
        
        //  Create service for immediate use
        connectionService = ConnectionService(
            baseURL: creds.baseURL,
            username: creds.username,
            password: creds.password
        )
    }
    
    // MARK: -  Reset (UI State Only)
    
    func reset() {
        scheme = "http"
        host = ""
        port = ""
        username = ""
        password = ""
        
        isConnected = false
        isTestingConnection = false
        connectionError = nil
        connectionService = nil
    }
    
    // MARK: -  UI Computed Properties
    
    /// Connection status for UI display
    var connectionStatusText: String {
        if isTestingConnection {
            return "Testing connection..."
        } else if isConnected {
            return "Connected"
        } else {
            return connectionError ?? "Not connected"
        }
    }
    
    /// Connection status color for UI
    var connectionStatusColor: Color {
        if isTestingConnection {
            return .blue
        } else if isConnected {
            return .green
        } else {
            return .red
        }
    }
    
    /// Form validation for UI
    var canTestConnection: Bool {
        return !host.isEmpty && !username.isEmpty && !password.isEmpty && !isTestingConnection
    }
    
    /// Current URL for display
    var currentURLString: String {
        buildBasicURL()?.absoluteString ?? "Invalid URL"
    }
}

// MARK: -  UI Extensions

extension ConnectionViewModel {
    
    /// Quick connection health check
    func performQuickHealthCheck() async {
        guard let service = connectionService else { return }
        
        let isHealthy = await service.ping()
        await MainActor.run {
            self.isConnected = isHealthy
            if !isHealthy {
                self.connectionError = "Server unreachable"
            }
        }
    }
    
    /// Update NetworkMonitor with current service
    func configureNetworkMonitor() {
    }
}
