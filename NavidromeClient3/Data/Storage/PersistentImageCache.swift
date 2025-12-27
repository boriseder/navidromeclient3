//
//  PersistentImageCache.swift
//  NavidromeClient
//
//  Swift 6: Converted to Actor for thread-safe I/O
//

import Foundation
import UIKit
import CryptoKit

actor PersistentImageCache {
    static let shared = PersistentImageCache()
    
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
        // Safe synchronous setup
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        cacheDirectory = documentsPath.appendingPathComponent("CoverArtCache", isDirectory: true)
        metadataFile = cacheDirectory.appendingPathComponent("metadata.json")
        
        // Create directory
        if !fileManager.fileExists(atPath: cacheDirectory.path) {
            try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        }
        
        // Load metadata synchronously (fast enough for init)
        if fileManager.fileExists(atPath: metadataFile.path),
           let data = try? Data(contentsOf: metadataFile),
           let loadedMetadata = try? JSONDecoder().decode([String: CacheMetadata].self, from: data) {
            metadata = loadedMetadata
        }
        
        AppLogger.cache.info("PersistentImageCache initialized (Actor)")
    }
    
    // MARK: - Public API (Async)
    
    func image(for key: String, size: Int) -> UIImage? {
        // Actors process messages one at a time, ensuring thread safety
        guard let meta = metadata[key] else { return nil }
        
        let fileURL = cacheDirectory.appendingPathComponent(meta.filename)
        
        guard fileManager.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL),
              let image = UIImage(data: data) else {
            // Self-repair: remove missing file metadata
            metadata.removeValue(forKey: key)
            saveMetadata() // No await needed, internal call
            return nil
        }
        
        updateLastAccessed(for: key)
        return image
    }
    
    func store(_ image: UIImage, for key: String, size: Int, quality: CGFloat = 0.92) {
        let filename = generateFilename(for: key)
        let fileURL = cacheDirectory.appendingPathComponent(filename)
        
        guard let data = image.jpegData(compressionQuality: quality) else { return }
        
        do {
            try data.write(to: fileURL, options: .atomic)
            
            let meta = CacheMetadata(
                key: key,
                filename: filename,
                createdAt: Date(),
                size: Int64(data.count),
                lastAccessed: Date()
            )
            
            metadata[key] = meta
            saveMetadata()
            
            // Trigger cleanup if needed (fire and forget internal check)
            if currentCacheSize() > maxCacheSize {
                performMaintenanceCleanup()
            }
            
        } catch {
            AppLogger.cache.error("Cache save error: \(error)")
        }
    }

    func removeImage(for key: String) {
        guard let meta = metadata[key] else { return }
        
        let fileURL = cacheDirectory.appendingPathComponent(meta.filename)
        try? fileManager.removeItem(at: fileURL)
        
        metadata.removeValue(forKey: key)
        saveMetadata()
    }
    
    func clearCache() {
        if let contents = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil) {
            for fileURL in contents {
                try? fileManager.removeItem(at: fileURL)
            }
        }
        
        metadata.removeAll()
        saveMetadata()
        AppLogger.cache.info("Disk cache cleared")
    }
    
    func getCacheStats() -> CacheStats {
        let diskSize = currentCacheSize()
        return CacheStats(
            memoryCount: 0,
            diskCount: metadata.count,
            diskSize: diskSize,
            maxSize: maxCacheSize
        )
    }
    
    // MARK: - Maintenance
    
    func performMaintenanceCleanup() {
        let now = Date()
        var expiredKeys: [String] = []
        
        // 1. Remove expired
        for (key, meta) in metadata {
            if now.timeIntervalSince(meta.createdAt) > maxAge {
                expiredKeys.append(key)
            }
        }
        
        for key in expiredKeys {
            removeImage(for: key)
        }
        
        // 2. Size limit
        let currentSize = currentCacheSize()
        if currentSize > maxCacheSize {
            let sortedByAccess = metadata.sorted { $0.value.lastAccessed < $1.value.lastAccessed }
            let targetSize = maxCacheSize * 80 / 100
            var removedSize: Int64 = 0
            
            for (key, meta) in sortedByAccess {
                removeImage(for: key)
                removedSize += meta.size
                
                if (currentSize - removedSize) <= targetSize {
                    break
                }
            }
        }
        
        // 3. Remove orphans
        removeOrphanedFiles()
        
        AppLogger.cache.info("PersistentImageCache maintenance completed")
    }
    
    // MARK: - Private Helpers
    
    private func currentCacheSize() -> Int64 {
        metadata.values.reduce(0) { $0 + $1.size }
    }
    
    private func generateFilename(for key: String) -> String {
        let inputData = Data(key.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap { String(format: "%02x", $0) }.joined()
        return "\(hashString).jpg"
    }
    
    private func saveMetadata() {
        guard let data = try? JSONEncoder().encode(metadata) else { return }
        try? data.write(to: metadataFile)
    }
    
    private func updateLastAccessed(for key: String) {
        guard var meta = metadata[key] else { return }
        meta.lastAccessed = Date()
        metadata[key] = meta
        
        // Optimization: Don't write to disk on every single read
        if Int.random(in: 1...20) == 1 {
            saveMetadata()
        }
    }
    
    private func removeOrphanedFiles() {
        guard let contents = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil) else { return }
        
        let metadataFilenames = Set(metadata.values.map { $0.filename })
        
        for fileURL in contents {
            let filename = fileURL.lastPathComponent
            if filename == "metadata.json" { continue }
            
            if !metadataFilenames.contains(filename) {
                try? fileManager.removeItem(at: fileURL)
            }
        }
    }
}

// Stats DTO
struct CacheStats: Sendable {
    let memoryCount: Int
    let diskCount: Int
    let diskSize: Int64
    let maxSize: Int64
    
    var diskSizeFormatted: String {
        ByteCountFormatter.string(fromByteCount: diskSize, countStyle: .file)
    }
}
