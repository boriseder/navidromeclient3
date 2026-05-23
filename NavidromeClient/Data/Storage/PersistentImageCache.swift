//
//  PersistentImageCache.swift
//  NavidromeClient
//
//  REFACTORED: Swift 6 — Step 1
//  - Converted from @MainActor class to actor
//  - All disk I/O delegated to StorageActor
//  - No blocking reads anywhere
//

import Foundation
import UIKit
import CryptoKit

actor PersistentImageCache {

    // MARK: - Shared instance
    // Still a singleton for now (removed in DI wiring step).
    // Safe: actor isolation guarantees thread safety.
    static let shared = PersistentImageCache(storage: AppStorageActor.shared)

    // MARK: - Dependencies

    private let storage: StorageActor

    // MARK: - Metadata (lives on this actor)

    // CacheMetadata is a Sendable struct — safe to pass across boundaries.
    struct CacheMetadata: Codable, Sendable {
        let key: String
        let filename: String
        let createdAt: Date
        let size: Int64
        var lastAccessed: Date
    }

    private var metadata: [String: CacheMetadata] = [:]
    private var isMetadataLoaded = false

    // Debounce handle — cancelled and replaced on every scheduleMetadataSave()
    // call so that a burst of 150 store() calls during preload produces exactly
    // one disk write after the burst settles, matching AlbumMetadataCache behaviour.
    private var metadataSaveTask: Task<Void, Never>?

    // MARK: - Configuration

    private let maxCacheSize: Int64 = 200 * 1024 * 1024  // 200 MB
    private let maxAge: TimeInterval = 30 * 24 * 60 * 60  // 30 days

    // MARK: - Init

    init(storage: StorageActor) {
        self.storage = storage
    }

    // MARK: - Lazy metadata bootstrap
    // Called before any read/write. Loads metadata once from disk.

    private func ensureMetadataLoaded() async {
        guard !isMetadataLoaded else { return }
        metadata = await storage.loadImageMetadata()
        isMetadataLoaded = true
    }

    // MARK: - Public API

    /// Returns a UIImage if one exists on disk for key + size. Nil otherwise.
    func image(for key: String, size: Int) async -> UIImage? {
        await ensureMetadataLoaded()

        guard let data = await storage.loadImage(key: key, size: size) else {
            // File disappeared — evict stale metadata entry
            metadata.removeValue(forKey: "\(key)_\(size)")
            scheduleMetadataSave()
            return nil
        }

        guard let image = UIImage(data: data) else { return nil }

        updateLastAccessed(for: key, size: size)
        return image
    }

    /// Persists image data to disk and updates metadata.
    func store(_ image: UIImage, for key: String, size: Int, quality: CGFloat = 0.92) async {
        await ensureMetadataLoaded()

        guard let data = image.jpegData(compressionQuality: quality) else { return }

        await storage.saveImage(data: data, key: key, size: size)

        // BUG FIX: key metadata by "\(key)_\(size)" so different sizes of the
        // same image don't clobber each other's metadata entry. Previously
        // metadata[key] was overwritten on every store for a new size, causing
        // getCacheStats() to undercount and LRU eviction to only track one size.
        let metaKey = "\(key)_\(size)"
        let filename = storageFilename(for: key, size: size)
        let meta = CacheMetadata(
            key: metaKey,
            filename: filename,
            createdAt: Date(),
            size: Int64(data.count),
            lastAccessed: Date()
        )
        metadata[metaKey] = meta
        scheduleMetadataSave()

        await checkCacheSizeAndCleanup()
    }

    func storeLossless(_ image: UIImage, for key: String, size: Int) async {
        await ensureMetadataLoaded()

        guard let data = image.pngData() else { return }

        await storage.saveImage(data: data, key: key, size: size)

        let metaKey = "\(key)_\(size)"
        let filename = storageFilename(for: key, size: size)
        let meta = CacheMetadata(
            key: metaKey,
            filename: filename,
            createdAt: Date(),
            size: Int64(data.count),
            lastAccessed: Date()
        )
        metadata[metaKey] = meta
        scheduleMetadataSave()
    }

    func removeImage(for key: String, size: Int) async {
        await ensureMetadataLoaded()
        await storage.deleteImage(key: key, size: size)
        metadata.removeValue(forKey: "\(key)_\(size)")
        scheduleMetadataSave()
    }

    func clearCache() async {
        await storage.clearImageCache()
        metadata.removeAll()
        scheduleMetadataSave()
        AppLogger.general.info("PersistentImageCache: Cache cleared")
    }

    func getCacheStats() async -> CacheStats {
        await ensureMetadataLoaded()
        let diskCount = metadata.count
        let diskSize = metadata.values.reduce(0) { $0 + $1.size }
        return CacheStats(
            memoryCount: 0,
            diskCount: diskCount,
            diskSize: diskSize,
            maxSize: maxCacheSize
        )
    }

    func performMaintenanceCleanup() async {
        await ensureMetadataLoaded()
        await removeExpiredImages()
        await checkCacheSizeAndCleanup()
        await storage.removeOrphanedImageFiles(
            knownFilenames: Set(metadata.values.map { $0.filename })
        )
        AppLogger.general.info("PersistentImageCache: Maintenance complete")
    }

    // MARK: - Private helpers

    private func updateLastAccessed(for key: String, size: Int) {
        let metaKey = "\(key)_\(size)"
        guard var meta = metadata[metaKey] else { return }
        meta.lastAccessed = Date()
        metadata[metaKey] = meta
        // Probabilistic save to avoid hammering disk on every read
        if Int.random(in: 1...20) == 1 { scheduleMetadataSave() }
    }

    private func scheduleMetadataSave() {
        // Cancel any pending save and restart the window. A burst of N store()
        // calls (e.g. 150 during a full preload) results in a single disk write
        // once the burst is done, rather than N concurrent writes of the full JSON.
        metadataSaveTask?.cancel()
        let snapshot = metadata
        let stor = storage
        metadataSaveTask = Task.detached { [snapshot, stor] in
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 s coalesce window
            guard !Task.isCancelled else { return }
            await stor.saveImageMetadata(snapshot)
        }
    }

    private func removeExpiredImages() async {
        let now = Date()
        let expired = metadata.filter { now.timeIntervalSince($0.value.createdAt) > maxAge }.map { $0.key }
        for key in expired {
            // We don't have size stored per-key in the old metadata, so we delete by filename
            if let meta = metadata[key] {
                let filename = meta.filename
                // StorageActor exposes a URL-based delete
                let url = await storage.imageCacheDirectory.appendingPathComponent(filename)
                await storage.deleteFile(at: url)
                metadata.removeValue(forKey: key)
            }
        }
        if !expired.isEmpty { scheduleMetadataSave() }
    }

    private func checkCacheSizeAndCleanup() async {
        let currentSize = metadata.values.reduce(0) { $0 + $1.size }
        guard currentSize > maxCacheSize else { return }

        let sorted = metadata.sorted { $0.value.lastAccessed < $1.value.lastAccessed }
        let target = maxCacheSize * 80 / 100
        var freed: Int64 = 0

        for (key, meta) in sorted {
            guard currentSize - freed > target else { break }
            let url = await storage.imageCacheDirectory.appendingPathComponent(meta.filename)
            await storage.deleteFile(at: url)
            metadata.removeValue(forKey: key)
            freed += meta.size
        }

        if freed > 0 { scheduleMetadataSave() }
    }

    private func storageFilename(for key: String, size: Int) -> String {
        "\(key.storageSHA256())_\(size).jpg"
    }

    // MARK: - Stats type

    struct CacheStats: Sendable {
        let memoryCount: Int
        let diskCount: Int
        let diskSize: Int64
        let maxSize: Int64

        var diskSizeFormatted: String {
            ByteCountFormatter.string(fromByteCount: diskSize, countStyle: .file)
        }
        var usagePercentage: Double {
            guard maxSize > 0 else { return 0 }
            return Double(diskSize) / Double(maxSize) * 100.0
        }
    }
}
