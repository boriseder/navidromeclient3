//
//  AppInitializer.swift
//  NavidromeClient
//
//  Master coordinator for app lifecycle
//  Owns initialization state and service management
//

import Foundation

@MainActor
final class AppInitializer: ObservableObject {

    // MARK: - Initialization State
    
    enum InitializationState: Equatable {
        case notStarted
        case inProgress
        case completed
        case failed(String)
    }

    @Published private(set) var state: InitializationState = .notStarted
    @Published private(set) var isConfigured: Bool = false

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
        // Listen for credential updates
        NotificationCenter.default.addObserver(
            forName: .credentialsUpdated,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                guard let credentials = notification.object as? ServerCredentials else { return }
                try? await self?.reinitializeAfterConfiguration()
            }
        }
    }

    func initialize() async throws {
        guard state == .notStarted || state == .failed("") else { return }

        state = .inProgress
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
        
        // Reset current state
        reset()
        
        // Reinitialize with new credentials
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

        // Configure network monitor with service
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
        guard state == .completed else {
            AppLogger.general.warn("[AppInitializer] Cannot configure managers - not initialized")
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
        guard state == .completed else {
            AppLogger.general.warn("[AppInitializer] Cannot load data - not initialized")
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

    // AppInitializer.swift
    func performFactoryReset() async {
        AppLogger.general.info("[AppInitializer] === Factory Reset Start ===")
        
        // 1. Clear credentials via AppConfig
        AppConfig.shared.clearCredentials()
        
        // 2. Reset network monitor FIRST (before state change)
        NetworkMonitor.shared.updateConfiguration(isConfigured: false)
        NetworkMonitor.shared.reset()
        
        // 3. Notify all managers to reset
        NotificationCenter.default.post(name: .factoryResetRequested, object: nil)
        
        // 4. Reset local state but keep .completed (triggers WelcomeView)
        unifiedService = nil
        isConfigured = false
        state = .completed  // ✅ Bleibt .completed, aber unconfigured
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
