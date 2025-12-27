//
//  ConnectionViewModel.swift
//  NavidromeClient
//
//  Swift 6: @Observable Migration
//

import Foundation
import SwiftUI
import Observation

@MainActor
@Observable
final class ConnectionViewModel {
    
    // MARK: - UI Form Bindings
    var scheme: String = "http"
    var host: String = ""
    var port: String = ""
    var username: String = ""
    var password: String = ""
    
    // MARK: - UI State
    var isConnected = false
    var isTestingConnection = false
    var connectionError: String?
    
    // MARK: - Dependencies
    // Note: ConnectionService is an Actor, but we store it as 'Any' or specific type if accessible.
    // Since ConnectionService is an Actor, we just hold it here for the lifecycle of the test.
    private var connectionService: ConnectionService?
    
    // MARK: - Initialization
    init() {
        loadSavedCredentials()
    }
    
    // MARK: - Actions
    
    func testConnection() async {
        guard let url = buildBasicURL() else {
            connectionError = "Invalid URL format"
            return
        }
        
        guard validateBasicInput() else { return }
        
        isTestingConnection = true
        connectionError = nil
        
        // Create Actor instance
        let service = ConnectionService(
            baseURL: url,
            username: username,
            password: password
        )
        self.connectionService = service
        
        // Await Actor result
        let result = await service.testConnection()
        
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
    
    func saveCredentials() async -> Bool {
        await testConnection()
        
        guard isConnected else { return false }
        
        guard let url = buildBasicURL() else { return false }
        // AppConfig handles the actual keychain storage
        AppConfig.shared.configure(baseURL: url, username: username, password: password)
        
        return true
    }
    
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
    
    // MARK: - Private Helpers
    
    private func buildBasicURL() -> URL? {
        let portString = port.isEmpty ? "" : ":\(port)"
        return URL(string: "\(scheme)://\(host)\(portString)")
    }
    
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
    
    private func loadSavedCredentials() {
        guard let creds = AppConfig.shared.getCredentials() else { return }
        
        scheme = creds.baseURL.scheme ?? "http"
        host = creds.baseURL.host ?? ""
        if let p = creds.baseURL.port {
            port = String(p)
        }
        username = creds.username
        password = creds.password
        
        // Assume valid if loaded, but don't auto-connect (let the AppInitializer handle real connection)
        isConnected = true
    }
    
    // MARK: - UI Computed Properties
    
    var connectionStatusText: String {
        if isTestingConnection { return "Testing connection..." }
        if isConnected { return "Connected" }
        return connectionError ?? "Not connected"
    }
    
    var connectionStatusColor: Color {
        if isTestingConnection { return .blue }
        if isConnected { return .green }
        return .red
    }
    
    var canTestConnection: Bool {
        return !host.isEmpty && !username.isEmpty && !password.isEmpty && !isTestingConnection
    }
}
