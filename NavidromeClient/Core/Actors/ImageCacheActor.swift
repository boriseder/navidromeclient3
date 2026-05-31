//
//  ImageCacheActor.swift
//  NavidromeClient
//
//  NEW: Swift 6 Concurrency Refactoring — Step 3
//  Owns image memory cache, decoding, scaling, and deduplication.
//  No network. No UI state. No MainActor.
//
//  FIXED (review):
//  - cachedImage() unified with peekCachedImage() — both were doing the same
//    work; actor isolation on cachedImage() was an unnecessary hop since
//    NSCache is thread-safe. One nonisolated implementation now serves both.
//  - commonSizes defined once as a static constant (was copy-pasted in two places)
//  - diskCacheKey and requestKey were identical — collapsed into one method
//  - CacheType .rawValue string redundancy removed ("album" = "album")
//

import Foundation
import UIKit

actor ImageCacheActor {

    // MARK: - Memory Cache

    // nonisolated(unsafe): NSCache is thread-safe by design, so concurrent
    // reads and writes from any context are safe. This lets cachedImage()
    // read synchronously without an actor hop.
    @ObservationIgnored nonisolated(unsafe) private let albumCache  = NSCache<NSString, AlbumCoverArt>()
    @ObservationIgnored nonisolated(unsafe) private let artistCache = NSCache<NSString, AlbumCoverArt>()

    // Sizes tried when an exact match isn't cached — used for downscale fallback.
    private static let commonSizes = [80, 100, 150, 200, 240, 300, 400, 800, 1000]

    // MARK: - In-flight deduplication
    // Key: "\(type)_\(id)_\(size)"
    private var inflightTasks: [String: Task<UIImage?, Never>] = [:]

    // MARK: - Dependencies

    private let storage: PersistentImageCache

    // MARK: - Init

    init(storage: PersistentImageCache = .shared) {
        self.storage = storage

        albumCache.countLimit      = 300
        albumCache.totalCostLimit  = 120 * 1024 * 1024
        albumCache.evictsObjectsWithDiscardedContent = false

        artistCache.countLimit     = 200
        artistCache.totalCostLimit = 60 * 1024 * 1024
        artistCache.evictsObjectsWithDiscardedContent = false
    }

    // MARK: - Synchronous memory read (hot path)

    /// Returns a cached image without hitting disk or network.
    /// Tries exact size first, then downsizes a larger cached variant.
    /// Safe to call from any isolation context — NSCache is thread-safe.
    /// Used on the MainActor (e.g. updateNowPlayingInfo) to avoid an await.
    nonisolated func cachedImage(for id: String, type: CacheType, size: Int) -> UIImage? {
        let cache = nonisolatedCache(for: type)
        let key   = cacheKey(id: id, size: size) as NSString

        if let art = cache.object(forKey: key),
           let img = art.getImage(for: size) {
            return img
        }

        // Try downscaling a larger cached size
        for larger in Self.commonSizes.filter({ $0 > size }).sorted() {
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
        let key      = cacheKey(id: id, size: size) as NSString
        let coverArt = AlbumCoverArt(image: image, size: size)
        nonisolatedCache(for: type).setObject(coverArt, forKey: key, cost: coverArt.memoryFootprint)
    }

    // MARK: - Disk read → memory store

    /// Loads from disk cache. Returns nil if not on disk.
    func loadFromDisk(for id: String, type: CacheType, size: Int) async -> UIImage? {
        let diskKey = storedKey(id: id, type: type, size: size)
        guard let image = await storage.image(for: diskKey, size: size) else { return nil }
        store(image: image, for: id, type: type, size: size)
        return image
    }

    // MARK: - Persist image to disk

    func saveToDisk(image: UIImage, for id: String, type: CacheType, size: Int) async {
        let diskKey = storedKey(id: id, type: type, size: size)
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
        let key = storedKey(id: id, type: type, size: size)

        if let existing = inflightTasks[key] {
            return await existing.value
        }

        let task = Task<UIImage?, Never> { await loader() }
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
        case album
        case artist
    }

    // MARK: - Private helpers

    /// nonisolated cache accessor — safe because both caches are nonisolated(unsafe).
    nonisolated private func nonisolatedCache(for type: CacheType) -> NSCache<NSString, AlbumCoverArt> {
        type == .album ? albumCache : artistCache
    }

    nonisolated private func cacheKey(id: String, size: Int) -> String {
        "\(id)_\(size)"
    }

    /// Single key format used for both disk storage and inflight deduplication.
    /// Format: "\(type)_\(id)_\(size)"
    private func storedKey(id: String, type: CacheType, size: Int) -> String {
        "\(type.rawValue)_\(id)_\(size)"
    }
}
