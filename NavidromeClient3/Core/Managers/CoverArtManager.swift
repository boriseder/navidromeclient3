//
//  CoverArtManager.swift
//  NavidromeClient3
//
//  Swift 6: @Observable Migration
//

import SwiftUI
import Observation
import Combine

@MainActor
@Observable
final class CoverArtManager {
    static let shared = CoverArtManager()
    
    // MARK: - State
    // @Observable tracks these automatically
    var cacheGeneration: Int = 0
    
    // Internal tracking for loading states
    private var loadingStates: [String: Bool] = [:]
    private var errorStates: [String: String] = [:]
    
    // Memory Cache (UIImage is MainActor-isolated, so this fits)
    private let memoryCache = NSCache<NSString, UIImage>()
    
    // Dependencies
    private weak var service: UnifiedSubsonicService?
    
    // MARK: - Initialization
    private init() {
        memoryCache.countLimit = 200 // Max 200 images in memory
    }
    
    func configure(service: UnifiedSubsonicService) {
        self.service = service
    }
    
    // MARK: - Public API
    
    func getAlbumImage(for id: String, context: ImageContext) -> UIImage? {
        let key = cacheKey(id: id, size: context.size)
        return memoryCache.object(forKey: key as NSString)
    }
    
    func getArtistImage(for id: String, context: ImageContext) -> UIImage? {
        // Re-use logic for now, or implement specific artist endpoint if API supports it
        // Often artist images use the same 'getCoverArt' endpoint with artist ID
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
        
        // 1. Check Memory
        if let cached = memoryCache.object(forKey: key as NSString) {
            return cached
        }
        
        // 2. Check Disk (Async)
        // Accessing PersistentImageCache (Actor)
        if let diskImage = await PersistentImageCache.shared.retrieve(for: id, size: size) {
            memoryCache.setObject(diskImage, forKey: key as NSString)
            // Trigger UI update
            cacheGeneration += 1
            return diskImage
        }
        
        // 3. Fetch from Network
        guard let service = service else { return nil }
        
        // Prevent duplicate requests
        if loadingStates[key] == true { return nil }
        
        loadingStates[key] = true
        errorStates[key] = nil
        
        // Note: We don't increment cacheGeneration for loading state changes to avoid excessive redraws,
        // but @Observable might track the dictionary change.
        
        defer {
            loadingStates[key] = false
        }
        
        // Call Actor
        if let image = await service.getCoverArt(for: id, size: size) {
            memoryCache.setObject(image, forKey: key as NSString)
            cacheGeneration += 1
            return image
        } else {
            errorStates[key] = "Failed to load"
            return nil
        }
    }
    
    // Alias for artists if logic is identical
    func loadArtistImage(for id: String, context: ImageContext) async -> UIImage? {
        return await loadAlbumImage(for: id, context: context)
    }
    
    // MARK: - Helpers
    
    private func cacheKey(id: String, size: Int) -> String {
        return "\(id)_\(size)"
    }
    
    func clearMemoryCache() {
        memoryCache.removeAllObjects()
        cacheGeneration += 1
    }
}
