//
//  PlayerViewModel.swift
//  NavidromeClient
//
//  UPDATED: Swift 6 Compliance
//  - Fixed MainActor isolation warnings in sink closures
//

import Foundation
import SwiftUI
import AVFoundation
import MediaPlayer
import Combine
import Observation

@MainActor
@Observable
class PlayerViewModel: NSObject {
    
    // MARK: - Properties
    
    var isPlaying = false
    var currentSong: Song?
    var currentAlbumId: String?
    var currentTime: TimeInterval = 0
    var duration: TimeInterval = 0
    var playbackProgress: Double = 0
    var isLoading = false
    var errorMessage: String?
    
    var volume: Float = 0.7 {
        didSet { playbackEngine.volume = volume }
    }
    
    // PlaylistManager is now @Observable and independent
    var playlistManager = PlaylistManager()
    
    // MARK: - Combine Storage
    @ObservationIgnored private var cancellables = Set<AnyCancellable>()

    // MARK: - Playlist Delegation
    var isShuffling: Bool { playlistManager.isShuffling }
    var repeatMode: PlaylistManager.RepeatMode { playlistManager.repeatMode }
    var currentPlaylist: [Song] { playlistManager.currentPlaylist }
    var currentIndex: Int { playlistManager.currentIndex }
    
    // MARK: - Private Properties
    @ObservationIgnored private let playbackEngine = PlaybackEngine()
    
    // MARK: - Dependencies
    @ObservationIgnored private weak var unifiedService: UnifiedSubsonicService?
    @ObservationIgnored private let downloadManager: DownloadManager
    @ObservationIgnored private let audioSessionManager = AudioSessionManager.shared
    @ObservationIgnored private let coverArtManager: CoverArtManager
    
    // MARK: - Initialization
    
    init(
        downloadManager: DownloadManager = .shared,
        coverArtManager: CoverArtManager
    ) {
        self.downloadManager = downloadManager
        self.coverArtManager = coverArtManager
        
        super.init()
        
        playbackEngine.delegate = self
        playbackEngine.volume = volume
        
        setupCombineObservers()
        configureAudioSession()
    }

    // MARK: - Configuration
    
    func configure(service: UnifiedSubsonicService) {
        self.unifiedService = service
    }
    
    func shutdown() {
        cancellables.removeAll()
        playbackEngine.stop()
        audioSessionManager.clearNowPlayingInfo()
    }
    
    // MARK: - Public Playback Methods
    
    func play(song: Song) async {
        await setPlaylist([song], startIndex: 0, albumId: song.albumId)
    }
    
    func setPlaylist(_ songs: [Song], startIndex: Int = 0, albumId: String?) async {
        guard !songs.isEmpty else { return }
        playlistManager.setPlaylist(songs, startIndex: startIndex)
        currentAlbumId = albumId
        await playCurrent()
    }
    
    func togglePlayPause() {
        if isPlaying {
            playbackEngine.pause()
        } else {
            playbackEngine.resume()
        }
    }
    
    func pause() {
        playbackEngine.pause()
    }
    
    func resume() {
        playbackEngine.resume()
    }
    
    func stop() {
        playbackEngine.stop()
        currentSong = nil
        currentTime = 0
        duration = 0
        playbackProgress = 0
        audioSessionManager.clearNowPlayingInfo()
    }
    
    func seek(to time: TimeInterval) {
        playbackEngine.seek(to: time)
    }
    
    func playNext() async {
        playlistManager.advanceToNext()
        await playCurrent()
    }
    
    func playPrevious() async {
        playlistManager.moveToPrevious(currentTime: currentTime)
        await playCurrent()
    }
    
    func skipForward(seconds: TimeInterval = 15) {
        playbackEngine.seek(to: currentTime + seconds)
    }
    
    func skipBackward(seconds: TimeInterval = 15) {
        playbackEngine.seek(to: currentTime - seconds)
    }
    
    func toggleShuffle() { playlistManager.toggleShuffle() }
    func toggleRepeat() { playlistManager.toggleRepeat() }
    
    // MARK: - Private Core Playback
    
    private func playCurrent() async {
        guard let song = playlistManager.currentSong else {
            stop()
            return
        }
        
        currentSong = song
        currentAlbumId = song.albumId
        duration = Double(song.duration ?? 0)
        currentTime = 0
        isLoading = true
        
        if let albumId = song.albumId {
            coverArtManager.preloadForFullscreen(albumId: albumId)
        }
        
        let audioURL = await getAudioURL(for: song)
        
        guard let url = audioURL else {
            errorMessage = "No audio source"
            isLoading = false
            return
        }
        
        await playbackEngine.setQueue(primaryURL: url, primaryId: song.id, upcomingURLs: [])
        isLoading = false
    }
    
