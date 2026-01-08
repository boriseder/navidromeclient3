//
//  AudioSessionManager.swift
//  NavidromeClient
//
//  UPDATED: Swift 6 & iOS 17+ Modernization
//  - Migrated to @Observable
//  - Modern AsyncSequence for Notification Handling
//

import Foundation
import AVFoundation
import MediaPlayer
import Observation

@MainActor
@Observable
class AudioSessionManager: NSObject {
    static let shared = AudioSessionManager()
    
    // Observable Properties
    var isAudioSessionActive = false
    var isHeadphonesConnected = false
    var audioRoute: String = ""
    
    // Dependencies
    weak var playerViewModel: PlayerViewModel?
    
    // Internal
    @ObservationIgnored private let audioSession = AVAudioSession.sharedInstance()
    
    // Task management
    @ObservationIgnored private var observationTasks: [Task<Void, Never>] = []
    
    private override init() {
        super.init()
        setupAudioSession()
        setupAsyncNotifications()
        setupRemoteCommandCenter()
        checkAudioRoute()
    }
    
    // MARK: - Cleanup

    func performCleanup() {
        observationTasks.forEach { $0.cancel() }
        observationTasks.removeAll()
        AppLogger.audio.info("🧹 AudioSessionManager cleanup performed")
    }

    // MARK: - Audio Session Setup
    
    func setupAudioSession() {
        do {
            try audioSession.setCategory(.playback)
            try audioSession.setMode(.default)
            try audioSession.setActive(true)
            isAudioSessionActive = true
            AppLogger.audio.info("✅ Audio Session OK")
        } catch {
            isAudioSessionActive = false
            AppLogger.audio.info("❌ Audio Session setup failed: \(error)")
        }
    }
    
    // MARK: - Notifications Setup (Modern)
    
    private func setupAsyncNotifications() {
        let center = NotificationCenter.default
        
        // 1. Interruption
        observationTasks.append(
            Task { [weak self] in
                for await notification in center.notifications(named: AVAudioSession.interruptionNotification) {
                    guard let self = self,
                          let userInfo = notification.userInfo,
                          let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
                          let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt else { continue }
                    
                    self.handleInterruption(typeValue: typeValue, optionsValue: optionsValue)
                }
            }
        )
        
        // 2. Route changes
        observationTasks.append(
            Task { [weak self] in
                for await notification in center.notifications(named: AVAudioSession.routeChangeNotification) {
                    guard let self = self,
                          let userInfo = notification.userInfo,
                          let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt else { continue }
                    
                    var wasHeadphones = false
                    if let previousRoute = userInfo[AVAudioSessionRouteChangePreviousRouteKey] as? AVAudioSessionRouteDescription {
                        wasHeadphones = previousRoute.outputs.contains { output in
                            output.portType == .headphones || output.portType == .bluetoothA2DP
                        }
                    }
                    
                    self.handleRouteChange(reasonValue: reasonValue, wasHeadphones: wasHeadphones)
                }
            }
        )
        
        // 3. Media services reset
        observationTasks.append(
            Task { [weak self] in
                for await _ in center.notifications(named: AVAudioSession.mediaServicesWereResetNotification) {
                    self?.handleMediaServicesResetNotification()
                }
            }
        )
        
        AppLogger.audio.info("📡 Async audio session observers registered")
    }
    
    // MARK: - Enhanced Command Center Setup
    
