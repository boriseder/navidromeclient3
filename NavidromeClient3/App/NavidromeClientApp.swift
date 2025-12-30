//
//  NavidromeClientApp.swift
//  NavidromeClient3
//
//  Swift 6: Watches for Login & Injects Service
//

import SwiftUI
import BackgroundTasks

@main
struct NavidromeClientApp: App {
    @State private var dependencies = AppDependencies()
    @Environment(\.scenePhase) private var scenePhase
    
    @State private var showLogin = false
    private let backgroundTaskID = "com.navidrome.client.refresh"
    
    init() {
        AppLogger.general.info("[App] Launching NavidromeClient3 (Swift 6)")
        setupTerminationHandler()
    }

    var body: some Scene {
        WindowGroup {
            Group {
                switch dependencies.appInitializer.state {
                case .notStarted, .inProgress:
                    InitializationView(initializer: dependencies.appInitializer)
                    
                case .completed:
                    // Check AppConfig directly for immediate UI update on login
                    if dependencies.appConfig.getCredentials() != nil {
                        ContentView()
                    } else {
                        NavigationStack {
                            WelcomeView { showLogin = true }
                            .navigationDestination(isPresented: $showLogin) {
                                ServerEditView(viewModel: dependencies.connectionViewModel)
                            }
                        }
                    }
                    
                case .failed(let error):
                    InitializationErrorView(error: error) {
                        Task { try? await dependencies.appInitializer.initialize() }
                    }
                }
            }
            // MARK: - Dependency Injection
            .environment(dependencies.appConfig)
            .environment(dependencies.appInitializer)
            .environment(dependencies.connectionViewModel)
            .environment(dependencies.playerViewModel)
            .environment(dependencies.audioSessionManager)
            .environment(dependencies.musicLibraryManager)
            .environment(dependencies.coverArtManager)
            .environment(dependencies.songManager)
            .environment(dependencies.exploreManager)
            .environment(dependencies.favoritesManager)
            .environment(dependencies.downloadManager)
            .environment(dependencies.offlineManager)
            .environment(dependencies.networkMonitor)
            .environment(dependencies.themeManager)
            .preferredColorScheme(dependencies.themeManager.colorScheme)
            .tint(dependencies.themeManager.accentColor.color)
            .task {
                // 1. Pass Managers to Initializer
                dependencies.appInitializer.configureManagers(
                    coverArtManager: dependencies.coverArtManager,
                    songManager: dependencies.songManager,
                    downloadManager: dependencies.downloadManager,
                    favoritesManager: dependencies.favoritesManager,
                    exploreManager: dependencies.exploreManager,
                    musicLibraryManager: dependencies.musicLibraryManager,
                    playerVM: dependencies.playerViewModel,
                    offlineManager: dependencies.offlineManager
                )
                
                // 2. Run Initialization
                do { try await dependencies.appInitializer.initialize() }
                catch { AppLogger.general.error("App initialization failed: \(error)") }
            }
            // 3. LISTEN FOR LOGIN (This fixes the post-login empty state)
            .onChange(of: dependencies.appConfig.getCredentials()) { _, newCreds in
                if let creds = newCreds {
                    AppLogger.general.info("Credentials changed/loaded - Configuring Service")
                    dependencies.appInitializer.setupService(with: creds)
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                handleScenePhaseChange(newPhase)
            }
        }
        .backgroundTask(.appRefresh(backgroundTaskID)) {
            await handleBackgroundRefresh()
        }
    }
    
    private func handleScenePhaseChange(_ phase: ScenePhase) {
        switch phase {
        case .background:
            dependencies.audioSessionManager.handleAppEnteredBackground()
            scheduleBackgroundRefresh()
        case .active:
            Task {
                await dependencies.networkMonitor.recheckConnection()
                dependencies.audioSessionManager.handleAppBecameActive()
            }
        case .inactive:
            dependencies.audioSessionManager.handleAppWillResignActive()
        @unknown default:
            break
        }
    }
    
    private func setupTerminationHandler() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { _ in
            MainActor.assumeIsolated {
                performEmergencySave()
            }
        }
        
        signal(SIGTERM) { _ in
            Task { @MainActor in
                AudioSessionManager.shared.handleEmergencyShutdown()
            }
        }
    }
    
    @MainActor
    private func performEmergencySave() {
        AppLogger.general.info("[App] Application terminating - saving state.")
        dependencies.audioSessionManager.handleAppWillTerminate()
    }
    
    private func scheduleBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: backgroundTaskID)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            AppLogger.general.error("Failed to schedule refresh: \(error)")
        }
    }
    
    private func handleBackgroundRefresh() async {
        guard dependencies.appConfig.getCredentials() != nil,
              dependencies.networkMonitor.canLoadOnlineContent else { return }
        await dependencies.favoritesManager.loadFavoriteSongs()
        scheduleBackgroundRefresh()
    }
}
