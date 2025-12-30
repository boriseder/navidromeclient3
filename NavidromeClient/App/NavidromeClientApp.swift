import SwiftUI
import BackgroundTasks

@main
struct NavidromeClientApp: App {
    // MARK: - State Objects
    @StateObject private var appInitializer = AppInitializer()
    @StateObject private var appConfig = AppConfig.shared
    @StateObject private var networkMonitor = NetworkMonitor.shared
    
    @StateObject private var musicLibraryManager = MusicLibraryManager()
    @StateObject private var playerVM: PlayerViewModel
    @StateObject private var coverArtManager = CoverArtManager()
    @StateObject private var songManager = SongManager()
    @StateObject private var exploreManager = ExploreManager()
    @StateObject private var favoritesManager = FavoritesManager()
    @StateObject private var downloadManager = DownloadManager.shared
    @StateObject private var audioSessionManager = AudioSessionManager.shared
    @StateObject private var offlineManager = OfflineManager.shared
    @StateObject private var connectionManager: ConnectionViewModel
    @StateObject private var theme = ThemeManager()
    
    // MARK: - Local State
    @State private var hasPerformedInitialConfiguration = false
    @State private var hasConfiguredManagers = false
    
    // MARK: - Scene Phase
    @Environment(\.scenePhase) private var scenePhase
    
    init() {
        // Initialize dependencies
        let musicLib = MusicLibraryManager()
        let coverArt = CoverArtManager()
        let player = PlayerViewModel(coverArtManager: coverArt)
        let connection = ConnectionViewModel()

        _musicLibraryManager = StateObject(wrappedValue: musicLib)
        _coverArtManager = StateObject(wrappedValue: coverArt)
        _playerVM = StateObject(wrappedValue: player)
        _connectionManager = StateObject(wrappedValue: connection)

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
                .environmentObject(appConfig)
                .environmentObject(appInitializer)
                .environmentObject(playerVM)
                .environmentObject(musicLibraryManager)
                .environmentObject(coverArtManager)
                .environmentObject(songManager)
                .environmentObject(exploreManager)
                .environmentObject(favoritesManager)
                .environmentObject(downloadManager)
                .environmentObject(audioSessionManager)
                .environmentObject(networkMonitor)
                .environmentObject(offlineManager)
                .environmentObject(connectionManager)
                .environmentObject(theme)
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
            // Wait for network monitor to settle before loading data
            await waitForStableNetworkState()
            
            await appInitializer.loadInitialData(
                exploreManager: exploreManager,
                favoritesManager: favoritesManager,
                musicLibraryManager: musicLibraryManager
            )
        }
    }
    
    private func waitForStableNetworkState() async {
        // Poll for network state stability (max 2 seconds)
        for _ in 0..<40 {
            if networkMonitor.contentLoadingStrategy != .setupRequired {
                return
            }
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
            audioSessionManager?.handleAppWillTerminate()
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
        
        if await !musicLibraryManager.isDataFresh {
             await musicLibraryManager.handleNetworkChange(isOnline: networkMonitor.canLoadOnlineContent)
        }
    }
    
    private func scheduleBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: "com.navidrome.client.refresh")
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }
    
    private func handleBackgroundRefresh() async {
        // Background refresh logic - perform essential updates only
        if let service = appInitializer.unifiedService {
             await favoritesManager.loadFavoriteSongs()
             // Preload some fresh covers
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
