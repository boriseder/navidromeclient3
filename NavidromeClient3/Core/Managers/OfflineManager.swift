//
//  OfflineManager.swift
//  NavidromeClient3
//
//  Swift 6: Connected to DownloadManager & NetworkMonitor
//

import Foundation
import Observation

@MainActor
@Observable
final class OfflineManager {
    static let shared = OfflineManager()
    
    private let downloadManager = DownloadManager.shared
    
    // MARK: - Real Data
    var offlineAlbums: [Album] {
        // Map downloaded metadata back to domain Album objects
        downloadManager.downloadedAlbums.map { dl in
            Album(
                id: dl.id,
                name: dl.title,
                artist: dl.artist,
                year: dl.year,
                genre: dl.genre,
                coverArt: dl.coverArtId,
                coverArtId: dl.coverArtId,
                duration: Int(dl.totalDuration),
                songCount: dl.songCount,
                artistId: nil,
                displayArtist: dl.artist
            )
        }
    }
    
    private init() {
        setupFactoryResetObserver()
    }
    
    // MARK: - Derived Data
    
    var offlineArtists: [Artist] {
        extractUniqueArtists(from: offlineAlbums)
    }
    
    var offlineGenres: [Genre] {
        extractUniqueGenres(from: offlineAlbums)
    }
    
    // MARK: - Public API
    
    var isOfflineMode: Bool {
        return !NetworkMonitor.shared.shouldLoadOnlineContent
    }
    
    // FIX: Added missing methods required by UI
    func switchToOnlineMode() {
        NetworkMonitor.shared.setManualOfflineMode(false)
    }
    
    func switchToOfflineMode() {
        NetworkMonitor.shared.setManualOfflineMode(true)
    }
    
    func toggleOfflineMode() {
        // Delegate state management to NetworkMonitor
        let currentStrategy = NetworkMonitor.shared.contentLoadingStrategy
        
        switch currentStrategy {
        case .online:
            switchToOfflineMode()
        case .offlineOnly(let reason):
            // Only switch back if user previously chose to go offline, or force it
            if reason == .userChoice {
                switchToOnlineMode()
            } else {
                // If network is down, we can't really switch to online, but we can try
                switchToOnlineMode()
            }
        case .setupRequired:
            break
        }
    }
    
    // MARK: - Queries
    
    func getOfflineAlbums(for artist: Artist) -> [Album] {
        return offlineAlbums.filter { $0.artist == artist.name }
    }
    
    func getOfflineAlbums(for genre: Genre) -> [Album] {
        return offlineAlbums.filter { $0.genre == genre.value }
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
    
    private func setupFactoryResetObserver() {
        // Observer logic if needed, although DownloadManager handles deletion
    }
}
