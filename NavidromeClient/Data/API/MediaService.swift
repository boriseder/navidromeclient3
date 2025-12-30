//
//  MediaService.swift - Media URLs & Cover Art
//  NavidromeClient
//
//  UPDATED: Swift 6 Concurrency Compliance
//  - Marked @MainActor
//

import Foundation
import UIKit

@MainActor
class MediaService {
    private let connectionService: ConnectionService
    private let session: URLSession
    
    init(connectionService: ConnectionService) {
        self.connectionService = connectionService
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 20
        config.timeoutIntervalForResource = 120 // Longer for media downloads
        self.session = URLSession(configuration: config)
    }
    
    // MARK: -  COVER ART API
    
    func getCoverArt(for coverId: String, size: Int = 300) async -> UIImage? {
        // Load from server
        guard let url = connectionService.buildURL(
            endpoint: "getCoverArt",
            params: ["id": coverId, "size": "\(size)"]
        ) else {
            return nil
        }
        
        do {
            let (data, response) = try await session.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let image = UIImage(data: data) else {
                return nil
            }
            
            // Cache the image
            PersistentImageCache.shared.store(image, for: coverId, size: size)
            return image
            
        } catch {
            AppLogger.ui.error("❌ Cover art load error: \(error)")
            return nil
        }
    }
    
    func preloadCoverArt(for albums: [Album], size: Int = 200) async {
        let albumsToPreload = albums.prefix(5) // Limit concurrent requests
        
        await withTaskGroup(of: Void.self) { group in
            for album in albumsToPreload {
                group.addTask {
                    _ = await self.getCoverArt(for: album.id, size: size)
                }
            }
        }
        
        AppLogger.general.info(" Preloaded cover art for \(albumsToPreload.count) albums")
    }
    
    // MARK: -  STREAMING URLS
    
    func streamURL(for songId: String) -> URL? {
        guard !songId.isEmpty else { return nil }
        return connectionService.buildURL(endpoint: "stream", params: ["id": songId])
    }
    
    func downloadURL(for songId: String, maxBitRate: Int? = nil) -> URL? {
        guard !songId.isEmpty else { return nil }
        
        var params = ["id": songId]
        if let bitRate = maxBitRate {
            params["maxBitRate"] = "\(bitRate)"
        }
        
        return connectionService.buildURL(endpoint: "download", params: params)
    }
    
    // MARK: -  MEDIA METADATA
    
    func getMediaInfo(for songId: String) async throws -> MediaInfo? {
        guard !songId.isEmpty else { return nil }
        
        // This would call a hypothetical getMediaInfo endpoint
        // For now, we'll extract from song data
        return nil
    }
    
    // MARK: -  BATCH COVER ART OPERATIONS
    
    func getCoverArtBatch(
        items: [(id: String, size: Int)],
        maxConcurrent: Int = 3
    ) async -> [String: UIImage] {
        var results: [String: UIImage] = [:]
        
        await withTaskGroup(of: (String, UIImage?).self) { group in
            var activeCount = 0
            var pendingItems = items
            
            while !pendingItems.isEmpty || activeCount > 0 {
                // Start new tasks up to limit
                while activeCount < maxConcurrent && !pendingItems.isEmpty {
                    let item = pendingItems.removeFirst()
                    activeCount += 1
                    
                    group.addTask {
                        let image = await self.getCoverArt(for: item.id, size: item.size)
                        return (item.id, image)
                    }
                }
                
                // Wait for at least one task to complete
                if let (id, image) = await group.next() {
                    activeCount -= 1
                    if let image = image {
                        results[id] = image
                    }
                }
            }
        }
        
        return results
    }
    
    // MARK: -  CACHE MANAGEMENT
    
    func clearCoverArtCache() {
        PersistentImageCache.shared.clearCache()
        AppLogger.general.info("🧹 Cleared media cache")
    }
    
    func getCacheStats() -> MediaCacheStats {
        let cacheStats = PersistentImageCache.shared.getCacheStats()
        
        return MediaCacheStats(
            imageCount: cacheStats.diskCount,
            cacheSize: cacheStats.diskSize,
            activeRequests: 0
        )
    }
}

// MARK: -  SUPPORTING TYPES

struct MediaInfo {
    let bitRate: Int?
    let format: String?
    let duration: TimeInterval?
    let fileSize: Int64?
}

struct MediaCacheStats {
    let imageCount: Int
    let cacheSize: Int64
    let activeRequests: Int
    
    var cacheSizeFormatted: String {
        ByteCountFormatter.string(fromByteCount: cacheSize, countStyle: .file)
    }
    
    var summary: String {
        return "Images: \(imageCount), Size: \(cacheSizeFormatted), Active: \(activeRequests)"
    }
}
