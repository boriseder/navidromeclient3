//
//  ContentView.swift
//  NavidromeClient3
//
//  Swift 6: @Observable Consumption
//

import SwiftUI

struct ContentView: View {
    // 1. New Environment Syntax
    @Environment(PlayerViewModel.self) private var playerVM
    @Environment(MusicLibraryManager.self) private var library
    @Environment(OfflineManager.self) private var offlineManager
    @Environment(NetworkMonitor.self) private var networkMonitor

    // Local state remains @State
    @State private var selectedTab: TabIdentifier = .library
    
    enum TabIdentifier: Hashable {
        case library, search, downloads, settings
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                // Tab 1: Library
                NavigationStack {
                    ExploreView() // Internal views now use Environment internally
                }
                .tabItem {
                    Label("Library", systemImage: "music.note.house")
                }
                .tag(TabIdentifier.library)

                // Tab 2: Favorites (Example replacement for Search for now)
                NavigationStack {
                    FavoritesView()
                }
                .tabItem {
                    Label("Favorites", systemImage: "heart")
                }
                .tag(TabIdentifier.search)
                
                // Tab 3: Downloads
                NavigationStack {
                    // DownloadsView() - Assuming existence
                    Text("Downloads Placeholder")
                }
                .tabItem {
                    Label("Downloads", systemImage: "arrow.down.circle")
                }
                .tag(TabIdentifier.downloads)

                // Tab 4: Settings
                NavigationStack {
                    SettingsView()
                }
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(TabIdentifier.settings)
            }
            .tint(Color.accentColor)
            
            // Player Overlay
            if playerVM.currentSong != nil {
                MiniPlayerView()
                    .padding(.bottom, 49) // Approximate tab bar height
                    .transition(.move(edge: .bottom))
            }
        }
        // Swift 6: Task modifier replaces .onAppear for async work
        .task {
             if networkMonitor.shouldLoadOnlineContent {
                 await library.loadInitialDataIfNeeded()
             }
        }
    }
}
