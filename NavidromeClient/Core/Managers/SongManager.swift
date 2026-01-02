//
//  SongManager.swift
//  NavidromeClient
//
//  UPDATED: Swift 6 & iOS 17+ Modernization
//  - Migrated to @Observable
//

import Foundation
import Observation

@MainActor
@Observable
class SongManager {
    private(set) var isLoading = false
    private(set) var error: String?
    
    @ObservationIgnored private weak var service: UnifiedSubsonicService?
    
    func configure(service: UnifiedSubsonicService) {
        self.service = service
    }
    
    func reset() {
        error = nil
        isLoading = false
    }
    
    func loadSongs(for albumId: String) async -> [Song] {
        isLoading = true
        error = nil
        
        guard let service = service else {
            isLoading = false
            error = "Service not configured"
            return []
        }
        
        do {
            let songs = try await service.getAlbumDetails(id: albumId)
            isLoading = false
            return songs
        } catch {
            isLoading = false
            self.error = error.localizedDescription
            AppLogger.general.error("Failed to load songs: \(error)")
            return []
        }
    }
}
