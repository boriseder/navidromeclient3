//
//  Notification+Extensions.swift
//  NavidromeClient
//
//  Centralized notification names
//

import Foundation

// MARK: - Notification Names

extension Notification.Name {
    // MARK: - App Lifecycle
    
    /// Posted when factory reset is requested
    /// Observers: All managers that need to clear state
    static let factoryResetRequested = Notification.Name("factoryResetRequested")
    
    // MARK: - Credentials
    
    /// Posted when credentials are updated/saved
    /// Object: ServerCredentials
    /// Observers: AppInitializer (for reinitialization)
    static let credentialsUpdated = Notification.Name("credentialsUpdated")
}
