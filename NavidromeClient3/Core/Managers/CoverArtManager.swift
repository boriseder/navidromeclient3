//
//  CoverArtManager.swift
//  NavidromeClient3
//
//  Swift 6: Removed deinit (Singleton does not need explicit cleanup)
//

import SwiftUI
import Observation
import Combine

@MainActor
@Observable
final class CoverArtManager {
    static let shared = CoverArtManager()
    
    // MARK: - State
    var cacheGeneration: Int = 0
    var sceneObservers: [NSObjectProtocol] = []
    
    // Internal tracking for loading states
    private var loadingStates: [String: Bool] = [:]
    private var errorStates: [String: String] = [:]
    
    private let memoryCache = NSCache<NSString, UIImage>()
    private weak var service: UnifiedSubsonicService?
    
    // MARK: - Initialization
    private init() {
        memoryCache.countLimit = 200
        setupScenePhaseObserver()
    }
    
    // FIX: Removed deinit.
    // Since this is a Singleton, it never deinitializes during the app's life.
    // Removing this fixes the "Main actor-isolated" error in deinit.
    
    func configure(service: UnifiedSubsonicService) {
        self.service = service
    }
    
    // MARK: - Public API
    
    func getAlbumImage(for id: String, context: ImageContext) -> UIImage? {
        let key = cacheKey(id: id, size: context.size)
        return memoryCache.object(forKey: key as NSString)
    }
    
    func getArtistImage(for id: String, context: ImageContext) -> UIImage? {
        let key = cacheKey(id: id, size: context.size)
        return memoryCache.object(forKey: key as NSString)
    }
    
    func isLoadingImage(for id: String, size: Int) -> Bool {
        let key = cacheKey(id: id, size: size)
        return loadingStates[key] ?? false
    }
    
    func getImageError(for id: String, size: Int) -> String? {
        let key = cacheKey(id: id, size: size)
        return errorStates[key]
    }
    
    // MARK: - Actions
    
    func loadAlbumImage(for id: String, context: ImageContext) async -> UIImage? {
        let size = context.size
        let key = cacheKey(id: id, size: size)
        
        if let cached = memoryCache.object(forKey: key as NSString) {
            return cached
        }
        
        if let diskImage = await PersistentImageCache.shared.retrieve(for: id, size: size) {
            memoryCache.setObject(diskImage, forKey: key as NSString)
            cacheGeneration += 1
            return diskImage
        }
        
        guard let service = service else { return nil }
        
        if loadingStates[key] == true { return nil }
        
        loadingStates[key] = true
        errorStates[key] = nil
        
        defer { loadingStates[key] = false }
        
        if let image = await service.getCoverArt(for: id, size: size) {
            memoryCache.setObject(image, forKey: key as NSString)
            cacheGeneration += 1
            return image
        } else {
            errorStates[key] = "Failed to load"
            return nil
        }
    }
    
    func loadArtistImage(for id: String, context: ImageContext) async -> UIImage? {
        return await loadAlbumImage(for: id, context: context)
    }
    
    // MARK: - Helpers
    
    func incrementCacheGeneration() {
        cacheGeneration += 1
    }
    
    private func cacheKey(id: String, size: Int) -> String {
        return "\(id)_\(size)"
    }
    
    func clearMemoryCache() {
        memoryCache.removeAllObjects()
        cacheGeneration += 1
    }
}
