//
//  SongManager.swift
//  NavidromeClient
//
//  SIMPLIFIED: Focused on core responsibilities
//  - In-memory song cache
//  - Task deduplication for parallel requests
//  - Smart loading with online/offline fallback
//
//  REMOVED:
//  - Legacy fallback logic (DownloadManager provides complete metadata)
//  - Stream URL pass-through (belongs to MediaService)
//  - Batch operations (belongs to discovery/content layers)

import Foundation
import SwiftUI

@MainActor
class SongManager: ObservableObject {
    
    // MARK: - Published State
    
    @Published private(set) var albumSongs: [String: [Song]] = [:]
    
    // MARK: - Private State
    
    private var loadTasks: [String: Task<[Song], Never>] = [:]
    
    // MARK: - Dependencies
    
    private weak var service: UnifiedSubsonicService?
    private let downloadManager: DownloadManager
    
    // MARK: - Initialization
    
    init(downloadManager: DownloadManager = DownloadManager.shared) {
        self.downloadManager = downloadManager
        setupFactoryResetObserver()
    }
    
    deinit {
        loadTasks.values.forEach { $0.cancel() }
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
    
    // MARK: - Configuration
    
    func configure(service: UnifiedSubsonicService) {
        self.service = service
        AppLogger.general.info("SongManager configured with UnifiedSubsonicService")
    }
    
    // MARK: - Primary API: Smart Song Loading
    
    /// Load songs for an album with intelligent caching and offline fallback
    /// - Returns cached songs if available
    /// - Deduplicates parallel requests for the same album
    /// - Tries online first, falls back to offline if needed
    func loadSongs(for albumId: String) async -> [Song] {
        guard service != nil else {
            AppLogger.general.info("SongManager.loadSongs called before service configured - using offline")
            return await loadOfflineSongs(for: albumId)
        }
        
        // Return cached if available
        if let cached = albumSongs[albumId], !cached.isEmpty {
            return cached
        }
        
        // Join existing task if loading
        if let existingTask = loadTasks[albumId] {
            AppLogger.general.info("Joining existing load task for album \(albumId)")
            return await existingTask.value
        }
        
        // Create new load task
        let task = Task {
            defer {
                loadTasks.removeValue(forKey: albumId)
            }
            
            guard !Task.isCancelled else {
                AppLogger.general.info("Load cancelled for album \(albumId)")
                return [Song]()
            }
            
            let songs = await loadWithFallback(for: albumId)
            
            if !songs.isEmpty {
                albumSongs[albumId] = songs
            }
            
            return songs
        }
        
        loadTasks[albumId] = task
        return await task.value
    }
    
    // MARK: - Cache Management
    
    /// Get cached songs without loading
    func getCachedSongs(for albumId: String) -> [Song]? {
        return albumSongs[albumId]
    }
    
    /// Check if songs are cached
    func hasCachedSongs(for albumId: String) -> Bool {
        return albumSongs[albumId] != nil && !albumSongs[albumId]!.isEmpty
    }
    
    /// Clear cache for specific album
    func clearCache(for albumId: String) {
        albumSongs.removeValue(forKey: albumId)
        loadTasks.removeValue(forKey: albumId)
        AppLogger.general.info("Cleared cache for album \(albumId)")
    }
    
    /// Clear all cached songs
    func clearSongCache() {
        let cacheSize = albumSongs.count
        albumSongs.removeAll()
        loadTasks.removeAll()
        AppLogger.general.info("Cleared song cache (\(cacheSize) albums)")
    }
    
    /// Preload songs for multiple albums
    func preloadSongs(for albumIds: [String]) async {
        await withTaskGroup(of: Void.self) { group in
            for albumId in albumIds.prefix(5) {
                group.addTask {
                    _ = await self.loadSongs(for: albumId)
                }
            }
        }
    }
    
    /// Warm up cache for visible albums
    func warmUpCache(for albumIds: [String]) async {
        let uncachedAlbums = albumIds.filter { !hasCachedSongs(for: $0) }
        
        if !uncachedAlbums.isEmpty {
            AppLogger.general.info("Warming up cache for \(uncachedAlbums.count) albums")
            await preloadSongs(for: Array(uncachedAlbums.prefix(3)))
        }
    }
    
    // MARK: - Statistics
    
    /// Get total number of cached songs
    func getCachedSongCount() -> Int {
        return albumSongs.values.reduce(0) { $0 + $1.count }
    }
    
    /// Get cache statistics
    func getCacheStats() -> SongCacheStats {
        let totalCachedSongs = getCachedSongCount()
        let cachedAlbums = albumSongs.count
        let offlineAlbums = downloadManager.downloadedAlbums.count
        let offlineSongs = downloadManager.downloadedAlbums.reduce(0) { $0 + $1.songs.count }
        
        return SongCacheStats(
            totalCachedSongs: totalCachedSongs,
            cachedAlbums: cachedAlbums,
            offlineAlbums: offlineAlbums,
            offlineSongs: offlineSongs
        )
    }
    
    /// Check if album has offline songs available
    func hasSongsAvailableOffline(for albumId: String) -> Bool {
        return downloadManager.isAlbumDownloaded(albumId)
    }
    
    /// Get offline song count for album
    func getOfflineSongCount(for albumId: String) -> Int {
        return downloadManager.getDownloadedSongs(for: albumId).count
    }
    
    // MARK: - Reset
    
    func reset() {
        AppLogger.general.info("Cancelling \(loadTasks.count) active load tasks")
        loadTasks.values.forEach { $0.cancel() }
        loadTasks.removeAll()
        
        albumSongs.removeAll()
        service = nil
        AppLogger.general.info("SongManager reset completed")
    }
    
    // MARK: - Diagnostics
    
    func getServiceDiagnostics() -> SongManagerDiagnostics {
        return SongManagerDiagnostics(
            hasService: service != nil,
            cachedAlbums: albumSongs.count,
            totalCachedSongs: getCachedSongCount(),
            activeLoading: loadTasks.count
        )
    }
    
    #if DEBUG
    func printServiceDiagnostics() {
        let diagnostics = getServiceDiagnostics()
        AppLogger.general.info(diagnostics.summary)
    }
    #endif
    
    // MARK: - Private Implementation
    
    /// Load songs with intelligent fallback strategy
    private func loadWithFallback(for albumId: String) async -> [Song] {
        // Priority 1: Try offline first if album is downloaded
        if downloadManager.isAlbumDownloaded(albumId) {
            AppLogger.general.info("Loading offline songs for album \(albumId)")
            let offlineSongs = await loadOfflineSongs(for: albumId)
            if !offlineSongs.isEmpty {
                return offlineSongs
            }
        }
        
        // Priority 2: Try online if network allows
        if NetworkMonitor.shared.canLoadOnlineContent && !OfflineManager.shared.isOfflineMode {
            AppLogger.general.info("Loading online songs for album \(albumId)")
            let onlineSongs = await loadOnlineSongs(for: albumId)
            if !onlineSongs.isEmpty {
                return onlineSongs
            }
        }
        
        // Priority 3: Final offline fallback
        AppLogger.general.info("Final offline fallback for album \(albumId)")
        return await loadOfflineSongs(for: albumId)
    }
    
    /// Load songs from server via UnifiedSubsonicService
    private func loadOnlineSongs(for albumId: String) async -> [Song] {
        guard let service = service else {
            AppLogger.general.info("UnifiedSubsonicService not available for online song loading")
            return []
        }
        
        do {
            let songs = try await service.getSongs(for: albumId)
            AppLogger.general.info("Loaded \(songs.count) online songs for album \(albumId)")
            return songs
        } catch {
            AppLogger.general.info("Failed to load online songs for album \(albumId): \(error)")
            return []
        }
    }
    
    /// Load songs from local downloads
    private func loadOfflineSongs(for albumId: String) async -> [Song] {
        let downloadedSongs = downloadManager.getDownloadedSongs(for: albumId)
        
        if downloadedSongs.isEmpty {
            AppLogger.general.info("No offline songs found for album \(albumId)")
            return []
        }
        
        let songs = downloadedSongs.map { $0.toSong() }
        AppLogger.general.info("Loaded \(songs.count) offline songs for album \(albumId)")
        return songs
    }
}

// MARK: - Supporting Types

struct SongCacheStats {
    let totalCachedSongs: Int
    let cachedAlbums: Int
    let offlineAlbums: Int
    let offlineSongs: Int
    
