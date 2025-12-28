//
//  MusicLibraryManager.swift
//  NavidromeClient
//
//  Swift 6: Fixed Method Calls
//

import Foundation
import SwiftUI
import Observation

@MainActor
@Observable
final class MusicLibraryManager {
    
    var loadedAlbums: [Album] = []
    var totalAlbumCount: Int = 0
    var albumLoadingState: DataLoadingState = .idle
    
    var loadedArtists: [Artist] = []
    var totalArtistCount: Int = 0
    var artistLoadingState: DataLoadingState = .idle
    
    var loadedGenres: [Genre] = []
    var genreLoadingState: DataLoadingState = .idle
    
    var hasLoadedInitialData = false
    var lastRefreshDate: Date?
    var backgroundLoadingProgress: String = ""
    
    private var isCurrentlyLoading = false
    private var pendingNetworkStrategyChange: ContentLoadingStrategy?
    
    private weak var service: UnifiedSubsonicService?
    
    init() {
        setupNetworkStateObserver()
        setupFactoryResetObserver()
    }
    
    var isLoading: Bool {
        albumLoadingState.isLoading || artistLoadingState.isLoading || genreLoadingState.isLoading
    }
    
    var isDataFresh: Bool {
        guard let lastRefresh = lastRefreshDate else { return false }
        return Date().timeIntervalSince(lastRefresh) < 10 * 60
    }
    
    func configure(service: UnifiedSubsonicService) {
        self.service = service
    }
    
    // MARK: - Coordinated Loading
    
    func loadInitialDataIfNeeded() async {
        guard !hasLoadedInitialData, !isCurrentlyLoading, service != nil else { return }
        
        isCurrentlyLoading = true
        defer { isCurrentlyLoading = false }
        
        await withDiscardingTaskGroup { group in
            group.addTask { await self.loadAlbumsProgressively(reset: true) }
            group.addTask { await self.loadArtistsProgressively(reset: true) }
            group.addTask { await self.loadGenresProgressively(reset: true) }
        }
        
        if hasLoadedInitialData { lastRefreshDate = Date() }
    }
    
    func refreshAllData() async {
        guard !isCurrentlyLoading, NetworkMonitor.shared.shouldLoadOnlineContent else { return }
        isCurrentlyLoading = true
        defer { isCurrentlyLoading = false }
        
        await withDiscardingTaskGroup { group in
            group.addTask { await self.loadAlbumsProgressively(reset: true) }
            group.addTask { await self.loadArtistsProgressively(reset: true) }
            group.addTask { await self.loadGenresProgressively(reset: true) }
        }
        lastRefreshDate = Date()
    }
    
    // MARK: - Specific Loading Methods
    
    func loadAlbums(for artist: Artist) async throws -> [Album] {
        guard let service = service else { return [] }
        return try await service.getAlbumsByArtist(artistId: artist.id)
    }
    
    func loadAlbums(for genre: Genre) async throws -> [Album] {
        guard let service = service else { return [] }
        // FIX: Removed 'size' argument to match UnifiedSubsonicService signature
        return try await service.getAlbumsByGenre(genre: genre.value)
    }
    
    // MARK: - Network
    
    private func setupNetworkStateObserver() {
        NotificationCenter.default.addObserver(forName: .contentLoadingStrategyChanged, object: nil, queue: .main) { [weak self] notification in
            if let strategy = notification.object as? ContentLoadingStrategy {
                Task { @MainActor in await self?.handleNetworkStrategyChange(strategy) }
            }
        }
    }
    
    private func setupFactoryResetObserver() {
        NotificationCenter.default.addObserver(forName: .factoryResetRequested, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.reset() }
        }
    }
    
    func handleNetworkChange(isOnline: Bool) async {
        await handleNetworkStrategyChange(NetworkMonitor.shared.contentLoadingStrategy)
    }
    
    private func handleNetworkStrategyChange(_ newStrategy: ContentLoadingStrategy) async {
        if isCurrentlyLoading {
            pendingNetworkStrategyChange = newStrategy
            return
        }
        pendingNetworkStrategyChange = nil
        
        switch newStrategy {
        case .online:
            if !isDataFresh, service != nil { await refreshAllData() }
        case .offlineOnly, .setupRequired:
            break
        }
        
        if let pending = pendingNetworkStrategyChange {
            await handleNetworkStrategyChange(pending)
        }
    }
    
    // MARK: - Progressive Loading
    
    func loadAlbumsProgressively(
        sortBy: AlbumSortType = .alphabetical,
        reset: Bool = false
    ) async {
        if reset {
            loadedAlbums = []
            totalAlbumCount = 0
            albumLoadingState = .idle
        }
        
        guard albumLoadingState.canLoadMore, let service = service, NetworkMonitor.shared.shouldLoadOnlineContent else { return }
        
        let offset = loadedAlbums.count
        albumLoadingState = offset == 0 ? .loading : .loadingMore
        
        do {
            let newAlbums = try await service.getAllAlbums(sortBy: sortBy, size: 20, offset: offset)
            
            if newAlbums.isEmpty {
                albumLoadingState = .completed
            } else {
                loadedAlbums.append(contentsOf: newAlbums)
                albumLoadingState = newAlbums.count < 20 ? .completed : .idle
            }
            
            if !hasLoadedInitialData && loadedAlbums.count >= 20 { hasLoadedInitialData = true }
            
        } catch {
            await handleLoadingError(error, for: "albums")
        }
    }
    
    func loadArtistsProgressively(reset: Bool = false) async {
        if reset {
            loadedArtists = []
            artistLoadingState = .idle
        }
        
        guard artistLoadingState.canLoadMore, let service = service, NetworkMonitor.shared.shouldLoadOnlineContent else { return }
        
        artistLoadingState = loadedArtists.isEmpty ? .loading : .loadingMore
        
        do {
            let allArtists = try await service.getArtists()
            loadedArtists = allArtists
            artistLoadingState = .completed
        } catch {
            await handleLoadingError(error, for: "artists")
        }
    }
    
    func loadGenresProgressively(reset: Bool = false) async {
        if reset {
            loadedGenres = []
            genreLoadingState = .idle
        }
        
        guard genreLoadingState.canLoadMore, let service = service, NetworkMonitor.shared.shouldLoadOnlineContent else { return }
        
        genreLoadingState = .loading
        
        do {
            let allGenres = try await service.getGenres()
            loadedGenres = allGenres
            genreLoadingState = .completed
        } catch {
            await handleLoadingError(error, for: "genres")
        }
    }
    
    private func handleLoadingError(_ error: Error, for type: String) async {
        AppLogger.general.error("Failed to load \(type): \(error)")
        switch type {
        case "albums": albumLoadingState = .error(error.localizedDescription)
        case "artists": artistLoadingState = .error(error.localizedDescription)
        case "genres": genreLoadingState = .error(error.localizedDescription)
        default: break
        }
    }
    
    func reset() {
        isCurrentlyLoading = false
        loadedAlbums = []
        loadedArtists = []
        loadedGenres = []
        albumLoadingState = .idle
        artistLoadingState = .idle
        genreLoadingState = .idle
        hasLoadedInitialData = false
        lastRefreshDate = nil
    }
}

enum DataLoadingState: Equatable, Sendable {
    case idle, loading, loadingMore, completed
    case error(String)
    
    var isLoading: Bool {
        switch self { case .loading, .loadingMore: return true; default: return false }
    }
    var canLoadMore: Bool {
        switch self { case .idle, .error: return true; default: return false }
    }
}
