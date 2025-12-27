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
    
    var playlists: [String] = []
    var isLoading = false
    
    private weak var service: UnifiedSubsonicService?
    
    func configure(service: UnifiedSubsonicService) {
        self.service = service
    }
    
    func loadPlaylists() async {
        // FIX: Replaced 'guard let service' with boolean check or underscore to silence warning
        guard service != nil else { return }
        isLoading = true
        
        // Placeholder for future logic
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        isLoading = false
    }
}