    var cacheHitRate: Double {
        guard offlineSongs > 0 else { return 0 }
        return Double(totalCachedSongs) / Double(offlineSongs) * 100
    }
    
    var summary: String {
        return "Cached: \(cachedAlbums) albums (\(totalCachedSongs) songs), Offline: \(offlineAlbums) albums (\(offlineSongs) songs)"
    }
}

struct SongManagerDiagnostics {
    let hasService: Bool
    let cachedAlbums: Int
    let totalCachedSongs: Int
    let activeLoading: Int
    
    var healthScore: Double {
        var score = 0.0
        
        if hasService { score += 0.5 }
        if activeLoading < 5 { score += 0.3 }
        if cachedAlbums > 0 { score += 0.2 }
        
        return min(score, 1.0)
    }
    
    var statusDescription: String {
        let score = healthScore * 100
        
        switch score {
        case 90...100: return "Excellent"
        case 70..<90: return "Good"
        case 50..<70: return "Fair"
        default: return "Needs Service"
        }
    }
    
    var summary: String {
        return """
        SONGMANAGER DIAGNOSTICS:
        - UnifiedSubsonicService: \(hasService ? "Available" : "Not Available")
        - Cached Albums: \(cachedAlbums)
        - Cached Songs: \(totalCachedSongs)
        - Active Loading: \(activeLoading)
        - Health: \(statusDescription)
        """
    }
}
