//
//  AppConfig.swift
//  NavidromeClient3
//
//  Swift 6: Fixed method delegation to CredentialStore
//

import Foundation
import Observation

@MainActor
@Observable
final class AppConfig {
    static let shared = AppConfig()
    
    private let credentialStore = CredentialStore()
    
    // Private state is fine; changes to it trigger updates if exposed via computed properties
    private var credentials: ServerCredentials?

    private init() {
        // FIX: Use correct method name from CredentialStore
        self.credentials = credentialStore.loadCredentials()
        AppLogger.general.info("[AppConfig] Initialized")
    }
    
    // MARK: - Public API
    
    func getCredentials() -> ServerCredentials? {
        return credentials
    }
    
    func saveCredentials(_ creds: ServerCredentials) {
        do {
            // FIX: Use correct method name
            try credentialStore.saveCredentials(creds)
            self.credentials = creds
            
            // Notify observers (if any logic depends on this notification)
            NotificationCenter.default.post(name: .credentialsUpdated, object: creds)
        } catch {
            AppLogger.general.error("Failed to save credentials: \(error)")
        }
    }
    
    func clearCredentials() {
        // FIX: Use correct method name
        credentialStore.clearCredentials()
        self.credentials = nil
    }
}
