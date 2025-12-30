//
//  AppInitializer.swift
//  NavidromeClient3
//
//  Swift 6: Updated to match PlayerViewModel's configure signature
//

import Foundation
import SwiftUI
import Observation

@MainActor
@Observable
final class AppInitializer {
    
    enum InitializationState {
        case notStarted
        case inProgress
        case completed
        case failed(String)
    }
    
    var state: InitializationState = .notStarted
    var isConfigured: Bool = false
    
    private let connectionViewModel: ConnectionViewModel
    private let networkMonitor: NetworkMonitor
    
    init(connectionViewModel: ConnectionViewModel, networkMonitor: NetworkMonitor) {
        self.connectionViewModel = connectionViewModel
        self.networkMonitor = networkMonitor
    }
    
    // Dependencies to be injected into ViewModels
    func configureManagers(
        coverArtManager: CoverArtManager,
        songManager: SongManager,
        downloadManager: DownloadManager,
        favoritesManager: FavoritesManager,
        exploreManager: ExploreManager,
        musicLibraryManager: MusicLibraryManager,
        playerVM: PlayerViewModel
    ) {
        // 1. Configure Connection ViewModel
        // connectionViewModel.configure(...) if needed
        
        // 2. Configure Player ViewModel (FIXED: Method now exists)
        playerVM.configure(
            musicLibraryManager: musicLibraryManager,
            downloadManager: downloadManager,
            favoritesManager: favoritesManager
        )
        
        // 3. Configure other managers if they need cross-references
    }
    
    func initialize() async throws {
        state = .inProgress
        
        // Simulate a small delay or check keychain for existing credentials
        try? await Task.sleep(for: .seconds(0.5))
        
        // Check if we have saved credentials
        if let _ = KeyChainHelper.shared.retrieveCredentials() {
            self.isConfigured = true
            AppLogger.general.info("App Initialized: Credentials found.")
        } else {
            self.isConfigured = false
            AppLogger.general.info("App Initialized: No credentials found.")
        }
        
        state = .completed
    }
}
