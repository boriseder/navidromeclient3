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
    
    private var playlistObserver: AnyCancellable?

    // MARK: - Playlist Delegation
    
    var isShuffling: Bool { playlistManager.isShuffling }
    var repeatMode: PlaylistManager.RepeatMode { playlistManager.repeatMode }
    var currentPlaylist: [Song] { playlistManager.currentPlaylist }
    var currentIndex: Int { playlistManager.currentIndex }
    
    // MARK: - Private Properties
    
    private let playbackEngine = PlaybackEngine()
    private var notificationObservers: [NSObjectProtocol] = []
    
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
        
        setupNotifications()
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
    
    deinit {
        // Synchronous cleanup for deinit
        notificationObservers.forEach {
            NotificationCenter.default.removeObserver($0)
        }
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
    
    // MARK: - Notifications Setup
    
    private func setupNotifications() {
        let center = NotificationCenter.default
        
        notificationObservers.append(
            center.addObserver(
                forName: .audioInterruptionBegan,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.pause()
            }
        )
        
        notificationObservers.append(
            center.addObserver(
                forName: .audioInterruptionEndedShouldResume,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                if self?.currentSong != nil {
                    self?.resume()
                }
            }
        )
        
        notificationObservers.append(
            center.addObserver(
                forName: .audioDeviceDisconnected,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.pause()
            }
        )
    }
    
    private func configureAudioSession() {
        _ = audioSessionManager.isAudioSessionActive
    }
    
    // MARK: - Cleanup
    
    private func cleanup() {
        notificationObservers.forEach {
            NotificationCenter.default.removeObserver($0)
        }
        notificationObservers.removeAll()
        
        // Cancel playlist observer
        playlistObserver?.cancel()
        playlistObserver = nil

        audioSessionManager.clearNowPlayingInfo()
    }
    
    func shutdown() {
        cleanup()
        playbackEngine.stop()
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
        
        await playbackEngine.addItemsToQueue(urls)
        AppLogger.general.info("PlayerViewModel: Successfully added \(urls.count) items to queue")
    }
    
}

// MARK: - Queue Management Extension

extension PlayerViewModel {
    
    func jumpToSong(at index: Int) async {
        guard currentPlaylist.indices.contains(index) else { return }
        playlistManager.jumpToSong(at: index)
        await playCurrent()
    }
    
    func removeQueueSongs(at indices: [Int]) async {
        guard !indices.isEmpty else { return }
        
        let wasCurrentSongRemoved = indices.contains(playlistManager.currentIndex)
        playlistManager.removeSongs(at: indices)
        
        if wasCurrentSongRemoved {
            if playlistManager.currentPlaylist.isEmpty {
                stop()
            } else {
                await playCurrent()
            }
        }
    }
    
    func moveQueueSongs(from sourceIndices: [Int], to destinationIndex: Int) async {
        guard !sourceIndices.isEmpty else { return }
        
        let wasCurrentSongMoved = sourceIndices.contains(playlistManager.currentIndex)
        playlistManager.moveSongs(from: sourceIndices, to: destinationIndex)
        
        if wasCurrentSongMoved {
            await playCurrent()
        }
    }
    
    func shuffleUpNext() {
        playlistManager.shuffleUpNext()
    }
    
    func clearQueue() {
        playlistManager.clearUpNext()
    }
    
    func addToQueue(_ songs: [Song]) {
        playlistManager.addToQueue(songs)
    }
    
    func playNext(_ songs: [Song]) {
        playlistManager.playNext(songs)
    }
    
    func getQueueStats() -> QueueStats {
        return QueueStats(
            totalSongs: playlistManager.currentPlaylist.count,
            currentIndex: playlistManager.currentIndex,
            upNextCount: playlistManager.getUpNextSongs().count,
            totalDuration: playlistManager.getTotalDuration(),
            remainingDuration: playlistManager.getRemainingDuration(),
            isShuffling: playlistManager.isShuffling,
            repeatMode: playlistManager.repeatMode
        )
    }
}

// MARK: - Download Status (UI Support)

extension PlayerViewModel {
    
    func isAlbumDownloaded(_ albumId: String) -> Bool {
        downloadManager.isAlbumDownloaded(albumId)
    }
    
    func isAlbumDownloading(_ albumId: String) -> Bool {
        downloadManager.isAlbumDownloading(albumId)
    }
    
    func isSongDownloaded(_ songId: String) -> Bool {
        downloadManager.isSongDownloaded(songId)
    }
    
    func getDownloadProgress(albumId: String) -> Double {
        downloadManager.downloadProgress[albumId] ?? 0.0
    }
    
    func deleteAlbum(albumId: String) {
        downloadManager.deleteAlbum(albumId: albumId)
    }
}

// MARK: - Supporting Types

struct QueueStats {
    let totalSongs: Int
    let currentIndex: Int
    let upNextCount: Int
    let totalDuration: Int
    let remainingDuration: Int
    let isShuffling: Bool
    let repeatMode: PlaylistManager.RepeatMode
    
    var currentPosition: String {
        "\(currentIndex + 1) of \(totalSongs)"
    }
    
    var formattedTotalDuration: String {
        formatDuration(totalDuration)
    }
    
    var formattedRemainingDuration: String {
        formatDuration(remainingDuration)
    }
    
    private func formatDuration(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        
        if hours > 0 {
            return String(format: "%d:%02d:00", hours, minutes)
        } else {
            return String(format: "%d:00", minutes)
        }
    }
}
