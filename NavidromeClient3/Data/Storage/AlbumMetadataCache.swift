import Foundation
import SwiftUI

// MARK: - Album Metadata Cache
// FIX: Converted to Actor to move File I/O off the Main Thread
actor AlbumMetadataCache {
    static let shared = AlbumMetadataCache()
    
    private let cacheFile: URL
    private var cachedAlbums: [String: Album] = [:]
    
    private init() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        cacheFile = documentsPath.appendingPathComponent("album_metadata_cache.json")
        
        // We cannot await in init, so we start a detached task to load
        Task {
            await loadCache()
        }
    }
    
    func cacheAlbum(_ album: Album) {
        cachedAlbums[album.id] = album
        saveCache()
    }
    
    func cacheAlbums(_ albums: [Album]) {
        for album in albums {
            cachedAlbums[album.id] = album
        }
        saveCache()
    }
    
    func getAlbum(id: String) -> Album? {
        return cachedAlbums[id]
    }
    
    func getAlbums(ids: Set<String>) -> [Album] {
        return ids.compactMap { cachedAlbums[$0] }
    }
    
    func getAllCachedAlbums() -> [Album] {
        return Array(cachedAlbums.values)
    }
    
    func clearCache() {
        cachedAlbums.removeAll()
        try? FileManager.default.removeItem(at: cacheFile)
        AppLogger.general.info("📦 AlbumMetadataCache: Cache cleared")
    }
    
    // MARK: - Private I/O (Async internal handling)
    
    private func loadCache() {
        guard FileManager.default.fileExists(atPath: cacheFile.path),
              let data = try? Data(contentsOf: cacheFile),
              let albums = try? JSONDecoder().decode([String: Album].self, from: data) else {
            return
        }
        cachedAlbums = albums
        AppLogger.general.info("📦 Loaded \(cachedAlbums.count) albums from metadata cache")
    }
    
    private func saveCache() {
        guard let data = try? JSONEncoder().encode(cachedAlbums) else { return }
        try? data.write(to: cacheFile)
    }
}
