//
//  AudioSessionManager.swift
//  NavidromeClient3
//
//  Swift 6: Fixed Deprecated 'allowBluetooth' -> 'allowBluetoothA2DP'
//

import AVFoundation
import MediaPlayer
import SwiftUI
import Observation

@MainActor
@Observable
final class AudioSessionManager {
    static let shared = AudioSessionManager()
    
    var isSessionActive = false
    
    init() {
        setupAudioSession()
        setupRemoteCommandCenter()
    }
    
    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            // Fix: 'allowBluetooth' is deprecated. Use 'allowBluetoothA2DP' for music.
            try session.setCategory(
                .playback,
                mode: .default,
                options: [.allowBluetoothA2DP, .allowAirPlay]
            )
            try session.setActive(true)
            isSessionActive = true
            AppLogger.general.info("Audio Session configured successfully")
        } catch {
            AppLogger.general.error("Failed to setup audio session: \(error)")
        }
    }
    
    private func setupRemoteCommandCenter() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        commandCenter.playCommand.addTarget { _ in
            Task { @MainActor in PlaybackEngine.shared.resume() }
            return .success
        }
        
        commandCenter.pauseCommand.addTarget { _ in
            Task { @MainActor in PlaybackEngine.shared.pause() }
            return .success
        }
        
        commandCenter.nextTrackCommand.addTarget { _ in
            Task { @MainActor in PlaybackEngine.shared.advanceToNextItem() }
            return .success
        }
        
        commandCenter.stopCommand.addTarget { _ in
            Task { @MainActor in PlaybackEngine.shared.stop() }
            return .success
        }
    }
    
    // MARK: - Lifecycle Handlers
    
    func handleAppEnteredBackground() {
        AppLogger.general.info("App entered background")
        PlaybackEngine.shared.saveCurrentState()
    }
    
    func handleAppBecameActive() {
        AppLogger.general.info("App became active")
    }
    
    func handleAppWillResignActive() {
        AppLogger.general.info("App will resign active")
    }
    
    func handleAppWillTerminate() {
        handleEmergencyShutdown()
    }
    
    func handleEmergencyShutdown() {
        AppLogger.general.info("🚨 Emergency Shutdown: Saving state immediately.")
        PlaybackEngine.shared.saveCurrentState()
    }
}
