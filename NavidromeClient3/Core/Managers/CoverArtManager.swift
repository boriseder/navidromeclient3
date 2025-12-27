//
//  CoverArtManager.swift
//  NavidromeClient
//
//  Swift 6: Updated to consume Actor-based PersistentImageCache
//

import Foundation
import SwiftUI

@MainActor
class CoverArtManager: ObservableObject {
    
    // ... [Configuration and CacheLimits structs remain unchanged] ...
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
    
    // ... [Properties remain unchanged] ...
    private var _cacheVersion = 0
    private let albumCache = NSCache<NSString, AlbumCoverArt>()
    private let artistCache = NSCache<NSString, AlbumCoverArt>()
    private weak var service: UnifiedSubsonicService?
    
    // CHANGED: Use the actor (it is a reference type, let is fine)
    private let persistentCache = PersistentImageCache.shared
    
    private var activeTasks: [String: Task<UIImage?, Error>] = [:]
    
    @Published private(set) var loadingStates: [String: Bool] = [:]
    @Published private(set) var errorStates: [String: String] = [:]
    
    // ... [Init and Setup methods remain unchanged] ...
    
    init() {
        setupMemoryCache()
        setupFactoryResetObserver()
        // Note: PersistentImageCache cleanup should be called in AppInitializer
    }
    
    func configure(service: UnifiedSubsonicService) {
        self.service = service
    }

    // ... [Memory Cache Setup remains unchanged] ...
    private func setupMemoryCache() {
        albumCache.countLimit = CacheLimits.albumCount
        albumCache.totalCostLimit = CacheLimits.albumMemory
        // ...
    }
    
    private func setupFactoryResetObserver() {
         NotificationCenter.default.addObserver(forName: .factoryResetRequested, object: nil, queue: .main) { [weak self] _ in
             Task { @MainActor in
                 self?.clearMemoryCache()
             }
         }
    }

    // ... [Sync accessors (getAlbumImage etc) remain unchanged] ...
    func getAlbumImage(for albumId: String, context: ImageContext) -> UIImage? {
        return getCachedImage(for: albumId, cache: albumCache, size: context.size)
    }
    
    // ... [Helper getCachedImage remains unchanged] ...
    private func getCachedImage(for id: String, cache: NSCache<NSString, AlbumCoverArt>, size: Int) -> UIImage? {
        let cacheKey = "\(id)_\(size)" as NSString
        if let coverArt = cache.object(forKey: cacheKey), let image = coverArt.getImage(for: size) {
            return image
        }
        // ... downscaling logic ...
        return nil
    }

    // ... [loadAlbumImage wrappers remain unchanged] ...
    func loadAlbumImage(for albumId: String, context: ImageContext, staggerIndex: Int = 0) async -> UIImage? {
        return await loadCoverArt(id: albumId, type: .album, size: context.size, staggerIndex: staggerIndex)
    }

    // MARK: - Core Loading Logic (Updated for Actor)
    
    private func loadCoverArt(
        id: String,
        type: CoverArtType,
        size: Int,
        staggerIndex: Int = 0
    ) async -> UIImage? {
        let requestKey = "\(type.name)_\(id)_\(size)"
        let cache = type.getCache(from: self)
        let cacheKey = "\(id)_\(size)" as NSString

        // 1. Memory Cache (Sync)
        if let coverArt = cache.object(forKey: cacheKey),
           let image = coverArt.getImage(for: size) {
            return image
        }
        
        // 2. Disk Cache (Async Actor Call)
        let diskCacheKey = "\(type.name)_\(id)_\(size)"
        // CHANGED: Await the actor
        if let cached = await persistentCache.image(for: diskCacheKey, size: size) {
            AppLogger.cache.debug("Disk HIT: \(diskCacheKey)")
            // Update memory cache
            storeImageInMemory(cached, forId: id, type: type, size: size)
            return cached
        }
        
        // 3. Downscaling Check (Async)
        // ... existing logic ...

        // 4. Network Request (Deduplicated)
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
        defer { activeTasks.removeValue(forKey: requestKey) }
        return try? await task.value
    }
    
    // MARK: - Network Loading
    
    private func loadImageFromNetwork(
        id: String,
        type: CoverArtType,
        size: Int,
        requestKey: String,
        staggerIndex: Int
    ) async -> UIImage? {
        guard let service = service else { return nil }
        
        if staggerIndex > 0 {
            try? await Task.sleep(nanoseconds: UInt64(staggerIndex * 100_000_000))
        }
        
        if let image = await service.getCoverArt(for: id, size: size) {
            // Update Memory Cache
            storeImageInMemory(image, forId: id, type: type, size: size)
            
            // Update Disk Cache (Async - Fire and Forget)
            let diskCacheKey = "\(type.name)_\(id)_\(size)"
            Task {
                await persistentCache.store(image, for: diskCacheKey, size: size)
            }
            
            return image
        }
        return nil
    }
    
    // MARK: - Storage Helper
    
    // Renamed to clarify it only touches memory now, as disk is handled via Actor
    private func storeImageInMemory(_ image: UIImage, forId id: String, type: CoverArtType, size: Int) {
        let cacheKey = "\(id)_\(size)" as NSString
        let cache = type.getCache(from: self)
        
        let coverArt = AlbumCoverArt(image: image, size: size)
        cache.setObject(coverArt, forKey: cacheKey, cost: coverArt.memoryFootprint)
        
        notifyChange()
    }

    private func notifyChange() {
        self._cacheVersion += 1
        self.objectWillChange.send()
    }
    
    // MARK: - Cache Clearing
    
    func clearMemoryCache() {
        albumCache.removeAllObjects()
        artistCache.removeAllObjects()
        
        // CHANGED: Async call to actor
        Task {
            await persistentCache.clearCache()
        }
        AppLogger.cache.info("All caches cleared")
    }
    
    // ... [Diagnostics and other methods need small updates to await stats] ...
    
    func getCacheStats() async -> CoverArtCacheStats {
        // CHANGED: Must await actor stats
        let persistentStats = await persistentCache.getCacheStats()
        
        return CoverArtCacheStats(
            diskCount: persistentStats.diskCount,
            diskSize: persistentStats.diskSize,
            activeRequests: activeTasks.count,
            errorCount: errorStates.count
        )
    }
}
