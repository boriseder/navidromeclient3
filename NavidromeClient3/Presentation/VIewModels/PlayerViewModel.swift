//
//  PlayerViewModel.swift
//  NavidromeClient3
//
//  Swift 6: @Observable Migration
//

import Foundation
import Observation

@MainActor
@Observable
final class PlayerViewModel {
    
    // MARK: - Properties (No @Published)
    var currentSong: Song?
    var isPlaying: Bool = false
    var currentTime: TimeInterval = 0
    var duration: TimeInterval = 0
    var isScrubbing: Bool = false
    
    // Dependencies
    private let service: UnifiedSubsonicService? // Injected later
    private let coverArtManager: CoverArtManager
    
    init(coverArtManager: CoverArtManager) {
        self.coverArtManager = coverArtManager
    }
    
    func configure(service: UnifiedSubsonicService) {
        // self.service = service
    }
    
    // MARK: - Controls
    func togglePlayPause() {
        isPlaying.toggle()
        // logic to actually pause engine
    }
    
    func seek(to time: TimeInterval) {
        currentTime = time
        isScrubbing = false
        // logic to seek engine
    }
    
    func nextTrack() { /* ... */ }
    func previousTrack() { /* ... */ }
}
