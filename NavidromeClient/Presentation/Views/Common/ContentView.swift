//
//  ContentView.swift
//  NavidromeClient
//

import SwiftUI
import Observation

struct ContentView: View {
    @Environment(AppConfig.self) var appConfig
    @Environment(AppInitializer.self) var appInitializer
    @Environment(ThemeManager.self) var theme
    @Environment(PlayerViewModel.self) var playerVM
    @Environment(NetworkMonitor.self) var networkMonitor

    var body: some View {
        Group {
            switch networkMonitor.contentLoadingStrategy {
            case .initializing:
                Color.clear

            case .setupRequired:
                WelcomeView()

            case .online, .offlineOnly:
                mainTabView
                    .overlay(networkStatusOverlay, alignment: .top)
                    .overlay(alignment: .bottom) {
                        if playerVM.currentSong != nil {
                            MiniPlayerView()
                                .padding(.horizontal, 8)
                                .padding(.bottom, tabBarHeight)
                        }
                    }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: networkMonitor.contentLoadingStrategy == .setupRequired)
    }

    // MARK: - Tab Bar Height

    private var tabBarHeight: CGFloat {
        let bottomInset = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?
            .windows.first?
            .safeAreaInsets.bottom ?? 0
        return 49 + bottomInset
    }

    // MARK: - Main Tab View

    private var mainTabView: some View {
        TabView {
            ExploreView()
                .tabItem { Label("Explore", systemImage: "music.note.house") }
                .tag(0)
            AlbumsView()
                .tabItem { Label("Albums", systemImage: "record.circle") }
                .tag(1)
            ArtistsView()
                .tabItem { Label("Artists", systemImage: "person.2") }
                .tag(2)
            GenreView()
                .tabItem { Label("Genres", systemImage: "music.note.list") }
                .tag(3)
            FavoritesView()
                .tabItem { Label("Favorites", systemImage: "heart") }
                .tag(4)
        }
        .tint(theme.accent)
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
