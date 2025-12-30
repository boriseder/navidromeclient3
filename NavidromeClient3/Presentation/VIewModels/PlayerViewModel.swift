//
//  PlayerViewModel.swift
//  NavidromeClient3
//
//  Swift 6: Added SwiftUI Import for Array Extensions
//

import Foundation
import Observation
import AVFoundation
import UIKit
import SwiftUI // FIX: Required for 'move(fromOffsets:)' and 'remove(atOffsets:)'

enum RepeatMode {
    case off, all, one
    
    var icon: String {
        switch self {
        case .off: return "repeat"
        case .all: return "repeat"
        case .one: return "repeat.1"
        }
    }
}

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
    var originalQueue: [Song] = []
    var queue: [Song] = []
    var currentIndex: Int = -1
    
    // State
    var isShuffleEnabled: Bool = false
    var repeatMode: RepeatMode = .off
    
    // Dependencies
    private var service: UnifiedSubsonicService?
    private let coverArtManager: CoverArtManager
    private let engine = PlaybackEngine.shared
    private let lockScreenManager = LockScreenManager.shared
    
    init(coverArtManager: CoverArtManager) {
        self.coverArtManager = coverArtManager
        self.engine.delegate = self
        
        // Inject self into LockScreenManager
        self.lockScreenManager.configure(playerVM: self)
    }
    
    func configure(service: UnifiedSubsonicService) {
        self.service = service
    }
    
    // MARK: - Playback Intentions
    
    func play(song: Song, context: [Song]) async {
        self.currentSong = song
        self.originalQueue = context
        
        if isShuffleEnabled {
            self.queue = [song] + context.filter { $0.id != song.id }.shuffled()
            self.currentIndex = 0
        } else {
            self.queue = context
            if let index = context.firstIndex(where: { $0.id == song.id }) {
                self.currentIndex = index
            } else {
                self.currentIndex = 0
                self.queue = [song] + context
            }
        }
        
        await loadAndPlayCurrentSong()
    }
    
    func togglePlayPause() {
        if isPlaying { pause() } else { resume() }
    }
    
    func pause() {
        engine.pause()
    }
    
    func resume() {
        engine.resume()
    }
    
    func seek(to time: TimeInterval) {
        isScrubbing = false
        engine.seek(to: time)
        // Update lock screen immediately for responsiveness
        updateLockScreen()
    }
    
    func nextTrack() {
        guard !queue.isEmpty else { return }
        
        if repeatMode == .one {
            seek(to: 0)
            return
        }
        
        if currentIndex < queue.count - 1 {
            currentIndex += 1
            Task { await loadAndPlayCurrentSong() }
        } else if repeatMode == .all {
            currentIndex = 0
            Task { await loadAndPlayCurrentSong() }
        } else {
            engine.stop()
            isPlaying = false
            updateLockScreen()
        }
    }
    
    func previousTrack() {
        guard !queue.isEmpty else { return }
        
        if currentTime > 3 {
            seek(to: 0)
        } else if currentIndex > 0 {
            currentIndex -= 1
            Task { await loadAndPlayCurrentSong() }
        } else {
            seek(to: 0)
        }
    }
    
    // MARK: - Queue Management
    
    func moveQueueItem(from source: IndexSet, to destination: Int) {
        // FIX: This method requires 'import SwiftUI'
        queue.move(fromOffsets: source, toOffset: destination)
        
        // Recalculate current index based on where the current song moved
        if let current = currentSong, let newIndex = queue.firstIndex(where: { $0.id == current.id }) {
            currentIndex = newIndex
        }
    }
    
    func removeQueueItem(at offsets: IndexSet) {
        // If we remove the current song, play next or stop
        let currentRemoved = offsets.contains(currentIndex)
        
        // FIX: This method requires 'import SwiftUI' (or Foundation with Collection extensions)
        queue.remove(atOffsets: offsets)
        
        if queue.isEmpty {
            engine.stop()
            currentSong = nil
            updateLockScreen()
            return
        }
        
        if currentRemoved {
            // Adjust index to stay within bounds
            currentIndex = min(currentIndex, queue.count - 1)
            Task { await loadAndPlayCurrentSong() }
        } else {
            // Re-find current index
            if let current = currentSong, let newIndex = queue.firstIndex(where: { $0.id == current.id }) {
                currentIndex = newIndex
            }
        }
    }
    
    func toggleShuffle() {
        isShuffleEnabled.toggle()
        guard let current = currentSong else { return }
        
        if isShuffleEnabled {
            let rest = originalQueue.filter { $0.id != current.id }.shuffled()
            queue = [current] + rest
            currentIndex = 0
        } else {
            queue = originalQueue
            if let index = queue.firstIndex(where: { $0.id == current.id }) {
                currentIndex = index
            }
        }
    }
    
    func toggleRepeat() {
        switch repeatMode {
        case .off: repeatMode = .all
        case .all: repeatMode = .one
        case .one: repeatMode = .off
        }
    }
    
    // MARK: - Internal Logic
    
    private func loadAndPlayCurrentSong() async {
        guard let service = service, currentIndex >= 0, currentIndex < queue.count else { return }
        
        let song = queue[currentIndex]
        self.currentSong = song
        
        // 1. Update Lock Screen immediately (loading state)
        updateLockScreen()
        
        // 2. Fetch URL
        guard let streamURL = await service.streamURL(for: song.id) else {
            AppLogger.general.error("Failed to get stream URL for \(song.title)")
            return
        }
        
        // 3. Prepare Queue for Gapless support (future proof)
        var upcoming: [(String, URL)] = []
        if currentIndex + 1 < queue.count {
            let nextSong = queue[currentIndex + 1]
            if let nextURL = await service.streamURL(for: nextSong.id) {
                upcoming.append((nextSong.id, nextURL))
            }
        }
        
        engine.setQueue(primaryURL: streamURL, primaryId: song.id, upcomingURLs: upcoming)
    }
    
    private func updateLockScreen() {
        guard let song = currentSong else {
            lockScreenManager.updateNowPlaying(song: nil, image: nil, duration: 0, currentTime: 0, isPlaying: false)
            return
        }
        
        // Get Cached Image Synchronously if possible
        var artwork: UIImage?
        if let albumId = song.albumId {
            artwork = coverArtManager.getAlbumImage(for: albumId, context: .detail)
        }
        
        lockScreenManager.updateNowPlaying(
            song: song,
            image: artwork,
            duration: duration,
            currentTime: currentTime,
            isPlaying: isPlaying
        )
    }
    
    // MARK: - PlaybackEngineDelegate
    
    func playbackEngine(_ engine: PlaybackEngine, didUpdateTime time: TimeInterval) {
        if !isScrubbing { self.currentTime = time }
    }
    
    func playbackEngine(_ engine: PlaybackEngine, didUpdateDuration duration: TimeInterval) {
        self.duration = duration
        updateLockScreen() // Update duration once known
    }
    
    func playbackEngine(_ engine: PlaybackEngine, didChangePlayingState isPlaying: Bool) {
        self.isPlaying = isPlaying
        updateLockScreen()
    }
    
    func playbackEngine(_ engine: PlaybackEngine, didFinishPlaying successfully: Bool) {
        if successfully { nextTrack() } else { isPlaying = false; updateLockScreen() }
    }
    
    func playbackEngine(_ engine: PlaybackEngine, didEncounterError error: String) {
        AppLogger.general.error("Playback error: \(error)")
        isPlaying = false
        updateLockScreen()
    }
}
