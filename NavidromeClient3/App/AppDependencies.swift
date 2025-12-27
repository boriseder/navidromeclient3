
//
//  AppDependencies.swift
//  NavidromeClient3
//
//  Swift 6: Centralized Dependency Injection Container
//  Analyzed Dependency Graph:
//  - PlayerViewModel -> needs CoverArtManager (Init Injection)
//  - AudioSessionManager (Singleton) -> needs PlayerViewModel (Property Injection)
//  - DownloadManager (Singleton) -> needs CoverArtManager (Method Injection)
//  - AppInitializer -> Orchestrates Service Injection dynamically
//

import Foundation
import SwiftUI
import Observation

@MainActor
@Observable
final class AppDependencies {
    
    // MARK: - Infrastructure Singletons
    // We hold references here to expose them to the Environment cleanly
    let appConfig = AppConfig.shared
    let networkMonitor = NetworkMonitor.shared
    let audioSessionManager = AudioSessionManager.shared
    let downloadManager = DownloadManager.shared
    let offlineManager = OfflineManager.shared
    
    // MARK: - Managers (Scoped to App Lifecycle)
    let themeManager = ThemeManager()
    let connectionViewModel = ConnectionViewModel()
    
    // Data Managers
    let coverArtManager = CoverArtManager()
    let songManager = SongManager()
    let exploreManager = ExploreManager()
    let favoritesManager = FavoritesManager()
    
    // Core Logic
    let musicLibraryManager = MusicLibraryManager()
    let appInitializer = AppInitializer()
    
    // Complex Dependencies
    let playerViewModel: PlayerViewModel
    
    init() {
        AppLogger.general.info("[AppDependencies] 🏗️ Building dependency graph...")
        
        // 1. Resolve Init-Dependency: Player needs CoverArt
        self.playerViewModel = PlayerViewModel(coverArtManager: coverArtManager)
        
        // 2. Resolve Cyclic/Property Dependency: AudioSession needs Player
        self.audioSessionManager.playerViewModel = self.playerViewModel
        
        // 3. Resolve Singleton Dependency: DownloadManager needs CoverArt
        // Note: DownloadManager is a singleton, but CoverArtManager is scoped. 
        // We configure the singleton with our scoped instance.
        self.downloadManager.configure(coverArtManager: coverArtManager)
        
        AppLogger.general.info("[AppDependencies] ✅ Graph constructed successfully")
    }
}
