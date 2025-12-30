//
//  AppConfig.swift
//  NavidromeClient3
//
//  Swift 6: Fixed method names to match CredentialStore API
//

import Foundation
import Observation

@MainActor
@Observable
final class AppConfig {
    static let shared = AppConfig()
    
    // Use the shared instance to ensure we share state with other components
    private let credentialStore = CredentialStore.shared
    
    // Local cache of credentials
    private(set) var credentials: ServerCredentials?

    private init() {
        // CredentialStore loads automatically on init, so we just grab the property
        self.credentials = credentialStore.currentCredentials
        AppLogger.general.info("[AppConfig] Initialized")
    }
    
    // MARK: - Public API
    
    func getCredentials() -> ServerCredentials? {
        return credentials
    }
    
    func saveCredentials(_ creds: ServerCredentials) {
        // CredentialStore.save is non-throwing (handles errors internally/logs them)
        credentialStore.save(creds)
        self.credentials = creds
        
        // Notify observers
        NotificationCenter.default.post(name: .credentialsUpdated, object: creds)
    }
    
    func clearCredentials() {
        credentialStore.clear()
        self.credentials = nil
    }
}
