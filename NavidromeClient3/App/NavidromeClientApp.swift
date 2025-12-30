//
//  NavidromeClientApp.swift
//  NavidromeClient3
//
//  Swift 6: Fixed Missing AudioSessionManager Injection
//

import SwiftUI

@main
struct NavidromeClientApp: App {
    @State private var dependencies = AppDependencies()
    @Environment(\.scenePhase) private var scenePhase
    
    // Navigation state for the Welcome flow
    @State private var showLogin = false
    
    init() {
        AppLogger.general.info("[App] Launching NavidromeClient3 (Swift 6)")
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
                        // Welcome Flow
                        NavigationStack {
                            WelcomeView {
                                showLogin = true
                            }
                            .navigationDestination(isPresented: $showLogin) {
                                ServerEditView(viewModel: dependencies.connectionViewModel)
                            }
                        }
                    }
                    
                case .failed(let error):
                    InitializationErrorView(error: error) {
                        Task {
                            try? await dependencies.appInitializer.initialize()
                        }
                    }
                }
            }
            // MARK: - Dependency Injection
            .environment(dependencies.appConfig)
            .environment(dependencies.appInitializer)
            .environment(dependencies.connectionViewModel)
            .environment(dependencies.playerViewModel)
            
            // FIX: Added missing AudioSessionManager
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
            
            // Styles
            .preferredColorScheme(dependencies.themeManager.colorScheme)
            .tint(dependencies.themeManager.accentColor.color)
            
            // Lifecycle
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
                
                do {
                    try await dependencies.appInitializer.initialize()
                } catch {
                    AppLogger.general.error("App initialization failed: \(error)")
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .background {
                    // dependencies.someManager.saveState()
                }
            }
        }
    }
}
