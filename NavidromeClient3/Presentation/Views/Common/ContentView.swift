//
//  ContentView.swift
//  NavidromeClient3
//
//  Swift 6: Restored Original Tab Layout & Overlays
//

import SwiftUI

struct ContentView: View {
    // MARK: - Dependencies (Swift 6 Environment)
    @Environment(AppConfig.self) private var appConfig
    @Environment(AppInitializer.self) private var appInitializer
    @Environment(PlayerViewModel.self) private var playerVM
    @Environment(NetworkMonitor.self) private var networkMonitor
    @Environment(OfflineManager.self) private var offlineManager
    @Environment(DownloadManager.self) private var downloadManager
    @Environment(ThemeManager.self) private var theme
    
    // MARK: - Local State
    @State private var selectedTab: TabIdentifier = .explore
    @State private var showingSettings = false
    
    enum TabIdentifier: Hashable {
        case explore, albums, artists, genres, favorites
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // MARK: - Main Tab View
            TabView(selection: $selectedTab) {
                
                // 1. Explore
                NavigationStack {
                    ExploreView()
                        .navigationDestination(for: NavidromeClient3.Album.self) { album in
                            AlbumDetailView(album: album)
                        }
                }
                .tabItem {
                    Label("Explore", systemImage: "music.note.house")
                }
                .tag(TabIdentifier.explore)
                
                // 2. Albums
                NavigationStack {
                    AlbumsView()
                        .navigationDestination(for: NavidromeClient3.Album.self) { album in
                            AlbumDetailView(album: album)
                        }
                }
                .tabItem {
                    Label("Albums", systemImage: "record.circle")
                }
                .tag(TabIdentifier.albums)
                
                // 3. Artists
                NavigationStack {
                    ArtistsView()
                        .navigationDestination(for: NavidromeClient3.Album.self) { album in
                            AlbumDetailView(album: album)
                        }
                }
                .tabItem {
                    Label("Artists", systemImage: "person.2")
                }
                .tag(TabIdentifier.artists)
                
                // 4. Genres
                NavigationStack {
                    GenreView()
                        .navigationDestination(for: NavidromeClient3.Album.self) { album in
                            AlbumDetailView(album: album)
                        }
                }
                .tabItem {
                    Label("Genres", systemImage: "music.note.list")
                }
                .tag(TabIdentifier.genres)
                
                // 5. Favorites
                NavigationStack {
                    FavoritesView()
                        .navigationDestination(for: NavidromeClient3.Album.self) { album in
                            AlbumDetailView(album: album)
                        }
                }
                .tabItem {
                    Label("Favorites", systemImage: "heart")
                }
                .tag(TabIdentifier.favorites)
            }
            .tint(theme.accentColor.color) // Use ThemeManager color
            
            // MARK: - Mini Player Overlay
            if playerVM.currentSong != nil {
                MiniPlayerView()
                    .padding(.bottom, 49) // Approximate tab bar height
                    .transition(.move(edge: .bottom))
            }
            
            // MARK: - Network Status Overlay (Top)
            networkStatusOverlay
        }
        // MARK: - Global Settings Sheet
        // We add a settings button to the top of Explore/Home usually,
        // or you can add a 6th tab for it.
        // For now, I'll assume you trigger this via a toolbar button inside the views.
        .sheet(isPresented: $showingSettings) {
            NavigationStack {
                SettingsView()
            }
        }
    }
    
    // MARK: - Network Overlay Component
    @ViewBuilder
    private var networkStatusOverlay: some View {
        VStack {
            switch networkMonitor.contentLoadingStrategy {
            case .offlineOnly(let reason):
                OfflineReasonBanner(reason: reason)
                    .padding(.horizontal, 16)
                    .padding(.top, 50) // Adjust for safe area
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(.easeOut, value: networkMonitor.canLoadOnlineContent)
                
            case .online, .setupRequired:
                EmptyView()
            }
            Spacer()
        }
        .allowsHitTesting(false) // Let clicks pass through to the app
    }
}
