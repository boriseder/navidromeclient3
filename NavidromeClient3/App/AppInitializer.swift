//
//  AppInitializer.swift
//  NavidromeClient3
//
//  Swift 6: Migrated to @Observable & Actor-ready
//

import Foundation
import Observation

@MainActor
@Observable
final class AppInitializer {
    
    // MARK: - Initialization State
    enum InitializationState: Equatable, Sendable {
        case notStarted
        case inProgress
        case completed
        case failed(String)
    }

    // Observation tracks these automatically
    var state: InitializationState = .notStarted
    var isConfigured: Bool = false

    // This will eventually become an Actor in Phase 5
    private(set) var unifiedService: UnifiedSubsonicService?
    
    var areServicesReady: Bool {
        return isConfigured && state == .completed
    }

    init() {
        setupNotificationObservers()
    }
    
    private func setupNotificationObservers() {
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

    func reinitializeAfterConfiguration() async throws {
        AppLogger.general.info("[AppInitializer] Reinitializing after configuration...")
        reset()
        try await initialize()
    }

    // MARK: - Service Creation
    private func createUnifiedService(with creds: ServerCredentials) throws {
        // Phase 5 Warning: When UnifiedSubsonicService becomes an Actor,
        // this assignment remains fine, but usages will need 'await'.
        unifiedService = UnifiedSubsonicService(
            baseURL: creds.baseURL,
            username: creds.username,
            password: creds.password
        )

        NetworkMonitor.shared.configureService(unifiedService)
        NetworkMonitor.shared.updateConfiguration(isConfigured: true)
        
        AppLogger.general.info("[AppInitializer] Service created")
    }

    // MARK: - Dependency Wiring
    // This injects the "Dynamic" Service into the "Static" Managers
    func configureManagers(
        coverArtManager: CoverArtManager,
        songManager: SongManager,
        downloadManager: DownloadManager,
        favoritesManager: FavoritesManager,
        exploreManager: ExploreManager,
        musicLibraryManager: MusicLibraryManager,
        playerVM: PlayerViewModel
    ) {
        guard state == .completed, let service = unifiedService else {
            AppLogger.general.warn("[AppInitializer] Cannot configure managers - Service not ready")
            return
        }

        AppLogger.general.info("[AppInitializer] Injecting service into managers...")

        coverArtManager.configure(service: service)
        songManager.configure(service: service)
        downloadManager.configure(service: service)
        // Note: downloadManager.configure(coverArtManager:) is already done in AppDependencies
        
        favoritesManager.configure(service: service)
        exploreManager.configure(service: service)
        musicLibraryManager.configure(service: service)
        playerVM.configure(service: service)

        AppLogger.general.info("[AppInitializer] ✅ Managers configured")
    }

    // MARK: - Data Loading
    func loadInitialData(
        exploreManager: ExploreManager,
        favoritesManager: FavoritesManager,
        musicLibraryManager: MusicLibraryManager
    ) async {
        guard state == .completed, unifiedService != nil else { return }

        AppLogger.general.info("[AppInitializer] Loading initial data...")

        // Swift 6: Structured Concurrency
        await withDiscardingTaskGroup { group in
            group.addTask { await exploreManager.loadExploreData() }
            group.addTask { await favoritesManager.loadFavoriteSongs() }
            group.addTask { await musicLibraryManager.loadInitialDataIfNeeded() }
        }
    }
    
    // MARK: - Reset Logic
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
    
    func reset() {
        unifiedService = nil
        state = .notStarted
        isConfigured = false
        NetworkMonitor.shared.configureService(nil)
    }
}
