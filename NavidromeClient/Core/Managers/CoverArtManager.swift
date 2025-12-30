//
//  CoverArtManager.swift
//  NavidromeClient
//
//  UPDATED: Swift 6 Concurrency
//  - Removed unsafe deinit
//  - Added explicit shutdown/cancel methods
//

import Foundation
import SwiftUI

@MainActor
class CoverArtManager: ObservableObject {
    
    // MARK: - Cache Configuration
    
    private struct CacheLimits {
        static let albumCount: Int = 300
        static let artistCount: Int = 200
        static let albumMemory: Int = 120 * 1024 * 1024
        static let artistMemory: Int = 60 * 1024 * 1024
    }
    
    private enum CoverArtType {
        case album
        case artist
        
        @MainActor
        func getCache(from manager: CoverArtManager) -> NSCache<NSString, AlbumCoverArt> {
            switch self {
            case .album: return manager.albumCache
            case .artist: return manager.artistCache
            }
        }
        
        var name: String {
            switch self {
            case .album: return "album"
            case .artist: return "artist"
            }
        }
    }

    private enum PreloadPriority {
        case immediate
        case userInitiated
        case background
    }
    
    private var _cacheVersion = 0
    var cacheVersion: Int {
        _cacheVersion
    }

    // MARK: - Storage
    
    private let albumCache = NSCache<NSString, AlbumCoverArt>()
    private let artistCache = NSCache<NSString, AlbumCoverArt>()
        
    // MARK: - Dependencies
    
    private weak var service: UnifiedSubsonicService?
    private let persistentCache = PersistentImageCache.shared
    
    // MARK: - Concurrency Control
    
    private var activeTasks: [String: Task<UIImage?, Error>] = [:]
    
    private var lastPreloadHash: Int = 0
    private var currentPreloadTask: Task<Void, Never>?
    private let preloadSemaphore = AsyncSemaphore(value: 18)
    
    @Published private(set) var loadingStates: [String: Bool] = [:]
    @Published private(set) var errorStates: [String: String] = [:]
    @Published private(set) var cacheGeneration: Int = 0
    
    var sceneObservers: [NSObjectProtocol] = []

    func incrementCacheGeneration() {
        cacheGeneration += 1
        AppLogger.cache.info("[CoverArtManager] Cache generation: \(cacheGeneration)")
    }

    // MARK: - Initialization
    
    init() {
        setupMemoryCache()
        setupFactoryResetObserver()
        setupScenePhaseObserver()
        AppLogger.cache.info("[CoverArtManager] Initialized with hybrid multi-size strategy")
    }
    
    // Swift 6: removed deinit accessing MainActor properties.
    // Use cancelAllTasks() manually if explicit shutdown is required.
    func cancelAllTasks() {
        activeTasks.values.forEach { $0.cancel() }
        activeTasks.removeAll()
        cleanupObservers()
        AppLogger.cache.debug("[CoverArtManager] Tasks cancelled and observers cleaned")
    }
    
    func configure(service: UnifiedSubsonicService) {
        self.service = service
        AppLogger.cache.info("[CoverArtManager] Configured with UnifiedSubsonicService")
    }

