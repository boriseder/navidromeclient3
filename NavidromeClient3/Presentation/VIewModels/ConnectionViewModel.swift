//
//  ConnectionViewModel.swift
//  NavidromeClient3
//
//  Swift 6: Added Port Support
//

import SwiftUI
import Observation

enum ServerScheme: String, CaseIterable, Identifiable {
    case https = "https"
    case http = "http"
    var id: String { rawValue }
}

@MainActor
@Observable
final class ConnectionViewModel {
    
    // MARK: - Properties
    var scheme: ServerScheme = .http // Default to HTTP for local setups usually
    var host: String = ""
    var port: String = "" // New Port Property
    var username: String = ""
    var password: String = ""
    
    var isLoading: Bool = false
    var errorMessage: String?
    
    var isValid: Bool {
        // Port is optional (implies 80/443), but if entered, it must be valid
        return !host.isEmpty && !username.isEmpty && !password.isEmpty
    }
    
    // MARK: - Actions
    
    func connect() async {
        guard isValid else {
            errorMessage = "Please enter a valid Host, Username, and Password."
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        // 1. Normalize Inputs
        var cleanHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Handle if user pasted full URL into Host field
        if cleanHost.lowercased().hasPrefix("http://") {
            cleanHost = String(cleanHost.dropFirst(7))
            scheme = .http
        } else if cleanHost.lowercased().hasPrefix("https://") {
            cleanHost = String(cleanHost.dropFirst(8))
            scheme = .https
        }
        
        // Handle if user pasted "host:port" into Host field
        if cleanHost.contains(":") && !cleanHost.hasSuffix("]") { // Excluding IPv6 brackets
            let components = cleanHost.split(separator: ":")
            if components.count == 2 {
                cleanHost = String(components[0])
                if port.isEmpty {
                    port = String(components[1]).trimmingCharacters(in: .punctuationCharacters)
                }
            }
        }
        
        // Remove trailing slashes
        while cleanHost.hasSuffix("/") {
            cleanHost = String(cleanHost.dropLast())
        }
        
        let cleanPort = port.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 2. Construct Full URL
        var finalUrlString = "\(scheme.rawValue)://\(cleanHost)"
        if !cleanPort.isEmpty {
            finalUrlString += ":\(cleanPort)"
        }
        
        guard let url = URL(string: finalUrlString) else {
            isLoading = false
            errorMessage = "Invalid URL format."
            return
        }
        
        let finalUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 3. Verify Connection
        let tempService = ConnectionService(
            baseURL: url,
            username: finalUsername,
            password: password
        )
        
        let isSuccess = await tempService.ping()
        
        if isSuccess {
            // 4. Save Credentials
            let credentials = ServerCredentials(
                baseURL: url,
                username: finalUsername,
                password: password
            )
            
            AppConfig.shared.saveCredentials(credentials)
            
            // Success
            isLoading = false
            
        } else {
            isLoading = false
            errorMessage = "Connection failed. Check your Host, Port, and Network."
        }
    }
}
