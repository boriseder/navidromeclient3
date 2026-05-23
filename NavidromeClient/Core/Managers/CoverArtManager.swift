//
//  CoverArtManager.swift
//  NavidromeClient
//
//  REFACTORED: Step 3 — ImageCacheActor
//  @MainActor holds only observable UI state.
//  All cache work delegated to ImageCacheActor.
//

import Foundation
import SwiftUI
import Observation

struct CoverArtCacheStats: Sendable {
    let diskCount: Int
    let diskSize: Int64
    let activeRequests: Int
    let errorCount: Int

    var diskSizeFormatted: String {
        ByteCountFormatter.string(fromByteCount: diskSize, countStyle: .file)
    }
    var summary: String {
        "Active: \(activeRequests) | Errors: \(errorCount) | Disk: \(diskCount) (\(diskSizeFormatted))"
    }
}

struct CoverArtHealthStatus: Sendable {
    let isHealthy: Bool
    let statusDescription: String
}

@MainActor
@Observable
class CoverArtManager {

    // MARK: - Observable UI State

    private(set) var loadingStates: [String: Bool] = [:]
    private(set) var errorStates:   [String: String] = [:]
    private(set) var cacheGeneration: Int = 0

    // MARK: - Dependencies

    @ObservationIgnored private weak var service: UnifiedSubsonicService?
    @ObservationIgnored let imageCache = ImageCacheActor()

    // MARK: - Concurrency control

    @ObservationIgnored private let preloadSemaphore = AsyncSemaphore(value: 8)
    @ObservationIgnored private var currentPreloadTask: Task<Void, Never>?
    @ObservationIgnored private var lastPreloadHash: Int = 0

    // MARK: - Observer storage

    @ObservationIgnored var sceneObservers: [NSObjectProtocol] = []

    // MARK: - Init

    init() {
        setupMemoryCacheObservers()
        setupFactoryResetObserver()
        setupScenePhaseObserver()
        AppLogger.cache.info("[CoverArtManager] Initialized")
    }

    func configure(service: UnifiedSubsonicService) {
        self.service = service
    }

    func cancelAllTasks() {
        cleanupObservers()
    }

    func incrementCacheGeneration() {
        cacheGeneration += 1
    }

    // MARK: - Synchronous memory reads (for views and lock screen)
    // These are hot-path reads that must not suspend. They use the nonisolated
    // NSCache peek on ImageCacheActor, which is thread-safe.
    // If the image hasn't been loaded yet they return nil — callers that need
    // a guaranteed result should use loadAlbumImage(for:context:) in a .task.

    func getAlbumImage(for albumId: String, context: ImageContext) -> UIImage? {
        imageCache.peekCachedImage(for: albumId, type: .album, size: context.size)
    }

    func getArtistImage(for artistId: String, context: ImageContext) -> UIImage? {
        imageCache.peekCachedImage(for: artistId, type: .artist, size: context.size)
    }

    func getSongImage(for song: Song, context: ImageContext) -> UIImage? {
        guard let albumId = song.albumId else { return nil }
        return getAlbumImage(for: albumId, context: context)
    }

    // MARK: - Synchronous cache peek (used by preload guards and MiniPlayer)
    // Calls into the actor synchronously via assumeIsolated-free pattern:
    // the caller must already hold a cached value from a prior async load.
    // For the MiniPlayer and NowPlaying overlay we keep the old NSCache
    // peek via a nonisolated helper on ImageCacheActor.

    // MARK: - Async image loading (main entry points)

    func loadAlbumImage(
        for albumId: String,
        context: ImageContext,
        staggerIndex: Int = 0
    ) async -> UIImage? {
        await loadImage(id: albumId, type: .album, size: context.size, staggerIndex: staggerIndex)
    }

    func loadArtistImage(
        for artistId: String,
        context: ImageContext,
        staggerIndex: Int = 0
    ) async -> UIImage? {
        await loadImage(id: artistId, type: .artist, size: context.size, staggerIndex: staggerIndex)
    }

