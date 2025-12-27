//
//  MusicLibraryManager.swift - SWIFT 6 & OBSERVATION MIGRATED
//  NavidromeClient
//
//  CHANGES:
//  - Converted to @Observable (Observation Framework)
//  - Removed Combine/@Published
//  - Implemented Structured Concurrency (withDiscardingTaskGroup)
//  - Removed artificial delays (Task.sleep)
//  - DataLoadingState marked Sendable
//

import Foundation
import SwiftUI
import Observation

@MainActor
@Observable
final class MusicLibraryManager {
    
    // MARK: - Progressive Library Data
    // Note: No @Published needed. Observation handles tracking automatically.
    
    var loadedAlbums: [Album] = []
    var totalAlbumCount: Int = 0
    var albumLoadingState: DataLoadingState = .idle
    
    var loadedArtists: [Artist] = []
    var totalArtistCount: Int = 0
    var artistLoadingState: DataLoadingState = .idle
    
    var loadedGenres: [Genre] = []
    var genreLoadingState: DataLoadingState = .idle
    
    // MARK: - State Management
    var hasLoadedInitialData = false
    var lastRefreshDate: Date?
    var backgroundLoadingProgress: String = ""
    
    // MARK: - Loading Coordination
    private var isCurrentlyLoading = false
    private var pendingNetworkStrategyChange: ContentLoadingStrategy?
    
    private weak var service: UnifiedSubsonicService?
    
    private struct LoadingConfig {
        static let albumBatchSize = 20
        static let artistBatchSize = 25
        static let genreBatchSize = 30
        // Removed artificial batchDelay
    }
    
    init() {
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
        guard !hasLoadedInitialData else {
            AppLogger.general.info("📚 Initial data already loaded - skipping")
            return
        }
        
        guard !isCurrentlyLoading else {
            AppLogger.general.info("📚 Already loading data - skipping")
            return
        }
        
        guard service != nil else {
            AppLogger.general.info("📚 No service configured - skipping initial load")
            return
        }
        
        isCurrentlyLoading = true
        defer { isCurrentlyLoading = false }
        
        AppLogger.general.info("📚 Starting coordinated initial data load...")
        
        // SWIFT 6: Structured Concurrency
        // Using withDiscardingTaskGroup for efficient parallel execution without result collection
        await withDiscardingTaskGroup { group in
            group.addTask {
                await self.loadAlbumsProgressively(reset: true)
            }
            
            group.addTask {
                await self.loadArtistsProgressively(reset: true)
            }
            
            group.addTask {
                await self.loadGenresProgressively(reset: true)
            }
        }
        
        if hasLoadedInitialData {
            lastRefreshDate = Date()
        }

        AppLogger.general.info("📚 Initial data load completed")
    }
    
    func refreshAllData() async {
        guard !isCurrentlyLoading else {
            AppLogger.general.info("Skipping refresh - already loading")
            return
        }
        
        guard NetworkMonitor.shared.shouldLoadOnlineContent else {
            AppLogger.general.info("Skipping refresh - offline")
            return
        }
        
        isCurrentlyLoading = true
        defer { isCurrentlyLoading = false }
        
        AppLogger.general.info("[MusicLibraryManager] Starting coordinated data refresh...")
        
        await withDiscardingTaskGroup { group in
            group.addTask {
                await self.loadAlbumsProgressively(reset: true)
            }
            group.addTask {
                await self.loadArtistsProgressively(reset: true)
            }
            group.addTask {
                await self.loadGenresProgressively(reset: true)
            }
        }
        
        lastRefreshDate = Date()
    }
    
    // MARK: - Network State Handling
    
