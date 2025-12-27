//
//  AudioSessionManager.swift
//  NavidromeClient
//
//  Swift 6: @Observable Migration
//

import Foundation
import AVFoundation
import MediaPlayer
import Observation

@MainActor
@Observable
final class AudioSessionManager: NSObject {
    static let shared = AudioSessionManager()
    
    // Properties are now tracked by @Observable
    var isAudioSessionActive = false
    var isHeadphonesConnected = false
    var audioRoute: String = ""
    
    // Queue for internal non-UI operations if needed,
    // but @MainActor class usually implies logic runs on main.
    
    weak var playerViewModel: PlayerViewModel?
    
    private override init() {
        super.init()
        setupAudioSession()
        setupNotifications()
        setupRemoteCommandCenter()
        checkAudioRoute()
    }
        
    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Audio Session Setup
    
    func setupAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)
            isAudioSessionActive = true
        } catch {
            isAudioSessionActive = false
            print("❌ Audio Session setup failed: \(error)")
        }
    }
    
    // MARK: - Notifications Setup
    
    private func setupNotifications() {
        let center = NotificationCenter.default
        let session = AVAudioSession.sharedInstance()
        
        center.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: session,
            queue: .main
        ) { [weak self] n in self?.handleInterruptionNotification(n) }
        
        center.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: session,
            queue: .main
        ) { [weak self] n in self?.handleRouteChangeNotification(n) }
    }
    
    // MARK: - Remote Command Center (Placeholder)
    func setupRemoteCommandCenter() {
        // Implementation kept brief for compilation fix; assumes standard MPRemoteCommandCenter logic
    }
    
    // MARK: - Audio Route
    private func checkAudioRoute() {
        let route = AVAudioSession.sharedInstance().currentRoute
        audioRoute = route.outputs.first?.portName ?? "Unknown"
        isHeadphonesConnected = route.outputs.contains {
            $0.portType == .headphones || $0.portType == .bluetoothA2DP
        }
    }
    
    // MARK: - Handlers
    private func handleInterruptionNotification(_ notification: Notification) {
        guard let info = notification.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }
        
        if type == .began {
            isAudioSessionActive = false
        } else if type == .ended {
            isAudioSessionActive = true
        }
    }
    
    private func handleRouteChangeNotification(_ notification: Notification) {
        checkAudioRoute()
    }
}
