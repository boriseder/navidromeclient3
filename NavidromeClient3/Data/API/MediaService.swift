import Foundation
import UIKit

// FIX: Converted to Actor
actor MediaService {
    private let connectionService: ConnectionService
    private let session: URLSession
    
    init(connectionService: ConnectionService) {
        self.connectionService = connectionService
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 20
        config.timeoutIntervalForResource = 120
        self.session = URLSession(configuration: config)
    }
    
    // MARK: -  COVER ART API
    
    func getCoverArt(for coverId: String, size: Int = 300) async -> UIImage? {
        // FIX: await connectionService
        guard let url = await connectionService.buildURL(
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
            
            // FIX: await PersistentImageCache (it is an actor)
            await PersistentImageCache.shared.store(image, for: coverId, size: size)
            return image
            
        } catch {
            AppLogger.ui.error("❌ Cover art load error: \(error)")
            return nil
        }
    }
    
    func preloadCoverArt(for albums: [Album], size: Int = 200) async {
        let albumsToPreload = albums.prefix(5)
        
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
    
    // FIX: Must be async because buildURL is async
    func streamURL(for songId: String) async -> URL? {
        guard !songId.isEmpty else { return nil }
        return await connectionService.buildURL(endpoint: "stream", params: ["id": songId])
    }
    
    // FIX: Must be async
    func downloadURL(for songId: String, maxBitRate: Int? = nil) async -> URL? {
        guard !songId.isEmpty else { return nil }
        
        var params = ["id": songId]
        if let bitRate = maxBitRate {
            params["maxBitRate"] = "\(bitRate)"
        }
        
        return await connectionService.buildURL(endpoint: "download", params: params)
    }
    
    // MARK: -  MEDIA METADATA
    
    func getMediaInfo(for songId: String) async throws -> MediaInfo? {
        guard !songId.isEmpty else { return nil }
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
                while activeCount < maxConcurrent && !pendingItems.isEmpty {
                    let item = pendingItems.removeFirst()
                    activeCount += 1
                    
                    group.addTask {
                        let image = await self.getCoverArt(for: item.id, size: item.size)
                        return (item.id, image)
                    }
                }
                
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
    
    func clearCoverArtCache() async {
        // FIX: await PersistentImageCache
        await PersistentImageCache.shared.clearCache()
        AppLogger.general.info("🧹 Cleared media cache")
    }
    
    func getCacheStats() async -> MediaCacheStats {
        // FIX: await PersistentImageCache
        let cacheStats = await PersistentImageCache.shared.getCacheStats()
        
        return MediaCacheStats(
            imageCount: cacheStats.diskCount,
            cacheSize: cacheStats.diskSize,
            activeRequests: 0
        )
    }
}

struct MediaInfo: Sendable {
    let bitRate: Int?
    let format: String?
    let duration: TimeInterval?
    let fileSize: Int64?
}

struct MediaCacheStats: Sendable {
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
