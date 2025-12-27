//
//  ExploreManager.swift
//  NavidromeClient
//
//  Swift 6: @Observable & Structured Concurrency
//

import Foundation
import SwiftUI
import Observation

@MainActor
@Observable
final class ExploreManager {
    
    // MARK: - State
    var recentAlbums: [Album] = []
    var newestAlbums: [Album] = []
    var frequentAlbums: [Album] = []
    var randomAlbums: [Album] = []
    
    var isLoading = false
    var error: String?
    
    // MARK: - Dependencies
    private weak var service: UnifiedSubsonicService?
    
    // MARK: - Configuration
    func configure(service: UnifiedSubsonicService) {
        self.service = service
    }
    
    // MARK: - Actions
    
    func loadExploreData() async {
        guard let service = service else { return }
        guard !isLoading else { return }
        
        isLoading = true
        error = nil
        
        do {
            // Swift 6: Parallel execution using 'async let'
            // We request the "Mix" from the service, which handles the parallelism internally
            // or we can do it here if the service doesn't aggregate them.
            // Based on your Service code, getDiscoveryMix exists.
            
            let mix = try await service.getDiscoveryMix(size: 20)
            
            self.recentAlbums = mix.recent
            self.newestAlbums = mix.newest
            self.frequentAlbums = mix.frequent
            self.randomAlbums = mix.random
            
        } catch {
            self.error = error.localizedDescription
            AppLogger.general.error("Explore load failed: \(error)")
        }
        
        isLoading = false
    }
    
    func refreshRandomAlbums() async {
        guard let service = service else { return }
        
        do {
            let newRandom = try await service.getRandomAlbums(size: 20)
            self.randomAlbums = newRandom
        } catch {
            // Non-critical error, just log
            AppLogger.general.error("Failed to refresh random albums: \(error)")
        }
    }
}
