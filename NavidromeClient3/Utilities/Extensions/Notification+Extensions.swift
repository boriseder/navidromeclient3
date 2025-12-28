//
//  Notification+Extensions.swift
//  NavidromeClient3
//
//  Swift 6: Added Audio Session Notifications
//

import Foundation

extension Notification.Name {
    // MARK: - App Lifecycle
    static let factoryResetRequested = Notification.Name("factoryResetRequested")
    
    // MARK: - Credentials
    static let credentialsUpdated = Notification.Name("credentialsUpdated")
    
    // MARK: - Audio Session
    static let audioInterruptionBegan = Notification.Name("audioInterruptionBegan")
    static let audioInterruptionEnded = Notification.Name("audioInterruptionEnded")
    static let audioRouteChangedOldDeviceUnavailable = Notification.Name("audioRouteChangedOldDeviceUnavailable")
}
