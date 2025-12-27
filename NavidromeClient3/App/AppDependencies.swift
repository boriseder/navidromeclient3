//
//  AppDependencies.swift
//  NavidromeClient3
//
//  Swift 6: Centralized Dependency Injection Container
//

import Foundation
import SwiftUI
import Observation

@MainActor
@Observable
final class AppDependencies {
    
    // MARK: - Infrastructure Singletons
    // Use .shared for managers that enforce singleton pattern via private init
    let appConfig = AppConfig.shared
    let networkMonitor = NetworkMonitor.shared
    let audioSessionManager = AudioSessionManager.shared
    let downloadManager = DownloadManager.shared
    let offlineManager = OfflineManager.shared
    let coverArtManager = CoverArtManager.shared // FIX: Use shared instance
    
    // MARK: - Managers (Scoped/New Instances)
    let themeManager = ThemeManager()
    let connectionViewModel = ConnectionViewModel()
    
    // Data Managers
    let songManager = SongManager()
    let exploreManager = ExploreManager()
    let favoritesManager = FavoritesManager()
    let playlistManager = PlaylistManager()
    
    // Core Logic
    let musicLibraryManager = MusicLibraryManager()
    let appInitializer = AppInitializer() // Assumed to accept dependencies via init or config
    
    // Complex Dependencies
    let playerViewModel: PlayerViewModel
    
    // Core Services (Actors)
    let unifiedService: UnifiedSubsonicService
    
    init() {
        // 1. Initialize Core Services
        // Placeholder credentials; real ones loaded by AppConfig/ConnectionViewModel later
        self.unifiedService = UnifiedSubsonicService(
            baseURL: URL(string: "http://localhost")!,
            username: "",
            password: ""
        )
        
        // 2. Resolve Init-Dependency: Player needs CoverArt
        self.playerViewModel = PlayerViewModel(coverArtManager: CoverArtManager.shared)
        
        // 3. Resolve Cyclic/Property Dependency: AudioSession needs Player
        // Note: AudioSessionManager is a singleton, so we assign the property
        AudioSessionManager.shared.playerViewModel = self.playerViewModel
        
        // 4. Resolve Singleton Dependency: DownloadManager needs CoverArt
        DownloadManager.shared.configure(coverArtManager: CoverArtManager.shared)
        
        // 5. Configure AppInitializer
        // Assuming AppInitializer has a configure method or public properties,
        // otherwise we'd inject in its init.
        // self.appInitializer.configure(...)
    }
}
