import SwiftUI
import BackgroundTasks

@main
struct NavidromeClientApp: App {
    // MARK: - App State
    // All top-level objects are now @State and injected via .environment()
    @State private var appInitializer = AppInitializer()
    @State private var appConfig = AppConfig.shared
    @State private var theme = ThemeManager()
    
    @State private var networkMonitor = NetworkMonitor.shared
    @State private var downloadManager = DownloadManager.shared
    @State private var offlineManager = OfflineManager.shared
    @State private var audioSessionManager = AudioSessionManager.shared
    
    @State private var musicLibraryManager = MusicLibraryManager()
    @State private var songManager = SongManager()
    @State private var exploreManager = ExploreManager()
    @State private var favoritesManager = FavoritesManager()
    @State private var connectionManager = ConnectionViewModel()
    
    @State private var coverArtManager: CoverArtManager
    @State private var playerVM: PlayerViewModel
    
    // MARK: - Local State
    @State private var hasPerformedInitialConfiguration = false
    @State private var hasConfiguredManagers = false
    
    // MARK: - Scene Phase
    @Environment(\.scenePhase) private var scenePhase
    
    init() {
        // Initialize interconnected managers
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
                    configureInitialDependencies()
                }
                .onChange(of: appInitializer.isConfigured) { _, isConfigured in
                    handleConfigurationChange(isConfigured)
                }
                .onChange(of: networkMonitor.canLoadOnlineContent) { _, isConnected in
                    Task {
                        await handleNetworkChange(isConnected: isConnected)
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .factoryResetRequested)) { _ in
                    Task {
                        await handleFactoryReset()
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
        switch appInitializer.state {
        case .notStarted, .inProgress:
            InitializationView(initializer: appInitializer)
            
        case .completed:
            ContentView()
                // Inject ALL dependencies using modern .environment()
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
            
        case .failed(let error):
            InitializationErrorView(error: error) {
                Task {
                    try? await appInitializer.initialize()
                }
            }
        }
    }

    // MARK: - Initialization Logic
    
    private func performInitialization() async {
        do {
            try await appInitializer.initialize()
            if appInitializer.state == .completed && appInitializer.isConfigured {
                AppLogger.general.info("[App] Initialization completed - configuring managers")
                configureManagersAndLoadData()
            }
        } catch {
            AppLogger.general.error("[App] Initialization failed: \(error)")
        }
    }

    private func handleConfigurationChange(_ isConfigured: Bool) {
        guard isConfigured else { return }

        if !hasConfiguredManagers {
            AppLogger.general.info("[App] Configuration changed - initializing managers")
            configureManagersAndLoadData()
            
            if !hasPerformedInitialConfiguration {
                hasPerformedInitialConfiguration = true
            }
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
            await waitForStableNetworkState()
            
            await appInitializer.loadInitialData(
                exploreManager: exploreManager,
                favoritesManager: favoritesManager,
                musicLibraryManager: musicLibraryManager
            )
        }
    }
    
    private func waitForStableNetworkState() async {
        for _ in 0..<40 {
            if networkMonitor.contentLoadingStrategy != .setupRequired { return }
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        AppLogger.general.warn("[App] Timeout waiting for stable network state")
    }
    
    private func configureInitialDependencies() {
        audioSessionManager.playerViewModel = playerVM
        audioSessionManager.setupRemoteCommandCenter()
        setupTerminationHandler()
    }
    
    // MARK: - Lifecycle & Background
    
    private func setupTerminationHandler() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak audioSessionManager] _ in
            MainActor.assumeIsolated {
                audioSessionManager?.handleAppWillTerminate()
            }
        }
    }
    
    private func handleScenePhaseChange(from oldPhase: ScenePhase, to newPhase: ScenePhase) {
        if newPhase == .active {
            guard appInitializer.state == .completed else { return }
            Task { @MainActor in await handleAppActivation() }
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
        hasPerformedInitialConfiguration = false
        hasConfiguredManagers = false
        AppLogger.general.info("[App] Factory reset handled")
    }
}
