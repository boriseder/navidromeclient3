//
//  OfflineManager.swift
//  NavidromeClient
//
//  UPDATED: Swift 6 & iOS 17+ Modernization
//  - Migrated to @Observable
//  - Modern Notification Handling
//  - Fixed Album Initialization Ambiguity
//  - Added Artist Support for Offline Mode
//

import Foundation
import Observation

@MainActor
@Observable
class OfflineManager {
    static let shared = OfflineManager()
    
    private(set) var isOfflineMode = false
    private(set) var offlineAlbums: [Album] = []
    private(set) var offlineArtists: [Artist] = []
    
    @ObservationIgnored private var observationTasks: [Task<Void, Never>] = []
    
    init() {
        setupAsyncObservers()
    }
    
    deinit {
        observationTasks.forEach { $0.cancel() }
    }
    
    // MARK: - Mode Control
    
    func toggleOfflineMode() {
        isOfflineMode.toggle()
        
        if isOfflineMode {
            AppLogger.general.info("[OfflineManager] Switched to Offline Mode")
            refreshOfflineContent()
        } else {
            AppLogger.general.info("[OfflineManager] Switched to Online Mode")
        }
        
        NotificationCenter.default.post(name: .contentLoadingStrategyChanged, object: nil)
    }
    
    func setOfflineMode(_ enabled: Bool) {
        guard isOfflineMode != enabled else { return }
        
        isOfflineMode = enabled
        if isOfflineMode {
            refreshOfflineContent()
        }
        NotificationCenter.default.post(name: .contentLoadingStrategyChanged, object: nil)
    }
    
    // MARK: - Content Management
    
    func refreshOfflineContent() {
        let downloaded = DownloadManager.shared.downloadedAlbums
        
        self.offlineAlbums = downloaded.map { dl in
            // Explicitly typed nils to ensure compiler matches the custom init
            let parentVal: String? = nil
            let artistIdVal: String? = nil
            let totalDuration = dl.songs.reduce(0) { $0 + ($1.duration ?? 0) }
            
            return Album(
                id: dl.albumId,
                parent: parentVal,
                album: dl.albumName,
                title: dl.albumName,
                name: dl.albumName,
                isDir: true,
                coverArt: dl.albumId,
                artist: dl.artistName,
                artistId: artistIdVal,
                created: dl.downloadDate,
                duration: totalDuration,
                playCount: 0,
                songCount: dl.songs.count,
                year: dl.year,
                genre: dl.genre
                // song: default nil
            )
        }.sorted { $0.name < $1.name }
        
        // Generate unique artists from downloaded albums
        self.offlineArtists = extractArtistsFromAlbums(offlineAlbums)
        
        AppLogger.general.info("[OfflineManager] Refreshed offline content: \(offlineAlbums.count) albums, \(offlineArtists.count) artists")
    }
    
    // MARK: - Data Access
    
    func getOfflineAlbums(for artist: Artist) -> [Album] {
        return offlineAlbums.filter { $0.artist == artist.name }
    }
    
    func getOfflineAlbums(for genre: Genre) -> [Album] {
        // Safe check for genre value
        let genreName = genre.value
        return offlineAlbums.filter { album in
            guard let albumGenre = album.genre else { return false }
            return albumGenre.contains(genreName)
        }
    }
    
    func isArtistAvailableOffline(_ artistName: String) -> Bool {
        return offlineArtists.contains { $0.name == artistName }
    }
    
    // MARK: - Helper Methods
    
    private func extractArtistsFromAlbums(_ albums: [Album]) -> [Artist] {
        var artistDict: [String: (id: String, albumCount: Int)] = [:]
        
        for album in albums {
            let artistName = album.artist
            let artistId = album.artistId ?? "offline-\(artistName.lowercased().replacingOccurrences(of: " ", with: "-"))"
            
            if let existing = artistDict[artistName] {
                artistDict[artistName] = (id: existing.id, albumCount: existing.albumCount + 1)
            } else {
                artistDict[artistName] = (id: artistId, albumCount: 1)
            }
        }
        
        return artistDict.map { name, info in
            Artist(
                id: info.id,
                name: name,
                coverArt: info.id,
                albumCount: info.albumCount,
                artistImageUrl: nil
            )
        }.sorted { $0.name < $1.name }
    }
    
    // MARK: - Reset
    
    func performCompleteReset() {
        isOfflineMode = false
        offlineAlbums.removeAll()
        offlineArtists.removeAll()
        AppLogger.general.info("[OfflineManager] Reset complete")
    }
    
    private func setupAsyncObservers() {
        let resetTask = Task { @MainActor [weak self] in
            for await _ in NotificationCenter.default.notifications(named: .factoryResetRequested) {
                self?.performCompleteReset()
            }
        }
        observationTasks.append(resetTask)
    }
}
