//
//  AlbumMetadataCache.swift
//  NavidromeClient
//
//  REFACTORED: Swift 6 — Step 1
//  - Converted from @MainActor class to actor
//  - All disk I/O delegated to StorageActor
//  - No blocking reads anywhere
//

import Foundation

actor AlbumMetadataCache {
    
    // MARK: - Singleton (replaced by DI in Step 7)
    static let shared = AlbumMetadataCache(storage: AppStorageActor.shared)
    
    // MARK: - Dependencies
    private let storage: StorageActor
    
    // MARK: - State (actor-isolated)
    private var cachedAlbums: [String: Album] = [:]
    private var isLoaded = false
    private var saveDebounceTask: Task<Void, Never>?
    
    // MARK: - Init
    
    init(storage: StorageActor) {
        self.storage = storage
        // No blocking I/O in init.
        // First call to any public method triggers lazy load.
    }
    
    // MARK: - Lazy Load
    
    private func ensureLoaded() async {
        guard !isLoaded else { return }
        cachedAlbums = await storage.loadAlbums()
        isLoaded = true
        AppLogger.general.info("AlbumMetadataCache: Loaded \(cachedAlbums.count) albums from disk")
    }
    
    // MARK: - Public API
    
    func cacheAlbum(_ album: Album) async {
        await ensureLoaded()
        cachedAlbums[album.id] = album
        scheduleSave()
    }
    
    func cacheAlbums(_ albums: [Album]) async {
        await ensureLoaded()
        for album in albums {
            cachedAlbums[album.id] = album
        }
        scheduleSave()
    }
    
    func getAlbum(id: String) async -> Album? {
        await ensureLoaded()
        return cachedAlbums[id]
    }
    
    func getAlbums(ids: Set<String>) async -> [Album] {
        await ensureLoaded()
        return ids.compactMap { cachedAlbums[$0] }
    }
    
    func getAllCachedAlbums() async -> [Album] {
        await ensureLoaded()
        return Array(cachedAlbums.values)
    }
    
    func clearCache() async {
        cachedAlbums.removeAll()
        isLoaded = true // Mark loaded so ensureLoaded won't reload stale data
        await storage.clearAlbumsFile()
        AppLogger.general.info("AlbumMetadataCache: Cache cleared")
    }
    
    // MARK: - Private
    
    private func scheduleSave() {
        saveDebounceTask?.cancel()
        
        let snapshot = cachedAlbums
        let stor = storage
        
        saveDebounceTask = Task.detached {
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2s coalesce window
            guard !Task.isCancelled else { return }
            await stor.saveAlbums(snapshot)
        }
    }
}
