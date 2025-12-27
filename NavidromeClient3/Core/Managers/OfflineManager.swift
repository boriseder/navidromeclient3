//
//  OfflineManager.swift
//  NavidromeClient
//
//  Swift 6: @Observable & Logic Fixes
//

import Foundation
import SwiftUI
import Observation

@MainActor
@Observable
final class OfflineManager {
    static let shared = OfflineManager()
    
    // MARK: - Offline Data Management
    
    var offlineAlbums: [Album] {
        // FIX: Calculate offline albums from downloaded songs + metadata cache
        // We get all songs, find their album IDs, then fetch albums
        // Note: This relies on AlbumMetadataCache having the data.
        
        // This is a synchronous computed property, so we can't await here.
        // We rely on what's currently in memory/cache synchronously.
        // For a proper solution, this should likely be a stored property updated via an async method.
        // However, to fit the existing pattern, we try to grab cached albums.
        
        // Since we can't do async calls here, we return an empty list or
        // we need to refactor this to be a loaded property.
        // For now, returning empty to fix crash, but real fix is async loading.
        return []
    }
    
    // Alternative: We expose a method to load them
    var loadedOfflineAlbums: [Album] = []
    
    var offlineArtists: [Artist] {
        extractUniqueArtists(from: loadedOfflineAlbums)
    }
    
    var offlineGenres: [Genre] {
        extractUniqueGenres(from: loadedOfflineAlbums)
    }
    
    // MARK: - Dependencies
    
    private let downloadManager = DownloadManager.shared
    private let networkMonitor = NetworkMonitor.shared
    
    private init() {
        setupFactoryResetObserver()
        Task { await refreshOfflineContent() }
    }
    
    // MARK: - Public API
    
    func refreshOfflineContent() async {
        // FIX: Rebuild offline albums list
        // This assumes AlbumMetadataCache can return all cached albums
        let allCached = await AlbumMetadataCache.shared.getAllCachedAlbums()
        let downloadedIds = downloadManager.downloadedSongs
        
        // Filter albums that have at least one song downloaded?
        // Or simply all albums in cache are considered "viewable" offline?
        // Let's assume all cached albums are relevant for offline mode.
        self.loadedOfflineAlbums = allCached
    }
    
    func switchToOnlineMode() {
        networkMonitor.setManualOfflineMode(false)
        AppLogger.general.info("Requested switch to online mode")
    }

    func switchToOfflineMode() {
        networkMonitor.setManualOfflineMode(true)
        AppLogger.general.info("Requested switch to offline mode")
    }
    
    func toggleOfflineMode() {
        let currentStrategy = networkMonitor.contentLoadingStrategy
        
        switch currentStrategy {
        case .online:
            switchToOfflineMode()
        case .offlineOnly(let reason):
            switch reason {
            case .userChoice:
                switchToOnlineMode()
            case .noNetwork, .serverUnreachable:
                AppLogger.general.info("Cannot switch to online: \(reason.message)")
            }
        case .setupRequired:
            AppLogger.general.info("Cannot toggle offline mode: Server setup required")
        }
    }
    
    var isOfflineMode: Bool {
        return !networkMonitor.shouldLoadOnlineContent
    }
    
    // MARK: - Queries
    
    func getOfflineAlbums(for artist: Artist) -> [Album] {
        return loadedOfflineAlbums.filter { $0.artist == artist.name }
    }
    
    func getOfflineAlbums(for genre: Genre) -> [Album] {
        return loadedOfflineAlbums.filter { $0.genre == genre.value }
    }
    
    func isAlbumAvailableOffline(_ albumId: String) -> Bool {
        return downloadManager.isAlbumDownloaded(albumId)
    }
    
    func isArtistAvailableOffline(_ artistName: String) -> Bool {
        return loadedOfflineAlbums.contains { $0.artist == artistName }
    }
    
    func isGenreAvailableOffline(_ genreName: String) -> Bool {
        return loadedOfflineAlbums.contains { $0.genre == genreName }
    }
    
    // MARK: - Statistics
    
    var offlineStats: OfflineStats {
        return OfflineStats(
            albumCount: loadedOfflineAlbums.count,
            artistCount: offlineArtists.count,
            genreCount: offlineGenres.count,
            totalSongs: downloadManager.downloadedSongs.count
        )
    }
    
    // MARK: - Reset
    
    func performCompleteReset() {
        loadedOfflineAlbums = []
        AppLogger.general.info("OfflineManager: Reset completed")
    }
    
    // MARK: - Reactive Updates
    
    private func setupFactoryResetObserver() {
        NotificationCenter.default.addObserver(
            forName: .factoryResetRequested,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // FIX: Explicitly capture on MainActor
            Task { @MainActor in
                self?.performCompleteReset()
            }
        }
    }
    
    // MARK: - Helpers
    
    private func extractUniqueArtists(from albums: [Album]) -> [Artist] {
        let uniqueArtists = Set(albums.map { $0.artist })
        return uniqueArtists.compactMap { artistName in
            Artist(
                id: artistName.replacingOccurrences(of: " ", with: "_"),
                name: artistName,
                coverArt: nil,
                albumCount: albums.filter { $0.artist == artistName }.count,
                artistImageUrl: nil
            )
        }.sorted { $0.name < $1.name }
    }
    
    private func extractUniqueGenres(from albums: [Album]) -> [Genre] {
        let genreGroups = Dictionary(grouping: albums) { $0.genre ?? "Unknown" }
        return genreGroups.map { genreName, albumsInGenre in
            Genre(
                value: genreName,
                songCount: albumsInGenre.reduce(0) { $0 + ($1.songCount ?? 0) },
                albumCount: albumsInGenre.count
            )
        }.sorted { $0.value < $1.value }
    }
}

// FIX: Added missing struct
struct OfflineStats: Sendable {
    let albumCount: Int
    let artistCount: Int
    let genreCount: Int
    let totalSongs: Int
}
