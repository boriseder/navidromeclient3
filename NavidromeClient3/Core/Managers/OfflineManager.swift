//
//  OfflineManager.swift - SWIFT 6 & OBSERVATION MIGRATED
//  NavidromeClient
//
//  CHANGES:
//  - Converted to @Observable
//  - Removed Combine (AnyCancellable)
//  - Removed ObservableObject/@Published
//

import Foundation
import SwiftUI
import Observation

@MainActor
@Observable
final class OfflineManager {
    static let shared = OfflineManager()
    
    // MARK: - Offline Data Management
    // Computed properties are automatically tracked by Observation
    
    var offlineAlbums: [Album] {
        let downloadedAlbumIds = Set(downloadManager.downloadedAlbums.map { $0.albumId })
        return AlbumMetadataCache.shared.getAlbums(ids: downloadedAlbumIds)
    }
    
    var offlineArtists: [Artist] {
        extractUniqueArtists(from: offlineAlbums)
    }
    
    var offlineGenres: [Genre] {
        extractUniqueGenres(from: offlineAlbums)
    }
    
    // MARK: - Dependencies
    
    private let downloadManager = DownloadManager.shared
    private let networkMonitor = NetworkMonitor.shared
    
    private init() {
        setupFactoryResetObserver()
    }
    
    // MARK: - Public API
    
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
    
    // MARK: - UI State Properties
    
    var isOfflineMode: Bool {
        return !networkMonitor.shouldLoadOnlineContent
    }
    
    // MARK: - Network Change Handling
    
    func handleNetworkLoss() {
        AppLogger.general.info("📵 Network lost - NetworkMonitor will handle strategy")
    }
    
    func handleNetworkRestored() {
        AppLogger.general.info("📶 Network restored - NetworkMonitor will handle strategy")
    }
    
    // MARK: - Album/Artist/Genre Queries
    
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
    
    // MARK: - Statistics
    
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
        AppLogger.general.info("🔄 OfflineManager: Reset completed")
    }
    
    // MARK: - Reactive Updates
    
    private func setupFactoryResetObserver() {
        NotificationCenter.default.addObserver(
            forName: .factoryResetRequested,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.performCompleteReset()
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
}
