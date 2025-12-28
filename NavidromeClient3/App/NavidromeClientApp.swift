//
//  NavidromeClientApp.swift
//  NavidromeClient3
//
//  Swift 6: Composition Root with Dependency Injection
//

import SwiftUI
import BackgroundTasks

@main
struct NavidromeClientApp: App {
    // 1. Single Source of Truth for all Dependencies
    @State private var dependencies = AppDependencies()
    
    // 2. Local App State
    @Environment(\.scenePhase) private var scenePhase
    
    init() {
        AppLogger.general.info("[App] Launching NavidromeClient3 (Swift 6)")
    }

    var body: some Scene {
        WindowGroup {
            Group {
                // Route based on initialization state
                switch dependencies.appInitializer.state {
                case .notStarted, .inProgress:
                    InitializationView(initializer: dependencies.appInitializer)
                    
                case .completed:
                    if dependencies.appInitializer.isConfigured {
                        ContentView()
                    } else {
                        WelcomeView()
                    }
                    
                case .failed(let error):
                    InitializationErrorView(error: error) {
                        Task {
                            // FIX: Added 'try?' to handle the throwing async function in the retry action
                            try? await dependencies.appInitializer.initialize()
                        }
                    }
                }
            }
            // 3. Inject Dependencies into Environment
            .environment(dependencies.appConfig)
            .environment(dependencies.appInitializer)
            .environment(dependencies.connectionViewModel)
            .environment(dependencies.playerViewModel)
            
            .environment(dependencies.musicLibraryManager)
            .environment(dependencies.coverArtManager)
            .environment(dependencies.songManager)
            .environment(dependencies.exploreManager)
            .environment(dependencies.favoritesManager)
            .environment(dependencies.downloadManager)
            .environment(dependencies.offlineManager)
            .environment(dependencies.networkMonitor)
            .environment(dependencies.themeManager)
            
            // 4. Styling
            .preferredColorScheme(dependencies.themeManager.colorScheme)
            .tint(dependencies.themeManager.accentColor.color)
            
            // 5. Lifecycle Hooks
            .task {
                // FIX: Wrapped throwing call in do-catch
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
        .backgroundTask(.appRefresh("com.navidrome.client.refresh")) {
            await dependencies.favoritesManager.loadFavoriteSongs()
        }
    }
}
