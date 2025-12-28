//
//  AudioSessionManager.swift
//  NavidromeClient3
//
//  Swift 6: Restored Missing Properties & Fixed Concurrency
//

import AVFoundation
import MediaPlayer
import Observation

@MainActor
@Observable
final class AudioSessionManager {
    static let shared = AudioSessionManager()
    
    // MARK: - State
    var isAudioSessionActive: Bool = false
    var isHeadphonesConnected: Bool = false
    var audioRoute: String = ""
    
    // FIX: Restored missing property required by AppDependencies
    weak var playerViewModel: PlayerViewModel?
    
    // MARK: - Initialization
    private init() {
        setupAudioSession()
        setupNotifications()
        checkAudioRoute()
    }
    
    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.allowAirPlay])
            try session.setActive(true)
            isAudioSessionActive = true
            AppLogger.audio.info("✅ Audio Session configured & active")
        } catch {
            AppLogger.audio.error("❌ Failed to setup audio session: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Notifications
    
    private func setupNotifications() {
        let center = NotificationCenter.default
        
        // Interruption (e.g. Phone call)
        center.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] n in
            guard let userInfo = n.userInfo,
                  let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
                return
            }
            
            let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            
            Task { @MainActor in
                self?.handleInterruption(type: type, options: options)
            }
        }
        
        // Route Change (e.g. Headphones unplugged)
        center.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] n in
            guard let userInfo = n.userInfo,
                  let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
                  let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
                return
            }
            
            Task { @MainActor in
                self?.handleRouteChange(reason: reason)
            }
        }
    }
    
    // MARK: - Helpers
    
    private func checkAudioRoute() {
        let route = AVAudioSession.sharedInstance().currentRoute
        audioRoute = route.outputs.first?.portName ?? "Unknown"
        isHeadphonesConnected = route.outputs.contains {
            $0.portType == .headphones || $0.portType == .bluetoothA2DP
        }
        AppLogger.audio.debug("🎧 Route: \(audioRoute), Headphones: \(isHeadphonesConnected)")
    }
    
    // MARK: - Handlers
    
    private func handleInterruption(type: AVAudioSession.InterruptionType, options: AVAudioSession.InterruptionOptions) {
        AppLogger.audio.debug("🎧 Audio Interruption: \(type.rawValue)")
        
        switch type {
        case .began:
            NotificationCenter.default.post(name: .audioInterruptionBegan, object: nil)
            
        case .ended:
            if options.contains(.shouldResume) {
                NotificationCenter.default.post(name: .audioInterruptionEnded, object: nil)
            }
            
        @unknown default:
            break
        }
    }
    
    private func handleRouteChange(reason: AVAudioSession.RouteChangeReason) {
        AppLogger.audio.debug("🎧 Audio Route Changed: \(reason.rawValue)")
        
        // Always refresh route info
        checkAudioRoute()
        
        switch reason {
        case .oldDeviceUnavailable:
            AppLogger.audio.info("🔌 Old device unavailable - requesting pause")
            NotificationCenter.default.post(name: .audioRouteChangedOldDeviceUnavailable, object: nil)
            
        case .newDeviceAvailable:
            AppLogger.audio.info("🎧 New device available")
            
        default:
            break
        }
    }
}
