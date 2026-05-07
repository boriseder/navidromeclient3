//
//  ContentView.swift
//  NavidromeClient
//
//  UPDATED: Swift 6 & iOS 17+ Modernization
//  - FIXED: Handles .initializing state to prevent WelcomeView flash
//

import SwiftUI
import Observation

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
            case .initializing:
                // Show nothing during initialization - prevents WelcomeView flash
                Color.clear
                
            case .setupRequired:
                WelcomeView {
                    isInitialSetup = true
                    showingSettings = true
                }
                
            case .online, .offlineOnly:

                ZStack(alignment: .bottom) {
                    // Layer 1: Deine Tabs
                    TabView {
                        ExploreView().tabItem { Label("Explore", systemImage: "music.note.house") }.tag(0)
                        AlbumsView().tabItem { Label("Albums", systemImage: "record.circle") }.tag(1)
                        ArtistsView().tabItem { Label("Artists", systemImage: "person.2") }.tag(2)
                        GenreView().tabItem { Label("Genres", systemImage: "music.note.list") }.tag(3)
                        FavoritesView().tabItem { Label("Favorites", systemImage: "heart") }.tag(4)
                    }
                    .tint(theme.accent)
                    .id(theme.accent)
                    
                    // Layer 2: Der MiniPlayer, der sich NICHT über die TabBar legt
                    VStack(spacing: 0) {
                        Spacer() // Drückt den Player nach unten
                        
                        MiniPlayerView()
                            .environment(playerVM)
                            // Hier schieben wir den Player so hoch, dass er exakt über der TabBar sitzt.
                            // 49 ist die Standard-Höhe einer TabBar auf dem iPhone. Du kannst hier auch
                            // einen festen Wert aus deinem DSLayout verwenden, falls du einen hast.
                            .padding(.bottom, 49)
                    }
                    // Verhindert, dass der VStack selbst Taps abfängt, wenn man ins Leere klickt
                    .allowsHitTesting(false)
                }
                .overlay(networkStatusOverlay, alignment: .top)

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
        guard appConfig.credentials != nil else {
            serviceInitError = "No credentials available"
            return
        }
        
        serviceInitError = nil
        
        try? await appInitializer.reinitializeAfterConfiguration()
        
        for _ in 0..<10 {
            try? await Task.sleep(for: .seconds(0.5))
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
                
            case .online, .setupRequired, .initializing:
                EmptyView()
        }
    }
}
