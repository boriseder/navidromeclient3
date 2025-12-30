//
//  OfflineManager.swift
//  NavidromeClient3
//
//  Swift 6: Fixed - Added configure method for Dependency Injection
//

import Foundation
import Observation

@MainActor
@Observable
final class OfflineManager {
    static let shared = OfflineManager()
    
    // MARK: - State
    var isOfflineMode: Bool = false
    var downloadedSongsCount: Int = 0
    
    // Simple in-memory set of downloaded IDs
    private var downloadedSongIds: Set<String> = []
    
    // MARK: - Dependencies
    // Added to satisfy AppInitializer.configureManagers
    private weak var service: UnifiedSubsonicService?
    
    // MARK: - Init
    init() {
        AppLogger.general.info("OfflineManager initialized")
        loadOfflineIndex()
    }
    
    // MARK: - Configuration
    
    func configure(service: UnifiedSubsonicService) {
        self.service = service
    }
    
    // MARK: - View Requirements
    
    func switchToOnlineMode() {
        self.isOfflineMode = false
        AppLogger.general.info("Switched to Online Mode")
    }
    
    func toggleOfflineMode() {
        isOfflineMode.toggle()
        AppLogger.general.info("Offline Mode toggled to: \(isOfflineMode)")
    }
    
    /// Retrieves albums from the DownloadManager to display in Offline Library.
    func getOfflineAlbums() -> [Album] {
        let downloads = DownloadManager.shared.downloadedAlbums
        
        return downloads.map { dlAlbum in
            Album(
                id: dlAlbum.id,
                name: dlAlbum.title,
                artist: dlAlbum.artist,
                year: dlAlbum.year,
                genre: dlAlbum.genre,
                coverArt: dlAlbum.coverArtId,
                coverArtId: dlAlbum.coverArtId,
                duration: nil,
                songCount: dlAlbum.songs.count,
                artistId: nil,
                displayArtist: dlAlbum.artist
            )
        }
    }
    
    /// Retrieves all offline songs.
    func getOfflineSongs() -> [Song] {
        let downloads = DownloadManager.shared.downloadedAlbums
        var songs: [Song] = []
        
        for album in downloads {
            let albumSongs = album.songs.map { dlSong in
                Song(
                    id: dlSong.id,
                    title: dlSong.title,
                    duration: Int(dlSong.duration),
                    coverArt: album.coverArtId,
                    artist: dlSong.artist,
                    album: album.title,
                    albumId: album.id,
                    track: dlSong.trackNumber,
                    year: album.year,
                    genre: album.genre,
                    artistId: nil,
                    isVideo: false,
                    contentType: "audio/mpeg",
                    suffix: "mp3",
                    path: dlSong.localFileName
                )
            }
            songs.append(contentsOf: albumSongs)
        }
        return songs
    }
    
    // MARK: - Core Logic
    
    func hasOfflineCopy(songId: String) -> Bool {
        return downloadedSongIds.contains(songId)
    }
    
    func getLocalUrl(for songId: String) -> URL? {
        guard hasOfflineCopy(songId: songId) else { return nil }
        
        guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        let fileURL = documentsURL.appendingPathComponent("\(songId).mp3")
        
        return FileManager.default.fileExists(atPath: fileURL.path) ? fileURL : nil
    }
    
    func registerOfflineTrack(songId: String, localUrl: URL) {
        downloadedSongIds.insert(songId)
        saveOfflineIndex()
        AppLogger.general.info("Registered offline track: \(songId)")
    }
    
    func removeOfflineTrack(songId: String) {
        guard hasOfflineCopy(songId: songId) else { return }
        
        guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let fileURL = documentsURL.appendingPathComponent("\(songId).mp3")
        
        try? FileManager.default.removeItem(at: fileURL)
        
        downloadedSongIds.remove(songId)
        saveOfflineIndex()
    }
    
    // MARK: - Persistence
    
    private func loadOfflineIndex() {
        if let savedIds = UserDefaults.standard.array(forKey: "offline_songs_index") as? [String] {
            self.downloadedSongIds = Set(savedIds)
            self.downloadedSongsCount = savedIds.count
        }
    }
    
    private func saveOfflineIndex() {
        let array = Array(downloadedSongIds)
        UserDefaults.standard.set(array, forKey: "offline_songs_index")
        self.downloadedSongsCount = array.count
    }
}
