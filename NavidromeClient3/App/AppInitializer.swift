//
//  AppInitializer.swift
//  NavidromeClient3
//
//  Swift 6: Fixed Dependency Injection Wiring
//

import Foundation
import Observation

@MainActor
@Observable
final class AppInitializer {
    
    enum InitializationState: Equatable, Sendable {
        case notStarted
        case inProgress
        case completed
        case failed(String)
    }

    var state: InitializationState = .notStarted
    var isConfigured: Bool = false
    private(set) var unifiedService: UnifiedSubsonicService?
    
    // MARK: - Weak References to Managers
    // We hold these weakly to avoid retain cycles. AppDependencies holds the strong references.
    private weak var coverArtManager: CoverArtManager?
    private weak var songManager: SongManager?
    private weak var downloadManager: DownloadManager?
    private weak var favoritesManager: FavoritesManager?
    private weak var exploreManager: ExploreManager?
    private weak var musicLibraryManager: MusicLibraryManager?
    private weak var playerVM: PlayerViewModel?
    
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
        ) { [weak self] _ in
            Task { @MainActor in
                try? await self?.reinitializeAfterConfiguration()
            }
        }
    }

    // MARK: - Configuration
    
    // Call this ONCE from NavidromeClientApp to wire everything up
    func configureManagers(
        coverArtManager: CoverArtManager,
        songManager: SongManager,
        downloadManager: DownloadManager,
        favoritesManager: FavoritesManager,
        exploreManager: ExploreManager,
        musicLibraryManager: MusicLibraryManager,
        playerVM: PlayerViewModel
    ) {
        // 1. Store references
        self.coverArtManager = coverArtManager
        self.songManager = songManager
        self.downloadManager = downloadManager
        self.favoritesManager = favoritesManager
        self.exploreManager = exploreManager
        self.musicLibraryManager = musicLibraryManager
        self.playerVM = playerVM
        
        // 2. If service already exists, inject immediately
        if let service = unifiedService {
            injectService(service)
        }
    }

    // MARK: - Initialization Logic

    func initialize() async throws {
        guard state == .notStarted || state == .failed("") else { return }

        state = .inProgress
        AppLogger.general.info("[AppInitializer] === Initialization start ===")
        
        let credentials = AppConfig.shared.getCredentials()
        isConfigured = credentials != nil

        if let creds = credentials {
            try createUnifiedService(with: creds)
        } else {
            // No credentials yet, just mark as completed so we show WelcomeView
            state = .completed
        }
    }

    func reinitializeAfterConfiguration() async throws {
        AppLogger.general.info("[AppInitializer] Reinitializing after configuration...")
        
        // 1. Re-create service
        let credentials = AppConfig.shared.getCredentials()
        isConfigured = credentials != nil
        
        if let creds = credentials {
            try createUnifiedService(with: creds)
        }
        
        state = .completed
    }

    private func createUnifiedService(with creds: ServerCredentials) throws {
        let service = UnifiedSubsonicService(
            baseURL: creds.baseURL,
            username: creds.username,
            password: creds.password
        )
        self.unifiedService = service

        NetworkMonitor.shared.configureService(service)
        NetworkMonitor.shared.updateConfiguration(isConfigured: true)
        
        // FIX: Inject the new service into all managers immediately
        injectService(service)
        
        // FIX: Trigger initial data load
        Task {
            await loadInitialData()
        }
        
        AppLogger.general.info("[AppInitializer] Service created & Managers injected")
        state = .completed
    }
    
    private func injectService(_ service: UnifiedSubsonicService) {
        AppLogger.general.info("[AppInitializer] Injecting service into managers...")
        coverArtManager?.configure(service: service)
        songManager?.configure(service: service)
        downloadManager?.configure(service: service)
        favoritesManager?.configure(service: service)
        exploreManager?.configure(service: service)
        musicLibraryManager?.configure(service: service)
        playerVM?.configure(service: service)
    }

    private func loadInitialData() async {
        guard let exploreManager = exploreManager,
              let favoritesManager = favoritesManager,
              let musicLibraryManager = musicLibraryManager else { return }

        AppLogger.general.info("[AppInitializer] 📥 Loading initial data...")

        await withDiscardingTaskGroup { group in
            group.addTask { await exploreManager.loadExploreData() }
            group.addTask { await favoritesManager.loadFavoriteSongs() }
            group.addTask { await musicLibraryManager.loadInitialDataIfNeeded() }
        }
    }
    
    // MARK: - Reset
    
    func performFactoryReset() async {
        AppLogger.general.info("[AppInitializer] === Factory Reset Start ===")
        AppConfig.shared.clearCredentials()
        NetworkMonitor.shared.updateConfiguration(isConfigured: false)
        NetworkMonitor.shared.reset()
        NotificationCenter.default.post(name: .factoryResetRequested, object: nil)
        
        unifiedService = nil
        isConfigured = false
        state = .completed // Return to WelcomeView
        
        NetworkMonitor.shared.configureService(nil)
        AppLogger.general.info("[AppInitializer] === Factory Reset Complete ===")
    }
}
