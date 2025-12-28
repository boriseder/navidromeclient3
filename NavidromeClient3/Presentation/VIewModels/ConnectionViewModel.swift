//
//  ConnectionViewModel.swift
//  NavidromeClient3
//
//  Swift 6: Fixed AppConfig integration & Added Pre-check
//

import SwiftUI
import Observation

@MainActor
@Observable
final class ConnectionViewModel {
    
    // MARK: - Properties
    var serverUrl: String = ""
    var username: String = ""
    var password: String = ""
    
    var isLoading: Bool = false
    var errorMessage: String?
    
    var isValid: Bool {
        guard let _ = URL(string: serverUrl) else { return false }
        return !serverUrl.isEmpty && !username.isEmpty && !password.isEmpty
    }
    
    // MARK: - Actions
    
    func connect() async {
        guard isValid else {
            errorMessage = "Please enter a valid URL, username, and password."
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        // 1. Normalize Inputs
        let cleanUrl = serverUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        // Ensure scheme exists
        let finalUrlString = cleanUrl.lowercased().hasPrefix("http") ? cleanUrl : "https://\(cleanUrl)"
        
        guard let url = URL(string: finalUrlString) else {
            isLoading = false
            errorMessage = "Invalid URL format."
            return
        }
        
        let finalUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 2. Verify Connection BEFORE saving
        // We create a temporary service just to check credentials
        let tempService = ConnectionService(
            baseURL: url,
            username: finalUsername,
            password: password
        )
        
        let isSuccess = await tempService.ping()
        
        if isSuccess {
            // 3. Save Credentials
            // This triggers 'AppConfig' to notify 'AppInitializer', which switches the view.
            let credentials = ServerCredentials(
                baseURL: url,
                username: finalUsername,
                password: password
            )
            
            // FIX: Use saveCredentials instead of 'configure'
            AppConfig.shared.saveCredentials(credentials)
            
            // Success! The UI will update automatically via AppState
            isLoading = false
            
        } else {
            isLoading = false
            errorMessage = "Connection failed. Please check your URL and credentials."
        }
    }
}
