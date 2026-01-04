//
//  ContentLoadingStrategy.swift
//  NavidromeClient
//
//  UPDATED: Swift 6 Concurrency Compliance
//  - Fixed OfflineManager call
//

import Foundation
import SwiftUI

enum ContentLoadingStrategy: Equatable, Sendable {
    case online
    case offlineOnly(reason: OfflineReason)
    case setupRequired
    
    enum OfflineReason: Equatable, Sendable {
        case noNetwork
        case serverUnreachable
        case userChoice
        
        var displayName: String {
            switch self {
            case .noNetwork: return "No Internet"
            case .serverUnreachable: return "Server Unreachable"
            case .userChoice: return "Offline Mode"
            }
        }
    }
    
    var shouldLoadOnlineContent: Bool {
        switch self {
        case .online: return true
        case .setupRequired: return true
        case .offlineOnly: return false
        }
    }
    
    var displayName: String {
        switch self {
        case .online: return "Online"
        case .offlineOnly(let reason): return reason.displayName
        case .setupRequired: return "Setup Required"
        }
    }

    var isEffectivelyOffline: Bool {
        return !shouldLoadOnlineContent
    }
}

// MARK: - UI Extensions

extension ContentLoadingStrategy.OfflineReason {
    var icon: String {
        switch self {
        case .noNetwork: return "wifi.slash"
        case .serverUnreachable: return "exclamationmark.triangle"
        case .userChoice: return "icloud.slash"
        }
    }
    
    var color: Color {
        switch self {
        case .noNetwork: return .red
        case .serverUnreachable: return .orange
        case .userChoice: return .blue
        }
    }
    
    var message: String {
        switch self {
        case .noNetwork: return "No internet connection - showing downloaded content"
        case .serverUnreachable: return "Server unreachable - showing downloaded content"
        case .userChoice: return "Offline mode \nshowing downloaded content"
        }
    }
    
    var canGoOnline: Bool {
        switch self {
        case .noNetwork, .serverUnreachable: return false
        case .userChoice: return true
        }
    }
    
    var actionTitle: String {
        switch self {
        case .userChoice: return "Go Online"
        default: return ""
        }
    }
    
    @MainActor
    func performAction() {
        switch self {
        case .userChoice:
            // Fixed: Use OfflineManager instead of NetworkMonitor
            OfflineManager.shared.setOfflineMode(false)
        default:
            break
        }
    }
}
