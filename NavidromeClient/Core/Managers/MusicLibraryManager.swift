//
//  MusicLibraryManager.swift
//  NavidromeClient
//
//  UPDATED: Technical Debt Eliminated
//  - FIXED: Observer memory leaks (HIGH)
//  - REMOVED: Unused contentLoadingStrategyChanged observer (MEDIUM)
//  - REMOVED: Unused backgroundLoadingProgress property (MEDIUM)
//  - RENAMED: isCurrentlyLoading → coordinatedLoadInProgress (MEDIUM)
//  - IMPROVED: Better freshness check logic (MEDIUM)
//  - IMPROVED: Magic numbers extracted to constants (LOW)
//  - FIXED: Swift 6 concurrency compliance
//

import Foundation
import SwiftUI
import Observation
@preconcurrency import ObjectiveC

@MainActor
@Observable
class MusicLibraryManager {
    
    // MARK: - Progressive Library Data
    private(set) var loadedAlbums: [Album] = []
    private(set) var totalAlbumCount: Int = 0
    private(set) var albumLoadingState: DataLoadingState = .idle
    
    private(set) var loadedArtists: [Artist] = []
    private(set) var totalArtistCount: Int = 0
    private(set) var artistLoadingState: DataLoadingState = .idle
    
    private(set) var loadedGenres: [Genre] = []
    private(set) var genreLoadingState: DataLoadingState = .idle
    
    // MARK: - State Management
    private(set) var hasLoadedInitialData = false
    private(set) var lastRefreshDate: Date?
    
    // MARK: - Loading Coordination
    // RENAMED: More descriptive name
    @ObservationIgnored private var coordinatedLoadInProgress = false
    @ObservationIgnored private var pendingNetworkStrategyChange: ContentLoadingStrategy?
    
    @ObservationIgnored private weak var service: UnifiedSubsonicService?
    
    // FIXED: Observers now stored for proper cleanup
    @ObservationIgnored private var observers: [NSObjectProtocol] = []
    
    // IMPROVED: Constants extracted
    private struct LoadingConfig {
        static let albumBatchSize = 100
        static let artistBatchSize = 100
        static let genreBatchSize = 50
        static let batchDelay: UInt64 = 100_000_000
    }
    
    private struct CacheConfig {
        static let freshnessDuration: TimeInterval = 10 * 60 // 10 minutes
    }
    
    nonisolated init() {
            // Observers are set up after initialization via NavidromeClientApp
        }
    
