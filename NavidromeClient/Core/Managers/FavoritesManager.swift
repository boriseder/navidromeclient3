//
//  FavoritesManager.swift - FIXED: Pure Facade Pattern
//  NavidromeClient
//
//
//  FavoritesManager.swift
//  Manages user's favorite songs with optimistic updates
//  Responsibilities: Star/unstar songs, maintain favorites list, sync with server


import Foundation
import SwiftUI

@MainActor
class FavoritesManager: ObservableObject {
    // REMOVED: static let shared = FavoritesManager()
    
    // MARK: - Published State
    @Published private(set) var favoriteSongs: [Song] = []
    @Published private(set) var favoriteSongIds: Set<String> = []
    @Published private(set) var isLoading = false
    @Published private(set) var lastRefresh: Date?
    @Published private(set) var errorMessage: String?
    
    // MARK: - Service Dependency
    private weak var service: UnifiedSubsonicService?
    
    // MARK: - Configuration
    private let refreshInterval: TimeInterval = 5 * 60
    
    init() {
        setupFactoryResetObserver()
    }
    
    // MARK: - Setup
    
    private func setupFactoryResetObserver() {
        NotificationCenter.default.addObserver(
            forName: .factoryResetRequested,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.reset()
            }
        }
    }
    
    // MARK: - Service Configuration
    
    func configure(service: UnifiedSubsonicService) {
        self.service = service
        AppLogger.general.info("FavoritesManager configured with UnifiedSubsonicService facade")
    }
    
    // MARK: - Public API
    
    func isFavorite(_ songId: String) -> Bool {
        return favoriteSongIds.contains(songId)
    }
    
    func toggleFavorite(_ song: Song) async {
        guard let service = service else {
            errorMessage = "Service not available"
            AppLogger.general.info("[FavoritesManager] UnifiedSubsonicService not configured")
            return
        }
        
        let songId = song.id
        let wasFavorite = isFavorite(songId)
        
        updateUIOptimistically(song: song, isFavorite: !wasFavorite)
        
        do {
            if wasFavorite {
                try await service.unstarSong(songId)
            } else {
                try await service.starSong(songId)
            }
            
            errorMessage = nil
            
        } catch {
            AppLogger.general.info("Failed to \(wasFavorite ? "unstar" : "star") song: \(error)")
            updateUIOptimistically(song: song, isFavorite: wasFavorite)
            errorMessage = error.localizedDescription
        }
    }
    
    func loadFavoriteSongs(forceRefresh: Bool = false) async {
        guard let service = service else {
            errorMessage = "Service not available"
            return
        }
        
        guard shouldRefresh || forceRefresh else {
            AppLogger.general.info("Favorites are fresh, skipping refresh")
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let songs = try await service.getStarredSongs()
            
            favoriteSongs = songs
            favoriteSongIds = Set(songs.map { $0.id })
            lastRefresh = Date()
            
        } catch {
            AppLogger.general.info("Failed to load favorite songs: \(error)")
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func clearAllFavorites() async {
        guard let service = service else {
            errorMessage = "Service not available"
            return
        }
        
        let songIds = Array(favoriteSongIds)
        guard !songIds.isEmpty else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            try await service.unstarSongs(songIds)
            
            favoriteSongs.removeAll()
            favoriteSongIds.removeAll()
            
        } catch {
            AppLogger.general.info("Failed to clear favorites: \(error)")
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    // MARK: - Network State Handling
    
    func handleNetworkChange(isOnline: Bool) async {
        guard isOnline, !isDataFresh else { return }
        
        AppLogger.general.info("Network restored - refreshing favorites")
        await loadFavoriteSongs(forceRefresh: true)
    }
    
    // MARK: - Stats & Info
    
    var favoriteCount: Int {
        return favoriteSongs.count
    }
    
    var isDataFresh: Bool {
        guard let lastRefresh = lastRefresh else { return false }
        return Date().timeIntervalSince(lastRefresh) < refreshInterval
    }
    
    private var shouldRefresh: Bool {
        return !isDataFresh
    }
    
    func getFavoriteStats() -> FavoriteStats {
        let totalDuration = favoriteSongs.reduce(0) { $0 + ($1.duration ?? 0) }
        let uniqueArtists = Set(favoriteSongs.compactMap { $0.artist }).count
        let uniqueAlbums = Set(favoriteSongs.compactMap { $0.album }).count
        
        return FavoriteStats(
            songCount: favoriteSongs.count,
            totalDuration: totalDuration,
            uniqueArtists: uniqueArtists,
            uniqueAlbums: uniqueAlbums,
            lastRefresh: lastRefresh
        )
    }
    
    // MARK: - Private Methods
    
    private func updateUIOptimistically(song: Song, isFavorite: Bool) {
        if isFavorite {
            if !favoriteSongIds.contains(song.id) {
                favoriteSongs.append(song)
                favoriteSongIds.insert(song.id)
            }
        } else {
            favoriteSongs.removeAll { $0.id == song.id }
            favoriteSongIds.remove(song.id)
        }
        
        objectWillChange.send()
    }
    
    // MARK: - Reset
    
    func reset() {
        favoriteSongs.removeAll()
        favoriteSongIds.removeAll()
        isLoading = false
        lastRefresh = nil
        errorMessage = nil
        service = nil
        
        AppLogger.general.info("FavoritesManager reset completed")
    }
}

// MARK: - Supporting Types

struct FavoriteStats {
    let songCount: Int
    let totalDuration: Int
    let uniqueArtists: Int
    let uniqueAlbums: Int
    let lastRefresh: Date?
    
    var formattedDuration: String {
        let hours = totalDuration / 3600
        let minutes = (totalDuration % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes) minutes"
        }
    }
    
    var summary: String {
        return "\(songCount) songs, \(uniqueArtists) artists, \(uniqueAlbums) albums"
    }
}
