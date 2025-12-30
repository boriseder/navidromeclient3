//
//  ContentLoadingStrategy.swift
//  NavidromeClient3
//
//  Swift 6: Unified Strategy & UI Helpers
//

import SwiftUI

enum ContentLoadingStrategy: Equatable, Sendable {
    /// Load from server, fallback to cache if needed
    case online
    
    /// Force load from local database/cache only
    case offlineOnly(reason: OfflineReason)
    
    /// App is not configured yet
    case setupRequired
    
    // MARK: - Properties
    
    var shouldLoadOnlineContent: Bool {
        switch self {
        case .online: return true
        case .offlineOnly, .setupRequired: return false
        }
    }
    
    var displayName: String {
        switch self {
        case .online: return "Online"
        case .offlineOnly(let reason): return "Offline: \(reason.title)"
        case .setupRequired: return "Setup Required"
        }
    }
    
    // MARK: - Nested Types
    
    enum OfflineReason: Equatable, Sendable {
        case userInitiated      // Modern name for 'userChoice'
        case noConnection       // Modern name for 'noNetwork'
        case serverUnreachable
    }
}

// MARK: - UI Helpers

extension ContentLoadingStrategy.OfflineReason {
    var icon: String {
        switch self {
        case .userInitiated: return "wifi.slash"
        case .noConnection: return "exclamationmark.triangle.fill"
        case .serverUnreachable: return "server.rack"
        }
    }
    
    var color: Color {
        switch self {
        case .userInitiated: return .orange
        case .noConnection: return .red
        case .serverUnreachable: return .purple
        }
    }
    
    var title: String {
        switch self {
        case .userInitiated: return "Offline Mode"
        case .noConnection: return "No Internet"
        case .serverUnreachable: return "Server Error"
        }
    }
    
    var message: String {
        switch self {
        case .userInitiated: return "You are currently in offline mode."
        case .noConnection: return "Check your internet connection."
        case .serverUnreachable: return "Could not connect to Navidrome."
        }
    }
    
    var canGoOnline: Bool {
        switch self {
        case .userInitiated: return true
        default: return false
        }
    }
    
    var actionTitle: String {
        return "Go Online"
    }
}