    private func setupMemoryCache() {
        albumCache.countLimit = CacheLimits.albumCount
        albumCache.totalCostLimit = CacheLimits.albumMemory
        albumCache.evictsObjectsWithDiscardedContent = false
        
        artistCache.countLimit = CacheLimits.artistCount
        artistCache.totalCostLimit = CacheLimits.artistMemory
        artistCache.evictsObjectsWithDiscardedContent = false
        
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                AppLogger.cache.warn("[CoverArtManager] Memory warning - incrementing cache generation")
                self?.incrementCacheGeneration()
            }
        }
        
        AppLogger.cache.debug("[CoverArtManager] Memory limits: Albums=\(CacheLimits.albumCount), Artists=\(CacheLimits.artistCount)")
    }
    
    private func setupFactoryResetObserver() {
        NotificationCenter.default.addObserver(
            forName: .factoryResetRequested,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.clearMemoryCache()
                AppLogger.cache.info("[CoverArtManager] Cache cleared on factory reset")
            }
        }
    }
    
    // MARK: - Context-Aware Image Retrieval (Unchanged)
    
    func getAlbumImage(for albumId: String, context: ImageContext) -> UIImage? {
        return getCachedImage(for: albumId, cache: albumCache, size: context.size)
    }

    func getArtistImage(for artistId: String, context: ImageContext) -> UIImage? {
        return getCachedImage(for: artistId, cache: artistCache, size: context.size)
    }

    func getSongImage(for song: Song, context: ImageContext) -> UIImage? {
        guard let albumId = song.albumId else { return nil }
        return getAlbumImage(for: albumId, context: context)
    }
    
    private func getCachedImage(
        for id: String,
        cache: NSCache<NSString, AlbumCoverArt>,
        size: Int
    ) -> UIImage? {
        let cacheKey = "\(id)_\(size)" as NSString
        
        if let coverArt = cache.object(forKey: cacheKey) {
            if let image = coverArt.getImage(for: size) {
                return image
            }
        }
        
        let commonSizes = [80, 100, 150, 200, 240, 300, 400, 800, 1000]
        let largerSizes = commonSizes.filter { $0 > size }.sorted()
        
        for largerSize in largerSizes {
            let largerKey = "\(id)_\(largerSize)" as NSString
            if let coverArt = cache.object(forKey: largerKey),
               let image = coverArt.getImage(for: size) {
                let downscaled = AlbumCoverArt(image: image, size: size)
                cache.setObject(downscaled, forKey: cacheKey, cost: downscaled.memoryFootprint)
                AppLogger.cache.debug("[CoverArtManager] Downscaled \(largerSize)px → \(size)px (ID: \(id))")
                return image
            }
        }
        
        return nil
    }

    // MARK: - Context-Aware Image Loading (Unchanged)
    
    func loadAlbumImage(
        for albumId: String,
        context: ImageContext,
        staggerIndex: Int = 0
    ) async -> UIImage? {
        return await loadCoverArt(
            id: albumId,
            type: .album,
            size: context.size,
            staggerIndex: staggerIndex
        )
    }

    func loadArtistImage(
        for artistId: String,
        context: ImageContext,
        staggerIndex: Int = 0
    ) async -> UIImage? {
        return await loadCoverArt(
            id: artistId,
            type: .artist,
            size: context.size,
            staggerIndex: staggerIndex
        )
    }
    
    func loadAlbumImage(
        album: Album,
        context: ImageContext,
        staggerIndex: Int = 0
    ) async -> UIImage? {
        return await loadAlbumImage(for: album.id, context: context, staggerIndex: staggerIndex)
    }
    
    func loadArtistImage(
        artist: Artist,
        context: ImageContext,
        staggerIndex: Int = 0
    ) async -> UIImage? {
        return await loadArtistImage(for: artist.id, context: context, staggerIndex: staggerIndex)
    }

    func loadSongImage(
        song: Song,
        context: ImageContext
    ) async -> UIImage? {
        guard let albumId = song.albumId else { return nil }
        return await loadAlbumImage(for: albumId, context: context)
    }
    
    // MARK: - Core Loading Logic (Concurrency Refactored)
    
    private func loadCoverArt(
        id: String,
        type: CoverArtType,
        size: Int,
        staggerIndex: Int = 0
    ) async -> UIImage? {
        let cacheKey = "\(id)_\(size)" as NSString
        let requestKey = "\(type.name)_\(id)_\(size)"
        let cache = type.getCache(from: self)

        if let coverArt = cache.object(forKey: cacheKey),
           let image = coverArt.getImage(for: size) {
            return image
        }
        
        let diskCacheKey = "\(type.name)_\(id)_\(size)"
        if let cached = persistentCache.image(for: diskCacheKey, size: size) {
            storeImage(cached, forId: id, type: type, size: size)
            return cached
        }
        
        if let downscaled = await checkForDownscalableVersion(id: id, requestedSize: size, type: type) {
            return downscaled
        }

        // Deduplication using activeTasks
        if let existingTask = activeTasks[requestKey] {
            return try? await existingTask.value
        }
        
        let task = Task { [weak self] () throws -> UIImage? in
            guard let self = self else { throw CancellationError() }
            
            await MainActor.run { self.loadingStates[requestKey] = true }
            
            let image = await self.loadImageFromNetwork(
                id: id,
                type: type,
                size: size,
                requestKey: requestKey,
                staggerIndex: staggerIndex
            )

            await MainActor.run { self.loadingStates.removeValue(forKey: requestKey) }
            
            return image
        }

        activeTasks[requestKey] = task
        // Safe cleanup when task completes
        defer {
            // Check if this task is still the active one before removing
            if activeTasks[requestKey] == task {
                activeTasks.removeValue(forKey: requestKey)
            }
        }

        return try? await task.value
    }
    
    private func checkForDownscalableVersion(
        id: String,
        requestedSize: Int,
        type: CoverArtType
    ) async -> UIImage? {
        let cache = type.getCache(from: self)
        let commonSizes = [80, 100, 150, 200, 240, 300, 400, 800, 1000]
        let largerSizes = commonSizes.filter { $0 > requestedSize }.sorted()
        
        for largerSize in largerSizes {
            let largerKey = "\(id)_\(largerSize)" as NSString
            if let coverArt = cache.object(forKey: largerKey),
               let image = coverArt.getImage(for: requestedSize) {
                storeImage(image, forId: id, type: type, size: requestedSize)
                return image
            }
        }
        
        return nil
    }
    
    // MARK: - Network Loading (Unchanged)
    
    private func loadImageFromNetwork(
        id: String,
        type: CoverArtType,
        size: Int,
        requestKey: String,
        staggerIndex: Int
    ) async -> UIImage? {
        guard let service = service else {
            await MainActor.run {
                errorStates[requestKey] = "Service unavailable"
            }
            AppLogger.cache.error("[CoverArtManager] Network failed: No service")
            return nil
        }
        
        if staggerIndex > 0 {
            try? await Task.sleep(nanoseconds: UInt64(staggerIndex * 100_000_000))
        }
        
        if let image = await service.getCoverArt(for: id, size: size) {
            storeImage(image, forId: id, type: type, size: size)
            
            await MainActor.run {
                _ = errorStates.removeValue(forKey: requestKey)
            }
            
            let diskCacheKey = "\(type.name)_\(id)_\(size)"
            persistentCache.store(image, for: diskCacheKey, size: size)
            return image
        } else {
            await MainActor.run {
                errorStates[requestKey] = "Failed to load"
            }
            return nil
        }
    }
    
    // MARK: - Image Storage

    private func storeImage(
        _ image: UIImage,
        forId id: String,
        type: CoverArtType,
        size: Int
    ) {
        let cacheKey = "\(id)_\(size)" as NSString
        let cache = type.getCache(from: self)
        
        let coverArt = AlbumCoverArt(image: image, size: size)
        let cost = coverArt.memoryFootprint
        cache.setObject(coverArt, forKey: cacheKey, cost: cost)
        
        notifyChange()
    }
    
    private func notifyChange() {
        Task { @MainActor in
            self._cacheVersion += 1
            self.objectWillChange.send()
        }
    }
    
    // MARK: - State Queries
    
    func isLoadingImage(for key: String, size: Int) -> Bool {
        let requestKey = "\(key)_\(size)"
        return loadingStates[requestKey] == true
    }
    
    func getImageError(for key: String, size: Int) -> String? {
        let requestKey = "\(key)_\(size)"
        return errorStates[requestKey]
    }
    
    // MARK: - Intelligent Preloading
    
    func preloadForFullscreen(albumId: String) {
        Task(priority: .userInitiated) {
            _ = await loadAlbumImage(for: albumId, context: .fullscreen)
            AppLogger.cache.debug("[CoverArtManager] Preloaded fullscreen: \(albumId)")
        }
    }
    
    func preloadAlbums(_ albums: [Album], context: ImageContext) async {
        await preloadCoverArt(
            items: albums,
            type: .album,
            context: context,
            priority: .immediate,
            getId: { $0.id }
        )
    }

    func preloadArtists(_ artists: [Artist], context: ImageContext) async {
        await preloadCoverArt(
            items: artists,
            type: .artist,
            context: context,
            priority: .immediate,
            getId: { $0.id }
        )
    }

    func preloadArtistsWhenIdle(_ artists: [Artist], context: ImageContext) {
        Task(priority: .background) {
            await preloadCoverArt(
                items: artists,
                type: .artist,
                context: context,
                priority: .background,
                getId: { $0.id }
            )
        }
    }
    
    func preloadAlbumsControlled(_ albums: [Album], context: ImageContext) async {
        await preloadCoverArt(
            items: albums,
            type: .album,
            context: context,
            priority: .userInitiated,
            getId: { $0.id }
        )
    }
    
    private func preloadCoverArt<T>(
        items: [T],
        type: CoverArtType,
        context: ImageContext,
        priority: PreloadPriority = .immediate,
        getId: @escaping (T) -> String
    ) async {
        let itemIds = Set(items.map(getId))
        let currentHash = itemIds.hashValue
        
        guard currentHash != lastPreloadHash else {
            return
        }
        
        currentPreloadTask?.cancel()
        lastPreloadHash = currentHash
        
        let size = context.size
        
        currentPreloadTask = Task {
            guard service != nil else { return }
            
            switch priority {
            case .immediate:
                await withTaskGroup(of: Void.self) { group in
                    for (index, item) in items.enumerated().prefix(5) {
                        let id = getId(item)
                        if getCachedImage(for: id, cache: type.getCache
