//
//  OfflineManager.swift
//  NavidromeClient
//
//  UPDATED: Swift 6 Concurrency Compliance
//  - Strictly MainActor to align with DownloadManager and UI
//

import Foundation
import SwiftUI
import Combine

@MainActor
class OfflineManager: ObservableObject {
    static let shared = OfflineManager()
    
    // MARK: - Offline Data Management (Core Responsibility)
    
    // The list of offline albums is now a computed property, eliminating the need
    // for manual internal caching and invalidation logic (cacheNeedsRefresh).
    var offlineAlbums: [Album] {
        // Access the source of truth directly. This ensures the list is always up-to-date
        // based on DownloadManager and AlbumMetadataCache without manual syncing.
        let downloadedAlbumIds = Set(downloadManager.downloadedAlbums.map { $0.albumId })
        return AlbumMetadataCache.shared.getAlbums(ids: downloadedAlbumIds)
    }
    
    var offlineArtists: [Artist] {
        // Recalculates from the current set of offlineAlbums
        extractUniqueArtists(from: offlineAlbums)
    }
    
    var offlineGenres: [Genre] {
        // Recalculates from the current set of offlineAlbums
        extractUniqueGenres(from: offlineAlbums)
    }
    
    // MARK: - Dependencies
    
    private let downloadManager = DownloadManager.shared
    private let networkMonitor = NetworkMonitor.shared
    
    private init() {
        setupFactoryResetObserver()
    }
    
    // MARK: - Public API (Delegates to NetworkMonitor)
    
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
                AppLogger.general.info("⚠️ Cannot switch to online: \(reason.message)")
            }
        case .setupRequired:
            AppLogger.general.info("⚠️ Cannot toggle offline mode: Server setup required")
        }
    }
    
    // MARK: - UI State Properties (Read-Only)
    
    /// Legacy compatibility: check if app is in offline mode
    var isOfflineMode: Bool {
        return !networkMonitor.shouldLoadOnlineContent
    }
    
    // MARK: - Network Change Handling (Simplified)
    
    func handleNetworkLoss() {
        // NetworkMonitor handles the strategy change
        AppLogger.general.info("📵 Network lost - NetworkMonitor will handle strategy")
    }
    
    func handleNetworkRestored() {
        // NetworkMonitor handles the strategy change
        AppLogger.general.info("📶 Network restored - NetworkMonitor will handle strategy")
    }
    
    // MARK: - Album/Artist/Genre Queries (Unchanged)
    
    func getOfflineAlbums(for artist: Artist) -> [Album] {
        return offlineAlbums.filter { $0.artist == artist.name }
    }
    
    func getOfflineAlbums(for genre: Genre) -> [Album] {
        return offlineAlbums.filter { $0.genre == genre.value }
    }
    
    func isAlbumAvailableOffline(_ albumId: String) -> Bool {
        return downloadManager.isAlbumDownloaded(albumId)
    }
    
    func isArtistAvailableOffline(_ artistName: String) -> Bool {
        return offlineAlbums.contains { $0.artist == artistName }
    }
    
    func isGenreAvailableOffline(_ genreName: String) -> Bool {
        return offlineAlbums.contains { $0.genre == genreName }
    }
    
    // MARK: - Statistics (Unchanged)
    
    var offlineStats: OfflineStats {
        return OfflineStats(
            albumCount: offlineAlbums.count,
            artistCount: offlineArtists.count,
            genreCount: offlineGenres.count,
            totalSongs: offlineAlbums.reduce(0) { $0 + ($1.songCount ?? 0) }
        )
    }
    
    // MARK: - Reset
    
    func performCompleteReset() {
        cancellables.removeAll()
        AppLogger.general.info("🔄 OfflineManager: Reset completed")
    }
    
    // MARK: - Reactive Updates
    
    private func setupFactoryResetObserver() {
        NotificationCenter.default.addObserver(
            forName: .factoryResetRequested,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.performCompleteReset()
            }
        }
    }

    // MARK: - Private Implementation
    
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
    
    private var cancellables = Set<AnyCancellable>()
}

// MARK: - Supporting Types

struct OfflineStats {
    let albumCount: Int
    let artistCount: Int
    let genreCount: Int
    let totalSongs: Int
    
    var isEmpty: Bool {
        return albumCount == 0
    }
    
    var summary: String {
        if isEmpty {
            return "No offline content"
        }
        
        var parts: [String] = []
        if albumCount > 0 { parts.append("\(albumCount) albums") }
        if artistCount > 0 { parts.append("\(artistCount) artists") }
        if genreCount > 0 { parts.append("\(genreCount) genres") }
        
        return parts.joined(separator: ", ")
    }
}
