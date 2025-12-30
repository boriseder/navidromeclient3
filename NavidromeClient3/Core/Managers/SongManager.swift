//
//  SongManager.swift
//  NavidromeClient3
//
//  Swift 6: Added getSongs for AlbumDetailView
//

import Foundation
import Observation

@MainActor
@Observable
final class SongManager {
    // MARK: - State
    var isLoading = false
    
    // MARK: - Dependencies
    private weak var service: UnifiedSubsonicService?
    
    // MARK: - Init
    init() {}
    
    func configure(service: UnifiedSubsonicService) {
        self.service = service
    }
    
    // MARK: - Actions
    
    func getSongs(for albumId: String) async throws -> [Song] {
        guard let service = service else {
            throw NSError(domain: "NavidromeClient", code: 0, userInfo: [NSLocalizedDescriptionKey: "Service not configured"])
        }
        
        let songs = try await service.getSongs(for: albumId)
        return songs
    }
}
