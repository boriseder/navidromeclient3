//
//  Notification+Extensions.swift
//  NavidromeClient
//
//  Centralized notification names for the entire app.
//  Fixes "Type 'NSNotification.Name' has no member" errors.
//

import Foundation

extension Notification.Name {
    // MARK: - App Lifecycle
    /// Posted when factory reset is requested (logout/clear data)
    static let factoryResetRequested = Notification.Name("factoryResetRequested")
    
    // MARK: - Credentials
    /// Posted when credentials are updated/saved
    static let credentialsUpdated = Notification.Name("credentialsUpdated")
    
    // MARK: - Downloads
    /// Posted when an album download finishes successfully
    static let downloadCompleted = Notification.Name("downloadCompleted")
    /// Posted when a download starts
    static let downloadStarted = Notification.Name("downloadStarted")
    /// Posted when a download fails
    static let downloadFailed = Notification.Name("downloadFailed")
    /// Posted when a download is deleted
    static let downloadDeleted = Notification.Name("downloadDeleted")
    
    // MARK: - Network
    /// Posted when the ContentLoadingStrategy changes (e.g. online -> offline)
    static let contentLoadingStrategyChanged = Notification.Name("contentLoadingStrategyChanged")
    /// Posted for general network state changes
    static let networkStateChanged = Notification.Name("networkStateChanged")
    
    // MARK: - Audio / Player
    /// Posted when audio is interrupted (e.g. phone call)
    static let audioInterruptionBegan = Notification.Name("audioInterruptionBegan")
    /// Posted when interruption ends but playback might NOT resume automatically
    static let audioInterruptionEnded = Notification.Name("audioInterruptionEnded")
    /// Posted when interruption ends and playback SHOULD resume
    static let audioInterruptionEndedShouldResume = Notification.Name("audioInterruptionEndedShouldResume")
    /// Posted when headphones/audio device is unplugged
    static let audioDeviceDisconnected = Notification.Name("audioDeviceDisconnected")
}