    func setupObservers() {
            let observer = NotificationCenter.default.addObserver(
                forName: .factoryResetRequested,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in self?.reset() }
            }
            observers.append(observer) // synchronous — no race
        }
    
    // FIXED: Use MainActor-isolated cleanup instead of deinit
    func cleanup() {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers.removeAll()
    }
    
    // MARK: - PUBLIC API
    var albums: [Album] { loadedAlbums }
    var artists: [Artist] { loadedArtists }
    var genres: [Genre] { loadedGenres }
    
    var isLoading: Bool {
        albumLoadingState.isLoading || artistLoadingState.isLoading || genreLoadingState.isLoading
    }
    
    var isLoadingInBackground: Bool {
        isLoading && hasLoadedInitialData
    }
    
    var isDataFresh: Bool {
        guard let lastRefresh = lastRefreshDate else { return false }
        return Date().timeIntervalSince(lastRefresh) < CacheConfig.freshnessDuration
    }
    
    func configure(service: UnifiedSubsonicService) {
        self.service = service
        AppLogger.general.info("MusicLibraryManager configured with UnifiedSubsonicService")
    }
    
    // MARK: - Coordinated Loading

    func loadInitialDataIfNeeded() async {
        guard !hasLoadedInitialData else { return }
        guard !coordinatedLoadInProgress else { return }
        guard service != nil else { return }
        
        coordinatedLoadInProgress = true
        defer { coordinatedLoadInProgress = false }
        
        AppLogger.general.info("📚 Starting coordinated initial data load...")
        
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadAlbumsProgressively(reset: true) }
            group.addTask { await self.loadArtistsProgressively(reset: true) }
            group.addTask { await self.loadGenresProgressively(reset: true) }
        }
        
        if !loadedAlbums.isEmpty {
            hasLoadedInitialData = true
            lastRefreshDate = Date()
        }
    }
    
    func refreshAllData() async {
        guard !coordinatedLoadInProgress else { return }
        guard NetworkMonitor.shared.canLoadOnlineContent else { return }
        
        coordinatedLoadInProgress = true
        defer { coordinatedLoadInProgress = false }
        
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadAlbumsProgressively(reset: true) }
            group.addTask { await self.loadArtistsProgressively(reset: true) }
            group.addTask { await self.loadGenresProgressively(reset: true) }
        }
        
        lastRefreshDate = Date()
    }
    
    // MARK: - Network State Handling
        
    private func storeObserver(_ observer: NSObjectProtocol) {
        observers.append(observer)
    }
    
    func handleNetworkChange(isOnline: Bool) async {
        await handleNetworkStrategyChange(NetworkMonitor.shared.contentLoadingStrategy)
    }
    
    // IMPROVED: Better freshness logic
    private func handleNetworkStrategyChange(_ newStrategy: ContentLoadingStrategy) async {
        if coordinatedLoadInProgress {
            pendingNetworkStrategyChange = newStrategy
            return
        }
        
        pendingNetworkStrategyChange = nil
        
        switch newStrategy {
        case .initializing:
            // Do nothing during app initialization
            break
            
        case .online:
            if service != nil {
                if !hasLoadedInitialData {
                    await loadInitialDataIfNeeded()
                } else if !isDataFresh {
                    await refreshAllData()
                }
            }
            
        case .offlineOnly, .setupRequired:
            break
        }
        
        if let pendingStrategy = pendingNetworkStrategyChange {
            await handleNetworkStrategyChange(pendingStrategy)
        }
    }
    
    // MARK: - ALBUMS LOADING
    
    func loadAlbumsProgressively(
        sortBy: ContentService.AlbumSortType = .alphabetical,
        reset: Bool = false
    ) async {
        if reset {
            loadedAlbums = []
            totalAlbumCount = 0
            albumLoadingState = .idle
        }
        
        guard albumLoadingState.canLoadMore else { return }
        guard let service = service else {
            albumLoadingState = .error("Service not available")
            return
        }
        
        guard NetworkMonitor.shared.canLoadOnlineContent else {
            albumLoadingState = .completed
            return
        }
        
        let offset = loadedAlbums.count
        let batchSize = LoadingConfig.albumBatchSize
        
        albumLoadingState = offset == 0 ? .loading : .loadingMore
        
        do {
            let newAlbums = try await service.getAllAlbums(
                sortBy: sortBy,
                size: batchSize,
                offset: offset
            )
            
            if newAlbums.isEmpty {
                albumLoadingState = .completed
                return
            }
            
            await AlbumMetadataCache.shared.cacheAlbums(newAlbums)
            loadedAlbums.append(contentsOf: newAlbums)
            
            if newAlbums.count < batchSize {
                albumLoadingState = .completed
            } else {
                albumLoadingState = .idle
            }
            
            totalAlbumCount = loadedAlbums.count
            
        } catch {
            await handleLoadingError(error, for: "albums")
        }
    }
    
    // MARK: - ARTISTS LOADING
    
    func loadArtistsProgressively(reset: Bool = false) async {
        if reset {
            loadedArtists = []
            totalArtistCount = 0
            artistLoadingState = .idle
        }
        
        guard artistLoadingState.canLoadMore else { return }
        guard let service = service else {
            artistLoadingState = .error("Service not available")
            return
        }
        
        guard NetworkMonitor.shared.canLoadOnlineContent else {
            artistLoadingState = .completed
            return
        }
        
        artistLoadingState = loadedArtists.isEmpty ? .loading : .loadingMore
        
        do {
            let allArtists = try await service.getArtists()
            loadedArtists = allArtists
            totalArtistCount = allArtists.count
            artistLoadingState = .completed
        } catch {
            await handleLoadingError(error, for: "artists")
        }
    }
    
    // MARK: - GENRES LOADING
    
    func loadGenresProgressively(reset: Bool = false) async {
        if reset {
            loadedGenres = []
            genreLoadingState = .idle
        }
        
        guard genreLoadingState.canLoadMore else { return }
        guard let service = service else {
            genreLoadingState = .error("Service not available")
            return
        }
        
        guard NetworkMonitor.shared.canLoadOnlineContent else {
            genreLoadingState = .completed
            return
        }
        
        genreLoadingState = .loading
        
        do {
            let allGenres = try await service.getGenres()
            loadedGenres = allGenres
            genreLoadingState = .completed
        } catch {
            await handleLoadingError(error, for: "genres")
        }
    }
    
    // MARK: - Load More
    
    func loadMoreAlbumsIfNeeded() async {
        await loadAlbumsProgressively()
    }
    
    // MARK: - Artist/Genre Detail Support
    
    func loadAlbums(context: AlbumCollectionContext) async throws -> [Album] {
        guard let service = service else {
            throw URLError(.networkConnectionLost)
        }
        
        guard NetworkMonitor.shared.canLoadOnlineContent else {
            throw URLError(.notConnectedToInternet)
        }
        
        switch context {
        case .byArtist(let artist):
            return try await service.getAlbumsByArtist(artistId: artist.id)
        
        case .byGenre(let genre):
            return try await service.getAlbumsByGenre(genre: genre.value)
        }
    }
    
    // MARK: - Private Implementation
    
    private func handleLoadingError(_ error: Error, for dataType: String) async {
        AppLogger.general.error("Failed to load \(dataType): \(error)")
        
        let errorMessage = error.localizedDescription
        
        switch dataType {
        case "albums": albumLoadingState = .error(errorMessage)
        case "artists": artistLoadingState = .error(errorMessage)
        case "genres": genreLoadingState = .error(errorMessage)
        default: break
        }
    }
    
    // MARK: - Reset
    
    func reset() {
        coordinatedLoadInProgress = false
        pendingNetworkStrategyChange = nil
        loadedAlbums = []
        loadedArtists = []
        loadedGenres = []
        albumLoadingState = .idle
        artistLoadingState = .idle
        genreLoadingState = .idle
        hasLoadedInitialData = false
        lastRefreshDate = nil
        totalAlbumCount = 0
        totalArtistCount = 0
        
        AppLogger.general.info("MusicLibraryManager reset completed")
    }
}

// MARK: - DATA LOADING STATE

enum DataLoadingState: Equatable {
    case idle
    case loading
    case loadingMore
    case completed
    case error(String)
    
    var isLoading: Bool {
        switch self {
        case .loading, .loadingMore: return true
        default: return false
        }
    }
    
    var canLoadMore: Bool {
        switch self {
        case .idle, .error: return true
        case .loading, .loadingMore, .completed: return false
        }
    }
}
