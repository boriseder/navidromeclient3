//
//  AppInitializer.swift
//  NavidromeClient
//
//  UPDATED: Swift 6 & iOS 17+ Modernization
//  - FIXED: Migrated from ObservableObject to @Observable
//  - Replaced Closure Observers with AsyncSequence
//

import Foundation
import Observation

@MainActor
@Observable
final class AppInitializer {

    // MARK: - Initialization State
    
    enum InitializationState: Equatable {
        case notStarted
        case completed
        case failed(String)
    }

    var state: InitializationState = .notStarted
    private(set) var isConfigured: Bool = false

    private(set) var unifiedService: UnifiedSubsonicService?
    
    // MARK: - Computed Properties
    
    var areServicesReady: Bool {
        return isConfigured && state == .completed
    }

    // MARK: - Initialization

    init() {
        setupNotificationObservers()
    }
    
    private func setupNotificationObservers() {
        Task { @MainActor in
            for await notification in NotificationCenter.default.notifications(named: .credentialsUpdated) {
                guard notification.object is ServerCredentials else { continue }
                
                try? await self.reinitializeAfterConfiguration()
            }
        }
    }

    func initialize() async throws {
        guard state == .notStarted || state == .failed("") else { return }

        // Remove: state = .inProgress
        AppLogger.general.info("[AppInitializer] === Initialization start ===")
        
        let credentials = AppConfig.shared.getCredentials()
        isConfigured = credentials != nil

        if let creds = credentials {
            try createUnifiedService(with: creds)
        }

        state = .completed
        AppLogger.general.info("[AppInitializer] === Initialization completed (configured: \(isConfigured)) ===")
    }

    // MARK: - Reinitialization

    func reinitializeAfterConfiguration() async throws {
        AppLogger.general.info("[AppInitializer] Reinitializing after configuration...")
        
        reset()
        try await initialize()
        
        AppLogger.general.info("[AppInitializer] Reinitialization completed")
    }

    // MARK: - Service Management
    
    private func createUnifiedService(with creds: ServerCredentials) throws {
        unifiedService = UnifiedSubsonicService(
            baseURL: creds.baseURL,
            username: creds.username,
            password: creds.password
        )

        NetworkMonitor.shared.configureService(unifiedService)
        NetworkMonitor.shared.updateConfiguration(isConfigured: true)
        
        AppLogger.general.info("[AppInitializer] UnifiedSubsonicService created and configured")
    }

    // MARK: - Manager Configuration

    func configureManagers(
        coverArtManager: CoverArtManager,
        songManager: SongManager,
        downloadManager: DownloadManager,
        favoritesManager: FavoritesManager,
        exploreManager: ExploreManager,
        musicLibraryManager: MusicLibraryManager,
        playerVM: PlayerViewModel
    ) {
        // Change: Only check for .completed
        guard state == .completed else {
            AppLogger.general.warn("[AppInitializer] Cannot configure managers - not initialized (state: \(state))")
            return
        }
        
        guard let service = unifiedService else {
            AppLogger.general.warn("[AppInitializer] Cannot configure managers - no service")
            return
        }

        AppLogger.general.info("[AppInitializer] Configuring all managers...")

        coverArtManager.configure(service: service)
        songManager.configure(service: service)
        downloadManager.configure(service: service)
        downloadManager.configure(coverArtManager: coverArtManager)
        favoritesManager.configure(service: service)
        exploreManager.configure(service: service)
        musicLibraryManager.configure(service: service)
        
        playerVM.configure(service: service)

        AppLogger.general.info("[AppInitializer] ✅ All managers configured successfully")
    }

    // MARK: - Data Load

    func loadInitialData(
        exploreManager: ExploreManager,
        favoritesManager: FavoritesManager,
        musicLibraryManager: MusicLibraryManager
    ) async {
        // Change: Only check for .completed
        guard state == .completed else {
            AppLogger.general.warn("[AppInitializer] Cannot load data - not initialized (state: \(state))")
            return
        }
        
        guard unifiedService != nil else {
            AppLogger.general.warn("[AppInitializer] Cannot load data - no service")
            return
        }

        AppLogger.general.info("[AppInitializer] Loading initial data...")

        await withTaskGroup(of: Void.self) { group in
            group.addTask { await exploreManager.loadExploreData() }
            group.addTask { await favoritesManager.loadFavoriteSongs() }
            group.addTask { await musicLibraryManager.loadInitialDataIfNeeded() }
        }
        
        AppLogger.general.info("[AppInitializer] ✅ Initial data loaded")
    }

    // MARK: - Factory Reset

    func performFactoryReset() async {
        AppLogger.general.info("[AppInitializer] === Factory Reset Start ===")
        
        AppConfig.shared.clearCredentials()
        
        NetworkMonitor.shared.updateConfiguration(isConfigured: false)
        NetworkMonitor.shared.reset()
        
        NotificationCenter.default.post(name: .factoryResetRequested, object: nil)
        
        unifiedService = nil
        isConfigured = false
        state = .completed
        NetworkMonitor.shared.configureService(nil)
        
        AppLogger.general.info("[AppInitializer] === Factory Reset Complete ===")
    }
    
    // MARK: - Reset

    func reset() {
        unifiedService = nil
        state = .notStarted
        isConfigured = false
        NetworkMonitor.shared.configureService(nil)
        
        AppLogger.general.info("[AppInitializer] State reset")
    }
}
