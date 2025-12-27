//
//  FavoritesManager.swift
//  NavidromeClient
//
//  Swift 6: @Observable & Optimistic UI
//

import Foundation
import Observation

@MainActor
@Observable
final class FavoritesManager {
    
    // MARK: - State
    var favoriteSongs: Set<String> = [] // IDs of starred songs
    var favoriteAlbums: Set<String> = [] // IDs of starred albums
    
    // Derived for UI
    var starredSongsList: [Song] = []
    
    var isLoading = false
    
    // MARK: - Dependencies
    private weak var service: UnifiedSubsonicService?
    
    // MARK: - Configuration
    func configure(service: UnifiedSubsonicService) {
        self.service = service
    }
    
    // MARK: - Loading
    
    func loadFavoriteSongs() async {
        guard let service = service else { return }
        isLoading = true
        
        do {
            let songs = try await service.getStarredSongs()
            self.starredSongsList = songs
            self.favoriteSongs = Set(songs.map { $0.id })
            
            // If you had albums:
            // self.favoriteAlbums = ...
            
        } catch {
            AppLogger.general.error("Failed to load favorites: \(error)")
        }
        
        isLoading = false
    }
    
    // MARK: - Actions
    
    func isFavorite(songId: String) -> Bool {
        favoriteSongs.contains(songId)
    }
    
    func toggleFavorite(song: Song) async {
        guard let service = service else { return }
        
        let isCurrentlyFavorite = favoriteSongs.contains(song.id)
        
        // 1. Optimistic Update (Instant UI feedback)
        if isCurrentlyFavorite {
            favoriteSongs.remove(song.id)
            if let index = starredSongsList.firstIndex(where: { $0.id == song.id }) {
                starredSongsList.remove(at: index)
            }
        } else {
            favoriteSongs.insert(song.id)
            starredSongsList.append(song)
        }
        
        // 2. Server Sync
        do {
            if isCurrentlyFavorite {
                try await service.unstarSong(song.id)
            } else {
                try await service.starSong(song.id)
            }
        } catch {
            // Revert on failure
            AppLogger.general.error("Failed to toggle favorite: \(error)")
            
            if isCurrentlyFavorite {
                favoriteSongs.insert(song.id)
                starredSongsList.append(song) // Add back
            } else {
                favoriteSongs.remove(song.id)
                starredSongsList.removeAll(where: { $0.id == song.id })
            }
        }
    }
}
