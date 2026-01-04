//
//  MusicLibraryManager.swift
//  NavidromeClient
//
//  UPDATED: Swift 6 Concurrency Compliance
//  - Increased Batch Size to 100
//  - Restored .byGenre functionality
//

import Foundation
import SwiftUI
import Observation

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
    private(set) var backgroundLoadingProgress: String = ""
    
    // MARK: - Loading Coordination
    @ObservationIgnored private var isCurrentlyLoading = false
    @ObservationIgnored private var pendingNetworkStrategyChange: ContentLoadingStrategy?
    
    @ObservationIgnored private weak var service: UnifiedSubsonicService?
    
    private struct LoadingConfig {
        // Fix: Increased from 20 to 100 to prevent "Limited to 20" feeling
        static let albumBatchSize = 100
        static let artistBatchSize = 100
        static let genreBatchSize = 50
        static let batchDelay: UInt64 = 100_000_000 // Reduced delay
    }
    
    nonisolated init() {
        setupNetworkStateObserver()
        setupFactoryResetObserver()
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
        let freshnessDuration: TimeInterval = 10 * 60
        return Date().timeIntervalSince(lastRefresh) < freshnessDuration
    }
    
    func configure(service: UnifiedSubsonicService) {
        self.service = service
        AppLogger.general.info("MusicLibraryManager configured with UnifiedSubsonicService")
    }
    
    // MARK: - Coordinated Loading

    func loadInitialDataIfNeeded() async {
        guard !hasLoadedInitialData else { return }
        guard !isCurrentlyLoading else { return }
        guard service != nil else { return }
        
        isCurrentlyLoading = true
        defer { isCurrentlyLoading = false }
        
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
        guard !isCurrentlyLoading else { return }
        guard NetworkMonitor.shared.canLoadOnlineContent else { return }
        
        isCurrentlyLoading = true
        defer { isCurrentlyLoading = false }
        
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadAlbumsProgressively(reset: true) }
            group.addTask { await self.loadArtistsProgressively(reset: true) }
            group.addTask { await self.loadGenresProgressively(reset: true) }
        }
        
        lastRefreshDate = Date()
    }
    
    // MARK: - Network State Handling
    
    private nonisolated func setupNetworkStateObserver() {
        NotificationCenter.default.addObserver(
            forName: .contentLoadingStrategyChanged,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let newStrategy = notification.object as? ContentLoadingStrategy {
                Task { @MainActor in
                    await self?.handleNetworkStrategyChange(newStrategy)
                }
            }
        }
    }
    
    private nonisolated func setupFactoryResetObserver() {
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
        case .initializing:
            // Do nothing during app initialization
            break
            
        case .online:
            if !isDataFresh, service != nil {
                await refreshAllData()
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
            
            AlbumMetadataCache.shared.cacheAlbums(newAlbums)
            loadedAlbums.append(contentsOf: newAlbums)
            
            // Fix: Correct logic for completion
            if newAlbums.count < batchSize {
                albumLoadingState = .completed
            } else {
                albumLoadingState = .idle // Allow triggering next batch
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
        isCurrentlyLoading = false
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
