//
//  ContentView.swift
//  NavidromeClient
//
//  UPDATED: Swift 6 & iOS 17+ Modernization
//  - Fully Migrated to @Observable
//  - No legacy EnvironmentObjects
//

import SwiftUI

struct ContentView: View {
    // MARK: - Environments
    @Environment(AppConfig.self) var appConfig
    @Environment(AppInitializer.self) var appInitializer
    @Environment(ThemeManager.self) var theme
    
    @Environment(PlayerViewModel.self) var playerVM
    @Environment(NetworkMonitor.self) var networkMonitor
    @Environment(OfflineManager.self) var offlineManager
    @Environment(DownloadManager.self) var downloadManager
    
    @State private var showingSettings = false
    @State private var isInitialSetup = false
    @State private var serviceInitError: String?
    
    var body: some View {
        Group {
            switch networkMonitor.contentLoadingStrategy {
            case .setupRequired:
                WelcomeView {
                    isInitialSetup = true
                    showingSettings = true
                }
            case .online, .offlineOnly:
                TabView {
                    ExploreView()
                        .tabItem {
                            Image(systemName: "music.note.house")
                            Text("Explore")
                        }
                        .tag(0)
                    
                    AlbumsView()
                        .tabItem {
                            Image(systemName: "record.circle")
                            Text("Albums")
                        }
                        .tag(1)
                    
                    ArtistsView()
                        .tabItem {
                            Image(systemName: "person.2")
                            Text("Artists")
                        }
                        .tag(2)
                    
                    GenreView()
                        .tabItem {
                            Image(systemName: "music.note.list")
                            Text("Genres")
                        }
                        .tag(3)
                    
                    FavoritesView()
                        .tabItem {
                            Image(systemName: "heart")
                            Text("Favorites")
                        }
                        .tag(4)
                }
                .accentColor(theme.accent)
                .id(theme.accent)
                .overlay(networkStatusOverlay, alignment: .top)
                .overlay(alignment: .bottom) {
                    MiniPlayerView()
                        .environment(playerVM)
                        .padding(.bottom, DSLayout.miniPlayerHeight)
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            NavigationStack {
                ServerEditView(dismissParent: {
                    if isInitialSetup {
                        showingSettings = false
                        isInitialSetup = false
                    }
                })
                .navigationTitle("Server Setup")
                .navigationBarTitleDisplayMode(.inline)
            }
        }
    }

    private func retryServiceInitialization() async {
        guard appConfig.hasCredentials() else {
            serviceInitError = "No credentials available"
            return
        }
        
        serviceInitError = nil
        
        try? await appInitializer.reinitializeAfterConfiguration()
        
        for _ in 0..<10 {
            try? await Task.sleep(nanoseconds: 500_000_000)
            if appInitializer.areServicesReady {
                AppLogger.ui.info("Service initialization retry succeeded")
                return
            }
        }
        
        serviceInitError = "Retry failed - check your connection"
    }
    
    // MARK: - Network Status Overlay
    @ViewBuilder
    private var networkStatusOverlay: some View {
        switch networkMonitor.contentLoadingStrategy {
            case .offlineOnly(let reason):
                OfflineReasonBanner(reason: reason)
                    .padding(.horizontal, DSLayout.screenPadding)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(DSAnimations.ease, value: networkMonitor.canLoadOnlineContent)
                
            case .online, .setupRequired:
                EmptyView()
        }
    }
}
