//
//  AppInitializer.swift
//  NavidromeClient
//
//  UPDATED: Swift 6 & iOS 17+ Modernization
//  - FIXED: Migrated from ObservableObject to @Observable
//  - Replaced Closure Observers with AsyncSequence
//  - FIXED Bug 04: initialize() guard now correctly matches .failed(_) with
//    any associated value, not just the empty string literal .failed("")
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
        // FIXED Bug 04: The old guard was:
        //
        //   guard state == .notStarted || state == .failed("") else { return }
        //
        // .failed("") is an equality check that compares the associated String
        // value to an empty string literal. A real failure like .failed("Network
        // error") never matches, so calling initialize() after a failure silently
        // did nothing — the app was permanently stuck.
        //
        // The fix uses a switch to pattern-match on the *case*, ignoring the
        // associated value entirely.

        switch state {
        case .notStarted, .failed:
            break          // proceed with initialization
        case .completed:
            return         // already done, nothing to do
        }

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

        // updateConfiguration MUST come before configureService.
        // configureService triggers a ping; if isConfigured is still false
        // at that point, updateStrategy() emits .offlineOnly before the
        // ping completes and the UI shows "no connection" on first launch.
        NetworkMonitor.shared.updateConfiguration(isConfigured: true)
        NetworkMonitor.shared.configureService(unifiedService)
        
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
        // FIXED Bug 02: SongManager needs DownloadManager so it can return
        // offline songs when the network is unavailable or the album is cached.
        songManager.configure(downloadManager: downloadManager)
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
