//
//  PersistentImageCache.swift
//  NavidromeClient
//
//  UPDATED: Swift 6 Concurrency Compliance
//  - Fixed "Sending closure" warnings by removing FileManager capture
//  - Uses local FileManager instances in detached tasks
//

import Foundation
import UIKit
import CryptoKit

@MainActor
class PersistentImageCache: ObservableObject {
    static let shared = PersistentImageCache()
    
    // Kept for MainActor usage, but NOT captured in background tasks
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    private let metadataFile: URL
    
    struct CacheMetadata: Codable, Sendable {
        let key: String
        let filename: String
        let createdAt: Date
        let size: Int64
        var lastAccessed: Date
    }
    
    private var metadata: [String: CacheMetadata] = [:]
    private let maxCacheSize: Int64 = 200 * 1024 * 1024 // 200MB
    private let maxAge: TimeInterval = 30 * 24 * 60 * 60 // 30 days
    
    private init() {
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        cacheDirectory = documentsPath.appendingPathComponent("CoverArtCache", isDirectory: true)
        metadataFile = cacheDirectory.appendingPathComponent("metadata.json")
        
        // Initial setup can be synchronous as it's app startup
        if !fileManager.fileExists(atPath: cacheDirectory.path) {
            try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        }
        
        // Load metadata
        if fileManager.fileExists(atPath: metadataFile.path),
           let data = try? Data(contentsOf: metadataFile),
           let loadedMetadata = try? JSONDecoder().decode([String: CacheMetadata].self, from: data) {
            self.metadata = loadedMetadata
            AppLogger.general.info("PersistentImageCache: Loaded metadata for \(loadedMetadata.count) items")
        }
        
        Task {
            await performMaintenanceCleanup()
        }
    }
    
    // MARK: - Public API
    
    func image(for key: String, size: Int) -> UIImage? {
        guard let meta = metadata[key] else { return nil }
        
        let fileURL = cacheDirectory.appendingPathComponent(meta.filename)
        
        // Reading small files on main thread is generally acceptable for cache hits
        guard fileManager.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL),
              let image = UIImage(data: data) else {
            metadata.removeValue(forKey: key)
            scheduleMetadataSave()
            return nil
        }
        