    private func getAudioURL(for song: Song) async -> URL? {
        if let localURL = downloadManager.getLocalFileURL(for: song.id) {
            return localURL
        }
        return unifiedService?.streamURL(for: song.id)
    }
    
    // MARK: - Notifications Setup
    
    private func setupCombineObservers() {
        let center = NotificationCenter.default
        
        // Fix: Wrap in Task { @MainActor } to allow calling pause() safely
        center.publisher(for: .audioInterruptionBegan)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.pause()
                }
            }
            .store(in: &cancellables)
        
        center.publisher(for: .audioInterruptionEndedShouldResume)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    // Safe access to currentSong (isolated) inside Task
                    if self?.currentSong != nil {
                        self?.resume()
                    }
                }
            }
            .store(in: &cancellables)
        
        center.publisher(for: .audioDeviceDisconnected)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.pause()
                }
            }
            .store(in: &cancellables)
    }
    
    private func configureAudioSession() {
        _ = audioSessionManager.isAudioSessionActive
    }
    
    private func updateNowPlayingInfo() {
        guard let song = currentSong else {
            audioSessionManager.clearNowPlayingInfo()
            return
        }
        let albumId = currentAlbumId ?? ""
        let artwork = coverArtManager.getAlbumImage(for: albumId, context: .detail)
        
        audioSessionManager.updateNowPlayingInfo(
            title: song.title,
            artist: song.artist ?? "Unknown",
            album: song.album,
            artwork: artwork,
            duration: duration,
            currentTime: currentTime,
            playbackRate: isPlaying ? 1.0 : 0.0
        )
    }
    
    private func updateProgress() {
        playbackProgress = duration > 0 ? currentTime / duration : 0
    }
    
    // MARK: - Remote Handlers
    func handleRemotePlay() { if currentSong != nil { resume() } }
    func handleRemotePause() { pause() }
    func handleRemoteTogglePlayPause() { togglePlayPause() }
    func handleRemoteNextTrack() { Task { await playNext() } }
    func handleRemotePreviousTrack() { Task { await playPrevious() } }
    func handleRemoteSeek(to time: TimeInterval) { seek(to: time) }
    func handleRemoteSkipForward(interval: TimeInterval) { skipForward(seconds: interval) }
    func handleRemoteSkipBackward(interval: TimeInterval) { skipBackward(seconds: interval) }
}

extension PlayerViewModel: PlaybackEngineDelegate {
    func playbackEngine(_ engine: PlaybackEngine, didUpdateTime time: TimeInterval) {
        currentTime = time
        updateProgress()
    }
    
    func playbackEngine(_ engine: PlaybackEngine, didUpdateDuration duration: TimeInterval) {
        self.duration = duration
    }
    
    func playbackEngine(_ engine: PlaybackEngine, didChangePlayingState isPlaying: Bool) {
        self.isPlaying = isPlaying
        updateNowPlayingInfo()
    }
    
    func playbackEngine(_ engine: PlaybackEngine, didFinishPlaying successfully: Bool) {
        if successfully {
            Task { await playNext() }
        }
    }
    
    func playbackEngine(_ engine: PlaybackEngine, didEncounterError error: String) {
        errorMessage = error
        Task { await playNext() }
    }
    
    func playbackEngineNeedsMoreItems(_ engine: PlaybackEngine) async {
        // Implementation omitted for brevity, no changes needed for this fix
    }
}

// MARK: - Queue & Download Extensions
extension PlayerViewModel {
    func jumpToSong(at index: Int) async {
        guard currentPlaylist.indices.contains(index) else { return }
        playlistManager.jumpToSong(at: index)
        await playCurrent()
    }
    
    func removeQueueSongs(at indices: [Int]) async {
        let wasCurrentRemoved = indices.contains(playlistManager.currentIndex)
        playlistManager.removeSongs(at: indices)
        if wasCurrentRemoved {
            if playlistManager.currentPlaylist.isEmpty { stop() }
            else { await playCurrent() }
        }
    }
    
    func moveQueueSongs(from source: [Int], to dest: Int) async {
        let wasCurrentMoved = source.contains(playlistManager.currentIndex)
        playlistManager.moveSongs(from: source, to: dest)
        if wasCurrentMoved { await playCurrent() }
    }
    
    func shuffleUpNext() { playlistManager.shuffleUpNext() }
    func clearQueue() { playlistManager.clearUpNext() }
    func addToQueue(_ songs: [Song]) { playlistManager.addToQueue(songs) }
    func playNext(_ songs: [Song]) { playlistManager.playNext(songs) }
    
    func isAlbumDownloaded(_ id: String) -> Bool { downloadManager.isAlbumDownloaded(id) }
    func isAlbumDownloading(_ id: String) -> Bool { downloadManager.isAlbumDownloading(id) }
    func deleteAlbum(albumId: String) { downloadManager.deleteAlbum(albumId: albumId) }
}
