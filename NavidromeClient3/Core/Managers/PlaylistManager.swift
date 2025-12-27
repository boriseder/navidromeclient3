//
//  PlaylistManager.swift
//  NavidromeClient
//
//  Swift 6: @Observable
//

import Foundation
import Observation

@MainActor
@Observable
final class PlaylistManager {
    
    // MARK: - State
    var playlists: [String] = [] // Placeholder type
    var isLoading = false
    
    // MARK: - Dependencies
    private weak var service: UnifiedSubsonicService?
    
    func configure(service: UnifiedSubsonicService) {
        self.service = service
    }
    
    func loadPlaylists() async {
        guard let service = service else { return }
        isLoading = true
        
        // Placeholder for actual API call
        // do {
        //    self.playlists = try await service.getPlaylists()
        // } catch { ... }
        
        isLoading = false
    }
}
