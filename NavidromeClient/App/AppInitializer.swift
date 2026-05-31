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
//  FIXED (review):
//  - credentialsObserverTask is now stored and cancelled on deinit (was fire-and-forget leak)
//  - setupNotificationObservers: try? replaced with do/catch that sets state = .failed
//  - initialize(): createUnifiedService failure now sets state = .failed instead of leaving
//    state as .notStarted with no signal to the caller
//  - performFactoryReset: local state reset before posting notification (was posting with stale state)
//  - performFactoryReset: state after reset is .notStarted, not .completed
//  - getCredentials() replaced with direct .credentials property access
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

    // Stored so the loop can be cancelled on deinit instead of leaking forever.
    @ObservationIgnored nonisolated(unsafe) private var credentialsObserverTask: Task<Void, Never>?

    init() {
        setupNotificationObservers()
    }

    deinit {
        credentialsObserverTask?.cancel()
    }

    private func setupNotificationObservers() {
        credentialsObserverTask = Task { @MainActor [weak self] in
            for await notification in NotificationCenter.default.notifications(named: .credentialsUpdated) {
                guard let self else { break }
                guard notification.object is ServerCredentials else { continue }
                do {
                    try await self.reinitializeAfterConfiguration()
                } catch {
                    // Surface the failure rather than silently swallowing it
                    self.state = .failed(error.localizedDescription)
                    AppLogger.general.error("[AppInitializer] Reinitialization after credentials update failed: \(error)")
                }
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

        let credentials = AppConfig.shared.credentials
        isConfigured = credentials != nil

        if let creds = credentials {
            do {
                try createUnifiedService(with: creds)
            } catch {
                // Set .failed so the caller and any state observers know
                // initialization didn't complete — without this, state would
                // stay .notStarted with no signal that something went wrong.
                state = .failed(error.localizedDescription)
                AppLogger.general.error("[AppInitializer] Service creation failed: \(error)")
                throw error
            }
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
        guard areServicesReady else {
            AppLogger.general.warn("[AppInitializer] Cannot configure managers - services not ready (state: \(state), isConfigured: \(isConfigured))")
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
        guard areServicesReady else {
            AppLogger.general.warn("[AppInitializer] Cannot load data - services not ready (state: \(state), isConfigured: \(isConfigured))")
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

        // Reset all local state BEFORE posting the notification.
        // Any observer that fires immediately will otherwise read stale values
        // (e.g. isConfigured = true, unifiedService still set).
        unifiedService = nil
        isConfigured = false
        state = .notStarted  // .notStarted, not .completed — the app needs to go through setup again
        NetworkMonitor.shared.configureService(nil)
        NetworkMonitor.shared.updateConfiguration(isConfigured: false)
        NetworkMonitor.shared.reset()

        NotificationCenter.default.post(name: .factoryResetRequested, object: nil)

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