    func loadAlbumImage(album: Album, context: ImageContext, staggerIndex: Int = 0) async -> UIImage? {
        await loadAlbumImage(for: album.id, context: context, staggerIndex: staggerIndex)
    }

    func loadArtistImage(artist: Artist, context: ImageContext, staggerIndex: Int = 0) async -> UIImage? {
        await loadArtistImage(for: artist.id, context: context, staggerIndex: staggerIndex)
    }

    func loadSongImage(song: Song, context: ImageContext) async -> UIImage? {
        guard let albumId = song.albumId else { return nil }
        return await loadAlbumImage(for: albumId, context: context)
    }

    // MARK: - Core load logic

    private func loadImage(
        id: String,
        type: ImageCacheActor.CacheType,
        size: Int,
        staggerIndex: Int = 0
    ) async -> UIImage? {
        let requestKey = "\(type.rawValue)_\(id)_\(size)"

        // 1. Memory check (actor-isolated)
        if let cached = await imageCache.cachedImage(for: id, type: type, size: size) {
            return cached
        }

        // 2. Disk check + network via deduplication
        return await imageCache.deduplicatedLoad(id: id, type: type, size: size) {
            // 2a. Disk
            if let fromDisk = await self.imageCache.loadFromDisk(for: id, type: type, size: size) {
                return fromDisk
            }

            // 2b. Network
            return await self.fetchFromNetwork(
                id: id,
                type: type,
                size: size,
                requestKey: requestKey,
                staggerIndex: staggerIndex
            )
        }
    }

    private func fetchFromNetwork(
        id: String,
        type: ImageCacheActor.CacheType,
        size: Int,
        requestKey: String,
        staggerIndex: Int
    ) async -> UIImage? {
        guard let service = service else {
            errorStates[requestKey] = "Service unavailable"
            return nil
        }

        loadingStates[requestKey] = true
        defer { loadingStates.removeValue(forKey: requestKey) }

        if staggerIndex > 0 {
            try? await Task.sleep(nanoseconds: UInt64(staggerIndex) * 100_000_000)
        }

        guard let image = await service.getCoverArt(for: id, size: size) else {
            errorStates[requestKey] = "Failed to load"
            return nil
        }

        errorStates.removeValue(forKey: requestKey)

        // Store in memory and on disk
        await imageCache.store(image: image, for: id, type: type, size: size)
        await imageCache.saveToDisk(image: image, for: id, type: type, size: size)

        incrementCacheGeneration()
        return image
    }

    // MARK: - State queries

    func isLoadingImage(for key: String, size: Int) -> Bool {
        let albumKey  = "album_\(key)_\(size)"
        let artistKey = "artist_\(key)_\(size)"
        return loadingStates[albumKey] == true || loadingStates[artistKey] == true
    }

    func getImageError(for key: String, size: Int) -> String? {
        let albumKey  = "album_\(key)_\(size)"
        let artistKey = "artist_\(key)_\(size)"
        return errorStates[albumKey] ?? errorStates[artistKey]
    }

    // MARK: - Preloading

    func preloadForFullscreen(albumId: String) {
        Task(priority: .userInitiated) {
            _ = await loadAlbumImage(for: albumId, context: .fullscreen)
        }
    }

    func preloadAlbums(_ albums: [Album], context: ImageContext) async {
        await preload(items: albums, type: .album, context: context, priority: .immediate) { $0.id }
    }

    func preloadArtists(_ artists: [Artist], context: ImageContext) async {
        await preload(items: artists, type: .artist, context: context, priority: .immediate) { $0.id }
    }

    func preloadArtistsWhenIdle(_ artists: [Artist], context: ImageContext) {
        Task(priority: .background) {
            await preload(items: artists, type: .artist, context: context, priority: .background) { $0.id }
        }
    }

    func preloadAlbumsControlled(_ albums: [Album], context: ImageContext) async {
        await preload(items: albums, type: .album, context: context, priority: .userInitiated) { $0.id }
    }

    private enum PreloadPriority { case immediate, userInitiated, background }

