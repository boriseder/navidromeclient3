//
//  AlbumMetadataCache.swift
//  NavidromeClient3
//
//  Swift 6: Fixed Actor Isolation Access
//

import Foundation

// MARK: - Album Metadata Cache
actor AlbumMetadataCache {
    static let shared = AlbumMetadataCache()
    
    private let cacheFile: URL
    private var cachedAlbums: [String: Album] = [:]
    
    private init() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        cacheFile = documentsPath.appendingPathComponent("album_metadata_cache.json")
        
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
        
        // Safe: No actor state accessed inside the closure
        Task { @MainActor in
            AppLogger.general.info("📦 AlbumMetadataCache: Cache cleared")
        }
    }
    
    // MARK: - Private I/O
    
    private func loadCache() {
        guard FileManager.default.fileExists(atPath: cacheFile.path),
              let data = try? Data(contentsOf: cacheFile),
              let albums = try? JSONDecoder().decode([String: Album].self, from: data) else {
            return
        }
        cachedAlbums = albums
        
        // FIX: Capture the count locally.
        // We cannot access 'cachedAlbums.count' inside the Task because the Task
        // runs on the MainActor, while 'cachedAlbums' belongs to this actor.
        let count = albums.count
        
        Task { @MainActor in
            AppLogger.general.info("📦 Loaded \(count) albums from metadata cache")
        }
    }
    
    private func saveCache() {
        guard let data = try? JSONEncoder().encode(cachedAlbums) else { return }
        try? data.write(to: cacheFile)
    }
}
