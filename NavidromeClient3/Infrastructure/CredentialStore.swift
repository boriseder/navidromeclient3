//
//  CredentialStore.swift
//  NavidromeClient
//
//  Single source of truth for credential persistence.
//  Pure infrastructure layer - no business logic.
//

import Foundation
import CryptoKit

@MainActor
final class CredentialStore {
    
    // MARK: - Error Handling
    
    enum CredentialError: Error, LocalizedError {
        case loadFailed
        case saveFailed
        case invalidData
        case keychainError(underlying: Error)
        
        var errorDescription: String? {
            switch self {
            case .loadFailed:
                return "Failed to load credentials from secure storage"
            case .saveFailed:
                return "Failed to save credentials to secure storage"
            case .invalidData:
                return "Credential data is invalid or corrupted"
            case .keychainError(let error):
                return "Keychain error: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Private Constants
    
    private enum KeychainKey {
        static let credentials = "navidrome_credentials"
        static let passwordHash = "navidrome_password_hash"
        static let sessionPassword = "navidrome_password_session"
    }
    
    // MARK: - Public Interface
    
    /// Load stored credentials with session password
    /// Returns nil if no credentials stored or if corrupted
    func loadCredentials() -> ServerCredentials? {
        AppLogger.general.info("[CredentialStore] Loading credentials...")
        
        guard let data = KeychainHelper.shared.load(forKey: KeychainKey.credentials) else {
            AppLogger.general.info("[CredentialStore] No credentials data in keychain")
            return nil
        }
        
        guard let creds = try? JSONDecoder().decode(ServerCredentials.self, from: data) else {
            AppLogger.general.error("[CredentialStore] Failed to decode credentials")
            return nil
        }
        
        AppLogger.general.info("[CredentialStore] Base credentials decoded: \(creds.baseURL.absoluteString), user: \(creds.username)")
        
        var sessionPassword = ""
        if let pwdData = KeychainHelper.shared.load(forKey: KeychainKey.sessionPassword),
           let pwd = String(data: pwdData, encoding: .utf8) {
            sessionPassword = pwd
            AppLogger.general.info("[CredentialStore] Session password loaded, length: \(sessionPassword.count)")
        } else {
            AppLogger.general.warn("[CredentialStore] No session password found in keychain")
        }
        
        let credentials = ServerCredentials(
            baseURL: creds.baseURL,
            username: creds.username,
            password: sessionPassword
        )
        
        AppLogger.general.info("[CredentialStore] Credentials loaded successfully")
        return credentials
    }
    
    /// Save credentials securely
    /// Stores credentials without password + password hash + session password separately
    func saveCredentials(_ credentials: ServerCredentials) throws {
        AppLogger.general.info("[CredentialStore] Saving credentials for: \(credentials.username)")
        
        guard validateCredentials(credentials) else {
            AppLogger.general.error("[CredentialStore] Validation failed")
            throw CredentialError.invalidData
        }
        
        // 1. Store base credentials (without password)
        let credsWithoutPassword = ServerCredentials(
            baseURL: credentials.baseURL,
            username: credentials.username,
            password: ""
        )
        
        guard let data = try? JSONEncoder().encode(credsWithoutPassword),
              KeychainHelper.shared.save(data, forKey: KeychainKey.credentials) else {
            AppLogger.general.error("[CredentialStore] Failed to save base credentials")
            throw CredentialError.saveFailed
        }
        
        AppLogger.general.info("[CredentialStore] Base credentials saved")
        
        // 2. Store password hash (for verification)
        let hashedPassword = hashPassword(credentials.password)
        guard let hashData = hashedPassword.data(using: .utf8),
              KeychainHelper.shared.save(hashData, forKey: KeychainKey.passwordHash) else {
            AppLogger.general.error("[CredentialStore] Failed to save password hash")
            throw CredentialError.saveFailed
        }
        
        AppLogger.general.info("[CredentialStore] Password hash saved")
        
        // 3. Store session password (actual password for API calls)
        guard let sessionData = credentials.password.data(using: .utf8),
              KeychainHelper.shared.save(sessionData, forKey: KeychainKey.sessionPassword) else {
            AppLogger.general.error("[CredentialStore] Failed to save session password")
            throw CredentialError.saveFailed
        }
        
        AppLogger.general.info("[CredentialStore] Session password saved, length: \(credentials.password.count)")
        AppLogger.general.info("[CredentialStore] All credentials saved successfully")
    }
    
    /// Verify password against stored hash
    func verifyPassword(_ password: String) -> Bool {
        guard let hashData = KeychainHelper.shared.load(forKey: KeychainKey.passwordHash),
              let storedHash = String(data: hashData, encoding: .utf8) else {
            AppLogger.general.error("[CredentialStore] No password hash found for verification")
            return false
        }
        
        let inputHash = hashPassword(password)
        let matches = inputHash == storedHash
        
        AppLogger.general.info("[CredentialStore] Password verification: \(matches ? "SUCCESS" : "FAILED")")
        return matches
    }
    
    /// Clear all stored credentials
    func clearCredentials() {
        AppLogger.general.info("[CredentialStore] Clearing all credentials")
        
        _ = KeychainHelper.shared.delete(forKey: KeychainKey.credentials)
        _ = KeychainHelper.shared.delete(forKey: KeychainKey.passwordHash)
        _ = KeychainHelper.shared.delete(forKey: KeychainKey.sessionPassword)
        
        AppLogger.general.info("[CredentialStore] All credentials cleared")
    }
    
    /// Check if credentials exist in storage
    func hasStoredCredentials() -> Bool {
        let exists = KeychainHelper.shared.load(forKey: KeychainKey.credentials) != nil
        AppLogger.general.info("[CredentialStore] Credentials exist: \(exists)")
        return exists
    }
    
    // MARK: - Private Helpers
    
    private func hashPassword(_ password: String) -> String {
        let inputData = Data(password.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    private func validateCredentials(_ credentials: ServerCredentials) -> Bool {
        guard let scheme = credentials.baseURL.scheme,
              ["http", "https"].contains(scheme),
              let host = credentials.baseURL.host,
              !host.isEmpty else {
            AppLogger.general.error("[CredentialStore] Invalid URL: \(credentials.baseURL)")
            return false
        }
        
        guard !credentials.username.trimmingCharacters(in: .whitespaces).isEmpty,
              credentials.username.count >= 2,
              credentials.username.count <= 50 else {
            AppLogger.general.error("[CredentialStore] Invalid username length: \(credentials.username.count)")
            return false
        }
        
        guard !credentials.password.isEmpty,
              credentials.password.count >= 4,
              credentials.password.count <= 100 else {
            AppLogger.general.error("[CredentialStore] Invalid password length: \(credentials.password.count)")
            return false
        }
        
        return true
    }
}
