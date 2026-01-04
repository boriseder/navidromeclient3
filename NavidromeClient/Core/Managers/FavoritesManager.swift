//
//  FavoritesManager.swift
//  NavidromeClient
//
//  UPDATED: Swift 6 Concurrency Compliance
//  - Replaced legacy Notification observer with AsyncSequence
//  - Added lifecycle management for observations
//  - Added clearAllFavorites method
//

import Foundation
import SwiftUI
import Observation

@MainActor
@Observable
class FavoritesManager {
    
    // MARK: - State
    private(set) var favoriteSongs: [Song] = []
    private(set) var favoriteSongIds: Set<String> = []
    private(set) var isLoading = false
    private(set) var lastRefresh: Date?
    private(set) var errorMessage: String?
    
    // MARK: - Dependencies
    @ObservationIgnored private weak var service: UnifiedSubsonicService?
    
    // MARK: - Configuration
    private let refreshInterval: TimeInterval = 5 * 60
    
    // MARK: - Observation Lifecycle
    @ObservationIgnored private var observationTasks: [Task<Void, Never>] = []
    
    // MARK: - Setup
    
    init() {
        setupAsyncObservers()
    }
    
    deinit {
        observationTasks.forEach { $0.cancel() }
    }
    
    private func setupAsyncObservers() {
        let resetTask = Task { @MainActor [weak self] in
            for await _ in NotificationCenter.default.notifications(named: .factoryResetRequested) {
                self?.reset()
            }
        }
        observationTasks.append(resetTask)
    }
    
    func configure(service: UnifiedSubsonicService) {
        self.service = service
    }
    
    // MARK: - Public API
    
    func isFavorite(_ songId: String) -> Bool {
        return favoriteSongIds.contains(songId)
    }
    
    func toggleFavorite(_ song: Song) async {
        guard let service = service else {
            errorMessage = "Service not available"
            return
        }
        
        let songId = song.id
        let wasFavorite = isFavorite(songId)
        
        // Optimistic UI Update
        if !wasFavorite {
            favoriteSongs.append(song)
            favoriteSongIds.insert(songId)
        } else {
            favoriteSongs.removeAll { $0.id == songId }
            favoriteSongIds.remove(songId)
        }
        
        do {
            if wasFavorite {
                try await service.unstar(id: songId)
            } else {
                try await service.star(id: songId)
            }
            errorMessage = nil
        } catch {
            // Revert optimization on failure
            if !wasFavorite {
                favoriteSongs.removeAll { $0.id == songId }
                favoriteSongIds.remove(songId)
            } else {
                favoriteSongs.append(song)
                favoriteSongIds.insert(songId)
            }
            errorMessage = error.localizedDescription
        }
    }
    
    func loadFavoriteSongs(forceRefresh: Bool = false) async {
        guard let service = service else {
            errorMessage = "Service not available"
            return
        }
        
        if !forceRefresh && isDataFresh { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // This MUST call a throwing function to make 'catch' reachable
            let songs = try await service.getStarredSongs()
            
            favoriteSongs = songs
            favoriteSongIds = Set(songs.map { $0.id })
            lastRefresh = Date()
            
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func clearAllFavorites() async {
        guard let service = service else {
            errorMessage = "Service not available"
            return
        }
        
        let songsToUnstar = favoriteSongs
        
        // Optimistic UI update
        favoriteSongs.removeAll()
        favoriteSongIds.removeAll()
        
        do {
            // Unstar all songs
            for song in songsToUnstar {
                try await service.unstar(id: song.id)
            }
            errorMessage = nil
            AppLogger.general.info("FavoritesManager: Cleared all favorites")
        } catch {
            // Revert on failure
            favoriteSongs = songsToUnstar
            favoriteSongIds = Set(songsToUnstar.map { $0.id })
            errorMessage = error.localizedDescription
            AppLogger.general.error("FavoritesManager: Failed to clear favorites - \(error)")
        }
    }
    
    // MARK: - Helpers
    
    var isDataFresh: Bool {
        guard let lastRefresh = lastRefresh else { return false }
        return Date().timeIntervalSince(lastRefresh) < refreshInterval
    }
    
    func reset() {
        favoriteSongs = []
        favoriteSongIds = []
        isLoading = false
        lastRefresh = nil
        errorMessage = nil
    }
}