    func setupRemoteCommandCenter() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.handleRemotePlay()
            return .success
        }
        
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.handleRemotePause()
            return .success
        }
        
        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.handleRemoteTogglePlayPause()
            return .success
        }
        
        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            self?.handleRemoteNextTrack()
            return .success
        }
        
        commandCenter.previousTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            self?.handleRemotePreviousTrack()
            return .success
        }
        
        commandCenter.changePlaybackPositionCommand.isEnabled = true
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            if let event = event as? MPChangePlaybackPositionCommandEvent {
                self?.handleRemoteSeek(to: event.positionTime)
                return .success
            }
            return .commandFailed
        }
        
        commandCenter.skipForwardCommand.isEnabled = true
        commandCenter.skipForwardCommand.preferredIntervals = [NSNumber(value: 15)]
        commandCenter.skipForwardCommand.addTarget { [weak self] event in
            if let event = event as? MPSkipIntervalCommandEvent {
                self?.handleRemoteSkipForward(interval: event.interval)
                return .success
            }
            return .commandFailed
        }
        
        commandCenter.skipBackwardCommand.isEnabled = true
        commandCenter.skipBackwardCommand.preferredIntervals = [NSNumber(value: 15)]
        commandCenter.skipBackwardCommand.addTarget { [weak self] event in
            if let event = event as? MPSkipIntervalCommandEvent {
                self?.handleRemoteSkipBackward(interval: event.interval)
                return .success
            }
            return .commandFailed
        }
        
        AppLogger.audio.info("🎛️ Remote command center configured")
    }
    
    func disableRemoteCommands() {
        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.playCommand.removeTarget(nil)
        commandCenter.pauseCommand.removeTarget(nil)
        commandCenter.togglePlayPauseCommand.removeTarget(nil)
        commandCenter.nextTrackCommand.removeTarget(nil)
        commandCenter.previousTrackCommand.removeTarget(nil)
        commandCenter.changePlaybackPositionCommand.removeTarget(nil)
        commandCenter.skipForwardCommand.removeTarget(nil)
        commandCenter.skipBackwardCommand.removeTarget(nil)
        
        AppLogger.audio.info("🔇 Remote commands disabled")
    }
    
    // MARK: - Now Playing Info (Lock Screen Display)

    func updateNowPlayingInfo(
        title: String,
        artist: String,
        album: String? = nil,
        artwork: UIImage? = nil,
        duration: TimeInterval,
        currentTime: TimeInterval,
        playbackRate: Float = 1.0
    ) {
        var nowPlayingInfo: [String: Any] = [
            MPMediaItemPropertyTitle: title,
            MPMediaItemPropertyArtist: artist,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: playbackRate
        ]
        
        if let album = album {
            nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = album
        }
        
        if let artwork = artwork {
            nowPlayingInfo[MPMediaItemPropertyArtwork] = createNonIsolatedArtwork(from: artwork)
        }
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
        AppLogger.audio.info("📱 Updated Now Playing Info: \(title) - \(artist)")
    }
    
    private nonisolated func createNonIsolatedArtwork(from image: UIImage) -> MPMediaItemArtwork {
        return MPMediaItemArtwork(boundsSize: image.size) { _ in
            return image
        }
    }
    
    func clearNowPlayingInfo() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        AppLogger.audio.info("🔇 Cleared Now Playing Info")
    }
    
    // MARK: - Lifecycle Handlers
    
    func handleAppBecameActive() async {
        AppLogger.audio.info("🟢 App became active - reactivating audio session")
        
        do {
            try await Task.detached {
                try AVAudioSession.sharedInstance().setActive(true)
            }.value
            
            self.isAudioSessionActive = true
            checkAudioRoute()
            AppLogger.audio.info("✅ Audio session reactivated")
            
        } catch {
            self.isAudioSessionActive = false
            AppLogger.audio.error("❌ Failed to reactivate audio session: \(error)")
        }
    }
    
    func handleAppWillResignActive() {
        AppLogger.audio.info("🟡 App will resign active")
    }
    
    func handleAppEnteredBackground() {
        AppLogger.audio.info("⬛ App entered background")
        
        guard let player = playerViewModel,
              let song = player.currentSong else {
            return
        }
        
        updateNowPlayingInfo(
            title: song.title,
            artist: song.artist ?? "Unknown Artist",
            album: song.album,
            artwork: nil, // Artwork usually managed by system cache if already set
            duration: player.duration,
            currentTime: player.currentTime,
            playbackRate: player.isPlaying ? 1.0 : 0.0
        )
    }
    
    func handleAppWillTerminate() {
        AppLogger.audio.info("🔴 App will terminate - cleaning up")
        
        performCleanup()
        
        do {
            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
            isAudioSessionActive = false
            AppLogger.audio.info("✅ Audio session deactivated")
        } catch {
            AppLogger.audio.error("❌ Failed to deactivate audio session: \(error)")
        }
        
        clearNowPlayingInfo()
        disableRemoteCommands()
    }
    
    func handleEmergencyShutdown() {
        AppLogger.audio.info("⚠️ Emergency shutdown - minimal cleanup")
        try? audioSession.setActive(false, options: .notifyOthersOnDeactivation)
    }
    
    // MARK: - Audio Route Management
    
    private func checkAudioRoute() {
        let route = audioSession.currentRoute
        audioRoute = route.outputs.first?.portName ?? "Unknown"
        
        isHeadphonesConnected = route.outputs.contains { output in
            output.portType == .headphones ||
            output.portType == .bluetoothA2DP ||
            output.portType == .bluetoothHFP ||
            output.portType == .bluetoothLE
        }
        
        AppLogger.audio.info("🎧 Audio Route: \(audioRoute), Headphones: \(isHeadphonesConnected)")
    }
    
    // MARK: - Notification Handlers
    
    private func handleInterruption(typeValue: UInt, optionsValue: UInt) {
        guard let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }
        
        switch type {
        case .began:
            AppLogger.audio.info("🔴 Audio Interruption BEGAN")
            isAudioSessionActive = false
            NotificationCenter.default.post(name: .audioInterruptionBegan, object: nil)
            
        case .ended:
            AppLogger.audio.info("🟢 Audio Interruption ENDED")
            isAudioSessionActive = true
            
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            if options.contains(.shouldResume) {
                AppLogger.audio.info("▶️ Should resume playback")
                NotificationCenter.default.post(name: .audioInterruptionEndedShouldResume, object: nil)
            } else {
                AppLogger.audio.info("⏸️ Should NOT resume playback")
                NotificationCenter.default.post(name: .audioInterruptionEnded, object: nil)
            }
            
        @unknown default:
            break
        }
    }
    
    private func handleRouteChange(reasonValue: UInt, wasHeadphones: Bool) {
        guard let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else { return }
        
        checkAudioRoute()
        
        switch reason {
        case .oldDeviceUnavailable:
            AppLogger.audio.info("🔌 Audio device disconnected")
            if wasHeadphones {
                AppLogger.audio.info("⏸️ Headphones removed - pausing playback")
                NotificationCenter.default.post(name: .audioDeviceDisconnected, object: nil)
            }
        default:
            break
        }
    }
    
    private func handleMediaServicesResetNotification() {
        AppLogger.audio.info("🔄 Media services were reset - reconfiguring")
        setupAudioSession()
        setupRemoteCommandCenter()
    }
    
    private func handleSilenceSecondaryAudioNotification() {}
    
    // MARK: - Remote Command Handlers
    
    private func handleRemotePlay() { playerViewModel?.handleRemotePlay() }
    private func handleRemotePause() { playerViewModel?.handleRemotePause() }
    private func handleRemoteTogglePlayPause() { playerViewModel?.handleRemoteTogglePlayPause() }
    private func handleRemoteNextTrack() { playerViewModel?.handleRemoteNextTrack() }
    private func handleRemotePreviousTrack() { playerViewModel?.handleRemotePreviousTrack() }
    
    private func handleRemoteSeek(to time: TimeInterval) {
        playerViewModel?.handleRemoteSeek(to: time)
    }
    
    private func handleRemoteSkipForward(interval: TimeInterval) {
        playerViewModel?.handleRemoteSkipForward(interval: interval)
    }
    
    private func handleRemoteSkipBackward(interval: TimeInterval) {
        playerViewModel?.handleRemoteSkipBackward(interval: interval)
    }
}
