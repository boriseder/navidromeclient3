//
//  AudioSessionManager.swift
//  NavidromeClient
//
//  UPDATED: Swift 6 Concurrency Compliance
//  - Removed unsafe background queue usage for observer cleanup
//  - Enforced MainActor isolation for lifecycle methods
//

import Foundation
import AVFoundation
import MediaPlayer

@MainActor
class AudioSessionManager: NSObject, ObservableObject {
    static let shared = AudioSessionManager()
    
    @Published var isAudioSessionActive = false
    @Published var isHeadphonesConnected = false
    @Published var audioRoute: String = ""
    
    // Swift 6: Observers must be accessed on MainActor since the class is @MainActor
    private var audioObservers: [NSObjectProtocol] = []

    private let audioSession = AVAudioSession.sharedInstance()
    
    weak var playerViewModel: PlayerViewModel?
    
    private override init() {
        super.init()
        setupAudioSession()
        setupNotifications()
        setupRemoteCommandCenter()
        checkAudioRoute()
    }
        
    deinit {
        // Swift 6: Deinit isolation is tricky.
        // We rely on explicit cleanup calls (handleAppWillTerminate) for safety.
        // However, if deinit triggers, we attempt a safe cleanup.
        Task { @MainActor [weak self] in
            self?.performCleanup()
        }
    }

    // MARK: - Cleanup

    func performCleanup() {
        // Swift 6 Fix: Accessing `audioObservers` must happen on MainActor.
        // NotificationCenter itself is thread-safe, so we don't need a background queue here.
        let observers = self.audioObservers
        self.audioObservers.removeAll()
        
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
        
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
    
    // MARK: - Notifications Setup
    
    private func setupNotifications() {
        let center = NotificationCenter.default
        
        // Interruption (calls, alarms, etc.)
        let interruptionObserver = center.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: audioSession,
            queue: .main
        ) { [weak self] notification in
            self?.handleInterruptionNotification(notification)
        }
        audioObservers.append(interruptionObserver)
        
        // Route changes (headphones, bluetooth)
        let routeObserver = center.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: audioSession,
            queue: .main
        ) { [weak self] notification in
            self?.handleRouteChangeNotification(notification)
        }
        audioObservers.append(routeObserver)
        
        // Media services reset
        let resetObserver = center.addObserver(
            forName: AVAudioSession.mediaServicesWereResetNotification,
            object: audioSession,
            queue: .main
        ) { [weak self] _ in
            self?.handleMediaServicesResetNotification()
        }
        audioObservers.append(resetObserver)
        
        // Silence secondary audio hint
        let silenceObserver = center.addObserver(
            forName: AVAudioSession.silenceSecondaryAudioHintNotification,
            object: audioSession,
            queue: .main
        ) { [weak self] notification in
            self?.handleSilenceSecondaryAudioNotification(notification)
        }
        audioObservers.append(silenceObserver)
        
        AppLogger.audio.info("📡 Audio session observers registered")
    }
    
    // MARK: - Enhanced Command Center Setup
    
    func setupRemoteCommandCenter() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        // Play Command
        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.handleRemotePlay()
            return .success
        }
        
        // Pause Command
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.handleRemotePause()
            return .success
        }
        
        // Toggle Play/Pause
        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.handleRemoteTogglePlayPause()
            return .success
        }
        
        // Next Track
        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            self?.handleRemoteNextTrack()
            return .success
        }
        
        // Previous Track
        commandCenter.previousTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            self?.handleRemotePreviousTrack()
            return .success
        }
        
        // Seeking
        commandCenter.changePlaybackPositionCommand.isEnabled = true
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            if let event = event as? MPChangePlaybackPositionCommandEvent {
                self?.handleRemoteSeek(to: event.positionTime)
                return .success
            }
            return .commandFailed
        }
        
        // Skip Forward/Backward
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
            let artworkItem = MPMediaItemArtwork(boundsSize: CGSize(width: 300, height: 300)) { _ in
                return artwork
            }
            nowPlayingInfo[MPMediaItemPropertyArtwork] = artworkItem
        }
        
        // Direct assignment on MainActor (Class is @MainActor)
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
        AppLogger.audio.info("📱 Updated Now Playing Info: \(title) - \(artist)")
    }
    
    func clearNowPlayingInfo() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        AppLogger.audio.info("🔇 Cleared Now Playing Info")
    }
    
    // MARK: - Modern App Lifecycle Handlers
    
    func handleAppBecameActive() async {
        AppLogger.audio.info("🟢 App became active - reactivating audio session")
        
        do {
            try await Task.detached {
                try AVAudioSession.sharedInstance().setActive(true)
            }.value
            
            // Re-check on MainActor
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
            artwork: nil,
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
    
    private func handleInterruptionNotification(_ notification: Notification) {
        guard let info = notification.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        switch type {
        case .began:
            AppLogger.audio.info("🔴 Audio Interruption BEGAN")
            isAudioSessionActive = false
            NotificationCenter.default.post(name: .audioInterruptionBegan, object: nil)
            
        case .ended:
            AppLogger.audio.info("🟢 Audio Interruption ENDED")
            isAudioSessionActive = true
            
            if let optionsValue = info[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) {
                    AppLogger.audio.info("▶️ Should resume playback")
                    NotificationCenter.default.post(name: .audioInterruptionEndedShouldResume, object: nil)
                } else {
                    AppLogger.audio.info("⏸️ Should NOT resume playback")
                    NotificationCenter.default.post(name: .audioInterruptionEnded, object: nil)
                }
            }
            
        @unknown default:
            break
        }
    }
    
    private func handleRouteChangeNotification(_ notification: Notification) {
        guard let info = notification.userInfo,
              let reasonValue = info[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }
        
        checkAudioRoute()
        
        switch reason {
        case .oldDeviceUnavailable:
            AppLogger.audio.info("🔌 Audio device disconnected")
            if let previousRoute = info[AVAudioSessionRouteChangePreviousRouteKey] as? AVAudioSessionRouteDescription {
                let wasHeadphones = previousRoute.outputs.contains { output in
                    output.portType == .headphones || output.portType == .bluetoothA2DP
                }
                
                if wasHeadphones {
                    AppLogger.audio.info("⏸️ Headphones removed - pausing playback")
                    NotificationCenter.default.post(name: .audioDeviceDisconnected, object: nil)
                }
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
    
    private func handleSilenceSecondaryAudioNotification(_ notification: Notification) {
        // Logging only
    }
    
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
