import Foundation
import SwiftUI
import AVFoundation
import MediaPlayer
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
    
    var playlistManager = PlaylistManager()
    private var songsAheadInEngine: Int = 0

    // MARK: - Playlist Delegation
    var isShuffling: Bool { playlistManager.isShuffling }
    var repeatMode: PlaylistManager.RepeatMode { playlistManager.repeatMode }
    var currentPlaylist: [Song] { playlistManager.currentPlaylist }
    var currentIndex: Int { playlistManager.currentIndex }
    
    // MARK: - Private Properties
    @ObservationIgnored private let playbackEngine = PlaybackEngine()
    @ObservationIgnored private var observationTasks: [Task<Void, Never>] = []
    
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
        
        startObservingNotifications()
        configureAudioSession()
    }
    
    deinit {
        // Cancel all observation tasks (thread-safe)
        observationTasks.forEach { $0.cancel() }
        
        // Capture references that need MainActor cleanup
        let engine = playbackEngine
        let sessionManager = audioSessionManager
        
        // Schedule MainActor cleanup asynchronously
        // Note: This may not complete if app is terminating
        Task { @MainActor in
            engine.shutdown()
            sessionManager.clearNowPlayingInfo()
            AppLogger.general.info("PlayerViewModel: Cleanup completed")
        }
        
        AppLogger.general.info("PlayerViewModel: Deinitialized")
    }

    // MARK: - Configuration
    
    func configure(service: UnifiedSubsonicService) {
        self.unifiedService = service
    }
    
    func shutdown() {
        observationTasks.forEach { $0.cancel() }
        observationTasks.removeAll()
        playbackEngine.shutdown()
        audioSessionManager.clearNowPlayingInfo()
        AppLogger.general.info("PlayerViewModel: Explicit shutdown completed")
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
        guard playlistManager.nextIndex() != nil else {
            AppLogger.general.info("PlayerViewModel: No next song available")
            stop()
            return
        }
        
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
    
    func playbackEngine(_ engine: PlaybackEngine, didAdvanceToSongId songId: String) {
        guard let index = playlistManager.currentPlaylist.firstIndex(where: { $0.id == songId }),
              index != playlistManager.currentIndex else { return }

        playlistManager.jumpToSong(at: index)
        songsAheadInEngine = max(0, songsAheadInEngine - 1)  // consumed one


        guard let song = playlistManager.currentSong else { return }
        currentSong = song
        currentAlbumId = song.albumId
        duration = Double(song.duration ?? 0)
        currentTime = 0

        if let albumId = song.albumId {
            coverArtManager.preloadForFullscreen(albumId: albumId)
        }

        updateNowPlayingInfo()
        AppLogger.general.info("PlayerViewModel: UI synced to gapless advance → \(song.title)")
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
        
        if let albumId = song.albumId {
            coverArtManager.preloadForFullscreen(albumId: albumId)
        }

        // Get upcoming songs for gapless playback
        let upcomingSongs = playlistManager.getUpcoming(count: 2)
        
        let audioURL = await getAudioURL(for: song)
        
        guard let url = audioURL else {
            errorMessage = "No audio source"
            isLoading = false
            return
        }
        
        // Resolve URLs for upcoming songs
        let upcomingURLs = await resolveUpcomingURLs(for: upcomingSongs)
        
        // Set the queue with current song + upcoming
        await playbackEngine.setQueue(
            primaryURL: url,
            primaryId: song.id,
            upcomingURLs: upcomingURLs
        )
        songsAheadInEngine = upcomingSongs.count
        isLoading = false
        
        AppLogger.general.info("PlayerViewModel: Started playback: \(song.title) with \(upcomingURLs.count) upcoming")
    }
    
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
        if let localURL = downloadManager.getLocalFileURL(for: song.id) {
            return localURL
        }
        
        guard let service = unifiedService else {
            AppLogger.general.error("PlayerViewModel: Service not configured")
            errorMessage = "Service not configured"
            return nil
        }
        
        return service.streamURL(for: song.id)
    }
    
    // MARK: - Notifications Setup (Simple Separate Tasks)
    
    private func startObservingNotifications() {
        let center = NotificationCenter.default
        
        // Task 1: Audio interruption began
        let task1 = Task { @MainActor [weak self] in
            for await _ in center.notifications(named: .audioInterruptionBegan) {
                self?.pause()
            }
        }
        observationTasks.append(task1)
        
        // Task 2: Audio interruption ended (should resume)
        let task2 = Task { @MainActor [weak self] in
            for await _ in center.notifications(named: .audioInterruptionEndedShouldResume) {
                guard let self = self else { return }
                if self.currentSong != nil {
                    self.resume()
                }
            }
        }
        observationTasks.append(task2)
        
        // Task 3: Audio device disconnected (headphones unplugged)
        let task3 = Task { @MainActor [weak self] in
            for await _ in center.notifications(named: .audioDeviceDisconnected) {
                self?.pause()
            }
        }
        observationTasks.append(task3)
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
        AppLogger.general.info("PlayerViewModel: Playback finished, successfully: \(successfully)")
        
        if successfully {
            Task {
                guard playlistManager.nextIndex() != nil else {
                    AppLogger.general.info("PlayerViewModel: End of playlist")
                    stop()
                    return
                }
                
                playlistManager.advanceToNext()
                await playCurrent()
            }
        } else {
            stop()
        }
    }
    
    func playbackEngine(_ engine: PlaybackEngine, didEncounterError error: String) {
        errorMessage = error
        AppLogger.general.info("PlayerViewModel: Encountered error, attempting next song")
        Task {
            await playNext()
        }
    }
    
    func playbackEngineNeedsMoreItems(_ engine: PlaybackEngine) async {
        let currentQueueSize = engine.currentQueueSize
        guard currentQueueSize < 3 else { return }
        
        let itemsNeeded = 3 - currentQueueSize
        AppLogger.general.info("PlayerViewModel: Need \(itemsNeeded) more items for queue")
        
        // Skip songs already buffered in the engine
        let offset = songsAheadInEngine
        let lookahead = offset + itemsNeeded
        let allUpcoming = playlistManager.getUpcoming(count: lookahead)
        let nextSongs = Array(allUpcoming.dropFirst(offset))
        
        guard !nextSongs.isEmpty else {
            AppLogger.general.info("PlayerViewModel: No more songs available in playlist")
            return
        }
        
        let urls = await resolveUpcomingURLs(for: nextSongs)
        guard !urls.isEmpty else { return }
        
        await playbackEngine.addItemsToQueue(urls)
        songsAheadInEngine += urls.count
        AppLogger.general.info("PlayerViewModel: Added \(urls.count) items, \(songsAheadInEngine) now buffered ahead")
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
