//
//  PlayerViewModel.swift
//  NavidromeClient3
//
//  Swift 6: Added Queue Management (Move/Delete)
//

import SwiftUI
import Observation
import UIKit
import AVFoundation

enum RepeatMode: Equatable, Sendable {
    case off
    case all
    case one
    
    var icon: String {
        switch self {
        case .off, .all: return "repeat"
        case .one: return "repeat.1"
        }
    }
}

@MainActor
@Observable
final class PlayerViewModel: PlaybackEngineDelegate {
    
    // MARK: - Dependencies
    private var playbackEngine: PlaybackEngine { PlaybackEngine.shared }
    
    private var musicLibraryManager: MusicLibraryManager?
    private var downloadManager: DownloadManager?
    private var favoritesManager: FavoritesManager?
    
    // MARK: - Playback State
    var isPlaying: Bool = false
    var playbackProgress: Double = 0.0
    var duration: Double = 0.0
    var isScrubbing: Bool = false
    
    // MARK: - Queue State
    var currentSong: Song?
    var queue: [Song] = []
    private var originalQueue: [Song] = [] // For un-shuffle logic
    var currentIndex: Int = 0
    
    // MARK: - Modes
    var repeatMode: RepeatMode = .off
    var isShuffleEnabled: Bool = false
    
    // MARK: - Computed Properties
    var currentTime: Double {
        get { playbackProgress }
        set { seek(to: newValue) }
    }
    
    var songTitle: String { currentSong?.title ?? "Not Playing" }
    var artistName: String { currentSong?.artist ?? "" }
    var coverArt: UIImage? { return nil }
    
    // MARK: - Init
    init() {
        PlaybackEngine.shared.delegate = self
    }
    
    // MARK: - Configuration
    func configure(
        musicLibraryManager: MusicLibraryManager,
        downloadManager: DownloadManager,
        favoritesManager: FavoritesManager
    ) {
        self.musicLibraryManager = musicLibraryManager
        self.downloadManager = downloadManager
        self.favoritesManager = favoritesManager
        AppLogger.general.info("PlayerViewModel configured with dependencies")
    }
    
    // MARK: - Intents
    
    func play(song: Song) {
        setupQueue(songs: [song], startIndex: 0)
    }
    
    func playQueue(songs: [Song], startIndex: Int) {
        setupQueue(songs: songs, startIndex: startIndex)
    }
    
    // MARK: - Queue Management (Fix for QueueView)
    
    func moveQueueItem(from source: IndexSet, to destination: Int) {
        // Track the playing song ID so we can update currentIndex after the move
        let playingId = currentSong?.id
        
        queue.move(fromOffsets: source, toOffset: destination)
        
        // Restore currentIndex
        if let playingId, let newIndex = queue.firstIndex(where: { $0.id == playingId }) {
            self.currentIndex = newIndex
        }
    }
    
    func removeQueueItem(at offsets: IndexSet) {
        let playingId = currentSong?.id
        
        queue.remove(atOffsets: offsets)
        
        if queue.isEmpty {
            stop()
        } else if let playingId, let newIndex = queue.firstIndex(where: { $0.id == playingId }) {
            self.currentIndex = newIndex
        } else {
            // If we deleted the current song, stop or play next available?
            // Simple approach: stop if confused, or clamp index
            if currentIndex >= queue.count {
                currentIndex = 0
            }
            // Ideally load the new song at currentIndex if playing
        }
    }
    
    // MARK: - Controls
    
    func resume() { playbackEngine.resume() }
    func pause() { playbackEngine.pause() }
    func stop() { playbackEngine.stop() }
    
    func togglePlayPause() {
        if isPlaying { pause() } else { resume() }
    }
    
    func nextTrack() {
        if repeatMode == .one {
            seek(to: 0)
            return
        }
        if currentIndex + 1 < queue.count {
            advanceTo(index: currentIndex + 1)
        } else if repeatMode == .all && !queue.isEmpty {
            advanceTo(index: 0)
        } else {
            stop()
        }
    }
    
    func previousTrack() {
        if playbackProgress > 3.0 {
            seek(to: 0)
        } else {
            if currentIndex > 0 {
                advanceTo(index: currentIndex - 1)
            } else {
                seek(to: 0)
            }
        }
    }
    
    func skipToNext() { nextTrack() }
    func skipToPrevious() { previousTrack() }
    
    func toggleShuffle() {
        isShuffleEnabled.toggle()
        if isShuffleEnabled {
            originalQueue = queue
            guard let current = currentSong else { return }
            var remaining = originalQueue.filter { $0.id != current.id }
            remaining.shuffle()
            queue = [current] + remaining
            currentIndex = 0
        } else {
            queue = originalQueue
            if let current = currentSong, let index = queue.firstIndex(where: { $0.id == current.id }) {
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
    
    func seek(to value: Double) {
        playbackEngine.seek(to: value)
        self.playbackProgress = value
    }
    
    // MARK: - Private Logic
    
    private func setupQueue(songs: [Song], startIndex: Int) {
        self.originalQueue = songs
        if isShuffleEnabled {
            let startSong = songs[startIndex]
            var remaining = songs
            remaining.remove(at: startIndex)
            remaining.shuffle()
            self.queue = [startSong] + remaining
            self.currentIndex = 0
        } else {
            self.queue = songs
            self.currentIndex = startIndex
        }
        startPlayback(for: self.queue[self.currentIndex])
    }
    
    private func advanceTo(index: Int) {
        self.currentIndex = index
        startPlayback(for: queue[index])
    }
    
    private func startPlayback(for song: Song) {
        self.currentSong = song
        let serverUrl = UserDefaults.standard.string(forKey: "serverUrl") ?? ""
        let username = UserDefaults.standard.string(forKey: "username") ?? ""
        let password = UserDefaults.standard.string(forKey: "password") ?? ""
        let streamUrlString = "\(serverUrl)/rest/stream?id=\(song.id)&u=\(username)&p=\(password)&v=1.16.1&c=NavidromeClient&f=mp3"
        guard let url = URL(string: streamUrlString) else { return }
        playbackEngine.play(url: url, songId: song.id)
    }
    
    // MARK: - PlaybackEngineDelegate
    
    func playbackEngine(_ engine: PlaybackEngine, didUpdateCurrentSongId songId: String?) {
        guard let songId = songId else { return }
        if let index = queue.firstIndex(where: { $0.id == songId }) {
            self.currentIndex = index
            self.currentSong = queue[index]
        }
    }
    
    func playbackEngine(_ engine: PlaybackEngine, didUpdateTime time: Double) {
        if !isScrubbing { self.playbackProgress = time }
    }
    
    func playbackEngine(_ engine: PlaybackEngine, didUpdateDuration duration: Double) {
        self.duration = duration
    }
    
    func playbackEngine(_ engine: PlaybackEngine, didChangePlayingState isPlaying: Bool) {
        self.isPlaying = isPlaying
    }
    
    func playbackEngine(_ engine: PlaybackEngine, didFinishPlaying successfully: Bool) {
        if successfully && currentIndex >= queue.count - 1 && repeatMode == .all {
             nextTrack()
        } else if successfully && currentIndex >= queue.count - 1 {
             self.isPlaying = false
        }
    }
    
    func playbackEngine(_ engine: PlaybackEngine, didEncounterError error: String) {
        self.isPlaying = false
    }
    
    func playbackEngineNeedsMoreItems(_ engine: PlaybackEngine) {}
}
