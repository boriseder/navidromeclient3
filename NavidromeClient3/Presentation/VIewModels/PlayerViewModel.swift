//
//  PlayerViewModel.swift
//  NavidromeClient
//
//  Swift 6: Fully functional Player logic with Actor integration
//

import Foundation
import Observation
import AVFoundation

@MainActor
@Observable
final class PlayerViewModel: PlaybackEngineDelegate {
    
    // MARK: - Properties
    var currentSong: Song?
    var isPlaying: Bool = false
    var currentTime: TimeInterval = 0
    var duration: TimeInterval = 0
    var isScrubbing: Bool = false
    
    // Queue Management
    var queue: [Song] = []
    var currentIndex: Int = -1
    
    // Dependencies
    private var service: UnifiedSubsonicService?
    private let coverArtManager: CoverArtManager
    private let engine = PlaybackEngine()
    
    init(coverArtManager: CoverArtManager) {
        self.coverArtManager = coverArtManager
        self.engine.delegate = self
    }
    
    func configure(service: UnifiedSubsonicService) {
        self.service = service
    }
    
    // MARK: - Intentions (Public API)
    
    func play(song: Song, context: [Song]) async {
        // Optimistic UI update
        self.currentSong = song
        self.queue = context
        
        if let index = context.firstIndex(where: { $0.id == song.id }) {
            self.currentIndex = index
        } else {
            // Fallback if song not in context (shouldn't happen usually)
            self.currentIndex = 0
            self.queue = [song] + context
        }
        
        await loadAndPlayCurrentSong()
    }
    
    func togglePlayPause() {
        if isPlaying {
            engine.pause()
        } else {
            engine.resume()
        }
    }
    
    func seek(to time: TimeInterval) {
        isScrubbing = false
        engine.seek(to: time)
    }
    
    func nextTrack() {
        guard !queue.isEmpty else { return }
        
        if currentIndex < queue.count - 1 {
            currentIndex += 1
            Task { await loadAndPlayCurrentSong() }
        } else {
            // End of queue behavior
            engine.stop()
            isPlaying = false
        }
    }
    
    func previousTrack() {
        guard !queue.isEmpty else { return }
        
        // If we are more than 3 seconds in, restart the song
        if currentTime > 3 {
            engine.seek(to: 0)
        } else if currentIndex > 0 {
            currentIndex -= 1
            Task { await loadAndPlayCurrentSong() }
        } else {
            engine.seek(to: 0) // First song, just restart
        }
    }
    
    // MARK: - Internal Logic
    
    private func loadAndPlayCurrentSong() async {
        guard let service = service, currentIndex >= 0, currentIndex < queue.count else { return }
        
        let song = queue[currentIndex]
        self.currentSong = song // Update UI immediately
        
        // 1. Get Stream URL (Async Actor Call)
        guard let streamURL = await service.streamURL(for: song.id) else {
            AppLogger.general.error("Failed to get stream URL for \(song.title)")
            return
        }
        
        // 2. Prepare Next URL for Gapless/Preloading
        var upcoming: [(String, URL)] = []
        if currentIndex + 1 < queue.count {
            let nextSong = queue[currentIndex + 1]
            if let nextURL = await service.streamURL(for: nextSong.id) {
                upcoming.append((nextSong.id, nextURL))
            }
        }
        
        // 3. Hand off to Engine
        await engine.setQueue(
            primaryURL: streamURL,
            primaryId: song.id,
            upcomingURLs: upcoming
        )
    }
    
    // MARK: - PlaybackEngineDelegate
    
    func playbackEngine(_ engine: PlaybackEngine, didUpdateTime time: TimeInterval) {
        // Don't update time while user is dragging the slider
        if !isScrubbing {
            self.currentTime = time
        }
    }
    
    func playbackEngine(_ engine: PlaybackEngine, didUpdateDuration duration: TimeInterval) {
        self.duration = duration
    }
    
    func playbackEngine(_ engine: PlaybackEngine, didChangePlayingState isPlaying: Bool) {
        self.isPlaying = isPlaying
    }
    
    func playbackEngine(_ engine: PlaybackEngine, didFinishPlaying successfully: Bool) {
        if successfully {
            nextTrack()
        } else {
            isPlaying = false
        }
    }
    
    func playbackEngine(_ engine: PlaybackEngine, didEncounterError error: String) {
        AppLogger.general.error("Playback error: \(error)")
        isPlaying = false
    }
    
    func playbackEngineNeedsMoreItems(_ engine: PlaybackEngine) async {
        // Logic to fetch more items if we are near the end of a dynamic queue (e.g. radio)
        // For now, standard playlists are static queues.
    }
}
