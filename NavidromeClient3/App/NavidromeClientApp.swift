//
//  NavidromeClientApp.swift
//  NavidromeClient3
//
//  Swift 6: Clean Entry Point
//

import SwiftUI
import BackgroundTasks

@main
struct NavidromeClientApp: App {
    
    // 1. The Container
    @State private var dependencies = AppDependencies()
    
    // 2. UI-Specific Local State
    @State private var hasPerformedInitialConfiguration = false
    @State private var hasConfiguredManagers = false
    
    @Environment(\.scenePhase) private var scenePhase
    
    init() {
        AppLogger.general.info("[App] Launching with Swift 6 Architecture")
    }

    var body: some Scene {
        WindowGroup {
            contentRoot
                .task {
                    await performInitialization()
                    configureInitialDependencies()
                }
                // React to dependencies state changes
                .onChange(of: dependencies.appInitializer.isConfigured) { _, isConfigured in
                    handleConfigurationChange(isConfigured)
                }
                .onChange(of: dependencies.networkMonitor.canLoadOnlineContent) { _, isConnected in
                    Task { await handleNetworkChange(isConnected: isConnected) }
                }
                .onReceive(NotificationCenter.default.publisher(for: .factoryResetRequested)) { _ in
                    Task { await handleFactoryReset() }
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
        Group {
            switch dependencies.appInitializer.state {
            case .notStarted, .inProgress:
                InitializationView(initializer: dependencies.appInitializer)
                
            case .completed:
                ContentView()
                
            case .failed(let error):
                InitializationErrorView(error: error) {
                    Task { try? await dependencies.appInitializer.initialize() }
                }
            }
        }
        // 3. Inject Resolved Dependencies
        .environment(dependencies.appConfig)
        .environment(dependencies.appInitializer)
        .environment(dependencies.playerViewModel)
        .environment(dependencies.musicLibraryManager)
        .environment(dependencies.coverArtManager)
        .environment(dependencies.songManager)
        .environment(dependencies.exploreManager)
        .environment(dependencies.favoritesManager)
        .environment(dependencies.downloadManager)
        .environment(dependencies.audioSessionManager)
        .environment(dependencies.networkMonitor)
        .environment(dependencies.offlineManager)
        .environment(dependencies.connectionViewModel)
        .environment(dependencies.themeManager)
        .preferredColorScheme(dependencies.themeManager.colorScheme)
    }

    // MARK: - Logic
    
    private func performInitialization() async {
        do {
            try await dependencies.appInitializer.initialize()
            if dependencies.appInitializer.state == .completed && dependencies.appInitializer.isConfigured {
                configureManagersAndLoadData()
            }
        } catch {
            AppLogger.general.error("[App] Init failed: \(error)")
        }
    }
    
    private func configureManagersAndLoadData() {
        guard !hasConfiguredManagers else { return }
        hasConfiguredManagers = true
        
        // Pass the resolved dependencies to the initializer
        dependencies.appInitializer.configureManagers(
            coverArtManager: dependencies.coverArtManager,
            songManager: dependencies.songManager,
            downloadManager: dependencies.downloadManager,
            favoritesManager: dependencies.favoritesManager,
            exploreManager: dependencies.exploreManager,
            musicLibraryManager: dependencies.musicLibraryManager,
            playerVM: dependencies.playerViewModel
        )
        
        Task {
            await waitForStableNetworkState()
            await dependencies.appInitializer.loadInitialData(
                exploreManager: dependencies.exploreManager,
                favoritesManager: dependencies.favoritesManager,
                musicLibraryManager: dependencies.musicLibraryManager
            )
        }
    }
    
    private func configureInitialDependencies() {
        // AudioSession is already wired to Player in AppDependencies.
        // We just need to trigger the command center setup.
        dependencies.audioSessionManager.setupRemoteCommandCenter()
        setupTerminationHandler()
    }
    
    // ... [Rest of the methods (handleNetworkChange, etc.) access 'dependencies.xxx' instead of local properties] ...
    
    private func waitForStableNetworkState() async {
        for _ in 0..<40 {
            if dependencies.networkMonitor.contentLoadingStrategy != .setupRequired { return }
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
    }
    
    private func handleNetworkChange(isConnected: Bool) async {
         guard dependencies.appInitializer.state == .completed, hasConfiguredManagers else { return }
         await dependencies.musicLibraryManager.handleNetworkChange(isOnline: isConnected)
    }
    
    private func handleFactoryReset() async {
        hasPerformedInitialConfiguration = false
        hasConfiguredManagers = false
    }
    
    private func handleBackgroundRefresh() async {
        await dependencies.favoritesManager.loadFavoriteSongs()
        // ... (rest of background logic)
    }
    
    private func setupTerminationHandler() {
         // Logic remains the same, referencing dependencies.audioSessionManager
    }
    
    private func handleScenePhaseChange(from old: ScenePhase, to new: ScenePhase) {
        // Logic remains the same
    }
}
