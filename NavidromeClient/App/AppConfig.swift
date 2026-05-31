//
//  AppConfig.swift
//  NavidromeClient
//
//  UPDATED: Swift 6 & iOS 17+ Modernization
//  - FIXED: Migrated from ObservableObject to @Observable
//  - REQUIRED for @Environment(AppConfig.self) to work
//
//  FIXED (review):
//  - Removed redundant getCredentials() — use .credentials directly
//  - Fixed needsPassword() logic bug (spurious ?? true on already-guarded optional)
//  - Keychain write in restorePassword() now goes through CredentialStore, not
//    KeychainHelper directly — all credential persistence in one place
//  - KeychainHelper save result is no longer silently discarded
//

import Foundation
import Observation

@MainActor
@Observable
final class AppConfig {
    static let shared = AppConfig()

    // @ObservationIgnored prevents internal helpers from triggering UI updates
    @ObservationIgnored private let credentialStore = CredentialStore()

    // In @Observable, properties are published by default
    private(set) var credentials: ServerCredentials?

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

        // Clear caches — both are actor-isolated, fire-and-forget is correct here
        Task {
            await PersistentImageCache.shared.clearCache()
            await AlbumMetadataCache.shared.clearCache()
        }

        AppLogger.general.info("[AppConfig] Credentials cleared")
    }

    // MARK: - Password Management

    /// Returns true only when credentials exist but the stored password is empty,
    /// indicating the user needs to re-enter their password (e.g. after a Keychain migration).
    func needsPassword() -> Bool {
        guard let credentials else { return false }
        return credentials.password.isEmpty
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

        let updatedCredentials = ServerCredentials(
            baseURL: creds.baseURL,
            username: creds.username,
            password: password
        )

        // Route all Keychain writes through CredentialStore — never bypass it
        // with a direct KeychainHelper call, so credential persistence stays
        // in one place.
        do {
            try credentialStore.saveCredentials(updatedCredentials)
            self.credentials = updatedCredentials
            AppLogger.general.info("[AppConfig] Password restored successfully")
            return true
        } catch {
            AppLogger.general.error("[AppConfig] Failed to persist restored password: \(error)")
            return false
        }
    }

    // MARK: - Private Helpers

    private func loadCredentials() {
        AppLogger.general.info("[AppConfig] Loading credentials from CredentialStore...")

        guard let creds = credentialStore.loadCredentials() else {
            AppLogger.general.info("[AppConfig] No credentials found")
            return
        }

        self.credentials = creds
        AppLogger.general.info("[AppConfig] Credentials loaded: \(creds.username)")
    }
}