    private func preload<T: Sendable>(
        items: [T],
        type: ImageCacheActor.CacheType,
        context: ImageContext,
        priority: PreloadPriority,
        getId: @escaping @Sendable (T) -> String
    ) async {
        let ids = Set(items.map(getId))
        let hash = ids.hashValue
        guard hash != lastPreloadHash else { return }

        currentPreloadTask?.cancel()
        lastPreloadHash = hash
        let size = context.size

        currentPreloadTask = Task {
            guard service != nil else { return }

            switch priority {
            case .immediate:
                await withTaskGroup(of: Void.self) { group in
                    for (index, item) in items.enumerated().prefix(5) {
                        let id = getId(item)
                        group.addTask {
                            _ = await self.loadImage(id: id, type: type, size: size, staggerIndex: index)
                        }
                    }
                }

            case .userInitiated:
                await withTaskGroup(of: Void.self) { group in
                    for item in items {
                        guard !Task.isCancelled else { break }
                        let id = getId(item)
                        group.addTask {
                            await self.preloadSemaphore.wait()
                            _ = await self.loadImage(id: id, type: type, size: size)
                            await self.preloadSemaphore.signal()
                        }
                    }
                }

            case .background:
                for (index, item) in items.enumerated() {
                    guard !Task.isCancelled else { break }
                    let id = getId(item)
                    _ = await loadImage(id: id, type: type, size: size)
                    if index < items.count - 1 {
                        try? await Task.sleep(nanoseconds: 300_000_000)
                    }
                }
            }
        }

        await currentPreloadTask?.value
    }

    // MARK: - Cache management

    // MARK: - Cache management

    func clearMemoryCache() {
        Task { await imageCache.clearMemory() }
        loadingStates.removeAll()
        errorStates.removeAll()
        incrementCacheGeneration()
        // NOTE: Does NOT clear PersistentImageCache here.
        // Callers that want a full wipe (e.g. CacheSettingsView) call
        // PersistentImageCache.shared.clearCache() directly before this.
        // Calling it here too would cause a double-clear race.
        AppLogger.cache.info("[CoverArtManager] Memory cache cleared")
    }

    // MARK: - Diagnostics

    func getCacheStats() async -> CoverArtCacheStats {
        let persistent = await PersistentImageCache.shared.getCacheStats()
        return CoverArtCacheStats(
            diskCount: persistent.diskCount,
            diskSize: persistent.diskSize,
            activeRequests: loadingStates.count,
            errorCount: errorStates.count
        )
    }

    func getHealthStatus() async -> CoverArtHealthStatus {
        let stats = await getCacheStats()
        let total = stats.activeRequests + stats.errorCount
        let errorRate = total > 0 ? Double(stats.errorCount) / Double(total) : 0.0
        let isHealthy = errorRate < 0.1 && stats.activeRequests < 50

        let description: String
        if errorRate < 0.05 && stats.activeRequests < 10  { description = "Excellent" }
        else if errorRate < 0.1 && stats.activeRequests < 30 { description = "Good" }
        else { description = "Poor" }

        return CoverArtHealthStatus(isHealthy: isHealthy, statusDescription: description)
    }

    func resetPerformanceStats() {
        loadingStates.removeAll()
        errorStates.removeAll()
    }

    func printDiagnostics() async {
        let stats  = await getCacheStats()
        let health = await getHealthStatus()
        AppLogger.cache.info("""
        [CoverArtManager] DIAGNOSTICS:
        Health: \(health.statusDescription)
        \(stats.summary)
        Generation: \(cacheGeneration)
        Service: \(service != nil ? "Available" : "Not Available")
        """)
    }

    // MARK: - Observer setup

    private func setupMemoryCacheObservers() {
        let observer = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.incrementCacheGeneration()
                await self?.imageCache.clearMemory()
            }
        }
        sceneObservers.append(observer)
    }

    private func setupFactoryResetObserver() {
        let observer = NotificationCenter.default.addObserver(
            forName: .factoryResetRequested,
            object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.clearMemoryCache()
            }
        }
        sceneObservers.append(observer)
    }
}
