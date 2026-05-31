//
//  NavidromeClientApp.swift
//  NavidromeClient
//
//  UPDATED: Swift 6 Compliance
//  - Added @MainActor to struct
//  - Replaced closure-based notifications with AsyncSequence
//
//  FIXED (review):
//  - Removed duplicate .credentialsUpdated handler — AppInitializer owns this
//  - Removed try? Task.sleep timing hack
//  - .factoryResetRequested migrated from .onReceive to .task AsyncSequence
//  - @State singletons annotated to clarify SwiftUI ownership intent
//  - performInitialization: failure now reflected in UI via appInitializer.state
//  - handleScenePhaseChange: redundant @MainActor annotation removed (struct is already @MainActor)
//

import SwiftUI
import BackgroundTasks

@main
@MainActor
struct NavidromeClientApp: App {
    // MARK: - App State

    @State private var appInitializer = AppInitializer()

    // Singletons held in @State so SwiftUI treats them as stable references
    // across re-renders. Assignment never happens after init, so @State
    // doesn't add overhead — it just prevents SwiftUI from discarding them.
    @State private var appConfig = AppConfig.shared
    @State private var networkMonitor = NetworkMonitor.shared
    @State private var downloadManager = DownloadManager.shared
    @State private var offlineManager = OfflineManager.shared
    @State private var audioSessionManager = AudioSessionManager.shared

    @State private var theme = ThemeManager()
    @State private var musicLibraryManager = MusicLibraryManager()
    @State private var songManager = SongManager()
    @State private var exploreManager = ExploreManager()
    @State private var favoritesManager = FavoritesManager()
    @State private var connectionManager = ConnectionViewModel()

    @State private var coverArtManager: CoverArtManager
    @State private var playerVM: PlayerViewModel

    // MARK: - Local State

    @State private var hasConfiguredManagers = false

    // MARK: - Scene Phase

    @Environment(\.scenePhase) private var scenePhase

    init() {
        let coverArt = CoverArtManager()
        let player = PlayerViewModel(coverArtManager: coverArt)

        _coverArtManager = State(initialValue: coverArt)
        _playerVM = State(initialValue: player)

        AppLogger.general.info("[App] Initialized with SwiftUI lifecycle")
    }

    var body: some Scene {
        WindowGroup {
            contentRoot
                .task {
                    await performInitialization()
                    if appInitializer.state == .completed {
                        configureInitialDependencies()
                    }
                }
                .task {
                    for await _ in NotificationCenter.default.notifications(named: UIApplication.willTerminateNotification) {
                        audioSessionManager.handleAppWillTerminate()
                    }
                }
                // NOTE: .credentialsUpdated is intentionally NOT handled here.
                // AppInitializer.setupNotificationObservers() owns that flow:
                // it calls reinitializeAfterConfiguration() which resets and
                // re-runs initialize(). configureManagersAndLoadData() is then
                // triggered by the state change observed in performInitialization().
                .task {
                    for await _ in NotificationCenter.default.notifications(named: .factoryResetRequested) {
                        await handleFactoryReset()
                    }
                }
                .onChange(of: networkMonitor.canLoadOnlineContent) { _, isConnected in
                    Task {
                        await handleNetworkChange(isConnected: isConnected)
                    }
                }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            handleScenePhaseChange(from: oldPhase, to: newPhase)
        }
        .backgroundTask(.appRefresh("com.navidrome.client.refresh")) {
            await handleBackgroundRefresh()
        }
    }

    @ViewBuilder
    private var contentRoot: some View {
        ContentView()
            .environment(appConfig)
            .environment(appInitializer)
            .environment(theme)
            .environment(networkMonitor)
            .environment(downloadManager)
            .environment(offlineManager)
            .environment(audioSessionManager)
            .environment(musicLibraryManager)
            .environment(songManager)
            .environment(exploreManager)
            .environment(favoritesManager)
            .environment(connectionManager)
            .environment(coverArtManager)
            .environment(playerVM)
            .preferredColorScheme(theme.colorScheme)
            .onAppear {
                musicLibraryManager.setupObservers()
            }
    }

    // MARK: - Initialization

    private func performInitialization() async {
        do {
            try await appInitializer.initialize()

            if appInitializer.isConfigured {
                AppLogger.general.info("[App] Configuring managers...")
                configureManagersAndLoadData()
            }
        } catch {
            // appInitializer.state is already set to .failed inside initialize(),
            // so ContentView can react to it. Log here for diagnostics.
            AppLogger.general.error("[App] Initialization failed: \(error)")
        }
    }

    private func configureManagersAndLoadData() {
        guard !hasConfiguredManagers else { return }
        hasConfiguredManagers = true

        appInitializer.configureManagers(
            coverArtManager: coverArtManager,
            songManager: songManager,
            downloadManager: downloadManager,
            favoritesManager: favoritesManager,
            exploreManager: exploreManager,
            musicLibraryManager: musicLibraryManager,
            playerVM: playerVM
        )

        Task {
            await appInitializer.loadInitialData(
                exploreManager: exploreManager,
                favoritesManager: favoritesManager,
                musicLibraryManager: musicLibraryManager
            )
        }
    }

    private func configureInitialDependencies() {
        audioSessionManager.playerViewModel = playerVM
        audioSessionManager.setupRemoteCommandCenter()
    }

    // MARK: - Lifecycle & Background

    private func handleScenePhaseChange(from oldPhase: ScenePhase, to newPhase: ScenePhase) {
        if newPhase == .active {
            guard appInitializer.state == .completed else { return }
            Task { await handleAppActivation() }
        } else if newPhase == .background {
            audioSessionManager.handleAppEnteredBackground()
            scheduleBackgroundRefresh()
        }
    }

    private func handleAppActivation() async {
        await audioSessionManager.handleAppBecameActive()
        await networkMonitor.recheckConnection()

        if !musicLibraryManager.isDataFresh {
            await musicLibraryManager.handleNetworkChange(isOnline: networkMonitor.canLoadOnlineContent)
        }
    }

    private func scheduleBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: "com.navidrome.client.refresh")
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    private func handleBackgroundRefresh() async {
        if let service = appInitializer.unifiedService {
            await favoritesManager.loadFavoriteSongs()
            if let newest = try? await service.getNewestAlbums(size: 5) {
                await coverArtManager.preloadAlbums(newest, context: .card)
            }
        }
    }

    private func handleNetworkChange(isConnected: Bool) async {
        guard hasConfiguredManagers else { return }
        await musicLibraryManager.handleNetworkChange(isOnline: isConnected)
    }

    private func handleFactoryReset() async {
        hasConfiguredManagers = false
        AppLogger.general.info("[App] Factory reset handled")
    }
}
