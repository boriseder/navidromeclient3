//
//  AppInitializer.swift
//  NavidromeClient3
//
//  Swift 6: Orchestrates Service Injection (Fixes Playback Auth)
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
    
    // MARK: - Manager References (Weak to avoid cycles)
    private weak var coverArtManager: CoverArtManager?
    private weak var songManager: SongManager?
    private weak var downloadManager: DownloadManager?
    private weak var favoritesManager: FavoritesManager?
    private weak var exploreManager: ExploreManager?
    private weak var musicLibraryManager: MusicLibraryManager?
    private weak var playerVM: PlayerViewModel?
    private weak var offlineManager: OfflineManager?
    
    init(connectionViewModel: ConnectionViewModel, networkMonitor: NetworkMonitor) {
        self.connectionViewModel = connectionViewModel
        self.networkMonitor = networkMonitor
    }
    
    // MARK: - Configuration
    
    func configureManagers(
        coverArtManager: CoverArtManager,
        songManager: SongManager,
        downloadManager: DownloadManager,
        favoritesManager: FavoritesManager,
        exploreManager: ExploreManager,
        musicLibraryManager: MusicLibraryManager,
        playerVM: PlayerViewModel,
        offlineManager: OfflineManager
    ) {
        // 1. Store references for later service injection
        self.coverArtManager = coverArtManager
        self.songManager = songManager
        self.downloadManager = downloadManager
        self.favoritesManager = favoritesManager
        self.exploreManager = exploreManager
        self.musicLibraryManager = musicLibraryManager
        self.playerVM = playerVM
        self.offlineManager = offlineManager
        
        // 2. Configure Player Dependencies
        playerVM.configure(
            musicLibraryManager: musicLibraryManager,
            downloadManager: downloadManager,
            favoritesManager: favoritesManager
        )
        
        // 3. Configure Manager Inter-dependencies
        downloadManager.configure(coverArtManager: coverArtManager)
    }
    
    // MARK: - Initialization Logic
    
    func initialize() async throws {
        state = .inProgress
        
        try? await Task.sleep(for: .seconds(0.5))
        
        if let credentials = AppConfig.shared.getCredentials() {
            self.isConfigured = true
            AppLogger.general.info("App Initialized: Credentials found.")
            setupService(with: credentials)
        } else {
            self.isConfigured = false
            AppLogger.general.info("App Initialized: No credentials found.")
        }
        
        state = .completed
    }
    
    // MARK: - Service Orchestration
    
    func setupService(with credentials: ServerCredentials) {
        AppLogger.general.info("Configuring Subsonic Service for: \(credentials.baseURL)")
        
        let service = UnifiedSubsonicService(
            baseURL: credentials.baseURL,
            username: credentials.username,
            password: credentials.password
        )
        
        networkMonitor.configureService(service)
        
        // Inject into ALL managers including PlayerViewModel
        musicLibraryManager?.configure(service: service)
        coverArtManager?.configure(service: service)
        songManager?.configure(service: service)
        exploreManager?.configure(service: service)
        favoritesManager?.configure(service: service)
        downloadManager?.configure(service: service)
        offlineManager?.configure(service: service)
        
        // FIX: Inject service into PlayerViewModel for URL generation
        playerVM?.configure(service: service)
        
        if networkMonitor.isConnected {
            Task {
                await musicLibraryManager?.loadInitialDataIfNeeded()
            }
        }
    }
}
