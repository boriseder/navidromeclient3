import Foundation
import SwiftUI
import AVFoundation
import MediaPlayer
import Combine

@MainActor
class PlayerViewModel: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isPlaying = false
    @Published var currentSong: Song?
    @Published var currentAlbumId: String?
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var playbackProgress: Double = 0
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var volume: Float = 0.7 {
        didSet { playbackEngine.volume = volume }
    }
    @Published var playlistManager = PlaylistManager()
    
    // MARK: - Combine Storage
    // Swift 6: Replaces NSObjectProtocol observers to avoid deinit isolation issues
    private var cancellables = Set<AnyCancellable>()
    private var playlistObserver: AnyCancellable?

    // MARK: - Playlist Delegation
    
    var isShuffling: Bool { playlistManager.isShuffling }
    var repeatMode: PlaylistManager.RepeatMode { playlistManager.repeatMode }
    var currentPlaylist: [Song] { playlistManager.currentPlaylist }
    var currentIndex: Int { playlistManager.currentIndex }
    
    // MARK: - Private Properties
    
    private let playbackEngine = PlaybackEngine()
    
    // MARK: - Dependencies
    
    private weak var unifiedService: UnifiedSubsonicService?
    private let downloadManager: DownloadManager
    private let audioSessionManager = AudioSessionManager.shared
    private let coverArtManager: CoverArtManager
    
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
   
        // Chain PlaylistManager changes to PlayerViewModel
        setupPlaylistObserver()
    }
    
    private func setupPlaylistObserver() {
        playlistObserver = playlistManager.objectWillChange.sink { [weak self] _ in
            guard let self = self else { return }
            
            // Forward playlist changes to PlayerViewModel observers
            Task { @MainActor in
                self.objectWillChange.send()
            }
        }
    }

    // MARK: - Configuration
    
    func configure(service: UnifiedSubsonicService) {
        self.unifiedService = service
        AppLogger.general.info("PlayerViewModel configured with UnifiedSubsonicService")
    }
    
    // Swift 6: removed deinit accessing MainActor properties.
    // Cancellables will clean themselves up automatically.
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
        guard !songs.isEmpty else {
            errorMessage = "Playlist is empty"
            return
        }
        
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
        errorMessage = nil
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
    
    // MARK: - Playlist Controls
    
    func toggleShuffle() {
        playlistManager.toggleShuffle()
    }
    
    func toggleRepeat() {
        playlistManager.toggleRepeat()
    }
    
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
        errorMessage = nil
        
        if let albumId = song.albumId {
            coverArtManager.preloadForFullscreen(albumId: albumId)
        }
        
        let upcomingSongs = playlistManager.getUpcoming(count: 3)
        
        async let currentURL = getAudioURL(for: song)
        async let upcomingURLs = resolveUpcomingURLs(for: upcomingSongs)
        
        guard let audioURL = await currentURL else {
            errorMessage = "No audio source available"
            isLoading = false
            return
        }
        
        let upcoming = await upcomingURLs
        await playbackEngine.setQueue(
            primaryURL: audioURL,
            primaryId: song.id,
            upcomingURLs: upcoming
        )
        
        isLoading = false
    }
    
    // MARK: - Audio Source Selection
    
    private func resolveUpcomingURLs(for songs: [Song]) async -> [(id: String, url: URL)] {
        await withTaskGroup(of: (String, URL?).self) { group in
            for song in songs {
                group.addTask {
                    let url = await self.getAudioURL(for: song)
                    return (song.id, url)
                }
            }
            
            var results: [(String, URL)] = []
            for await (id, url) in group {
                if let url = url {
                    results.append((id, url))
                }
            }
            return results
        }
    }
    
    private func getAudioURL(for song: Song) async -> URL? {
        // Priority 1: Downloaded file
        if let localURL = downloadManager.getLocalFileURL(for: song.id) {
            AppLogger.general.info("Using downloaded file for: \(song.title)")
            return localURL
        }
        
        // Priority 2: Stream URL from service
        if let service = unifiedService, let streamURL = service.streamURL(for: song.id) {
            AppLogger.general.info("Using stream URL for: \(song.title)")
            return streamURL
        }
        
        AppLogger.general.info("No audio source available for: \(song.title)")
        return nil
    }
    
    // MARK: - Notifications Setup (Combine)
    
    private func setupCombineObservers() {
        let center = NotificationCenter.default
        
        center.publisher(for: .audioInterruptionBegan)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.pause()
            }
            .store(in: &cancellables)
        
        center.publisher(for: .audioInterruptionEndedShouldResume)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                if self?.currentSong != nil {
                    self?.resume()
                }
            }
            .store(in: &cancellables)
        
        center.publisher(for: .audioDeviceDisconnected)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.pause()
            }
            .store(in: &cancellables)
    }
    
    private func configureAudioSession() {
        _ = audioSessionManager.isAudioSessionActive
    }
    
    // MARK: - Now Playing Info
    
    private func updateNowPlayingInfo() {
        guard let song = currentSong else {
            audioSessionManager.clearNowPlayingInfo()
            return
        }
        
        let albumId = currentAlbumId ?? ""
        let artwork = coverArtManager.getAlbumImage(for: albumId, context: .detail)
        
        audioSessionManager.updateNowPlayingInfo(
            title: song.title,
            artist: song.artist ?? "Unknown Artist",
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
    
    // MARK: - Remote Command Handlers
    
    func handleRemotePlay() {
        if currentSong != nil {
            resume()
        }
    }
    
    func handleRemotePause() {
        pause()
    }
    
    func handleRemoteTogglePlayPause() {
        togglePlayPause()
    }
    
    func handleRemoteNextTrack() {
        Task { await playNext() }
    }
    
    func handleRemotePreviousTrack() {
        Task { await playPrevious() }
    }
    
    func handleRemoteSeek(to time: TimeInterval) {
        seek(to: time)
    }
    
    func handleRemoteSkipForward(interval: TimeInterval) {
        skipForward(seconds: interval)
    }
    
    func handleRemoteSkipBackward(interval: TimeInterval) {
        skipBackward(seconds: interval)
    }
}

// MARK: - PlaybackEngineDelegate

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
            Task {
                await playNext()
            }
        }
    }
    
    func playbackEngine(_ engine: PlaybackEngine, didEncounterError error: String) {
        errorMessage = error
        Task {
            await playNext()
        }
    }
    
    func playbackEngineNeedsMoreItems(_ engine: PlaybackEngine) async {
        let currentQueueSize = engine.currentQueueSize
        
        guard currentQueueSize < 3 else {
            AppLogger.general.info("PlayerViewModel: Queue sufficient (\(currentQueueSize) items)")
            return
        }
        
        let itemsNeeded = 3 - currentQueueSize
        AppLogger.general.info("PlayerViewModel: Need \(itemsNeeded) more items for queue")
        
        let nextSongs = playlistManager.getUpcoming(count: itemsNeeded)
        
        guard !nextSongs.isEmpty else {
            AppLogger.general.info("PlayerViewModel: No more songs available in playlist")
            return
        }
        
        AppLogger.general.info("PlayerViewModel: Loading \(nextSongs.count) upcoming songs")
        let urls = await resolveUpcomingURLs(for: nextSongs)
        
        guard !urls.isEmpty else {
            AppLogger.general.info("PlayerViewModel: Failed to resolve URLs for upcoming songs")
            return
        }
        
        await playbackEngine.addItemsToQueue(urls
