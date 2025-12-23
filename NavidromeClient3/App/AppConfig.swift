//
//  AppConfig.swift
//  NavidromeClient
//
//  Pure credential storage and retrieval
//  No state management, no manager coordination
//

import Foundation

@MainActor
final class AppConfig: ObservableObject {
    static let shared = AppConfig()
    
    private let credentialStore = CredentialStore()
    private var credentials: ServerCredentials?

    // MARK: - Initialization
    
    private init() {
        loadCredentials()
        AppLogger.general.info("[AppConfig] Initialized")
    }
        
    // MARK: - Configuration
    
    func configure(baseURL: URL, username: String, password: String) {
        AppLogger.general.info("[AppConfig] Configure called for user: \(username)")
        
        let newCredentials = ServerCredentials(
            baseURL: baseURL,
            username: username,
            password: password
        )
        
        do {
            try credentialStore.saveCredentials(newCredentials)
            self.credentials = newCredentials
            AppLogger.general.info("[AppConfig] Credentials saved successfully")
            
            // Notify that new credentials are available
            NotificationCenter.default.post(
                name: .credentialsUpdated,
                object: newCredentials
            )
        } catch {
            AppLogger.general.error("[AppConfig] Failed to save credentials: \(error)")
        }
    }
    
    // MARK: - Factory Reset (Credential Clearing Only)

    func clearCredentials() {
        AppLogger.general.info("[AppConfig] Clearing credentials")
        
        credentialStore.clearCredentials()
        credentials = nil
        
        // Clear caches
        PersistentImageCache.shared.clearCache()
        AlbumMetadataCache.shared.clearCache()
        
        AppLogger.general.info("[AppConfig] Credentials cleared")
    }
            
    // MARK: - Credentials Access
    
    func getCredentials() -> ServerCredentials? {
        return credentials
    }
    
    func hasCredentials() -> Bool {
        return credentials != nil
    }
    
    private func loadCredentials() {
        AppLogger.general.info("[AppConfig] Loading credentials from CredentialStore...")
        
        guard let creds = credentialStore.loadCredentials() else {
            AppLogger.general.info("[AppConfig] No credentials found")
            return
        }
        
        self.credentials = creds
        AppLogger.general.info("[AppConfig] Credentials loaded: \(creds.username)")
    }
    
    // MARK: - Password Management
    
    func needsPassword() -> Bool {
        return credentials != nil && (credentials?.password.isEmpty ?? true)
    }
    
    func restorePassword(_ password: String) -> Bool {
        AppLogger.general.info("[AppConfig] Attempting to restore password...")
        
        guard let creds = credentials else {
            AppLogger.general.error("[AppConfig] Cannot restore password - no credentials")
            return false
        }
        
        guard credentialStore.verifyPassword(password) else {
            AppLogger.general.error("[AppConfig] Password verification failed")
            return false
        }
        
        self.credentials = ServerCredentials(
            baseURL: creds.baseURL,
            username: creds.username,
            password: password
        )
        
        if let sessionData = password.data(using: .utf8) {
            _ = KeychainHelper.shared.save(sessionData, forKey: "navidrome_password_session")
        }
        
        AppLogger.general.info("[AppConfig] Password restored successfully")
        return true
    }
}
