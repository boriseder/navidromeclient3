//
//  ExploreManager.swift
//  NavidromeClient
//
//  UPDATED: Swift 6 & iOS 17+ Modernization
//  - Optimized shelf limits
//  - Added missing computed properties and methods
//

import Foundation
import Observation

@MainActor
@Observable
class ExploreManager {
    private(set) var recentAlbums: [Album] = []
    private(set) var randomAlbums: [Album] = []
    private(set) var frequentAlbums: [Album] = []
    private(set) var newestAlbums: [Album] = []
    
    private(set) var isLoading = false
    private(set) var error: String?
    private(set) var hasCompletedInitialLoad = false
    
    @ObservationIgnored private weak var service: UnifiedSubsonicService?
    
    // Fix: Limit display to 12 items for horizontal shelves
    private let shelfLimit = 12
    
    var hasExploreViewData: Bool {
        !recentAlbums.isEmpty || !randomAlbums.isEmpty ||
        !frequentAlbums.isEmpty || !newestAlbums.isEmpty
    }
    
    func configure(service: UnifiedSubsonicService) {
        self.service = service
    }
    
    func loadExploreData() async {
        guard let service = service else { return }
        isLoading = true
        error = nil
        
        do {
            // Now works because UnifiedSubsonicService accepts 'size'
            async let recent = service.getRecentAlbums(size: shelfLimit)
            async let random = service.getRandomAlbums(size: shelfLimit)
            async let frequent = service.getFrequentAlbums(size: shelfLimit)
            async let newest = service.getNewestAlbums(size: shelfLimit)
            
            let (r, rnd, f, n) = try await (recent, random, frequent, newest)
            
            self.recentAlbums = r
            self.randomAlbums = rnd
            self.frequentAlbums = f
            self.newestAlbums = n
            
            hasCompletedInitialLoad = true
            
            AppLogger.general.info("ExploreManager: Loaded explore data (limit: \(shelfLimit))")
        } catch {
            self.error = error.localizedDescription
            AppLogger.general.error("ExploreManager failed: \(error)")
        }
        
        isLoading = false
    }
    
    func refreshRandomAlbums() async {
        guard let service = service else { return }
        
        do {
            let random = try await service.getRandomAlbums(size: shelfLimit)
            self.randomAlbums = random
            AppLogger.general.info("ExploreManager: Refreshed random albums")
        } catch {
            self.error = error.localizedDescription
            AppLogger.general.error("ExploreManager refresh failed: \(error)")
        }
    }
}