    private func setupNetworkStateObserver() {
        // Note: NotificationCenter is legacy but acceptable for now.
        // In Phase 5 we can move to AsyncStream.
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
    
    func handleNetworkChange(isOnline: Bool) async {
        await handleNetworkStrategyChange(NetworkMonitor.shared.contentLoadingStrategy)
    }
    
    private func handleNetworkStrategyChange(_ newStrategy: ContentLoadingStrategy) async {
        if isCurrentlyLoading {
            pendingNetworkStrategyChange = newStrategy
            AppLogger.general.info("Network strategy change queued: \(newStrategy.displayName)")
            return
        }
        
        pendingNetworkStrategyChange = nil
        
        switch newStrategy {
        case .online:
            if !isDataFresh, service != nil {
                AppLogger.general.info("Network online - refreshing stale data")
                await refreshAllData()
            } else if isDataFresh {
                AppLogger.general.info("Network online - data is fresh, skipping refresh")
            } else {
                AppLogger.general.info("Network online - waiting for service configuration")
            }
            
        case .offlineOnly, .setupRequired:
            AppLogger.general.info("Network offline - using cached data")
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
        
        guard NetworkMonitor.shared.shouldLoadOnlineContent else {
            albumLoadingState = .completed
            return
        }
        
        let offset = loadedAlbums.count
        let batchSize = LoadingConfig.albumBatchSize
        
        albumLoadingState = offset == 0 ? .loading : .loadingMore
        backgroundLoadingProgress = "Loading albums \(offset + 1)-\(offset + batchSize)..."
        
        do {
            // Removed artificial delay
            
            let newAlbums = try await service.getAllAlbums(
                sortBy: sortBy,
                size: batchSize,
                offset: offset
            )
            
            if newAlbums.isEmpty {
                albumLoadingState = .completed
                totalAlbumCount = loadedAlbums.count
                backgroundLoadingProgress = ""
                return
            }
            
            AlbumMetadataCache.shared.cacheAlbums(newAlbums)
            loadedAlbums.append(contentsOf: newAlbums)
            
            if newAlbums.count < batchSize {
                albumLoadingState = .completed
                totalAlbumCount = loadedAlbums.count
            } else {
                albumLoadingState = .idle
            }
            
            if !hasLoadedInitialData && loadedAlbums.count >= LoadingConfig.albumBatchSize {
                hasLoadedInitialData = true
            }
            
            backgroundLoadingProgress = ""
            
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
        
        guard NetworkMonitor.shared.shouldLoadOnlineContent else {
            artistLoadingState = .completed
            return
        }
        
        artistLoadingState = loadedArtists.isEmpty ? .loading : .loadingMore
        backgroundLoadingProgress = "Loading artists..."
        
        do {
            let allArtists = try await service.getArtists()
            
            loadedArtists = allArtists
            totalArtistCount = allArtists.count
            artistLoadingState = .completed
            backgroundLoadingProgress = ""
            
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
        
        guard NetworkMonitor.shared.shouldLoadOnlineContent else {
            genreLoadingState = .completed
            return
        }
        
        genreLoadingState = .loading
        backgroundLoadingProgress = "Loading genres..."
        
        do {
            let allGenres = try await service.getGenres()
            
            loadedGenres = allGenres
            genreLoadingState = .completed
            backgroundLoadingProgress = ""
            
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
        
        guard NetworkMonitor.shared.shouldLoadOnlineContent else {
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
        
        let errorMessage: String
        if let subsonicError = error as? SubsonicError {
            switch subsonicError {
            case .timeout:
                await handleImmediateOfflineSwitch()
                return
            case .network where subsonicError.isOfflineError:
                await handleOfflineFallback()
                return
            default:
                errorMessage = subsonicError.localizedDescription
            }
        } else {
            errorMessage = error.localizedDescription
        }
        
        switch dataType {
        case "albums":
            albumLoadingState = .error(errorMessage)
        case "artists":
            artistLoadingState = .error(errorMessage)
        case "genres":
            genreLoadingState = .error(errorMessage)
        default:
            break
        }
        
        backgroundLoadingProgress = ""
    }
    
    private func handleImmediateOfflineSwitch() async {
        OfflineManager.shared.switchToOfflineMode()
    }
    
    private func handleOfflineFallback() async {
        OfflineManager.shared.switchToOfflineMode()
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
        backgroundLoadingProgress = ""
        totalAlbumCount = 0
        totalArtistCount = 0
        
        AppLogger.general.info("MusicLibraryManager reset completed")
    }
}

// MARK: - DATA LOADING STATE

enum DataLoadingState: Equatable, Sendable { // Marked Sendable
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
