//
//  SongManager.swift
//  NavidromeClient
//
//  Swift 6: @Observable
//

import Foundation
import Observation

@MainActor
@Observable
final class SongManager {
    
    // MARK: - Dependencies
    private weak var service: UnifiedSubsonicService?
    
    // MARK: - Configuration
    func configure(service: UnifiedSubsonicService) {
        self.service = service
    }
    
    // MARK: - Actions
    
    func getSongs(for albumId: String) async -> [Song] {
        guard let service = service else { return [] }
        
        do {
            return try await service.getSongs(for: albumId)
        } catch {
            AppLogger.general.error("Failed to load songs for album \(albumId): \(error)")
            return []
        }
    }
    
    // Helper to get a full song object if we only have an ID
    // (Useful for deep links or notifications)
    func fetchSongDetails(id: String) async -> Song? {
        // Assuming your service has a getSong(id:) method.
        // If not, you might need to fetch the album or search.
        // For now, returning nil as placeholder if endpoint doesn't exist.
        return nil
    }
}
