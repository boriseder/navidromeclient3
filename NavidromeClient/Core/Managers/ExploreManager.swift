//
//  ExploreManager.swift
//  NavidromeClient
//
//  UPDATED: Swift 6 & iOS 17+ Modernization
//  - Migrated to @Observable
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
    
    @ObservationIgnored private weak var service: UnifiedSubsonicService?
    
    func configure(service: UnifiedSubsonicService) {
        self.service = service
    }
    
    func loadExploreData() async {
        guard let service = service else { return }
        isLoading = true
        error = nil
        
        do {
            async let recent = service.getRecentAlbums()
            async let random = service.getRandomAlbums()
            async let frequent = service.getFrequentAlbums()
            async let newest = service.getNewestAlbums()
            
            let (r, rnd, f, n) = try await (recent, random, frequent, newest)
            
            self.recentAlbums = r
            self.randomAlbums = rnd
            self.frequentAlbums = f
            self.newestAlbums = n
            
            AppLogger.general.info("ExploreManager: Loaded explore data")
        } catch {
            self.error = error.localizedDescription
            AppLogger.general.error("ExploreManager failed: \(error)")
        }
        
        isLoading = false
    }
}
