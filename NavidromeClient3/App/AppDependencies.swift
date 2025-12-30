//
//  AppDependencies.swift
//  NavidromeClient3
//
//  Swift 6: Fixed AudioSessionManager initialization errors
//

import Foundation
import SwiftUI
import Observation

@MainActor
@Observable
final class AppDependencies {
    
    // Core Managers
    let appConfig: AppConfig
    let appInitializer: AppInitializer
    let networkMonitor: NetworkMonitor
    let themeManager: ThemeManager
    
    // Data Managers
    let musicLibraryManager: MusicLibraryManager
    let coverArtManager: CoverArtManager
    let songManager: SongManager
    let exploreManager: ExploreManager
    let favoritesManager: FavoritesManager
    let downloadManager: DownloadManager
    let offlineManager: OfflineManager
    
    // Audio & Playback
    let audioSessionManager: AudioSessionManager
    // let lockScreenManager: LockScreenManager // Uncomment if you are using it
    
    // ViewModels
    let connectionViewModel: ConnectionViewModel
    let playerViewModel: PlayerViewModel
    
    init() {
        // 1. Config & Base
        self.appConfig = AppConfig.shared
        self.networkMonitor = NetworkMonitor.shared
        self.themeManager = ThemeManager()
        
        // 2. ViewModels
        self.connectionViewModel = ConnectionViewModel()
        self.playerViewModel = PlayerViewModel()
        
        // 3. Audio Session (FIXED: No arguments needed)
        self.audioSessionManager = AudioSessionManager.shared
        
        // 4. Data Managers (Initialize with dependencies if needed)
        // Assuming these have standard inits or singleton access patterns as per your codebase
        self.musicLibraryManager = MusicLibraryManager()
        self.coverArtManager = CoverArtManager()
        self.songManager = SongManager()
        self.exploreManager = ExploreManager()
        self.favoritesManager = FavoritesManager()
        self.downloadManager = DownloadManager()
        self.offlineManager = OfflineManager()
        
        // 5. Initializer
        self.appInitializer = AppInitializer(
            connectionViewModel: connectionViewModel,
            networkMonitor: networkMonitor
        )
        
        // 6. Setup Relationships (Manual Dependency Injection)
        // Note: We do NOT assign playerViewModel to audioSessionManager anymore.
        // If LockScreenManager exists, it would be initialized here:
        // self.lockScreenManager = LockScreenManager(playerViewModel: playerViewModel)
    }
}
