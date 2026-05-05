//
//  ImageCacheActor.swift
//  NavidromeClient
//
//  Created by Boris Eder on 05.05.26.
//


//
//  ImageCacheActor.swift
//  NavidromeClient
//
//  NEW: Swift 6 Concurrency Refactoring — Step 3
//  Owns image memory cache, decoding, scaling, and deduplication.
//  No network. No UI state. No MainActor.
//

import Foundation
import UIKit

actor ImageCacheActor {

    // MARK: - Memory Cache

    private let albumCache  = NSCache<NSString, AlbumCoverArt>()
    private let artistCache = NSCache<NSString, AlbumCoverArt>()

    // MARK: - In-flight deduplication
    // Key: "\(type)_\(id)_\(size)"
    private var inflightTasks: [String: Task<UIImage?, Never>] = [:]

    // MARK: - Dependencies

    private let storage: PersistentImageCache

    // MARK: - Init

    init(storage: PersistentImageCache = .shared) {
        self.storage = storage

        albumCache.countLimit       = 300
        albumCache.totalCostLimit   = 120 * 1024 * 1024
        albumCache.evictsObjectsWithDiscardedContent = false

        artistCache.countLimit      = 200
        artistCache.totalCostLimit  = 60 * 1024 * 1024
        artistCache.evictsObjectsWithDiscardedContent = false
    }

    // MARK: - Synchronous memory read (hot path)

    /// Returns a cached image without hitting disk or network.
    /// Tries exact size first, then downsizes a larger cached variant.
    func cachedImage(for id: String, type: CacheType, size: Int) -> UIImage? {
        let cache = cache(for: type)
        let key   = cacheKey(id: id, size: size) as NSString

        if let art = cache.object(forKey: key),
           let img = art.getImage(for: size) {
            return img
        }

        // Try downscaling a larger cached size
        let commonSizes = [80, 100, 150, 200, 240, 300, 400, 800, 1000]
        for larger in commonSizes.filter({ $0 > size }).sorted() {
            let largerKey = cacheKey(id: id, size: larger) as NSString
            if let art = cache.object(forKey: largerKey),
               let img = art.getImage(for: size) {
                let downscaled = AlbumCoverArt(image: img, size: size)
                cache.setObject(downscaled, forKey: key, cost: downscaled.memoryFootprint)
                return img
            }
        }

        return nil
    }

    // MARK: - Store image in memory

    func store(image: UIImage, for id: String, type: CacheType, size: Int) {
        let key     = cacheKey(id: id, size: size) as NSString
        let coverArt = AlbumCoverArt(image: image, size: size)
        cache(for: type).setObject(coverArt, forKey: key, cost: coverArt.memoryFootprint)
    }

    // MARK: - Disk read → memory store

    /// Loads from disk cache. Returns nil if not on disk.
    func loadFromDisk(for id: String, type: CacheType, size: Int) async -> UIImage? {
        let diskKey = diskCacheKey(id: id, type: type, size: size)
        guard let image = await storage.image(for: diskKey, size: size) else { return nil }
        store(image: image, for: id, type: type, size: size)
        return image
    }

    // MARK: - Persist image to disk

    func saveToDisk(image: UIImage, for id: String, type: CacheType, size: Int) async {
        let diskKey = diskCacheKey(id: id, type: type, size: size)
        await storage.store(image, for: diskKey, size: size)
    }

    // MARK: - Deduplicated load

    /// Deduplicates concurrent requests for the same key.
    /// `loader` is called at most once per key while a request is in-flight.
    func deduplicatedLoad(
        id: String,
        type: CacheType,
        size: Int,
        loader: @escaping @Sendable () async -> UIImage?
    ) async -> UIImage? {
        let key = requestKey(id: id, type: type, size: size)

        // Already in-flight — await its result
        if let existing = inflightTasks[key] {
            return await existing.value
        }

        // Start new task
        let task = Task<UIImage?, Never> {
            await loader()
        }
        inflightTasks[key] = task

        let result = await task.value
        inflightTasks.removeValue(forKey: key)
        return result
    }

    // MARK: - Clear

    func clearMemory() {
        albumCache.removeAllObjects()
        artistCache.removeAllObjects()
        // Cancel nothing — in-flight tasks will complete and store to an
        // empty cache, which is harmless.
    }

    // MARK: - Cache type

    enum CacheType: String, Sendable {
        case album  = "album"
        case artist = "artist"
    }

    // MARK: - Private helpers

    private func cache(for type: CacheType) -> NSCache<NSString, AlbumCoverArt> {
        type == .album ? albumCache : artistCache
    }

    private func cacheKey(id: String, size: Int) -> String {
        "\(id)_\(size)"
    }

    private func diskCacheKey(id: String, type: CacheType, size: Int) -> String {
        "\(type.rawValue)_\(id)_\(size)"
    }

    private func requestKey(id: String, type: CacheType, size: Int) -> String {
        "\(type.rawValue)_\(id)_\(size)"
    }
}
