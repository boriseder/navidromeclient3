//
//  NavidromeClientApp.swift
//  NavidromeClient3
//
//  Swift 6: Fixed 'MainActor isolated' errors in Observer
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
                    if dependencies.appInitializer.isConfigured {
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
                dependencies.appInitializer.configureManagers(
                    coverArtManager: dependencies.coverArtManager,
                    songManager: dependencies.songManager,
                    downloadManager: dependencies.downloadManager,
                    favoritesManager: dependencies.favoritesManager,
                    exploreManager: dependencies.exploreManager,
                    musicLibraryManager: dependencies.musicLibraryManager,
                    playerVM: dependencies.playerViewModel
                )
                do { try await dependencies.appInitializer.initialize() }
                catch { AppLogger.general.error("App initialization failed: \(error)") }
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
        // These methods now exist in the updated AudioSessionManager
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
        // 1. OS Notification
        NotificationCenter.default.addObserver(
            forName: UIApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { _ in
            // Fix: Explicitly assume isolation since we are on 'queue: .main'
            MainActor.assumeIsolated {
                performEmergencySave()
            }
        }
        
        // 2. SIGTERM
        signal(SIGTERM) { _ in
            Task { @MainActor in
                AudioSessionManager.shared.handleEmergencyShutdown()
            }
        }
    }
    
    @MainActor
    private func performEmergencySave() {
        AppLogger.general.info("[App] Application terminating - saving state.")
        // Now valid, method added in step 1
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
        guard dependencies.appInitializer.isConfigured,
              dependencies.networkMonitor.canLoadOnlineContent else { return }
        await dependencies.favoritesManager.loadFavoriteSongs()
        scheduleBackgroundRefresh()
    }
}
