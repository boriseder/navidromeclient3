//
//  ConnectionManager.swift
//  NavidromeClient
//
//  UPDATED: Swift 6 Concurrency Compliance
//  - MainActor isolation
//

import Foundation
import SwiftUI

@MainActor
class ConnectionViewModel: ObservableObject {
    
    // MARK: -  UI Form Bindings
    
    @Published var scheme: String = "http"
    @Published var host: String = ""
    @Published var port: String = ""
    @Published var username: String = ""
    @Published var password: String = ""
    
    // MARK: -  UI State
    
    @Published private(set) var isConnected = false
    @Published private(set) var isTestingConnection = false
    @Published private(set) var connectionError: String?
    
    // MARK: -  Dependencies
    
    private var connectionService: ConnectionService?
    
    // MARK: -  Initialization
    
    init() {
        loadSavedCredentials()
    }
    
    // MARK: -  UI Actions
    
    func testConnection() async {
        guard let url = buildBasicURL() else {
            connectionError = "Invalid URL format"
            return
        }
        
        guard validateBasicInput() else { return }
        
        isTestingConnection = true
        connectionError = nil
        
        // Create temporary service for testing
        let service = ConnectionService(
            baseURL: url,
            username: username,
            password: password
        )
        self.connectionService = service
        
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
        AppConfig.shared.configure(baseURL: url, username: username, password: password)
        
        return true
    }
       
    // MARK: -  Helpers
    
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
        port = creds.baseURL.port.map { String($0) } ?? ""
        username = creds.username
        password = creds.password
        
        // Assume valid if loaded
        isConnected = true
        
        connectionService = ConnectionService(
            baseURL: creds.baseURL,
            username: creds.username,
            password: creds.password
        )
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
    
    // MARK: -  Computed Properties
    
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
