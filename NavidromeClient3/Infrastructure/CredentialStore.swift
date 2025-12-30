//
//  CredentialStore.swift
//  NavidromeClient3
//
//  Swift 6: Fixed 'baseURL' property access
//

import Foundation
import Observation

@MainActor
@Observable
final class CredentialStore {
    static let shared = CredentialStore()
    
    // MARK: - Properties
    var currentCredentials: ServerCredentials?
    
    var hasCredentials: Bool {
        currentCredentials != nil
    }
    
    // MARK: - Init
    init() {
        // Load on startup
        self.currentCredentials = KeyChainHelper.shared.retrieveCredentials()
        if let creds = currentCredentials {
            AppLogger.general.info("Loaded credentials for server: \(creds.baseURL)")
        }
    }
    
    // MARK: - Public API
    
    func save(_ credentials: ServerCredentials) {
        self.currentCredentials = credentials
        KeyChainHelper.shared.saveCredentials(credentials)
        
        // Also update standard defaults for legacy/quick access
        UserDefaults.standard.set(credentials.baseURL.absoluteString, forKey: "serverUrl")
        UserDefaults.standard.set(credentials.username, forKey: "username")
        // Never save password in UserDefaults
    }
    
    func clear() {
        self.currentCredentials = nil
        KeyChainHelper.shared.deleteCredentials()
        
        UserDefaults.standard.removeObject(forKey: "serverUrl")
        UserDefaults.standard.removeObject(forKey: "username")
        UserDefaults.standard.removeObject(forKey: "password")
    }
    
    // MARK: - Helper Access
    var keychain: KeyChainHelper {
        KeyChainHelper.shared
    }
}