        updateLastAccessed(for: key)
        return image
    }
    
    func store(_ image: UIImage, for key: String, size: Int, quality: CGFloat = 0.92) {
        Task {
            await saveImageToDisk(image, key: key, quality: quality, isPNG: false)
        }
    }
    
    func storeLossless(_ image: UIImage, for key: String, size: Int) {
        Task {
            await saveImageToDisk(image, key: key, quality: 1.0, isPNG: true)
        }
    }

    func removeImage(for key: String) {
        Task {
            await removeImageFromDisk(key: key)
        }
    }
    
    func clearCache() {
        Task {
            await clearDiskCache()
        }
    }
    
    func getCacheStats() -> CacheStats {
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
        await removeExpiredImages()
        await checkCacheSizeAndCleanup()
        await removeOrphanedFiles()
        AppLogger.general.info("PersistentImageCache maintenance completed")
    }
    
    // MARK: - Private Operations
    
    private func saveImageToDisk(_ image: UIImage, key: String, quality: CGFloat, isPNG: Bool) async {
        let ext = isPNG ? "png" : "jpg"
        let filename = "\(key.sha256()).\(ext)"
        let fileURL = cacheDirectory.appendingPathComponent(filename)
        
        // Offload heavy compression and I/O
        guard let result = await performBackgroundWrite(image: image, url: fileURL, quality: quality, isPNG: isPNG) else {
            return
        }
        
        let meta = CacheMetadata(
            key: key,
            filename: filename,
            createdAt: Date(),
            size: result.size,
            lastAccessed: Date()
        )
        
        metadata[key] = meta
        scheduleMetadataSave()
        
        await checkCacheSizeAndCleanup()
    }
    
    // Swift 6: Non-isolated helper for background I/O
    private nonisolated func performBackgroundWrite(image: UIImage, url: URL, quality: CGFloat, isPNG: Bool) async -> (size: Int64, success: Bool)? {
        // Use Task.detached to ensure we are off the MainActor
        return await Task.detached {
            let data: Data? = isPNG ? image.pngData() : image.jpegData(compressionQuality: quality)
            guard let data = data else { return nil }
            
            do {
                try data.write(to: url, options: .atomic)
                return (Int64(data.count), true)
            } catch {
                return nil
            }
        }.value
    }
    
    private func removeImageFromDisk(key: String) async {
        guard let meta = metadata[key] else { return }
        let fileURL = cacheDirectory.appendingPathComponent(meta.filename)
        
        // Fix: Use local FileManager instance in detached task, DO NOT capture [fileManager]
        await Task.detached {
            try? FileManager.default.removeItem(at: fileURL)
        }.value
        
        metadata.removeValue(forKey: key)
        scheduleMetadataSave()
    }
    
    private func clearDiskCache() async {
        let url = cacheDirectory
        
        // Fix: Use local FileManager instance in detached task, DO NOT capture [fileManager]
        await Task.detached {
            let fm = FileManager.default
            if let contents = try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: nil) {
                for fileURL in contents {
                    try? fm.removeItem(at: fileURL)
                }
            }
        }.value
        
        metadata.removeAll()
        scheduleMetadataSave()
        AppLogger.general.info("Disk cache cleared")
    }
    
    private func scheduleMetadataSave() {
        // Capture data safely for background write
        let currentMeta = self.metadata
        let fileURL = self.metadataFile
        
        // Debounce/Batch save
        Task {
            await Task.detached {
                if let data = try? JSONEncoder().encode(currentMeta) {
                    try? data.write(to: fileURL)
                }
            }.value
        }
    }
    
    private func updateLastAccessed(for key: String) {
        guard var meta = metadata[key] else { return }
        meta.lastAccessed = Date()
        metadata[key] = meta
        
        // Randomly save sometimes to keep access times somewhat fresh without thrashing IO
        if Int.random(in: 1...20) == 1 {
            scheduleMetadataSave()
        }
    }
    
    private func removeExpiredImages() async {
        let now = Date()
        let expiredKeys = metadata.filter { now.timeIntervalSince($0.value.createdAt) > maxAge }.map { $0.key }
        
        for key in expiredKeys {
            await removeImageFromDisk(key: key)
        }
    }
    
    private func checkCacheSizeAndCleanup() async {
        let currentSize = metadata.values.reduce(0) { $0 + $1.size }
        guard currentSize > maxCacheSize else { return }
        
        let sortedByAccess = metadata.sorted { $0.value.lastAccessed < $1.value.lastAccessed }
        let targetSize = maxCacheSize * 80 / 100
        
        var removedSize: Int64 = 0
        
        for (key, meta) in sortedByAccess {
            await removeImageFromDisk(key: key)
            removedSize += meta.size
            if currentSize - removedSize <= targetSize { break }
        }
    }
    
    private func removeOrphanedFiles() async {
        let knownFiles = Set(metadata.values.map { $0.filename })
        let url = cacheDirectory
        
        // Fix: Use local FileManager instance in detached task, DO NOT capture [fileManager]
        await Task.detached {
            let fm = FileManager.default
            guard let contents = try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: nil) else { return }
            
            for fileURL in contents {
                let filename = fileURL.lastPathComponent
                if filename == "metadata.json" { continue }
                
                if !knownFiles.contains(filename) {
                    try? fm.removeItem(at: fileURL)
                }
            }
        }.value
    }
    
    // MARK: - CacheStats
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

extension String {
    func sha256() -> String {
        let inputData = Data(utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.compactMap { String(format: "%02x", $0) }.joined()
    }
}
